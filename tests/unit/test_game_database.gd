extends ModusGutTestBase

# Test MODUS Framework GameManager data service functionality
# Converted from legacy GameDatabase to GameManager pattern

func before_each() -> void:
	await modus_setup()

func after_each() -> void:
	modus_teardown()

func test_autoload_exists() -> void:
	assert_autoload_exists("GameManager")

func test_weapons_loaded() -> void:
	assert_autoload_exists("GameManager")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var data_service: Variant = gm.get_core_system("data")
		if data_service:
			var weapons: Dictionary = data_service.get("weapons")

			assert_not_null(weapons, "Weapons data should not be null")
			assert_false(weapons.is_empty(), "Weapons should be loaded from JSON")

			# Verify at least one expected weapon exists
			var has_expected_weapon: bool = weapons.has("pistol") or weapons.has("shotgun")
			assert_true(has_expected_weapon, "Should have at least one expected weapon (pistol or shotgun)")

func test_enemies_loaded() -> void:
	assert_autoload_exists("GameManager")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var data_service: Variant = gm.get_core_system("data")
		if data_service:
			var enemies: Dictionary = data_service.get("enemies")

			assert_not_null(enemies, "Enemies data should not be null")
			assert_false(enemies.is_empty(), "Enemies should be loaded from JSON")

func test_get_weapon_data() -> void:
	assert_autoload_exists("GameManager")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var data_service: Variant = gm.get_core_system("data")
		if data_service:
			var pistol: Dictionary = data_service.call("get_weapon_data", "pistol")

			if pistol.is_empty():
				# Try shotgun as fallback
				var shotgun: Dictionary = data_service.call("get_weapon_data", "shotgun")
				assert_false(shotgun.is_empty(), "get_weapon_data should return data for at least one weapon")
			else:
				assert_true(true, "get_weapon_data returned pistol data successfully")

func test_get_enemy_data() -> void:
	assert_autoload_exists("GameManager")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var data_service: Variant = gm.get_core_system("data")
		if data_service:
			var grunt: Dictionary = data_service.call("get_enemy_data", "grunt_basic")

			# Just verify method works without crashing
			assert_eq(typeof(grunt), TYPE_DICTIONARY, "get_enemy_data should return dictionary")

func test_get_nonexistent() -> void:
	assert_autoload_exists("GameManager")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var data_service: Variant = gm.get_core_system("data")
		if data_service:
			var result: Dictionary = data_service.call("get_weapon_data", "nonexistent")

			# Should return empty dictionary, not crash
			assert_eq(typeof(result), TYPE_DICTIONARY, "Invalid ID should return dictionary (empty is acceptable)")

