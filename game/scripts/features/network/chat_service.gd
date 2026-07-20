extends Node
class_name ChatService

signal message_received(sender_name: String, message: String)

var max_message_length: int = 256
var rate_limit_seconds: float = 0.5
var show_timestamps: bool = true
var history_size: int = 50

var _last_message_time: float = 0.0


func initialize() -> void:
	_load_config()
	var cfg: Node = GameManager.get_core_system("config")
	if cfg:
		cfg.config_reloaded.connect(_on_config_reloaded)
	GameManager.get_core_system("logger").info("[Chat] Initialized", "Chat")


func _exit_tree() -> void:
	# === SIGNAL HYGIENE ===
	var cfg: Node = GameManager.get_core_system("config")
	if cfg:
		if cfg.config_reloaded.is_connected(_on_config_reloaded):
			cfg.config_reloaded.disconnect(_on_config_reloaded)


func _on_config_reloaded(_file_path: String = "") -> void:
	_load_config()
	GameManager.get_core_system("logger").debug("[Chat] Configuration reloaded", "Chat")


func _load_config() -> void:
	var cfg: Node = GameManager.get_core_system("config")
	if not cfg:
		return

	var data_result: Variant = cfg.get_value("visuals.chat")
	if data_result == null or not data_result is Dictionary:
		return

	var config: Dictionary = data_result
	if config.is_empty():
		return

	# Load values with fallbacks
	max_message_length = int(config.get("max_message_length", max_message_length))
	rate_limit_seconds = float(config.get("rate_limit_seconds", rate_limit_seconds))
	show_timestamps = bool(config.get("show_timestamps", show_timestamps))
	history_size = int(config.get("history_size", history_size))


## Send a chat message (Client -> Server)


func send_message(message: String) -> void:
	# Use GameCore dynamic check
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("GameManager"):
		var manager: Node = tree.root.get_node("GameManager")
		if not manager.is_feature_enabled("chat"):
			return

	if message.strip_edges().is_empty():
		return

	# Apply rate limiting
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_message_time < rate_limit_seconds:
		return
	_last_message_time = current_time

	# Truncate message if too long
	if message.length() > max_message_length:
		message = message.substr(0, max_message_length)

	if multiplayer.has_multiplayer_peer():
		_server_receive_message.rpc_id(1, message)
	else:
		# Offline / Singleplayer fallback
		message_received.emit("Player", message)


## Server receives message

@rpc("any_peer", "call_local", "reliable")
func _server_receive_message(message: String) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1  # Local host

	# RPC Rate Limiting Validation
	var network_mgr: Node = GameManager.get_core_system("network")
	if network_mgr and network_mgr.has_method("validate_rpc"):
		if not network_mgr.validate_rpc(sender_id, "send_chat_message", [message]):
			GameManager.get_core_system("logger").warn(
				"[Chat] Rate limit exceeded for peer %d" % sender_id, "Chat"
			)
			return

	# Get player name via GameplayService.match_service.
	var sender_name: String = "Unknown"
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	var match_service: Node = gs.match_service if gs else null
	if match_service and match_service.has_method("get_player_name"):
		sender_name = match_service.get_player_name(sender_id)
	else:
		sender_name = "Player " + str(sender_id)

	# Check for commands
	if message.begins_with("/"):
		_handle_command(sender_id, message)
		return

	# Broadcast to all clients
	_client_receive_message.rpc(sender_name, message)


func _handle_command(sender_id: int, message: String) -> void:
	var args: PackedStringArray = message.split(" ")
	var command: String = args[0].to_lower()

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var world: Node = tree.current_scene
	# Validate we are in the game world
	if not world or not world.has_method("spawn_player_node"):
		_send_system_message.rpc_id(sender_id, "Command only available in game.")
		return

	match command:
		"/spec":
			_send_system_message.rpc_id(sender_id, "Entering Spectator Mode...")
			world.remove_player(sender_id)
			world.spawn_player_node(sender_id, "editor")

		"/unspec":
			_send_system_message.rpc_id(sender_id, "Returning to game in 3 seconds...")
			world.remove_player(sender_id)

			# Wait 3 seconds then respawn
			await get_tree().create_timer(3.0).timeout

			# Check if player is still connected
			if sender_id in multiplayer.get_peers() or sender_id == 1:
				world.spawn_player_node(sender_id, "player")

		_:
			_send_system_message.rpc_id(sender_id, "Unknown command: " + command)


@rpc("authority", "call_local", "reliable")
func _send_system_message(message: String) -> void:
	message_received.emit("[SYSTEM]", message)
	GameManager.get_core_system("logger").info("[Chat] [SYSTEM]: %s" % message, "Chat")


## Client receives message

@rpc("authority", "call_local", "reliable")
func _client_receive_message(sender_name: String, message: String) -> void:
	message_received.emit(sender_name, message)
	GameManager.get_core_system("logger").debug("[Chat] %s: %s" % [sender_name, message], "Chat")
