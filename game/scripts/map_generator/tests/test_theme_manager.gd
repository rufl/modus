extends GutTest

## Unit tests for ThemeManager
## Tests theme configuration, prefab filtering, and lighting setup

var theme_manager: ThemeManager
var mock_rng: RandomNumberGenerator


func before_each() -> void:
	theme_manager = ThemeManager.new()
	mock_rng = RandomNumberGenerator.new()
	mock_rng.seed = 12345


func after_each() -> void:
	theme_manager = null
	mock_rng = null


## Test: ThemeManager initializes with all default themes
func test_initialization_loads_all_themes() -> void:
	assert_not_null(theme_manager, "ThemeManager should be initialized")

	# Check all themes are available
	assert_true(theme_manager.has_theme(GenerationConfig.ThemeType.TECH), "Should have TECH theme")
	assert_true(theme_manager.has_theme(GenerationConfig.ThemeType.HELL), "Should have HELL theme")
	assert_true(
		theme_manager.has_theme(GenerationConfig.ThemeType.URBAN), "Should have URBAN theme"
	)
	assert_true(theme_manager.has_theme(GenerationConfig.ThemeType.CAVE), "Should have CAVE theme")
	assert_true(
		theme_manager.has_theme(GenerationConfig.ThemeType.JUMBLED), "Should have JUMBLED theme"
	)


## Test: Setting theme updates current theme
func test_set_theme_updates_current_theme() -> void:
	theme_manager.set_theme(GenerationConfig.ThemeType.TECH)

	var current_theme: MapTheme = theme_manager.get_current_theme()
	assert_not_null(current_theme, "Current theme should be set")
	assert_eq(current_theme.theme_type, GenerationConfig.ThemeType.TECH, "Should be TECH theme")


## Test: Get materials for each theme
func test_get_materials_for_themes() -> void:
	var theme_types := [
		GenerationConfig.ThemeType.TECH,
		GenerationConfig.ThemeType.HELL,
		GenerationConfig.ThemeType.URBAN,
		GenerationConfig.ThemeType.CAVE
	]

	for theme_type in theme_types:
		theme_manager.set_theme(theme_type)

		var wall_mat: Material = theme_manager.get_wall_material()
		var floor_mat: Material = theme_manager.get_floor_material()
		var ceiling_mat: Material = theme_manager.get_ceiling_material()
		var cave_mat: Material = theme_manager.get_cave_material()

		assert_not_null(wall_mat, "Wall material should exist for theme %d" % theme_type)
		assert_not_null(floor_mat, "Floor material should exist for theme %d" % theme_type)
		assert_not_null(ceiling_mat, "Ceiling material should exist for theme %d" % theme_type)
		assert_not_null(cave_mat, "Cave material should exist for theme %d" % theme_type)


## Test: Get lighting configuration for each theme
func test_get_lighting_configuration() -> void:
	var theme_types := [
		GenerationConfig.ThemeType.TECH,
		GenerationConfig.ThemeType.HELL,
		GenerationConfig.ThemeType.URBAN,
		GenerationConfig.ThemeType.CAVE
	]

	for theme_type in theme_types:
		theme_manager.set_theme(theme_type)

		var ambient_color: Color = theme_manager.get_ambient_color()
		var ambient_energy: float = theme_manager.get_ambient_energy()
		var directional_color: Color = theme_manager.get_directional_color()
		var directional_energy: float = theme_manager.get_directional_energy()

		assert_not_null(ambient_color, "Ambient color should exist for theme %d" % theme_type)
		assert_gt(
			ambient_energy, 0.0, "Ambient energy should be positive for theme %d" % theme_type
		)
		assert_not_null(
			directional_color, "Directional color should exist for theme %d" % theme_type
		)
		assert_gt(
			directional_energy,
			0.0,
			"Directional energy should be positive for theme %d" % theme_type
		)


## Test: Prefab filtering for matching theme
func test_prefab_filtering_matching_theme() -> void:
	theme_manager.set_theme(GenerationConfig.ThemeType.TECH)

	# Create a tech-themed prefab metadata
	var tech_metadata := PrefabMetadata.new()
	tech_metadata.required_theme = GenerationConfig.ThemeType.TECH
	tech_metadata.dimensions = Vector3(2, 2, 2)

	var is_compatible: bool = theme_manager.is_prefab_compatible(tech_metadata)
	assert_true(is_compatible, "Tech prefab should be compatible with Tech theme")


## Test: Prefab filtering for non-matching theme
func test_prefab_filtering_non_matching_theme() -> void:
	theme_manager.set_theme(GenerationConfig.ThemeType.TECH)

	# Create a hell-themed prefab metadata
	var hell_metadata := PrefabMetadata.new()
	hell_metadata.required_theme = GenerationConfig.ThemeType.HELL
	hell_metadata.dimensions = Vector3(2, 2, 2)

	var is_compatible: bool = theme_manager.is_prefab_compatible(hell_metadata)
	assert_false(is_compatible, "Hell prefab should not be compatible with Tech theme")


## Test: Shared prefabs work with all themes
func test_shared_prefabs_compatible_with_all_themes() -> void:
	var shared_metadata := PrefabMetadata.new()
	shared_metadata.required_theme = GenerationConfig.ThemeType.JUMBLED  # Shared/Jumbled
	shared_metadata.dimensions = Vector3(2, 2, 2)

	var theme_types := [
		GenerationConfig.ThemeType.TECH,
		GenerationConfig.ThemeType.HELL,
		GenerationConfig.ThemeType.URBAN,
		GenerationConfig.ThemeType.CAVE
	]

	for theme_type in theme_types:
		theme_manager.set_theme(theme_type)
		var is_compatible: bool = theme_manager.is_prefab_compatible(shared_metadata)
		assert_true(is_compatible, "Shared prefab should be compatible with theme %d" % theme_type)


## Test: Jumbled theme accepts all prefabs
func test_jumbled_theme_accepts_all_prefabs() -> void:
	theme_manager.set_theme(GenerationConfig.ThemeType.JUMBLED)

	# Test with different themed prefabs
	var theme_types := [
		GenerationConfig.ThemeType.TECH,
		GenerationConfig.ThemeType.HELL,
		GenerationConfig.ThemeType.URBAN,
		GenerationConfig.ThemeType.CAVE
	]

	for theme_type in theme_types:
		var metadata := PrefabMetadata.new()
		metadata.required_theme = theme_type
		metadata.dimensions = Vector3(2, 2, 2)

		var is_compatible: bool = theme_manager.is_prefab_compatible(metadata)
		assert_true(is_compatible, "Jumbled theme should accept theme %d prefab" % theme_type)


## Test: Get random theme for Jumbled mode
func test_get_random_theme_for_jumbled() -> void:
	theme_manager.set_theme(GenerationConfig.ThemeType.JUMBLED, mock_rng)

	# Get multiple random themes to ensure variety
	var themes_seen := {}
	for i in range(20):
		var random_theme: MapTheme = theme_manager.get_random_theme_for_jumbled()
		assert_not_null(random_theme, "Random theme should not be null")
		themes_seen[random_theme.theme_type] = true

	# Should have seen at least 2 different themes in 20 attempts
	assert_gte(themes_seen.size(), 2, "Should get variety in random themes")


## Test: Apply lighting to scene creates WorldEnvironment
func test_apply_lighting_creates_world_environment() -> void:
	theme_manager.set_theme(GenerationConfig.ThemeType.TECH)

	var root_node := Node3D.new()
	theme_manager.apply_lighting_to_scene(root_node)

	# Check WorldEnvironment was created
	var world_env: WorldEnvironment = null
	for child in root_node.get_children():
		if child is WorldEnvironment:
			world_env = child
			break

	assert_not_null(world_env, "WorldEnvironment should be created")
	assert_not_null(world_env.environment, "Environment should be set")

	# Cleanup
	root_node.queue_free()


## Test: Apply lighting to scene creates DirectionalLight3D
func test_apply_lighting_creates_directional_light() -> void:
	theme_manager.set_theme(GenerationConfig.ThemeType.HELL)

	var root_node := Node3D.new()
	theme_manager.apply_lighting_to_scene(root_node)

	# Check DirectionalLight3D was created
	var directional_light: DirectionalLight3D = null
	for child in root_node.get_children():
		if child is DirectionalLight3D:
			directional_light = child
			break

	assert_not_null(directional_light, "DirectionalLight3D should be created")
	assert_true(directional_light.shadow_enabled, "Shadows should be enabled")

	# Cleanup
	root_node.queue_free()


## Test: Apply lighting sets theme-specific colors
func test_apply_lighting_sets_theme_colors() -> void:
	theme_manager.set_theme(GenerationConfig.ThemeType.HELL)

	var root_node := Node3D.new()
	theme_manager.apply_lighting_to_scene(root_node)

	# Find WorldEnvironment
	var world_env: WorldEnvironment = null
	for child in root_node.get_children():
		if child is WorldEnvironment:
			world_env = child
			break

	assert_not_null(world_env, "WorldEnvironment should exist")

	var expected_ambient: Color = theme_manager.get_ambient_color()
	var actual_ambient: Color = world_env.environment.ambient_light_color

	# Colors should match (with some tolerance for floating point)
	assert_almost_eq(actual_ambient.r, expected_ambient.r, 0.01, "Ambient red should match")
	assert_almost_eq(actual_ambient.g, expected_ambient.g, 0.01, "Ambient green should match")
	assert_almost_eq(actual_ambient.b, expected_ambient.b, 0.01, "Ambient blue should match")

	# Cleanup
	root_node.queue_free()


## Test: Get material for surface type
func test_get_material_for_surface_type() -> void:
	theme_manager.set_theme(GenerationConfig.ThemeType.URBAN)

	var wall_mat: Material = theme_manager.get_material_for_surface("wall")
	var floor_mat: Material = theme_manager.get_material_for_surface("floor")
	var ceiling_mat: Material = theme_manager.get_material_for_surface("ceiling")
	var cave_mat: Material = theme_manager.get_material_for_surface("cave")

	assert_not_null(wall_mat, "Wall material should be returned")
	assert_not_null(floor_mat, "Floor material should be returned")
	assert_not_null(ceiling_mat, "Ceiling material should be returned")
	assert_not_null(cave_mat, "Cave material should be returned")

	# Test case insensitivity
	var wall_mat_upper: Material = theme_manager.get_material_for_surface("WALL")
	assert_eq(wall_mat, wall_mat_upper, "Surface type should be case insensitive")


## Test: Get available themes
func test_get_available_themes() -> void:
	var available: Array = theme_manager.get_available_themes()

	assert_eq(available.size(), 5, "Should have 5 themes available")
	assert_true(available.has(GenerationConfig.ThemeType.TECH), "Should include TECH")
	assert_true(available.has(GenerationConfig.ThemeType.HELL), "Should include HELL")
	assert_true(available.has(GenerationConfig.ThemeType.URBAN), "Should include URBAN")
	assert_true(available.has(GenerationConfig.ThemeType.CAVE), "Should include CAVE")
	assert_true(available.has(GenerationConfig.ThemeType.JUMBLED), "Should include JUMBLED")


## Test: Theme name conversion
func test_theme_name_conversion() -> void:
	var theme_types := [
		GenerationConfig.ThemeType.TECH,
		GenerationConfig.ThemeType.HELL,
		GenerationConfig.ThemeType.URBAN,
		GenerationConfig.ThemeType.CAVE,
		GenerationConfig.ThemeType.JUMBLED
	]

	for theme_type in theme_types:
		var theme: MapTheme = theme_manager.get_theme(theme_type)
		var theme_name: String = theme.get_theme_name()

		assert_false(
			theme_name.is_empty(), "Theme name should not be empty for type %d" % theme_type
		)
		assert_ne(theme_name, "unknown", "Theme name should be valid for type %d" % theme_type)


## Test: Empty required_theme treated as shared
func test_empty_required_theme_treated_as_shared() -> void:
	theme_manager.set_theme(GenerationConfig.ThemeType.TECH)

	var metadata := PrefabMetadata.new()
	metadata.required_theme = GenerationConfig.ThemeType.JUMBLED  # Jumbled/shared
	metadata.dimensions = Vector3(2, 2, 2)

	var is_compatible: bool = theme_manager.is_prefab_compatible(metadata)
	assert_true(is_compatible, "Jumbled/shared theme should be compatible with all themes")


## Test: Cave material differs by theme
func test_cave_material_differs_by_theme() -> void:
	var materials := {}

	var theme_types := [
		GenerationConfig.ThemeType.TECH,
		GenerationConfig.ThemeType.HELL,
		GenerationConfig.ThemeType.URBAN,
		GenerationConfig.ThemeType.CAVE
	]

	for theme_type in theme_types:
		theme_manager.set_theme(theme_type)
		var cave_mat: Material = theme_manager.get_cave_material()
		materials[theme_type] = cave_mat

	# Materials should be different for different themes
	assert_ne(
		materials[GenerationConfig.ThemeType.TECH],
		materials[GenerationConfig.ThemeType.HELL],
		"Tech and Hell cave materials should differ"
	)
	assert_ne(
		materials[GenerationConfig.ThemeType.URBAN],
		materials[GenerationConfig.ThemeType.CAVE],
		"Urban and Cave materials should differ"
	)
