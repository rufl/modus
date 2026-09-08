extends SceneTree

# Manual test for RPC rate limiting
# Run with: godot --headless --path . --script tests/manual_test_rpc_rate_limiting.gd


func _init():
	print("\n=== Manual RPC Rate Limiting Test ===\n")

	# Create a minimal test environment
	var root = get_root()

	# Create GameCore mock
	var game_manager = Node.new()
	game_manager.name = "GameManager"
	root.add_child(game_manager)

	# Create a simple logger mock
	var logger = Node.new()
	logger.name = "logger"
	game_manager.add_child(logger)

	# Add logger methods
	logger.set_script(load("res://tests/mocks/simple_logger.gd"))
	game_manager.set("logger", logger)

	# Create NetworkManager
	var network_manager_script = load("res://game/core/network/network_manager.gd")
	var network_manager = network_manager_script.new()
	network_manager.name = "NetworkManager"
	root.add_child(network_manager)

	# Wait a frame for initialization
	await create_timer(0.1).timeout

	# Test 1: Chat message rate limiting
	print("Test 1: Chat message rate limiting (3 calls/sec)")
	var peer_id = 2
	var result1 = network_manager.validate_rpc(peer_id, "send_chat_message", [])
	print("  First call: %s (expected: true)" % result1)

	var result2 = network_manager.validate_rpc(peer_id, "send_chat_message", [])
	print("  Second call (immediate): %s (expected: false)" % result2)

	# Wait for rate limit to expire
	await create_timer(0.4).timeout

	var result3 = network_manager.validate_rpc(peer_id, "send_chat_message", [])
	print("  Third call (after 0.4s): %s (expected: true)" % result3)

	# Test 2: Match service rate limiting
	print("\nTest 2: Match service update_player_status (10 calls/sec)")
	peer_id = 3
	var result4 = network_manager.validate_rpc(peer_id, "update_player_status", [peer_id, 100, 1])
	print("  First call: %s (expected: true)" % result4)

	var result5 = network_manager.validate_rpc(peer_id, "update_player_status", [peer_id, 100, 1])
	print("  Second call (immediate): %s (expected: false)" % result5)

	await create_timer(0.15).timeout

	var result6 = network_manager.validate_rpc(peer_id, "update_player_status", [peer_id, 100, 1])
	print("  Third call (after 0.15s): %s (expected: true)" % result6)

	# Test 3: Editor rate limiting
	print("\nTest 3: Editor place_block (10 calls/sec)")
	peer_id = 4
	var result7 = network_manager.validate_rpc(peer_id, "place_block", [{}])
	print("  First call: %s (expected: true)" % result7)

	var result8 = network_manager.validate_rpc(peer_id, "place_block", [{}])
	print("  Second call (immediate): %s (expected: false)" % result8)

	await create_timer(0.15).timeout

	var result9 = network_manager.validate_rpc(peer_id, "place_block", [{}])
	print("  Third call (after 0.15s): %s (expected: true)" % result9)

	# Test 4: Player state rate limiting
	print("\nTest 4: Player state set_player_state (5 calls/sec)")
	peer_id = 5
	var result10 = network_manager.validate_rpc(peer_id, "set_player_state", [1])
	print("  First call: %s (expected: true)" % result10)

	var result11 = network_manager.validate_rpc(peer_id, "set_player_state", [1])
	print("  Second call (immediate): %s (expected: false)" % result11)

	# Summary
	print("\n=== Test Summary ===")
	var all_passed = (
		result1 == true
		and result2 == false
		and result3 == true
		and result4 == true
		and result5 == false
		and result6 == true
		and result7 == true
		and result8 == false
		and result9 == true
		and result10 == true
		and result11 == false
	)

	if all_passed:
		print("✓ All tests PASSED")
		quit(0)
	else:
		print("✗ Some tests FAILED")
		quit(1)
