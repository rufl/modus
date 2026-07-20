extends GutTest

## Unit tests for MapPrefabSystem and PrefabMetadata

const PrefabMetadata = preload("res://game/scripts/map_generator/prefab_metadata.gd")
const MapPrefabSystem = preload("res://game/scripts/map_generator/prefab_system.gd")

var prefab_system: MapPrefabSystem


func before_each() -> void:
	prefab_system = MapPrefabSystem.new()


func after_each() -> void:
	prefab_system = null


## Test PrefabMetadata parsing from dictionary
func test_prefab_metadata_from_dict_valid() -> void:
	var data := {
		"dimensions": [2.0, 3.0, 2.0],
		"anchor_points": [[0.0, 0.0, 0.0], [1.0, 0.0, 0.0]],
		"required_theme": "tech",
		"density_weight": 1.5,
		"tags": ["prop", "cover"],
		"collision_radius": 0.75,
		"placement_rules": {"min_distance_from_walls": 0.5}
	}

	var metadata := PrefabMetadata.from_dict(data)

	assert_not_null(metadata, "Metadata should be parsed successfully")
	assert_eq(metadata.dimensions, Vector3(2.0, 3.0, 2.0), "Dimensions should match")
	assert_eq(metadata.anchor_points.size(), 2, "Should have 2 anchor points")
	assert_eq(metadata.required_theme, GenerationConfig.ThemeType.TECH, "MapTheme should be TECH")
	assert_eq(metadata.density_weight, 1.5, "Density weight should match")
	assert_eq(metadata.tags.size(), 2, "Should have 2 tags")
	assert_eq(metadata.collision_radius, 0.75, "Collision radius should match")
	assert_true(
		metadata.placement_rules.has("min_distance_from_walls"), "Should have placement rule"
	)


## Test PrefabMetadata parsing with missing required fields
func test_prefab_metadata_from_dict_missing_dimensions() -> void:
	var data := {"anchor_points": [[0.0, 0.0, 0.0]], "required_theme": "tech"}

	var metadata := PrefabMetadata.from_dict(data)

	assert_null(metadata, "Metadata should be null when dimensions are missing")


## Test PrefabMetadata parsing with invalid theme
func test_prefab_metadata_from_dict_invalid_theme() -> void:
	var data := {
		"dimensions": [2.0, 3.0, 2.0],
		"anchor_points": [[0.0, 0.0, 0.0]],
		"required_theme": "invalid_theme"
	}

	var metadata := PrefabMetadata.from_dict(data)

	assert_null(metadata, "Metadata should be null when theme is invalid")


## Test PrefabMetadata parsing with default values
func test_prefab_metadata_from_dict_defaults() -> void:
	var data := {
		"dimensions": [2.0, 3.0, 2.0], "anchor_points": [[0.0, 0.0, 0.0]], "required_theme": "hell"
	}

	var metadata := PrefabMetadata.from_dict(data)

	assert_not_null(metadata, "Metadata should be parsed successfully")
	assert_eq(metadata.density_weight, 1.0, "Default density weight should be 1.0")
	assert_eq(metadata.tags.size(), 0, "Default tags should be empty")
	assert_eq(metadata.collision_radius, 0.5, "Default collision radius should be 0.5")
	assert_eq(metadata.placement_rules.size(), 0, "Default placement rules should be empty")


## Test PrefabMetadata to_dict conversion
func test_prefab_metadata_to_dict() -> void:
	var metadata := PrefabMetadata.new()
	metadata.dimensions = Vector3(2.0, 3.0, 2.0)
	metadata.anchor_points = [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)]
	metadata.required_theme = GenerationConfig.ThemeType.URBAN
	metadata.density_weight = 1.2
	metadata.tags = ["furniture", "decorative"]
	metadata.collision_radius = 0.6
	metadata.placement_rules = {"requires_floor": true}

	var data := metadata.to_dict()

	assert_eq(data["dimensions"], [2.0, 3.0, 2.0], "Dimensions should match")
	assert_eq(data["anchor_points"].size(), 2, "Should have 2 anchor points")
	assert_eq(data["required_theme"], "urban", "MapTheme should be 'urban'")
	assert_eq(data["density_weight"], 1.2, "Density weight should match")
	assert_eq(data["tags"].size(), 2, "Should have 2 tags")
	assert_eq(data["collision_radius"], 0.6, "Collision radius should match")
	assert_true(data["placement_rules"].has("requires_floor"), "Should have placement rule")


## Test PrefabMetadata round-trip (parse -> export -> parse)
func test_prefab_metadata_round_trip() -> void:
	var original_data := {
		"dimensions": [3.0, 2.5, 1.5],
		"anchor_points": [[0.0, 0.0, 0.0]],
		"required_theme": "cave",
		"density_weight": 0.8,
		"tags": ["gameplay"],
		"collision_radius": 1.0,
		"placement_rules": {"max_per_room": 2}
	}

	var metadata := PrefabMetadata.from_dict(original_data)
	assert_not_null(metadata, "First parse should succeed")

	var exported_data := metadata.to_dict()
	var metadata2 := PrefabMetadata.from_dict(exported_data)
	assert_not_null(metadata2, "Second parse should succeed")

	# Verify all fields match
	assert_eq(metadata2.dimensions, metadata.dimensions, "Dimensions should match")
	assert_eq(
		metadata2.anchor_points.size(),
		metadata.anchor_points.size(),
		"Anchor points count should match"
	)
	assert_eq(metadata2.required_theme, metadata.required_theme, "MapTheme should match")
	assert_eq(metadata2.density_weight, metadata.density_weight, "Density weight should match")
	assert_eq(metadata2.tags.size(), metadata.tags.size(), "Tags count should match")
	assert_eq(
		metadata2.collision_radius, metadata.collision_radius, "Collision radius should match"
	)


## Test PrefabMetadata validation
func test_prefab_metadata_is_valid() -> void:
	var metadata := PrefabMetadata.new()

	# Invalid: zero dimensions
	metadata.dimensions = Vector3.ZERO
	assert_false(metadata.is_valid(), "Should be invalid with zero dimensions")

	# Valid: non-zero dimensions
	metadata.dimensions = Vector3(1.0, 1.0, 1.0)
	assert_true(metadata.is_valid(), "Should be valid with non-zero dimensions")


## Test MapPrefabSystem cache initialization
func test_prefab_system_cache_initialization() -> void:
	assert_not_null(prefab_system, "MapPrefabSystem should be created")

	# Check that cache is initialized for all themes
	for theme: int in GenerationConfig.ThemeType.values():
		var count := prefab_system.get_prefab_count(theme)
		assert_eq(count, 0, "Initial prefab count should be 0 for theme %d" % theme)


## Test MapPrefabSystem get_categories
func test_prefab_system_get_categories() -> void:
	var categories := prefab_system.get_categories(GenerationConfig.ThemeType.TECH)

	assert_not_null(categories, "Categories should not be null")
	assert_eq(categories.size(), 0, "Initial categories should be empty")


## Test MapPrefabSystem has_prefabs_for_theme
func test_prefab_system_has_prefabs_for_theme() -> void:
	var has_prefabs := prefab_system.has_prefabs_for_theme(GenerationConfig.ThemeType.TECH)

	assert_false(has_prefabs, "Should not have prefabs initially")


## Test MapPrefabSystem statistics
func test_prefab_system_statistics() -> void:
	var stats := prefab_system.get_statistics()

	assert_not_null(stats, "Statistics should not be null")
	assert_true(stats.has("total_prefabs"), "Should have total_prefabs")
	assert_true(stats.has("by_theme"), "Should have by_theme")
	assert_true(stats.has("by_category"), "Should have by_category")
	assert_eq(stats["total_prefabs"], 0, "Initial total should be 0")


## Test PrefabMetadata JSON string export
func test_prefab_metadata_to_json_string() -> void:
	var metadata := PrefabMetadata.new()
	metadata.dimensions = Vector3(2.0, 3.0, 2.0)
	metadata.anchor_points = [Vector3(0.0, 0.0, 0.0)]
	metadata.required_theme = GenerationConfig.ThemeType.TECH

	var json_str := metadata.to_json_string()

	assert_not_null(json_str, "JSON string should not be null")
	assert_true(json_str.length() > 0, "JSON string should not be empty")
	assert_true(json_str.contains("dimensions"), "JSON should contain dimensions")
	assert_true(json_str.contains("anchor_points"), "JSON should contain anchor_points")
	assert_true(json_str.contains("required_theme"), "JSON should contain required_theme")
