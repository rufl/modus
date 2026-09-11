class_name NetworkManager
extends Node

## NetworkManager - Core Multiplayer Infrastructure
##
## This manager orchestrates all high-level network operations including
## hosting sessions, joining servers, managing peer connections, and
## handling authoritative state synchronization.
## It integrates security, rate-limiting, and optimization subsystems.

# Preload RPC Whitelist for security validation
const RPC_WHITELIST = preload("res://game/core/network/rpc_whitelist.gd")

# SECURITY FIX: Magic number constants for validation
const MAX_PLAYER_SPEED: float = 10.0  # Maximum player movement speed (m/s)
const MAX_REVIVE_DISTANCE: float = 3.0  # Maximum distance for reviving (meters)
const AIM_SNAP_THRESHOLD_DEG: float = 30.0  # Aim snap detection threshold (degrees)
const MAX_WEAPON_INDEX: int = 8  # Maximum weapon slot index (0-8 = 9 weapons)
const MAX_DAMAGE_AMOUNT: float = 1000.0  # Hard cap on damage per hit
const MAX_PICKUP_DISTANCE: float = 5.0  # Maximum distance for item pickup (meters)

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal state_snapshot_ready(peer_id: int, snapshot: Dictionary)
signal hosting_started(port: int)
signal connection_established(is_host: bool)
signal connection_failed(reason: String)
signal connection_lost  # Triggered when client loses connection to server
signal reconnection_attempt(attempt: int, max_attempts: int)
signal reconnection_failed
signal reconnection_success
signal tick_completed
signal pre_tick
signal post_tick

const MAX_PREDICTION_BUFFER_SIZE: int = 64
const MAX_SERVER_TICKS_PER_FRAME: int = 8

var config: NetworkConfig = null
var delta_compressor: RefCounted = null  # DeltaCompression instance

var _rpc_rate_limits: Dictionary = {}  # method -> {calls_per_sec, last_call_time}
var _validation_enabled: bool = true
var _state_snapshots: Dictionary = {}  # peer_id -> Dictionary
var _trusted_peers: Array[int] = []
var _last_positions: Dictionary = {}  # peer_id -> Vector3
var _last_check_times: Dictionary = {}  # peer_id -> float (timestamp)
var _violation_counts: Dictionary = {}  # peer_id -> int
var _aim_suspicion_scores: Dictionary = {}  # peer_id -> float
var _last_aim_vectors: Dictionary = {}  # peer_id -> Vector3
var _last_fire_times: Dictionary = {}  # peer_id -> float (timestamp)
var _peer_steam_ids: Dictionary = {}  # Verified peer_id -> Steam ID
var _pending_steam_ids: Dictionary = {}  # Auth-started peer_id -> Steam ID
var _reconnect_attempts: int = 0
var _max_reconnect_attempts: int = 5
var _reconnect_delay_ms: int = 2000
var _reconnect_window_sec: float = 60.0
var _reconnect_timer: Timer = null
var _last_host_info: Dictionary = {"host": "", "port": 0, "is_steam": false}
var _is_reconnecting: bool = false
var _expected_server_disconnect: bool = false
var _use_steam: bool = false
var _fallback_to_enet: bool = true
var _default_port: int = 9999
var _max_players: int = 16
var _steam_manager: Node = null
var _tick_accumulator: float = 0.0
var _tick_timer: float = 0.0
var _tick_overrun_warning_active: bool = false
var _current_tick: int = 0
var _prediction_buffer: Array[Dictionary] = []


func get_steam_manager() -> Node:
	if not _steam_manager:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm:
			var ns: Variant = gm.get_core_system("network")
			_steam_manager = ns.steam_manager if ns else null
	return _steam_manager


func get_peer_steam_id(peer_id: int) -> int:
	return int(_peer_steam_ids.get(peer_id, 0))

func _bind_steam_auth_signal() -> void:
	var steam: Node = get_steam_manager()
	if steam and steam.has_signal("steam_auth_ticket_validated"):
		if not steam.steam_auth_ticket_validated.is_connected(_on_steam_auth_ticket_validated):
			steam.steam_auth_ticket_validated.connect(_on_steam_auth_ticket_validated)


func _steam_auth_available() -> bool:
	var steam: Node = get_steam_manager()
	return (
		_use_steam
		and steam != null
		and steam.has_method("is_steam_running")
		and steam.is_steam_running()
	)


func _on_steam_auth_ticket_validated(steam_id: int, response: int) -> void:
	var peer_id: int = 0
	for pending_peer: Variant in _pending_steam_ids:
		if int(_pending_steam_ids[pending_peer]) == steam_id:
			peer_id = int(pending_peer)
			break
	if peer_id == 0:
		return

	if response != 0:
		push_warning(
			"[Network] Steam Auth rejected for peer %d (ID: %d, response: %d)"
			% [peer_id, steam_id, response]
		)
		# Keep the pending entry until disconnect so its started session is ended.
		multiplayer.disconnect_peer(peer_id)
		return

	for verified_peer: Variant in _peer_steam_ids:
		if int(_peer_steam_ids[verified_peer]) == steam_id and int(verified_peer) != peer_id:
			push_warning("[Network] Steam ID %d is already verified for peer %d" % [steam_id, verified_peer])
			multiplayer.disconnect_peer(peer_id)
			return

	_pending_steam_ids.erase(peer_id)
	_peer_steam_ids[peer_id] = steam_id
	add_trusted_peer(peer_id)


func _ready() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[Network] Initializing...", "Network")

	# Initialize Delta Compression
	var delta_script: Script = load("res://game/core/network/delta_compression.gd")
	if delta_script:
		delta_compressor = delta_script.new()

	# Load network config (legacy JSON5 + new NetworkConfig resource)
	_load_network_config()
	_load_network_config_resource()

	# Connect to multiplayer signals
	if multiplayer:
		if not multiplayer.peer_connected.is_connected(_on_peer_connected):
			multiplayer.peer_connected.connect(_on_peer_connected)
		if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
			multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_bind_steam_auth_signal()

	_setup_rate_limits()

	# Setup partial reconnection timer
	_reconnect_timer = Timer.new()
	_reconnect_timer.one_shot = true
	if not _reconnect_timer.timeout.is_connected(_on_reconnect_timer_timeout):
		_reconnect_timer.timeout.connect(_on_reconnect_timer_timeout)
	add_child(_reconnect_timer)


func _exit_tree() -> void:
	# === SIGNAL HYGIENE: Disconnect ALL signals to prevent memory leaks ===

	# Multiplayer signals
	if multiplayer:
		if multiplayer.peer_connected.is_connected(_on_peer_connected):
			multiplayer.peer_connected.disconnect(_on_peer_connected)
		if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
			multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	var steam: Node = get_steam_manager()
	if steam and steam.has_signal("steam_auth_ticket_validated"):
		if steam.steam_auth_ticket_validated.is_connected(_on_steam_auth_ticket_validated):
			steam.steam_auth_ticket_validated.disconnect(_on_steam_auth_ticket_validated)


	# Timer signals
	if _reconnect_timer:
		if _reconnect_timer.timeout.is_connected(_on_reconnect_timer_timeout):
			_reconnect_timer.timeout.disconnect(_on_reconnect_timer_timeout)
		_reconnect_timer.queue_free()
		_reconnect_timer = null


## Load network configuration from network.json5


func _load_network_config() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var cm: Variant = gm.get_core_system("config")
		if cm and cm.has_method("get_value"):
			_use_steam = bool(
				_get_first_config_value(
					cm, ["network.connection.use_steam", "network.use_steam_networking"], false
				)
			)
			_fallback_to_enet = bool(
				_get_first_config_value(
					cm, ["network.connection.fallback_to_enet", "network.fallback_to_enet"], true
				)
			)
			_default_port = int(
				_get_first_config_value(
					cm, ["network.connection.default_port", "network.default_port"], 9999
				)
			)
			_max_players = int(
				_get_first_config_value(
					cm, ["network.connection.max_players", "network.max_players"], 16
				)
			)

			# Load reconnection settings from config
			_max_reconnect_attempts = int(
				_get_first_config_value(
					cm, ["network.connection.max_reconnect_attempts", "network.max_reconnect_attempts"], 5
				)
			)
			_reconnect_delay_ms = int(
				_get_first_config_value(
					cm, ["network.connection.reconnect_delay_ms", "network.reconnect_delay_ms"], 2000
				)
			)
			_reconnect_window_sec = float(
				_get_first_config_value(
					cm,
					["network.connection.reconnect_window_seconds", "network.reconnect_window"],
					60.0
				)
			)

	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info(
				(
					"[Network] Legacy config loaded - Steam: %s, Port: %d, MaxReconnect: %d"
					% [_use_steam, _default_port, _max_reconnect_attempts]
				),
				"Network"
			)


## Load NetworkConfig resource (new netcode architecture)


func _get_first_config_value(
	cm: Variant, paths: Array[String], default_value: Variant
) -> Variant:
	for path: String in paths:
		var value: Variant = cm.get_value(path, null)
		if value != null and not value is Dictionary:
			return value
	return default_value


func _load_network_config_resource() -> void:
	var config_path: String = "res://game/core/network/default_network_config.tres"
	var config_script_path: String = "res://game/core/network/network_config.gd"

	var gm: Node = get_node_or_null("/root/GameManager")
	var created_default: bool = false

	if ResourceLoader.exists(config_path):
		config = load(config_path) as NetworkConfig
		if config:
			_max_players = config.max_players
		if gm:
			var logger: Variant = gm.get_core_system("logger")
			if logger and logger.has_method("info"):
				logger.info("[Network] NetworkConfig loaded", "Network")
				logger.info(config.get_config_summary(), "Network")
	else:
		var config_script: Script = load(config_script_path)
		if config_script:
			config = config_script.new() as NetworkConfig
			created_default = true

	if not config:
		push_error("[Network] Failed to create NetworkConfig")
		return

	# Presets provide defaults; explicit JSON settings below always win.
	if created_default:
		config.apply_preset(config.active_preset, false)

	# Synchronize with JSON5 config (Bridge Legacy -> New System).
	if gm:
		var cm: Variant = gm.get_core_system("config")
		if cm and cm.has_method("get_value"):
			var logger_sync: Variant = gm.get_core_system("logger")
			if logger_sync and logger_sync.has_method("info"):
				logger_sync.info(
					"[Network] Synchronizing JSON5 config with NetworkResource...", "Network"
				)

			var json_tick: int = int(
				_get_first_config_value(
					cm, ["network.tick_rate.server", "network.tick_rate", "system.tick_rate"], 60
				)
			)
			if json_tick != config.server_tick_rate:
				config.server_tick_rate = json_tick
				if logger_sync and logger_sync.has_method("info"):
					logger_sync.info("  - server_tick_rate: %d (from JSON)" % json_tick, "Network")

			var json_max: int = int(
				_get_first_config_value(
					cm, ["network.connection.max_players", "network.max_players"], 16
				)
			)
			if json_max != config.max_players:
				config.max_players = json_max
				if logger_sync and logger_sync.has_method("info"):
					logger_sync.info("  - max_players: %d (from JSON)" % json_max, "Network")

			var json_lag: bool = bool(
				_get_first_config_value(
					cm,
					["network.lag_compensation.enabled", "network.lag_compensation_enabled"],
					true
				)
			)
			if json_lag != config.enable_lag_compensation:
				config.enable_lag_compensation = json_lag
				if logger_sync and logger_sync.has_method("info"):
					logger_sync.info(
						"  - enable_lag_compensation: %s (from JSON)" % json_lag, "Network"
					)

			var json_hist_ms: float = float(
				_get_first_config_value(
					cm,
					[
						"network.lag_compensation.max_window_ms",
						"network.lag_compensation_max_ms"
					],
					1000.0
				)
			)
			var json_hist_sec: float = json_hist_ms / 1000.0
			if not is_equal_approx(json_hist_sec, config.lag_comp_history_duration):
				config.lag_comp_history_duration = json_hist_sec
				if logger_sync and logger_sync.has_method("info"):
					logger_sync.info(
						"  - lag_comp_history_duration: %.2fs (from JSON)" % json_hist_sec,
						"Network"
					)

			var interpolation_enabled: bool = bool(
				_get_first_config_value(
					cm,
					["network.snapshot_buffer.interpolation_enabled", "network.interpolation_enabled"],
					true
				)
			)
			if not interpolation_enabled:
				config.interpolation_delay = 0.0
				if logger_sync and logger_sync.has_method("info"):
					logger_sync.info("  - interpolation_delay: 0.0s (Disabled via JSON)", "Network")

	_max_players = config.max_players
	config.refresh_derived_values()

	if created_default and gm:
		var logger2: Variant = gm.get_core_system("logger")
		if logger2 and logger2.has_method("info"):
			logger2.info("[Network] Created default NetworkConfig", "Network")

## Initialize method for GameCore service pattern


func initialize() -> void:
	await get_tree().process_frame


## Get service initialization priority


func get_init_priority() -> int:
	return 20  # Load after GameManager.get_core_system("config") and NetworkService.steam_manager


## Setup rate limits for RPC methods


func _setup_rate_limits() -> void:
	# Load rate limits from whitelist
	for method: String in RPC_WHITELIST.get_all_methods():
		var rate: float = RPC_WHITELIST.get_rate_limit(method)
		add_rate_limit(method, rate)

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info(
				"[Network] Loaded %d RPC rate limits from whitelist" % _rpc_rate_limits.size(),
				"Network"
			)

	# Print whitelist summary in debug mode
	if OS.is_debug_build():
		RPC_WHITELIST.print_summary()


## Add rate limit for an RPC method


func add_rate_limit(method_name: String, calls_per_second: float) -> void:
	_rpc_rate_limits[method_name] = {"calls_per_second": calls_per_second, "last_call_time": {}}


## Validate RPC call (server-side validation)
## CRITICAL SECURITY: Whitelist-based validation (deny by default)


func validate_rpc(peer_id: int, method: String, args: Array = []) -> bool:
	# SECURITY FIX: Only allow disabling validation in debug builds
	if not _validation_enabled:
		if OS.is_debug_build() and OS.has_feature("editor"):
			push_warning("[Security] RPC validation DISABLED (debug mode only)")
			return true

		# In production, log the attempt and continue validating
		push_error("[Security] Attempt to bypass validation blocked in production")
		# Fall through to validation

	# The server's own peer is trusted. Remote peers still need whitelist,
	# rate-limit, and payload validation even when this node has authority.
	if peer_id == 1:
		return true

	# Steam-authenticated peers are identified, not exempt from RPC controls.

	# CRITICAL: Check whitelist FIRST (deny by default)
	if not RPC_WHITELIST.is_allowed(method):
		push_error("[Security] Unauthorized RPC attempt: '%s' from peer %d" % [method, peer_id])
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm:
			var logger: Variant = gm.get_core_system("logger")
			if logger and logger.has_method("error"):
				logger.error(
					"[Security] BLOCKED unauthorized RPC: '%s' from peer %d" % [method, peer_id],
					"Network"
				)

		# SECURITY FIX: Immediate kick on first unauthorized RPC attempt
		# No tolerance for probing attacks - fail secure
		push_error("[Security] KICKING peer %d for unauthorized RPC attempt" % peer_id)
		multiplayer.disconnect_peer(peer_id)
		return false

	# Rate limit check
	if not _check_rate_limit(peer_id, method):
		push_warning("[Network] Rate limit exceeded for peer %d, method %s" % [peer_id, method])
		return false

	# Additional validation if required by whitelist
	# SECURITY FIX: Use static dispatch instead of dynamic call()
	if RPC_WHITELIST.requires_validation(method):
		var validator: String = RPC_WHITELIST.get_validator(method)

		# Static method dispatch - compiler-verified method names
		match validator:
			"_validate_shoot_request":
				return _validate_shoot_request(peer_id, args)
			"_validate_damage_request":
				return _validate_damage_request(args)
			"_validate_weapon_switch":
				return _validate_weapon_switch(peer_id, args)
			"_validate_pickup_request":
				return _validate_pickup_request(peer_id, args)
			"_validate_revive_request":
				return _validate_revive_request(peer_id, args)
			"_validate_player_status_update":
				return _validate_player_status_update(peer_id, args)
			"_validate_chat_message":
				return _validate_chat_message(args)
			"_validate_kill_registration":
				return _validate_kill_registration(peer_id, args)
			"_validate_steam_ticket":
				return _validate_steam_ticket(args)
			"_validate_target_player_rpc":
				return _validate_target_player_rpc(peer_id, args)
			"_validate_interaction_pickup":
				return _validate_interaction_pickup(peer_id, args)
			"_validate_interaction_throw":
				return _validate_interaction_throw(args)
			_:
				push_error("[Security] Unknown validator: %s" % validator)
				return false  # Fail secure

	return true


## Check rate limit for a method


func _check_rate_limit(peer_id: int, method: String) -> bool:
	if not _rpc_rate_limits.has(method):
		return true  # No rate limit defined

	var limit_data: Dictionary = _rpc_rate_limits[method]
	var calls_per_second: float = limit_data.calls_per_second
	var last_call_times: Dictionary = limit_data.last_call_time

	var current_time: float = Time.get_ticks_msec() / 1000.0
	var min_interval: float = 1.0 / calls_per_second

	if last_call_times.has(peer_id):
		var last_call: float = last_call_times[peer_id]
		var time_since_last: float = current_time - last_call

		if time_since_last < min_interval:
			return false  # Too soon

	# Update last call time
	last_call_times[peer_id] = current_time
	return true


func _process(delta: float) -> void:
	# A caller may temporarily detach a transport while replacing it.
	# Normal single-player operation keeps an OfflineMultiplayerPeer.
	if multiplayer.multiplayer_peer == null:
		return
	if not multiplayer.is_server():
		return

	# Server tick simulation (fixed timestep for determinism)
	if config:
		_run_server_tick(delta)

	# Periodic movement validation (runs every frame, not every tick)
	_validate_movement(delta)


## Fixed-timestep server simulation


func _run_server_tick(delta: float) -> void:
	var tick_duration: float = maxf(config.frame_duration_ms / 1000.0, 0.000001)
	_tick_accumulator += maxf(delta, 0.0)

	var ticks_to_process: int = mini(
		MAX_SERVER_TICKS_PER_FRAME, int(_tick_accumulator / tick_duration)
	)
	for _tick_index: int in range(ticks_to_process):
		pre_tick.emit()

		# Game logic updates happen here via signals.
		# Components/systems connect to tick_completed to update.
		_current_tick += 1
		tick_completed.emit()
		post_tick.emit()

		_tick_accumulator -= tick_duration
		_tick_timer += tick_duration

	# Drop stale whole-tick backlog after the bounded catch-up budget. Keeping
	# only the fractional remainder prevents a permanent runaway catch-up loop.
	if ticks_to_process == MAX_SERVER_TICKS_PER_FRAME and _tick_accumulator >= tick_duration:
		if not _tick_overrun_warning_active:
			push_warning(
				"[Network] Server tick catch-up budget exceeded; dropping stale tick backlog"
			)
			_tick_overrun_warning_active = true
		_tick_accumulator = fmod(_tick_accumulator, tick_duration)
	else:
		_tick_overrun_warning_active = false


func _validate_movement(_delta: float) -> void:
	# Use GameManager.get_core_system("entity") for fast O(1) lookup
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return
	var gs: Variant = gm.get_core_system("gameplay")
	if not gs:
		return

	var registry: Node = gs.get("entity_registry")
	if not is_instance_valid(registry):
		return

	var players: Array = registry.get_all_players()
	if players.is_empty():
		return

	# Optimization: Distribute validation across frames
	# For 32+ players, validating everyone every frame is expensive.
	# We check 1/4th of the players each frame (approx 15Hz check rate at 60FPS)
	var frame_mod: int = Engine.get_process_frames() % 4
	var current_time: float = Time.get_ticks_msec() / 1000.0

	for i in range(players.size()):
		var player: Node = players[i]

		# SECURITY FIX: Validate player is still valid
		if not is_instance_valid(player):
			continue

		# Skip simple distribution check (round robin)
		if i % 4 != frame_mod:
			continue

		# Safe method check
		if not player.has_method("is_multiplayer_authority"):
			continue
		if player.is_multiplayer_authority():
			continue

		# Safe peer_id extraction
		if not player.name.is_valid_int():
			continue
		var peer_id: int = int(player.name)
		# Steam-authenticated peers still receive movement validation.

		# Safe position access
		if not "global_position" in player:
			continue
		var current_pos: Vector3 = player.global_position
		if not current_pos.is_finite():
			continue

		# Initialize if missing
		if not _last_positions.has(peer_id):
			_last_positions[peer_id] = current_pos
			_last_check_times[peer_id] = current_time
			continue

		var last_time: float = _last_check_times.get(peer_id, current_time - 0.016)
		var time_elapsed: float = current_time - last_time

		# Prevent division by zero or extremely small deltas
		if time_elapsed < 0.001:
			continue

		var last_pos: Vector3 = _last_positions[peer_id]
		var dist: float = current_pos.distance_to(last_pos)
		var speed: float = dist / time_elapsed

		# Calculate allowed speed
		var max_speed: float = MAX_PLAYER_SPEED  # Default fallback
		if "move_speed" in player:
			max_speed = player.move_speed
		# Use absolute max if defined
		if "max_speed" in player:
			max_speed = player.max_speed

		var multiplier: float = 1.0
		if "is_sprinting" in player and player.is_sprinting:
			if "sprint_multiplier" in player:
				multiplier = player.sprint_multiplier
		if player.has_method("get_movement_modifier"):
			multiplier *= player.get_movement_modifier()

		var allowed: float = max_speed * multiplier * config.max_speed_tolerance

		# Check for flying logic if needed
		if "velocity" in player:
			# If falling (y velocity negative), speed might be high vertically
			if player.velocity.y < -10.0:
				allowed *= 2.0

		var violation_threshold: float = config.speed_violation_dist_threshold

		if speed > allowed and dist > violation_threshold:  # Ignore micro-movements
			_violation_counts[peer_id] = _violation_counts.get(peer_id, 0) + 1

			# Kick persistent cheaters
			if _violation_counts[peer_id] > config.max_violations_kick:
				push_error(
					(
						"[Network] Kicking peer %d for speed hacking (%d violations)"
						% [peer_id, _violation_counts[peer_id]]
					)
				)
				multiplayer.disconnect_peer(peer_id)
				return

			# Rubber-band for moderate violations
			if _violation_counts[peer_id] > config.max_violations_rubberband:
				push_warning(
					(
						"[Network] Speed violation: Peer %d at %.2f (Max: %.2f) dt=%.3f"
						% [peer_id, speed, allowed, time_elapsed]
					)
				)
				player.global_position = last_pos  # Rubber band

		else:
			_violation_counts[peer_id] = max(0, _violation_counts.get(peer_id, 0) - 1)

		# Update history
		_last_positions[peer_id] = current_pos
		_last_check_times[peer_id] = current_time


## Validate shoot request


func _validate_shoot_request(peer_id: int, args: Array) -> bool:
	# Args: [origin, direction, weapon_index]
	if args.size() < 3:
		push_error("[Security] Invalid shoot request: insufficient args")
		return false

	# SECURITY FIX: Type validation
	if not args[0] is Vector3:
		push_error("[Security] Invalid shoot request: origin not Vector3")
		return false
	if not args[1] is Vector3:
		push_error("[Security] Invalid shoot request: direction not Vector3")
		return false
	if not args[2] is int:
		push_error("[Security] Invalid shoot request: weapon_index not int")
		return false

	var origin: Vector3 = args[0]
	var direction: Vector3 = args[1]
	var weapon_index: int = args[2]

	# SECURITY FIX: Range validation
	if not origin.is_finite():
		push_error("[Security] Invalid shoot request: origin not finite")
		return false

	if not direction.is_finite():
		push_error("[Security] Invalid shoot request: direction not finite")
		return false

	if direction.length_squared() < 0.01:  # Avoid sqrt
		push_error("[Security] Invalid shoot request: direction too short")
		return false

	if weapon_index < 0 or weapon_index >= MAX_WEAPON_INDEX:  # Max 9 weapons (0-8)
		push_error("[Security] Invalid shoot request: weapon_index out of range")
		return false

	# Check if player exists and is alive
	var player: Node = _get_player_by_peer_id(peer_id)
	if not player:
		return false

	if player.has_method("is_dead") and player.is_dead:
		return false

	# 1. ORIGIN VALIDATION (Anti-Teleport/Reach Hacks)
	# Player shoots from their camera/eyes.
	# Server player position is at feet.
	# Allow approx height + tolerance for lag
	var allowed_dist: float = config.shot_origin_tolerance

	# If we have a 'Head' node or similar, use it?
	# For now, distance from global_position (feet)
	if player.global_position.distance_to(origin) > allowed_dist:
		# Double check if player is in a vehicle or similar?
		push_warning(
			(
				"[Network] Peer %d shot from too far away (%.2fm)"
				% [peer_id, player.global_position.distance_to(origin)]
			)
		)
		return false

	# 2. WEAPON VALIDATION
	var weapon_manager: Node = player.get_node_or_null("WeaponManager")
	if weapon_manager:
		# Check ammo
		if weapon_manager.has_method("get_current_ammo"):
			# Assuming we can get ammo for specific weapon index
			# Using get_current_ammo() gets CURRENT equipped.
			# The server's equipped weapon is authoritative.  Accepting a
			# mismatched index would let a client bypass ammo and fire-rate checks
			# for another weapon.
			if weapon_manager.current_weapon_index != weapon_index:
				push_warning(
					"[Network] Peer %d tried to fire weapon %d while weapon %d is equipped"
					% [peer_id, weapon_index, weapon_manager.current_weapon_index]
				)
				return false
			else:
				var ammo: Array = weapon_manager.get_current_ammo()
				if ammo.size() > 0 and ammo[0] <= 0:
					push_warning("[Network] Peer %d tried to shoot with 0 ammo" % peer_id)
					return false

		# 3. FIRE RATE VALIDATION
		if weapon_manager.weapons and weapon_index < weapon_manager.weapons.size():
			var weapon_data: Resource = weapon_manager.weapons[weapon_index]
			if weapon_data and "fire_rate" in weapon_data:
				var current_time: float = Time.get_ticks_msec() / 1000.0
				# 15% tolerance for jitter
				var required_interval: float = weapon_data.fire_rate * 0.85
				var last_fire: float = _last_fire_times.get(peer_id, 0.0)

				if current_time - last_fire < required_interval:
					# Too fast
					var gm: Node = get_node_or_null("/root/GameManager")
					if gm:
						var logger: Variant = gm.get_core_system("logger")
						if logger and logger.has_method("debug"):
							logger.debug(
								"[Network] Rate limit: Suspicious fire rate peer %d" % peer_id,
								"Network"
							)
					return false

				_last_fire_times[peer_id] = current_time

	# 4. AIMBOT HEURISTICS (Angular Velocity)
	# Highly skilled players can snap, but instant 180 degree snaps are suspicious.
	# We monitor angle changes between shots.
	if _last_aim_vectors.has(peer_id):
		var last_dir: Vector3 = _last_aim_vectors[peer_id]
		var angle_diff: float = rad_to_deg(last_dir.angle_to(direction))

		# If angle change is massive (>30 deg) and time delta is tiny?
		# Hard to measure perfectly without precise packet timestamps.
		# Just track for patterns.
		if angle_diff > config.aim_snap_threshold_deg:
			_aim_suspicion_scores[peer_id] = _aim_suspicion_scores.get(peer_id, 0.0) + 1.0
		else:
			_aim_suspicion_scores[peer_id] = max(0.0, _aim_suspicion_scores.get(peer_id, 0.0) - 0.1)

		if _aim_suspicion_scores.get(peer_id, 0.0) > config.aim_suspicion_threshold:
			var gm: Node = get_node_or_null("/root/GameManager")
			if gm:
				var logger: Variant = gm.get_core_system("logger")
				if logger and logger.has_method("warning"):
					logger.warning(
						"[Network] High aimbot suspicion score for peer %d" % peer_id, "Network"
					)

	_last_aim_vectors[peer_id] = direction

	return true


## Validate weapon switch


func _validate_weapon_switch(peer_id: int, args: Array) -> bool:
	if args.size() < 1:
		return false
	var index: int = args[0]

	var player: Node = _get_player_by_peer_id(peer_id)
	if not player:
		return false

	var wm: Node = player.get_node_or_null("WeaponManager")
	if not wm or not wm.weapons:
		return false

	if index < 0 or index >= wm.weapons.size():
		return false

	return true


## Validate damage request


func _validate_damage_request(args: Array) -> bool:
	# Server should handle damage, not clients
	if not multiplayer.is_server():
		return false

	# Validate Arguments and reject malformed/non-finite payloads.
	if args.size() < 3:
		return false
	if (
		(not args[0] is float and not args[0] is int)
		or not args[1] is int
		or not args[2] is Vector3
	):
		return false
	if not args[2].is_finite():
		return false

	var amount: float = float(args[0])
	var attacker_id: int = args[1]
	# 1. Damage Cap Check
	if amount < 0 or amount > MAX_DAMAGE_AMOUNT:  # Hard cap
		push_warning("[Network] Damage validation failed: Invalid amount %.2f" % amount)
		return false

	# 2. Attacker Validation
	# Ensure the peer sending the request is the one claiming to be the attacker
	# OR the server is the one sending it (peer_id 1)
	var sender_id: int = multiplayer.get_remote_sender_id()

	if sender_id != 1 and sender_id != attacker_id:
		# Client tried to damage on behalf of someone else?
		push_warning("[Network] Peer %d tried to claim damage from %d" % [sender_id, attacker_id])
		return false

	# 3. Entity Existence Check
	var attacker: Node = _get_player_by_peer_id(attacker_id)
	if not attacker:
		# Could be environmental or AI?
		if attacker_id != 0:  # 0 usually means world/environment
			return false

	return true


func _validate_player_status_update(peer_id: int, args: Array) -> bool:
	if args.size() < 3:
		return false
	if not args[0] is int or int(args[0]) != peer_id:
		return false
	if not args[1] is int or int(args[1]) < 0 or int(args[1]) > 10000:
		return false
	if not args[2] is int or int(args[2]) < 0 or int(args[2]) > 5:
		return false
	return true


func _validate_chat_message(args: Array) -> bool:
	if args.size() != 1 or not args[0] is String:
		return false
	var message: String = args[0]
	return (
		not message.strip_edges().is_empty()
		and message.length() <= 256
		and not message.contains("\n")
		and not message.contains("\r")
	)


func _validate_kill_registration(peer_id: int, args: Array) -> bool:
	if args.size() < 2 or args.size() > 3:
		return false
	if not args[0] is int or not args[1] is int:
		return false
	var killer_id: int = args[0]
	var victim_id: int = args[1]
	if killer_id <= 0 or victim_id <= 0 or peer_id != killer_id and peer_id != victim_id:
		return false
	if args.size() == 3:
		if not args[2] is String:
			return false
		var damage_source: String = args[2]
		if (
			damage_source.length() > 64
			or damage_source.contains("\n")
			or damage_source.contains("\r")
		):
			return false
	return true


func _validate_steam_ticket(args: Array) -> bool:
	if args.size() != 1 or not args[0] is Dictionary:
		return false
	var ticket_bundle: Dictionary = args[0]
	var steam_id: Variant = ticket_bundle.get("id", 0)
	var ticket_buffer: Variant = ticket_bundle.get("buffer", [])
	if not steam_id is int or int(steam_id) <= 0:
		return false
	if not ticket_buffer is Array or ticket_buffer.is_empty() or ticket_buffer.size() > 4096:
		return false
	return true


func _validate_target_player_rpc(peer_id: int, args: Array) -> bool:
	if args.size() != 1 or not args[0] is NodePath:
		return false
	var target_component: Node = get_node_or_null(args[0])
	var player: Node = _get_player_by_peer_id(peer_id)
	return target_component != null and player != null and target_component.get_parent() == player


func _validate_interaction_pickup(peer_id: int, args: Array) -> bool:
	if args.size() != 1 or not args[0] is NodePath:
		return false
	var player: Node = _get_player_by_peer_id(peer_id)
	var obj: Node = get_node_or_null(args[0])
	if not player or not obj or not obj is RigidBody3D:
		return false
	return player.global_position.distance_to(obj.global_position) <= MAX_PICKUP_DISTANCE


func _validate_interaction_throw(args: Array) -> bool:
	if args.size() != 1 or not args[0] is Vector3:
		return false
	var direction: Vector3 = args[0]
	var magnitude: float = direction.length()
	return direction.is_finite() and magnitude > 0.1 and magnitude <= 1.1


## Validate pickup request


func _validate_pickup_request(peer_id: int, args: Array) -> bool:
	var player: Node = _get_player_by_peer_id(peer_id)
	if not player:
		return false

	# Check if player is close enough to item
	if args.size() > 0:
		var object_path: NodePath = args[0]
		var obj: Node = get_node_or_null(object_path)
		if obj and obj is Node3D:
			if player.global_position.distance_to(obj.global_position) > MAX_PICKUP_DISTANCE:
				push_warning(
					(
						"[Network] Peer %d pickup too far: %.2fm"
						% [peer_id, player.global_position.distance_to(obj.global_position)]
					)
				)
				return false

	return true


## Validate revive request (CRITICAL #7 - Revive Exploit Fix)
## This prevents the race condition where players can revive from across the map


func _validate_revive_request(peer_id: int, args: Array) -> bool:
	# Args should include: [reviver_position: Vector3, downed_player_path: NodePath]
	# Or for legacy: [downed_player_path: NodePath]

	if args.size() < 1:
		push_warning("[Network] Revive request missing arguments from peer %d" % peer_id)
		return false

	var reviver: Node = _get_player_by_peer_id(peer_id)
	if not reviver:
		push_warning("[Network] Revive request from non-existent peer %d" % peer_id)
		return false

	# Check if reviver is alive
	if reviver.has_method("is_dead") and reviver.is_dead:
		push_warning("[Network] Dead player %d tried to revive" % peer_id)
		return false

	# Get downed player
	var downed_player_path: NodePath

	# SECURITY FIX: Type validation for arguments
	# Parse arguments (support both old and new format)
	if args[0] is Vector3:
		# New format: [reviver_position, downed_player_path]
		if args.size() < 2:
			push_warning("[Network] Revive request malformed from peer %d" % peer_id)
			return false
		if not args[1] is NodePath:
			push_error("[Security] Invalid revive request: downed_player_path not NodePath")
			return false
		# Client-claimed position is ignored (security fix)
		downed_player_path = args[1]
	elif args[0] is NodePath:
		# Old format: [downed_player_path]
		downed_player_path = args[0]
	else:
		push_error("[Security] Invalid revive request: invalid argument types")
		return false

	var downed_player: Node = get_node_or_null(downed_player_path)
	if not downed_player:
		push_warning("[Network] Revive target not found: %s" % downed_player_path)
		return false

	# SECURITY FIX: Use server-authoritative position only, no tolerance for "lag"
	# Server knows the truth - client position claims cannot be trusted

	# Use ONLY server-side positions for validation
	var actual_distance: float = reviver.global_position.distance_to(downed_player.global_position)

	if actual_distance > MAX_REVIVE_DISTANCE:
		push_warning(
			(
				"[Network] Revive rejected: distance %.2fm > %.2fm from peer %d"
				% [actual_distance, MAX_REVIVE_DISTANCE, peer_id]
			)
		)
		return false

	return true


func _get_player_by_peer_id(peer_id: int) -> Node:
	# Direct O(1) lookup instead of O(n) tree traversal
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return null
	var gs: Variant = gm.get_core_system("gameplay")
	if not gs:
		return null
	var registry: Node = gs.get("entity_registry")
	if is_instance_valid(registry) and registry.has_method("get_player"):
		return registry.get_player(peer_id)
	return null


## Create state snapshot for reconnection


func create_state_snapshot(peer_id: int) -> Dictionary:
	var snapshot: Dictionary = {
		"timestamp": Time.get_ticks_msec(),
		"peer_id": peer_id,
		"game_state": {},
		"player_state": {},
		"match_state": {}
	}

	# Collect match state
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var ms: Variant = gm.get_core_system("match")
		if ms and ms.has_method("get_match_snapshot"):
			snapshot.match_state = ms.get_match_snapshot()

	# Collect player state
	var player: Node = _get_player_by_peer_id(peer_id)
	if player and player.has_method("get_snapshot"):
		var full_state: Dictionary = player.get_snapshot()

		# Add Editor/Spectator states specifically if not covered by get_snapshot
		if "is_in_editor_mode" in player:
			full_state["is_in_editor_mode"] = player.is_in_editor_mode
		if "is_spectator" in player:
			full_state["is_spectator"] = player.is_spectator

		# Apply Delta Compression
		if delta_compressor and delta_compressor.has_method("encode_delta"):
			snapshot.player_state = delta_compressor.encode_delta(peer_id, full_state)
		else:
			snapshot.player_state = full_state

	# Store snapshot
	_state_snapshots[peer_id] = snapshot
	state_snapshot_ready.emit(peer_id, snapshot)

	return snapshot


## Restore state from snapshot


func restore_state_snapshot(peer_id: int) -> bool:
	if not _state_snapshots.has(peer_id):
		return false

	var snapshot: Dictionary = _state_snapshots[peer_id]
	sync_state_to_client.rpc_id(peer_id, snapshot)

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[Network] Restoring state snapshot for peer %d" % peer_id, "Network")
	return true


## Sync state to reconnecting client

@rpc("authority", "call_remote", "reliable")
func sync_state_to_client(snapshot: Dictionary) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[Network] Received state snapshot from server", "Network")
	# Client-side state restoration
	_apply_state_snapshot(snapshot)


## Apply state snapshot to local world


func _apply_state_snapshot(snapshot: Dictionary) -> void:
	# 1. Apply Match State
	if snapshot.has("match_state"):
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm:
			var ms: Variant = gm.get_core_system("match")
			if ms and ms.has_method("apply_match_snapshot"):
				ms.apply_match_snapshot(snapshot.match_state)

	# 2. Apply Player State
	if snapshot.has("player_state"):
		# We need to find OUR player.
		# If this is reconnection, our player might already exist or be spawning.
		var my_id: int = multiplayer.get_unique_id()
		var player: Node = _get_player_by_peer_id(my_id)

		# If player doesn't exist yet, we might need to wait or rely on spawn packet?
		# Usually snapshot comes AFTER load.
		# Usually snapshot comes AFTER load.
		if player:
			if player.has_method("apply_snapshot"):
				player.apply_snapshot(snapshot.player_state)

			# Restore extra modes
			if snapshot.player_state.has("is_in_editor_mode") and "is_in_editor_mode" in player:
				player.is_in_editor_mode = snapshot.player_state.is_in_editor_mode
			if snapshot.player_state.has("is_spectator") and "is_spectator" in player:
				player.is_spectator = snapshot.player_state.is_spectator


## Client-side prediction buffer

## Predict action on client (Client-side prediction hook)


func predict_action(action: String, data: Dictionary) -> void:
	# Store prediction for reconciliation
	var prediction: Dictionary = {
		"action": action,
		"data": data.duplicate(),
		"timestamp_ms": Time.get_ticks_msec(),
		"sequence": _prediction_buffer.size()
	}

	_prediction_buffer.append(prediction)

	# Limit buffer size to prevent memory growth
	if _prediction_buffer.size() > MAX_PREDICTION_BUFFER_SIZE:
		_prediction_buffer.pop_front()


## Reconcile state with server update


func reconcile_state(server_state: Dictionary) -> void:
	# Compare server state with predicted state
	# Find matching prediction and remove older predictions
	var server_time_ms: float = server_state.get("timestamp_ms", 0.0)

	# Remove all predictions older than server state
	var new_buffer: Array[Dictionary] = []
	for prediction: Dictionary in _prediction_buffer:
		if prediction.timestamp_ms > server_time_ms:
			new_buffer.append(prediction)
	_prediction_buffer = new_buffer

	# Check for misprediction (rollback trigger)
	if server_state.has("position") and server_state.has("expected_position"):
		var pos_diff: float = (server_state.position as Vector3).distance_to(
			server_state.expected_position as Vector3
		)

		# If difference is significant, replay predictions
		if pos_diff > 0.1:
			_replay_predictions(server_state)


## Replay predictions from last confirmed state


func _replay_predictions(confirmed_state: Dictionary) -> void:
	# This would apply player input from buffered predictions
	# Starting from confirmed server state

	var predicted_pos: Vector3 = Vector3.ZERO
	if _prediction_buffer.size() > 0:
		predicted_pos = _prediction_buffer.back().data.get("position", Vector3.ZERO)

	var confirmed_pos: Vector3 = verified_pos_from_state(confirmed_state)

	push_warning(
		(
			"[Network] Rollback triggered - Misprediction %.2fm"
			% [confirmed_pos.distance_to(predicted_pos)]
		)
	)

	# Basic reconciliation: Snap to server state if deviation is too large
	# A more advanced implementation would re-run move_and_slide for all cached inputs
	# but that requires a deterministic physics simulation which is hard in Godot
	# + diverse controllers.

	var local_id: int = multiplayer.get_unique_id()
	var player: Node = _get_player_by_peer_id(local_id)
	if player:
		# Hard snap
		if confirmed_pos != Vector3.ZERO:
			player.global_position = confirmed_pos
			# Clear buffer as previous predictions were invalid based on this divergent state
			_prediction_buffer.clear()


func verified_pos_from_state(state: Dictionary) -> Vector3:
	return state.get("position", Vector3.ZERO)


## Enable/disable validation


func set_validation_enabled(enabled: bool) -> void:
	_validation_enabled = enabled
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info(
				"[Network] Validation %s" % ("enabled" if enabled else "disabled"), "Network"
			)


## Add trusted peer (bypasses some validation)


func add_trusted_peer(peer_id: int) -> void:
	if peer_id not in _trusted_peers:
		_trusted_peers.append(peer_id)
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm:
			var logger: Variant = gm.get_core_system("logger")
			if logger and logger.has_method("info"):
				logger.info("[Network] Added trusted peer: %d" % peer_id, "Network")


## Remove trusted peer


func remove_trusted_peer(peer_id: int) -> void:
	_trusted_peers.erase(peer_id)


## Peer connected handler


func _on_peer_connected(id: int) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[Network] Peer connected: %d" % id, "Network")
	peer_connected.emit(id)

	# If we sent a connection request, this confirms success
	if id == 1 and not multiplayer.is_server():
		if _is_reconnecting:
			reconnection_success.emit()
			if gm:
				var logger2: Variant = gm.get_core_system("logger")
				if logger2 and logger2.has_method("info"):
					logger2.info("[Network] Reconnection successful!", "Network")

		connection_established.emit(false)
		_reconnect_attempts = 0  # Reset reconnect counter
		_is_reconnecting = false
		_reconnect_timer.stop()

		# Client side: Send auth ticket if using Steam
		if is_steam_networking_available():
			var steam: Node = get_steam_manager()
			var ticket: Dictionary = steam.get_auth_ticket()
			if not ticket.is_empty():
				verify_steam_ticket.rpc_id(1, ticket)


## Client -> Server: Verify Steam Auth Ticket


@rpc("any_peer", "call_remote", "reliable")
func verify_steam_ticket(ticket_bundle: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	if not _steam_auth_available():
		push_warning("[Network] Rejected Steam ticket: Steam authentication is unavailable")
		return

	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id <= 0:
		return
	var ticket_gm: Node = get_node_or_null("/root/GameManager")
	var network_service: Variant = ticket_gm.get_core_system("network") if ticket_gm else null
	var network_mgr: Node = network_service.network_manager if network_service else self
	if not network_mgr or not network_mgr.has_method("validate_rpc"):
		push_warning("[Network] Rejected Steam ticket: NetworkManager unavailable")
		return
	if not network_mgr.validate_rpc(peer_id, "verify_steam_ticket", [ticket_bundle]):
		push_warning("[Network] Invalid Steam ticket payload from peer %d" % peer_id)
		return

	var steam_id: int = int(ticket_bundle.get("id", 0))
	var ticket_buffer: Array = ticket_bundle.get("buffer", [])
	if steam_id <= 0 or ticket_buffer.is_empty():
		push_warning("[Network] Invalid ticket from peer %d" % peer_id)
		return

	if _pending_steam_ids.has(peer_id) or _peer_steam_ids.has(peer_id):
		push_warning("[Network] Duplicate Steam authentication request from peer %d" % peer_id)
		return

	var steam: Node = get_steam_manager()
	var result: int = steam.begin_auth_session(steam_id, ticket_buffer)
	if result != 0:
		push_warning("[Network] Steam Auth failed to start for peer %d: %d" % [peer_id, result])
		multiplayer.disconnect_peer(peer_id)
		return

	# begin_auth_session only starts asynchronous validation. Do not identify or
	# trust the peer until Steam emits a successful auth response.
	_pending_steam_ids[peer_id] = steam_id
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info(
				"[Network] Steam Auth pending for peer %d (ID: %d)" % [peer_id, steam_id],
				"Network"
			)

## Peer disconnected handler


func _on_peer_disconnected(id: int) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[Network] Peer disconnected: %d" % id, "Network")
	peer_disconnected.emit(id)

	# Identity and trust must be removed for every transport mode.
	var steam_id: int = 0
	var had_auth_session := false
	if _peer_steam_ids.has(id):
		steam_id = int(_peer_steam_ids[id])
		had_auth_session = steam_id > 0
	if _pending_steam_ids.has(id):
		if steam_id == 0:
			steam_id = int(_pending_steam_ids[id])
		had_auth_session = had_auth_session or steam_id > 0
	_pending_steam_ids.erase(id)
	_peer_steam_ids.erase(id)
	remove_trusted_peer(id)

	# End only sessions that were actually started, and only on the server.
	if multiplayer.is_server() and had_auth_session and steam_id > 0:
		var steam: Node = get_steam_manager()
		if steam and steam.has_method("end_auth_session"):
			steam.end_auth_session(steam_id)
			if gm:
				var logger2: Variant = gm.get_core_system("logger")
				if logger2 and logger2.has_method("info"):
					logger2.info(
						(
							"[Network] Ended Steam auth session for peer %d (Steam ID: %d)"
							% [id, steam_id]
						),
						"Network"
					)

	# Clean up rate limit data
	for limit_data: Dictionary in _rpc_rate_limits.values():
		limit_data.last_call_time.erase(id)

	# Clean up validation tracking data
	_violation_counts.erase(id)
	_aim_suspicion_scores.erase(id)
	_last_positions.erase(id)
	_last_check_times.erase(id)
	_last_aim_vectors.erase(id)
	_last_fire_times.erase(id)
	_state_snapshots.erase(id)

	# Handle Client-Side Disconnection (Lost connection to server)
	if id == 1 and not multiplayer.is_server():
		connection_lost.emit()
		if gm:
			var logger3: Variant = gm.get_core_system("logger")
			if logger3 and logger3.has_method("warning"):
				logger3.warning("[Network] Lost connection to server!", "Network")

		if not _expected_server_disconnect:
			_attempt_auto_reconnect()
		else:
			# Reset flag
			_expected_server_disconnect = false


## Get network stats


func get_network_stats() -> Dictionary:
	var has_peer := multiplayer.has_multiplayer_peer()
	return {
		"peer_count": multiplayer.get_peers().size() if has_peer else 0,
		"is_server": multiplayer.is_server() if has_peer else false,
		"trusted_peers": _trusted_peers.size(),
		"snapshots_stored": _state_snapshots.size()
	}


## Print network stats


func print_stats() -> void:
	var stats: Dictionary = get_network_stats()
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[Network] Statistics:", "Network")
			logger.info("  Peer count: %d" % stats.peer_count, "Network")
			logger.info("  Is server: %s" % stats.is_server, "Network")
			logger.info("  Trusted peers: %d" % stats.trusted_peers, "Network")
			logger.info("  Snapshots stored: %d" % stats.snapshots_stored, "Network")


# ============================================================================
# HIGH-LEVEL HOSTING/JOINING API
# ============================================================================

## Host a game - uses Steam if enabled and available, otherwise ENet


func host_game(port: int = -1, max_players: int = -1) -> Error:
	if port < 0:
		port = _default_port
	if max_players < 0:
		max_players = _max_players

	var peer: MultiplayerPeer
	var steam: Node = get_steam_manager()

	# Try Steam if enabled
	if _use_steam and steam and steam.is_steam_running():
		peer = steam.create_multiplayer_peer_host(port)
		# FIXED: Null check to prevent crash if Steam peer creation returns null
		if peer:
			var gm: Node = get_node_or_null("/root/GameManager")
			if gm:
				var logger: Variant = gm.get_core_system("logger")
				if logger and logger.has_method("info"):
					logger.info("[Network] Hosting via Steam", "Network")
		else:
			var error_msg: String = "Steam host failed - Steam may be offline or not running"
			push_warning("[Network] " + error_msg)
			if not _fallback_to_enet:
				connection_failed.emit(error_msg)
				return ERR_CANT_CREATE

	# Fallback to ENet if Steam failed or disabled
	if not peer:
		if _use_steam and _fallback_to_enet:
			var gm2: Node = get_node_or_null("/root/GameManager")
			if gm2:
				var logger2: Variant = gm2.get_core_system("logger")
				if logger2 and logger2.has_method("info"):
					logger2.info(
						"[Network] Steam unavailable/failed, falling back to ENet", "Network"
					)

		var enet_peer := ENetMultiplayerPeer.new()
		var err := enet_peer.create_server(port, max_players)
		if err != OK:
			push_error("[Network] Failed to create ENet server: %s" % error_string(err))
			connection_failed.emit("Failed to start server: " + error_string(err))
			return err
		peer = enet_peer
		var msg: String = "[Network] Hosting via ENet on port %d" % port
		var gm3: Node = get_node_or_null("/root/GameManager")
		if gm3:
			var logger3: Variant = gm3.get_core_system("logger")
			if logger3 and logger3.has_method("info"):
				logger3.info(msg, "Network")

	multiplayer.multiplayer_peer = peer
	hosting_started.emit(port)
	connection_established.emit(true)

	# Save info for validation/reconnect (though hosts don't reconnect to themselves usually)
	_last_host_info = {"host": "localhost", "port": port, "is_steam": _use_steam and peer == steam}

	return OK


## Join a game - uses Steam if host is a Steam ID, otherwise ENet


func join_game(host: String, port: int = -1) -> Error:
	if port < 0:
		port = _default_port

	var peer: MultiplayerPeer
	var steam: Node = get_steam_manager()

	# Check if host is a Steam ID (all digits)
	var is_steam_id: bool = host.is_valid_int() and _use_steam

	if is_steam_id and steam and steam.is_steam_running():
		peer = steam.create_multiplayer_peer_client(host, port)
		# FIXED: Null check to prevent crash if Steam peer creation returns null
		if peer:
			var gm: Node = get_node_or_null("/root/GameManager")
			if gm:
				var logger: Variant = gm.get_core_system("logger")
				if logger and logger.has_method("info"):
					logger.info("[Network] Joining via Steam ID: %s" % host, "Network")
		else:
			var error_msg: String = "Steam join failed - Steam may be offline or not running"
			push_warning("[Network] " + error_msg)
			if not _fallback_to_enet:
				connection_failed.emit(error_msg)
				return ERR_CANT_CREATE

	if not peer:
		# Use ENet with IP address
		var enet_peer := ENetMultiplayerPeer.new()
		var err := enet_peer.create_client(host, port)
		if err != OK:
			push_error("[Network] Failed to connect: %s" % error_string(err))
			connection_failed.emit("Failed to connect: " + error_string(err))
			return err
		peer = enet_peer
		var msg: String = "[Network] Joining via ENet: %s:%d" % [host, port]
		var gm2: Node = get_node_or_null("/root/GameManager")
		if gm2:
			var logger2: Variant = gm2.get_core_system("logger")
			if logger2 and logger2.has_method("info"):
				logger2.info(msg, "Network")

	_expected_server_disconnect = false
	multiplayer.multiplayer_peer = peer

	# Save before notifying listeners, which may explicitly disconnect.
	_last_host_info = {"host": host, "port": port, "is_steam": is_steam_id}
	connection_established.emit(false)

	return OK


## Disconnect from current game


func disconnect_game() -> void:
	_expected_server_disconnect = true
	_is_reconnecting = false
	_reconnect_attempts = 0
	_last_host_info.clear()
	if _reconnect_timer:
		_reconnect_timer.stop()
	if multiplayer.multiplayer_peer:
		# Cancellation precedes close, which may emit disconnection signals.
		multiplayer.multiplayer_peer.close()
	# Null disables SceneMultiplayer authority/ID queries; offline is still server 1.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[Network] Disconnected from game", "Network")


## Check if Steam networking is available and enabled


func is_steam_networking_available() -> bool:
	var steam: Node = get_steam_manager()
	return _use_steam and steam != null and steam.is_steam_running()


## Get current network mode description


func get_network_mode() -> String:
	if is_steam_networking_available():
		return "Steam P2P"
	return "ENet (IP/LAN)"


# ============================================================================
# AUTOMATED RECONNECTION LOGIC
# ============================================================================


func _attempt_auto_reconnect() -> void:
	if _expected_server_disconnect or not _last_host_info.get("host"):
		return
	if _reconnect_attempts >= _max_reconnect_attempts:
		_is_reconnecting = false
		_reconnect_timer.stop()
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm:
			var logger: Variant = gm.get_core_system("logger")
			if logger and logger.has_method("error"):
				logger.error("[Network] Max reconnection attempts reached.", "Network")
		reconnection_failed.emit()
		return

	_is_reconnecting = true
	_reconnect_attempts += 1
	var delay: float = (_reconnect_delay_ms / 1000.0) * _reconnect_attempts

	var gm2: Node = get_node_or_null("/root/GameManager")
	if gm2:
		var logger2: Variant = gm2.get_core_system("logger")
		if logger2 and logger2.has_method("info"):
			logger2.info(
				(
					"[Network] Attempting reconnect %d/%d in %.1fs..."
					% [_reconnect_attempts, _max_reconnect_attempts, delay]
				),
				"Network"
			)

	_reconnect_timer.start(delay)
	reconnection_attempt.emit(_reconnect_attempts, _max_reconnect_attempts)


func _on_reconnect_timer_timeout() -> void:
	if not _is_reconnecting or _expected_server_disconnect:
		return
	if not _last_host_info.get("host"):
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm:
			var logger: Variant = gm.get_core_system("logger")
			if logger and logger.has_method("error"):
				logger.error("[Network] Cannot reconnect: No host info found.", "Network")
		reconnection_failed.emit()
		return

	var err: Error = join_game(_last_host_info.host, _last_host_info.get("port", _default_port))

	if err != OK:
		var gm2: Node = get_node_or_null("/root/GameManager")
		if gm2:
			var logger2: Variant = gm2.get_core_system("logger")
			if logger2 and logger2.has_method("warning"):
				logger2.warning("[Network] Reconnect failed immediately.", "Network")
		# Try again?
		_attempt_auto_reconnect()
