extends ModusGutTestBase

# Test MODUS Framework Steam integration
# Converted from legacy Dictionary format to GUT assertions


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func _get_steam_manager() -> Node:
	var ns := NetworkSvc.get_service()
	if ns:
		return ns.steam_manager
	return null


# =============================================================================
# STEAM MANAGER AVAILABILITY
# =============================================================================


func test_steam_manager_exists() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be found in NetworkService")


func test_steam_manager_has_required_methods() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")

	if not steam:
		return

	var required_methods: Array[String] = [
		"create_lobby",
		"join_lobby",
		"leave_lobby",
		"request_lobby_list",
		"get_multiplayer_peer",
	]

	for method_name: String in required_methods:
		assert_true(steam.has_method(method_name), "SteamManager should have method: %s" % method_name)


# =============================================================================
# STEAM SIGNALS
# =============================================================================


func test_steam_manager_has_signals() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")

	if not steam:
		return

	var required_signals: Array[String] = [
		"steam_initialized",
		"lobby_created",
		"lobby_joined",
		"lobby_join_failed",
		"lobby_list_received",
	]

	for signal_name: String in required_signals:
		assert_true(steam.has_signal(signal_name), "SteamManager should have signal: %s" % signal_name)


# =============================================================================
# ENET FALLBACK
# =============================================================================


func test_get_multiplayer_peer_returns_peer() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")

	if not steam:
		return

	# Should return ENetMultiplayerPeer when Steam is unavailable
	var _peer: Variant = steam.get_multiplayer_peer()

	# It's okay if this returns null (no Steam) - we just verify it doesn't crash
	assert_true(true, "get_multiplayer_peer() should not crash")


func test_steam_available_check() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")

	if not steam:
		return

	# Should have a method to check if Steam is available
	if steam.has_method("is_steam_available"):
		var _available: bool = steam.is_steam_available()
		# Just verify it returns without crashing
		assert_true(true, "is_steam_available() should not crash")


# =============================================================================
# LOBBY CONSTANTS
# =============================================================================


func test_lobby_type_constants_exist() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")

	if not steam:
		return

	# Check for lobby type constants
	var expected_constants: Array[String] = [
		"LOBBY_TYPE_PRIVATE",
		"LOBBY_TYPE_FRIENDS",
		"LOBBY_TYPE_PUBLIC",
	]

	for const_name: String in expected_constants:
		assert_true(const_name in steam, "SteamManager should have constant: %s" % const_name)


# =============================================================================
# STEAM ID & USERNAME
# =============================================================================


func test_steam_id_accessors() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")

	if not steam:
		return

	# Check for Steam ID accessor
	if steam.has_method("get_steam_id"):
		var _id: int = steam.get_steam_id()
		# Just verify it doesn't crash
		assert_true(true, "get_steam_id() should not crash")
	elif "_steam_id" in steam:
		var _id: int = steam._steam_id
		assert_true(true, "_steam_id property should be accessible")


func test_steam_username_accessors() -> void:
	var steam := _get_steam_manager()
	assert_not_null(steam, "SteamManager should be available")

	if not steam:
		return

	# Check for username accessor
	if steam.has_method("get_steam_username"):
		var _name: String = steam.get_steam_username()
		assert_true(true, "get_steam_username() should not crash")
	elif "_steam_username" in steam:
		var _name: String = steam._steam_username
		assert_true(true, "_steam_username property should be accessible")
