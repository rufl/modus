class_name CSGGeometryBuilder
extends RefCounted

## Builds 3D level geometry using CSG (Constructive Solid Geometry) nodes
## Converts grid-based layout into walls, floors, ceilings, and doorways

const CELL_SIZE := 2.0  # Each grid cell is 2m x 2m in world space
const WALL_HEIGHT := 3.0  # Standard wall height in meters
const WALL_THICKNESS := 0.2  # Wall thickness in meters
const FLOOR_THICKNESS := 0.2  # Floor thickness in meters
const CEILING_THICKNESS := 0.2  # Ceiling thickness in meters
const DOORWAY_WIDTH := 2.0  # Standard doorway width in meters
const DOORWAY_HEIGHT := 2.5  # Standard doorway height in meters

var _context: GenerationContext
var _csg_root: CSGCombiner3D
var _wall_material: Material
var _floor_material: Material
var _ceiling_material: Material
var _advanced_geometry: RefCounted  # AdvancedGeometryBuilder (dynamic loading)
var _occlusion_culling: RefCounted  # OcclusionCullingManager (dynamic loading)


## Initialize the CSG geometry builder with generation context
func initialize(context: GenerationContext) -> void:
	_context = context
	_csg_root = CSGCombiner3D.new()
	_csg_root.name = "MapGeometry"
	_csg_root.use_collision = true
	_context.csg_root = _csg_root

	# Initialize advanced geometry builder
	var AdvancedGeometryBuilderClass: GDScript = load(
		"res://game/scripts/map_generator/advanced_geometry_builder.gd"
	)
	_advanced_geometry = AdvancedGeometryBuilderClass.new()
	_advanced_geometry.initialize(_context, _csg_root)

	# Initialize occlusion culling manager
	var OcclusionCullingManagerClass: GDScript = load(
		"res://game/scripts/map_generator/occlusion_culling_manager.gd"
	)
	_occlusion_culling = OcclusionCullingManagerClass.new()
	_occlusion_culling.initialize(_context)

	# Load theme materials
	_load_theme_materials()


## Load materials based on the current theme
func _load_theme_materials() -> void:
	# If theme is not set, create a default theme
	if _context.theme == null:
		_context.theme = MapTheme.create_default_theme(_context.config.theme)

	# Load materials from theme
	_wall_material = _context.theme.wall_material
	_floor_material = _context.theme.floor_material
	_ceiling_material = _context.theme.ceiling_material

	# Log material loading
	if _wall_material and _floor_material and _ceiling_material:
		print("CSGGeometryBuilder: Loaded materials for theme: ", _context.theme.get_theme_name())
	else:
		push_warning(
			"CSGGeometryBuilder: Some materials are missing for theme: ",
			_context.theme.get_theme_name()
		)


## Build all geometry from the grid layout
func build_geometry() -> CSGCombiner3D:
	if _csg_root == null:
		push_error("CSGGeometryBuilder not initialized")
		return null

	_build_floors()
	_build_walls()
	_build_ceilings()
	_create_doorways()

	# Build advanced geometry features (slopes and 3D floors)
	_advanced_geometry.build_advanced_geometry()

	# Generate occlusion culling occluders if enabled
	if _context.config.enable_occlusion_culling:
		var occluders_root: Node3D = _occlusion_culling.generate_occluders()
		_csg_root.add_child(occluders_root)

	return _csg_root


## Bake CSG geometry to static meshes for improved performance
## Returns a MeshInstance3D with baked geometry and collision
func bake_geometry() -> MeshInstance3D:
	if _csg_root == null:
		push_error("CSGGeometryBuilder: Cannot bake, no CSG root exists")
		return null

	print("CSGGeometryBuilder: Baking CSG geometry to static mesh...")

	# Get the baked mesh from CSG
	var meshes := _csg_root.get_meshes()
	if meshes.is_empty():
		push_error("CSGGeometryBuilder: No meshes found in CSG root")
		return null

	# Create MeshInstance3D with baked mesh
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "BakedMapGeometry"
	mesh_instance.mesh = meshes[1]  # Index 1 contains the actual mesh

	# Create collision shape from baked mesh
	var static_body := StaticBody3D.new()
	static_body.name = "Collision"

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	collision_shape.shape = mesh_instance.mesh.create_trimesh_shape()

	static_body.add_child(collision_shape)
	mesh_instance.add_child(static_body)

	print(
		"CSGGeometryBuilder: Baking complete. Mesh has ",
		mesh_instance.mesh.get_surface_count(),
		" surfaces"
	)

	return mesh_instance


## Replace CSG geometry with baked mesh in the scene
## This removes the CSG nodes and replaces them with optimized static mesh
func replace_with_baked_mesh(parent_node: Node3D) -> MeshInstance3D:
	var baked_mesh := bake_geometry()
	if baked_mesh == null:
		return null

	# Add baked mesh to parent
	parent_node.add_child(baked_mesh)

	# Remove CSG root from parent if it's attached
	if _csg_root.get_parent() == parent_node:
		parent_node.remove_child(_csg_root)

	# Queue CSG root for deletion
	_csg_root.queue_free()
	_csg_root = null

	print("CSGGeometryBuilder: Replaced CSG geometry with baked mesh")

	return baked_mesh


## Create floor geometry for all walkable cells
func _build_floors() -> void:
	var floor_combiner := CSGCombiner3D.new()
	floor_combiner.name = "Floors"

	for y in range(_context.grid.size()):
		for x in range(_context.grid[y].size()):
			var cell: Cell = _context.grid[y][x]

			# Skip empty cells
			if cell.type == Cell.Type.EMPTY:
				continue

			# Create floor box for this cell
			var floor_box := CSGBox3D.new()
			floor_box.name = "Floor_%d_%d" % [x, y]
			floor_box.size = Vector3(CELL_SIZE, FLOOR_THICKNESS, CELL_SIZE)

			# Position at cell center, slightly below ground level
			var world_pos := _grid_to_world(Vector2i(x, y))
			floor_box.position = Vector3(
				world_pos.x, -FLOOR_THICKNESS / 2.0 + cell.height, world_pos.y
			)

			# Apply material override if specified
			if cell.material_override:
				floor_box.material = cell.material_override
			elif _floor_material:
				floor_box.material = _floor_material

			floor_combiner.add_child(floor_box)

	_csg_root.add_child(floor_combiner)


## Create wall geometry for all cell boundaries
func _build_walls() -> void:
	var wall_combiner := CSGCombiner3D.new()
	wall_combiner.name = "Walls"

	# Track which walls have been created to avoid duplicates
	var created_walls: Dictionary = {}

	for y in range(_context.grid.size()):
		for x in range(_context.grid[y].size()):
			var cell: Cell = _context.grid[y][x]

			# Skip empty cells
			if cell.type == Cell.Type.EMPTY:
				continue

			# Check all 4 directions for walls
			# East
			_create_wall_if_needed(wall_combiner, Vector2i(x, y), Vector2i(1, 0), created_walls)
			# South
			_create_wall_if_needed(wall_combiner, Vector2i(x, y), Vector2i(0, 1), created_walls)

	_csg_root.add_child(wall_combiner)


## Create a wall between two cells if needed
func _create_wall_if_needed(
	parent: CSGCombiner3D, cell_pos: Vector2i, direction: Vector2i, created_walls: Dictionary
) -> void:
	var neighbor_pos := cell_pos + direction

	# Check if neighbor is out of bounds or empty
	var needs_wall := false
	if not _is_valid_grid_pos(neighbor_pos):
		needs_wall = true
	else:
		var neighbor_cell: Cell = _context.grid[neighbor_pos.y][neighbor_pos.x]
		if neighbor_cell.type == Cell.Type.EMPTY:
			needs_wall = true

	if not needs_wall:
		return

	# Create unique wall key to avoid duplicates
	var wall_key := _get_wall_key(cell_pos, neighbor_pos)
	if created_walls.has(wall_key):
		return

	created_walls[wall_key] = true

	# Create wall box
	var wall_box := CSGBox3D.new()
	wall_box.name = "Wall_%d_%d_to_%d_%d" % [cell_pos.x, cell_pos.y, neighbor_pos.x, neighbor_pos.y]

	# Determine wall orientation and size
	var is_horizontal := direction.x != 0
	if is_horizontal:
		wall_box.size = Vector3(WALL_THICKNESS, WALL_HEIGHT, CELL_SIZE)
	else:
		wall_box.size = Vector3(CELL_SIZE, WALL_HEIGHT, WALL_THICKNESS)

	# Position wall at cell boundary
	var world_pos := _grid_to_world(cell_pos)
	var offset := Vector2(direction.x * CELL_SIZE / 2.0, direction.y * CELL_SIZE / 2.0)
	wall_box.position = Vector3(world_pos.x + offset.x, WALL_HEIGHT / 2.0, world_pos.y + offset.y)

	# Apply material
	var cell: Cell = _context.grid[cell_pos.y][cell_pos.x]
	if cell.material_override:
		wall_box.material = cell.material_override
	elif _wall_material:
		wall_box.material = _wall_material

	parent.add_child(wall_box)


## Create ceiling geometry for indoor cells
func _build_ceilings() -> void:
	var ceiling_combiner := CSGCombiner3D.new()
	ceiling_combiner.name = "Ceilings"

	for y in range(_context.grid.size()):
		for x in range(_context.grid[y].size()):
			var cell: Cell = _context.grid[y][x]

			# Skip empty cells and outdoor areas (no ceiling)
			if cell.type == Cell.Type.EMPTY or cell.type == Cell.Type.OUTDOOR:
				continue

			# Create ceiling box for this cell
			var ceiling_box := CSGBox3D.new()
			ceiling_box.name = "Ceiling_%d_%d" % [x, y]
			ceiling_box.size = Vector3(CELL_SIZE, CEILING_THICKNESS, CELL_SIZE)

			# Position at cell center, at ceiling height
			var world_pos := _grid_to_world(Vector2i(x, y))
			ceiling_box.position = Vector3(
				world_pos.x, WALL_HEIGHT + CEILING_THICKNESS / 2.0 + cell.height, world_pos.y
			)

			# Apply material override if specified
			if cell.material_override:
				ceiling_box.material = cell.material_override
			elif _ceiling_material:
				ceiling_box.material = _ceiling_material

			ceiling_combiner.add_child(ceiling_box)

	_csg_root.add_child(ceiling_combiner)


## Convert grid coordinates to world position (center of cell)
func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * CELL_SIZE + CELL_SIZE / 2.0, grid_pos.y * CELL_SIZE + CELL_SIZE / 2.0
	)


## Check if grid position is valid
func _is_valid_grid_pos(pos: Vector2i) -> bool:
	return (
		pos.y >= 0
		and pos.y < _context.grid.size()
		and pos.x >= 0
		and pos.x < _context.grid[pos.y].size()
	)


## Create unique key for wall between two cells
func _get_wall_key(pos1: Vector2i, pos2: Vector2i) -> String:
	var min_x := mini(pos1.x, pos2.x)
	var max_x := maxi(pos1.x, pos2.x)
	var min_y := mini(pos1.y, pos2.y)
	var max_y := maxi(pos1.y, pos2.y)
	return "%d_%d_%d_%d" % [min_x, min_y, max_x, max_y]


## Create doorways at hallway connections using CSG subtraction
func _create_doorways() -> void:
	var doorway_combiner := CSGCombiner3D.new()
	doorway_combiner.name = "Doorways"
	doorway_combiner.operation = CSGShape3D.OPERATION_SUBTRACTION

	# Create doorways for all hallway connections
	for hallway in _context.hallways:
		_create_doorways_for_hallway(doorway_combiner, hallway)

	# Create doorways at room entrance points
	for room in _context.rooms:
		_create_doorways_for_room(doorway_combiner, room)

	_csg_root.add_child(doorway_combiner)


## Create doorways along a hallway path
func _create_doorways_for_hallway(parent: CSGCombiner3D, hallway: Hallway) -> void:
	# Track doorways created to avoid duplicates
	var created_doorways: Dictionary = {}

	for i in range(hallway.path.size() - 1):
		var current_pos := hallway.path[i]
		var next_pos := hallway.path[i + 1]

		# Check if we're transitioning between different cell types
		var current_cell: Cell = _context.grid[current_pos.y][current_pos.x]
		var next_cell: Cell = _context.grid[next_pos.y][next_pos.x]

		# Create doorway if transitioning from hallway to room or vice versa
		if (
			(current_cell.type == Cell.Type.HALLWAY and next_cell.type == Cell.Type.ROOM)
			or (current_cell.type == Cell.Type.ROOM and next_cell.type == Cell.Type.HALLWAY)
		):
			_create_doorway_between_cells(parent, current_pos, next_pos, created_doorways)


## Create doorways at room entrance points
func _create_doorways_for_room(parent: CSGCombiner3D, room: Room) -> void:
	var created_doorways: Dictionary = {}

	for entrance_point in room.entrance_points:
		# Check all 4 directions for hallway connections
		var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

		for direction: Vector2i in directions:
			var neighbor_pos: Vector2i = entrance_point + direction

			if not _is_valid_grid_pos(neighbor_pos):
				continue

			var neighbor_cell: Cell = _context.grid[neighbor_pos.y][neighbor_pos.x]

			# Create doorway if neighbor is a hallway
			if neighbor_cell.type == Cell.Type.HALLWAY:
				_create_doorway_between_cells(
					parent, entrance_point, neighbor_pos, created_doorways
				)


## Create a doorway between two adjacent cells
func _create_doorway_between_cells(
	parent: CSGCombiner3D, pos1: Vector2i, pos2: Vector2i, created_doorways: Dictionary
) -> void:
	# Create unique doorway key to avoid duplicates
	var doorway_key := _get_wall_key(pos1, pos2)
	if created_doorways.has(doorway_key):
		return

	created_doorways[doorway_key] = true

	# Determine doorway orientation
	var direction := pos2 - pos1
	var is_horizontal := direction.x != 0

	# Create doorway box for subtraction
	var doorway_box := CSGBox3D.new()
	doorway_box.name = "Doorway_%d_%d_to_%d_%d" % [pos1.x, pos1.y, pos2.x, pos2.y]

	# Size doorway slightly larger than standard to ensure clean subtraction
	if is_horizontal:
		doorway_box.size = Vector3(WALL_THICKNESS + 0.1, DOORWAY_HEIGHT, DOORWAY_WIDTH)
	else:
		doorway_box.size = Vector3(DOORWAY_WIDTH, DOORWAY_HEIGHT, WALL_THICKNESS + 0.1)

	# Position doorway at cell boundary
	var world_pos := _grid_to_world(pos1)
	var offset := Vector2(direction.x * CELL_SIZE / 2.0, direction.y * CELL_SIZE / 2.0)
	doorway_box.position = Vector3(
		world_pos.x + offset.x, DOORWAY_HEIGHT / 2.0, world_pos.y + offset.y
	)

	parent.add_child(doorway_box)


## Add a sloped floor at the specified grid position
## angle: slope angle in degrees
## direction: direction vector for the slope (will be normalized)
func add_floor_slope(grid_pos: Vector2i, angle_degrees: float, direction: Vector2) -> void:
	if _advanced_geometry:
		_advanced_geometry.add_floor_slope(grid_pos, deg_to_rad(angle_degrees), direction)


## Add a sloped ceiling at the specified grid position
## angle: slope angle in degrees
## direction: direction vector for the slope (will be normalized)
func add_ceiling_slope(grid_pos: Vector2i, angle_degrees: float, direction: Vector2) -> void:
	if _advanced_geometry:
		_advanced_geometry.add_ceiling_slope(grid_pos, deg_to_rad(angle_degrees), direction)


## Add a 3D floor (platform over pit) at the specified grid position
## platform_height: height above base floor in meters
## thickness: platform thickness in meters (default 0.2)
func add_3d_floor(grid_pos: Vector2i, platform_height: float, thickness: float = 0.2) -> void:
	if _advanced_geometry:
		_advanced_geometry.add_3d_floor(grid_pos, platform_height, thickness)


## Parse and add UDMF-style slope definition
## udmf_string: UDMF slope definition (e.g., "angle:30,1,0" or "plane:0,0,0,1,0,0")
## grid_pos: grid position for the slope
## is_ceiling: true for ceiling slope, false for floor slope
func add_udmf_slope(udmf_string: String, grid_pos: Vector2i, is_ceiling: bool = false) -> void:
	if _advanced_geometry:
		_advanced_geometry.parse_udmf_slope(udmf_string, grid_pos, is_ceiling)


## Get the advanced geometry builder for direct access
func get_advanced_geometry_builder() -> RefCounted:
	return _advanced_geometry


## Get the occlusion culling manager for direct access
func get_occlusion_culling_manager() -> RefCounted:
	return _occlusion_culling


## Bake occlusion data during export phase
## This should be called after geometry is finalized
func bake_occlusion_data() -> void:
	if _occlusion_culling:
		_occlusion_culling.bake_occlusion_data()
