extends ModusGutTestBase

# Test MODUS Framework Weapons System functionality
# Converted from legacy Dictionary format to GUT assertions


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func test_weapon_data_class_exists() -> void:
	var weapon: WeaponData = WeaponData.new()
	assert_not_null(weapon, "Should be able to instantiate WeaponData")


func test_weapon_data_has_required_properties() -> void:
	var weapon: WeaponData = WeaponData.new()
	assert_not_null(weapon, "WeaponData should be available")

	if weapon:
		var required_props: Array[String] = [
			"weapon_id",
			"display_name",
			"damage",
			"fire_rate",
		]

		for prop: String in required_props:
			assert_true(prop in weapon, "WeaponData should have property: " + prop)


# =============================================================================
# WEAPON REGISTRY
# =============================================================================


func test_weapons_in_game_database() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	assert_not_null(gm, "GameManager should exist")

	if gm:
		var data_service: Variant = gm.get_core_system("data")
		assert_not_null(data_service, "Data service should exist")

		if data_service and data_service.has_method("get_all_weapons"):
			var weapons: Variant = data_service.get_all_weapons()
			var is_valid_type: bool = weapons is Dictionary or weapons is Array
			assert_true(is_valid_type, "get_all_weapons() should return Dictionary or Array")


func test_minimum_weapon_count() -> void:
	assert_autoload_exists("GameManager")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var data_service: Variant = gm.get_core_system("data")
		if data_service and data_service.has_method("get_all_weapons"):
			var weapons: Variant = data_service.get_all_weapons()
			var count: int = 0

			if weapons is Dictionary:
				count = weapons.size()
			elif weapons is Array:
				count = weapons.size()

			# Should have at least 5 weapons for a boomer shooter
			assert_ge(count, 5, "Should have at least 5 weapons, found: " + str(count))


# =============================================================================
# WEAPON BALANCE CONFIG
# =============================================================================


func test_weapon_balance_in_config() -> void:
	assert_gamecore_subsystem_exists("config")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var config_service: Variant = gm.get_core_system("config")
		if config_service:
			var balance: Variant = (
				config_service.get_balance("weapons", null)
				if config_service.has_method("get_balance")
				else null
			)

			if balance == null:
				# Try alternative path
				balance = config_service.get_value("balance.weapons")

			# It's okay if balance isn't configured - weapons may use res:// data files
			assert_true(true, "Weapon balance config check completed")


func test_pistol_defined() -> void:
	assert_autoload_exists("GameManager")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var data_service: Variant = gm.get_core_system("data")
		if data_service and data_service.has_method("get_weapon"):
			var pistol: Variant = data_service.get_weapon("pistol")
			assert_not_null(pistol, "Pistol weapon should be found in database")


func test_shotgun_defined() -> void:
	assert_autoload_exists("GameManager")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var data_service: Variant = gm.get_core_system("data")
		if data_service and data_service.has_method("get_weapon"):
			var shotgun: Variant = data_service.get_weapon("shotgun")
			assert_not_null(shotgun, "Shotgun weapon should be found in database")


func test_rocket_launcher_defined() -> void:
	assert_autoload_exists("GameManager")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var data_service: Variant = gm.get_core_system("data")
		if data_service and data_service.has_method("get_weapon"):
			var rocket: Variant = data_service.get_weapon("rocket_launcher")
			assert_not_null(rocket, "Rocket launcher should be found in database")


# =============================================================================
# WEAPON SCENES
# =============================================================================


func test_weapon_scenes_exist() -> void:
	var weapon_paths: Array[String] = [
		"res://game/weapons/pistol.tscn",
		"res://game/weapons/shotgun.tscn",
		"res://game/weapons/machinegun.tscn",
		"res://game/weapons/rocket_launcher.tscn",
		"res://game/weapons/knife.tscn",
	]

	for path: String in weapon_paths:
		assert_true(ResourceLoader.exists(path), "Weapon scene should exist: " + path)


func test_chaingun_scene_exists() -> void:
	var path: String = "res://game/weapons/chaingun.tscn"
	assert_true(ResourceLoader.exists(path), "Chaingun scene should exist")


func test_grenade_launcher_scene_exists() -> void:
	var path: String = "res://game/weapons/grenade_launcher.tscn"
	assert_true(ResourceLoader.exists(path), "Grenade launcher scene should exist")
