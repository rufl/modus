extends ModusGutTestBase

# Test MODUS Framework Environment Systems
# Converted from legacy Dictionary format to GUT assertions

const LootPropSpawnerScript := preload("res://game/world/actors/props/loot_prop_spawner.gd")


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	modus_teardown()


func test_elevator_script_exists() -> void:
	var path: String = "res://game/world/actors/traversal/elevator.gd"
	assert_true(FileAccess.file_exists(path), "Elevator script should exist at: %s" % path)


func test_ladder_script_exists() -> void:
	var path: String = "res://game/world/actors/traversal/ladder.gd"
	assert_true(FileAccess.file_exists(path), "Ladder script should exist at: %s" % path)


func test_slipgate_script_exists() -> void:
	var path: String = "res://game/world/actors/traversal/slipgate.gd"
	assert_true(FileAccess.file_exists(path), "Slipgate script should exist at: %s" % path)


func test_teleporter_platform_script_exists() -> void:
	var path: String = "res://game/world/actors/traversal/teleporter_platform.gd"
	assert_true(
		FileAccess.file_exists(path), "Teleporter platform script should exist at: %s" % path
	)


func test_rope_script_exists() -> void:
	var path: String = "res://game/world/actors/traversal/rope.gd"
	assert_true(FileAccess.file_exists(path), "Rope script should exist at: %s" % path)


func test_jump_pod_script_exists() -> void:
	var path: String = "res://game/world/actors/traversal/jump_pod.gd"
	assert_true(FileAccess.file_exists(path), "Jump pod script should exist at: %s" % path)


func test_door_script_exists() -> void:
	var path: String = "res://game/world/actors/door.gd"
	assert_true(FileAccess.file_exists(path), "Door script should exist at: %s" % path)


# =============================================================================
# HAZARD SCRIPT FILES
# =============================================================================


func test_hazard_block_script_exists() -> void:
	var path: String = "res://game/world/actors/hazards/hazard_block.gd"
	assert_true(FileAccess.file_exists(path), "Hazard block script should exist at: %s" % path)


func test_turret_script_exists() -> void:
	var path: String = "res://game/world/actors/hazards/turret.gd"
	assert_true(FileAccess.file_exists(path), "Turret script should exist at: %s" % path)


func test_crusher_script_exists() -> void:
	var path: String = "res://game/world/actors/hazards/crusher.gd"
	assert_true(FileAccess.file_exists(path), "Crusher script should exist at: %s" % path)


func test_spikes_script_exists() -> void:
	var path: String = "res://game/world/actors/hazards/spikes.gd"
	assert_true(FileAccess.file_exists(path), "Spikes script should exist at: %s" % path)


# =============================================================================
# ENVIRONMENT SCRIPT FILES
# =============================================================================


func test_day_night_controller_exists() -> void:
	var path: String = "res://game/world/actors/day_night_controller.gd"
	assert_true(
		FileAccess.file_exists(path), "Day/night controller script should exist at: %s" % path
	)


func test_liquid_volume_exists() -> void:
	var path: String = "res://game/world/actors/liquid_volume.gd"
	assert_true(FileAccess.file_exists(path), "Liquid volume script should exist at: %s" % path)


func test_map_boundary_exists() -> void:
	var path: String = "res://game/world/actors/map_boundary.gd"
	assert_true(FileAccess.file_exists(path), "Map boundary script should exist at: %s" % path)


# =============================================================================
# WEATHER SYSTEM
# =============================================================================


func test_weather_directory_exists() -> void:
	var path: String = "res://game/world/actors/weather/"
	assert_true(DirAccess.dir_exists_absolute(path), "Weather directory should exist at: %s" % path)
	var weather_scene_path: String = path.path_join("weather_controller.tscn")
	assert_true(
		ResourceLoader.exists(weather_scene_path),
		"Weather controller scene should exist at: %s" % weather_scene_path
	)

	for scene_path: String in LootPropSpawnerScript.PROP_SCENES.values():
		assert_true(
			ResourceLoader.exists(scene_path),
			"Registered loot-prop scene should resolve at: %s" % scene_path
		)

	var gib_material_path := "res://game/scripts/features/effects/effects/gib_physics.tres"
	assert_true(
		ResourceLoader.exists(gib_material_path),
		"Gib physics material should resolve at: %s" % gib_material_path
	)
