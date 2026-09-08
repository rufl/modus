extends GutTest

## Test suite for autoload consolidation
## Verifies that the new architecture works correctly

const GameManagerScript := preload("res://game/scripts/core/game_manager.gd")
const LegacyConstants := preload("res://game/core/constants.gd")


func test_gamecore_has_constants() -> void:
	assert_eq(GameManagerScript.BUS_MASTER, "Master", "BUS_MASTER should match")
	assert_eq(GameManagerScript.GROUP_PLAYER, "player", "GROUP_PLAYER should match")

	var resource_paths: Array[String] = [
		GameManagerScript.PATH_WEAPONS,
		GameManagerScript.PATH_EFFECTS,
		GameManagerScript.PATH_ENTITIES,
		GameManagerScript.PATH_PROJECTILES,
		GameManagerScript.PATH_ITEMS,
		GameManagerScript.PATH_PROPS,
		GameManagerScript.PATH_UI,
		GameManagerScript.PATH_AUDIO,
		GameManagerScript.PATH_CFG,
	]
	for path: String in resource_paths:
		assert_true(
			DirAccess.dir_exists_absolute(path), "Resource directory should exist: %s" % path
		)


func test_gamecore_has_child_services() -> void:
	# Wait for services to initialize
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and not gm.is_initialized():
		await gm.ready

	if gm:
		assert_not_null(
			gm.get_core_system("localization"), "GameCore should have localization child"
		)
		assert_not_null(gm.get_core_system("mod_loader"), "GameCore should have mod_loader child")
		assert_not_null(
			gm.get_core_system("state_manager"), "GameCore should have state_manager child"
		)
		assert_not_null(
			gm.get_core_system("blood_effects"), "GameCore should have blood_effects child"
		)


func test_get_service_returns_child_services() -> void:
	# Wait for services to initialize
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and not gm.is_initialized():
		await gm.ready

	if gm:
		var localization: Node = gm.get_core_system("localization")
		var mod_loader: Node = gm.get_core_system("mod_loader")
		var state_manager: Node = gm.get_core_system("state_manager")
		var blood_effects: Node = gm.get_core_system("blood_effects")

		assert_not_null(localization, "Should get localization service")
		assert_not_null(mod_loader, "Should get mod_loader service")
		assert_not_null(state_manager, "Should get state_manager service")
		assert_not_null(blood_effects, "Should get blood_effects service")


func test_localization_service_methods() -> void:
	# Wait for services to initialize
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and not gm.is_initialized():
		await gm.ready

	if gm:
		var localization: Node = gm.get_core_system("localization")
		assert_not_null(localization, "Localization service should exist")

		assert_has_method(localization, "translate", "Should have translate method")
		assert_has_method(localization, "load_language", "Should have load_language method")
		assert_has_method(
			localization, "get_available_languages", "Should have get_available_languages method"
		)


func test_mod_loader_service_methods() -> void:
	# Wait for services to initialize
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and not gm.is_initialized():
		await gm.ready

	if gm:
		var mod_loader: Node = gm.get_core_system("mod_loader")
		assert_not_null(mod_loader, "ModLoader service should exist")

		assert_has_method(mod_loader, "get_loaded_mods", "Should have get_loaded_mods method")
		assert_has_method(mod_loader, "is_mod_loaded", "Should have is_mod_loaded method")
		assert_has_method(mod_loader, "load_all_mods", "Should have load_all_mods method")


func test_state_manager_service_methods() -> void:
	# Wait for services to initialize
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and not gm.is_initialized():
		await gm.ready

	if gm:
		var state_manager: Node = gm.get_core_system("state_manager")
		assert_not_null(state_manager, "StateManager service should exist")

		assert_has_method(state_manager, "save_game", "Should have save_game method")
		assert_has_method(state_manager, "load_game", "Should have load_game method")
		assert_has_method(state_manager, "get_save_list", "Should have get_save_list method")


func test_blood_effects_service_methods() -> void:
	# Wait for services to initialize
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and not gm.is_initialized():
		await gm.ready

	if gm:
		var blood_effects: Node = gm.get_core_system("blood_effects")
		assert_not_null(blood_effects, "BloodEffects service should exist")

		assert_has_method(blood_effects, "spawn_blood", "Should have spawn_blood method")
		assert_has_method(blood_effects, "is_available", "Should have is_available method")


func test_constants_backward_compatibility() -> void:
	assert_eq(
		LegacyConstants.BUS_MASTER, GameManagerScript.BUS_MASTER, "Bus constants should match"
	)
	assert_eq(
		LegacyConstants.GROUP_PLAYER, GameManagerScript.GROUP_PLAYER, "Group constants should match"
	)
	assert_eq(
		LegacyConstants.GROUP_CORPSE_PILES,
		GameManagerScript.GROUP_CORPSE_PILES,
		"Corpse-pile group constants should match"
	)

	var legacy_paths: Array[String] = [
		LegacyConstants.PATH_WEAPONS,
		LegacyConstants.PATH_EFFECTS,
		LegacyConstants.PATH_ENTITIES,
		LegacyConstants.PATH_PROJECTILES,
		LegacyConstants.PATH_ITEMS,
		LegacyConstants.PATH_PROPS,
		LegacyConstants.PATH_UI,
		LegacyConstants.PATH_AUDIO,
		LegacyConstants.PATH_CFG,
	]
	var current_paths: Array[String] = [
		GameManagerScript.PATH_WEAPONS,
		GameManagerScript.PATH_EFFECTS,
		GameManagerScript.PATH_ENTITIES,
		GameManagerScript.PATH_PROJECTILES,
		GameManagerScript.PATH_ITEMS,
		GameManagerScript.PATH_PROPS,
		GameManagerScript.PATH_UI,
		GameManagerScript.PATH_AUDIO,
		GameManagerScript.PATH_CFG,
	]
	for index: int in range(current_paths.size()):
		assert_eq(legacy_paths[index], current_paths[index], "Compatibility path should match")


func test_only_current_core_autoloads() -> void:
	# GameManager owns the service tree; MapGenerator remains a separate lifecycle owner.
	var core_autoloads: Array[String] = ["GameManager", "MapGenerator"]

	for autoload_name: String in core_autoloads:
		assert_not_null(
			get_node_or_null("/root/" + autoload_name),
			"Core autoload %s should exist" % autoload_name
		)

	for retired_name: String in [
		"SystemService", "GameplayService", "NetworkService", "EventBus", "GameDatabase"
	]:
		assert_null(
			get_node_or_null("/root/" + retired_name),
			"Retired autoload %s should remain consolidated" % retired_name
		)
