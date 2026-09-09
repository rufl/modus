extends Node

const PlayerScene = preload("res://game/entities/player/player.tscn")
const EnemyScene = preload("res://game/entities/enemies/enemy.tscn")
const EditorAvatarScene = preload("res://game/entities/player/editor_avatar.tscn")
const IntermissionScreenScript = preload("res://game/ui/menus/intermission_screen.gd")
const EnemySpawnManagerScript = preload("res://game/world/enemy_spawn_manager.gd")
const ShowcaseSignageScript = preload("res://game/world/showcase_signage.gd")
const PORT = 9999
const PAUSE_SCREEN = "res://shared/ui_core/screens/pause_screen.tscn"
const MAIN_MENU_SCREEN = "res://shared/ui_core/screens/main_menu_screen.tscn"
const WELCOME_SCREEN = "res://game/ui/menus/welcome_screen.tscn"
const DEFAULT_ENEMY_OUT_OF_BOUNDS_Y: float = -50.0

var enet_peer: ENetMultiplayerPeer = null
var _session_multiplayer: MultiplayerAPI = null
var in_game: bool = false
var match_stats: Dictionary = {
	"enemies_killed": 0,
	"shots_fired": 0,
	"shots_hit": 0,
	"damage_dealt": 0.0,
	"damage_taken": 0.0,
	"critical_hits": 0,
	"items_collected": 0,
	"enemies_spawned": 0,
	"enemies_stuck": 0,
	"enemies_out_of_bounds": 0,
	"enemies_relocated": 0,
}

@onready var spawn_manager: Node  # EnemySpawnManager


# Helper function to safely log messages
func _log(message: String, category: String = "World") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])


func _log_debug(message: String, category: String = "World") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("debug"):
		logger.debug(message, category)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_log_debug("ESC pressed, in_game=%s" % in_game)

		if in_game:
			var us := UISystem.get_service()
			_log_debug("UISystem service: %s" % us)

			if us and us.ui_manager:
				# Prevent opening pause menu if already transitioning or has modal
				var ui: Node = us.ui_manager
				var can_open: bool = not ui.has_open_modal()
				_log_debug("can_open=%s has_open_modal=%s" % [can_open, ui.has_open_modal()])

				if (
					can_open
					and (not ui.has_method("is_transitioning") or not ui.is_transitioning())
				):
					_log_debug("Opening pause menu...")
					ui.push_screen(PAUSE_SCREEN)
					get_viewport().set_input_as_handled()
				else:
					print("[World] Cannot open pause menu - transitioning or has modal")
			else:
				print("[World] UISystem or ui_manager not available")
		else:
			print("[World] Not in game yet")


func _notification(_what: int) -> void:
	# Legacy logic removed
	pass


func _process(_delta: float) -> void:
	if not enet_peer:
		return
	var current_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if (
		current_peer != enet_peer
		or enet_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED
	):
		# NetworkManager may disconnect or replace the transport independently.
		# An externally supplied active session retains its own gameplay state.
		if (
			not current_peer
			or current_peer is OfflineMultiplayerPeer
			or current_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED
		):
			in_game = false
		_release_host_session()


func _ready() -> void:
	_log("[World] World scene _ready() called!")

	# If this is during menu startup AND we are not the current scene, don't initialize
	# This prevents the world from sticking around if it was loaded as a background preview
	# but allows it to function if it's the intended main scene.
	# MENU state
	if GameManager and GameManager.has_method("get_state") and GameManager.get_state() == 0:
		if get_tree().current_scene != self:
			_log("[World] Skipping initialization: Background instance detected during menu")
			queue_free()
			return

		_log("[World] Running as main scene during menu state (likely startup map)")

	var p_node: Node = get_parent()
	var p_name: String = str(p_node.name) if p_node else "null"
	_log("[World] Parent: %s" % p_name)

	var tree: SceneTree = get_tree()
	var c_scene: Node = tree.current_scene if tree else null
	var s_name: String = str(c_scene.name) if c_scene else "null"
	_log("[World] Current scene: %s" % s_name)

	# Initialize Object Pools
	var bullet_hole_scene: PackedScene = preload("res://game/scenes/effects/bullet_hole.tscn")
	var impact_scene: PackedScene = preload("res://game/scenes/effects/impact_particles.tscn")
	var pool_service: Node = GameManager.get_core_system("pools")
	if pool_service and pool_service.has_method("register_pool"):
		pool_service.register_pool("bullet_hole", bullet_hole_scene, 100, 500)
		pool_service.register_pool("impact_particles", impact_scene, 50, 200)

	# Auto-start game if we transitioned from menu via "Start Game"
	# Check if GameManager state is INITIALIZING (coming from menu)
	if GameManager and GameManager.has_method("get_state"):
		var current_state: int = GameManager.get_state()
		# GameManager.State.INITIALIZING = 0
		if current_state == 0:  # INITIALIZING state from menu
			_log("[World] Initializing state detected, auto-starting singleplayer...")
			_on_single_player_start_requested("default")

			if in_game:
				GameManager.change_state(GameManager.State.RUNNING)

			# Ensure loading screen is hidden
			var us := UISystem.get_service()
			if us and us.loading_screen:
				us.loading_screen.hide_loading()

			if in_game:
				# Show welcome screen on showcase map
				call_deferred("_show_welcome_screen")

	# Spawn showcase zone signs
	call_deferred("_spawn_showcase_signs")

	# Register MultiplayerSpawner scenes
	$MultiplayerSpawner.add_spawnable_scene("res://game/entities/projectiles/rocket.tscn")
	$MultiplayerSpawner.add_spawnable_scene("res://game/entities/projectiles/grenade.tscn")
	$MultiplayerSpawner.add_spawnable_scene("res://game/entities/player/player.tscn")
	$MultiplayerSpawner.add_spawnable_scene("res://game/entities/player/editor_avatar.tscn")
	$MultiplayerSpawner.add_spawnable_scene("res://game/entities/enemies/enemy.tscn")

	var spawner: MultiplayerSpawner = $MultiplayerSpawner
	spawner.add_spawnable_scene("res://game/scenes/items/pickups/pistol_pickup.tscn")
	spawner.add_spawnable_scene("res://game/scenes/items/pickups/shotgun_pickup.tscn")
	spawner.add_spawnable_scene("res://game/scenes/items/pickups/machinegun_pickup.tscn")
	spawner.add_spawnable_scene("res://game/scenes/items/pickups/rocket_launcher_pickup.tscn")
	spawner.add_spawnable_scene("res://game/scenes/items/pickups/health_pickup.tscn")
	spawner.add_spawnable_scene("res://game/scenes/items/pickups/ammo_pickup.tscn")
	spawner.add_spawnable_scene("res://game/scenes/items/pickups/armor_pickup.tscn")
	spawner.add_spawnable_scene("res://game/scenes/items/pickups/consumable_pickup.tscn")
	spawner.add_spawnable_scene("res://game/scenes/items/pickups/pickup_base.tscn")
	spawner.add_spawnable_scene("res://game/scenes/items/pickups/double_jump_powerup.tscn")
	spawner.add_spawnable_scene("res://game/scenes/items/pickups/dodge_powerup.tscn")
	for prop_scene: String in LootPropSpawner.PROP_SCENES.values():
		spawner.add_spawnable_scene(prop_scene)

	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		call_deferred("_bake_nav_mesh")

	# Subscriptions
	GameManager.subscribe("match_started", _on_match_started)
	GameManager.subscribe("play_requested", _on_play_requested)
	GameManager.subscribe("enemy_died", _on_enemy_died_stats)
	GameManager.subscribe("weapon_fired", _on_weapon_fired_stats)
	GameManager.subscribe("damage_dealt", _on_damage_dealt_stats)
	GameManager.subscribe("critical_hit", _on_critical_hit_stats)
	GameManager.subscribe("item_picked_up", _on_item_collected_stats)

	# Setup Enemy Spawn Manager
	spawn_manager = EnemySpawnManagerScript.new()
	spawn_manager.name = "EnemySpawnManager"
	add_child(spawn_manager)
	spawn_manager.setup(self, match_stats)

	# Setup Intermission Screen for match end
	_setup_intermission_screen()


func _exit_tree() -> void:
	_release_host_session()
	in_game = false
	# Unsubscribe from all GameManager events to prevent null callable errors
	GameManager.unsubscribe("match_started", _on_match_started)
	GameManager.unsubscribe("play_requested", _on_play_requested)
	GameManager.unsubscribe("enemy_died", _on_enemy_died_stats)
	GameManager.unsubscribe("weapon_fired", _on_weapon_fired_stats)
	GameManager.unsubscribe("damage_dealt", _on_damage_dealt_stats)
	GameManager.unsubscribe("critical_hit", _on_critical_hit_stats)
	GameManager.unsubscribe("item_picked_up", _on_item_collected_stats)
	GameManager.unsubscribe("intermission_replay", _on_intermission_replay_event)
	GameManager.unsubscribe("intermission_harder", _on_intermission_harder_event)
	GameManager.unsubscribe("intermission_main_menu", _on_intermission_main_menu_event)


func _on_play_requested(data: Dictionary) -> void:
	var slot_name: String = data.get("slot_name", "default")
	_on_single_player_start_requested(slot_name)


func _on_match_started(_args: Dictionary = {}) -> void:
	in_game = true
	print("[World] Match started - in_game set to true")


func add_player(_peer_id: int) -> void:
	# Only server spawns players (MultiplayerSpawner handles replication)
	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if not is_server_or_sp:
		return
	# Wait for spawn request


@rpc("any_peer", "call_local", "reliable")
func request_spawn(mode: String = "player") -> void:
	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if not is_server_or_sp:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	spawn_player_node(peer_id, mode)


func spawn_player_node(peer_id: int, mode: String) -> void:
	print("========== SPAWNING PLAYER ==========")
	print("[World] spawn_player_node called - peer_id: ", peer_id, " mode: ", mode)

	var player: Node3D
	if mode == "editor":
		print("[World] Instantiating EditorAvatarScene")
		player = EditorAvatarScene.instantiate()
	else:
		print("[World] Instantiating PlayerScene")
		player = PlayerScene.instantiate()

	player.name = str(peer_id)
	print("[World] Player name set to: ", player.name)

	# Configure spawn state before _ready and MultiplayerSpawner observe the player.
	var spawn_transform := Transform3D(Basis.IDENTITY, Vector3(0, 2, 0))
	var spawn_points: Array[Node3D] = []
	for marker: Node in get_tree().get_nodes_in_group("spawn_player"):
		if marker is Node3D and is_ancestor_of(marker):
			spawn_points.append(marker)
	if not spawn_points.is_empty():
		var spawn: Node3D = spawn_points.pick_random()
		spawn_transform = Transform3D(
			Basis.from_euler(spawn.global_rotation), spawn.global_position
		)
		print("[World] Player spawned at spawn point: ", spawn.global_position)
	else:
		# Fallback to map origin with slight Y offset for physics safety
		print("[World] Player spawned at fallback position: Vector3(0, 2, 0)")

	var world_node: Node = self
	player.transform = (
		(world_node as Node3D).global_transform.affine_inverse() * spawn_transform
		if world_node is Node3D
		else spawn_transform
	)
	add_child(player)

	# Register player with PlayerService for reconnect support
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.player:
		gs.player.register_player(peer_id)

	print("========== PLAYER SPAWN COMPLETE ==========")


func remove_player(peer_id: int) -> void:
	var player: Node = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()


func upnp_setup() -> void:
	var upnp: UPNP = UPNP.new()

	upnp.discover()
	upnp.add_port_mapping(PORT)

	var ip: String = upnp.query_external_address()
	if ip == "":
		_log("Failed to establish upnp connection!")
	else:
		_log("Success! Join Address: %s" % upnp.query_external_address())


## Spawn enemies at predefined positions (server only)


func spawn_enemies() -> void:
	if spawn_manager:
		spawn_manager.spawn_enemies()


## Public API for spawning single enemy (used by save/load system)


func spawn_enemy_at(
	pos: Vector3, enemy_id: String = "grunt_basic", is_aggressive: bool = false
) -> Node:
	if spawn_manager:
		return spawn_manager.spawn_enemy_at(pos, enemy_id, is_aggressive)
	return null


## Start stuck detection timer for enemies


func _start_stuck_detection() -> void:
	# Run immediate check after spawn (allow physics to settle first)
	get_tree().create_timer(0.5).timeout.connect(_check_enemies_stuck)

	# Then run periodic check every 3 seconds
	var timer := Timer.new()
	timer.name = "StuckDetectionTimer"
	timer.wait_time = 3.0
	timer.autostart = true
	timer.timeout.connect(_check_enemies_stuck)
	add_child(timer)


## Y threshold for out-of-bounds enemies (default, overridable by config)

## Check all enemies for being stuck or out-of-bounds and respawn them if needed


func _check_enemies_stuck() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var enemies_checked: int = 0
	var enemies_relocated: int = 0

	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy: CharacterBody3D = enemy_node as CharacterBody3D
		if not enemy or not is_instance_valid(enemy):
			continue

		# Skip dead enemies
		if "is_dead" in enemy and enemy.is_dead:
			continue

		# Skip fleeing enemies (they often corner themselves temporarily)
		if "is_fleeing" in enemy and enemy.is_fleeing:
			continue

		enemies_checked += 1

		# Check if out of bounds (fallen off map)
		if _is_enemy_out_of_bounds(enemy):
			var old_pos: Vector3 = enemy.global_position
			var new_pos: Vector3 = Vector3.ZERO + Vector3(randf_range(-3, 3), 1, randf_range(-3, 3))
			print(
				"[World] STUCK: '%s' OUT OF BOUNDS Y=%.1f -> %s" % [enemy.name, old_pos.y, new_pos]
			)
			enemy.global_position = new_pos
			enemy.velocity = Vector3.ZERO
			enemies_relocated += 1
			match_stats.enemies_out_of_bounds += 1
			match_stats.enemies_relocated += 1
			continue

		# Check if stuck (colliding with world on multiple sides)
		if _is_enemy_stuck(enemy):
			var old_pos: Vector3 = enemy.global_position
			var new_pos: Vector3 = old_pos + Vector3(randf_range(-5, 5), 2, randf_range(-5, 5))
			if new_pos != old_pos:
				_log("[World] STUCK: '%s' at %s -> %s" % [enemy.name, old_pos, new_pos])
				enemy.global_position = new_pos
				enemy.velocity = Vector3.ZERO
				enemies_relocated += 1
				match_stats.enemies_stuck += 1
				match_stats.enemies_relocated += 1

	if enemies_relocated > 0:
		_log("[World] Stuck check: %d/%d relocated" % [enemies_relocated, enemies_checked])


## Check if an enemy is out of bounds (fallen off map)


func _is_enemy_out_of_bounds(enemy: CharacterBody3D) -> bool:
	var threshold: float = DEFAULT_ENEMY_OUT_OF_BOUNDS_Y
	var cm: Node = GameManager.get_core_system("config")
	if cm:
		threshold = cm.get_value("game_rules.enemy_out_of_bounds_y", threshold)
	return enemy.global_position.y < threshold


## Check if an enemy is stuck inside geometry


func _is_enemy_stuck(enemy: CharacterBody3D) -> bool:
	var world_3d: World3D = get_viewport().world_3d
	if not world_3d:
		return false
	var space: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if not space:
		return false

	var pos: Vector3 = enemy.global_position + Vector3(0, 0.5, 0)
	var directions: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]

	var blocked_count: int = 0
	for dir in directions:
		var query := PhysicsRayQueryParameters3D.create(
			pos, pos + dir * 0.6, CollisionLayers.LAYER_WORLD, [enemy.get_rid()]
		)
		var result := space.intersect_ray(query)
		if result:
			blocked_count += 1

	# If blocked on ALL 4 sides, enemy is likely stuck inside geometry
	return blocked_count >= 4


func _set_mouse_filter_recursive(node: Node, filter: Control.MouseFilter) -> void:
	if node is Control:
		node.mouse_filter = filter

	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)


func _on_enemy_died_stats(_data: Dictionary) -> void:
	match_stats.enemies_killed += 1


func _on_weapon_fired_stats(_data: Dictionary) -> void:
	match_stats.shots_fired += 1


func _on_damage_dealt_stats(data: Dictionary) -> void:
	var amount: float = data.get("amount", 0.0)
	var target: Node = data.get("target", null)
	var source: Node = data.get("source", null)
	var source_id: int = data.get("source_id", 0)

	# Get local player to determine if we dealt or took damage
	var local_player: Node = null
	var local_peer_id: int = 1
	if multiplayer.has_multiplayer_peer():
		local_peer_id = multiplayer.get_unique_id()

	for p: Variant in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p) and p.is_multiplayer_authority():
			local_player = p
			break

	if local_player:
		# Check if WE dealt the damage:
		# 1. Direct source match (hitscan)
		# 2. source_id matches our peer_id (projectiles pass source_id)
		var we_dealt_damage: bool = false
		if source == local_player:
			we_dealt_damage = true
		elif source_id == local_peer_id:
			we_dealt_damage = true
		elif source_id > 0 and str(source_id) == local_player.name:
			we_dealt_damage = true

		if we_dealt_damage:
			match_stats.damage_dealt += amount
			match_stats.shots_hit += 1

		# We took the damage
		if target == local_player:
			match_stats.damage_taken += amount


func _on_critical_hit_stats(_data: Dictionary) -> void:
	match_stats.critical_hits += 1


func _on_item_collected_stats(_data: Dictionary) -> void:
	match_stats.items_collected += 1


# --- Intermission Screen ---
# NOTE: The actual IntermissionScreen is shown via UIManager in MatchService.end_match()
# We only subscribe to EventBus signals here to handle replay/harder/menu actions


func _setup_intermission_screen() -> void:
	# Subscribe to intermission action events (emitted by IntermissionScreen)
	GameManager.subscribe("intermission_replay", _on_intermission_replay_event)
	GameManager.subscribe("intermission_harder", _on_intermission_harder_event)
	GameManager.subscribe("intermission_main_menu", _on_intermission_main_menu_event)


func _on_intermission_replay_event(_data: Dictionary) -> void:
	_on_intermission_replay()


func _on_intermission_harder_event(_data: Dictionary) -> void:
	_on_intermission_harder()


func _on_intermission_main_menu_event(_data: Dictionary) -> void:
	_return_to_main_menu()


func _on_intermission_replay() -> void:
	# Clear existing enemies
	_cleanup_enemies()
	# Restart match
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		gs.match_service.replay_match()
	# Re-spawn enemies
	spawn_enemies()
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_intermission_harder() -> void:
	# Clear existing enemies
	_cleanup_enemies()
	# Start harder match
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		gs.match_service.start_harder_match()
	# Re-spawn enemies with higher difficulty
	spawn_enemies()
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var us := UISystem.get_service()
	if us and us.ui_manager and not us.ui_manager.has_open_modal():
		us.ui_manager.push_screen(PAUSE_SCREEN)


func _return_to_main_menu() -> void:
	# Return to main menu via UIService.ui_manager
	var us := UISystem.get_service()
	if us and us.ui_manager:
		us.ui_manager.clear_all()
		us.ui_manager.open_screen(MAIN_MENU_SCREEN)

	# Cleanup game state
	_cleanup_enemies()
	_cleanup_players()


func _cleanup_enemies() -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()


func _cleanup_players() -> void:
	for player: Node in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(player):
			player.queue_free()


func _bake_nav_mesh() -> void:
	var nav_region: NavigationRegion3D = get_node_or_null("NavigationRegion3D")
	if not nav_region:
		push_warning("NavigationRegion3D not found, skipping nav mesh bake")
		return

	# Check if runtime navigation mesh baking is enabled
	var enable_runtime_baking: bool = false  # Set to true to enable runtime baking

	if not enable_runtime_baking:
		# Skip navigation mesh baking if it's causing issues
		# Navigation mesh can be pre-baked in the editor instead
		_log("[World] Runtime navigation mesh baking disabled to prevent hanging")
		_log("[World] To enable: set enable_runtime_baking = true in _bake_nav_mesh()")
		_log("[World] Consider pre-baking navigation mesh in the editor for better performance")

		# Check if navigation mesh is already baked
		if nav_region.navigation_mesh and nav_region.navigation_mesh.get_vertices().size() > 0:
			_log("[World] Using pre-baked navigation mesh")
		else:
			_log("[World] No pre-baked navigation mesh found - AI pathfinding may be limited")
		return

	# Runtime baking code (only runs if enable_runtime_baking is true)
	var nav_mesh: NavigationMesh
	if not nav_region.navigation_mesh:
		_log("[World] NavigationMesh resource not set on NavigationRegion3D, creating default...")
		nav_region.navigation_mesh = NavigationMesh.new()

	nav_mesh = nav_region.navigation_mesh

	# Configure for performance (use static colliders - faster than visual mesh parsing)
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN

	# Agent parameters to match gameplay
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.75  # Aligned to cell_height (0.25 * 7)
	nav_mesh.agent_max_climb = 0.25  # Aligned to cell_height (0.25 * 1)
	nav_mesh.agent_max_slope = 45.0

	# Precision settings to reduce warnings
	nav_mesh.cell_height = 0.25  # Matches default project setting

	_log("Baking Navigation Mesh...")

	# Use a more robust baking approach
	call_deferred("_perform_nav_bake", nav_region)


func _perform_nav_bake(nav_region: NavigationRegion3D) -> void:
	## Perform the actual navigation mesh baking in a deferred call
	if not nav_region or not is_instance_valid(nav_region):
		_log("[World] NavigationRegion3D is no longer valid")
		return

	# Attempt to bake navigation mesh with error handling
	_log("[World] Starting navigation mesh baking...")
	nav_region.bake_navigation_mesh(false)  # false = on_main_thread
	_log("[World] Navigation mesh baking completed")


func _release_host_session() -> void:
	if _session_multiplayer:
		if _session_multiplayer.peer_disconnected.is_connected(remove_player):
			_session_multiplayer.peer_disconnected.disconnect(remove_player)
		if enet_peer and _session_multiplayer.multiplayer_peer == enet_peer:
			_session_multiplayer.multiplayer_peer = null
	if enet_peer:
		enet_peer.close()
		enet_peer = null
	_session_multiplayer = null


func _create_host_session(port: int, max_players: int) -> Error:
	var current_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	# NetworkManager and other callers may already own this MultiplayerAPI.
	# Never replace an active session, including a repeated request for our own.
	if (
		current_peer
		and not current_peer is OfflineMultiplayerPeer
		and current_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED
	):
		return ERR_ALREADY_IN_USE

	# NetworkManager.disconnect_game() may have closed and detached our peer.
	_release_host_session()
	in_game = false
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, max_players)
	if err != OK:
		peer.close()
		return err

	enet_peer = peer
	_session_multiplayer = multiplayer
	_session_multiplayer.multiplayer_peer = enet_peer
	if not _session_multiplayer.peer_disconnected.is_connected(remove_player):
		_session_multiplayer.peer_disconnected.connect(remove_player)
	in_game = true
	return OK


func _on_single_player_start_requested(slot_name: String) -> void:
	# Start a local game (listen server with configurable local players)
	# Create server with configurable max local players (default 4)
	var max_local: int = 4
	var cm: Node = GameManager.get_core_system("config")
	if cm:
		max_local = cm.get_value("network.singleplayer_max_local_players", 4)

	var err: Error = _create_host_session(PORT, max_local)
	if err != OK:
		push_error("[World] Failed to create solo server: %s" % error_string(err))
		return

	var globals: Node = GameManager.get_core_system("globals")
	if globals:
		globals.current_save_slot = slot_name

	# Server spawns itself
	var mode: String = "editor" if globals and globals.join_as_editor else "player"
	spawn_player_node(multiplayer.get_unique_id(), mode)

	# CRITICAL: Capture mouse for gameplay
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Defer enemy spawning to allow NavMesh baking to complete
	call_deferred("spawn_enemies")
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		gs.match_service.start_match()


func _on_host_requested(connection_settings: Dictionary, match_settings: Dictionary) -> void:
	_log("[World] Hosting game with settings: %s, %s" % [connection_settings, match_settings])

	# Start multiplayer server
	var port: int = connection_settings.get("port", PORT)
	var max_players: int = connection_settings.get("max_players", 8)
	var use_upnp: bool = connection_settings.get("use_upnp", false)

	var err: Error = _create_host_session(port, max_players)
	if err != OK:
		push_error("[World] Failed to create multiplayer server: %s" % error_string(err))
		return

	if use_upnp:
		upnp_setup()

	# Server spawns itself
	var globals: Node = GameManager.get_core_system("globals")
	var mode: String = "editor" if globals and globals.join_as_editor else "player"
	spawn_player_node(multiplayer.get_unique_id(), mode)

	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	spawn_enemies()
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		gs.match_service.start_match()


# --- Menu Navigation & Animations ---


func _animate_menu_transition(from_menu: Control, to_menu: Control) -> void:
	if not from_menu or not to_menu:
		return

	# Ensure to_menu is ready
	to_menu.visible = true
	to_menu.modulate.a = 0.0

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Fade out from_menu
	tween.tween_property(from_menu, "modulate:a", 0.0, 0.2)
	# Fade in to_menu
	tween.tween_property(to_menu, "modulate:a", 1.0, 0.3)

	# Cleanup after fade out
	tween.chain().tween_callback(from_menu.hide)
	tween.tween_callback(func() -> void: from_menu.modulate.a = 1.0)  # Reset visibility


func _on_host_menu_back() -> void:
	_log("[World] Host menu back pressed")
	var host_menu: Control = get_node_or_null("%HostGameMenu")
	var main_menu: Control = get_node_or_null("%MainMenu")
	_animate_menu_transition(host_menu, main_menu)


func _on_multiplayer_menu_back() -> void:
	_log("[World] Multiplayer menu back pressed")
	var mp_menu: Control = get_node_or_null("%MultiplayerMenu")
	var main_menu: Control = get_node_or_null("%MainMenu")
	_animate_menu_transition(mp_menu, main_menu)


func _on_save_menu_back() -> void:
	_log("[World] Save menu back pressed")
	var save_menu: Control = get_node_or_null("%SaveLoadMenu")
	var main_menu: Control = get_node_or_null("%MainMenu")
	_animate_menu_transition(save_menu, main_menu)


# Options Menu Connections


func _on_options_button_toggled(toggled_on: bool) -> void:
	var options_menu: Control = get_node_or_null("%Options")
	var main_menu: Control = get_node_or_null("%MainMenu")

	if toggled_on:
		# Show Options, Hide Main
		_animate_menu_transition(main_menu, options_menu)
	else:
		# Is this ever called by button toggle off?
		# Usually Back button handles the return.
		pass


func _on_back_pressed() -> void:
	# Called by Options Menu "Back" button
	var options_menu: Control = get_node_or_null("%Options")
	var main_menu: Control = get_node_or_null("%MainMenu")

	# Untoggle the main menu button if it exists
	var path: String = "MarginContainer/VBoxContainer/OptionsButton"
	var opt_btn: Button = main_menu.get_node_or_null(path) if main_menu else null
	if opt_btn:
		opt_btn.set_pressed_no_signal(false)

	_animate_menu_transition(options_menu, main_menu)


# Main Menu Button Handlers (that open submenus)


func _on_multiplayer_pressed() -> void:
	var mp_menu: Control = get_node_or_null("%MultiplayerMenu")
	var main_menu: Control = get_node_or_null("%MainMenu")
	_animate_menu_transition(main_menu, mp_menu)


func _on_single_player_pressed() -> void:
	# Ensure editor mode is OFF for normal play
	var globals: Node = GameManager.get_core_system("globals")
	if globals:
		globals.join_as_editor = false

	var save_menu: Control = get_node_or_null("%SaveLoadMenu")
	var main_menu: Control = get_node_or_null("%MainMenu")
	_animate_menu_transition(main_menu, save_menu)


func _on_host_pressed() -> void:
	# Called from Multiplayer Menu to go to Host Game Menu
	var mp_menu: Control = get_node_or_null("%MultiplayerMenu")
	var host_menu: Control = get_node_or_null("%HostGameMenu")
	_animate_menu_transition(mp_menu, host_menu)


func _on_editor_button_pressed() -> void:
	_log("[World] Editor Mode requested")
	var globals: Node = GameManager.get_core_system("globals")
	if globals:
		globals.join_as_editor = true

	# Transition to LOADING state
	if GameManager and GameManager.has_method("change_state"):
		GameManager.change_state(1)  # LOADING state

	# Switch to Showcase map
	var showcase_path: String = "res://game/world/maps/showcase.tscn"
	if ResourceLoader.exists(showcase_path):
		get_tree().change_scene_to_file(showcase_path)
	else:
		push_error("[World] Showcase map not found at: " + showcase_path)
		# Fallback to current scene if showcase missing
		get_tree().reload_current_scene()


func _show_welcome_screen() -> void:
	if not ResourceLoader.exists(WELCOME_SCREEN):
		return
	var screen: Control = load(WELCOME_SCREEN).instantiate()
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100  # Above everything
	canvas.name = "WelcomeLayer"
	canvas.add_child(screen)
	add_child(canvas)


func _spawn_showcase_signs() -> void:
	ShowcaseSignageScript.spawn_signs(self)
