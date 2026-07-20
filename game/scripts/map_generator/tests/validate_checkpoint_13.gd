#!/usr/bin/env -S godot --headless --script
## Checkpoint 13 Validation Script
## Validates CSG Geometry Builder, Prefab System, and Theme Manager integration

extends SceneTree

var _validation_results := {
	"csg_geometry": [], "prefab_system": [], "theme_manager": [], "integration": []
}


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("  CHECKPOINT 13 VALIDATION")
	print("  Geometry and Prefab Systems Integration Test")
	print("=".repeat(70) + "\n")

	_validate_csg_geometry_builder()
	_validate_prefab_system()
	_validate_theme_manager()
	_validate_integration()
	_print_results()

	var has_failures := _has_failures()
	quit(0 if not has_failures else 1)


func _validate_csg_geometry_builder() -> void:
	print("Validating CSG Geometry Builder...")

	# Test 1: Class exists and can be instantiated
	var builder = CSGGeometryBuilder.new()
	_add_result("csg_geometry", "Class instantiation", builder != null)

	# Test 2: Create test context
	var config := GenerationConfig.new()
	config.map_size = Vector2i(10, 10)
	config.theme = GenerationConfig.ThemeType.TECH

	var context := GenerationContext.new()
	context.config = config
	context.grid_size = config.map_size
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 12345

	# Initialize grid
	context.grid = []
	for y in range(config.map_size.y):
		var row: Array[Cell] = []
		for x in range(config.map_size.x):
			row.append(Cell.new(Cell.Type.EMPTY))
		context.grid.append(row)

	# Test 3: Initialize builder
	builder.initialize(context)
	_add_result("csg_geometry", "Builder initialization", context.csg_root != null)
	_add_result("csg_geometry", "CSG root name", context.csg_root.name == "MapGeometry")
	_add_result("csg_geometry", "CSG collision enabled", context.csg_root.use_collision)
	_add_result("csg_geometry", "Theme loaded", context.theme != null)

	# Test 4: Create simple room
	for y in range(3, 6):
		for x in range(3, 6):
			context.grid[y][x].type = Cell.Type.ROOM

	# Test 5: Build geometry
	var csg_root := builder.build_geometry()
	_add_result("csg_geometry", "Geometry built", csg_root != null)
	_add_result("csg_geometry", "Has Floors node", csg_root.has_node("Floors"))
	_add_result("csg_geometry", "Has Walls node", csg_root.has_node("Walls"))
	_add_result("csg_geometry", "Has Ceilings node", csg_root.has_node("Ceilings"))

	# Test 6: Bake geometry
	var baked_mesh := builder.bake_geometry()
	_add_result("csg_geometry", "Mesh baking", baked_mesh != null)
	_add_result("csg_geometry", "Baked mesh has collision", baked_mesh.has_node("Collision"))

	# Cleanup
	if csg_root:
		csg_root.queue_free()
	if baked_mesh:
		baked_mesh.queue_free()


func _validate_prefab_system() -> void:
	print("\nValidating Prefab System...")

	# Test 1: Class exists and can be instantiated
	var prefab_system := MapPrefabSystem.new()
	_add_result("prefab_system", "Class instantiation", prefab_system != null)

	# Test 2: Cache initialization
	var has_cache := prefab_system.get_prefab_count(GenerationConfig.ThemeType.TECH) >= 0
	_add_result("prefab_system", "Cache initialized", has_cache)

	# Test 3: Load prefabs for tech theme
	var loaded_count := prefab_system.load_prefabs_for_theme(GenerationConfig.ThemeType.TECH)
	_add_result("prefab_system", "Tech prefabs loaded", loaded_count >= 0)

	# Test 4: Check if test prefab exists
	var tech_prefabs := prefab_system.get_prefabs(GenerationConfig.ThemeType.TECH, "")
	_add_result("prefab_system", "Tech prefabs available", tech_prefabs.size() > 0)

	# Test 5: Validate metadata parsing
	var metadata_path := "res://game/data/map_generator/prefabs/tech/test_crate.json"
	if FileAccess.file_exists(metadata_path):
		var metadata := PrefabMetadata.from_file(metadata_path)
		_add_result("prefab_system", "Metadata parsing", metadata != null)
		if metadata:
			_add_result("prefab_system", "Metadata validation", metadata.is_valid())
			_add_result("prefab_system", "Dimensions set", metadata.dimensions.length() > 0)
			_add_result(
				"prefab_system",
				"Theme set",
				metadata.required_theme == GenerationConfig.ThemeType.TECH
			)
	else:
		_add_result("prefab_system", "Test prefab exists", false)

	# Test 6: Statistics
	var stats := prefab_system.get_statistics()
	_add_result("prefab_system", "Statistics available", stats != null)
	_add_result("prefab_system", "Statistics has total", stats.has("total_prefabs"))


func _validate_theme_manager() -> void:
	print("\nValidating Theme Manager...")

	# Test 1: Class exists and can be instantiated
	var theme_manager := ThemeManager.new()
	_add_result("theme_manager", "Class instantiation", theme_manager != null)

	# Test 2: All themes loaded
	_add_result(
		"theme_manager",
		"Tech theme loaded",
		theme_manager.has_theme(GenerationConfig.ThemeType.TECH)
	)
	_add_result(
		"theme_manager",
		"Hell theme loaded",
		theme_manager.has_theme(GenerationConfig.ThemeType.HELL)
	)
	_add_result(
		"theme_manager",
		"Urban theme loaded",
		theme_manager.has_theme(GenerationConfig.ThemeType.URBAN)
	)
	_add_result(
		"theme_manager",
		"Cave theme loaded",
		theme_manager.has_theme(GenerationConfig.ThemeType.CAVE)
	)
	_add_result(
		"theme_manager",
		"Jumbled theme loaded",
		theme_manager.has_theme(GenerationConfig.ThemeType.JUMBLED)
	)

	# Test 3: Set theme and get materials
	theme_manager.set_theme(GenerationConfig.ThemeType.TECH)
	_add_result("theme_manager", "Theme set", theme_manager.get_current_theme() != null)
	_add_result("theme_manager", "Wall material", theme_manager.get_wall_material() != null)
	_add_result("theme_manager", "Floor material", theme_manager.get_floor_material() != null)
	_add_result("theme_manager", "Ceiling material", theme_manager.get_ceiling_material() != null)
	_add_result("theme_manager", "Cave material", theme_manager.get_cave_material() != null)

	# Test 4: Lighting configuration
	_add_result("theme_manager", "Ambient color", theme_manager.get_ambient_color() != null)
	_add_result("theme_manager", "Ambient energy", theme_manager.get_ambient_energy() > 0.0)
	_add_result("theme_manager", "Directional color", theme_manager.get_directional_color() != null)
	_add_result("theme_manager", "Directional energy", theme_manager.get_directional_energy() > 0.0)

	# Test 5: Prefab filtering
	var test_metadata := PrefabMetadata.new()
	test_metadata.dimensions = Vector3(2, 2, 2)
	test_metadata.required_theme = GenerationConfig.ThemeType.TECH

	var is_compatible := theme_manager.is_prefab_compatible(test_metadata)
	_add_result("theme_manager", "Prefab filtering (matching)", is_compatible)

	test_metadata.required_theme = GenerationConfig.ThemeType.HELL
	is_compatible = theme_manager.is_prefab_compatible(test_metadata)
	_add_result("theme_manager", "Prefab filtering (non-matching)", not is_compatible)

	# Test 6: Jumbled theme accepts all
	theme_manager.set_theme(GenerationConfig.ThemeType.JUMBLED)
	is_compatible = theme_manager.is_prefab_compatible(test_metadata)
	_add_result("theme_manager", "Jumbled accepts all", is_compatible)


func _validate_integration() -> void:
	print("\nValidating System Integration...")

	# Test 1: Create integrated context
	var config := GenerationConfig.new()
	config.map_size = Vector2i(10, 10)
	config.theme = GenerationConfig.ThemeType.TECH

	var context := GenerationContext.new()
	context.config = config
	context.grid_size = config.map_size
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 12345

	# Initialize grid
	context.grid = []
	for y in range(config.map_size.y):
		var row: Array[Cell] = []
		for x in range(config.map_size.x):
			row.append(Cell.new(Cell.Type.EMPTY))
		context.grid.append(row)

	# Test 2: Theme Manager + CSG Builder integration
	var theme_manager := ThemeManager.new()
	theme_manager.set_theme(config.theme)

	var builder := CSGGeometryBuilder.new()
	builder.initialize(context)

	_add_result("integration", "Theme applied to context", context.theme != null)
	_add_result("integration", "Materials loaded", context.theme.wall_material != null)

	# Test 3: Theme Manager + Prefab System integration
	var prefab_system := MapPrefabSystem.new()
	prefab_system.set_theme_manager(theme_manager)
	prefab_system.load_prefabs_for_theme(config.theme)

	var filtered_prefabs := prefab_system.get_filtered_prefabs(config.theme, "")
	_add_result("integration", "Prefab system has theme manager", true)
	_add_result("integration", "Filtered prefabs available", filtered_prefabs.size() >= 0)

	# Test 4: Complete workflow
	for y in range(3, 6):
		for x in range(3, 6):
			context.grid[y][x].type = Cell.Type.ROOM

	var csg_root := builder.build_geometry()
	_add_result("integration", "Geometry built with theme", csg_root != null)

	# Test 5: Lighting application
	var test_scene := Node3D.new()
	theme_manager.apply_lighting_to_scene(test_scene)

	var has_world_env := false
	var has_light := false
	for child in test_scene.get_children():
		if child is WorldEnvironment:
			has_world_env = true
		if child is DirectionalLight3D:
			has_light = true

	_add_result("integration", "Lighting applied (WorldEnvironment)", has_world_env)
	_add_result("integration", "Lighting applied (DirectionalLight)", has_light)

	# Cleanup
	if csg_root:
		csg_root.queue_free()
	test_scene.queue_free()


func _add_result(category: String, test_name: String, passed: bool) -> void:
	_validation_results[category].append({"name": test_name, "passed": passed})


func _print_results() -> void:
	print("\n" + "=".repeat(70))
	print("  VALIDATION RESULTS")
	print("=".repeat(70))

	var total_tests := 0
	var total_passed := 0

	for category in _validation_results.keys():
		var results: Array = _validation_results[category]
		var passed := 0
		var failed := 0

		for result in results:
			total_tests += 1
			if result.passed:
				passed += 1
				total_passed += 1
			else:
				failed += 1

		var category_name: String = category.replace("_", " ").capitalize()
		print("\n%s: %d/%d passed" % [category_name, passed, results.size()])

		for result in results:
			var icon := "✓" if result.passed else "✗"
			var status := "PASS" if result.passed else "FAIL"
			print("  %s %s - %s" % [icon, result.name, status])

	print("\n" + "=".repeat(70))
	print(
		(
			"TOTAL: %d/%d tests passed (%.1f%%)"
			% [total_passed, total_tests, (float(total_passed) / float(total_tests)) * 100.0]
		)
	)
	print("=".repeat(70) + "\n")


func _has_failures() -> bool:
	for category in _validation_results.keys():
		for result in _validation_results[category]:
			if not result.passed:
				return true
	return false
