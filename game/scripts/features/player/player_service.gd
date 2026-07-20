class_name PlayerSvc
extends GameService

signal player_data_loaded(peer_id: int, data: Dictionary)
signal player_saved(peer_id: int)
signal session_started(peer_id: int)
signal session_ended(peer_id: int)
signal reconnect_started(peer_id: int)
signal reconnect_failed(peer_id: int, reason: String)
signal reconnect_success(peer_id: int)

const DATA_DIR: String = "user://playerdata/"
const RECONNECT_WINDOW: float = 60.0
const TOKEN_LENGTH: int = 16
const JSONHelperClass = preload("res://game/core/json_helper.gd")

var _player_data: Dictionary = {}
var _pending_sessions: Dictionary = {}
var _active_tokens: Dictionary = {}
var _cleanup_timer: float = 0.0


static func get_instance() -> PlayerSvc:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return null
	var gm: Node = tree.root.get_node_or_null("GameManager")
	if not gm or not gm.has_method("get_core_system"):
		return null
	var gs: Variant = gm.get_core_system("gameplay")
	if gs and gs is GameplaySvc:
		return gs.player as PlayerSvc
	return null


## Helper method for safe logging
func _log_info(message: String) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info(message, "Core")
			return
	print(message)


func _ready() -> void:
	name = "PlayerService"

	# Ensure data directory exists
	DirAccess.make_dir_recursive_absolute(DATA_DIR)

	# Connect multiplayer signals
	if multiplayer:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


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
	if gm and gm.has_method("unsubscribe"):
		gm.unsubscribe("match_ended", _on_match_ended)


func get_init_priority() -> int:
	return 30  # Load before gameplay services


func get_dependencies() -> Array[String]:
	return ["config", "network"]


func initialize() -> void:
	await _wait_for_dependencies()

	# Subscribe to game events
	subscribe_event("match_ended", _on_match_ended)

	_mark_initialized()
	_log_info("[PlayerService] Initialized")


func _process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Periodic cleanup of expired sessions
	_cleanup_timer += delta
	if _cleanup_timer >= 1.0:
		_cleanup_timer = 0.0
		_check_expired_sessions()


# === SESSION MANAGEMENT ===

## Register a player when they spawn (called by world.gd)


func register_player(peer_id: int) -> void:
	# Ensure player data is loaded
	get_player_data(peer_id)
	# Create session for reconnect support
	create_session(peer_id)


## Generate new session for player


func create_session(peer_id: int) -> String:
	var token: String = _generate_token()
	_active_tokens[peer_id] = token

	# Send token to client
	if peer_id != 1:
		_receive_token.rpc_id(peer_id, token)

	return token


## Client receives session token

@rpc("authority", "reliable")
func _receive_token(token: String) -> void:
	var peer_id: int = multiplayer.get_unique_id()
	_active_tokens[peer_id] = token
	_log_info("[PlayerService] Session token received")


## Attempt reconnection with token


func request_reconnect(token: String) -> void:
	_request_reconnect_rpc.rpc_id(1, token)


@rpc("any_peer", "reliable")
func _request_reconnect_rpc(token: String) -> void:
	if not multiplayer.is_server():
		return

	var new_peer_id: int = multiplayer.get_remote_sender_id()

	# Rate limit reconnection attempts
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var ns: Variant = gm.get_core_system("network")
		if ns and ns is NetworkSvc:
			if ns.network_manager and ns.network_manager.has_method("validate_rpc"):
				if not ns.network_manager.validate_rpc(new_peer_id, "request_reconnect", []):
					return

	if not _pending_sessions.has(token):
		_reconnect_result.rpc_id(new_peer_id, false, "Invalid or expired session")
		reconnect_failed.emit(new_peer_id, "Invalid token")
		return

	reconnect_started.emit(new_peer_id)

	var session: Dictionary = _pending_sessions[token]
	var old_peer_id: int = session.get("peer_id", 0)

	# Restore data from session
	_player_data[new_peer_id] = session.get("data", {})
	_player_data[new_peer_id]["peer_id"] = new_peer_id  # Update ID

	# Restore physical state
	call_deferred("_restore_physical_state", new_peer_id, session)

	# Cleanup pending session
	_pending_sessions.erase(token)

	# Create new active session
	create_session(new_peer_id)

	# Notify
	reconnect_success.emit(new_peer_id)
	_reconnect_result.rpc_id(new_peer_id, true, "Reconnected successfully")
	_log_info("[PlayerService] Player reconnected: %d (was %d)" % [new_peer_id, old_peer_id])


@rpc("authority", "reliable")
func _reconnect_result(success: bool, message: String) -> void:
	if success:
		_log_info("[PlayerService] Reconnection successful")
		reconnect_success.emit(multiplayer.get_unique_id())
	else:
		push_warning("[PlayerService] Reconnect failed: %s" % message)
		reconnect_failed.emit(multiplayer.get_unique_id(), message)


func _restore_physical_state(peer_id: int, session: Dictionary) -> void:
	# Wait for spawn using a more robust retry mechanism rather than fixed delay
	var retries: int = 10
	var player: Node = null

	while retries > 0:
		player = _get_player_node(peer_id)
		if player:
			break
		await get_tree().create_timer(0.2).timeout
		retries -= 1

	if not player:
		push_warning("[PlayerService] Could not find player node to restore state for %d" % peer_id)
		return

	# Restore transformed properties
	if session.has("position"):
		var p: Array = session["position"]
		var restored_pos: Vector3 = Vector3(p[0], p[1], p[2])
		player.global_position = restored_pos

	if session.has("rotation"):
		var r: Array = session["rotation"]
		player.global_rotation = Vector3(r[0], r[1], r[2])

	if session.has("health") and "health" in player:
		player.health = session["health"]

	# Dispatch event
	emit_event("player_reconnected", {"peer_id": peer_id, "position": player.global_position})


# === DATA PERSISTENCE ===

## Get player data (load if needed)


func get_player_data(peer_id: int) -> Dictionary:
	if _player_data.has(peer_id):
		return _player_data[peer_id]

	# Try load from file
	var data: Dictionary = _load_from_disk(peer_id)
	if data.is_empty():
		data = _create_default_data(peer_id)

	_player_data[peer_id] = data
	player_data_loaded.emit(peer_id, data)
	return data


## Save player data to disk


func save_player_data(peer_id: int) -> void:
	if not _player_data.has(peer_id):
		return

	var data: Dictionary = _player_data[peer_id]
	data["last_saved"] = Time.get_datetime_string_from_system(true)

	# Update active stats if player node exists
	_update_data_from_node(peer_id, data)

	var path: String = _get_save_path(data["uuid"])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if file:
		file.store_string(JSONHelperClass.safe_stringify(data, "\t"))
		file.close()
		player_saved.emit(peer_id)
		_log_info("[PlayerService] Saved data for peer %d" % peer_id)


## Save all players


func save_all() -> void:
	for peer_id: int in _player_data:
		save_player_data(peer_id)


## Get player inventory


func get_inventory(peer_id: int) -> Inventory:
	var data: Dictionary = get_player_data(peer_id)
	var inv: Inventory = Inventory.new()

	if data.has("inventory"):
		inv.from_dict(data["inventory"])

	inv.owner_peer_id = peer_id
	return inv


## Update player stat


func update_stat(peer_id: int, stat_name: String, value: Variant) -> void:
	if not _player_data.has(peer_id):
		return

	if not _player_data[peer_id].has("stats"):
		_player_data[peer_id]["stats"] = {}

	_player_data[peer_id]["stats"][stat_name] = value


# === INTERNAL HELPERS ===


func _generate_token() -> String:
	var chars: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var token: String = ""
	while true:
		token = ""
		for i: int in TOKEN_LENGTH:
			token += chars[randi() % chars.length()]

		# Ensure uniqueness (Collision Check)
		if not _active_tokens.values().has(token) and not _pending_sessions.has(token):
			break
	return token


func _create_default_data(peer_id: int) -> Dictionary:
	var uuid: String = _generate_uuid()
	return {
		"uuid": uuid,
		"peer_id": peer_id,
		"name": "Player_%d" % peer_id,
		"created": Time.get_datetime_string_from_system(true),
		"inventory": {},  # Serialized inventory
		"stats": {"level": 1, "xp": 0, "kills": 0, "deaths": 0}
	}


func _generate_uuid() -> String:
	var chars: String = "0123456789abcdef"
	var uuid: String = ""
	for i: int in 32:
		if i in [8, 12, 16, 20]:
			uuid += "-"
		uuid += chars[randi() % 16]
	return uuid


func _get_save_path(uuid: String) -> String:
	return DATA_DIR + uuid + ".json"


func _load_from_disk(peer_id: int) -> Dictionary:
	# Note: In a real auth system, we'd lookup UUID by username/auth-token
	# For now we use peer_id mapping (implied temporary persistence)

	# For Host (Peer 1), we can try to load a stable profile
	if peer_id == 1:
		var path: String = DATA_DIR + "host_profile.json"
		if FileAccess.file_exists(path):
			var data: Dictionary = JSON5Loader.load_file(path)
			if data:
				_log_info("[PlayerService] Loaded host profile")
				return data

	# For clients, without Auth Service, we cannot reliably map PeerID -> File
	# TODO(#001, @network-team, 2026-03-15): Integrate with SteamID for lookup
	# Implementation plan:
	# 1. Get Steam API from NetworkService.steam_manager
	# 2. Call Steam.getSteamID64() for peer
	# 3. Use SteamID as persistent identifier instead of peer_id
	# 4. Load profile from DATA_DIR + steam_id + ".json"
	# 5. Handle fallback for non-Steam builds (use peer_id)
	# Estimated effort: 8-12 hours
	return {}


func _update_data_from_node(peer_id: int, data: Dictionary) -> void:
	var player: Node = _get_player_node(peer_id)
	if not player:
		return

	# Update position
	var pos: Vector3 = player.global_position
	if pos.is_finite():
		data["last_position"] = [pos.x, pos.y, pos.z]
	else:
		push_warning("[PlayerService] NaN position detected for peer %d" % peer_id)
		data["last_position"] = [0.0, 0.0, 0.0]

	# Update stats from player persistence component if exists
	if player.has_method("get_persistence_data"):
		var p_data: Dictionary = player.get_persistence_data()
		data.merge(p_data, true)


func _capture_session_state(peer_id: int) -> Dictionary:
	var state: Dictionary = {
		"peer_id": peer_id,
		"disconnect_time": Time.get_unix_time_from_system(),
		"data": get_player_data(peer_id).duplicate(true)
	}

	# Capture physical state
	var player: Node = _get_player_node(peer_id)
	if player:
		var pos: Vector3 = player.global_position
		var rot: Vector3 = player.global_rotation

		# Validate vectors
		if not pos.is_finite():
			pos = Vector3.ZERO
			push_warning("[PlayerService] NaN position in session capture for %d" % peer_id)

		if not rot.is_finite():
			rot = Vector3.ZERO
			push_warning("[PlayerService] NaN rotation in session capture for %d" % peer_id)

		state["position"] = [pos.x, pos.y, pos.z]
		state["rotation"] = [rot.x, rot.y, rot.z]
		if "health" in player:
			state["health"] = player.health

	return state


func _check_expired_sessions() -> void:
	var now: float = Time.get_unix_time_from_system()
	var to_remove: Array[String] = []

	for token: String in _pending_sessions:
		var session: Dictionary = _pending_sessions[token]
		if now - session["disconnect_time"] > RECONNECT_WINDOW:
			to_remove.append(token)

			# Auto-save expired session before clearing
			var peer_id: int = session.get("peer_id", 0)
			_log_info("[PlayerService] Session expired for peer %d" % peer_id)

	for token: String in to_remove:
		_pending_sessions.erase(token)


func _get_player_node(peer_id: int) -> Node:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var gs: Variant = gm.get_core_system("gameplay")
		if gs and gs is GameplaySvc:
			if gs.entity_registry and gs.entity_registry.has_method("get_player"):
				return gs.entity_registry.get_player(peer_id)

	# Fallback (Slow)
	var players: Array = get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if p.get_multiplayer_authority() == peer_id:
			return p
	return null


# === EVENT HANDLERS ===


func _on_peer_connected(peer_id: int) -> void:
	# Load or create data
	get_player_data(peer_id)
	create_session(peer_id)
	session_started.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	# Save state
	if _active_tokens.has(peer_id):
		var token: String = _active_tokens[peer_id]
		var session: Dictionary = _capture_session_state(peer_id)

		# Move to pending sessions
		_pending_sessions[token] = session
		_active_tokens.erase(peer_id)

		# Persist to disk
		save_player_data(peer_id)
		_player_data.erase(peer_id)  # Remove from active memory

		session_ended.emit(peer_id)
		_log_info("[PlayerService] Player disconnected, session pending (%.1fs)" % RECONNECT_WINDOW)


func _on_match_ended(_data: Dictionary) -> void:
	save_all()
