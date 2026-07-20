@tool
class_name PathBrush
extends RefCounted

signal path_placed(nodes: Array[Node3D])

enum PathProfile { FLAT, WALL, PIPE, RAIL, CUSTOM }  ## Flat surface (road, floor)  ## Vertical wall  ## Circular pipe  ## Rail/beam profile  ## Custom polygon

var grid_system: Node = null
var editor_state: Node = null
var path_points: Array[Vector3] = []
var is_editing: bool = false
var path_width: float = 1.0
var path_height: float = 0.5
var path_segments: int = 8  ## Segments per curve
var path_closed: bool = false
var profile: PathProfile = PathProfile.FLAT
var custom_polygon: PackedVector2Array = PackedVector2Array()


func setup(grid: Node, state: Node) -> void:
	grid_system = grid
	editor_state = state


## Start new path


func start_path(world_position: Vector3) -> void:
	path_points.clear()
	path_points.append(_snap_position(world_position))
	is_editing = true


## Add point to path


func add_point(world_position: Vector3) -> void:
	if is_editing:
		path_points.append(_snap_position(world_position))


## Update last point (for preview while moving mouse)


func update_preview_point(world_position: Vector3) -> void:
	if is_editing and path_points.size() > 1:
		path_points[-1] = _snap_position(world_position)


## Remove last point


func undo_last_point() -> void:
	if is_editing and path_points.size() > 1:
		path_points.pop_back()


## Finish and create path


func finish_path(level_root: Node3D) -> Array[Node3D]:
	is_editing = false

	if path_points.size() < 2:
		path_points.clear()
		return []

	var nodes: Array[Node3D] = []

	# Choose creation method based on profile
	match profile:
		PathProfile.FLAT:
			nodes = _create_flat_path(level_root)
		PathProfile.WALL:
			nodes = _create_wall_path(level_root)
		PathProfile.PIPE:
			nodes = _create_pipe_path(level_root)
		PathProfile.RAIL:
			nodes = _create_rail_path(level_root)
		PathProfile.CUSTOM:
			nodes = _create_custom_path(level_root)

	if not nodes.is_empty():
		path_placed.emit(nodes)

	path_points.clear()
	return nodes


## Cancel path creation


func cancel_path() -> void:
	is_editing = false
	path_points.clear()


## Create flat path (road/floor)


func _create_flat_path(level_root: Node3D) -> Array[Node3D]:
	var path_node := Path3D.new()
	path_node.name = "FlatPath"
	path_node.curve = _create_curve()
	level_root.add_child(path_node)

	# Create CSGPolygon following path
	var csg := CSGPolygon3D.new()
	csg.name = "PathMesh"
	csg.mode = CSGPolygon3D.MODE_PATH
	csg.path_node = path_node.get_path()

	# Flat profile (rectangle)
	csg.polygon = PackedVector2Array(
		[
			Vector2(-path_width * 0.5, 0),
			Vector2(path_width * 0.5, 0),
			Vector2(path_width * 0.5, path_height),
			Vector2(-path_width * 0.5, path_height)
		]
	)

	csg.path_interval = 1.0 / path_segments
	csg.path_simplify_angle = 5.0
	csg.use_collision = true
	csg.set_meta("level_editor_placed", true)
	csg.set_meta("path_brush", true)

	path_node.add_child(csg)

	return [path_node]


## Create wall path


func _create_wall_path(level_root: Node3D) -> Array[Node3D]:
	var path_node := Path3D.new()
	path_node.name = "WallPath"
	path_node.curve = _create_curve()
	level_root.add_child(path_node)

	var csg := CSGPolygon3D.new()
	csg.name = "PathMesh"
	csg.mode = CSGPolygon3D.MODE_PATH
	csg.path_node = path_node.get_path()

	# Wall profile (tall rectangle)
	csg.polygon = PackedVector2Array(
		[
			Vector2(-path_width * 0.5, 0),
			Vector2(path_width * 0.5, 0),
			Vector2(path_width * 0.5, path_height * 3),
			Vector2(-path_width * 0.5, path_height * 3)
		]
	)

	csg.path_interval = 1.0 / path_segments
	csg.use_collision = true
	csg.set_meta("level_editor_placed", true)
	csg.set_meta("path_brush", true)

	path_node.add_child(csg)

	return [path_node]


## Create pipe path


func _create_pipe_path(level_root: Node3D) -> Array[Node3D]:
	var path_node := Path3D.new()
	path_node.name = "PipePath"
	path_node.curve = _create_curve()
	level_root.add_child(path_node)

	var csg := CSGPolygon3D.new()
	csg.name = "PathMesh"
	csg.mode = CSGPolygon3D.MODE_PATH
	csg.path_node = path_node.get_path()

	# Circular profile (approximated with polygon)
	var circle: PackedVector2Array = PackedVector2Array()
	var radius: float = path_width * 0.5
	var circle_segments: int = 12
	for i: int in range(circle_segments):
		var angle: float = TAU * i / circle_segments
		circle.append(Vector2(cos(angle) * radius, sin(angle) * radius + radius))

	csg.polygon = circle
	csg.path_interval = 1.0 / path_segments
	csg.use_collision = true
	csg.set_meta("level_editor_placed", true)
	csg.set_meta("path_brush", true)

	path_node.add_child(csg)

	return [path_node]


## Create rail path


func _create_rail_path(level_root: Node3D) -> Array[Node3D]:
	var path_node := Path3D.new()
	path_node.name = "RailPath"
	path_node.curve = _create_curve()
	level_root.add_child(path_node)

	var csg := CSGPolygon3D.new()
	csg.name = "PathMesh"
	csg.mode = CSGPolygon3D.MODE_PATH
	csg.path_node = path_node.get_path()

	# I-beam profile
	var w: float = path_width * 0.5
	var h: float = path_height
	var flange: float = 0.15
	csg.polygon = PackedVector2Array(
		[
			Vector2(-w, 0),
			Vector2(w, 0),
			Vector2(w, flange),
			Vector2(flange, flange),
			Vector2(flange, h - flange),
			Vector2(w, h - flange),
			Vector2(w, h),
			Vector2(-w, h),
			Vector2(-w, h - flange),
			Vector2(-flange, h - flange),
			Vector2(-flange, flange),
			Vector2(-w, flange)
		]
	)

	csg.path_interval = 1.0 / path_segments
	csg.use_collision = true
	csg.set_meta("level_editor_placed", true)
	csg.set_meta("path_brush", true)

	path_node.add_child(csg)

	return [path_node]


## Create custom profile path


func _create_custom_path(level_root: Node3D) -> Array[Node3D]:
	if custom_polygon.is_empty():
		return _create_flat_path(level_root)

	var path_node := Path3D.new()
	path_node.name = "CustomPath"
	path_node.curve = _create_curve()
	level_root.add_child(path_node)

	var csg := CSGPolygon3D.new()
	csg.name = "PathMesh"
	csg.mode = CSGPolygon3D.MODE_PATH
	csg.path_node = path_node.get_path()
	csg.polygon = custom_polygon
	csg.path_interval = 1.0 / path_segments
	csg.use_collision = true
	csg.set_meta("level_editor_placed", true)
	csg.set_meta("path_brush", true)

	path_node.add_child(csg)

	return [path_node]


## Create Curve3D from path points


func _create_curve() -> Curve3D:
	var curve := Curve3D.new()

	for i: int in range(path_points.size()):
		var point: Vector3 = path_points[i]

		# Calculate tangent handles for smooth curve
		var in_handle := Vector3.ZERO
		var out_handle := Vector3.ZERO

		if path_points.size() >= 2:
			var prev_point: Vector3
			var next_point: Vector3

			if i == 0:
				prev_point = point
				next_point = path_points[1]
			elif i == path_points.size() - 1:
				prev_point = path_points[i - 1]
				next_point = point
			else:
				prev_point = path_points[i - 1]
				next_point = path_points[i + 1]

			# Smooth tangent
			var tangent: Vector3 = (next_point - prev_point).normalized()
			var handle_length: float = point.distance_to(next_point) * 0.3

			in_handle = -tangent * handle_length
			out_handle = tangent * handle_length

		curve.add_point(point, in_handle, out_handle)

	return curve


func _snap_position(position: Vector3) -> Vector3:
	if grid_system:
		return grid_system.snap_to_grid(position)
	return position


## Get current path points for preview


func get_path_points() -> Array[Vector3]:
	return path_points


## Set path width


func set_path_width(width: float) -> void:
	path_width = maxf(0.1, width)


## Set path height


func set_path_height(height: float) -> void:
	path_height = maxf(0.1, height)


## Set curve segments per section


func set_path_segments(segments: int) -> void:
	path_segments = clampi(segments, 2, 32)


## Set custom extrusion polygon


func set_custom_polygon(polygon: PackedVector2Array) -> void:
	custom_polygon = polygon
	profile = PathProfile.CUSTOM


## Close path (loop back to start)


func set_path_closed(closed: bool) -> void:
	path_closed = closed
