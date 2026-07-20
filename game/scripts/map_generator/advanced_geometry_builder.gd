class_name AdvancedGeometryBuilder
extends RefCounted

## Builds advanced geometry features inspired by UDMF (Universal Doom Map Format)
## Supports sloped floors/ceilings and 3D floors (platforms over pits)

const CELL_SIZE := 2.0  # Each grid cell is 2m x 2m in world space
const WALL_HEIGHT := 3.0  # Standard wall height in meters

var _context: GenerationContext
var _csg_root: CSGCombiner3D


## UDMF slope definition structure
class SlopeDefinition:
	var grid_pos: Vector2i
	var slope_type: SlopeType
	var angle: float  # Slope angle in radians
	var direction: Vector2  # Direction vector for slope
	var height_offset: float = 0.0  # Base height offset

	enum SlopeType { FLOOR_SLOPE, CEILING_SLOPE }


## 3D floor definition structure (platforms over pits)
class ThreeDFloor:
	var grid_pos: Vector2i
	var platform_height: float  # Height above base floor
	var platform_thickness: float = 0.2
	var has_collision: bool = true


var _slope_definitions: Array[SlopeDefinition] = []
var _three_d_floors: Array[ThreeDFloor] = []


## Initialize the advanced geometry builder
func initialize(context: GenerationContext, csg_root: CSGCombiner3D) -> void:
	_context = context
	_csg_root = csg_root


## Add a sloped floor definition
func add_floor_slope(grid_pos: Vector2i, angle: float, direction: Vector2) -> void:
	var slope := SlopeDefinition.new()
	slope.grid_pos = grid_pos
	slope.slope_type = SlopeDefinition.SlopeType.FLOOR_SLOPE
	slope.angle = angle
	slope.direction = direction.normalized()
	_slope_definitions.append(slope)


## Add a sloped ceiling definition
func add_ceiling_slope(grid_pos: Vector2i, angle: float, direction: Vector2) -> void:
	var slope := SlopeDefinition.new()
	slope.grid_pos = grid_pos
	slope.slope_type = SlopeDefinition.SlopeType.CEILING_SLOPE
	slope.angle = angle
	slope.direction = direction.normalized()
	_slope_definitions.append(slope)


## Add a 3D floor (platform over pit)
func add_3d_floor(grid_pos: Vector2i, platform_height: float, thickness: float = 0.2) -> void:
	var floor_3d := ThreeDFloor.new()
	floor_3d.grid_pos = grid_pos
	floor_3d.platform_height = platform_height
	floor_3d.platform_thickness = thickness
	_three_d_floors.append(floor_3d)


## Parse UDMF-style slope definition string
## Format examples:
##   "plane:0,0,0,1,0,0" - Plane equation (point + normal)
##   "angle:30,1,0" - Angle in degrees + direction vector
func parse_udmf_slope(udmf_string: String, grid_pos: Vector2i, is_ceiling: bool = false) -> void:
	var parts := udmf_string.split(":")
	if parts.size() != 2:
		push_warning("Invalid UDMF slope definition: ", udmf_string)
		return

	var slope_format := parts[0]
	var params := parts[1].split(",")

	match slope_format:
		"angle":
			if params.size() >= 3:
				var angle_deg := float(params[0])
				var direction := Vector2(float(params[1]), float(params[2]))
				var angle_rad := deg_to_rad(angle_deg)

				if is_ceiling:
					add_ceiling_slope(grid_pos, angle_rad, direction)
				else:
					add_floor_slope(grid_pos, angle_rad, direction)

		"plane":
			# Plane equation format: point(x,y,z) + normal(nx,ny,nz)
			if params.size() >= 6:
				var normal := Vector3(float(params[3]), float(params[4]), float(params[5]))
				# Convert plane normal to angle and direction
				var angle_rad := acos(normal.y)  # Angle from vertical
				var direction := Vector2(normal.x, normal.z).normalized()

				if is_ceiling:
					add_ceiling_slope(grid_pos, angle_rad, direction)
				else:
					add_floor_slope(grid_pos, angle_rad, direction)

		_:
			push_warning("Unknown UDMF slope format: ", slope_format)


## Build all advanced geometry features
func build_advanced_geometry() -> void:
	_build_sloped_surfaces()
	_build_3d_floors()


## Build sloped floor and ceiling surfaces
func _build_sloped_surfaces() -> void:
	if _slope_definitions.is_empty():
		return

	var slopes_combiner := CSGCombiner3D.new()
	slopes_combiner.name = "SlopedSurfaces"

	for slope in _slope_definitions:
		_create_sloped_surface(slopes_combiner, slope)

	_csg_root.add_child(slopes_combiner)
	print("AdvancedGeometryBuilder: Created ", _slope_definitions.size(), " sloped surfaces")


## Create a single sloped surface using mesh deformation
func _create_sloped_surface(parent: CSGCombiner3D, slope: SlopeDefinition) -> void:
	# Use CSGMesh3D with custom mesh for slopes
	var csg_mesh := CSGMesh3D.new()
	csg_mesh.name = "Slope_%d_%d" % [slope.grid_pos.x, slope.grid_pos.y]

	# Create sloped mesh using SurfaceTool
	var mesh := _create_sloped_mesh(slope)
	csg_mesh.mesh = mesh

	# Position at grid cell
	var world_pos := _grid_to_world(slope.grid_pos)
	csg_mesh.position = Vector3(world_pos.x, slope.height_offset, world_pos.y)

	# Apply material based on slope type
	var material: Material = null
	if slope.slope_type == SlopeDefinition.SlopeType.FLOOR_SLOPE:
		material = _context.theme.floor_material if _context.theme else null
	else:
		material = _context.theme.ceiling_material if _context.theme else null

	if material:
		csg_mesh.material = material

	parent.add_child(csg_mesh)


## Create a sloped mesh using SurfaceTool
func _create_sloped_mesh(slope: SlopeDefinition) -> Mesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Calculate slope height change across cell
	var height_change := tan(slope.angle) * CELL_SIZE

	# Define quad corners based on slope direction
	var half_size := CELL_SIZE / 2.0
	var corners := [
		Vector3(-half_size, 0, -half_size),
		Vector3(half_size, 0, -half_size),
		Vector3(half_size, 0, half_size),
		Vector3(-half_size, 0, half_size)
	]

	# Apply height changes based on slope direction
	for i in range(corners.size()):
		var corner: Vector3 = corners[i]
		var corner_2d := Vector2(corner.x, corner.z)
		var dot_product := corner_2d.dot(slope.direction)
		var height_adjustment := dot_product * height_change / CELL_SIZE

		if slope.slope_type == SlopeDefinition.SlopeType.CEILING_SLOPE:
			corners[i].y = WALL_HEIGHT + height_adjustment
		else:
			corners[i].y = height_adjustment

	# Calculate normal for the sloped surface
	var edge1: Vector3 = corners[1] - corners[0]
	var edge2: Vector3 = corners[2] - corners[0]
	var normal: Vector3 = edge1.cross(edge2).normalized()

	# Create two triangles for the quad
	# Triangle 1
	surface_tool.set_normal(normal)
	surface_tool.set_uv(Vector2(0, 0))
	surface_tool.add_vertex(corners[0])

	surface_tool.set_normal(normal)
	surface_tool.set_uv(Vector2(1, 0))
	surface_tool.add_vertex(corners[1])

	surface_tool.set_normal(normal)
	surface_tool.set_uv(Vector2(1, 1))
	surface_tool.add_vertex(corners[2])

	# Triangle 2
	surface_tool.set_normal(normal)
	surface_tool.set_uv(Vector2(0, 0))
	surface_tool.add_vertex(corners[0])

	surface_tool.set_normal(normal)
	surface_tool.set_uv(Vector2(1, 1))
	surface_tool.add_vertex(corners[2])

	surface_tool.set_normal(normal)
	surface_tool.set_uv(Vector2(0, 1))
	surface_tool.add_vertex(corners[3])

	surface_tool.generate_normals()
	return surface_tool.commit()


## Build 3D floors (platforms over pits)
func _build_3d_floors() -> void:
	if _three_d_floors.is_empty():
		return

	var platforms_combiner := CSGCombiner3D.new()
	platforms_combiner.name = "3DFloors"

	for floor_3d in _three_d_floors:
		_create_3d_floor_platform(platforms_combiner, floor_3d)

	_csg_root.add_child(platforms_combiner)
	print("AdvancedGeometryBuilder: Created ", _three_d_floors.size(), " 3D floor platforms")


## Create a single 3D floor platform
func _create_3d_floor_platform(parent: CSGCombiner3D, floor_3d: ThreeDFloor) -> void:
	# Create platform using CSGBox3D
	var platform_box := CSGBox3D.new()
	platform_box.name = "Platform_%d_%d" % [floor_3d.grid_pos.x, floor_3d.grid_pos.y]
	platform_box.size = Vector3(CELL_SIZE, floor_3d.platform_thickness, CELL_SIZE)

	# Position at specified height
	var world_pos := _grid_to_world(floor_3d.grid_pos)
	platform_box.position = Vector3(world_pos.x, floor_3d.platform_height, world_pos.y)

	# Apply floor material
	if _context.theme and _context.theme.floor_material:
		platform_box.material = _context.theme.floor_material

	parent.add_child(platform_box)

	# Create collision shape if needed
	if floor_3d.has_collision:
		_create_platform_collision(platform_box, floor_3d)


## Create collision shape for 3D floor platform
func _create_platform_collision(_platform_box: CSGBox3D, _floor_3d: ThreeDFloor) -> void:
	# CSG nodes automatically generate collision when use_collision is true on root
	# Additional collision handling can be added here if needed
	pass


## Get all slope definitions (for navigation mesh integration)
func get_slope_definitions() -> Array[SlopeDefinition]:
	return _slope_definitions


## Get all 3D floor definitions (for navigation mesh integration)
func get_3d_floor_definitions() -> Array[ThreeDFloor]:
	return _three_d_floors


## Convert grid coordinates to world position (center of cell)
func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * CELL_SIZE + CELL_SIZE / 2.0, grid_pos.y * CELL_SIZE + CELL_SIZE / 2.0
	)


## Apply collision shapes to all advanced geometry
func apply_collision_shapes() -> void:
	# Collision is handled by CSG root's use_collision property
	# This method can be extended for custom collision handling
	print("AdvancedGeometryBuilder: Collision shapes applied via CSG")
