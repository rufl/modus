extends GameComponent

signal state_changed(new_state: int)
signal respawned

const SPECTATOR_SCENE: PackedScene = preload("res://game/scenes/entities/spectator.tscn")
const RAGDOLL_SCENE: PackedScene = preload("res://game/entities/common/mannequin_ragdoll.tscn")
const BACKPACK_SCENE: PackedScene = preload("res://game/scenes/items/backpack.tscn")

var current_state: int = Enums.PlayerState.ALIVE
var respawn_time: float = 5.0

var _player: CharacterBody3D
var _health_component: HealthComponent
var _match_service: Node
var _godmode_mat: ShaderMaterial
var _invisible_mat: ShaderMaterial
var _spectator_instance: Node3D = null


func _init() -> void:
	_godmode_mat = ShaderMaterial.new()
	_godmode_mat.shader = load("res://game/art/shaders/godmode.gdshader")

	_invisible_mat = ShaderMaterial.new()
	_invisible_mat.shader = load("res://game/art/shaders/invisibility.gdshader")


func setup(player: CharacterBody3D, health_comp: HealthComponent, match_svc: Node) -> void:
	_player = player
	_health_component = health_comp
	_match_service = match_svc


func set_respawn_time(time: float) -> void:
	respawn_time = time


# Public State Transitions


func enter_downed() -> void:
	if current_state == Enums.PlayerState.DOWNED or current_state == Enums.PlayerState.DEAD:
		return

	current_state = Enums.PlayerState.DOWNED
	state_changed.emit(current_state)

	if _player.downed_handler:
		_player.downed_handler.enter_downed()

	if not _player.multiplayer.has_multiplayer_peer():
		_sync_downed_visuals(true)
	else:
		_sync_downed_visuals.rpc(true)


func revive() -> void:
	current_state = Enums.PlayerState.ALIVE
	state_changed.emit(current_state)

	if _health_component:
		_health_component.reset_death_state()
		# Restore 30% HP
		_health_component.current_health = _health_component.max_health * 0.3

	if not _player.multiplayer.has_multiplayer_peer():
		_sync_downed_visuals(false)
	else:
		_sync_downed_visuals.rpc(false)


func bleedout() -> void:
	# Transition from Downed to Dead
	_handle_death_penalty()
	_spawn_ragdoll()
	enter_dead()


func enter_dead() -> void:
	if current_state == Enums.PlayerState.DEAD:
		return
	current_state = Enums.PlayerState.DEAD
	state_changed.emit(current_state)

	# Enter Spectator Mode
	if _player.is_multiplayer_authority():
		_start_spectating()

		# Schedule respawn
		get_tree().create_timer(respawn_time).timeout.connect(_respawn_player)

	# Sync visuals (Hide player)
	_sync_death_visuals.rpc(true)

	if _match_service:
		# Notify match service
		if _player.is_multiplayer_authority():
			if _match_service.has_method("update_player_status"):
				if _player.multiplayer.has_multiplayer_peer():
					_match_service.update_player_status.rpc(0, Enums.PlayerState.DEAD)
				else:
					_match_service.update_player_status(0, Enums.PlayerState.DEAD)


# Visual Effects


func set_godmode_visuals(enabled: bool) -> void:
	if not _player:
		return

	var mesh: MeshInstance3D = _player.get_node_or_null("MeshInstance3D")
	if not mesh:
		return

	if enabled:
		mesh.material_overlay = _godmode_mat
	else:
		if mesh.material_overlay == _godmode_mat:
			mesh.material_overlay = null


func set_invisible_visuals(enabled: bool) -> void:
	if not _player:
		return

	var mesh: MeshInstance3D = _player.get_node_or_null("MeshInstance3D")
	if not mesh:
		return

	if enabled:
		# Initial simple approach: Set material override to invisibility
		# Note: This replaces the regular texture. If we want partial transparency
		# while keeping textures, we need a more complex shader setup.
		# For "Invisibility" powerup, fully replacing with a distortion shader is often desired.
		mesh.material_override = _invisible_mat
		_sync_invisible_visuals.rpc(true)
	else:
		if mesh.material_override == _invisible_mat:
			mesh.material_override = null
		_sync_invisible_visuals.rpc(false)


# Internal Logic


func _handle_death_penalty() -> void:
	# 1. XP Penalty
	var xp_to_backpack: int = 0
	if _player.progression:
		var deducted: int = _player.progression.deduct_xp(0.10)
		xp_to_backpack = int(deducted * 0.5)

	# 2. Drop Backpack (Authority Only)
	if not _player.multiplayer.has_multiplayer_peer() or _player.multiplayer.is_server():
		var my_id: int = _player.name.to_int()
		var gs := GameManager.get_core_system("gameplay") as GameplaySvc
		var inv: Inventory = gs.inventory.get_inventory(my_id) if gs and gs.inventory else null

		if inv:
			_spawn_backpack(my_id, inv, xp_to_backpack)
			# Clear inventory on death
			if gs and gs.inventory:
				gs.inventory.clear_inventory(my_id)

			if _player.weapon_manager:
				_player.weapon_manager.refill_ammo()

	# 3. Reset persistent states
	_player.has_double_jump = false
	_player.has_dodge = false


func _spawn_backpack(player_id: int, inv: Inventory, xp: int) -> void:
	var backpack: Node3D = BACKPACK_SCENE.instantiate()
	var tree := _player.get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if scene_root:
		scene_root.add_child(backpack)
		backpack.global_position = _player.global_position + Vector3(0, 0.5, 0)
	else:
		backpack.queue_free()
		return

	var uuid: String = ""
	var p_name: String = "Unknown"

	# Try to get player data
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.player_service:
		var data: Dictionary = gs.player_service.get_player_data(player_id)
		uuid = data.get("uuid", "")
		p_name = data.get("name", "Unknown")

	backpack.setup(uuid, player_id, p_name, inv.to_dict(), xp)


func _spawn_ragdoll() -> void:
	var death_force: float = 10.0
	var hit_dir: Vector3 = _player.last_hit_dir
	_sync_spawn_ragdoll.rpc(hit_dir, death_force)


func _start_spectating() -> void:
	var spectator: Node3D = SPECTATOR_SCENE.instantiate()
	var tree := _player.get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if scene_root:
		scene_root.add_child(spectator)
		spectator.global_transform = _player.camera.global_transform
	else:
		spectator.queue_free()
		return
	_spectator_instance = spectator


func _respawn_player() -> void:
	current_state = Enums.PlayerState.ALIVE
	state_changed.emit(current_state)

	# IMPORTANT: Restore player controls BEFORE freeing spectator
	# to prevent camera being lost during the transition
	if _player.input_component and _player.input_component.has_method("set_mouse_captured"):
		_player.input_component.set_mouse_captured(true)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _player.camera:
		_player.camera.current = true

	# Now safe to free spectator
	if is_instance_valid(_spectator_instance):
		_spectator_instance.queue_free()
		_spectator_instance = null

	_sync_death_visuals.rpc(false)

	if _health_component:
		_health_component.reset_death_state()
		_health_component.current_health = _health_component.max_health

	if _player.weapon_manager:
		_player.weapon_manager.refill_ammo()
		_player.weapon_manager.switch_to_weapon(0)

	# Find spawn point (group prioritized)
	var spawn_points := get_tree().get_nodes_in_group("player_spawn")
	if not spawn_points.is_empty():
		var spawn: Node3D = spawn_points.pick_random()
		_player.global_position = spawn.global_position
		_player.global_rotation = spawn.global_rotation
	elif not _player.spawns.is_empty():
		_player.position = _player.spawns[randi() % _player.spawns.size()]
	else:
		_player.position = Vector3(0, 2, 0)  # Fallback

	_player.velocity = Vector3.ZERO

	respawned.emit()

	# Notify Match Service
	if _match_service:
		var hp: float = _health_component.current_health if _health_component else 100.0
		if _player.is_multiplayer_authority():
			if _match_service.has_method("update_player_status"):
				if _player.multiplayer.has_multiplayer_peer():
					_match_service.update_player_status.rpc(hp, Enums.PlayerState.ALIVE)
				else:
					_match_service.update_player_status(hp, Enums.PlayerState.ALIVE)


# RPCs

@rpc("authority", "call_local", "reliable")
func _sync_spawn_ragdoll(impact_dir: Vector3, force: float) -> void:
	if not RAGDOLL_SCENE:
		return

	var corpse: Node3D = RAGDOLL_SCENE.instantiate()
	corpse.position = _player.global_position
	corpse.rotation = _player.global_rotation

	# Add to scene root usually
	var p_parent: Node = _player.get_parent()
	if p_parent:
		p_parent.add_child(corpse)
	else:
		var tree := _player.get_tree()
		var scene_root: Node = tree.current_scene if tree else null
		if not scene_root and tree:
			scene_root = tree.root

		if scene_root:
			scene_root.add_child(corpse)
		else:
			corpse.queue_free()
			return

	if corpse.has_method("setup"):
		corpse.call_deferred("setup", null, _player.global_transform, Color(0.2, 0.8, 0.2))

	var impulse_strength: float = force * 3.0
	var final_impulse: Vector3 = (impact_dir + Vector3(0, 0.3, 0)).normalized() * impulse_strength

	if corpse.has_method("apply_central_impulse"):
		corpse.call_deferred("apply_central_impulse", final_impulse)
		corpse.call_deferred("apply_torque_impulse", Vector3.ONE * 2.0)


@rpc("call_local", "reliable")
func _sync_death_visuals(is_dead: bool) -> void:
	if not _player:
		return

	var col: CollisionShape3D = _player.get_node_or_null("CollisionShape3D")
	if col:
		col.disabled = is_dead

	_player.visible = !is_dead

	if not is_dead and _player.camera:
		_player.camera.position = Vector3(0, _player.standing_camera_height, 0)
		# Only reset pitch (X rotation), not the entire rotation
		_player.camera.rotation.x = 0


@rpc("call_local")
func _sync_invisible_visuals(invisible: bool) -> void:
	if not _player:
		return
	var mesh: MeshInstance3D = _player.get_node_or_null("MeshInstance3D")
	if not mesh:
		return

	if invisible:
		mesh.material_override = _invisible_mat
		# also hide weapon locally if desired, or make it transparent
	else:
		if mesh.material_override == _invisible_mat:
			mesh.material_override = null


@rpc("call_local")
func _sync_downed_visuals(downed: bool) -> void:
	if not _player:
		return

	# Access Player Visuals
	var capsule_mesh: Node3D = _player.get_node_or_null("MeshInstance3D")
	var visuals_node: Node3D = _player.get_node_or_null("PlayerVisuals")
	var cam: Camera3D = _player.camera

	if downed:
		# Camera Gears Style
		if cam:
			cam.position = Vector3(0, 2.0, 2.5)
			cam.rotation.x = deg_to_rad(-30)

		if _player.weapon_holder:
			_player.weapon_holder.visible = false

		if capsule_mesh:
			capsule_mesh.visible = false
		if visuals_node:
			visuals_node.visible = true
			if visuals_node.has_method("play_animation"):
				visuals_node.play_animation("Crawl_Idle")
	else:
		if current_state != Enums.PlayerState.DEAD:
			if cam:
				cam.position = Vector3(0, _player.standing_camera_height, 0)
				cam.rotation.x = 0

			if _player.weapon_holder:
				_player.weapon_holder.visible = true

			if capsule_mesh:
				capsule_mesh.visible = true
			if visuals_node:
				visuals_node.visible = false
