class_name PlayerStateSvc
extends GameService

signal state_changed(peer_id: int, old_state: int, new_state: int)
signal mode_changed(peer_id: int, old_mode: int, new_mode: int)

enum Mode { PLAYING = 0, SPECTATING = 1, EDITOR = 2 }

const PLAYER_STATE_ENUM = Enums.PlayerState

var _player_states: Dictionary = {}
var _afk_timeout: float = 300.0  # 5 minutes
var _state_lock: Mutex = Mutex.new()  # SECURITY FIX: Prevent race conditions


static func get_instance() -> PlayerStateSvc:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return null
	var manager: Node = tree.root.get_node_or_null("GameManager")
	if not manager or not manager.has_method("get_core_system"):
		return null
	return manager.get_core_system("player_state")


# === SIGNALS ===

# === CONSTANTS ===
# Use global Enums.PlayerState for consistency
# Alias for backward compatibility (renamed to avoid shadowing global State class)

# Mode enum for player activity mode

# === DATA ===
# peer_id -> { "state": int, "mode": int, "last_action_time": float }


func _ready() -> void:
	name = "PlayerStateSvc"
	# Registration is done by GameCore

	if multiplayer:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func get_init_priority() -> int:
	return 40  # Load before MatchService (50)


func get_dependencies() -> Array[String]:
	return ["config"]


func initialize() -> void:
	await _wait_for_dependencies()
	_mark_initialized()
	GameManager.get_core_system("logger").info("[PlayerState] Initialized", "PlayerState")


func _process(_delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return

	# Check AFK
	var now: float = Time.get_ticks_msec() / 1000.0
	for peer_id: int in _player_states:
		var info: Dictionary = _player_states[peer_id]
		# Explicit cast to int for comparison
		var current_state: int = info.state
		var current_mode: int = info.mode

		# Compare as integers - use Enums.PlayerState values
		if current_state == Enums.PlayerState.ALIVE and current_mode == int(Mode.PLAYING):
			if now - info.last_action_time > _afk_timeout:
				set_player_state(peer_id, Enums.PlayerState.AFK)


# === PUBLIC API ===

## Set player state (ALIVE, DEAD, etc)


func set_player_state(peer_id: int, new_state: int) -> void:
	# SECURITY FIX: Use mutex to prevent race conditions
	_state_lock.lock()

	if not _player_states.has(peer_id):
		_init_player(peer_id)

	var info: Dictionary = _player_states[peer_id]
	var old_state: int = info.state

	# SECURITY FIX: Validate state transition
	if not _is_valid_transition(old_state, new_state):
		push_warning(
			(
				"[PlayerState] Invalid transition: %d -> %d for peer %d"
				% [old_state, new_state, peer_id]
			)
		)
		_state_lock.unlock()
		return

	if old_state != new_state:
		info.state = new_state

		# Reset action timer if becoming alive
		if new_state == Enums.PlayerState.ALIVE:
			info.last_action_time = Time.get_ticks_msec() / 1000.0

		# Sync
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			_sync_state.rpc(peer_id, new_state)

			# Propagate to MatchService for Scoreboard
			var ms: MatchSvc = MatchSvc.get_instance()
			if ms:
				ms.update_player_status(
					peer_id, 100 if new_state == Enums.PlayerState.ALIVE else 0, new_state
				)

		state_changed.emit(peer_id, old_state, new_state)

	_state_lock.unlock()


func _is_valid_transition(old_state: int, new_state: int) -> bool:
	# SECURITY FIX: Define valid state transitions to prevent invalid states
	# Allow any transition from/to AFK (special case)
	if old_state == Enums.PlayerState.AFK or new_state == Enums.PlayerState.AFK:
		return true

	match old_state:
		Enums.PlayerState.ALIVE:
			return new_state in [Enums.PlayerState.DOWNED, Enums.PlayerState.DEAD]
		Enums.PlayerState.DOWNED:
			return new_state in [Enums.PlayerState.ALIVE, Enums.PlayerState.DEAD]
		Enums.PlayerState.DEAD:
			return new_state == Enums.PlayerState.ALIVE  # Respawn only
		_:
			return true  # Unknown states - allow for flexibility


## Set player mode (PLAYING, SPECTATOR, EDITOR)


func set_player_mode(peer_id: int, new_mode: int) -> void:
	if not _player_states.has(peer_id):
		_init_player(peer_id)

	var info: Dictionary = _player_states[peer_id]
	var old_mode: int = info.mode

	if old_mode != new_mode:
		info.mode = new_mode

		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			_sync_mode.rpc(peer_id, new_mode)

		mode_changed.emit(peer_id, old_mode, new_mode)


## Register action (prevent AFK)


func register_action(peer_id: int) -> void:
	if _player_states.has(peer_id):
		_player_states[peer_id].last_action_time = Time.get_ticks_msec() / 1000.0
		# Use Enums.PlayerState for comparison
		if _player_states[peer_id].state == Enums.PlayerState.AFK:
			set_player_state(peer_id, Enums.PlayerState.ALIVE)  # Auto-wakeup


func get_player_state(peer_id: int) -> int:
	var def: int = Enums.PlayerState.ALIVE
	return _player_states.get(peer_id, {}).get("state", def)


func get_player_mode(peer_id: int) -> int:
	var def: int = int(Mode.PLAYING)
	return _player_states.get(peer_id, {}).get("mode", def)


# === INTERNAL ===


func _init_player(peer_id: int) -> void:
	_player_states[peer_id] = {
		"state": Enums.PlayerState.ALIVE,
		"mode": int(Mode.PLAYING),
		"last_action_time": Time.get_ticks_msec() / 1000.0
	}


# === RPCs ===

@rpc("authority", "call_remote", "reliable")
func _sync_state(peer_id: int, new_state: int) -> void:
	set_player_state(peer_id, new_state)


@rpc("authority", "call_remote", "reliable")
func _sync_mode(peer_id: int, new_mode: int) -> void:
	set_player_mode(peer_id, new_mode)


@rpc("any_peer", "call_remote", "reliable")
func request_set_mode(new_mode: int) -> void:
	if (
		not multiplayer.is_server()
		or not new_mode is int
		or new_mode < int(Mode.PLAYING)
		or new_mode > int(Mode.EDITOR)
	):
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return

	# RPC Rate Limiting Validation
	var network_mgr: Node = GameManager.get_core_system("network")
	if network_mgr and network_mgr.has_method("validate_rpc"):
		if not network_mgr.validate_rpc(sender_id, "set_player_mode", [new_mode]):
			GameManager.get_core_system("logger").warn(
				"[PlayerState] Rate limit exceeded for peer %d" % sender_id, "PlayerState"
			)
			return

	set_player_mode(sender_id, new_mode)


@rpc("any_peer", "call_remote", "reliable")
func request_set_state(new_state: int) -> void:
	if (
		not multiplayer.is_server()
		or not new_state is int
		or new_state < Enums.PlayerState.ALIVE
		or new_state > Enums.PlayerState.MENU
	):
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return

	# RPC Rate Limiting Validation
	var network_mgr: Node = GameManager.get_core_system("network")
	if network_mgr and network_mgr.has_method("validate_rpc"):
		if not network_mgr.validate_rpc(sender_id, "set_player_state", [new_state]):
			GameManager.get_core_system("logger").warn(
				"[PlayerState] Rate limit exceeded for peer %d" % sender_id, "PlayerState"
			)
			return


@rpc("any_peer", "call_remote", "reliable")
func request_assist_downed() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 0 or get_player_state(sender_id) != Enums.PlayerState.DOWNED:
		return
	# Logic for "Help me!" callout
	GameManager.get_core_system("logger").info(
		"Player %d requested assistance!" % sender_id, "PlayerState"
	)


@rpc("any_peer", "call_remote", "reliable")
func request_spectate_target(target_id: int) -> void:
	if not multiplayer.is_server() or not target_id is int:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 0 or not _player_states.has(target_id):
		return
	GameManager.get_core_system("logger").info(
		"Player %d requested to spectate %d" % [sender_id, target_id], "PlayerState"
	)


# === HANDLERS ===


func _on_peer_connected(id: int) -> void:
	_init_player(id)


func _on_peer_disconnected(id: int) -> void:
	_player_states.erase(id)
