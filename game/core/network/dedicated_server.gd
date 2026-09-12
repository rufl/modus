class_name DedicatedServer
extends Node

signal server_started
signal server_stopped
signal mod_loaded(mod_name: String)

const CONFIG_PATH: String = "user://server_config.json5"
const MODS_DIR: String = "user://mods/"
const JSON5LoaderClass: GDScript = preload("res://game/core/json5_loader.gd")
const JSONHelperClass = preload("res://game/core/json_helper.gd")

var config: Dictionary = {}
var loaded_mods: Array[String] = []
var is_dedicated: bool = false

var _broadcaster: Node = null
var _steam_server_active: bool = false


## Helper function to safely access GameManager
func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _ready() -> void:
	# Check if running in headless/dedicated mode
	# Only activate for explicit dedicated-server launches. Generic headless
	# runs are used by tests and smoke checks, and must not bind sockets.
	var has_dedicated_feature: bool = OS.has_feature("dedicated_server")
	var has_dedicated_arg: bool = (
		OS.get_cmdline_args().has("--dedicated-server")
		or OS.get_cmdline_args().has("--modus-dedicated")
	)
	var has_dedicated_env: bool = (
		OS.has_environment("MODUS_DEDICATED_SERVER")
		and OS.get_environment("MODUS_DEDICATED_SERVER") == "1"
	)
	var is_editor: bool = OS.has_feature("editor") or Engine.is_editor_hint()

	is_dedicated = (
		(has_dedicated_feature or has_dedicated_arg or has_dedicated_env) and not is_editor
	)

	if is_dedicated:
		var gm: Node = _get_game_manager()
		if gm:
			var logger: Node = gm.get_core_system("logger")
			if logger and logger.has_method("info"):
				logger.info("[DedicatedServer] Running in dedicated server mode", "DedicatedServer")
		_initialize_server()
	else:
		# Still load config for potential hosting
		_load_config()


func _initialize_server() -> void:
	_load_config()
	_load_mods()
	_start_hosting()
	_start_steam_game_server()


## Load server configuration


func _load_config() -> void:
	# Try JSON5 first
	var json5_path: String = "user://server_config.json5"
	if FileAccess.file_exists(json5_path):
		var data: Variant = JSON5LoaderClass.load_file(json5_path)
		if data != null and typeof(data) == TYPE_DICTIONARY:
			config = data
			var gm: Node = _get_game_manager()
			if gm:
				var logger: Node = gm.get_core_system("logger")
				if logger and logger.has_method("info"):
					logger.info(
						"[DedicatedServer] Loaded JSON5 config: %s" % config, "DedicatedServer"
					)
			return

	# Fallback to JSON
	var json_path: String = "user://server_config.json"
	if FileAccess.file_exists(json_path):
		var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
		if file:
			var json: JSON = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				config = json.data
				var gm: Node = _get_game_manager()
				if gm:
					var logger2: Node = gm.get_core_system("logger")
					if logger2 and logger2.has_method("info"):
						logger2.info(
							"[DedicatedServer] Loaded JSON config: %s" % config, "DedicatedServer"
						)

				# Migration: Update old server name if found
				if config.get("server_name") == "Thauma Server":
					config["server_name"] = "Modus Server"
					_save_config()  # Helper to save

			file.close()
			return

	# Create default config if neither exists
	_create_default_config()


func _create_default_config() -> void:
	config = {
		"server_name": "Modus Server",
		"port": 7777,
		"max_players": 16,
		"map": "res://game/world/maps/showcase.tscn",
		"password": "",
		"mods": [],
		"difficulty": 1,
		"friendly_fire": false,
		"auto_save_interval": 300,
		"welcome_message": "Welcome to the server!"
	}

	_save_config()


func _save_config() -> void:
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSONHelperClass.safe_stringify(config, "\t"))
		file.close()
		var gm: Node = _get_game_manager()
		if gm:
			var logger: Node = gm.get_core_system("logger")
			if logger and logger.has_method("info"):
				logger.info(
					"[DedicatedServer] Saved config to: %s" % CONFIG_PATH, "DedicatedServer"
				)


## Load mods from config and mods folder


func _load_mods() -> void:
	# Ensure mods directory exists
	DirAccess.make_dir_recursive_absolute(MODS_DIR.replace("user://", OS.get_user_data_dir() + "/"))

	# Load mods from config
	var mod_list: Array = config.get("mods", [])

	for mod_name: String in mod_list:
		_load_mod(mod_name)

	# Scan mods folder for PCK, ZIP files, and folders
	var dir: DirAccess = DirAccess.open(MODS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			var mod_name: String = ""
			if file_name.ends_with(".pck"):
				mod_name = file_name.replace(".pck", "")
			elif file_name.ends_with(".zip"):
				mod_name = file_name.replace(".zip", "")
			elif dir.current_is_dir() and not file_name.begins_with("."):
				mod_name = file_name

			if mod_name != "" and mod_name not in loaded_mods:
				_load_mod(mod_name)
			file_name = dir.get_next()


func _load_mod(mod_name: String) -> bool:
	# Try PCK first
	var pck_path: String = MODS_DIR + mod_name + ".pck"
	if FileAccess.file_exists(pck_path):
		if ProjectSettings.load_resource_pack(pck_path):
			loaded_mods.append(mod_name)
			var gm: Node = _get_game_manager()
			if gm:
				var logger: Node = gm.get_core_system("logger")
				if logger and logger.has_method("info"):
					logger.info(
						"[DedicatedServer] Loaded PCK mod: %s" % mod_name, "DedicatedServer"
					)
			mod_loaded.emit(mod_name)
			return true
		push_error("[DedicatedServer] Failed to load PCK mod: ", mod_name)
		return false

	# Try ZIP (extract to temp location or load directly)
	var zip_path: String = MODS_DIR + mod_name + ".zip"
	if FileAccess.file_exists(zip_path):
		if _load_zip_mod(mod_name, zip_path):
			loaded_mods.append(mod_name)
			var gm: Node = _get_game_manager()
			if gm:
				var logger2: Node = gm.get_core_system("logger")
				if logger2 and logger2.has_method("info"):
					logger2.info(
						"[DedicatedServer] Loaded ZIP mod: %s" % mod_name, "DedicatedServer"
					)
			mod_loaded.emit(mod_name)
			return true
		push_error("[DedicatedServer] Failed to load ZIP mod: ", mod_name)
		return false

	# Try folder
	var folder_path: String = MODS_DIR + mod_name + "/"
	if DirAccess.dir_exists_absolute(folder_path):
		loaded_mods.append(mod_name)
		var gm: Node = _get_game_manager()
		if gm:
			var logger3: Node = gm.get_core_system("logger")
			if logger3 and logger3.has_method("info"):
				logger3.info(
					"[DedicatedServer] Registered folder mod: %s" % mod_name, "DedicatedServer"
				)
		mod_loaded.emit(mod_name)
		return true

	return false


## Load mod from ZIP file


func _is_safe_zip_entry(entry_path: String, extraction_root: String) -> bool:
	var normalized_path: String = entry_path.replace("\\", "/")
	if normalized_path.is_empty() or normalized_path.contains("://"):
		return false
	if (
		normalized_path.begins_with("/")
		or (normalized_path.length() >= 2 and normalized_path[1] == ":")
	):
		return false

	for component: String in normalized_path.split("/", true):
		if component == "..":
			return false

	var root_path: String = ProjectSettings.globalize_path(extraction_root).simplify_path()
	var target_path: String = (
		ProjectSettings.globalize_path(extraction_root.path_join(normalized_path)).simplify_path()
	)
	if not (target_path == root_path or target_path.begins_with(root_path + "/")):
		return false

	var root_parent: DirAccess = DirAccess.open(root_path.get_base_dir())
	if not root_parent or root_parent.is_link(root_path.get_file()):
		return false

	var current_path: String = root_path
	for component: String in normalized_path.split("/", true):
		if component.is_empty() or component == ".":
			continue
		current_path = current_path.path_join(component)
		var parent_dir: DirAccess = DirAccess.open(current_path.get_base_dir())
		if parent_dir and parent_dir.is_link(current_path.get_file()):
			return false
	return true


func _ensure_zip_directory(path: String) -> Error:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var dir_err: Error = DirAccess.make_dir_recursive_absolute(absolute_path)
	if dir_err != OK and not DirAccess.dir_exists_absolute(absolute_path):
		return dir_err
	return OK


func _load_zip_mod(mod_name: String, zip_path: String) -> bool:
	# Try to open the archive before creating any extraction paths.
	var reader: ZIPReader = ZIPReader.new()
	var err: Error = reader.open(zip_path)
	if err != OK:
		reader.close()
		push_error("[DedicatedServer] Cannot open ZIP: ", zip_path)
		return false

	# Extract to temp folder
	var extract_path: String = "user://mods_extracted/" + mod_name + "/"
	var root_err: Error = _ensure_zip_directory(extract_path)
	if root_err != OK:
		reader.close()
		push_error("[DedicatedServer] Cannot create ZIP extraction directory: ", extract_path)
		return false

	var files: PackedStringArray = reader.get_files()
	for file_path: String in files:
		if not _is_safe_zip_entry(file_path, extract_path):
			reader.close()
			push_error("[DedicatedServer] Unsafe ZIP entry: ", file_path)
			return false

		var normalized_path: String = file_path.replace("\\", "/")
		var full_path: String = extract_path.path_join(normalized_path)
		if normalized_path.ends_with("/"):
			var directory_err: Error = _ensure_zip_directory(full_path)
			if directory_err != OK:
				reader.close()
				push_error("[DedicatedServer] Cannot create ZIP directory: ", full_path)
				return false
			continue

		if not reader.file_exists(file_path):
			reader.close()
			push_error("[DedicatedServer] Cannot read ZIP entry: ", file_path)
			return false
		var content: PackedByteArray = reader.read_file(file_path)

		# Ensure directory exists
		var dir_err: Error = _ensure_zip_directory(full_path.get_base_dir())
		if dir_err != OK:
			reader.close()
			push_error("[DedicatedServer] Cannot create ZIP directory: ", full_path.get_base_dir())
			return false

		# Write file
		var file: FileAccess = FileAccess.open(full_path, FileAccess.WRITE)
		if not file:
			reader.close()
			push_error("[DedicatedServer] Cannot open extracted ZIP file: ", full_path)
			return false
		file.store_buffer(content)
		file.flush()
		var write_err: Error = file.get_error()
		file.close()
		if write_err != OK:
			reader.close()
			push_error("[DedicatedServer] Cannot write extracted ZIP file: ", full_path)
			return false

	reader.close()

	# Check if ZIP contains a PCK file
	var extracted_pck: String = extract_path + mod_name + ".pck"
	if FileAccess.file_exists(extracted_pck):
		return ProjectSettings.load_resource_pack(extracted_pck)

	# Otherwise treat as loose files (resources accessible via user://mods_extracted/mod_name/)
	return true


## Start hosting server


func _start_hosting() -> void:
	var port: int = config.get("port", 7777)
	var max_players: int = config.get("max_players", 16)

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, max_players)

	if err != OK:
		push_error("[DedicatedServer] Failed to start server on port ", port)
		return

	multiplayer.multiplayer_peer = peer

	var gm: Node = _get_game_manager()
	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[DedicatedServer] Server started on port %d" % port, "DedicatedServer")
			logger.info("[DedicatedServer] Max players: %d" % max_players, "DedicatedServer")
			logger.info("[DedicatedServer] Loaded mods: %s" % str(loaded_mods), "DedicatedServer")

	# Load the map after autoload initialization finishes; changing scenes in
	# an autoload's _ready callback races the scene tree's child bookkeeping.
	var map_path: String = config.get("map", "res://game/world.tscn")
	if ResourceLoader.exists(map_path):
		get_tree().call_deferred("change_scene_to_file", map_path)

	server_started.emit()

	# Start broadcasting server info
	_start_broadcasting()

	# Setup auto-save
	var save_interval: int = config.get("auto_save_interval", 300)
	if save_interval > 0:
		_setup_auto_save(save_interval)


func _setup_auto_save(interval: float) -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = interval
	timer.autostart = true
	if not timer.timeout.is_connected(_on_auto_save):
		timer.timeout.connect(_on_auto_save)
	add_child(timer)


func _on_auto_save() -> void:
	if multiplayer.is_server():
		var gm: Node = _get_game_manager()
		if gm:
			var logger: Node = gm.get_core_system("logger")
			if logger and logger.has_method("info"):
				logger.info("[DedicatedServer] Auto-saving...", "DedicatedServer")
			if gm.get_core_system("state_manager"):
				gm.get_core_system("state_manager").save_game("autosave")

			var gs: Node = gm.get_core_system("gameplay")
			if gs and gs.player:
				gs.player.save_all_players()


func _start_steam_game_server() -> void:
	if not config.get("steam_server", false):
		return

	# Check if SteamManager is available and GodotSteam installed
	var gm: Node = _get_game_manager()
	if not gm:
		return

	var ns: Node = gm.get_core_system("network")
	var steam: Node = ns.steam_manager if ns else null
	if not steam or not steam.is_steam_running():
		var logger: Node = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[DedicatedServer] Steam not available for Game Server", "DedicatedServer")
		return

	var logger2: Node = gm.get_core_system("logger")
	if logger2 and logger2.has_method("info"):
		logger2.info("[DedicatedServer] Initializing Steam Game Server...", "DedicatedServer")

	# Initialize via NetworkService.steam_manager
	var port: int = config.get("port", 7777)
	var max_players: int = config.get("max_players", 16)
	var server_name: String = config.get("server_name", "Modus Server")
	if steam.init_game_server(port, max_players, server_name, "Dedicated Server"):
		_steam_server_active = true
		var logger3: Node = gm.get_core_system("logger")
		if logger3 and logger3.has_method("info"):
			logger3.info(
				"[DedicatedServer] Steam Game Server initialized via SteamManager",
				"DedicatedServer"
			)


## Stop server


func stop_server() -> void:
	# Stop broadcasting
	if _broadcaster:
		_broadcaster.stop_broadcasting()

	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	server_stopped.emit()
	var gm: Node = _get_game_manager()
	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[DedicatedServer] Server stopped", "DedicatedServer")


## Start broadcasting server info on LAN


func _start_broadcasting() -> void:
	var ServerBroadcasterClass: GDScript = load("res://game/core/network/server_broadcaster.gd")
	_broadcaster = ServerBroadcasterClass.new()
	add_child(_broadcaster)
	_broadcaster.start_broadcasting(get_server_info())
	var gm: Node = _get_game_manager()
	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[DedicatedServer] Broadcasting server info on LAN", "DedicatedServer")


## Get server info


func get_server_info() -> Dictionary:
	return {
		"name": config.get("server_name", "Unknown"),
		"port": config.get("port", 7777),
		"max_players": config.get("max_players", 16),
		"current_players": multiplayer.get_peers().size() if multiplayer.multiplayer_peer else 0,
		"mods": loaded_mods,
		"map": config.get("map", ""),
		"password_protected": config.get("password", "") != ""
	}


## Check password


func verify_password(password: String) -> bool:
	var server_password: String = config.get("password", "")
	if server_password == "":
		return true
	return password == server_password


## Send welcome message to player


func send_welcome_message(peer_id: int) -> void:
	var message: String = config.get("welcome_message", "")
	if message != "":
		_receive_welcome.rpc_id(peer_id, message)


@rpc("authority", "reliable")
func _receive_welcome(message: String) -> void:
	var gm: Node = _get_game_manager()
	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[Server] %s" % message, "Server")
	# Could also display in UI


## Handle console commands (for dedicated server admins)


func handle_console_command(cmd: String) -> void:
	var parts: PackedStringArray = cmd.split(" ", false)
	if parts.size() == 0:
		return

	var command: String = parts[0].to_lower()

	match command:
		"help":
			_print_help()
		"perf":
			var gm: Node = _get_game_manager()
			if gm:
				var perf_service: Node = gm.get_core_system("performance")
				if perf_service and perf_service.has_method("print_performance_stats"):
					perf_service.print_performance_stats()
		"perf_report":
			var gm: Node = _get_game_manager()
			if gm:
				var perf_service: Node = gm.get_core_system("performance")
				if perf_service and perf_service.has_method("get_performance_report"):
					var report: Dictionary = perf_service.get_performance_report()
					var logger: Node = gm.get_core_system("logger")
					if logger and logger.has_method("info"):
						logger.info("\n=== Performance Report ===", "Core")
						logger.info(str(JSONHelperClass.safe_stringify(report, "\t")), "Core")
						logger.info("==========================\n", "Core")
		"pool_stats":
			var gm: Node = _get_game_manager()
			if gm:
				var pool_service: Node = gm.get_core_system("pools")
				if pool_service and pool_service.has_method("print_pool_stats"):
					pool_service.print_pool_stats()
		"optimize_ai":
			if multiplayer.is_server():
				var gm: Node = _get_game_manager()
				if gm:
					var perf_service: Node = gm.get_core_system("performance")
					if perf_service and perf_service.has_method("optimize_ai_pathfinding"):
						perf_service.optimize_ai_pathfinding()
			else:
				var gm: Node = _get_game_manager()
				if gm:
					var logger: Node = gm.get_core_system("logger")
					if logger and logger.has_method("info"):
						logger.info("Command only available on server", "Core")
		"save":
			var slot: String = parts[1] if parts.size() > 1 else "quicksave"
			var gm: Node = _get_game_manager()
			if gm and gm.get_core_system("state_manager"):
				gm.get_core_system("state_manager").save_game(slot)
		"load":
			var slot: String = parts[1] if parts.size() > 1 else "quicksave"
			var gm: Node = _get_game_manager()
			if gm and gm.get_core_system("state_manager"):
				gm.get_core_system("state_manager").load_game(slot)
		"list_players":
			_list_players()
		"kick":
			if parts.size() > 1:
				var peer_id: int = parts[1].to_int()
				multiplayer.multiplayer_peer.disconnect_peer(peer_id)
				var gm: Node = _get_game_manager()
				if gm:
					var logger: Node = gm.get_core_system("logger")
					if logger and logger.has_method("info"):
						logger.info("Kicked player: %d" % peer_id, "Core")
		"stop":
			stop_server()
			get_tree().quit()
		_:
			var gm: Node = _get_game_manager()
			if gm:
				var logger: Node = gm.get_core_system("logger")
				if logger and logger.has_method("info"):
					logger.info("Unknown command: %s" % command, "Core")
			_print_help()


func _print_help() -> void:
	var gm: Node = _get_game_manager()
	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("\n=== Server Console Commands ===", "Core")
			logger.info("help              - Show this help message", "Core")
			logger.info("perf              - Show performance statistics", "Core")
			logger.info("perf_report       - Show detailed performance report (JSON)", "Core")
			logger.info("pool_stats        - Show object pool statistics", "Core")
			logger.info("optimize_ai       - Manually optimize AI pathfinding", "Core")
			logger.info("save [slot]       - Save game (default: quicksave)", "Core")
			logger.info("load [slot]       - Load game (default: quicksave)", "Core")
			logger.info("list_players      - List connected players", "Core")
			logger.info("kick <peer_id>    - Kick player by peer ID", "Core")
			logger.info("stop              - Stop server and quit", "Core")
			logger.info("===============================\n", "Core")


func _list_players() -> void:
	var gm: Node = _get_game_manager()
	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("\n=== Connected Players ===", "Core")
			var peers: Array = multiplayer.get_peers()
			logger.info("Total: " + " " + str(peers.size()), "Core")
			for peer_id: int in peers:
				logger.info("  Peer ID: " + " " + str(peer_id), "Core")
			logger.info("=========================\n", "Core")
