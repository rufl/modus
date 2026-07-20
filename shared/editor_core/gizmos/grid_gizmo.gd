@tool
extends EditorNode3DGizmoPlugin

var grid_system: Node = null


func _init() -> void:
	create_material("grid_major", Color(0.5, 0.5, 0.5, 0.3))
	create_material("grid_minor", Color(0.4, 0.4, 0.4, 0.15))
	create_material("grid_axis_x", Color(1.0, 0.3, 0.3, 0.5))
	create_material("grid_axis_z", Color(0.3, 0.3, 1.0, 0.5))


func _get_gizmo_name() -> String:
	return "EditorGrid"


func _has_gizmo(node: Node3D) -> bool:
	# Show on LevelRoot nodes
	if node.get_script():
		return node.get_script().resource_path.contains("level_root.gd")
	return false


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	if not grid_system or not grid_system.show_grid:
		return

	var node := gizmo.get_node_3d()
	if not node:
		return

	_draw_grid(gizmo, node)


func _draw_grid(gizmo: EditorNode3DGizmo, node: Node3D) -> void:
	var cell_size: float = grid_system.cell_size if grid_system else 1.0
	var extent: int = grid_system.grid_extent if grid_system else 20
	var height: float = grid_system.get_current_height() if grid_system else 0.0

	var lines_major := PackedVector3Array()
	var lines_minor := PackedVector3Array()
	var lines_x := PackedVector3Array()
	var lines_z := PackedVector3Array()

	var half_extent: float = extent * cell_size

	# Draw grid lines
	for i in range(-extent, extent + 1):
		var pos := i * cell_size
		var is_major := i % 5 == 0

		# X-axis line (at z=0)
		if i == 0:
			lines_x.append(Vector3(-half_extent, height, 0))
			lines_x.append(Vector3(half_extent, height, 0))
		elif is_major:
			lines_major.append(Vector3(-half_extent, height, pos))
			lines_major.append(Vector3(half_extent, height, pos))
		else:
			lines_minor.append(Vector3(-half_extent, height, pos))
			lines_minor.append(Vector3(half_extent, height, pos))

		# Z-axis line (at x=0)
		if i == 0:
			lines_z.append(Vector3(0, height, -half_extent))
			lines_z.append(Vector3(0, height, half_extent))
		elif is_major:
			lines_major.append(Vector3(pos, height, -half_extent))
			lines_major.append(Vector3(pos, height, half_extent))
		else:
			lines_minor.append(Vector3(pos, height, -half_extent))
			lines_minor.append(Vector3(pos, height, half_extent))

	# Add lines with materials
	if lines_minor.size() > 0:
		gizmo.add_lines(lines_minor, get_material("grid_minor", gizmo), false)
	if lines_major.size() > 0:
		gizmo.add_lines(lines_major, get_material("grid_major", gizmo), false)
	if lines_x.size() > 0:
		gizmo.add_lines(lines_x, get_material("grid_axis_x", gizmo), false)
	if lines_z.size() > 0:
		gizmo.add_lines(lines_z, get_material("grid_axis_z", gizmo), false)


## Set grid system reference


func set_grid_system(system: Node) -> void:
	grid_system = system
