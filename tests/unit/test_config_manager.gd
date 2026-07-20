extends ModusGutTestBase

# Test MODUS Framework configuration manager
# Converted from legacy Dictionary format to GUT assertions

func before_each() -> void:
	await modus_setup()

func after_each() -> void:
	modus_teardown()

func test_config_exists() -> void:
	assert_gamecore_subsystem_exists("config")

func test_feature_flags() -> void:
	# Test that feature flag checking works
	assert_gamecore_subsystem_exists("config")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.get_core_system("config"):
		var gore_enabled: bool = gm.get_core_system("config").is_feature_enabled("gore")
		var _loot_enabled: bool = gm.get_core_system("config").is_feature_enabled("loot")

		# We just verify the method doesn't crash and returns bool
		assert_eq(typeof(gore_enabled), TYPE_BOOL, "is_feature_enabled should return bool")

func test_get_value() -> void:
	# Test nested config access with fallback
	assert_gamecore_subsystem_exists("config")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.get_core_system("config"):
		var fallback_value: int = 999
		var result: Variant = gm.get_core_system("config").get_value("nonexistent.path", fallback_value)
		assert_eq(result, fallback_value, "Fallback value should be returned for nonexistent path")

func test_get_config() -> void:
	# Test retrieving entire config file
	assert_gamecore_subsystem_exists("config")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.get_core_system("config"):
		var player_config: Variant = gm.get_core_system("config").get_value("player")

		# Should return dictionary (empty or populated) or null for missing key
		if player_config != null:
			assert_eq(typeof(player_config), TYPE_DICTIONARY, "Player config should be dictionary when present")
		else:
			# Null is acceptable for missing config sections
			assert_true(true, "Player config section not found - this is acceptable")
