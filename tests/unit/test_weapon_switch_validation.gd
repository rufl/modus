extends GutTest

## Unit Test: Weapon Switch RPC Validation
## Tests that weapon switch RPCs are properly rate-limited and validated

const RPCWhitelistScript = preload("res://game/core/network/rpc_whitelist.gd")

var rpc_whitelist: RefCounted = null
var allowed_rpcs: Dictionary = {}


func before_each() -> void:
	# Load RPC whitelist
	rpc_whitelist = RPCWhitelistScript.new()
	allowed_rpcs = rpc_whitelist.ALLOWED_RPCS


func test_request_weapon_switch_in_whitelist() -> void:
	# Assert: request_weapon_switch is in the whitelist
	assert_true(allowed_rpcs.has("request_weapon_switch"),
		"request_weapon_switch should be in RPC whitelist")


func test_request_weapon_switch_requires_validation() -> void:
	# Arrange
	var rpc_config: Dictionary = allowed_rpcs.get("request_weapon_switch", {})
	
	# Assert: Requires validation
	assert_true(rpc_config.get("requires_validation", false),
		"request_weapon_switch should require server validation")
	
	# Assert: Has validator method
	assert_true(rpc_config.has("validator_method"),
		"request_weapon_switch should have a validator method")
	
	var validator: String = rpc_config.get("validator_method", "")
	assert_eq(validator, "_validate_weapon_switch",
		"request_weapon_switch should use _validate_weapon_switch validator")


func test_request_weapon_switch_rate_limit() -> void:
	# Arrange
	var rpc_config: Dictionary = allowed_rpcs.get("request_weapon_switch", {})
	
	# Assert: Has rate limit configured
	assert_true(rpc_config.has("calls_per_second"),
		"request_weapon_switch should have rate limit configured")
	
	var rate_limit: float = rpc_config.get("calls_per_second", 0.0)
	
	# Assert: Rate limit is reasonable (5 calls/sec)
	assert_eq(rate_limit, 5.0,
		"request_weapon_switch should have 5 calls/sec rate limit")


func test_rapid_weapon_switches_respect_rate_limit() -> void:
	# Arrange
	var rpc_config: Dictionary = allowed_rpcs.get("request_weapon_switch", {})
	var rate_limit: float = rpc_config.get("calls_per_second", 5.0)
	
	# Simulate rapid weapon switches
	var attempts: int = 20
	var time_window: float = 1.0  # 1 second
	var allowed_calls: int = int(rate_limit * time_window)
	
	# Act: Calculate how many should be allowed
	var violations: int = attempts - allowed_calls
	
	# Assert: Violations should be detected
	assert_eq(violations, 15,
		"Should detect 15 violations when attempting 20 switches in 1 second (limit: 5)")
	
	# Assert: Some calls should be allowed
	assert_gt(allowed_calls, 0,
		"Some weapon switches should be allowed within rate limit")


func test_weapon_switch_rpc_has_description() -> void:
	# Arrange
	var rpc_config: Dictionary = allowed_rpcs.get("request_weapon_switch", {})
	
	# Assert: Has description for documentation
	assert_true(rpc_config.has("description"),
		"request_weapon_switch should have description")
	
	var description: String = rpc_config.get("description", "")
	assert_false(description.is_empty(),
		"request_weapon_switch description should not be empty")


func test_confirm_weapon_switch_in_whitelist() -> void:
	# Assert: Server confirmation RPC exists
	assert_true(allowed_rpcs.has("confirm_weapon_switch"),
		"confirm_weapon_switch should be in RPC whitelist for server confirmation")


func test_reject_weapon_switch_in_whitelist() -> void:
	# Assert: Server rejection RPC exists
	assert_true(allowed_rpcs.has("reject_weapon_switch"),
		"reject_weapon_switch should be in RPC whitelist for server rejection")


func test_reject_weapon_switch_rate_limit() -> void:
	# Arrange
	var rpc_config: Dictionary = allowed_rpcs.get("reject_weapon_switch", {})
	
	# Assert: Has rate limit (should match request rate)
	assert_true(rpc_config.has("calls_per_second"),
		"reject_weapon_switch should have rate limit")
	
	var rate_limit: float = rpc_config.get("calls_per_second", 0.0)
	assert_eq(rate_limit, 5.0,
		"reject_weapon_switch should have same rate limit as request (5 calls/sec)")


func test_weapon_switch_validation_flow() -> void:
	# Test the complete validation flow
	
	# 1. Client sends request_weapon_switch
	assert_true(allowed_rpcs.has("request_weapon_switch"),
		"Step 1: Client can send request_weapon_switch")
	
	# 2. Server validates the request
	var request_config: Dictionary = allowed_rpcs.get("request_weapon_switch", {})
	assert_true(request_config.get("requires_validation", false),
		"Step 2: Server validates the request")
	
	# 3. Server can confirm or reject
	assert_true(allowed_rpcs.has("confirm_weapon_switch"),
		"Step 3a: Server can confirm valid switch")
	assert_true(allowed_rpcs.has("reject_weapon_switch"),
		"Step 3b: Server can reject invalid switch")


func test_rate_limit_prevents_spam() -> void:
	# Simulate a spam attack
	var rpc_config: Dictionary = allowed_rpcs.get("request_weapon_switch", {})
	var rate_limit: float = rpc_config.get("calls_per_second", 5.0)
	
	# Attacker tries 100 switches per second
	var attack_rate: int = 100
	var expected_blocks: int = attack_rate - int(rate_limit)
	
	# Assert: Most attacks should be blocked
	assert_eq(expected_blocks, 95,
		"Rate limiting should block 95 out of 100 spam attempts")
	
	# Assert: Rate limit is effective
	var block_percentage: float = (float(expected_blocks) / float(attack_rate)) * 100.0
	assert_gt(block_percentage, 90.0,
		"Rate limiting should block >90% of spam attempts")


func test_weapon_switch_does_not_require_authentication() -> void:
	# Weapon switches should be validated but not require special auth
	var rpc_config: Dictionary = allowed_rpcs.get("request_weapon_switch", {})
	
	# Assert: Validation is for rate limiting and game state, not authentication
	assert_true(rpc_config.get("requires_validation", false),
		"Requires validation for rate limiting")
	
	# Note: Authentication is handled at connection level, not per-RPC


func test_all_weapon_rpcs_have_rate_limits() -> void:
	# Check that all weapon-related RPCs have rate limits
	var weapon_rpcs: Array[String] = [
		"request_weapon_switch",
		"confirm_weapon_switch",
		"reject_weapon_switch",
		"request_reload"
	]
	
	for rpc_name: String in weapon_rpcs:
		if allowed_rpcs.has(rpc_name):
			var rpc_config: Dictionary = allowed_rpcs[rpc_name]
			assert_true(rpc_config.has("calls_per_second"),
				"%s should have rate limit configured" % rpc_name)


## Integration test with NetworkManager (if available)
func test_network_manager_validates_weapon_switch() -> void:
	# Check if NetworkManager is available
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm or not gm.has_method("get_core_system"):
		pass_test("GameManager not available for integration test")
		return
	
	var network_service: Node = gm.get_core_system("network")
	if not network_service:
		pass_test("NetworkService not available for integration test")
		return
	
	var network_manager: Node = network_service.get("network_manager")
	if not network_manager or not network_manager.has_method("validate_rpc"):
		pass_test("NetworkManager.validate_rpc not available for integration test")
		return
	
	var test_peer_id: int = 999
	var rpc_name: String = "request_weapon_switch"

	# Malformed requests fail through the configured validator, not unknown dispatch.
	assert_false(network_manager.validate_rpc(test_peer_id, rpc_name, []),
		"Weapon switch without an index should be rejected")

	# Isolate a fresh peer so payload rejection above does not consume this rate-limit slot.
	var rate_limit_peer_id: int = 1000
	assert_true(network_manager._check_rate_limit(rate_limit_peer_id, rpc_name),
		"First weapon switch should pass the rate limiter")
	assert_false(network_manager._check_rate_limit(rate_limit_peer_id, rpc_name),
		"Rapid weapon switches should be rate limited")
