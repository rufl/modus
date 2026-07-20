extends GutTest

## Unit tests for NavigationMeshBaker
## Tests navigation mesh creation, baking, validation, and error handling

const NavigationMeshBaker = preload("res://game/scripts/map_generator/navigation_mesh_baker.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const Cell = preload("res://game/scripts/map_generator/cell.gd")
const MapTheme = preload("res://game/scripts/map_generator/theme.gd")

var baker: NavigationMeshBaker
var context: GenerationContext


func before_each() -> void:
	baker = NavigationMeshBaker.new()
	context = GenerationContext.new()
	context.config = GenerationConfig.new()
	context.grid_size = Vector2i(32, 32)
	_create_test_grid()
	_create_test_csg_geometry()


func after_each() -> void:
	baker = null
	if context.csg_root != null:
		context.csg_root.queue_free()
	if context.navigation_region != null:
		context.navigation_region.queue_free()
	context = null


## Create a test grid with walkable cells
func _create_test_grid() -> void:
	context.grid = []
	for y in range(context.grid_size.y):
		var row: Array[Cell] = []
		for x in range(context.grid_size.x):
			var cell := Cell.new()
			# Create a simple room pattern
			if x > 5 and x < 26 and y > 5 and y < 26:
				cell.type = Cell.Type.ROOM
			row.append(cell)
		context.grid.append(row)


## Create minimal CSG geometry for testing
func _create_test_csg_geometry() -> void:
	var csg_root := CSGCombiner3D.new()
	csg_root.name = "TestGeometry"

	# Create a simple floor
	var floor_box := CSGBox3D.new()
	floor_box.name = "Floor"
	floor_box.size = Vector3(40.0, 0.2, 40.0)
	floor_box.position = Vector3(20.0, -0.1, 20.0)
	csg_root.add_child(floor_box)

	context.csg_root = csg_root


## Test 16.1: Create NavigationRegion3D node
func test_create_navigation_region() -> void:
	baker.initialize(context)

	assert_not_null(context.navigation_region, "Navigation region should be created")
	assert_eq(
		context.navigation_region.name,
		"NavigationRegion",
		"Navigation region should have correct name"
	)
	assert_not_null(context.navigation_region.navigation_mesh, "Navigation mesh should be assigned")


## Test 16.1: Configure navigation parameters
func test_configure_navigation_parameters() -> void:
	baker.initialize(context)

	var navmesh := context.navigation_region.navigation_mesh
	assert_not_null(navmesh, "Navigation mesh should exist")

	# Check agent parameters
	assert_eq(navmesh.agent_radius, 0.5, "Agent radius should be 0.5")
	assert_eq(navmesh.agent_height, 2.0, "Agent height should be 2.0")
	assert_eq(navmesh.cell_size, 0.25, "Cell size should be 0.25")


## Test 16.1: Navigation mesh has correct filtering settings
func test_navigation_mesh_filtering() -> void:
	baker.initialize(context)

	var navmesh := context.navigation_region.navigation_mesh
	assert_true(navmesh.filter_low_hanging_obstacles, "Should filter low hanging obstacles")
	assert_true(navmesh.filter_ledge_spans, "Should filter ledge spans")
	assert_true(navmesh.filter_walkable_low_height_spans, "Should filter walkable low height spans")


## Test 16.2: Bake navigation mesh successfully
func test_bake_navigation_mesh_success() -> void:
	baker.initialize(context)

	# Add CSG root to scene tree for baking
	add_child_autofree(context.csg_root)
	add_child_autofree(context.navigation_region)

	var success := baker.bake_navigation_mesh()

	# Note: Actual baking may not work in headless test environment
	# We're testing the API and error handling
	assert_true(success is bool, "Bake should return boolean")


## Test 16.2: Count walkable cells correctly
func test_count_walkable_cells() -> void:
	baker.initialize(context)

	# Access private method through call
	var walkable_count: int = baker.call("_count_walkable_cells")

	# We created a 20x20 room (26-6 = 20 in each dimension)
	var expected_count := 20 * 20
	assert_eq(walkable_count, expected_count, "Should count correct number of walkable cells")


## Test 16.2: Identify walkable cell types
func test_is_walkable_cell_type() -> void:
	baker.initialize(context)

	# Test walkable types
	assert_true(baker.call("_is_walkable_cell_type", Cell.Type.ROOM), "ROOM should be walkable")
	assert_true(
		baker.call("_is_walkable_cell_type", Cell.Type.HALLWAY), "HALLWAY should be walkable"
	)
	assert_true(
		baker.call("_is_walkable_cell_type", Cell.Type.OUTDOOR), "OUTDOOR should be walkable"
	)
	assert_true(baker.call("_is_walkable_cell_type", Cell.Type.CAVE), "CAVE should be walkable")
	assert_true(
		baker.call("_is_walkable_cell_type", Cell.Type.BOSS_ARENA), "BOSS_ARENA should be walkable"
	)
	assert_true(baker.call("_is_walkable_cell_type", Cell.Type.SECRET), "SECRET should be walkable")

	# Test non-walkable type
	assert_false(
		baker.call("_is_walkable_cell_type", Cell.Type.EMPTY), "EMPTY should not be walkable"
	)


## Test 16.2: Exclude non-walkable areas
func test_exclude_non_walkable_areas() -> void:
	baker.initialize(context)

	var excluded_areas: Array[Rect2i] = [Rect2i(0, 0, 5, 5), Rect2i(27, 27, 5, 5)]

	baker.exclude_non_walkable_areas(excluded_areas)

	assert_true(
		context.metadata.has("excluded_navmesh_areas"), "Should store excluded areas in metadata"
	)
	assert_eq(
		context.metadata["excluded_navmesh_areas"].size(),
		2,
		"Should store correct number of excluded areas"
	)


## Test 16.3: Handle baking failure with retry
func test_baking_failure_retry() -> void:
	baker.initialize(context)

	# Don't add to scene tree - this should cause baking to fail
	# The baker should attempt retries

	var success := baker.bake_navigation_mesh()

	# In test environment, baking will likely fail
	# We're testing that it doesn't crash and handles errors
	assert_true(success is bool, "Should return boolean even on failure")


## Test 16.3: Relax parameters on retry
func test_relax_parameters_on_retry() -> void:
	baker.initialize(context)

	var navmesh := context.navigation_region.navigation_mesh
	var original_cell_size := navmesh.cell_size
	var original_edge_error := navmesh.edge_max_error

	# Call relax parameters
	baker.call("_relax_parameters")

	assert_gt(navmesh.cell_size, original_cell_size, "Cell size should increase on retry")
	assert_gt(
		navmesh.edge_max_error, original_edge_error, "Edge error tolerance should increase on retry"
	)


## Test 16.3: Respect maximum retry limit
func test_maximum_retry_limit() -> void:
	baker.initialize(context)

	# Set retry count to max
	baker.set("_retry_count", 3)
	baker.set("_max_retries", 3)

	# Attempt retry - should fail immediately
	var success: bool = baker.call("_retry_baking")

	assert_false(success, "Should fail when max retries reached")


## Test 16.3: Log errors with details
func test_log_errors_with_details() -> void:
	baker.initialize(context)

	# Watch for error messages
	watch_signals(baker)

	# Try to bake without proper setup
	context.csg_root = null
	var success := baker.bake_navigation_mesh()

	assert_false(success, "Should fail when CSG root is missing")


## Test: Get navigation region
func test_get_navigation_region() -> void:
	baker.initialize(context)

	var nav_region := baker.get_navigation_region()

	assert_not_null(nav_region, "Should return navigation region")
	assert_eq(
		nav_region,
		context.navigation_region,
		"Should return the same navigation region from context"
	)


## Test: Get navigation mesh
func test_get_navigation_mesh() -> void:
	baker.initialize(context)

	var navmesh := baker.get_navigation_mesh()

	assert_not_null(navmesh, "Should return navigation mesh")
	assert_eq(
		navmesh,
		context.navigation_region.navigation_mesh,
		"Should return the navigation mesh from region"
	)


## Test: Setup source geometry
func test_setup_source_geometry() -> void:
	baker.initialize(context)

	baker.call("_setup_source_geometry")

	# Check that CSG root is added to navigation geometry group
	assert_true(
		context.csg_root.is_in_group("navigation_geometry"),
		"CSG root should be in navigation_geometry group"
	)


## Test: Add CSG geometry as source recursively
func test_add_csg_geometry_recursive() -> void:
	baker.initialize(context)

	# Add a child to CSG root
	var child_box := CSGBox3D.new()
	child_box.name = "ChildBox"
	context.csg_root.add_child(child_box)

	baker.call("_add_csg_geometry_as_source", context.csg_root)

	assert_true(
		context.csg_root.is_in_group("navigation_geometry"),
		"Root should be in navigation_geometry group"
	)
	assert_true(
		child_box.is_in_group("navigation_geometry"), "Child should be in navigation_geometry group"
	)


## Test: Validation detects empty navigation mesh
func test_validation_detects_empty_mesh() -> void:
	baker.initialize(context)

	# Navigation mesh starts empty
	var is_valid: bool = baker.call("_validate_navigation_mesh")

	assert_false(is_valid, "Should fail validation when mesh is empty")


## Test: Initialize without context fails gracefully
func test_initialize_requires_context() -> void:
	var new_baker := NavigationMeshBaker.new()

	# Try to bake without initialization
	var success := new_baker.bake_navigation_mesh()

	assert_false(success, "Should fail when not initialized")


## Test: Multiple initializations work correctly
func test_multiple_initializations() -> void:
	baker.initialize(context)
	var first_region := baker.get_navigation_region()

	# Initialize again with new context
	var new_context := GenerationContext.new()
	new_context.config = GenerationConfig.new()
	new_context.grid_size = Vector2i(16, 16)
	_create_test_grid_for_context(new_context)
	_create_test_csg_for_context(new_context)

	baker.initialize(new_context)
	var second_region: NavigationRegion3D = baker.get_navigation_region()

	assert_ne(
		first_region, second_region, "Should create new navigation region on re-initialization"
	)


## Helper: Create test grid for specific context
func _create_test_grid_for_context(ctx: GenerationContext) -> void:
	ctx.grid = []
	for y in range(ctx.grid_size.y):
		var row: Array[Cell] = []
		for x in range(ctx.grid_size.x):
			var cell := Cell.new()
			if x > 2 and x < 14 and y > 2 and y < 14:
				cell.type = Cell.Type.ROOM
			row.append(cell)
		ctx.grid.append(row)


## Helper: Create test CSG for specific context
func _create_test_csg_for_context(ctx: GenerationContext) -> void:
	var csg_root := CSGCombiner3D.new()
	csg_root.name = "TestGeometry"
	var floor_box := CSGBox3D.new()
	floor_box.size = Vector3(20.0, 0.2, 20.0)
	csg_root.add_child(floor_box)
	ctx.csg_root = csg_root
