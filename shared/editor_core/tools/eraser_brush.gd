@tool
class_name EraserBrush
extends RefCounted

signal erased(nodes: Array[Node])

var grid_system: Node = null
var editor_state: Node = null
var is_box_selecting: bool = false
var box_start: Vector3 = Vector3.ZERO
var box_end: Vector3 = Vector3.ZERO


func setup(grid: Node, state: Node) -> void:
	grid_system = grid
	editor_state = state


## Start a box selection


func start_box_selection(world_position: Vector3) -> void:
	is_box_selecting = true
	box_start = _snap_position(world_position)
	box_end = box_start


## Update box selection end point


func update_box_selection(world_position: Vector3) -> void:
	if is_box_selecting:
		box_end = _snap_position(world_position)


## Finish box selection and erase


func finish_box_selection() -> Array[Node]:
	is_box_selecting = false
	var erased_nodes := _erase_in_box(box_start, box_end)
	erased.emit(erased_nodes)
	return erased_nodes


## Cancel box selection


func cancel_box_selection() -> void:
	is_box_selecting = false


## Erase single node at position


func erase_at_position(world_position: Vector3, level_root: Node3D) -> Node:
	var snapped := _snap_position(world_position)
	var node := _find_node_at_position(snapped, level_root)

	if node:
		_erase_node(node)
		erased.emit([node])

	return node


## Erase nodes under raycast hit


func erase_at_raycast(hit_result: Dictionary, level_root: Node3D) -> Node:
	if hit_result.is_empty():
		return null

	var collider: Node = hit_result.get("collider")
	if not collider:
		return null

	# Find the root object (CSG node or placed entity)
	var target := _find_erasable_parent(collider, level_root)
	if target:
		_erase_node(target)
		erased.emit([target])

	return target


func _find_erasable_parent(node: Node, level_root: Node3D) -> Node3D:
	var current := node
	while current and current != level_root:
		# CSG nodes placed by editor
		if current is CSGShape3D:
			return current
		# Entities placed by editor
		if current.has_meta("level_editor_placed"):
			return current
		# SpawnPoints
		if current.get_script() and current.get_script().resource_path.contains("spawn_point.gd"):
			return current
		current = current.get_parent()
	return null


func _erase_node(node: Node) -> void:
	if not node:
		return

	# Use the editor manager when embedded, with the runtime fallback for standalone mode.
	var undo: UndoRedo = EditorGlobals.get_undo_redo()
	undo.create_action("Erase Object")

	var parent := node.get_parent()
	undo.add_do_method(Callable(parent, "remove_child").bind(node))
	undo.add_do_method(Callable(node, "queue_free"))
	undo.add_undo_method(Callable(parent, "add_child").bind(node))
	undo.add_undo_reference(node)

	# Free grid cells if applicable
	if grid_system:
		var cell: Vector3i = grid_system.world_to_cell(node.global_position)
		undo.add_do_method(Callable(grid_system, "free_cell").bind(cell))
		undo.add_undo_method(Callable(grid_system, "occupy_cell").bind(cell, node))

	undo.commit_action()


func _erase_in_box(start: Vector3, end: Vector3) -> Array[Node]:
	var erased_nodes: Array[Node] = []

	if not grid_system:
		return erased_nodes

	var start_cell: Vector3i = grid_system.world_to_cell(start)
	var end_cell: Vector3i = grid_system.world_to_cell(end)
	var cells: Array[Vector3i] = grid_system.get_cells_in_box(start_cell, end_cell)

	# Collect nodes to erase
	var nodes_to_erase: Array[Node] = []
	for cell: Vector3i in cells:
		var occupant: Node = grid_system.get_occupant(cell)
		if occupant and occupant not in nodes_to_erase:
			nodes_to_erase.append(occupant)

	# Erase all in single undo action
	if nodes_to_erase.size() > 0:
		var undo: UndoRedo = EditorGlobals.get_undo_redo()
		undo.create_action("Erase %d Objects" % nodes_to_erase.size())

		for node in nodes_to_erase:
			var parent := node.get_parent()
			undo.add_do_method(Callable(parent, "remove_child").bind(node))
			undo.add_do_method(Callable(node, "queue_free"))
			undo.add_undo_method(Callable(parent, "add_child").bind(node))
			undo.add_undo_reference(node)

			var cell: Vector3i = grid_system.world_to_cell(node.global_position)
			undo.add_do_method(Callable(grid_system, "free_cell").bind(cell))
			undo.add_undo_method(Callable(grid_system, "occupy_cell").bind(cell, node))

			erased_nodes.append(node)

		undo.commit_action()

	return erased_nodes


func _find_node_at_position(position: Vector3, _level_root: Node3D) -> Node3D:
	if not grid_system:
		return null

	var cell: Vector3i = grid_system.world_to_cell(position)
	return grid_system.get_occupant(cell)


func _snap_position(position: Vector3) -> Vector3:
	if grid_system:
		return grid_system.snap_to_grid(position)
	return position


## Get box selection bounds for gizmo preview


func get_box_bounds() -> Dictionary:
	if not is_box_selecting:
		return {}

	return {
		"min":
		Vector3(
			minf(box_start.x, box_end.x), minf(box_start.y, box_end.y), minf(box_start.z, box_end.z)
		),
		"max":
		Vector3(
			maxf(box_start.x, box_end.x), maxf(box_start.y, box_end.y), maxf(box_start.z, box_end.z)
		)
	}
