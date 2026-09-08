class_name MatchSvc
extends "res://game/core/game_service.gd"

signal match_state_changed(new_state: MatchState)
signal match_timer_updated(time_left: float)
signal match_started(settings: Dictionary)
signal match_ended(winner_id: int)
signal scores_updated
signal kill_feed_updated
signal player_killed(killer_id: int, victim_id: int)
signal debug_vision_toggled(enabled: bool)

enum MatchState { WAITING, WARMUP, PLAYING, PAUSED, ENDED }

var current_match_state: MatchState = MatchState.WAITING
var time_left: float = 0.0
var match_time_limit: float = 600.0  # From config
var auto_restart_delay: float = 10.0
var frag_limit: int = 25
var respawn_time: float = 5.0
var friendly_fire: bool = false
var player_scores: Dictionary = {}  # peer_id -> {kills, deaths, score, state, health}
var kill_feed: Array[Dictionary] = []
var max_kill_feed_entries: int = 5
var kill_feed_duration: float = 5.0
var godmode: bool = false
var flymode: bool = false
var noclip: bool = false
var debug_vision_enabled: bool = false
var _match_timer_active: bool = false
var _periodic_state_broadcast_timer: float = 0.0
var _periodic_state_broadcast_interval: float = 2.0  # Broadcast state every 2 seconds

# FIXED C-05: Store timer reference for proper cleanup
var _auto_restart_timer: SceneTreeTimer = null


## Helper method for safe logging
func _log_info(message: String) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Variant = gm.get_core_system("logger") if gm else null
	if logger and logger.has_method("info"):
		logger.info(message, "Match")
	else:
		print(message)


static func get_instance() -> MatchSvc:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return null

	# Try multiple paths to find the match service
	var paths: Array[String] = [
		"GameManager", "/root/GameManager", "GameplaySvc", "/root/GameplaySvc"
	]

	for path: String in paths:
		var node: Node = tree.root.get_node_or_null(path)
		if node:
			# Try to get match service from GameCore
			if node.has_method("get_service"):
				var gameplay: Node = node.get_service("gameplay")
				if gameplay and "match_service" in gameplay:
					return gameplay.match_service as MatchSvc

			# Try to get match service directly from GameplaySvc
			if "match_service" in node:
				return node.match_service as MatchSvc

	# Fallback: Look for any MatchSvc node in the tree
	var match_nodes: Array[Node] = tree.get_nodes_in_group("match_service")
	if not match_nodes.is_empty():
		return match_nodes[0] as MatchSvc

	# Last resort: Create a temporary instance for testing
	if OS.has_feature("debug"):
		var instance: MatchSvc = MatchSvc.new()
		instance.name = "MatchService_Test"
		tree.root.add_child(instance)
		return instance

	return null


## MatchService - Consolidated match, score, and game rules management
##
## Merges functionality from:
## - GameManager (game rules, debug modes)
## - MatchManager (match lifecycle, timer)
## - ScoreManager (scoring, kill feed) - INTEGRATED
##
## Provides centralized match state management with EventBus integration.

# Service preloads to resolve lints

# No more DifficultyMgr preload - use service if needed

# === SIGNALS ===

# Debug signals

# === ENUMS ===

# === MATCH STATE ===

# === MATCH SETTINGS ===

# === SCORING ===

# === DEBUG MODES ===


func _ready() -> void:
	name = "MatchService"
	add_to_group("match_service")

	# Allow debug keys to work even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect multiplayer signals
	if multiplayer:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Setup input for debug modes
	set_process_input(true)


func _exit_tree() -> void:
	# === SIGNAL HYGIENE: Disconnect all signals to prevent memory leaks ===
	# 1. Multiplayer signals
	if multiplayer:
		if multiplayer.peer_connected.is_connected(_on_peer_connected):
			multiplayer.peer_connected.disconnect(_on_peer_connected)
		if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
			multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)

	# 2. EventBus subscriptions
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.unsubscribe("player_died", _on_player_died_event)
		gm.unsubscribe("player_spawned", _on_player_spawned_event)
		gm.unsubscribe("damage_dealt", _on_damage_dealt_event)
		gm.unsubscribe("item_picked_up", _on_item_picked_up_event)
		gm.unsubscribe("xp_gained", _on_xp_gained_event)

	# 3. FIXED C-05: Cleanup timer connections
	if _auto_restart_timer and _auto_restart_timer.timeout.is_connected(_on_auto_restart_timeout):
		_auto_restart_timer.timeout.disconnect(_on_auto_restart_timeout)
		_auto_restart_timer = null


func get_init_priority() -> int:
	return 50  # After config (10), network (20), before gameplay (100)


func get_dependencies() -> Array[String]:
	return ["config", "network"]


func initialize() -> void:
	await _wait_for_dependencies()

	# Load settings from config
	match_time_limit = get_config("game_rules.match_time_limit", 600.0)
	frag_limit = int(get_config("game_rules.frag_limit", 25))
	respawn_time = get_config("game_rules.respawn_time", 5.0)
	friendly_fire = get_config("game_rules.friendly_fire", false)
	auto_restart_delay = get_config("game_rules.warmup_time", 10.0)

	max_kill_feed_entries = int(get_config("visuals.hud.kill_feed.max_entries", 5))
	kill_feed_duration = get_config("visuals.hud.kill_feed.duration", 5.0)

	# Subscribe to events
	subscribe_event("player_died", _on_player_died_event)
	subscribe_event("player_spawned", _on_player_spawned_event)
	subscribe_event("damage_dealt", _on_damage_dealt_event)
	subscribe_event("item_picked_up", _on_item_picked_up_event)
	subscribe_event("xp_gained", _on_xp_gained_event)

	# Auto-start if server or singleplayer
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		# Optional: Auto-start or wait for command
		pass

	_mark_initialized()
	_log_info(
		"[Match] Initialized - Time limit: %ds, Frag limit: %d" % [match_time_limit, frag_limit]
	)


func _process(delta: float) -> void:
	# Match timer
	if _match_timer_active and current_match_state == MatchState.PLAYING:
		time_left -= delta
		if time_left <= 0:
			time_left = 0
			end_match()

		match_timer_updated.emit(time_left)

	# Periodic state broadcast for proper state detection by peers
	_periodic_state_broadcast_timer += delta
	if _periodic_state_broadcast_timer >= _periodic_state_broadcast_interval:
		_periodic_state_broadcast_timer = 0.0
		_broadcast_all_player_states()

	# Check frag limit
	# Check frag limit removed (duplicate)
	var is_auth: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if current_match_state == MatchState.PLAYING and is_auth:
		_check_frag_limit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				toggle_godmode()
			KEY_F2:
				toggle_flymode()
			KEY_F3:
				toggle_noclip()
			KEY_F5:
				toggle_debug_vision()
			KEY_F11:
				toggle_fullscreen()
			KEY_F12:
				take_screenshot()


# === MATCH LIFECYCLE ===

## Replay the current match


func replay_match() -> void:
	start_match()


## Start match with increased difficulty


func start_harder_match() -> void:
	# Increase difficulty logic
	var gm: Node = get_node_or_null("/root/GameManager")
	var gs := gm.get_core_system("gameplay") as GameplaySvc if gm else null
	if gs and gs.difficulty:
		var current: int = gs.difficulty.base_difficulty
		if current < DifficultyMgr.DifficultyLevel.NIGHTMARE:
			gs.difficulty.set_difficulty(current + 1)

	start_match()


## Start a new match

@rpc("authority", "call_local", "reliable")
func start_match(settings: Dictionary = {}) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Apply settings (use provided or defaults)
	match_time_limit = settings.get("time_limit", match_time_limit)
	frag_limit = settings.get("frag_limit", frag_limit)

	# Reset state
	current_match_state = MatchState.PLAYING
	time_left = match_time_limit
	_match_timer_active = match_time_limit > 0  # 0 = no time limit (free roam)
	get_tree().paused = false  # Ensure game is unpaused

	# Reset scores
	for peer_id: int in player_scores.keys():
		player_scores[peer_id].kills = 0
		player_scores[peer_id].deaths = 0
		player_scores[peer_id].score = 0

	# Emit signals
	match_state_changed.emit(current_match_state)
	match_started.emit(settings)
	scores_updated.emit()

	# Emit event
	emit_event("match_started", settings)

	# Notify MissionManager if available
	var gm: Node = get_node_or_null("/root/GameManager")
	var gs := gm.get_core_system("gameplay") as GameplaySvc if gm else null
	if gs and gs.mission:
		gs.mission.handle_match_started(settings)

	# Broadcast to clients
	if not multiplayer.has_multiplayer_peer():
		# Singleplayer: No broadcast, but logic is already local
		pass
	elif multiplayer:
		_sync_match_state.rpc(current_match_state, time_left)

	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger:
		logger.info(
			"[Match] Match started - Time: %ds, Frag limit: %d" % [match_time_limit, frag_limit],
			"Match"
		)


## End the current match

@rpc("authority", "call_local", "reliable")
func end_match(winner_id: int = -1) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	current_match_state = MatchState.ENDED
	_match_timer_active = false

	# Emit signals
	match_state_changed.emit(current_match_state)
	match_ended.emit(winner_id)

	# Emit event
	emit_event("match_ended", {"winner_id": winner_id})

	# Broadcast to clients
	if not multiplayer.has_multiplayer_peer():
		pass
	elif multiplayer:
		_sync_match_state.rpc(current_match_state, 0.0)

	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger:
		logger.info(
			(
				"[Match] Match ended - Winner: %s"
				% (get_player_name(winner_id) if winner_id >= 0 else "None")
			),
			"Match"
		)

	# Trigger Intermission Screen via UIService.ui_manager
	# Trigger Intermission Screen via UIService.ui_manager
	# We delay the pause slightly to allow final death effects/gibs to spawn and replicate
	# This prevents "ready signal not emitted" crashes from MultiplayerSpawner being interrupted
	await get_tree().create_timer(1.2).timeout

	# Pause game to stop physics/AI
	get_tree().paused = true
	# We can use the push_screen method if available
	var us := UISystem.get_service()
	if us and us.ui_manager:
		# Assuming intermission screen is registered or we push by path/scene
		# For now, let's assume register_screen usage or direct push
		# If previously: UIManager.open_screen(INTERMISSION_SCREEN)
		# Check if transitioning
		if us.ui_manager.has_method("is_transitioning") and us.ui_manager.is_transitioning():
			# Wait for transition
			await us.ui_manager.transition_finished

		var stats: Dictionary = _compile_final_stats(winner_id)
		us.ui_manager.open_screen("res://game/ui/menus/intermission_screen.tscn", {"stats": stats})
	else:
		push_warning("[Match] UIManager not found in UIService, cannot show intermission")
		# FIXED C-05: Store timer reference and use named method
		_auto_restart_timer = get_tree().create_timer(auto_restart_delay)
		_auto_restart_timer.timeout.connect(_on_auto_restart_timeout)


func _on_auto_restart_timeout() -> void:
	## Called when auto-restart timer completes
	start_match()


## Compile stats for intermission


func _compile_final_stats(winner_id: int) -> Dictionary:
	var local_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var target_id: int = local_id

	# Get world match_stats for enemy kill count (tracked separately from PvP kills)
	var world_stats: Dictionary = {}
	var world: Node = get_tree().root.get_node_or_null("World")
	if world and "match_stats" in world:
		world_stats = world.match_stats

	# If spectator, show winner stats? Or local player stats?
	if player_scores.has(target_id):
		var s: Dictionary = player_scores[target_id]
		# Add some derived stats
		var shots: int = s.get("shots_fired", 0)
		var hits: int = s.get("shots_hit", 0)
		var acc: float = 0.0
		if shots > 0:
			acc = (float(hits) / float(shots)) * 100.0

		var stats: Dictionary = s.duplicate()
		stats["accuracy"] = acc if not is_nan(acc) else 0.0
		stats["winner"] = (winner_id == target_id)
		# Map for Intermission Screen - use world.match_stats for enemy kills
		stats["enemies_killed"] = world_stats.get("enemies_killed", 0)
		stats["damage_dealt"] = world_stats.get("damage_dealt", s.get("damage_dealt", 0))
		stats["damage_taken"] = world_stats.get("damage_taken", s.get("damage_taken", 0))
		stats["critical_hits"] = world_stats.get("critical_hits", s.get("critical_hits", 0))
		stats["items_collected"] = world_stats.get("items_collected", s.get("items_collected", 0))
		stats["shots_fired"] = world_stats.get("shots_fired", s.get("shots_fired", 0))
		stats["shots_hit"] = world_stats.get("shots_hit", s.get("shots_hit", 0))
		stats["xp_earned"] = s.get("xp_earned", 0)
		return stats

	# Fallback: Return world stats or empty stats to prevent UI crashes
	return {
		"kills": 0,
		"deaths": 0,
		"score": 0,
		"accuracy": 0.0,
		"winner": false,
		"enemies_killed": world_stats.get("enemies_killed", 0),
		"damage_dealt": world_stats.get("damage_dealt", 0),
		"damage_taken": world_stats.get("damage_taken", 0),
		"critical_hits": world_stats.get("critical_hits", 0),
		"items_collected": world_stats.get("items_collected", 0),
		"shots_fired": world_stats.get("shots_fired", 0),
		"shots_hit": world_stats.get("shots_hit", 0),
		"xp_earned": 0
	}


## Sync match state to clients

@rpc("authority", "call_remote", "reliable")
func _sync_match_state(state: MatchState, time: float) -> void:
	current_match_state = state
	time_left = time
	_match_timer_active = (state == MatchState.PLAYING)
	match_state_changed.emit(current_match_state)


## Check if frag limit reached


func _check_frag_limit() -> void:
	if frag_limit <= 0:
		return  # No frag limit

	for peer_id: int in player_scores.keys():
		if player_scores[peer_id].kills >= frag_limit:
			end_match(peer_id)
			return


# === SCORING ===

## Initialize player score


func init_player_score(peer_id: int) -> void:
	player_scores[peer_id] = {
		"kills": 0,
		"deaths": 0,
		"score": 0,
		"state": Enums.PlayerState.ALIVE,
		"health": 100,
		"shots_fired": 0,
		"shots_hit": 0,
		"damage_dealt": 0.0,
		"damage_taken": 0.0,
		"critical_hits": 0,
		"items_collected": 0,
		"xp_earned": 0
	}

	scores_updated.emit()


## Get player score


func get_player_score(peer_id: int) -> Dictionary:
	if player_scores.has(peer_id):
		return player_scores[peer_id]
	return {}


## Remove player score (for cleanup)


func remove_player_score(peer_id: int) -> void:
	if player_scores.has(peer_id):
		player_scores.erase(peer_id)
		scores_updated.emit()


## Register a kill (Server Authority)

@rpc("any_peer", "call_local", "reliable")
func register_kill(killer_id: int, victim_id: int, damage_source: String = "") -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Validate RPC
	var sender_id: int = multiplayer.get_remote_sender_id()

	# RPC Rate Limiting Validation
	var gm: Node = get_node_or_null("/root/GameManager")
	var network_mgr: Node = gm.get_core_system("network") if gm else null
	if network_mgr and network_mgr.has_method("validate_rpc"):
		var args: Array = [killer_id, victim_id, damage_source]
		if not network_mgr.validate_rpc(sender_id, "register_kill", args):
			push_warning("[Match] Rate limit exceeded for peer %d" % sender_id)
			return

	# sender_id=0 is valid for local server calls (event handlers)
	if sender_id != 0 and sender_id != 1 and sender_id != killer_id and sender_id != victim_id:
		push_warning("[Match] Invalid kill report from peer %d" % sender_id)
		return

	# Init scores if needed
	if not player_scores.has(victim_id):
		init_player_score(victim_id)
	if not player_scores.has(killer_id):
		init_player_score(killer_id)

	# Update stats
	var is_valid_kill: bool = (
		killer_id != victim_id and killer_id != 0 and player_scores.has(killer_id)
	)

	if is_valid_kill:
		player_scores[killer_id].kills += 1
		player_scores[killer_id].score += 100

	player_scores[victim_id].deaths += 1
	player_scores[victim_id].state = Enums.PlayerState.DEAD

	# Broadcast
	# Broadcast
	var k_kills: int = player_scores[killer_id].kills if is_valid_kill else 0

	if not multiplayer.has_multiplayer_peer():
		_broadcast_kill(
			killer_id, victim_id, k_kills, player_scores[victim_id].deaths, damage_source
		)
	else:
		_broadcast_kill.rpc(
			killer_id, victim_id, k_kills, player_scores[victim_id].deaths, damage_source
		)

	# Generate funny message
	var victim_name: String = get_player_name(victim_id)
	var killer_name: String = get_player_name(killer_id)
	if get_tree().root.has_node("DeathMessageGenerator"):
		var dmg: Node = get_tree().root.get_node("DeathMessageGenerator")
		var message: String = dmg.generate_message(victim_name, killer_name, damage_source)

		_log_info("[Match] " + message)


## Register a shot fired (for accuracy stats)


func register_shot_fired(peer_id: int) -> void:
	if not player_scores.has(peer_id):
		init_player_score(peer_id)

	var s: Dictionary = player_scores[peer_id]
	if not s.has("shots_fired"):
		s["shots_fired"] = 0
	s["shots_fired"] += 1


## Register a shot hit (for accuracy stats)


func register_shot_hit(peer_id: int) -> void:
	if not player_scores.has(peer_id):
		init_player_score(peer_id)

	var s: Dictionary = player_scores[peer_id]
	if not s.has("shots_hit"):
		s["shots_hit"] = 0
	s["shots_hit"] += 1


## Broadcast kill to all clients

@rpc("authority", "call_local", "reliable")
func _broadcast_kill(
	killer_id: int, victim_id: int, k_kills: int, v_deaths: int, weapon_id: String = ""
) -> void:
	# Update local cache
	if player_scores.has(killer_id):
		player_scores[killer_id].kills = k_kills

	if not player_scores.has(victim_id):
		init_player_score(victim_id)
	player_scores[victim_id].deaths = v_deaths

	# Add to unified kill feed
	add_kill_feed_entry(killer_id, victim_id, weapon_id)

	# Emit signals
	kill_feed_updated.emit()
	scores_updated.emit()
	player_killed.emit(killer_id, victim_id)


## Update player status (health, state)

@rpc("any_peer", "call_local", "reliable")
func update_player_status(peer_id: int, health: int, state: int) -> void:
	# Requests are handled only by the server; clients receive the authority-only broadcast.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	if peer_id <= 0 or (sender_id != 0 and sender_id != peer_id):
		push_warning("Peer %d tried to update status for %d - denied" % [sender_id, peer_id])
		return

	# RPC Rate Limiting Validation
	var gm: Node = get_node_or_null("/root/GameManager")
	var network_mgr: Node = gm.get_core_system("network") if gm else null
	if sender_id != 0 and network_mgr and network_mgr.has_method("validate_rpc"):
		if not network_mgr.validate_rpc(
			sender_id, "update_player_status", [peer_id, health, state]
		):
			push_warning("[Match] Rate limit exceeded for peer %d" % sender_id)
			return

	_update_local_player_status(peer_id, health, state)

	# Server Authority: Broadcast to everyone else
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_broadcast_player_status.rpc(peer_id, health, state)


func _update_local_player_status(peer_id: int, health: int, state: int) -> void:
	if not player_scores.has(peer_id):
		init_player_score(peer_id)

	player_scores[peer_id].health = health
	player_scores[peer_id].state = state
	scores_updated.emit()


@rpc("authority", "call_remote", "reliable")
func _broadcast_player_status(peer_id: int, health: int, state: int) -> void:
	_update_local_player_status(peer_id, health, state)


## Get player name


func get_player_name(peer_id: int) -> String:
	# 1. Try PlayerService (Persistent Data)
	var ps := PlayerSvc.get_instance()
	if ps:
		var data: Dictionary = ps.get_player_data(peer_id)
		if data.has("name") and not str(data["name"]).is_empty():
			return data["name"]

	# 2. Try Local Config (Self)
	if multiplayer and peer_id == multiplayer.get_unique_id():
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm and gm.get_core_system("config"):
			var cfg: Node = gm.get_core_system("config")
			var custom_name: String = cfg.get_value("gameplay.player_name", "")
			if not custom_name.is_empty():
				return custom_name

	# 3. Fallback
	if player_scores.has(peer_id):
		return "Player%d" % peer_id
	if peer_id == 0:
		return "Environment"
	return "Enemy"


## Get sorted scores (for scoreboard)


func get_sorted_scores() -> Array[Dictionary]:
	var sorted: Array[Dictionary] = []
	for peer_id: int in player_scores.keys():
		sorted.append(
			{
				"peer_id": peer_id,
				"name": get_player_name(peer_id),
				"kills": player_scores[peer_id].kills,
				"deaths": player_scores[peer_id].deaths,
				"score": player_scores[peer_id].score,
				"health": player_scores[peer_id].health,
				"state": player_scores[peer_id].state
			}
		)

	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.kills > b.kills)

	return sorted


## Reset all scores


func reset_scores() -> void:
	player_scores.clear()
	kill_feed.clear()
	# No sync needed
	scores_updated.emit()
	kill_feed_updated.emit()


# === EVENT HANDLERS ===


func _on_peer_connected(peer_id: int) -> void:
	if not player_scores.has(peer_id):
		init_player_score(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if player_scores.has(peer_id):
		# Was OFFLINE, closest map is AFK or drop?
		player_scores[peer_id].state = Enums.PlayerState.AFK
		scores_updated.emit()


func _on_player_died_event(data: Dictionary) -> void:
	var peer_id: int = data.get("peer_id", -1)
	var killer_id: int = data.get("killer_id", 0)
	var weapon_id: String = data.get("weapon_id", "")

	if peer_id >= 0:
		register_kill(killer_id, peer_id, weapon_id)


func _on_player_spawned_event(data: Dictionary) -> void:
	var peer_id: int = data.get("peer_id", -1)

	if peer_id >= 0 and player_scores.has(peer_id):
		player_scores[peer_id].state = Enums.PlayerState.ALIVE
		scores_updated.emit()


func _on_damage_dealt_event(data: Dictionary) -> void:
	var amount: float = data.get("amount", 0.0)
	var is_crit: bool = data.get("is_critical", false)
	var source: Node = data.get("source")
	var source_id: int = data.get("source_id", 0)
	var target: Node = data.get("target")

	# Handle Damage Dealt - check both direct source and source_id for projectiles
	var dealer_pid: int = -1

	# Try to get peer_id from source node (hitscan)
	if source and source.is_in_group("player"):
		dealer_pid = _get_peer_id_from_node(source)
	# Fallback to source_id (projectiles pass this)
	elif source_id > 0:
		dealer_pid = source_id

	if dealer_pid != -1:
		if not player_scores.has(dealer_pid):
			init_player_score(dealer_pid)
		var current_damage: float = player_scores[dealer_pid].get("damage_dealt", 0.0)
		var add_damage: float = amount if not is_nan(amount) else 0.0
		player_scores[dealer_pid].damage_dealt = current_damage + add_damage
		if is_crit:
			player_scores[dealer_pid].critical_hits = (
				player_scores[dealer_pid].get("critical_hits", 0) + 1
			)

	# Handle Damage Taken
	if target and target.is_in_group("player"):
		var pid: int = _get_peer_id_from_node(target)
		if pid != -1:
			if not player_scores.has(pid):
				init_player_score(pid)
			var current_dmg: float = player_scores[pid].get("damage_taken", 0.0)
			player_scores[pid].damage_taken = current_dmg + (amount if not is_nan(amount) else 0.0)


func _on_item_picked_up_event(data: Dictionary) -> void:
	var peer_id: int = data.get("peer_id", -1)
	if peer_id >= 0:
		if not player_scores.has(peer_id):
			init_player_score(peer_id)
		player_scores[peer_id].items_collected = (
			player_scores[peer_id].get("items_collected", 0) + 1
		)


func _on_xp_gained_event(data: Dictionary) -> void:
	var peer_id: int = data.get("peer_id", -1)
	var amount: int = data.get("amount", 0)
	if peer_id >= 0 and amount > 0:
		if not player_scores.has(peer_id):
			init_player_score(peer_id)
		player_scores[peer_id].xp_earned = player_scores[peer_id].get("xp_earned", 0) + amount


func _get_peer_id_from_node(node: Node) -> int:
	if not node:
		return -1
	# Removed impossible check for MultiplayerPeer logic

	# Try authority
	if node.has_method("get_multiplayer_authority"):
		return node.get_multiplayer_authority()

	# Try name parsing if numeric
	if node.name.is_valid_int():
		return node.name.to_int()

	return -1


# === DEBUG MODES ===


func toggle_godmode() -> void:
	godmode = not godmode
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	var status: String = "ENABLED" if godmode else "DISABLED"
	if logger:
		logger.info("[Match] GODMODE: %s" % status, "Match")

	# Apply to local player
	var players: Array = get_tree().get_nodes_in_group("player")
	for player: Node in players:
		if player.is_multiplayer_authority():
			if "invincible" in player:
				player.invincible = godmode
			break


func toggle_flymode() -> void:
	flymode = not flymode
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	var status: String = "ENABLED" if flymode else "DISABLED"
	if logger:
		logger.info("[Match] FLYMODE: %s" % status, "Match")

	var players: Array = get_tree().get_nodes_in_group("player")
	for player: Node in players:
		if player.is_multiplayer_authority():
			if "can_fly" in player:
				player.can_fly = flymode
			break


func toggle_noclip() -> void:
	noclip = not noclip
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	var status: String = "ENABLED" if noclip else "DISABLED"
	if logger:
		logger.info("[Match] NOCLIP: %s" % status, "Match")

	# Noclip enables both flying and wall clipping
	if noclip and not flymode:
		toggle_flymode()

	var players: Array = get_tree().get_nodes_in_group("player")
	for player: Node in players:
		if player.is_multiplayer_authority():
			if "noclip" in player:
				player.noclip = noclip
			break


func toggle_debug_vision() -> void:
	debug_vision_enabled = not debug_vision_enabled
	debug_vision_toggled.emit(debug_vision_enabled)
	_log_info("[Match] DEBUG VISION: %s" % ("ENABLED" if debug_vision_enabled else "DISABLED"))


func is_godmode_active() -> bool:
	return godmode


func is_flymode_active() -> bool:
	return flymode


func is_noclip_active() -> bool:
	return noclip


func toggle_fullscreen() -> void:
	## Toggle fullscreen mode (F11)
	var window := get_window()
	if window:
		if window.mode == Window.MODE_FULLSCREEN:
			window.mode = Window.MODE_WINDOWED
			_log_info("[Match] FULLSCREEN: DISABLED")
		else:
			window.mode = Window.MODE_FULLSCREEN
			_log_info("[Match] FULLSCREEN: ENABLED")


func take_screenshot() -> void:
	## Take a screenshot and save to user directory (F12)
	var viewport := get_viewport()
	if not viewport:
		push_warning("[Match] Cannot take screenshot: no viewport")
		return

	var image := viewport.get_texture().get_image()
	if not image:
		push_warning("[Match] Cannot take screenshot: failed to get image")
		return

	# Create screenshots directory if it doesn't exist
	var dir := "user://screenshots"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_absolute(dir)

	# Generate filename with timestamp
	var datetime := Time.get_datetime_dict_from_system()
	var filename := (
		"screenshot_%04d%02d%02d_%02d%02d%02d.png"
		% [
			datetime.year,
			datetime.month,
			datetime.day,
			datetime.hour,
			datetime.minute,
			datetime.second
		]
	)
	var filepath := dir + "/" + filename

	# Save screenshot
	var err := image.save_png(filepath)
	if err == OK:
		_log_info("[Match] Screenshot saved: %s" % filepath)
	else:
		push_error("[Match] Failed to save screenshot: %s" % error_string(err))


# === SNAPSHOTS ===

## Get match state snapshot


func get_match_snapshot() -> Dictionary:
	return {
		"time_left": time_left,
		"state": current_match_state,
		"scores": player_scores.duplicate(true)
	}


## Apply match state snapshot


func apply_match_snapshot(data: Dictionary) -> void:
	if data.has("time_left"):
		time_left = data.time_left
	if data.has("state"):
		current_match_state = int(data.state) as MatchState
	if data.has("scores"):
		player_scores = data.scores.duplicate(true)

	# Update state
	_match_timer_active = (current_match_state == MatchState.PLAYING)

	# Emit updates
	match_state_changed.emit(current_match_state)
	scores_updated.emit()
	match_timer_updated.emit(time_left)


# === KILL FEED LOGIC ===


func add_kill_feed_entry(killer_id: int, victim_id: int, weapon_id: String) -> void:
	# Add to Kill Feed
	var entry: Dictionary = {
		"killer_id": killer_id,
		"victim_id": victim_id,
		"weapon_id": weapon_id,
		"timestamp": Time.get_ticks_msec()
	}
	kill_feed.push_front(entry)
	if kill_feed.size() > max_kill_feed_entries:
		kill_feed.pop_back()

	kill_feed_updated.emit()
	scores_updated.emit()
	player_killed.emit(killer_id, victim_id)

	# Auto remove from feed
	var entry_ref: Dictionary = entry
	get_tree().create_timer(kill_feed_duration).timeout.connect(
		func() -> void:
			if entry_ref in kill_feed:
				kill_feed.erase(entry_ref)
				kill_feed_updated.emit()
	)


## Broadcast all player states periodically to ensure proper state detection by peers
func _broadcast_all_player_states() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return  # Only server should broadcast

	# Broadcast each player's state to all clients
	for peer_id: int in player_scores.keys():
		var player_data: Dictionary = player_scores[peer_id]
		var health: int = player_data.get("health", 100)
		var state: int = player_data.get("state", Enums.PlayerState.ALIVE)

		# Broadcast to all clients
		_broadcast_player_status.rpc(peer_id, health, state)
