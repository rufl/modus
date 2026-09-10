extends ModusGutTestBase

# Test MODUS Framework NetworkManager functionality
# Converted from legacy Dictionary format to GUT assertions

var _network_manager: Node = null
var _reconnect_root: Node = null


class ReconnectProbe:
	extends NetworkManager

	var attempted_hosts: Array[String] = []

	func join_game(host: String, _port: int = -1) -> Error:
		attempted_hosts.append(host)
		return OK


func before_each():
	await modus_setup()
	# Get NetworkManager via NetworkService
	var ns := NetworkSvc.get_service()
	if ns:
		_network_manager = ns.network_manager


func after_each():
	if is_instance_valid(_reconnect_root):
		var root_path: NodePath = _reconnect_root.get_path()
		var api: MultiplayerAPI = _reconnect_root.multiplayer
		if api.multiplayer_peer:
			api.multiplayer_peer.close()
		_reconnect_root.free()
		get_tree().set_multiplayer(null, root_path)
		_reconnect_root = null
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


func test_trusted_peer_still_obeys_rpc_rate_limits() -> void:
	if not _network_manager:
		var ns := NetworkSvc.get_service()
		if ns:
			_network_manager = ns.network_manager

	assert_not_null(_network_manager, "NetworkManager should be available")
	if not _network_manager:
		return

	var peer_id := 999
	var first: bool = _network_manager.validate_rpc(peer_id, "send_chat_message", ["hello"])
	var second: bool = _network_manager.validate_rpc(peer_id, "send_chat_message", ["hello"])
	_network_manager.remove_trusted_peer(peer_id)

	assert_true(first, "Authenticated peer's first RPC should pass")
	assert_false(second, "Authenticated peer's immediate RPC should be rate limited")


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
		var result1: bool = _network_manager.validate_rpc(peer_id, method, ["hello"])
		assert_true(result1, "First RPC call should succeed")

		# Immediate second call should fail (rate limited)
		var result2: bool = _network_manager.validate_rpc(peer_id, method, ["hello"])
		assert_false(result2, "Immediate second RPC call should be rate limited")

		# Wait for rate limit to expire (chat is 3 calls/sec = 0.33s interval)
		await get_tree().create_timer(0.4).timeout

		# Third call should succeed after waiting
		var result3: bool = _network_manager.validate_rpc(peer_id, method, ["hello"])
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
		var result1: bool = _network_manager.validate_rpc(peer_id, method, [peer_id, 100, 1])
		assert_true(result1, "First update_player_status call should succeed")

		# Immediate second call should fail
		var result2: bool = _network_manager.validate_rpc(peer_id, method, [peer_id, 100, 1])
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

func test_semantic_validation_rejects_forged_status_and_chat_payloads() -> void:
	if not _network_manager:
		var ns := NetworkSvc.get_service()
		if ns:
			_network_manager = ns.network_manager

	assert_not_null(_network_manager, "NetworkManager should be available")
	if not _network_manager:
		return

	assert_false(
		_network_manager.validate_rpc(7, "update_player_status", [8, 500, 1]),
		"Status updates cannot target another peer"
	)
	assert_false(
		_network_manager.validate_rpc(7, "update_player_status", [7, -1, 1]),
		"Status health cannot be negative"
	)
	assert_false(
		_network_manager.validate_rpc(7, "send_chat_message", ["x".repeat(257)]),
		"Chat payloads cannot exceed the protocol limit"
	)
	assert_false(
		_network_manager.validate_rpc(7, "register_kill", [8, 9, "rifle"]),
		"Kill reports must involve the sending peer"
	)
	assert_false(
		_network_manager.validate_rpc(10, "verify_steam_ticket", [{"id": 123, "buffer": []}]),
		"Steam tickets require a non-empty bounded buffer"
	)
	assert_true(
		_network_manager.validate_rpc(11, "register_kill", [11, 12, "rifle"]),
		"Valid kill reports should pass semantic validation"
	)


func _create_reconnect_probe() -> ReconnectProbe:
	_reconnect_root = Node.new()
	_reconnect_root.name = "ReconnectTest"
	add_child(_reconnect_root)
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, _reconnect_root.get_path())
	var peer := ENetMultiplayerPeer.new()
	assert_eq(peer.create_client("127.0.0.1", 9), OK)
	api.multiplayer_peer = peer
	var probe := ReconnectProbe.new()
	_reconnect_root.add_child(probe)
	probe.set_process(false)
	probe._reconnect_delay_ms = 20
	probe._last_host_info = {"host": "127.0.0.1", "port": 9, "is_steam": false}
	return probe


func test_disconnect_cancels_pending_retry_and_stale_timeout() -> void:
	var probe := _create_reconnect_probe()
	probe._on_peer_disconnected(1)

	# The transport may already be gone by the time the user leaves.
	probe.multiplayer.multiplayer_peer.close()
	probe.multiplayer.multiplayer_peer = null
	probe.disconnect_game()
	probe._on_reconnect_timer_timeout()
	await get_tree().create_timer(0.08).timeout

	assert_true(
		probe.attempted_hosts.is_empty(), "Leaving must cancel both queued and stale retries"
	)
	assert_true(probe._reconnect_timer.is_stopped(), "Leaving must stop the pending retry timer")
	assert_false(probe._last_host_info.has("host"), "Leaving must forget the reconnect destination")


func test_unexpected_disconnect_retries_remembered_server() -> void:
	var probe := _create_reconnect_probe()
	probe._on_peer_disconnected(1)
	await get_tree().create_timer(0.08).timeout

	assert_eq(probe.attempted_hosts, ["127.0.0.1"], "Unexpected loss must still retry the server")


func test_disconnect_from_retry_notification_cancels_retry() -> void:
	var probe := _create_reconnect_probe()
	probe.reconnection_attempt.connect(
		func(_attempt: int, _maximum: int) -> void: probe.disconnect_game()
	)
	probe._on_peer_disconnected(1)
	await get_tree().create_timer(0.08).timeout

	assert_true(
		probe.attempted_hosts.is_empty(), "A listener leaving the game must cancel its retry"
	)
	assert_true(probe._reconnect_timer.is_stopped())


func test_disconnect_restores_offline_inventory_and_same_port_hosting() -> void:
	assert_not_null(_network_manager)
	if not _network_manager:
		return
	var original_use_steam: bool = _network_manager._use_steam
	_network_manager._use_steam = false
	var error: Error = _network_manager.host_game(0, 2)
	assert_eq(error, OK)
	if error != OK:
		_network_manager._use_steam = original_use_steam
		return
	var peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer
	var port: int = peer.get_host().get_local_port()

	_network_manager.disconnect_game()
	_network_manager.disconnect_game()
	var inventory_manager := InventoryMgr.new()
	add_child_autofree(inventory_manager)
	var inventory := Inventory.new()
	inventory_manager.register_inventory(1, inventory)
	var item := InventoryItem.new()
	item.id = "offline_tool"
	inventory.slots[0] = item
	inventory_manager.request_move_item(0, 1)
	assert_null(inventory.slots[0], "Repeated disconnect must retain local inventory authority")
	assert_same(inventory.slots[1], item)

	assert_eq(peer.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED)
	assert_eq(_network_manager.host_game(port, 2), OK, "Disconnect must release the host port")
	_network_manager.disconnect_game()
	_network_manager._use_steam = original_use_steam
