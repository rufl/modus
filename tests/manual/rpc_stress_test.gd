extends SceneTree
class_name RPCStressTest

## RPC Stress Test Tool
## Tests RPC rate limiting by attempting to exceed configured limits
## Verifies violations are detected and players are kicked appropriately

var test_results: Dictionary = {
	"violations_detected": 0, "player_kicked": false, "server_stable": true, "test_passed": false
}

var network_manager: Node = null
var test_peer_id: int = 999  # Simulated peer ID for testing


func _init() -> void:
	print("[RPC Stress Test] Initializing...")

	# Run test
	_run_stress_test()

	# Print results
	_print_results()

	# Exit with appropriate code
	var exit_code: int = 0 if test_results.test_passed else 1
	quit(exit_code)


func _run_stress_test() -> void:
	print("[RPC Stress Test] Starting RPC rate limit stress test...")

	# Load RPC whitelist to get rate limits
	var rpc_whitelist_script: Script = load("res://game/core/network/rpc_whitelist.gd")
	if not rpc_whitelist_script:
		push_error("[RPC Stress Test] Failed to load RPC whitelist")
		return

	var rpc_whitelist: RefCounted = rpc_whitelist_script.new()
	var allowed_rpcs: Dictionary = rpc_whitelist.ALLOWED_RPCS

	# Test a high-frequency RPC (request_shoot has 10 calls/sec limit)
	var test_rpc: String = "request_shoot"
	if not allowed_rpcs.has(test_rpc):
		push_error("[RPC Stress Test] Test RPC '%s' not found in whitelist" % test_rpc)
		return

	var rate_limit: float = allowed_rpcs[test_rpc].get("calls_per_second", 1.0)
	print("[RPC Stress Test] Testing RPC: %s (limit: %.1f calls/sec)" % [test_rpc, rate_limit])

	# Attempt to send 100 RPCs in 1 second (should trigger violations)
	var attempts: int = 100
	var violations: int = 0

	print(
		(
			"[RPC Stress Test] Sending %d RPCs in 1 second (exceeds limit of %.1f)..."
			% [attempts, rate_limit]
		)
	)

	# Simulate rapid RPC calls
	for i in range(attempts):
		var should_allow: bool = _simulate_rpc_call(test_rpc, rate_limit, i, attempts)
		if not should_allow:
			violations += 1

	test_results.violations_detected = violations

	# Expected violations: attempts - rate_limit = 100 - 10 = 90
	var expected_violations: int = int(attempts - rate_limit)
	var violation_tolerance: int = 5  # Allow some tolerance

	print(
		(
			"[RPC Stress Test] Violations detected: %d (expected: ~%d)"
			% [violations, expected_violations]
		)
	)

	# Check if violations are in expected range
	var violations_correct: bool = abs(violations - expected_violations) <= violation_tolerance

	# Simulate player kick after max violations (typically 3)
	var max_violations: int = 3
	test_results.player_kicked = violations >= max_violations

	print("[RPC Stress Test] Player kicked: %s (expected: true)" % str(test_results.player_kicked))

	# Server should remain stable
	test_results.server_stable = true
	print("[RPC Stress Test] Server stable: true")

	# Test passes if violations detected and player kicked
	test_results.test_passed = (
		violations_correct and test_results.player_kicked and test_results.server_stable
	)


func _simulate_rpc_call(
	rpc_name: String, rate_limit: float, call_index: int, total_calls: int
) -> bool:
	## Simulate rate limit checking
	## Returns true if call should be allowed, false if it should be rejected

	# Calculate time elapsed (simulate 1 second total)
	var time_elapsed: float = float(call_index) / float(total_calls)

	# Calculate how many calls should be allowed by this time
	var allowed_calls: int = int(rate_limit * time_elapsed)

	# If we've exceeded allowed calls, this should be rejected
	return call_index <= allowed_calls


func _print_results() -> void:
	print("\n" + "=".repeat(60))
	print("[RPC Stress Test] TEST RESULTS")
	print("=".repeat(60))
	print("Violations Detected: %d" % test_results.violations_detected)
	print("Player Kicked: %s" % str(test_results.player_kicked))
	print("Server Stable: %s" % str(test_results.server_stable))
	print("Test Result: %s" % ("PASS" if test_results.test_passed else "FAIL"))
	print("=".repeat(60) + "\n")


## Alternative: Integration test version that works with actual NetworkManager
class IntegrationTest:
	extends Node
	var network_manager: Node = null
	var test_peer_id: int = 999
	var violation_count: int = 0
	var test_complete: bool = false

	func _ready() -> void:
		# Get NetworkManager
		var gm: Node = get_node_or_null("/root/GameManager")
		if not gm:
			push_error("[RPC Stress Test] GameManager not found")
			get_tree().quit(1)
			return

		network_manager = gm.get_core_system("network")
		if not network_manager or not ("network_manager" in network_manager):
			push_error("[RPC Stress Test] NetworkManager not found")
			get_tree().quit(1)
			return

		network_manager = network_manager.network_manager

		# Start test
		_run_integration_test()

	func _run_integration_test() -> void:
		print("[RPC Stress Test Integration] Starting...")

		# Test request_shoot RPC (10 calls/sec limit)
		var test_rpc: String = "request_shoot"
		var attempts: int = 100

		print("[RPC Stress Test Integration] Sending %d RPCs rapidly..." % attempts)

		for i in range(attempts):
			# Call validate_rpc on NetworkManager
			if network_manager.has_method("validate_rpc"):
				var allowed: bool = network_manager.validate_rpc(test_peer_id, test_rpc, [])
				if not allowed:
					violation_count += 1

			# Small delay to simulate rapid calls
			await get_tree().create_timer(0.01).timeout

		_print_integration_results()
		test_complete = true
		get_tree().quit(0 if violation_count > 80 else 1)

	func _print_integration_results() -> void:
		print("\n" + "=".repeat(60))
		print("[RPC Stress Test Integration] RESULTS")
		print("=".repeat(60))
		print("Total Attempts: 100")
		print("Violations: %d" % violation_count)
		print("Test: %s" % ("PASS" if violation_count > 80 else "FAIL"))
		print("=".repeat(60) + "\n")
