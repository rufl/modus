extends SceneTree

# Simple synchronous test for RPC rate limiting
# Run with: godot --headless --path . --script tests/simple_rate_limit_test.gd


func _init():
	print("\n=== Simple RPC Rate Limiting Test ===\n")

	# Create NetworkManager
	var network_manager_script = load("res://game/core/network/network_manager.gd")
	var network_manager = network_manager_script.new()
	get_root().add_child(network_manager)

	# Test 1: Verify rate limits are configured
	print("Test 1: Verify rate limits are configured")
	var has_chat_limit = network_manager._rpc_rate_limits.has("send_chat_message")
	var has_status_limit = network_manager._rpc_rate_limits.has("update_player_status")
	var has_place_limit = network_manager._rpc_rate_limits.has("place_block")
	var has_delete_limit = network_manager._rpc_rate_limits.has("delete_node")
	var has_paint_limit = network_manager._rpc_rate_limits.has("paint_block")
	var has_state_limit = network_manager._rpc_rate_limits.has("set_player_state")
	var has_mode_limit = network_manager._rpc_rate_limits.has("set_player_mode")

	print("  send_chat_message: %s" % has_chat_limit)
	print("  update_player_status: %s" % has_status_limit)
	print("  place_block: %s" % has_place_limit)
	print("  delete_node: %s" % has_delete_limit)
	print("  paint_block: %s" % has_paint_limit)
	print("  set_player_state: %s" % has_state_limit)
	print("  set_player_mode: %s" % has_mode_limit)

	# Test 2: Verify rate limit values
	print("\nTest 2: Verify rate limit values")
	if has_chat_limit:
		var chat_limit = network_manager._rpc_rate_limits["send_chat_message"]["calls_per_second"]
		print("  send_chat_message: %.1f calls/sec" % chat_limit)

	if has_status_limit:
		var status_limit = (
			network_manager._rpc_rate_limits["update_player_status"]["calls_per_second"]
		)
		print("  update_player_status: %.1f calls/sec" % status_limit)

	if has_place_limit:
		var place_limit = network_manager._rpc_rate_limits["place_block"]["calls_per_second"]
		print("  place_block: %.1f calls/sec" % place_limit)

	if has_delete_limit:
		var delete_limit = network_manager._rpc_rate_limits["delete_node"]["calls_per_second"]
		print("  delete_node: %.1f calls/sec" % delete_limit)

	if has_paint_limit:
		var paint_limit = network_manager._rpc_rate_limits["paint_block"]["calls_per_second"]
		print("  paint_block: %.1f calls/sec" % paint_limit)

	if has_state_limit:
		var state_limit = network_manager._rpc_rate_limits["set_player_state"]["calls_per_second"]
		print("  set_player_state: %.1f calls/sec" % state_limit)

	if has_mode_limit:
		var mode_limit = network_manager._rpc_rate_limits["set_player_mode"]["calls_per_second"]
		print("  set_player_mode: %.1f calls/sec" % mode_limit)

	# Test 3: Basic rate limiting functionality
	print("\nTest 3: Basic rate limiting functionality")
	var peer_id = 2
	var result1 = network_manager.validate_rpc(peer_id, "send_chat_message", [])
	print("  First call: %s (expected: true)" % result1)

	var result2 = network_manager.validate_rpc(peer_id, "send_chat_message", [])
	print("  Second call (immediate): %s (expected: false)" % result2)

	# Summary
	print("\n=== Test Summary ===")
	var all_configured = (
		has_chat_limit
		and has_status_limit
		and has_place_limit
		and has_delete_limit
		and has_paint_limit
		and has_state_limit
		and has_mode_limit
	)
	var basic_works = result1 == true and result2 == false

	if all_configured and basic_works:
		print("✓ All tests PASSED")
		print("  - All rate limits configured")
		print("  - Basic rate limiting works")
		quit(0)
	else:
		print("✗ Some tests FAILED")
		if not all_configured:
			print("  - Not all rate limits configured")
		if not basic_works:
			print("  - Basic rate limiting not working")
		quit(1)
