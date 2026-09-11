@tool
class_name AdvancedBrushTool
extends Node3D

## Advanced Brush Tool - Enhanced brush-based editing capabilities
## Features: Presets, batch ops, advanced shapes, smart snapping, performance optimization

# Signals
signal brush_applied(brush_type: String, count: int)
signal brush_operation_started(operation: String)
signal brush_operation_completed(operation: String, success: bool)
signal brush_operation_failed(brush_type: String, reason: String)


# Brush types
enum BrushType {
	SPHERE = 0,
	CUBE = 1,
	CYLINDER = 2,
	CONE = 3,
	PYRAMID = 4,
	WEDGE = 5,
	STAIRCASE = 6,
	ARCH = 7,
	TORUS = 8,
	CAPSULE = 9
}

# Brush operation modes
enum OperationMode { ADD = 0, REMOVE = 1, PAINT = 2, REPLACE = 3, FILL = 4, CLEAR = 5 }


# Brush preset struct
class BrushPreset:
	var name: String
	var brush_type: BrushType
	var size: Vector3 = Vector3.ONE
	var material: Material = null
	var operation_mode: OperationMode = OperationMode.ADD
	var hollow: bool = false
	var hollow_thickness: float = 0.2
	var snap_to_grid: bool = true
	var density: float = 1.0  # For scattered placement
	var rotation: Vector3 = Vector3.ZERO
	var scale_variation: float = 0.0
	var rotation_variation: float = 0.0


# Exported properties
@export_group("Brush Settings")
@export var brush_type: BrushType = BrushType.CUBE
@export var brush_size: Vector3 = Vector3.ONE
@export var brush_material: Material
@export var brush_operation_mode: OperationMode = OperationMode.ADD
@export var hollow_brush: bool = false
@export var hollow_thickness: float = 0.2

@export_group("Advanced Options")
@export var snap_to_grid: bool = true
@export var grid_size: float = 1.0
@export var brush_density: float = 1.0  # 0.0 = sparse, 1.0 = dense
@export var random_rotation: bool = false
@export var random_scale: bool = false
@export var scale_variation: float = 0.1
@export var rotation_variation: float = 0.1

@export_group("Performance")
@export var max_batch_size: int = 100  # Maximum objects to place in one operation
@export var optimize_placement: bool = true  # Use object pooling for performance

var _brush_presets: Array[BrushPreset] = []
var _is_active: bool = false
var _preview_mesh: MeshInstance3D = null
var _grid_system: Node = null
var _selected_objects: Array[Node3D] = []
var _batch_operations_queue: Array = []
var _object_pool: Dictionary = {}


func _ready() -> void:
	# Initialize brush system
	_create_preview_mesh()
	_load_default_presets()

	# Runtime and editor tools share the same preview node.


func _process(_delta: float) -> void:
	if _is_active:
		_update_preview()


func _input(event: InputEvent) -> void:
	if not _is_active:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_apply_brush()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_brush()


## Create preview mesh for brush
func _create_preview_mesh() -> void:
	_preview_mesh = MeshInstance3D.new()
	_preview_mesh.name = "BrushPreview"
	_preview_mesh.visible = false
	add_child(_preview_mesh)

	# Make it semi-transparent for preview
	var preview_mat := StandardMaterial3D.new()
	preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_mat.albedo_color = Color(0.2, 0.6, 1.0, 0.3)  # Semi-transparent blue
	preview_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_mesh.material_override = preview_mat


## Update brush preview based on current settings
func _update_preview() -> void:
	if not _preview_mesh:
		return

	var mesh: Mesh = null
	match brush_type:
		BrushType.CUBE:
			var cube_mesh := BoxMesh.new()
			cube_mesh.size = brush_size
			mesh = cube_mesh
		BrushType.SPHERE:
			var sphere_mesh := SphereMesh.new()
			sphere_mesh.radius = min(brush_size.x, min(brush_size.y, brush_size.z)) * 0.5
			sphere_mesh.height = brush_size.y
			mesh = sphere_mesh
		BrushType.CYLINDER:
			var cylinder_mesh := CylinderMesh.new()
			cylinder_mesh.top_radius = brush_size.x * 0.5
			cylinder_mesh.bottom_radius = brush_size.z * 0.5
			cylinder_mesh.height = brush_size.y
			mesh = cylinder_mesh
		BrushType.CONE:
			var cone_mesh := CylinderMesh.new()
			cone_mesh.top_radius = 0.0
			cone_mesh.bottom_radius = min(brush_size.x, brush_size.z) * 0.5
			cone_mesh.height = brush_size.y
			mesh = cone_mesh
		BrushType.PYRAMID:
			mesh = _create_pyramid_mesh(brush_size)
		BrushType.WEDGE:
			mesh = _create_wedge_mesh(brush_size)
		BrushType.STAIRCASE:
			mesh = _create_staircase_mesh(brush_size)
		BrushType.ARCH:
			mesh = _create_arch_mesh(brush_size)
		BrushType.TORUS:
			mesh = _create_torus_mesh(brush_size)
		BrushType.CAPSULE:
			mesh = _create_capsule_mesh(brush_size)

	if mesh:
		_preview_mesh.mesh = mesh
		_preview_mesh.visible = true


## Create pyramid mesh
func _create_pyramid_mesh(size: Vector3) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()

	# Define pyramid vertices
	var half_x = size.x * 0.5
	var half_z = size.z * 0.5
	var height = size.y

	# Apex
	vertices.append(Vector3(0, height, 0))
	# Base corners
	vertices.append(Vector3(-half_x, 0, -half_z))  # Bottom-left
	vertices.append(Vector3(half_x, 0, -half_z))  # Bottom-right
	vertices.append(Vector3(half_x, 0, half_z))  # Top-right
	vertices.append(Vector3(-half_x, 0, half_z))  # Top-left

	# Create triangles for each face
	var indices: PackedInt32Array = PackedInt32Array()

	# Front face
	indices.append(0)  # Apex
	indices.append(1)  # Bottom-left
	indices.append(2)  # Bottom-right

	# Right face
	indices.append(0)  # Apex
	indices.append(2)  # Bottom-right
	indices.append(3)  # Top-right

	# Back face
	indices.append(0)  # Apex
	indices.append(3)  # Top-right
	indices.append(4)  # Top-left

	# Left face
	indices.append(0)  # Apex
	indices.append(4)  # Top-left
	indices.append(1)  # Bottom-left

	# Base (two triangles)
	indices.append(1)  # Bottom-left
	indices.append(3)  # Top-right
	indices.append(2)  # Bottom-right

	indices.append(1)  # Bottom-left
	indices.append(4)  # Top-left
	indices.append(3)  # Top-right

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(0, arrays)
	return mesh


## Create wedge mesh
func _create_wedge_mesh(size: Vector3) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()

	var half_x = size.x * 0.5
	var half_z = size.z * 0.5
	var height = size.y

	# Wedge vertices (like a triangular prism)
	vertices.append(Vector3(-half_x, 0, -half_z))  # 0 - Bottom-left
	vertices.append(Vector3(half_x, 0, -half_z))  # 1 - Bottom-right
	vertices.append(Vector3(-half_x, height, -half_z))  # 2 - Top-left
	vertices.append(Vector3(half_x, 0, half_z))  # 3 - Front-right
	vertices.append(Vector3(-half_x, height, half_z))  # 4 - Front-left
	vertices.append(Vector3(half_x, height, -half_z))  # 5 - Top-right

	var indices: PackedInt32Array = PackedInt32Array()

	# Front triangle
	indices.append(0)  # Bottom-left
	indices.append(2)  # Top-left
	indices.append(1)  # Bottom-right

	# Back rectangle (split into 2 triangles)
	indices.append(3)  # Front-right
	indices.append(5)  # Top-right
	indices.append(4)  # Front-left

	indices.append(4)  # Front-left
	indices.append(5)  # Top-right
	indices.append(2)  # Top-left

	# Bottom rectangle
	indices.append(0)  # Bottom-left
	indices.append(1)  # Bottom-right
	indices.append(3)  # Front-right

	indices.append(0)  # Bottom-left
	indices.append(3)  # Front-right
	indices.append(4)  # Front-left

	# Top rectangle
	indices.append(2)  # Top-left
	indices.append(5)  # Top-right
	indices.append(4)  # Front-left

	indices.append(2)  # Top-left
	indices.append(1)  # Bottom-right
	indices.append(5)  # Top-right

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(0, arrays)
	return mesh


## Apply brush at specified position
func _apply_brush() -> void:
	var mouse_pos: Vector3 = _get_mouse_world_position()
	if mouse_pos == Vector3.ZERO:
		var reason := "Unable to determine a world position for the brush"
		push_warning("[AdvancedBrushTool] %s" % reason)
		brush_operation_failed.emit(str(brush_type), reason)
		brush_operation_completed.emit("apply_brush", false)
		return

	brush_operation_started.emit("apply_brush")

	# Calculate actual position based on grid settings
	var position: Vector3 = mouse_pos
	if snap_to_grid:
		position = _snap_to_grid(mouse_pos)

	# Determine operation based on mode
	var success: bool = false
	match brush_operation_mode:
		OperationMode.ADD:
			success = _place_brush_object(position)
		OperationMode.REMOVE:
			success = _remove_brush_object(position)
		OperationMode.FILL:
			success = _fill_area_with_brush(position)
		OperationMode.CLEAR:
			success = _clear_area(position)
		OperationMode.PAINT, OperationMode.REPLACE:
			var unsupported_reason := "Brush operation %s is not supported" % OperationMode.keys()[brush_operation_mode]
			push_error("[AdvancedBrushTool] %s" % unsupported_reason)
			brush_operation_failed.emit(str(brush_type), unsupported_reason)
		_:
			var unknown_reason := "Unknown brush operation mode: %d" % brush_operation_mode
			push_error("[AdvancedBrushTool] %s" % unknown_reason)
			brush_operation_failed.emit(str(brush_type), unknown_reason)

	brush_operation_completed.emit("apply_brush", success)
	if success:
		brush_applied.emit(str(brush_type), 1)


## Place a single brush object
func _place_brush_object(position: Vector3) -> bool:
	var shape: Node3D = null

	# Use object pooling for performance
	var pool_key: String = str(brush_type)
	if optimize_placement and _object_pool.has(pool_key) and _object_pool[pool_key].size() > 0:
		shape = _object_pool[pool_key].pop_back()
	else:
		shape = _create_brush_shape(brush_type)

	if not shape:
		return false

	# Apply transformations
	shape.position = position

	# Apply random variations if enabled
	if random_rotation:
		shape.rotation = Vector3(
			shape.rotation.x + randf_range(-rotation_variation, rotation_variation),
			shape.rotation.y + randf_range(-rotation_variation, rotation_variation),
			shape.rotation.z + randf_range(-rotation_variation, rotation_variation)
		)

	if random_scale:
		var scale_factor: float = 1.0 + randf_range(-scale_variation, scale_variation)
		shape.scale = Vector3(scale_factor, scale_factor, scale_factor) * brush_size

	# Apply material
	if brush_material:
		if shape is MeshInstance3D:
			shape.material_override = brush_material

	# Add to scene
	var parent: Node3D = _get_level_parent()
	if parent:
		parent.add_child(shape)
		# Mark as editor-placed
		shape.set_meta("editor_placed", true)
		shape.set_meta("brush_type", brush_type)
		return true

	return false


## Create brush shape based on type
func _create_brush_shape(brush_type: BrushType) -> Node3D:
	var shape: Node3D = null

	match brush_type:
		BrushType.CUBE:
			var box = CSGBox3D.new()
			box.size = brush_size
			shape = box
		BrushType.SPHERE:
			var sphere = CSGSphere3D.new()
			sphere.radius = min(brush_size.x, min(brush_size.y, brush_size.z)) * 0.5
			sphere.height = brush_size.y
			shape = sphere
		BrushType.CYLINDER:
			var cylinder = CSGCylinder3D.new()
			cylinder.radius = min(brush_size.x, brush_size.z) * 0.5
			cylinder.height = brush_size.y
			shape = cylinder
		BrushType.CONE:
			var cone = CSGCylinder3D.new()
			cone.radius = min(brush_size.x, brush_size.z) * 0.5
			cone.height = brush_size.y
			cone.cone = true
			shape = cone
		BrushType.PYRAMID:
			shape = _create_pyramid_shape(brush_size)
		BrushType.WEDGE:
			shape = _create_wedge_shape(brush_size)
		BrushType.STAIRCASE, BrushType.ARCH, BrushType.TORUS, BrushType.CAPSULE:
			var mesh_instance := MeshInstance3D.new()
			match brush_type:
				BrushType.STAIRCASE:
					mesh_instance.mesh = _create_staircase_mesh(brush_size)
				BrushType.ARCH:
					mesh_instance.mesh = _create_arch_mesh(brush_size)
				BrushType.TORUS:
					mesh_instance.mesh = _create_torus_mesh(brush_size)
				BrushType.CAPSULE:
					mesh_instance.mesh = _create_capsule_mesh(brush_size)
			shape = mesh_instance
		_:
			var invalid_brush_reason := "Unknown brush type: %d" % brush_type
			push_error("[AdvancedBrushTool] %s" % invalid_brush_reason)
			brush_operation_failed.emit(str(brush_type), invalid_brush_reason)
			return null

	# Hollowing is a CSG subtraction, not metadata. Only primitive CSG
	# shapes with reducible dimensions support hollowing.
	if hollow_brush:
		return _create_hollow_shape(shape)

	return shape


func _create_hollow_shape(outer_shape: Node3D) -> Node3D:
	if not outer_shape is CSGShape3D:
		var reason := "Brush type %s does not support hollowing" % BrushType.keys()[brush_type]
		push_error("[AdvancedBrushTool] %s" % reason)
		brush_operation_failed.emit(str(brush_type), reason)
		return null

	var wall: float = maxf(hollow_thickness, 0.001)
	var inner_shape: CSGShape3D = null
	var csg_shape := outer_shape as CSGShape3D

	if csg_shape is CSGBox3D:
		var box := csg_shape as CSGBox3D
		var inner_size := box.size - Vector3.ONE * (wall * 2.0)
		if inner_size.x <= 0.0 or inner_size.y <= 0.0 or inner_size.z <= 0.0:
			var reason := "Hollow thickness %.3f is too large for brush size %s" % [wall, str(box.size)]
			push_error("[AdvancedBrushTool] %s" % reason)
			brush_operation_failed.emit(str(brush_type), reason)
			return null
		var inner_box := CSGBox3D.new()
		inner_box.size = inner_size
		inner_shape = inner_box
	elif csg_shape is CSGSphere3D:
		var sphere := csg_shape as CSGSphere3D
		if sphere.radius <= wall or sphere.height <= wall * 2.0:
			var reason := "Hollow thickness %.3f is too large for sphere size" % wall
			push_error("[AdvancedBrushTool] %s" % reason)
			brush_operation_failed.emit(str(brush_type), reason)
			return null
		var inner_sphere := CSGSphere3D.new()
		inner_sphere.radius = sphere.radius - wall
		inner_sphere.height = sphere.height - wall * 2.0
		inner_shape = inner_sphere
	elif csg_shape is CSGCylinder3D:
		var cylinder := csg_shape as CSGCylinder3D
		if cylinder.radius <= wall or cylinder.height <= wall * 2.0:
			var reason := "Hollow thickness %.3f is too large for cylinder size" % wall
			push_error("[AdvancedBrushTool] %s" % reason)
			brush_operation_failed.emit(str(brush_type), reason)
			return null
		var inner_cylinder := CSGCylinder3D.new()
		inner_cylinder.radius = cylinder.radius - wall
		inner_cylinder.height = cylinder.height - wall * 2.0
		inner_cylinder.cone = cylinder.cone
		inner_shape = inner_cylinder
	else:
		var reason := "Brush type %s does not support hollowing" % BrushType.keys()[brush_type]
		push_error("[AdvancedBrushTool] %s" % reason)
		brush_operation_failed.emit(str(brush_type), reason)
		return null

	var combiner := CSGCombiner3D.new()
	combiner.name = "HollowBrush"
	combiner.use_collision = true
	csg_shape.operation = CSGShape3D.OPERATION_UNION
	inner_shape.operation = CSGShape3D.OPERATION_SUBTRACTION
	combiner.add_child(csg_shape)
	combiner.add_child(inner_shape)
	return combiner


## Create pyramid shape using CSG
func _create_pyramid_shape(size: Vector3) -> CSGPolygon3D:
	var pyramid = CSGPolygon3D.new()
	pyramid.polygon = PackedVector2Array(
		[
			Vector2(-size.x * 0.5, 0),
			Vector2(size.x * 0.5, 0),
			Vector2(size.x * 0.5, size.y),
			Vector2(-size.x * 0.5, size.y)
		]
	)
	pyramid.depth = size.z
	pyramid.mode = CSGPolygon3D.MODE_DEPTH
	pyramid.use_collision = true
	return pyramid


## Create wedge shape using CSG
func _create_wedge_shape(size: Vector3) -> CSGPolygon3D:
	var wedge = CSGPolygon3D.new()
	wedge.polygon = PackedVector2Array(
		[Vector2(-size.x * 0.5, 0), Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, size.y)]
	)
	wedge.depth = size.z
	wedge.mode = CSGPolygon3D.MODE_DEPTH
	wedge.use_collision = true
	return wedge


func _create_staircase_mesh(size: Vector3) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var steps: int = maxi(2, ceili(size.y))
	var step_height := size.y / steps
	for step in range(steps):
		var height := step_height * (step + 1)
		var center_z := -size.z * 0.5 + size.z * (step + 0.5) / steps
		_append_box(
			vertices,
			indices,
			Vector3(-size.x * 0.5, 0, center_z - size.z / (2.0 * steps)),
			Vector3(size.x * 0.5, height, center_z + size.z / (2.0 * steps))
		)
	return _build_mesh(vertices, indices)


func _create_arch_mesh(size: Vector3) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var segments: int = 16
	var outer_radius := minf(size.x, size.y) * 0.5
	var inner_radius := maxf(outer_radius - minf(size.x, size.y) * 0.22, outer_radius * 0.35)
	var depth := size.z * 0.5
	for i in range(segments):
		var a0 := PI * float(i) / segments
		var a1 := PI * float(i + 1) / segments
		var points := [
			Vector3(cos(a0) * outer_radius, sin(a0) * outer_radius, -depth),
			Vector3(cos(a1) * outer_radius, sin(a1) * outer_radius, -depth),
			Vector3(cos(a1) * inner_radius, sin(a1) * inner_radius, -depth),
			Vector3(cos(a0) * inner_radius, sin(a0) * inner_radius, -depth),
		]
		var back_points := points.duplicate()
		for point in back_points:
			point.z = depth
		_append_quad(vertices, indices, points[0], points[1], points[2], points[3])
		_append_quad(
			vertices, indices, back_points[3], back_points[2], back_points[1], back_points[0]
		)
		_append_quad(vertices, indices, points[0], back_points[0], back_points[1], points[1])
		_append_quad(vertices, indices, points[3], points[2], back_points[2], back_points[3])
		_append_quad(vertices, indices, points[1], back_points[1], back_points[2], points[2])
		_append_quad(vertices, indices, points[0], points[3], back_points[3], back_points[0])
	# Pillars close the arch at the ground.
	_append_box(
		vertices,
		indices,
		Vector3(-outer_radius, -size.y * 0.5, -depth),
		Vector3(-inner_radius, 0, depth)
	)
	_append_box(
		vertices,
		indices,
		Vector3(inner_radius, -size.y * 0.5, -depth),
		Vector3(outer_radius, 0, depth)
	)
	return _build_mesh(vertices, indices)


func _create_torus_mesh(size: Vector3) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var major_radius := maxf(size.x, size.z) * 0.25
	var tube_radius := minf(size.x, size.y) * 0.18
	var major_segments := 24
	var tube_segments := 10
	for i in range(major_segments):
		for j in range(tube_segments):
			var u0 := TAU * float(i) / major_segments
			var u1 := TAU * float(i + 1) / major_segments
			var v0 := TAU * float(j) / tube_segments
			var v1 := TAU * float(j + 1) / tube_segments
			var points := [
				_torus_point(major_radius, tube_radius, u0, v0),
				_torus_point(major_radius, tube_radius, u1, v0),
				_torus_point(major_radius, tube_radius, u1, v1),
				_torus_point(major_radius, tube_radius, u0, v1),
			]
			_append_quad(vertices, indices, points[0], points[1], points[2], points[3])
	return _build_mesh(vertices, indices)


func _create_capsule_mesh(size: Vector3) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var rings := 12
	var sides := 16
	var radius := minf(size.x, size.z) * 0.5
	var half_cylinder := maxf(0.0, size.y * 0.5 - radius)
	for ring in range(rings + 1):
		var t := float(ring) / rings
		var latitude := -PI * 0.5 + PI * t
		var y := sin(latitude) * radius
		if y > 0:
			y += half_cylinder
		elif y < 0:
			y -= half_cylinder
		var ring_radius := cos(latitude) * radius
		for side in range(sides):
			var angle := TAU * float(side) / sides
			vertices.append(Vector3(cos(angle) * ring_radius, y, sin(angle) * ring_radius))
	for ring in range(rings):
		for side in range(sides):
			var next_side := (side + 1) % sides
			var a := ring * sides + side
			var b := ring * sides + next_side
			var c := (ring + 1) * sides + next_side
			var d := (ring + 1) * sides + side
			indices.append_array([a, b, c, a, c, d])
	return _build_mesh(vertices, indices)


func _torus_point(major_radius: float, tube_radius: float, u: float, v: float) -> Vector3:
	var ring := major_radius + tube_radius * cos(v)
	return Vector3(ring * cos(u), tube_radius * sin(v), ring * sin(u))


func _append_quad(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3
) -> void:
	var base := vertices.size()
	vertices.append_array([a, b, c, d])
	indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


func _append_box(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	min_corner: Vector3,
	max_corner: Vector3
) -> void:
	var corners := [
		Vector3(min_corner.x, min_corner.y, min_corner.z),
		Vector3(max_corner.x, min_corner.y, min_corner.z),
		Vector3(max_corner.x, max_corner.y, min_corner.z),
		Vector3(min_corner.x, max_corner.y, min_corner.z),
		Vector3(min_corner.x, min_corner.y, max_corner.z),
		Vector3(max_corner.x, min_corner.y, max_corner.z),
		Vector3(max_corner.x, max_corner.y, max_corner.z),
		Vector3(min_corner.x, max_corner.y, max_corner.z),
	]
	_append_quad(vertices, indices, corners[0], corners[1], corners[2], corners[3])
	_append_quad(vertices, indices, corners[5], corners[4], corners[7], corners[6])
	_append_quad(vertices, indices, corners[4], corners[0], corners[3], corners[7])
	_append_quad(vertices, indices, corners[1], corners[5], corners[6], corners[2])
	_append_quad(vertices, indices, corners[3], corners[2], corners[6], corners[7])
	_append_quad(vertices, indices, corners[4], corners[5], corners[1], corners[0])


func _build_mesh(vertices: PackedVector3Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Snap position to grid
func _snap_to_grid(position: Vector3) -> Vector3:
	if grid_size <= 0:
		return position

	return Vector3(
		round(position.x / grid_size) * grid_size,
		round(position.y / grid_size) * grid_size,
		round(position.z / grid_size) * grid_size
	)


## Get mouse world position
func _get_mouse_world_position() -> Vector3:
	# In editor context, this would use the 3D editor camera
	# For runtime, we might need to raycast from the camera
	if Engine.is_editor_hint():
		# Editor context - would use editor tools
		return Vector3.ZERO

	# Runtime context - use camera raycast
	var editor_camera: Camera3D = _find_active_camera()
	if not editor_camera:
		return Vector3.ZERO

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = editor_camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = editor_camera.project_ray_normal(mouse_pos)

	# Raycast to find intersection with ground or existing geometry
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 1000.0)
	var result: Dictionary = space_state.intersect_ray(query)

	if result.size() > 0:
		return result.position

	# Default to ray at certain distance if no intersection
	return ray_origin + ray_dir * 10.0


## Find active camera in scene
func _find_active_camera() -> Camera3D:
	var cameras = get_tree().get_nodes_in_group("editor_camera")
	if cameras.size() > 0:
		return cameras[0] as Camera3D

	# Look for current camera
	var current_scene = get_tree().current_scene
	if current_scene:
		var cam = current_scene.get_node_or_null("Camera3D")
		if cam and cam is Camera3D:
			return cam as Camera3D

	return null


## Get level parent for placing objects
func _get_level_parent() -> Node3D:
	if not is_inside_tree():
		return self
	var current_scene := get_tree().current_scene
	if current_scene:
		var level_root := current_scene.get_node_or_null("LevelRoot")
		if level_root is Node3D:
			return level_root
		return current_scene as Node3D
	return self


## Load default brush presets
func _load_default_presets() -> void:
	var cube_preset := BrushPreset.new()
	cube_preset.name = "Basic Cube"
	cube_preset.brush_type = BrushType.CUBE
	cube_preset.size = Vector3.ONE
	cube_preset.operation_mode = OperationMode.ADD
	_brush_presets.append(cube_preset)

	var sphere_preset := BrushPreset.new()
	sphere_preset.name = "Basic Sphere"
	sphere_preset.brush_type = BrushType.SPHERE
	sphere_preset.size = Vector3.ONE
	sphere_preset.operation_mode = OperationMode.ADD
	_brush_presets.append(sphere_preset)

	var wall_preset := BrushPreset.new()
	wall_preset.name = "Wall Segment"
	wall_preset.brush_type = BrushType.CUBE
	wall_preset.size = Vector3(2, 2, 0.5)
	wall_preset.operation_mode = OperationMode.ADD
	_brush_presets.append(wall_preset)

	var floor_preset := BrushPreset.new()
	floor_preset.name = "Floor Tile"
	floor_preset.brush_type = BrushType.CUBE
	floor_preset.size = Vector3(2, 0.2, 2)
	floor_preset.operation_mode = OperationMode.ADD
	_brush_presets.append(floor_preset)


## Apply a preset
func apply_preset(preset_index: int) -> void:
	if preset_index < 0 or preset_index >= _brush_presets.size():
		return
	var preset: BrushPreset = _brush_presets[preset_index]
	brush_type = preset.brush_type
	brush_size = preset.size
	brush_material = preset.material
	brush_operation_mode = preset.operation_mode
	hollow_brush = preset.hollow
	hollow_thickness = preset.hollow_thickness
	snap_to_grid = preset.snap_to_grid
	brush_density = preset.density


## Batch place multiple objects
func batch_place(objects_data: Array[Dictionary]) -> bool:
	if objects_data.size() > max_batch_size:
		push_warning("Batch size exceeds maximum allowed. Splitting into chunks.")
		return _batch_place_chunked(objects_data)

	brush_operation_started.emit("batch_place")
	var success_count := 0
	for data: Dictionary in objects_data:
		var old_type := brush_type
		var old_size := brush_size
		var old_material := brush_material
		brush_type = data.get("type", BrushType.CUBE)
		brush_size = data.get("size", Vector3.ONE)
		brush_material = data.get("material", null)
		if _place_brush_object(data.get("position", Vector3.ZERO)):
			success_count += 1
		brush_type = old_type
		brush_size = old_size
		brush_material = old_material
	var success := success_count == objects_data.size()
	brush_operation_completed.emit("batch_place", success)
	return success


## Batch place with chunking for performance
func _batch_place_chunked(objects_data: Array[Dictionary]) -> bool:
	var total_count: int = objects_data.size()
	var chunks: Array[Array] = []
	var chunk_size: int = max_batch_size

	for i in range(0, total_count, chunk_size):
		var end: int = min(i + chunk_size, total_count)
		var chunk: Array = objects_data.slice(i, end)
		chunks.append(chunk)

	var all_success: bool = true
	for chunk: Array in chunks:
		if not _batch_place_single_chunk(chunk):
			all_success = false

	return all_success


func _batch_place_single_chunk(chunk: Array[Dictionary]) -> bool:
	brush_operation_started.emit("batch_place_chunk")

	var success_count: int = 0
	for data: Dictionary in chunk:
		var pos: Vector3 = data.get("position", Vector3.ZERO)
		if _place_brush_object(pos):
			success_count += 1

	var success: bool = success_count == chunk.size()
	brush_operation_completed.emit("batch_place_chunk", success)
	return success


## Fill area with brush objects
func _fill_area_with_brush(start_pos: Vector3) -> bool:
	var spacing := maxf(grid_size, 0.25)
	var half_size := brush_size * 0.5
	var placed := 0
	var max_count := mini(max_batch_size, 1000)
	for x in range(ceili(-half_size.x / spacing), ceili(half_size.x / spacing) + 1):
		for y in range(ceili(-half_size.y / spacing), ceili(half_size.y / spacing) + 1):
			for z in range(ceili(-half_size.z / spacing), ceili(half_size.z / spacing) + 1):
				if placed >= max_count:
					break
				var hash_value := (
					float(absi(x * 73856093 + y * 19349663 + z * 83492791) % 1000) / 1000.0
				)
				if hash_value > clampf(brush_density, 0.0, 1.0):
					continue
				if _place_brush_object(start_pos + Vector3(x, y, z) * spacing):
					placed += 1
	brush_applied.emit("FILL", placed)
	return placed > 0


## Clear area around position
func _clear_area(center_pos: Vector3) -> bool:
	if not is_inside_tree() or not get_world_3d():
		brush_applied.emit("CLEAR", 0)
		return false
	var radius := maxf(brush_size.x, maxf(brush_size.y, brush_size.z))
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center_pos)
	var removed_count := 0
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var obj: Node3D = result.get("collider", null)
		if obj and obj.has_meta("editor_placed"):
			obj.queue_free()
			removed_count += 1
	brush_applied.emit("CLEAR", removed_count)
	return removed_count > 0


## Remove brush object at position
func _remove_brush_object(position: Vector3) -> bool:
	if not is_inside_tree() or not get_world_3d():
		return false
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, position)
	var results := get_world_3d().direct_space_state.intersect_shape(query, 1)
	if results.size() > 0:
		var obj: Node3D = results[0].get("collider", null)
		if obj and obj.has_meta("editor_placed"):
			obj.queue_free()
			brush_applied.emit("REMOVE", 1)
			return true
	return false


## Get available presets
func get_presets() -> Array[BrushPreset]:
	return _brush_presets.duplicate()


## Save current settings as preset
func save_current_as_preset(name: String) -> void:
	var preset = BrushPreset.new()
	preset.name = name
	preset.brush_type = brush_type
	preset.size = brush_size
	preset.material = brush_material
	preset.operation_mode = brush_operation_mode
	preset.hollow = hollow_brush
	preset.hollow_thickness = hollow_thickness
	preset.snap_to_grid = snap_to_grid
	preset.density = brush_density

	_brush_presets.append(preset)


## Activate the brush tool
func activate() -> void:
	_is_active = true
	if _preview_mesh:
		_preview_mesh.visible = true


## Deactivate the brush tool
func deactivate() -> void:
	_is_active = false
	if _preview_mesh:
		_preview_mesh.visible = false


## Cancel current brush operation
func _cancel_brush() -> void:
	# Currently just hides preview
	if _preview_mesh:
		_preview_mesh.visible = false


## Get current brush statistics
func get_statistics() -> Dictionary:
	return {
		"active": _is_active,
		"type": brush_type,
		"size": brush_size,
		"operation_mode": brush_operation_mode,
		"total_presets": _brush_presets.size()
	}
