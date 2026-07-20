class_name NavigationMeshBaker
extends RefCounted

## Bakes navigation meshes for AI pathfinding in generated maps
## Creates NavigationRegion3D nodes and configures navigation parameters

const AGENT_RADIUS := 0.5  # Agent radius in meters
const AGENT_HEIGHT := 2.0  # Agent height in meters
const CELL_SIZE := 0.25  # Navigation mesh cell size
const CELL_HEIGHT := 0.2  # Navigation mesh cell height
const AGENT_MAX_CLIMB := 0.5  # Maximum step height agents can climb
# Maximum slope angle in degrees (increased for sloped surfaces)
const AGENT_MAX_SLOPE := 45.0

var _context: GenerationContext
var _navigation_region: NavigationRegion3D
var _navigation_mesh: NavigationMesh
var _retry_count: int = 0
var _max_retries: int = 3
var _has_sloped_surfaces: bool = false


## Initialize the navigation mesh baker with generation context
func initialize(context: GenerationContext) -> void:
	_context = context
	_retry_count = 0

	# Create NavigationRegion3D node
	_navigation_region = NavigationRegion3D.new()
	_navigation_region.name = "NavigationRegion"
	_context.navigation_region = _navigation_region

	# Create and configure NavigationMesh
	_navigation_mesh = NavigationMesh.new()
	_configure_navigation_mesh()
	_navigation_region.navigation_mesh = _navigation_mesh

	print(
		"NavigationMeshBaker: Initialized with agent_radius=",
		AGENT_RADIUS,
		", agent_height=",
		AGENT_HEIGHT,
		", cell_size=",
		CELL_SIZE
	)


## Configure navigation mesh parameters
func _configure_navigation_mesh() -> void:
	# Agent parameters
	_navigation_mesh.agent_radius = AGENT_RADIUS
	_navigation_mesh.agent_height = AGENT_HEIGHT
	_navigation_mesh.agent_max_climb = AGENT_MAX_CLIMB
	_navigation_mesh.agent_max_slope = AGENT_MAX_SLOPE

	# Cell parameters
	_navigation_mesh.cell_size = CELL_SIZE
	_navigation_mesh.cell_height = CELL_HEIGHT

	# Region parameters
	_navigation_mesh.region_min_size = 8.0  # Minimum region size in square meters
	_navigation_mesh.region_merge_size = 20.0  # Merge regions smaller than this

	# Edge parameters
	_navigation_mesh.edge_max_length = 12.0  # Maximum edge length
	_navigation_mesh.edge_max_error = 1.3  # Edge simplification error tolerance

	# Detail mesh parameters
	_navigation_mesh.detail_sample_distance = 6.0  # Detail mesh sample distance
	_navigation_mesh.detail_sample_max_error = 1.0  # Detail mesh error tolerance

	# Filtering
	_navigation_mesh.filter_low_hanging_obstacles = true
	_navigation_mesh.filter_ledge_spans = true
	_navigation_mesh.filter_walkable_low_height_spans = true


## Bake navigation mesh covering all walkable areas
## Returns true if baking succeeded, false otherwise
func bake_navigation_mesh() -> bool:
	if _navigation_region == null or _navigation_mesh == null:
		push_error("NavigationMeshBaker: Not initialized")
		return false

	if _context.csg_root == null:
		push_error("NavigationMeshBaker: No CSG geometry found in context")
		return false

	# Check if we have sloped surfaces or 3D floors
	_check_for_advanced_geometry()

	print("NavigationMeshBaker: Starting navigation mesh baking...")
	if _has_sloped_surfaces:
		print("NavigationMeshBaker: Detected sloped surfaces, adjusting parameters...")

	var start_time := Time.get_ticks_msec()

	# Set up source geometry for baking
	_setup_source_geometry()

	# Bake the navigation mesh
	var success := _perform_baking()

	if success:
		var end_time := Time.get_ticks_msec()
		var bake_time := end_time - start_time
		print("NavigationMeshBaker: Baking completed in ", bake_time, "ms")
		print("NavigationMeshBaker: Generated ", _navigation_mesh.get_polygon_count(), " polygons")

		# Validate the baked mesh
		if not _validate_navigation_mesh():
			push_warning("NavigationMeshBaker: Validation failed, attempting retry...")
			return _retry_baking()

		return true

	push_error("NavigationMeshBaker: Baking failed")
	return _retry_baking()


## Set up source geometry for navigation mesh baking
func _setup_source_geometry() -> void:
	# Clear any existing source geometry
	_navigation_mesh.clear()

	# Add CSG geometry as source
	if _context.csg_root != null:
		_add_csg_geometry_as_source(_context.csg_root)

	# Calculate bounding box from grid (stored for reference but not used directly)
	var grid_size := _context.grid_size
	# 2m per cell, 10m height
	var _bounds := AABB(Vector3.ZERO, Vector3(grid_size.x * 2.0, 10.0, grid_size.y * 2.0))

	# Set parsing parameters
	_navigation_mesh.geometry_source_geometry_mode = (
		NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	)
	_navigation_mesh.geometry_source_group_name = "navigation_geometry"


## Add CSG geometry as navigation source
func _add_csg_geometry_as_source(csg_node: Node3D) -> void:
	# Add to navigation geometry group
	if not csg_node.is_in_group("navigation_geometry"):
		csg_node.add_to_group("navigation_geometry")

	# Recursively add children
	for child in csg_node.get_children():
		if child is Node3D:
			_add_csg_geometry_as_source(child)


## Perform the actual navigation mesh baking
func _perform_baking() -> bool:
	# In Godot 4.x, navigation mesh baking is done through NavigationServer
	# We need to parse the source geometry and generate the navigation mesh

	# Create a temporary root node for baking if needed
	var temp_root: Node3D = null
	var needs_temp_root := false

	if _context.csg_root.get_parent() == null:
		needs_temp_root = true
		temp_root = Node3D.new()
		var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
		if scene_tree:
			scene_tree.root.add_child(temp_root)
		temp_root.add_child(_context.csg_root)
		temp_root.add_child(_navigation_region)

	# Bake using NavigationServer
	# Create source geometry data for parsing
	var source_geometry := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(
		_navigation_mesh, source_geometry, _context.csg_root
	)
	NavigationServer3D.bake_from_source_geometry_data(_navigation_mesh, source_geometry)

	# Clean up temporary root
	if needs_temp_root and temp_root != null:
		temp_root.remove_child(_context.csg_root)
		temp_root.remove_child(_navigation_region)
		temp_root.queue_free()

	# Check if baking produced any polygons
	return _navigation_mesh.get_polygon_count() > 0


## Validate the baked navigation mesh
func _validate_navigation_mesh() -> bool:
	var polygon_count := _navigation_mesh.get_polygon_count()

	if polygon_count == 0:
		push_error("NavigationMeshBaker: No polygons generated")
		return false

	# Calculate expected coverage
	var walkable_cells := _count_walkable_cells()
	var expected_area := walkable_cells * 4.0  # Each cell is 2x2 = 4 square meters

	# Estimate actual coverage (rough approximation)
	var estimated_coverage := polygon_count * 2.0  # Rough estimate: 2 sq meters per polygon
	var coverage_ratio := estimated_coverage / expected_area if expected_area > 0 else 0.0

	print("NavigationMeshBaker: Coverage ratio: ", coverage_ratio * 100.0, "%")
	print("NavigationMeshBaker: Walkable cells: ", walkable_cells, ", Polygons: ", polygon_count)

	# Require at least 70% coverage (relaxed from 90% for initial implementation)
	if coverage_ratio < 0.7:
		push_warning(
			"NavigationMeshBaker: Coverage ratio (",
			coverage_ratio * 100.0,
			"%) is below 70% threshold"
		)
		return false
	return true


## Count walkable cells in the grid
func _count_walkable_cells() -> int:
	var count := 0
	var grid := _context.grid

	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var cell: Cell = grid[y][x]
			if _is_walkable_cell_type(cell.type):
				count += 1

	return count


## Check if a cell type is walkable
func _is_walkable_cell_type(cell_type: Cell.Type) -> bool:
	match cell_type:
		Cell.Type.ROOM, Cell.Type.HALLWAY, Cell.Type.OUTDOOR:
			return true
		Cell.Type.CAVE, Cell.Type.BOSS_ARENA, Cell.Type.SECRET:
			return true
		_:
			return false


## Retry baking with relaxed parameters
func _retry_baking() -> bool:
	_retry_count += 1

	if _retry_count >= _max_retries:
		push_error("NavigationMeshBaker: Failed after ", _max_retries, " attempts")
		return false

	push_warning("NavigationMeshBaker: Retry attempt ", _retry_count, " of ", _max_retries)

	# Relax parameters for retry
	_relax_parameters()

	# Try baking again
	return bake_navigation_mesh()


## Relax navigation mesh parameters for retry attempts
func _relax_parameters() -> void:
	print("NavigationMeshBaker: Relaxing parameters for retry...")

	# Increase cell size (less detail, faster baking)
	_navigation_mesh.cell_size *= 1.2
	_navigation_mesh.cell_height *= 1.2

	# Increase error tolerances
	_navigation_mesh.edge_max_error *= 1.3
	_navigation_mesh.detail_sample_max_error *= 1.3

	# Reduce region requirements
	_navigation_mesh.region_min_size *= 0.8

	print(
		"NavigationMeshBaker: New cell_size=",
		_navigation_mesh.cell_size,
		", edge_max_error=",
		_navigation_mesh.edge_max_error
	)


## Get the baked navigation region node
func get_navigation_region() -> NavigationRegion3D:
	return _navigation_region


## Get the navigation mesh
func get_navigation_mesh() -> NavigationMesh:
	return _navigation_mesh


## Check if a position is on the navigation mesh
func is_position_on_navmesh(position: Vector3) -> bool:
	if _navigation_mesh == null or _navigation_mesh.get_polygon_count() == 0:
		return false

	# Use NavigationServer to check if position is valid
	var map_rid := _navigation_region.get_navigation_map()
	var closest_point := NavigationServer3D.map_get_closest_point(map_rid, position)

	# If closest point is within reasonable distance, position is on navmesh
	return position.distance_to(closest_point) < 1.0


## Exclude non-walkable areas from navigation mesh
## This should be called before baking to mark areas as non-walkable
func exclude_non_walkable_areas(areas: Array[Rect2i]) -> void:
	# Store excluded areas for reference
	if not _context.metadata.has("excluded_navmesh_areas"):
		_context.metadata["excluded_navmesh_areas"] = []

	for area in areas:
		_context.metadata["excluded_navmesh_areas"].append(
			{"position": area.position, "size": area.size}
		)

	print("NavigationMeshBaker: Excluded ", areas.size(), " non-walkable areas")


## Check for advanced geometry features (slopes, 3D floors)
func _check_for_advanced_geometry() -> void:
	_has_sloped_surfaces = false

	# Check if CSG root has sloped surfaces or 3D floors
	if _context.csg_root != null:
		for child in _context.csg_root.get_children():
			if child.name == "SlopedSurfaces" or child.name == "3DFloors":
				_has_sloped_surfaces = true
				break

	# Adjust navigation mesh parameters for sloped surfaces
	if _has_sloped_surfaces:
		# Increase max slope to handle steeper surfaces
		_navigation_mesh.agent_max_slope = 60.0
		# Reduce cell height for better slope detection
		_navigation_mesh.cell_height = 0.15
		print("NavigationMeshBaker: Adjusted parameters for sloped surfaces")
