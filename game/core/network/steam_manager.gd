class_name SteamManager
extends Node

const Constants = preload("res://game/core/constants.gd")

signal steam_initialized
signal steam_auth_ticket_validated(steam_id: int, response: int)
signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal lobby_join_failed(reason: String)
signal lobby_list_received(lobbies: Array)
signal lobby_member_joined(steam_id: int)
signal lobby_member_left(steam_id: int)
signal persona_state_changed(steam_id: int)
signal achievement_unlocked(achievement_name: String)

const AUTH_SESSION_UNAVAILABLE := -1

const LOBBY_TYPE_PRIVATE := 0
const LOBBY_TYPE_FRIENDS := 1
const LOBBY_TYPE_PUBLIC := 2
const LOBBY_TYPE_INVISIBLE := 3

var _steam_available: bool = false
var _is_server: bool = false
var _current_lobby_id: int = 0
var _steam_id: int = 0
var _steam_username: String = ""


## Helper to safely log messages
func _log_info(message: String, category: String = "Core") -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info(message, category)
			return
	print(message)


func _ready() -> void:
	_steam_available = _check_steam_available()

	if _steam_available:
		# We don't auto-init here because we might be a dedicated server
		# which requires different initialization.
		# Client init happens in _initialize_steam() called explicitly or via check.
		# For now, we assume client init unless told otherwise, but we'll safe check.
		if not DisplayServer.get_name() == "headless":
			_initialize_steam_client()
	else:
		_log_info("[SteamManager] Steam not available - using fallback networking")


func _check_steam_available() -> bool:
	# Check if GodotSteam is present
	return Engine.has_singleton("Steam") or ClassDB.class_exists("Steam")


## Initialize Steam for a Client


func _initialize_steam_client() -> void:
	if not _steam_available:
		return

	var steam: Object = Engine.get_singleton("Steam")
	var init_result: Variant = steam.steamInit(false)
	var init_success := false
	var init_verbal := "unknown result"
	if init_result is Dictionary:
		init_success = int(init_result.get("status", 0)) == 1
		init_verbal = str(init_result.get("verbal", init_verbal))
	elif init_result is bool:
		init_success = init_result
		init_verbal = "Steam API returned false"
	if not init_success:
		push_error("[SteamManager] Steam init failed: %s" % init_verbal)
		_steam_available = false
		return

	_steam_id = steam.getSteamID()
	_steam_username = steam.getPersonaName()
	_log_info("[SteamManager] Logged in as: %s (ID: %d)" % [_steam_username, _steam_id])

	_connect_steam_signals()
	steam_initialized.emit()


## Initialize Steam for a Dedicated Server


func initialize_steam_server(data: Dictionary) -> void:
	if not _steam_available:
		return
	_is_server = true

	var steam: Object = Engine.get_singleton("Steam")

	# Extract server config
	var ip: String = data.get("ip", "0.0.0.0")
	var game_port: int = data.get("steam_game_port", 27015)
	var query_port: int = data.get("steam_query_port", 27016)
	var server_mode: int = data.get("server_mode", 1)  # 1 = Auth, 2 = NoAuth, 3 = Password
	var version: String = data.get("version", Constants.GAME_VERSION)

	# Init Game Server
	var init_success: bool = steam.gameServerInit(ip, game_port, query_port, server_mode, version)

	if not init_success:
		push_error("[SteamManager] Failed to initialize Steam Game Server")
		return

	# Configure Server
	steam.gameServer_SetModDir("modus")
	steam.gameServer_SetProduct("modus")
	steam.gameServer_SetGameDescription(data.get("description", "MODUS Server"))
	steam.gameServer_SetServerName(data.get("name", "Unconfigured Server"))
	steam.gameServer_SetMaxPlayerCount(data.get("max_players", 16))
	steam.gameServer_SetPasswordProtected(false)
	steam.gameServer_SetDedicatedServer(true)

	# Login
	var token: String = data.get("steam_server_token", "")
	_connect_steam_signals()
	if token != "":
		steam.gameServer_LogOn(token)
	else:
		steam.gameServer_LogOnAnonymous()

	# Enable Heartbeats
	steam.gameServer_EnableHeartbeats(true)

	_log_info(
		"Steam Dedicated Server Initialized on ports %d/%d" % [game_port, query_port],
		"SteamManager"
	)

func _connect_steam_signals() -> void:
	var steam: Object = Engine.get_singleton("Steam")
	# Standard Lobbies - with safety checks
	if not steam.lobby_created.is_connected(_on_lobby_created):
		steam.lobby_created.connect(_on_lobby_created)
	if not steam.lobby_joined.is_connected(_on_lobby_joined):
		steam.lobby_joined.connect(_on_lobby_joined)
	if not steam.lobby_match_list.is_connected(_on_lobby_match_list):
		steam.lobby_match_list.connect(_on_lobby_match_list)
	if not steam.lobby_chat_update.is_connected(_on_lobby_chat_update):
		steam.lobby_chat_update.connect(_on_lobby_chat_update)
	if not steam.persona_state_change.is_connected(_on_persona_state_change):
		steam.persona_state_change.connect(_on_persona_state_change)
	if steam.has_signal("validate_auth_ticket_response"):
		if not steam.validate_auth_ticket_response.is_connected(_on_validate_auth_ticket_response):
			steam.validate_auth_ticket_response.connect(_on_validate_auth_ticket_response)


func _process(_delta: float) -> void:
	if _steam_available:
		var steam: Object = Engine.get_singleton("Steam")
		if _is_server:
			steam.gameServer_RunCallbacks()
		else:
			steam.run_callbacks()


# ============================================================================
# PUBLIC API - Steam Status
# ============================================================================

## Check if Steam is running and available


func is_steam_running() -> bool:
	return _steam_available and Engine.get_singleton("Steam") != null


## Get current user's Steam ID


func get_steam_id() -> int:
	return _steam_id


## Get current user's display name


func get_persona_name() -> String:
	if _steam_available:
		return _steam_username
	return "Player"


## Get friend's display name by Steam ID


func get_friend_persona_name(steam_id: int) -> String:
	if _steam_available:
		var steam: Object = Engine.get_singleton("Steam")
		return steam.getFriendPersonaName(steam_id)
	return "Player_%d" % steam_id


# ============================================================================
# PUBLIC API - Lobbies
# ============================================================================

## Create a new Steam lobby


func create_lobby(max_players: int = 8, lobby_type: int = LOBBY_TYPE_PUBLIC) -> void:
	if not _steam_available:
		push_error("[SteamManager] Cannot create lobby - Steam not available")
		return

	_log_info("[SteamManager] Creating lobby (max %d players)..." % max_players)
	var steam: Object = Engine.get_singleton("Steam")
	steam.createLobby(lobby_type, max_players)


## Join an existing lobby


func join_lobby(lobby_id: int) -> void:
	if not _steam_available:
		push_error("[SteamManager] Cannot join lobby - Steam not available")
		return

	_log_info("[SteamManager] Joining lobby: %d" % lobby_id)
	var steam: Object = Engine.get_singleton("Steam")
	steam.joinLobby(lobby_id)


## Leave current lobby


func leave_lobby() -> void:
	if _current_lobby_id == 0:
		return

	if _steam_available:
		_log_info("[SteamManager] Leaving lobby: %d" % _current_lobby_id)
		var steam: Object = Engine.get_singleton("Steam")
		steam.leaveLobby(_current_lobby_id)

	_current_lobby_id = 0


## Get current lobby ID (0 if not in a lobby)


func get_current_lobby_id() -> int:
	return _current_lobby_id


## Request list of available lobbies


func request_lobby_list() -> void:
	if not _steam_available:
		lobby_list_received.emit([])
		return

	_log_info("[SteamManager] Requesting lobby list...")
	var steam: Object = Engine.get_singleton("Steam")
	# Add default filter to find only our game's lobbies
	steam.addRequestLobbyListStringFilter("game", "modus", steam.LOBBY_COMPARISON_EQUAL)
	steam.requestLobbyList()


## Set lobby metadata (host only)


func set_lobby_data(key: String, value: String) -> bool:
	if _current_lobby_id == 0 or not _steam_available:
		return false

	var steam: Object = Engine.get_singleton("Steam")
	return steam.setLobbyData(_current_lobby_id, key, value)


## Get lobby metadata


func get_lobby_data(lobby_id: int, key: String) -> String:
	if not _steam_available:
		return ""

	var steam: Object = Engine.get_singleton("Steam")
	return steam.getLobbyData(lobby_id, key)


## Get number of members in a lobby


func get_lobby_member_count(lobby_id: int) -> int:
	if not _steam_available:
		return 0

	var steam: Object = Engine.get_singleton("Steam")
	return steam.getNumLobbyMembers(lobby_id)


## Get Steam ID of lobby member by index


func get_lobby_member_by_index(lobby_id: int, member_index: int) -> int:
	if not _steam_available:
		return 0

	var steam: Object = Engine.get_singleton("Steam")
	return steam.getLobbyMemberByIndex(lobby_id, member_index)


## Add a lobby list filter (string match)


func add_lobby_list_string_filter(key: String, value: String, comparison: int = 0) -> void:
	if not _steam_available:
		return

	var steam: Object = Engine.get_singleton("Steam")
	steam.addRequestLobbyListStringFilter(key, value, comparison)


# ============================================================================
# PUBLIC API - Auth & Dedicated Server
# ============================================================================

## Get an Auth Ticket to send to the server


func get_auth_ticket() -> Dictionary:
	if not _steam_available:
		return {}

	var steam: Object = Engine.get_singleton("Steam")
	# getAuthSessionTicket( identity_remote = 0 ) returning [id, ticket_buffer]
	# Modern steam uses getAuthSessionTicket with SteamNetworkingIdentity
	# But GodotSteam simply returns the dictionary with 'id' and 'buffer'
	var ticket: Dictionary = steam.getAuthSessionTicket()
	return ticket


## Begin Auth Session (Server Side)
## Returns k_EBeginAuthSessionResultOK only when Steam accepted the ticket.
## A successful call still remains pending until validate_auth_ticket_response.
## steam_id: The client's Steam ID
## ticket: The auth ticket buffer


func begin_auth_session(steam_id: int, ticket: Array) -> int:
	if not _steam_available:
		# Never report unavailable authentication as an accepted session.
		return AUTH_SESSION_UNAVAILABLE

	var steam: Object = Engine.get_singleton("Steam")
	if not steam:
		# The plugin class may exist while the runtime singleton is unavailable.
		return AUTH_SESSION_UNAVAILABLE
	# beginAuthSession( ticket_buffer, ticket_size, steam_id )
	var result: int = steam.beginAuthSession(ticket, ticket.size(), steam_id)
	return result  # 0 means the asynchronous validation started


## End Auth Session


func end_auth_session(steam_id: int) -> void:
	if not _steam_available:
		return

	var steam: Object = Engine.get_singleton("Steam")
	if steam:
		steam.endAuthSession(steam_id)


# ============================================================================
# PUBLIC API - Achievements
# ============================================================================

## Unlock a Steam achievement


func unlock_achievement(achievement_name: String) -> bool:
	if not _steam_available:
		_log_info("[SteamManager] Achievement unlocked (local): %s" % achievement_name)
		return true

	# Only unlock if not already achieved
	if is_achievement_unlocked(achievement_name):
		return true

	_log_info("[SteamManager] Unlocking achievement: %s" % achievement_name)
	var steam: Object = Engine.get_singleton("Steam")
	steam.setAchievement(achievement_name)
	steam.storeStats()

	achievement_unlocked.emit(achievement_name)
	return true


## Check if achievement is unlocked


func is_achievement_unlocked(achievement_name: String) -> bool:
	if not _steam_available:
		return false

	var steam: Object = Engine.get_singleton("Steam")
	var result: Dictionary = steam.getAchievement(achievement_name)
	if result.has("achieved"):
		return result["achieved"]
	return false


## Reset all achievements (for testing)


func reset_all_achievements() -> void:
	if not _steam_available:
		return

	_log_info("[SteamManager] Resetting all achievements...")
	var steam: Object = Engine.get_singleton("Steam")
	steam.resetAllStats(true)


# ============================================================================
# STEAM CALLBACKS
# ============================================================================


func _on_lobby_created(result: int, lobby_id: int) -> void:
	if result == 1:  # k_EResultOK
		_current_lobby_id = lobby_id
		_log_info("[SteamManager] Lobby created: %d" % lobby_id)

		# Set default lobby data
		set_lobby_data("game", "modus")
		set_lobby_data("version", Constants.GAME_VERSION)
		set_lobby_data("name", get_persona_name() + "'s Game")

		# Allow join via friends list
		var steam: Object = Engine.get_singleton("Steam")
		steam.setLobbyJoinable(lobby_id, true)

		lobby_created.emit(lobby_id)
	else:
		push_error("[SteamManager] Failed to create lobby: %d" % result)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, result: int) -> void:
	if result == 1:  # k_EResultOK
		_current_lobby_id = lobby_id
		_log_info("[SteamManager] Joined lobby: %d" % lobby_id)
		lobby_joined.emit(lobby_id)
	else:
		push_error("[SteamManager] Failed to join lobby: %d" % result)
		lobby_join_failed.emit("Join failed with result %d" % result)


func _on_lobby_match_list(lobbies: Array) -> void:
	_log_info("[SteamManager] Found %d lobbies" % lobbies.size())
	lobby_list_received.emit(lobbies)


func _on_lobby_chat_update(
	_lobby_id: int, changed_id: int, _making_change_id: int, chat_state: int
) -> void:
	# chat_state 1=Joined, 2=Left, 4=Disconnect, 8=Kicked, 16=Banned
	if chat_state == 1:
		lobby_member_joined.emit(changed_id)
	elif chat_state == 2 or chat_state == 4:
		lobby_member_left.emit(changed_id)


func _on_persona_state_change(steam_id: int, _flags: int) -> void:
	persona_state_changed.emit(steam_id)


func _on_validate_auth_ticket_response(
	steam_id: int, auth_session_response: int, _owner_steam_id: int
) -> void:
	steam_auth_ticket_validated.emit(steam_id, auth_session_response)


# ============================================================================
# NETWORKING INTEGRATION
# ============================================================================

## Get a multiplayer peer (Steam or ENet fallback)


func create_multiplayer_peer_host(_port: int = 9999) -> MultiplayerPeer:
	if not _steam_available:
		push_warning("[SteamManager] Cannot create Steam host - Steam not available")
		return null

	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		push_warning(
			"[SteamManager] Cannot create Steam host - SteamMultiplayerPeer class not found"
		)
		return null

	# Use Steam networking
	var steam_peer_class: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	if not steam_peer_class:
		push_error("[SteamManager] Failed to instantiate SteamMultiplayerPeer")
		return null

	_log_info("[SteamManager] Creating Steam Host...")
	# 0 for using the SteamNetworkingSockets, 0 is EServerMode.eServerModeNoAuthentication
	var err: int = steam_peer_class.create_host(0)
	if err == OK:
		return steam_peer_class

	push_error("[SteamManager] Failed to create Steam Host: %d" % err)
	return null


## Get a multiplayer peer for clients


func create_multiplayer_peer_client(host: String, _port: int = 9999) -> MultiplayerPeer:
	if not _steam_available:
		push_warning("[SteamManager] Cannot create Steam client - Steam not available")
		return null

	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		push_warning(
			"[SteamManager] Cannot create Steam client - SteamMultiplayerPeer class not found"
		)
		return null

	if not host.is_valid_int():
		push_warning("[SteamManager] Invalid Steam ID: %s" % host)
		return null

	# Use Steam networking if host is a SteamID
	_log_info("[SteamManager] Connecting to Steam Host: %s" % host)

	# Version check if in lobby
	if _current_lobby_id != 0:
		var lobby_version: String = get_lobby_data(_current_lobby_id, "version")
		if not lobby_version.is_empty() and lobby_version != Constants.GAME_VERSION:
			push_error(
				(
					"[SteamManager] Version mismatch! Client: %s, Server: %s"
					% [Constants.GAME_VERSION, lobby_version]
				)
			)
			return null

	var steam_peer_class: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	if not steam_peer_class:
		push_error("[SteamManager] Failed to instantiate SteamMultiplayerPeer")
		return null

	var err: int = steam_peer_class.create_client(host.to_int(), 0)
	if err == OK:
		return steam_peer_class

	push_error("[SteamManager] Failed to create Steam Client: %d" % err)
	return null


## Get multiplayer peer (fallback to ENet if Steam unavailable)


func get_multiplayer_peer() -> MultiplayerPeer:
	if _steam_available and ClassDB.class_exists("SteamMultiplayerPeer"):
		var steam_peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
		if steam_peer:
			return steam_peer

	# Fallback to ENet
	var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	return enet_peer


## Check if Steam is available


func is_steam_available() -> bool:
	return _steam_available
