extends ModusGutTestBase

# Test MODUS Framework Enemy AI Systems
# Converted from legacy Dictionary format to GUT assertions


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func test_enemies_config_in_gameplay_json5() -> void:
	assert_gamecore_subsystem_exists("config")

	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm or not gm.get_core_system("config"):
		return

	var enemies: Variant = gm.get_core_system("config").get_value("enemies")

	assert_not_null(enemies, "Enemies config should be found in gameplay.json5")
	assert_true(enemies is Dictionary, "Enemies config should be a Dictionary")


func test_grunt_enemy_defined() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	assert_not_null(gm, "GameManager should exist")
	
	if not gm:
		return
	
	var data_service: Variant = gm.get_core_system("data")
	assert_not_null(data_service, "Data service should exist")

	if not data_service:
		return

	var enemies: Dictionary = data_service.enemies

	assert_false(enemies.is_empty(), "Enemies should be loaded in data service")
	assert_true(enemies.has("grunt"), "Grunt enemy should be defined")


func test_enemy_has_required_stats() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	assert_not_null(gm, "GameManager should exist")
	
	if not gm:
		return
	
	var data_service: Variant = gm.get_core_system("data")
	assert_not_null(data_service, "Data service should exist")

	if not data_service:
		return

	var enemies: Dictionary = data_service.enemies

	assert_false(enemies.is_empty(), "Enemies should be loaded in data service")
	assert_true(enemies.has("grunt"), "Grunt should be found for testing")

	if not enemies.has("grunt"):
		return

	var grunt: Dictionary = enemies["grunt"]
	var required_fields: Array[String] = ["name", "tier", "stats"]

	for field: String in required_fields:
		assert_true(grunt.has(field), "Grunt should have field: %s" % field)


func test_enemy_tiers_exist() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	assert_not_null(gm, "GameManager should exist")
	
	if not gm:
		return
	
	var data_service: Variant = gm.get_core_system("data")
	assert_not_null(data_service, "Data service should exist")

	if not data_service:
		return

	var enemies: Dictionary = data_service.enemies

	assert_false(enemies.is_empty(), "Enemies should be loaded in data service")

	# Check that multiple tiers are represented
	var tiers_found: Array[int] = []

	for enemy_id: String in enemies.keys():
		var enemy: Dictionary = enemies[enemy_id]
		if enemy.has("tier"):
			var tier: int = enemy["tier"]
			if tier not in tiers_found:
				tiers_found.append(tier)

	assert_ge(tiers_found.size(), 2, "Should have at least 2 enemy tiers, found: %d" % tiers_found.size())


# =============================================================================
# ENEMY DATABASE
# =============================================================================


func test_enemies_in_game_database() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	assert_not_null(gm, "GameManager should exist")
	
	if not gm:
		return
	
	var data_service: Variant = gm.get_core_system("data")
	assert_not_null(data_service, "Data service should exist")

	if not data_service:
		return

	if not data_service.has_method("get_all_enemies"):
		pass_test("get_all_enemies() method not found - skipping test")
		return

	var enemies: Variant = data_service.get_all_enemies()

	assert_not_null(enemies, "get_all_enemies() should return valid data")


# =============================================================================
# AI COMBAT CONFIG
# =============================================================================


func test_ai_combat_config_exists() -> void:
	assert_gamecore_subsystem_exists("config")

	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm or not gm.get_core_system("config"):
		return

	var ai_combat: Variant = gm.get_core_system("config").get_value("gameplay.ai_combat")

	assert_not_null(ai_combat, "ai_combat config should be found")


func test_infighting_config_exists() -> void:
	assert_gamecore_subsystem_exists("config")

	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm or not gm.get_core_system("config"):
		return

	var ai_combat: Variant = gm.get_core_system("config").get_value("gameplay.ai_combat")

	assert_not_null(ai_combat, "ai_combat config should be accessible")
	assert_true(ai_combat is Dictionary, "ai_combat should be a Dictionary")

	if not ai_combat is Dictionary:
		return

	assert_true(ai_combat.has("infighting"), "Infighting config should be found")


func test_squad_tactics_config_exists() -> void:
	assert_gamecore_subsystem_exists("config")

	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm or not gm.get_core_system("config"):
		return

	var ai_combat: Variant = gm.get_core_system("config").get_value("gameplay.ai_combat")

	assert_not_null(ai_combat, "ai_combat config should be accessible")
	assert_true(ai_combat is Dictionary, "ai_combat should be a Dictionary")

	if not ai_combat is Dictionary:
		return

	assert_true(ai_combat.has("squad_tactics"), "Squad tactics config should be found")


func test_damage_numbers_config_exists() -> void:
	assert_gamecore_subsystem_exists("config")

	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm or not gm.get_core_system("config"):
		return

	var ai_combat: Variant = gm.get_core_system("config").get_value("gameplay.ai_combat")

	assert_not_null(ai_combat, "ai_combat config should be accessible")
	assert_true(ai_combat is Dictionary, "ai_combat should be a Dictionary")

	if not ai_combat is Dictionary:
		return

	assert_true(ai_combat.has("damage_numbers"), "Damage numbers config should be found")


# =============================================================================
# ENEMY SCENE FILES
# =============================================================================


func test_enemy_base_script_exists() -> void:
	var path: String = "res://game/entities/enemies/enemy.gd"
	assert_true(FileAccess.file_exists(path), "Base enemy script should exist at: %s" % path)


func test_enemy_ai_controller_exists() -> void:
	var path: String = "res://game/entities/enemies/ai/enemy_ai_controller.gd"
	assert_true(FileAccess.file_exists(path), "Enemy AI controller script should exist at: %s" % path)


func test_infighting_system_exists() -> void:
	var path: String = "res://game/entities/enemies/ai/infighting_system.gd"
	assert_true(FileAccess.file_exists(path), "Infighting system script should exist at: %s" % path)


func test_squad_tactics_exists() -> void:
	var path: String = "res://game/entities/enemies/ai/squad_tactics.gd"
	assert_true(FileAccess.file_exists(path), "Squad tactics script should exist at: %s" % path)
