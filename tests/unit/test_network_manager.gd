extends ModusGutTestBase

# Test MODUS Framework NetworkManager functionality
# Converted from legacy Dictionary format to GUT assertions

var _network_manager: Node = null

func before_each():
	await modus_setup()
	# Get NetworkManager via NetworkService
	var ns := NetworkSvc.get_service()
	if ns:
		_network_manager = ns.network_manager

func after_each():
	modus_teardown()

func test_service_exists():
	# Test that NetworkService is accessible
	var ns := NetworkSvc.get_service()
	assert_not_null(ns, "NetworkSvc.get_service() should return valid service")

func test_autoload_exists():
	if not _network_manager:
		# Try getting it again (setup might not have been called)
		var ns := NetworkSvc.get_service()
		if ns:
			_network_manager = ns.network_manager

	assert_not_null(_network_manager, "NetworkManager should be found via NetworkSvc.get_service()")

func test_validation_toggle():
	if not _network_manager:
		var ns := NetworkSvc.get_service()
		if ns:
			_network_manager = ns.network_manager

	assert_not_null(_network_manager, "NetworkManager should be available")

	if _network_manager:
		# Test enabling/disabling validation
		_network_manager.set_validation_enabled(false)
		_network_manager.set_validation_enabled(true)

		# If we got here without crashing, it works
		assert_true(true, "Validation toggle should work without errors")

func test_validate_rpc_server_trusted():
	if not _network_manager:
		var ns := NetworkSvc.get_service()
		if ns:
			_network_manager = ns.network_manager

	assert_not_null(_network_manager, "NetworkManager should be available")

	if _network_manager:
		# Server (peer 1) should always be trusted
		var result: bool = _network_manager.validate_rpc(1, "test_method", [])
		assert_true(result, "Server peer should be trusted")

func test_add_trusted_peer():
	if not _network_manager:
		var ns := NetworkSvc.get_service()
		if ns:
			_network_manager = ns.network_manager

	assert_not_null(_network_manager, "NetworkManager should be available")

	if _network_manager:
		# Test adding/removing trusted peers
		_network_manager.add_trusted_peer(999)
		_network_manager.remove_trusted_peer(999)

		# If we got here without crashing, it works
		assert_true(true, "Trusted peer management should work without errors")

func test_get_network_stats():
	if not _network_manager:
		var ns := NetworkSvc.get_service()
		if ns:
			_network_manager = ns.network_manager

	assert_not_null(_network_manager, "NetworkManager should be available")

	if _network_manager:
		# Test stats retrieval
		var stats: Dictionary = _network_manager.get_network_stats()

		assert_eq(typeof(stats), TYPE_DICTIONARY, "get_network_stats should return dictionary")

		# Should have expected keys
		assert_dict_has_key(stats, "is_server", "Stats should have is_server key")

func test_rpc_rate_limiting():
	if not _network_manager:
		var ns := NetworkSvc.get_service()
		if ns:
			_network_manager = ns.network_manager

	assert_not_null(_network_manager, "NetworkManager should be available")

	if _network_manager:
		# Test rate limiting for a method
		var peer_id: int = 2  # Non-server peer
		var method: String = "send_chat_message"

		# First call should succeed
		var result1: bool = _network_manager.validate_rpc(peer_id, method, [])
		assert_true(result1, "First RPC call should succeed")

		# Immediate second call should fail (rate limited)
		var result2: bool = _network_manager.validate_rpc(peer_id, method, [])
		assert_false(result2, "Immediate second RPC call should be rate limited")

		# Wait for rate limit to expire (chat is 3 calls/sec = 0.33s interval)
		await get_tree().create_timer(0.4).timeout

		# Third call should succeed after waiting
		var result3: bool = _network_manager.validate_rpc(peer_id, method, [])
		assert_true(result3, "RPC call after rate limit cooldown should succeed")


func test_rpc_rate_limiting_match_service():
	if not _network_manager:
		var ns := NetworkSvc.get_service()
		if ns:
			_network_manager = ns.network_manager

	assert_not_null(_network_manager, "NetworkManager should be available")

	if _network_manager:
		# Test rate limiting for match service RPCs
		var peer_id: int = 3
		var method: String = "update_player_status"

		# Should allow up to 10 calls per second (0.1s interval)
		var result1: bool = _network_manager.validate_rpc(peer_id, method, [100, 1])
		assert_true(result1, "First update_player_status call should succeed")

		# Immediate second call should fail
		var result2: bool = _network_manager.validate_rpc(peer_id, method, [100, 1])
		assert_false(result2, "Immediate second update_player_status call should be rate limited")


func test_rpc_rate_limiting_editor():
	if not _network_manager:
		var ns := NetworkSvc.get_service()
		if ns:
			_network_manager = ns.network_manager

	assert_not_null(_network_manager, "NetworkManager should be available")

	if _network_manager:
		# Test rate limiting for editor RPCs
		var peer_id: int = 4
		var method: String = "place_block"

		# Should allow up to 10 calls per second (0.1s interval)
		var result1: bool = _network_manager.validate_rpc(peer_id, method, [{}])
		assert_true(result1, "First place_block call should succeed")

		# Immediate second call should fail
		var result2: bool = _network_manager.validate_rpc(peer_id, method, [{}])
		assert_false(result2, "Immediate second place_block call should be rate limited")

		# Wait for rate limit to expire
		await get_tree().create_timer(0.15).timeout

		# Third call should succeed
		var result3: bool = _network_manager.validate_rpc(peer_id, method, [{}])
		assert_true(result3, "place_block call after cooldown should succeed")
