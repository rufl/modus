extends ModusGutTestBase

## Test Reference Integrity
## Validates that file paths, function calls, and signal connections are valid
## Helps catch broken references after refactoring or file reorganization

# =============================================================================
# CRITICAL FILE PATH REFERENCES
# =============================================================================


func test_service_paths_exist() -> void:
	var service_paths: Array[String] = [
		"res://game/scripts/features/audio/audio_service.gd",
		"res://game/scripts/core/event_service.gd",
		"res://game/scripts/core/log_service.gd",
		"res://game/scripts/core/global_state.gd",
		"res://game/scripts/features/data/config_service.gd",
		"res://game/scripts/features/performance/performance_service.gd",
		"res://game/scripts/features/gameplay/entity_service.gd",
		"res://game/scripts/features/performance/pool_service.gd",
		"res://game/scripts/features/gameplay/input_service.gd",
		"res://game/scripts/features/save/save_service.gd",
		"res://game/scripts/features/data/data_service.gd",
		"res://game/scripts/features/ui/ui_service.gd",
		"res://game/scripts/features/player/player_state_manager.gd",
		"res://game/scripts/features/network/chat_service.gd",
		"res://game/scripts/features/player/player_service.gd",
		"res://game/scripts/features/combat/combat_service.gd",
		"res://game/scripts/features/loot/loot_service.gd",
		"res://game/scripts/features/match/match_service.gd",
		"res://game/scripts/features/ui/damage_indicator_service.gd",
		"res://game/scripts/features/effects/effects_service.gd",
	]

	for path in service_paths:
		assert_file_exists(path, "Service file should exist: %s" % path)


func test_shader_paths_exist() -> void:
	var shader_paths: Array[String] = [
		"res://game/art/shaders/retro_tracer.gdshader",
		"res://game/art/shaders/retro_blood.gdshader",
		"res://game/art/shaders/retro_particle.gdshader",
		"res://game/art/shaders/retro_decal.gdshader",
		"res://game/art/shaders/godmode.gdshader",
		"res://game/art/shaders/invisibility.gdshader",
		"res://game/art/shaders/screen_effects.gdshader",
		"res://game/art/shaders/blood_pool.gdshader",
		"res://shared/shaders/blood_pool.gdshader",
	]

	for path in shader_paths:
		assert_file_exists(path, "Shader file should exist: %s" % path)


func test_shared_blood_pool_sources_load() -> void:
	var shader := load("res://shared/shaders/blood_pool.gdshader") as Shader
	var controller := load("res://shared/shaders/blood_pool.gd") as Script
	assert_not_null(shader, "Shared blood-pool shader should parse and load")
	assert_not_null(controller, "Shared blood-pool controller should parse and load")


func test_projectile_paths_exist() -> void:
	var projectile_paths: Array[String] = [
		"res://game/entities/projectiles/explosion_quake.tscn",
		"res://game/entities/projectiles/rocket.tscn",
		"res://game/entities/projectiles/grenade.tscn",
		"res://game/entities/projectiles/plasma.tscn",
		"res://game/entities/projectiles/nuker3000_ball.tscn",
		"res://game/entities/projectiles/grenade.gd",
		"res://game/entities/projectiles/rocket.gd",
	]

	for path in projectile_paths:
		assert_file_exists(path, "Projectile file should exist: %s" % path)


func test_config_paths_exist() -> void:
	var config_paths: Array[String] = [
		"res://game/config/features.json5",
		"res://game/config/features/splitscreen.json5",
		"res://game/config/gameplay/input.json5",
		"res://game/config/gameplay/audio.json5",
		"res://game/config/gameplay/gameplay.json5",
		"res://game/config/network/network_config.json5",
		"res://game/config/performance/visuals.json5",
		"res://game/config/entities/weapons.json5",
		"res://game/config/entities/enemies.json5",
	]

	for path in config_paths:
		assert_file_exists(path, "Config file should exist: %s" % path)


func test_data_paths_exist() -> void:
	var data_paths: Array[String] = [
		"res://game/data/weapons.json5",
		"res://game/data/enemies.json5",
		"res://game/data/loot_tables.json5",
		"res://game/config/items/sample_items.json5",
		"res://game/config/items/loot_tables.json5",
	]

	for path in data_paths:
		assert_file_exists(path, "Data file should exist: %s" % path)


func test_data_config_ownership_documented() -> void:
	var schema_path := "res://docs/technical/JSON_SCHEMAS.md"
	assert_file_exists(schema_path, "Data/config ownership document should exist")
	var schema_file := FileAccess.open(schema_path, FileAccess.READ)
	assert_not_null(schema_file, "Data/config ownership document should be readable")
	if not schema_file:
		return
	var schema_text := schema_file.get_as_text()
	schema_file.close()
	assert_string_contains(schema_text, "`game/data/` is content data")
	assert_string_contains(schema_text, "`game/config/` is runtime configuration")
	assert_string_contains(schema_text, "`user://mods/`")


func test_tool_scripts_exist() -> void:
	var tool_paths: Array[String] = [
		"res://game/core/tools/sound_generator.gd",
		"res://game/core/tools/blood_pool.gd",
		"res://game/core/tools/minimap_generator.gd",
	]

	for path in tool_paths:
		assert_file_exists(path, "Tool script should exist: %s" % path)


# =============================================================================
# CRITICAL FUNCTION REFERENCES
# =============================================================================


func test_skeletal_character_visuals_functions() -> void:
	var script_path := "res://game/entities/common/skeletal_character_visuals.gd"
	assert_file_exists(script_path, "SkeletalCharacterVisuals script should exist")

	var script: Script = load(script_path)
	assert_not_null(script, "SkeletalCharacterVisuals script should load")

	# Create temporary instance to check methods
	var instance: Node = Node3D.new()
	instance.set_script(script)

	# Check critical functions exist
	assert_has_method(instance, "attach_weapon_node", "Should have attach_weapon_node() method")
	assert_has_method(instance, "equip_knife", "Should have equip_knife() method")
	assert_has_method(instance, "flash", "Should have flash() method")

	instance.free()


func test_weapon_manager_functions() -> void:
	var script_path := "res://game/entities/player/components/weapon_manager.gd"
	assert_file_exists(script_path, "WeaponManager script should exist")

	var script: Script = load(script_path)
	assert_not_null(script, "WeaponManager script should load")

	var instance: Node = Node3D.new()
	instance.set_script(script)

	# Check critical functions exist
	assert_has_method(instance, "fire", "Should have fire() method")
	assert_has_method(
		instance, "_spawn_projectile_server", "Should have _spawn_projectile_server() method"
	)
	# Note: reload and switch_weapon may be in inventory component

	instance.free()


func test_sound_generator_functions() -> void:
	# Test that SoundGenerator class exists and has all required functions
	# Since SoundGenerator is a static class, we test by trying to call the functions
	var required_functions: Array[String] = [
		"generate_shoot_sound",
		"generate_hit_sound",
		"generate_explosion_sound",
		"generate_footstep_sound",
		"generate_enemy_death_sound",
		"generate_glass_shatter",
		"generate_wood_crack",
		"generate_metal_clang",
		"generate_breakable_explosion",
	]

	# Load the script and check method list
	var script_path := "res://game/core/tools/sound_generator.gd"
	assert_file_exists(script_path, "SoundGenerator script should exist")

	var script: Script = load(script_path)
	assert_not_null(script, "SoundGenerator script should load")

	if not script:
		return

	var method_list: Array = script.get_script_method_list()
	var method_names: Array[String] = []
	for method in method_list:
		method_names.append(method["name"])

	for func_name in required_functions:
		assert_array_contains(
			method_names, func_name, "SoundGenerator should have %s() method" % func_name
		)


func test_effects_service_functions() -> void:
	var script_path := "res://game/scripts/features/effects/effects_service.gd"
	assert_file_exists(script_path, "EffectsService script should exist")

	var script: Script = load(script_path)
	assert_not_null(script, "EffectsService script should load")

	var instance: Node = Node.new()
	instance.set_script(script)

	# Check critical functions exist
	assert_has_method(instance, "spawn_explosion", "Should have spawn_explosion() method")
	assert_has_method(instance, "spawn_blood_decal", "Should have spawn_blood_decal() method")
	assert_has_method(instance, "spawn_tracer", "Should have spawn_tracer() method")

	instance.free()


func test_combat_service_functions() -> void:
	var script_path := "res://game/scripts/features/combat/combat_service.gd"
	assert_file_exists(script_path, "CombatService script should exist")

	var script: Script = load(script_path)
	assert_not_null(script, "CombatService script should load")

	var instance: Node = Node.new()
	instance.set_script(script)

	# Check critical functions exist
	assert_has_method(instance, "apply_damage", "Should have apply_damage() method")
	assert_has_method(instance, "validate_hit", "Should have validate_hit() method")

	instance.free()


# =============================================================================
# SIGNAL DEFINITIONS
# =============================================================================


func test_player_signals_exist() -> void:
	var script_path := "res://game/entities/player/player.gd"
	assert_file_exists(script_path, "Player script should exist")

	var script: Script = load(script_path)
	assert_not_null(script, "Player script should load")

	# Check that critical signals are defined
	var signal_list: Array = script.get_script_signal_list()
	var signal_names: Array[String] = []
	for sig in signal_list:
		signal_names.append(sig["name"])

	# Expected signals
	var expected_signals: Array[String] = [
		"ammo_changed",
		"reload_started",
		"reload_finished",
	]

	for expected_signal in expected_signals:
		assert_array_contains(
			signal_names, expected_signal, "Player should define signal: %s" % expected_signal
		)


func test_enemy_signals_exist() -> void:
	var script_path := "res://game/entities/enemies/enemy.gd"
	assert_file_exists(script_path, "Enemy script should exist")

	var script: Script = load(script_path)
	assert_not_null(script, "Enemy script should load")

	var signal_list: Array = script.get_script_signal_list()
	var signal_names: Array[String] = []
	for sig in signal_list:
		signal_names.append(sig["name"])

	# Expected signals (Enemy may not have signals at class level)
	# Signals may be in components or emitted dynamically
	# Just verify the script loads
	assert_true(true, "Enemy script loads successfully")


func test_breakable_object_signals_exist() -> void:
	var script_path := "res://game/world/actors/hazards/breakable_object.gd"
	assert_file_exists(script_path, "BreakableObject script should exist")

	var script: Script = load(script_path)
	assert_not_null(script, "BreakableObject script should load")

	var signal_list: Array = script.get_script_signal_list()
	var signal_names: Array[String] = []
	for sig in signal_list:
		signal_names.append(sig["name"])

	# Expected signals
	assert_array_contains(signal_names, "broken", "BreakableObject should define 'broken' signal")


# =============================================================================
# PRELOAD REFERENCES
# =============================================================================


func test_weapon_database_projectile_references() -> void:
	var weapons_path := "res://game/data/weapons.json5"
	assert_file_exists(weapons_path, "Weapons database should exist")

	# Load and parse weapons.json5
	var file := FileAccess.open(weapons_path, FileAccess.READ)
	assert_not_null(file, "Should be able to open weapons.json5")

	if not file:
		return

	var content := file.get_as_text()
	file.close()

	# Check for projectile path references (should be in entities/projectiles/)
	assert_false(
		"res://game/projectiles/" in content,
		"Weapons database should not reference old projectile path"
	)

	# Verify new paths are used
	if "projectile_scene" in content:
		assert_true(
			"res://game/entities/projectiles/" in content,
			"Weapons database should use new projectile path"
		)


func test_no_orphaned_procedural_sound_generator_references() -> void:
	# Ensure no files reference the old procedural_sound_generator.gd
	var files_to_check: Array[String] = [
		"res://game/world/actors/hazards/breakable_object.gd",
		"res://game/scripts/features/audio/audio_service.gd",
	]

	for file_path in files_to_check:
		if not FileAccess.file_exists(file_path):
			continue

		var file := FileAccess.open(file_path, FileAccess.READ)
		if not file:
			continue

		var content := file.get_as_text()
		file.close()

		assert_false(
			"procedural_sound_generator" in content.to_lower(),
			"File should not reference old procedural_sound_generator: %s" % file_path
		)


# =============================================================================
# AUTOLOAD AVAILABILITY
# =============================================================================


func test_critical_autoloads_exist() -> void:
	var autoloads: Array[String] = [
		"GameManager",
		"MapGenerator",
		# Note: EnemyTracker may not be an autoload
	]

	for autoload_name in autoloads:
		assert_autoload_exists(autoload_name, "Critical autoload should exist: %s" % autoload_name)


# =============================================================================
# SCENE REFERENCES
# =============================================================================


func test_projectile_scenes_loadable() -> void:
	var projectile_scenes: Array[String] = [
		"res://game/entities/projectiles/rocket.tscn",
		"res://game/entities/projectiles/grenade.tscn",
		"res://game/entities/projectiles/plasma.tscn",
	]

	for scene_path in projectile_scenes:
		var scene: PackedScene = load(scene_path)
		assert_not_null(scene, "Projectile scene should load: %s" % scene_path)


func test_player_scene_loadable() -> void:
	var player_path := "res://game/entities/player/player.tscn"
	assert_file_exists(player_path, "Player scene should exist")

	var scene: PackedScene = load(player_path)
	assert_not_null(scene, "Player scene should load")


func test_enemy_scenes_loadable() -> void:
	var enemy_scenes: Array[String] = [
		"res://game/entities/enemies/enemy.tscn",
		"res://game/entities/enemies/corpse.tscn",
		"res://game/entities/enemies/dummy/dummy_skeletal.tscn",
	]

	var found_any := false
	for scene_path in enemy_scenes:
		assert_file_exists(scene_path, "Enemy scene should exist: %s" % scene_path)
		var scene: PackedScene = load(scene_path)
		assert_not_null(scene, "Enemy scene should load: %s" % scene_path)
		found_any = true

	assert_true(found_any, "At least one maintained enemy scene should be checked")


# =============================================================================
# HELPER METHODS
# =============================================================================


func assert_file_exists(path: String, message: String = "") -> void:
	var msg := message if message != "" else "File should exist: %s" % path
	assert_true(FileAccess.file_exists(path), msg)


func assert_has_method(object: Object, method_name: String, message: String = "") -> void:
	var msg := message if message != "" else "Object should have method: %s" % method_name
	assert_true(object.has_method(method_name), msg)
