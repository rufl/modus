@tool
extends EditorNode3DGizmoPlugin


func _init() -> void:
	# Channel colors
	create_material("channel_red", Color(1.0, 0.3, 0.3, 0.8))
	create_material("channel_blue", Color(0.3, 0.5, 1.0, 0.8))
	create_material("channel_green", Color(0.3, 0.8, 0.3, 0.8))
	create_material("channel_yellow", Color(1.0, 0.8, 0.2, 0.8))
	create_material("channel_purple", Color(0.7, 0.3, 1.0, 0.8))
	create_material("channel_default", Color(0.8, 0.8, 0.8, 0.6))


func _get_gizmo_name() -> String:
	return "ConnectionWire"


func _has_gizmo(node: Node3D) -> bool:
	# Show on nodes that have channel connections
	return _has_channel_data(node)


func _has_channel_data(node: Node3D) -> bool:
	# Check if node has channel metadata
	if node.has_meta("level_editor_channels"):
		return true
	# Check for our custom component
	if node.has_node("ChannelConnector"):
		return true
	return false


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var node := gizmo.get_node_3d()
	if not node:
		return

	# Get channel connections
	var connections := _get_connections(node)
	if connections.is_empty():
		return

	for connection in connections:
		_draw_connection(gizmo, node, connection)


func _get_connections(node: Node3D) -> Array:
	# Get from metadata
	if node.has_meta("level_editor_channels"):
		return node.get_meta("level_editor_channels")

	# Get from component
	var connector := node.get_node_or_null("ChannelConnector")
	if connector and connector.has_method("get_connections"):
		return connector.get_connections()

	return []


func _draw_connection(gizmo: EditorNode3DGizmo, source: Node3D, connection: Dictionary) -> void:
	if not connection.has("target_path"):
		return

	var target := source.get_node_or_null(connection.target_path) as Node3D
	if not target:
		return

	var lines := PackedVector3Array()
	var start := Vector3.ZERO  # Local to source
	var end := target.global_position - source.global_position

	# Draw curved wire
	_draw_wire(lines, start, end)

	# Get material based on channel color
	var channel_name: String = connection.get("channel", "default")
	var mat_name := "channel_" + _get_channel_color(channel_name)
	var material := get_material(mat_name, gizmo)
	if not material:
		material = get_material("channel_default", gizmo)

	gizmo.add_lines(lines, material, false)


func _draw_wire(lines: PackedVector3Array, start: Vector3, end: Vector3) -> void:
	# Draw a bezier curve wire
	var mid_y := maxf(start.y, end.y) + 1.0
	var control1 := Vector3(start.x, mid_y, start.z)
	var control2 := Vector3(end.x, mid_y, end.z)

	var segments := 20
	for i in range(segments):
		var t1 := float(i) / segments
		var t2 := float(i + 1) / segments

		var p1 := _bezier(start, control1, control2, end, t1)
		var p2 := _bezier(start, control1, control2, end, t2)

		lines.append(p1)
		lines.append(p2)

	# Draw arrow at end
	var arrow_size := 0.2
	var dir := (end - _bezier(start, control1, control2, end, 0.95)).normalized()
	var right := dir.cross(Vector3.UP).normalized() * arrow_size

	lines.append(end)
	lines.append(end - dir * arrow_size + right)
	lines.append(end)
	lines.append(end - dir * arrow_size - right)


func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var q0 := p0.lerp(p1, t)
	var q1 := p1.lerp(p2, t)
	var q2 := p2.lerp(p3, t)
	var r0 := q0.lerp(q1, t)
	var r1 := q1.lerp(q2, t)
	return r0.lerp(r1, t)


func _get_channel_color(channel_name: String) -> String:
	# Map common channel names to colors
	var name_lower := channel_name.to_lower()

	if name_lower.contains("red") or name_lower.contains("1"):
		return "red"
	if name_lower.contains("blue") or name_lower.contains("2"):
		return "blue"
	if name_lower.contains("green") or name_lower.contains("3"):
		return "green"
	if name_lower.contains("yellow") or name_lower.contains("4"):
		return "yellow"
	if name_lower.contains("purple") or name_lower.contains("5"):
		return "purple"

	return "default"
