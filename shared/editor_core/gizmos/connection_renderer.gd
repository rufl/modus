@tool
class_name ConnectionRenderer
extends Node3D

signal connection_clicked(source: Node3D, target: Node3D, channel: String)

var line_segments: int = 16
var line_thickness: float = 0.03
var arrow_size: float = 0.15
var curve_height: float = 1.0
var default_color: Color = Color(0.3, 0.7, 0.3, 0.8)
var highlight_color: Color = Color(0.9, 0.9, 0.3, 1.0)
var selected_color: Color = Color(0.3, 0.5, 0.9, 1.0)
var channel_system: Node = null
var level_root: Node3D = null

var _line_meshes: Dictionary = {}  # connection_id -> MeshInstance3D
var _highlighted_connection: String = ""
var _selected_connections: Array[String] = []


func _ready() -> void:
	name = "ConnectionRenderer"


## Setup with references


func setup(channel_sys: Node, root: Node3D) -> void:
	channel_system = channel_sys
	level_root = root

	if channel_system:
		if channel_system.has_signal("connection_created"):
			channel_system.connection_created.connect(_on_connection_created)
		if channel_system.has_signal("connection_removed"):
			channel_system.connection_removed.connect(_on_connection_removed)


## Refresh all connection visuals


func refresh_all() -> void:
	_clear_all_lines()

	if not channel_system:
		return

	# Get all connections from channel system
	if channel_system.has_method("get_all_connections"):
		var connections: Array = channel_system.get_all_connections()
		for conn: Dictionary in connections:
			_create_connection_line(
				conn.get("source"),
				conn.get("target"),
				conn.get("channel", ""),
				conn.get("color", default_color)
			)


## Update positions (call when actors move)


func update_positions() -> void:
	for conn_id: String in _line_meshes:
		var mesh: MeshInstance3D = _line_meshes[conn_id]
		var source: Node3D = mesh.get_meta("source", null)
		var target: Node3D = mesh.get_meta("target", null)

		if source and target and is_instance_valid(source) and is_instance_valid(target):
			_update_line_mesh(mesh, source.global_position, target.global_position)


## Highlight a connection


func highlight_connection(source: Node3D, target: Node3D) -> void:
	var conn_id: String = _get_connection_id(source, target)

	# Unhighlight previous
	if not _highlighted_connection.is_empty():
		_set_line_color(_highlighted_connection, default_color)

	_highlighted_connection = conn_id

	if _line_meshes.has(conn_id):
		_set_line_color(conn_id, highlight_color)


## Clear highlight


func clear_highlight() -> void:
	if not _highlighted_connection.is_empty():
		if _highlighted_connection not in _selected_connections:
			_set_line_color(_highlighted_connection, default_color)
		_highlighted_connection = ""


## Select a connection


func select_connection(source: Node3D, target: Node3D) -> void:
	var conn_id: String = _get_connection_id(source, target)

	if conn_id not in _selected_connections:
		_selected_connections.append(conn_id)

	if _line_meshes.has(conn_id):
		_set_line_color(conn_id, selected_color)


## Deselect a connection


func deselect_connection(source: Node3D, target: Node3D) -> void:
	var conn_id: String = _get_connection_id(source, target)
	_selected_connections.erase(conn_id)

	if _line_meshes.has(conn_id):
		_set_line_color(conn_id, default_color)


## Clear all selections


func clear_selection() -> void:
	for conn_id: String in _selected_connections:
		if _line_meshes.has(conn_id):
			_set_line_color(conn_id, default_color)
	_selected_connections.clear()


func _create_connection_line(
	source: Node3D, target: Node3D, channel: String, color: Color = Color.WHITE
) -> void:
	if not source or not target:
		return

	var conn_id: String = _get_connection_id(source, target)

	# Create mesh instance
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Connection_" + conn_id.substr(0, 8)
	mesh_instance.set_meta("source", source)
	mesh_instance.set_meta("target", target)
	mesh_instance.set_meta("channel", channel)

	# Create material
	var material := StandardMaterial3D.new()
	material.albedo_color = color if color != Color.WHITE else default_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material

	add_child(mesh_instance)
	_line_meshes[conn_id] = mesh_instance

	# Generate line mesh
	_update_line_mesh(mesh_instance, source.global_position, target.global_position)


func _update_line_mesh(mesh_instance: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var im := ImmediateMesh.new()

	# Create bezier curve points
	var points: PackedVector3Array = _calculate_bezier_curve(start, end)

	# Create tube along path
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var up := Vector3.UP
	var prev_right := Vector3.RIGHT

	for i: int in range(points.size()):
		var point: Vector3 = points[i]
		var forward: Vector3

		if i < points.size() - 1:
			forward = (points[i + 1] - point).normalized()
		else:
			forward = (point - points[i - 1]).normalized()

		var right: Vector3 = forward.cross(up).normalized()
		if right.length_squared() < 0.01:
			right = prev_right
		prev_right = right

		# Add vertices for tube cross-section
		var offset1: Vector3 = right * line_thickness
		var offset2: Vector3 = up * line_thickness

		im.surface_add_vertex(point + offset1)
		im.surface_add_vertex(point - offset1)

	im.surface_end()

	# Add arrow at end
	_add_arrow_to_mesh(im, points[-2], points[-1])

	mesh_instance.mesh = im


func _calculate_bezier_curve(start: Vector3, end: Vector3) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()

	# Control points for curved line
	var mid: Vector3 = (start + end) * 0.5
	mid.y += curve_height

	var control1: Vector3 = start.lerp(mid, 0.5)
	var control2: Vector3 = mid.lerp(end, 0.5)

	for i: int in range(line_segments + 1):
		var t: float = float(i) / line_segments

		# Cubic bezier
		var p: Vector3 = _bezier_point(start, control1, control2, end, t)
		points.append(p)

	return points


func _bezier_point(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u: float = 1.0 - t
	var tt: float = t * t
	var uu: float = u * u
	var uuu: float = uu * u
	var ttt: float = tt * t

	var p: Vector3 = p0 * uuu
	p += p1 * 3 * uu * t
	p += p2 * 3 * u * tt
	p += p3 * ttt

	return p


func _add_arrow_to_mesh(im: ImmediateMesh, from: Vector3, to: Vector3) -> void:
	var direction: Vector3 = (to - from).normalized()
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var up: Vector3 = right.cross(direction).normalized()

	var arrow_base: Vector3 = to - direction * arrow_size

	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	# Arrow head (pyramid)
	var tip: Vector3 = to
	var base1: Vector3 = arrow_base + right * arrow_size * 0.5
	var base2: Vector3 = arrow_base - right * arrow_size * 0.5
	var base3: Vector3 = arrow_base + up * arrow_size * 0.5
	var base4: Vector3 = arrow_base - up * arrow_size * 0.5

	# Side faces
	im.surface_add_vertex(tip)
	im.surface_add_vertex(base1)
	im.surface_add_vertex(base3)

	im.surface_add_vertex(tip)
	im.surface_add_vertex(base3)
	im.surface_add_vertex(base2)

	im.surface_add_vertex(tip)
	im.surface_add_vertex(base2)
	im.surface_add_vertex(base4)

	im.surface_add_vertex(tip)
	im.surface_add_vertex(base4)
	im.surface_add_vertex(base1)

	im.surface_end()


func _set_line_color(conn_id: String, color: Color) -> void:
	if not _line_meshes.has(conn_id):
		return

	var mesh: MeshInstance3D = _line_meshes[conn_id]
	if mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = mesh.material_override
		mat.albedo_color = color


func _get_connection_id(source: Node3D, target: Node3D) -> String:
	if not source or not target:
		return ""
	return str(source.get_instance_id()) + "_" + str(target.get_instance_id())


func _clear_all_lines() -> void:
	for conn_id: String in _line_meshes:
		var mesh: MeshInstance3D = _line_meshes[conn_id]
		if is_instance_valid(mesh):
			mesh.queue_free()
	_line_meshes.clear()


func _on_connection_created(source: Node3D, target: Node3D, channel: String) -> void:
	var color: Color = default_color
	if channel_system and channel_system.has_method("get_channel_color"):
		color = channel_system.get_channel_color(channel)
	_create_connection_line(source, target, channel, color)


func _on_connection_removed(source: Node3D, target: Node3D, _channel: String) -> void:
	var conn_id: String = _get_connection_id(source, target)
	if _line_meshes.has(conn_id):
		var mesh: MeshInstance3D = _line_meshes[conn_id]
		if is_instance_valid(mesh):
			mesh.queue_free()
		_line_meshes.erase(conn_id)


## Get connection at screen position (for clicking)


func get_connection_at_position(screen_pos: Vector2, camera: Camera3D) -> Dictionary:
	# Ray cast to find connections
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)

	var closest: Dictionary = {}
	var closest_dist: float = 1.0

	for conn_id: String in _line_meshes:
		var mesh: MeshInstance3D = _line_meshes[conn_id]
		var source: Node3D = mesh.get_meta("source", null)
		var target: Node3D = mesh.get_meta("target", null)

		if not source or not target:
			continue

		# Check distance from ray to line segment
		var dist: float = _ray_to_line_distance(
			from, direction, source.global_position, target.global_position
		)

		if dist < closest_dist:
			closest_dist = dist
			closest = {
				"source": source,
				"target": target,
				"channel": mesh.get_meta("channel", ""),
				"distance": dist
			}

	return closest


func _ray_to_line_distance(
	ray_origin: Vector3, ray_dir: Vector3, line_start: Vector3, line_end: Vector3
) -> float:
	var u: Vector3 = ray_dir
	var v: Vector3 = line_end - line_start
	var w: Vector3 = ray_origin - line_start
	var a: float = u.dot(u)
	var b: float = u.dot(v)
	var c: float = v.dot(v)
	var d: float = u.dot(w)
	var e: float = v.dot(w)
	var denom: float = a * c - b * b

	if absf(denom) < 0.0001:
		return w.length()

	var s: float = (b * e - c * d) / denom
	var t: float = (a * e - b * d) / denom
	t = clampf(t, 0.0, 1.0)

	var closest_on_ray: Vector3 = ray_origin + u * s
	var closest_on_line: Vector3 = line_start + v * t

	return closest_on_ray.distance_to(closest_on_line)
