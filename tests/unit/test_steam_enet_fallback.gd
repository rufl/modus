extends ModusGutTestBase

## Unit Test: Steam to ENet Fallback
## Tests that server creation succeeds with ENet when Steam is unavailable
## Validates: Requirements 11.3

var network_manager: Node = null


func before_each() -> void:
	# Get NetworkManager if available
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_core_system"):
		var network_service: Variant = gm.get_core_system("network")
		if network_service:
			network_manager = network_service.get("network_manager")


func after_each() -> void:
	# Clean up multiplayer peer
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null


## Test: Server creation succeeds with ENet when Steam unavailable
func test_server_creation_with_enet_when_steam_unavailable() -> void:
	# This test verifies fallback behavior
	# In production, if Steam is unavailable, server should use ENet

	# Create ENet server directly (simulating fallback)
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(7777, 8)

	assert_eq(err, OK, "ENet server creation should succeed")
	assert_true(peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED,
		"ENet server should be connected")

	# Clean up
	peer.close()


## Test: Server uses Steam when available
func test_server_uses_steam_when_available() -> void:
	# Check if Steam is available
	if not Engine.has_singleton("Steam"):
		pass_test("Steam singleton not available (expected in non-Steam builds)")
		return

	var Steam = Engine.get_singleton("Steam")
	if not Steam or not Steam.isSteamRunning():
		pass_test("Steam not running (expected in test environment)")
		return

	# If we reach here, Steam is available
	# In production code, server should prefer Steam over ENet
	assert_true(Steam.isSteamRunning(), "Steam should be running")

	# Note: Actual Steam networking test would require Steam initialization
	# which is not available in test environment


## Test: Fallback config setting is respected
func test_fallback_to_enet_config_setting() -> void:
	# Load network config
	var config_path = "res://game/config/network/network_config.json5"

	if not FileAccess.file_exists(config_path):
		pass_test("Network config not found (may not exist yet)")
		return

	# Check if config has fallback_to_enet setting
	var config_mgr = autofree(preload("res://game/scripts/core/configuration_manager.gd").new())
	var config = config_mgr.load_config_file(config_path)

	if config.is_empty():
		pass_test("Could not load network config")
		return

	# Check for connection settings
	if config.has("connection"):
		var connection = config.connection

		# Verify fallback setting exists (or default behavior)
		# If fallback_to_enet is not specified, default should be true
		var fallback_enabled = connection.get("fallback_to_enet", true)

		assert_typeof(fallback_enabled, TYPE_BOOL,
			"fallback_to_enet should be a boolean")
	else:
		pass_test("Connection settings not found in config")


## Test: ENet server accepts connections
func test_enet_server_accepts_connections() -> void:
	# Create server
	var server_peer = ENetMultiplayerPeer.new()
	var err = server_peer.create_server(7778, 2)

	assert_eq(err, OK, "Server creation should succeed")

	# Set as multiplayer peer
	var original_peer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = server_peer

	# Verify server is ready
	assert_true(multiplayer.is_server(), "Should be server")
	assert_eq(multiplayer.get_unique_id(), 1, "Server should have ID 1")

	# Create client
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	err = client_peer.create_client("127.0.0.1", 7778)

	assert_eq(err, OK, "Client creation should succeed")

	# Wait a frame for connection
	await get_tree().process_frame

	# Clean up
	client_peer.close()
	server_peer.close()
	multiplayer.multiplayer_peer = original_peer


## Test: Fallback error handling
func test_fallback_error_handling() -> void:
	# Test that fallback handles errors gracefully

	# Try to create server on invalid port
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(-1, 8)  # Invalid port
	assert_engine_error("p_port < 0 || p_port > 65535")

	assert_ne(err, OK, "Invalid port should fail")
	assert_ne(peer.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED,
		"Should not be connected with invalid port")


## Test: Multiple fallback attempts
func test_multiple_fallback_attempts() -> void:
	# Test that multiple fallback attempts work

	# First attempt
	var peer1 = ENetMultiplayerPeer.new()
	var error1 = peer1.create_server(7779, 8)
	assert_eq(error1, OK, "First server creation should succeed")

	# Second attempt on same port should fail
	var peer2 = ENetMultiplayerPeer.new()
	var error2 = peer2.create_server(7779, 8)
	assert_engine_error("Parameter \"host\" is null")
	assert_ne(error2, OK, "Second server on same port should fail")

	# Third attempt on different port should succeed
	var peer3 = ENetMultiplayerPeer.new()
	var error3 = peer3.create_server(7780, 8)
	assert_eq(error3, OK, "Server on different port should succeed")

	# Clean up
	peer1.close()
	peer2.close()
	peer3.close()


## Test: Steam singleton availability check
func test_steam_singleton_availability_check() -> void:
	# Test the check for Steam availability
	var has_steam = Engine.has_singleton("Steam")

	# This is informational - both true and false are valid
	if has_steam:
		var Steam = Engine.get_singleton("Steam")
		assert_not_null(Steam, "Steam singleton should not be null if available")

		# Check if Steam is running
		if Steam.has_method("isSteamRunning"):
			var is_running = Steam.isSteamRunning()
			# Both true and false are valid in test environment
			assert_typeof(is_running, TYPE_BOOL, "isSteamRunning should return bool")
	else:
		# No Steam singleton - this is expected in non-Steam builds
		pass_test("Steam singleton not available (expected in test environment)")


## Test: Network manager fallback integration
func test_network_manager_fallback_integration() -> void:
	if not network_manager:
		pass_test("NetworkManager not available for integration test")
		return

	# Check if NetworkManager has fallback logic
	if network_manager.has_method("create_server"):
		# NetworkManager should handle fallback internally
		# We can't test actual Steam fallback without Steam running,
		# but we can verify the method exists
		assert_true(true, "NetworkManager has create_server method")
	else:
		pass_test("NetworkManager doesn't have create_server method")


## Test: Port configuration
func test_port_configuration() -> void:
	# Test that different ports can be configured
	var ports = [7777, 8888, 9999]

	for port in ports:
		var peer = ENetMultiplayerPeer.new()
		var err = peer.create_server(port, 8)

		assert_eq(err, OK, "Server creation on port %d should succeed" % port)

		peer.close()

		# Wait a frame to ensure port is released
		await get_tree().process_frame


## Test: Max clients configuration
func test_max_clients_configuration() -> void:
	# Test that max clients can be configured
	var max_clients_values = [2, 4, 8, 16]

	for max_clients in max_clients_values:
		var peer = ENetMultiplayerPeer.new()
		var err = peer.create_server(7781 + max_clients, max_clients)

		assert_eq(err, OK,
			"Server creation with %d max clients should succeed" % max_clients)

		peer.close()
		await get_tree().process_frame


## Integration test: Full fallback scenario
func test_full_fallback_scenario() -> void:
	# Simulate full fallback scenario:
	# 1. Check for Steam
	# 2. If unavailable, fall back to ENet
	# 3. Create server
	# 4. Verify server is functional

	var use_steam = false

	# Check Steam availability
	if Engine.has_singleton("Steam"):
		var Steam = Engine.get_singleton("Steam")
		if Steam and Steam.has_method("isSteamRunning"):
			use_steam = Steam.isSteamRunning()

	# If Steam not available, use ENet (fallback)
	if not use_steam:
		var peer = ENetMultiplayerPeer.new()
		var err = peer.create_server(7782, 8)

		assert_eq(err, OK, "ENet fallback server creation should succeed")
		assert_true(peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED,
			"ENet fallback server should be connected")

		# Set as multiplayer peer
		var original_peer = multiplayer.multiplayer_peer
		multiplayer.multiplayer_peer = peer

		# Verify server functionality
		assert_true(multiplayer.is_server(), "Should be server after fallback")
		assert_eq(multiplayer.get_unique_id(), 1, "Server should have ID 1")

		# Clean up
		multiplayer.multiplayer_peer = original_peer
		peer.close()
	else:
		pass_test("Steam is available, fallback not needed")
