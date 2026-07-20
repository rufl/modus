@tool
extends EditorNode3DGizmoPlugin

var editor_state: Node = null


func _init() -> void:
	create_material("preview", Color(0.2, 0.8, 1.0, 0.5))
	create_material("preview_invalid", Color(1.0, 0.2, 0.2, 0.5))


func _get_gizmo_name() -> String:
	return "BrushPreview"


func _has_gizmo(node: Node3D) -> bool:
	# Show on LevelRoot nodes
	if node.get_script():
		return node.get_script().resource_path.contains("level_root.gd")
	return false


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	if not editor_state or not editor_state.is_editing():
		return

	var node := gizmo.get_node_3d()
	if not node:
		return

	# Only show for block brush tool
	if editor_state.current_tool != editor_state.ToolType.BLOCK_BRUSH:
		return

	# Draw block preview at hover position
	_draw_block_preview(gizmo, node)


func _draw_block_preview(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var lines := PackedVector3Array()
	var hover_pos: Vector3 = editor_state.hover_position - node.global_position
	var size: Vector3 = Vector3(editor_state.brush_size) * editor_state.get_grid_size()
	var half_size: Vector3 = size * 0.5

	# Bottom face
	lines.append(hover_pos + Vector3(-half_size.x, 0, -half_size.z))
	lines.append(hover_pos + Vector3(half_size.x, 0, -half_size.z))

	lines.append(hover_pos + Vector3(half_size.x, 0, -half_size.z))
	lines.append(hover_pos + Vector3(half_size.x, 0, half_size.z))

	lines.append(hover_pos + Vector3(half_size.x, 0, half_size.z))
	lines.append(hover_pos + Vector3(-half_size.x, 0, half_size.z))

	lines.append(hover_pos + Vector3(-half_size.x, 0, half_size.z))
	lines.append(hover_pos + Vector3(-half_size.x, 0, -half_size.z))

	# Top face
	lines.append(hover_pos + Vector3(-half_size.x, size.y, -half_size.z))
	lines.append(hover_pos + Vector3(half_size.x, size.y, -half_size.z))

	lines.append(hover_pos + Vector3(half_size.x, size.y, -half_size.z))
	lines.append(hover_pos + Vector3(half_size.x, size.y, half_size.z))

	lines.append(hover_pos + Vector3(half_size.x, size.y, half_size.z))
	lines.append(hover_pos + Vector3(-half_size.x, size.y, half_size.z))

	lines.append(hover_pos + Vector3(-half_size.x, size.y, half_size.z))
	lines.append(hover_pos + Vector3(-half_size.x, size.y, -half_size.z))

	# Vertical edges
	lines.append(hover_pos + Vector3(-half_size.x, 0, -half_size.z))
	lines.append(hover_pos + Vector3(-half_size.x, size.y, -half_size.z))

	lines.append(hover_pos + Vector3(half_size.x, 0, -half_size.z))
	lines.append(hover_pos + Vector3(half_size.x, size.y, -half_size.z))

	lines.append(hover_pos + Vector3(half_size.x, 0, half_size.z))
	lines.append(hover_pos + Vector3(half_size.x, size.y, half_size.z))

	lines.append(hover_pos + Vector3(-half_size.x, 0, half_size.z))
	lines.append(hover_pos + Vector3(-half_size.x, size.y, half_size.z))

	var material := get_material("preview", gizmo)
	gizmo.add_lines(lines, material, false)


## Set editor state reference


func set_editor_state(state: Node) -> void:
	editor_state = state
