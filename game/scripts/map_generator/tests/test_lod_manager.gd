extends GutTest

## Unit tests for MapLODManager
## Tests LOD system initialization, configuration, and statistics

const MapLODManager = preload("res://game/scripts/map_generator/lod_manager.gd")

var lod_manager: MapLODManager
var context: GenerationContext


func before_each() -> void:
	# Create a test generation context
	context = GenerationContext.new()
	context.config = GenerationConfig.new()
	context.config.enable_lod = true
	context.grid_size = Vector2i(64, 64)

	# Initialize LOD manager
	lod_manager = MapLODManager.new()
	lod_manager.initialize(context)


func after_each() -> void:
	lod_manager = null
	context = null


## Test: LOD manager initializes with correct settings
func test_lod_manager_initialization() -> void:
	assert_not_null(lod_manager, "LOD manager should be created")
	assert_true(lod_manager._lod_enabled, "LOD should be enabled when config.enable_lod is true")


## Test: LOD manager respects disabled configuration
func test_lod_manager_disabled() -> void:
	var disabled_context := GenerationContext.new()
	disabled_context.config = GenerationConfig.new()
	disabled_context.config.enable_lod = false

	var disabled_lod := MapLODManager.new()
	disabled_lod.initialize(disabled_context)

	assert_false(
		disabled_lod._lod_enabled, "LOD should be disabled when config.enable_lod is false"
	)


## Test: LOD distance thresholds are correctly defined
func test_lod_distance_thresholds() -> void:
	assert_eq(MapLODManager.LOD0_DISTANCE, 20.0, "LOD0 distance should be 20m")
	assert_eq(MapLODManager.LOD1_DISTANCE, 50.0, "LOD1 distance should be 50m")
	assert_eq(MapLODManager.LOD2_DISTANCE, 100.0, "LOD2 distance should be 100m")


## Test: LOD complexity ratios are correctly defined
func test_lod_complexity_ratios() -> void:
	assert_eq(MapLODManager.LOD1_COMPLEXITY, 0.5, "LOD1 should have 50% complexity")
	assert_eq(MapLODManager.LOD2_COMPLEXITY, 0.25, "LOD2 should have 25% complexity")


## Test: LOD statistics are returned correctly
func test_lod_statistics() -> void:
	var stats := lod_manager.get_lod_statistics()

	assert_not_null(stats, "Statistics should be returned")
	assert_true(stats.has("lod_enabled"), "Stats should include lod_enabled")
	assert_true(stats.has("lod0_distance"), "Stats should include lod0_distance")
	assert_true(stats.has("lod1_distance"), "Stats should include lod1_distance")
	assert_true(stats.has("lod2_distance"), "Stats should include lod2_distance")
	assert_true(stats.has("lod1_complexity"), "Stats should include lod1_complexity")
	assert_true(stats.has("lod2_complexity"), "Stats should include lod2_complexity")

	assert_eq(stats["lod_enabled"], true, "LOD should be enabled in stats")
	assert_eq(stats["lod0_distance"], 20.0, "LOD0 distance should match")
	assert_eq(stats["lod1_distance"], 50.0, "LOD1 distance should match")


## Test: Minimum vertex count threshold is reasonable
func test_minimum_vertex_threshold() -> void:
	assert_eq(
		MapLODManager.MIN_VERTEX_COUNT_FOR_LOD,
		100,
		"Minimum vertex count should be 100 to skip simple meshes"
	)


## Test: LOD manager handles null context gracefully
func test_null_context_handling() -> void:
	var test_lod := MapLODManager.new()
	# Don't initialize - context should be null

	# This should not crash
	var stats := test_lod.get_lod_statistics()
	assert_not_null(stats, "Should return stats even without initialization")


## Test: Apply LOD to scene with disabled LOD skips processing
func test_apply_lod_disabled() -> void:
	var disabled_context := GenerationContext.new()
	disabled_context.config = GenerationConfig.new()
	disabled_context.config.enable_lod = false

	var disabled_lod := MapLODManager.new()
	disabled_lod.initialize(disabled_context)

	var root := Node3D.new()
	add_child_autofree(root)

	# This should skip processing and not crash
	disabled_lod.apply_lod_to_scene(root)

	# No assertions needed - just verify it doesn't crash


## Test: Apply LOD to empty scene doesn't crash
func test_apply_lod_empty_scene() -> void:
	var root := Node3D.new()
	add_child_autofree(root)

	context.csg_root = null
	context.prefab_instances = []

	# This should not crash
	lod_manager.apply_lod_to_scene(root)

	# No assertions needed - just verify it doesn't crash
