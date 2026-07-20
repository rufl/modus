extends GutTest

## Test RPC Whitelist Security
##
## This test verifies that the RPC whitelist correctly blocks unauthorized RPCs
## and allows only whitelisted methods.

const RPCWhitelist = preload("res://game/core/network/rpc_whitelist.gd")


func test_whitelist_allows_known_rpcs() -> void:
	# Test that all critical RPCs are in the whitelist
	assert_true(RPCWhitelist.is_allowed("request_shoot"), "request_shoot should be allowed")
	assert_true(RPCWhitelist.is_allowed("request_damage"), "request_damage should be allowed")
	assert_true(
		RPCWhitelist.is_allowed("request_weapon_switch"), "request_weapon_switch should be allowed"
	)
	assert_true(RPCWhitelist.is_allowed("request_pickup"), "request_pickup should be allowed")
	assert_true(RPCWhitelist.is_allowed("request_revive"), "request_revive should be allowed")
	assert_true(RPCWhitelist.is_allowed("send_message"), "send_message should be allowed")


func test_whitelist_blocks_unknown_rpcs() -> void:
	# Test that unknown/malicious RPCs are blocked
	assert_false(RPCWhitelist.is_allowed("hack_give_admin"), "hack_give_admin should be blocked")
	assert_false(
		RPCWhitelist.is_allowed("cheat_infinite_ammo"), "cheat_infinite_ammo should be blocked"
	)
	assert_false(RPCWhitelist.is_allowed("exploit_teleport"), "exploit_teleport should be blocked")
	assert_false(RPCWhitelist.is_allowed("unknown_method"), "unknown_method should be blocked")


func test_whitelist_rate_limits() -> void:
	# Test that rate limits are correctly configured
	var shoot_rate: float = RPCWhitelist.get_rate_limit("request_shoot")
	assert_eq(shoot_rate, 10.0, "request_shoot should have 10 calls/sec limit")

	var chat_rate: float = RPCWhitelist.get_rate_limit("send_message")
	assert_eq(chat_rate, 3.0, "send_message should have 3 calls/sec limit (anti-spam)")

	var kick_rate: float = RPCWhitelist.get_rate_limit("kick_player")
	assert_eq(kick_rate, 0.1, "kick_player should have 0.1 calls/sec limit (1 per 10 sec)")


func test_whitelist_validation_requirements() -> void:
	# Test that critical RPCs require validation
	assert_true(
		RPCWhitelist.requires_validation("request_shoot"), "request_shoot should require validation"
	)
	assert_true(
		RPCWhitelist.requires_validation("request_damage"),
		"request_damage should require validation"
	)
	assert_true(
		RPCWhitelist.requires_validation("request_weapon_switch"),
		"request_weapon_switch should require validation"
	)
	assert_true(
		RPCWhitelist.requires_validation("request_pickup"),
		"request_pickup should require validation"
	)
	assert_true(
		RPCWhitelist.requires_validation("request_revive"),
		"request_revive should require validation (CRITICAL #7)"
	)


func test_whitelist_validators() -> void:
	# Test that validators are correctly assigned
	var shoot_validator: String = RPCWhitelist.get_validator("request_shoot")
	assert_eq(
		shoot_validator, "_validate_shoot_request", "request_shoot should have correct validator"
	)

	var revive_validator: String = RPCWhitelist.get_validator("request_revive")
	assert_eq(
		revive_validator, "_validate_revive_request", "request_revive should have correct validator"
	)


func test_whitelist_completeness() -> void:
	# Test that whitelist has a reasonable number of methods
	var methods: Array[String] = RPCWhitelist.get_all_methods()
	assert_gt(methods.size(), 50, "Whitelist should have at least 50 methods")
	assert_lt(methods.size(), 200, "Whitelist should have less than 200 methods (sanity check)")


func test_whitelist_no_duplicates() -> void:
	# Test that there are no duplicate entries
	var methods: Array[String] = RPCWhitelist.get_all_methods()
	var unique_methods: Dictionary = {}

	for method: String in methods:
		assert_false(unique_methods.has(method), "Method %s should not be duplicated" % method)
		unique_methods[method] = true


func test_critical_issue_12_rpcs_present() -> void:
	# Test that Critical Issue #12 RPCs are in whitelist
	# (RPC Rate Limiting Not Enforced on All Methods)

	# Match Service RPCs
	assert_true(
		RPCWhitelist.is_allowed("update_player_status"), "update_player_status should be allowed"
	)
	assert_true(RPCWhitelist.is_allowed("register_kill"), "register_kill should be allowed")
	assert_true(RPCWhitelist.is_allowed("request_respawn"), "request_respawn should be allowed")

	# Player State Manager RPCs
	assert_true(RPCWhitelist.is_allowed("set_player_state"), "set_player_state should be allowed")
	assert_true(RPCWhitelist.is_allowed("set_player_mode"), "set_player_mode should be allowed")

	# Network Editor RPCs
	assert_true(RPCWhitelist.is_allowed("place_block"), "place_block should be allowed")
	assert_true(RPCWhitelist.is_allowed("delete_node"), "delete_node should be allowed")
	assert_true(RPCWhitelist.is_allowed("paint_block"), "paint_block should be allowed")

	# Chat Service RPC
	assert_true(RPCWhitelist.is_allowed("send_message"), "send_message should be allowed")


func test_critical_issue_7_revive_rpc_present() -> void:
	# Test that Critical Issue #7 revive RPCs are in whitelist with validation
	assert_true(RPCWhitelist.is_allowed("request_revive"), "request_revive should be allowed")
	assert_true(
		RPCWhitelist.is_allowed("request_revive_start"), "request_revive_start should be allowed"
	)

	# Both should require validation to prevent exploit
	assert_true(
		RPCWhitelist.requires_validation("request_revive"),
		"request_revive should require validation"
	)
	assert_true(
		RPCWhitelist.requires_validation("request_revive_start"),
		"request_revive_start should require validation"
	)
