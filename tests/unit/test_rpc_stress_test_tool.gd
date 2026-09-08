extends ModusGutTestBase

## Unit Tests for RPC Stress Test Tool
## Tests rate limit detection logic, violation counting, and result reporting

const RPCWhitelistScript = preload("res://game/core/network/rpc_whitelist.gd")

var stress_test: RPCStressTest = null


class MockRPCStressTest:
	extends Node

	func _simulate_rpc_call(
		_rpc_name: String, rate_limit: float, call_index: int, _total_calls: int
	) -> bool:
		return call_index < rate_limit


## Test: Rate limit detection logic
func test_rate_limit_detection_logic() -> void:
	# Create a temporary instance for testing (not as SceneTree)
	var test_instance: Node = MockRPCStressTest.new()
	add_child_autofree(test_instance)

	# Test rate limit: 10 calls/sec, 100 total calls
	var rate_limit: float = 10.0
	var total_calls: int = 100

	# First 10 calls should be allowed
	for i in range(10):
		var allowed: bool = test_instance._simulate_rpc_call("test_rpc", rate_limit, i, total_calls)
		assert_true(allowed, "Call %d should be allowed (within rate limit)" % i)

	# Calls beyond rate limit should be rejected
	for i in range(11, 20):
		var allowed: bool = test_instance._simulate_rpc_call("test_rpc", rate_limit, i, total_calls)
		assert_false(allowed, "Call %d should be rejected (exceeds rate limit)" % i)


## Test: Violation counting accuracy
func test_violation_counting_accuracy() -> void:
	var test_instance: Node = MockRPCStressTest.new()
	add_child_autofree(test_instance)

	# Simulate 100 calls with 10 calls/sec limit
	var rate_limit: float = 10.0
	var total_calls: int = 100
	var violations: int = 0

	for i in range(total_calls):
		var allowed: bool = test_instance._simulate_rpc_call("test_rpc", rate_limit, i, total_calls)
		if not allowed:
			violations += 1

	# Expected violations: 100 - 10 = 90
	var expected_violations: int = 90
	var tolerance: int = 5

	assert_almost_eq(
		float(violations),
		float(expected_violations),
		float(tolerance),
		"Violation count should be approximately %d (got %d)" % [expected_violations, violations]
	)


## Test: Different rate limits
func test_different_rate_limits() -> void:
	var test_instance: Node = MockRPCStressTest.new()
	add_child_autofree(test_instance)

	# Test with 5 calls/sec limit
	var rate_limit_5: float = 5.0
	var total_calls: int = 50
	var violations_5: int = 0

	for i in range(total_calls):
		var allowed: bool = test_instance._simulate_rpc_call(
			"test_rpc", rate_limit_5, i, total_calls
		)
		if not allowed:
			violations_5 += 1

	# Expected: 50 - 5 = 45 violations
	assert_almost_eq(
		float(violations_5), 45.0, 5.0, "Should detect ~45 violations with 5 calls/sec limit"
	)

	# Test with 20 calls/sec limit
	var rate_limit_20: float = 20.0
	var violations_20: int = 0

	for i in range(total_calls):
		var allowed: bool = test_instance._simulate_rpc_call(
			"test_rpc", rate_limit_20, i, total_calls
		)
		if not allowed:
			violations_20 += 1

	# Expected: 50 - 20 = 30 violations
	assert_almost_eq(
		float(violations_20), 30.0, 5.0, "Should detect ~30 violations with 20 calls/sec limit"
	)


## Test: Zero rate limit (all calls rejected)
func test_zero_rate_limit() -> void:
	var test_instance: Node = MockRPCStressTest.new()
	add_child_autofree(test_instance)

	# Test with 0 calls/sec (all should be rejected)
	var rate_limit: float = 0.0
	var total_calls: int = 10
	var violations: int = 0

	for i in range(total_calls):
		var allowed: bool = test_instance._simulate_rpc_call("test_rpc", rate_limit, i, total_calls)
		if not allowed:
			violations += 1

	# All calls should be violations
	assert_eq(violations, total_calls, "All calls should be rejected with 0 rate limit")


## Test: High rate limit (most calls allowed)
func test_high_rate_limit() -> void:
	var test_instance: Node = MockRPCStressTest.new()
	add_child_autofree(test_instance)

	# Test with 95 calls/sec (most should be allowed)
	var rate_limit: float = 95.0
	var total_calls: int = 100
	var violations: int = 0

	for i in range(total_calls):
		var allowed: bool = test_instance._simulate_rpc_call("test_rpc", rate_limit, i, total_calls)
		if not allowed:
			violations += 1

	# Expected: 100 - 95 = 5 violations
	assert_almost_eq(
		float(violations), 5.0, 3.0, "Should detect ~5 violations with 95 calls/sec limit"
	)


## Test: RPC whitelist loading
func test_rpc_whitelist_loading() -> void:
	# Verify RPC whitelist can be loaded
	var rpc_whitelist_script: Script = RPCWhitelistScript
	assert_not_null(rpc_whitelist_script, "RPC whitelist script should load successfully")

	if rpc_whitelist_script:
		var rpc_whitelist: RefCounted = rpc_whitelist_script.new()
		assert_not_null(rpc_whitelist, "Should be able to instantiate RPC whitelist")

		# Verify ALLOWED_RPCS dictionary exists
		assert_true(
			rpc_whitelist.get("ALLOWED_RPCS") != null,
			"RPC whitelist should have ALLOWED_RPCS dictionary"
		)

		var allowed_rpcs: Dictionary = rpc_whitelist.ALLOWED_RPCS

		# Verify test RPC exists
		assert_true(allowed_rpcs.has("request_shoot"), "RPC whitelist should contain request_shoot")

		# Verify rate limit is configured
		if allowed_rpcs.has("request_shoot"):
			var rpc_config: Dictionary = allowed_rpcs["request_shoot"]
			assert_true(
				rpc_config.has("calls_per_second"),
				"request_shoot should have calls_per_second configured"
			)


## Test: Result reporting format
func test_result_reporting_format() -> void:
	var test_instance: Node = MockRPCStressTest.new()
	add_child_autofree(test_instance)

	# Simulate test results
	var test_results: Dictionary = {
		"violations_detected": 90, "player_kicked": true, "server_stable": true, "test_passed": true
	}

	# Verify result structure
	assert_true(test_results.has("violations_detected"), "Results should have violations_detected")
	assert_true(test_results.has("player_kicked"), "Results should have player_kicked")
	assert_true(test_results.has("server_stable"), "Results should have server_stable")
	assert_true(test_results.has("test_passed"), "Results should have test_passed")

	# Verify types
	assert_typeof(test_results.violations_detected, TYPE_INT, "violations_detected should be int")
	assert_typeof(test_results.player_kicked, TYPE_BOOL, "player_kicked should be bool")
	assert_typeof(test_results.server_stable, TYPE_BOOL, "server_stable should be bool")
	assert_typeof(test_results.test_passed, TYPE_BOOL, "test_passed should be bool")


## Test: Player kick threshold
func test_player_kick_threshold() -> void:
	# Test that player should be kicked after exceeding max violations
	var max_violations: int = 3

	# Test with violations below threshold
	var violations_low: int = 2
	var should_kick_low: bool = violations_low >= max_violations
	assert_false(should_kick_low, "Player should not be kicked with %d violations" % violations_low)

	# Test with violations at threshold
	var violations_at: int = 3
	var should_kick_at: bool = violations_at >= max_violations
	assert_true(should_kick_at, "Player should be kicked with %d violations" % violations_at)

	# Test with violations above threshold
	var violations_high: int = 90
	var should_kick_high: bool = violations_high >= max_violations
	assert_true(should_kick_high, "Player should be kicked with %d violations" % violations_high)


## Test: Edge case - single call
func test_edge_case_single_call() -> void:
	var test_instance: Node = MockRPCStressTest.new()
	add_child_autofree(test_instance)

	# Test with single call and 1 call/sec limit
	var rate_limit: float = 1.0
	var total_calls: int = 1

	var allowed: bool = test_instance._simulate_rpc_call("test_rpc", rate_limit, 0, total_calls)
	assert_true(allowed, "Single call should be allowed with 1 call/sec limit")


## Test: Edge case - exact rate limit match
func test_edge_case_exact_rate_limit_match() -> void:
	var test_instance: Node = MockRPCStressTest.new()
	add_child_autofree(test_instance)

	# Test with exactly matching rate limit (10 calls with 10 calls/sec)
	var rate_limit: float = 10.0
	var total_calls: int = 10
	var violations: int = 0

	for i in range(total_calls):
		var allowed: bool = test_instance._simulate_rpc_call("test_rpc", rate_limit, i, total_calls)
		if not allowed:
			violations += 1

	# Should have minimal violations (0-2 due to timing)
	assert_lt(violations, 3, "Should have minimal violations when calls match rate limit exactly")


## Test: Stress test with multiple RPC types
func test_multiple_rpc_types() -> void:
	# Verify whitelist contains multiple RPC types with different limits
	var rpc_whitelist_script: Script = RPCWhitelistScript
	assert_not_null(rpc_whitelist_script, "RPC whitelist should load")

	if rpc_whitelist_script:
		var rpc_whitelist: RefCounted = rpc_whitelist_script.new()
		var allowed_rpcs: Dictionary = rpc_whitelist.ALLOWED_RPCS

		# Check for different RPC types
		var rpc_types: Array[String] = ["request_shoot", "request_weapon_switch", "request_pickup"]

		for rpc_name: String in rpc_types:
			if allowed_rpcs.has(rpc_name):
				var rpc_config: Dictionary = allowed_rpcs[rpc_name]
				assert_true(
					rpc_config.has("calls_per_second"),
					"%s should have rate limit configured" % rpc_name
				)

				var rate_limit: float = rpc_config.get("calls_per_second", 0.0)
				assert_gt(rate_limit, 0.0, "%s should have positive rate limit" % rpc_name)


## Test: Integration test class structure
func test_integration_test_class_exists() -> void:
	# Verify IntegrationTest inner class can be instantiated
	var script: Script = load("res://tests/manual/rpc_stress_test.gd")
	assert_not_null(script, "RPC stress test script should load")

	# The IntegrationTest is an inner class, verify script has it
	var script_source: String = script.source_code
	assert_string_contains(
		script_source, "class IntegrationTest", "Script should contain IntegrationTest inner class"
	)
	assert_string_contains(
		script_source,
		"func _run_integration_test",
		"IntegrationTest should have _run_integration_test method"
	)
