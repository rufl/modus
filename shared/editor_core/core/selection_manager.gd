@tool
class_name SelectionManager
extends Node


# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])


signal selection_changed(nodes: Array[Node3D])
signal clipboard_changed

var selected_nodes: Array[Node3D] = []
var clipboard: Array[Dictionary] = []
var is_box_selecting: bool = false
var box_start: Vector2 = Vector2.ZERO
var box_end: Vector2 = Vector2.ZERO


func clear_selection() -> void:
	for node in selected_nodes:
		if is_instance_valid(node):
			_set_node_selected(node, false)
	selected_nodes.clear()
	selection_changed.emit(selected_nodes)


## Select a single node (replace selection)


func select(node: Node3D) -> void:
	clear_selection()
	add_to_selection(node)


## Add node to selection


func add_to_selection(node: Node3D) -> void:
	if node in selected_nodes:
		return
	selected_nodes.append(node)
	_set_node_selected(node, true)
	selection_changed.emit(selected_nodes)


## Remove node from selection


func remove_from_selection(node: Node3D) -> void:
	if node not in selected_nodes:
		return
	selected_nodes.erase(node)
	_set_node_selected(node, false)
	selection_changed.emit(selected_nodes)


## Toggle node selection


func toggle_selection(node: Node3D) -> void:
	if node in selected_nodes:
		remove_from_selection(node)
	else:
		add_to_selection(node)


## Select multiple nodes


func select_multiple(nodes: Array[Node3D]) -> void:
	clear_selection()
	for node in nodes:
		if is_instance_valid(node):
			selected_nodes.append(node)
			_set_node_selected(node, true)
	selection_changed.emit(selected_nodes)


func _set_node_selected(node: Node3D, selected: bool) -> void:
	node.set_meta("level_editor_selected", selected)
	# Could add visual highlight here


## Start box selection


func start_box(screen_pos: Vector2) -> void:
	is_box_selecting = true
	box_start = screen_pos
	box_end = screen_pos


## Update box selection


func update_box(screen_pos: Vector2) -> void:
	if is_box_selecting:
		box_end = screen_pos


## Finish box selection and select contained nodes


func finish_box(camera: Camera3D, level_root: Node3D) -> Array[Node3D]:
	is_box_selecting = false

	if not camera or not level_root:
		return []

	var nodes_in_box: Array[Node3D] = []
	var box_rect := _get_box_rect()

	# Check each child of level root
	for child in level_root.get_children():
		if child is Node3D:
			var screen_pos := camera.unproject_position(child.global_position)
			if box_rect.has_point(screen_pos):
				nodes_in_box.append(child)

	# Select the nodes
	if not nodes_in_box.is_empty():
		if Input.is_key_pressed(KEY_SHIFT):
			# Add to selection
			for node in nodes_in_box:
				add_to_selection(node)
		else:
			select_multiple(nodes_in_box)

	return nodes_in_box


func _get_box_rect() -> Rect2:
	return Rect2(
		Vector2(minf(box_start.x, box_end.x), minf(box_start.y, box_end.y)),
		Vector2(absf(box_end.x - box_start.x), absf(box_end.y - box_start.y))
	)


## Copy selected nodes to clipboard


func copy() -> void:
	clipboard.clear()

	for node in selected_nodes:
		if not is_instance_valid(node):
			continue

		var data := {
			"position": node.global_position,
			"rotation": node.global_rotation,
			"scale": node.scale,
			"name": node.name,
		}

		# Store scene path for entities
		if node.scene_file_path and not node.scene_file_path.is_empty():
			data["scene_path"] = node.scene_file_path

		# Store script path for CSG
		if node.get_script():
			data["script_path"] = node.get_script().resource_path

		# Store CSG properties
		if node is CSGBox3D:
			data["type"] = "csg_box"
			data["size"] = node.size
			if node.material:
				data["material"] = node.material.resource_path
		elif node is CSGCylinder3D:
			data["type"] = "csg_cylinder"
			data["radius"] = node.radius
			data["height"] = node.height

		clipboard.append(data)

	clipboard_changed.emit()
	_log(str("[SelectionManager] Copied %d items" % clipboard.size()), "Log")


## Paste clipboard at position


func paste(position: Vector3, parent: Node) -> Array[Node3D]:
	if clipboard.is_empty() or not parent:
		return []

	var pasted: Array[Node3D] = []
	var undo: UndoRedo = EditorGlobals.get_undo_redo()
	undo.create_action("Paste %d Objects" % clipboard.size())

	# Calculate centroid of copied items
	var centroid := Vector3.ZERO
	for data in clipboard:
		centroid += data.position
	centroid /= clipboard.size()

	# Paste with offset
	for data in clipboard:
		var node := _create_node_from_data(data)
		if node:
			# Position relative to paste point
			var offset: Vector3 = data.position - centroid
			node.global_position = position + offset
			node.global_rotation = data.rotation
			node.scale = data.scale

			undo.add_do_method(Callable(parent, "add_child").bind(node))
			var edited_root: Node = EditorGlobals.get_edited_scene_root()
			if edited_root:
				undo.add_do_property(node, "owner", edited_root)
			undo.add_undo_method(Callable(parent, "remove_child").bind(node))
			undo.add_undo_method(Callable(node, "queue_free"))

			pasted.append(node)

	undo.commit_action()

	# Select pasted nodes
	select_multiple(pasted)

	_log(str("[SelectionManager] Pasted %d items" % pasted.size()), "Log")
	return pasted


## Duplicate selected nodes


func duplicate_selection(offset: Vector3 = Vector3(1, 0, 1)) -> Array[Node3D]:
	copy()

	# Calculate paste position
	var center := Vector3.ZERO
	for node in selected_nodes:
		center += node.global_position
	center /= selected_nodes.size()

	var parent: Node = null
	if not selected_nodes.is_empty():
		parent = selected_nodes[0].get_parent()

	return paste(center + offset, parent)


func _create_node_from_data(data: Dictionary) -> Node3D:
	var node: Node3D = null

	# Try to instantiate scene
	if data.has("scene_path"):
		var scene := load(data.scene_path) as PackedScene
		if scene:
			node = scene.instantiate() as Node3D

	# Create CSG node
	elif data.get("type") == "csg_box":
		var box := CSGBox3D.new()
		box.size = data.get("size", Vector3.ONE)
		if data.has("material"):
			box.material = load(data.material)
		box.use_collision = true
		node = box

	elif data.get("type") == "csg_cylinder":
		var cyl := CSGCylinder3D.new()
		cyl.radius = data.get("radius", 0.5)
		cyl.height = data.get("height", 1.0)
		cyl.use_collision = true
		node = cyl

	# Apply script if specified
	if node and data.has("script_path"):
		var script := load(data.script_path)
		if script:
			node.set_script(script)

	# Mark as editor placed
	if node:
		node.set_meta("level_editor_placed", true)
		node.name = data.get("name", "ClipboardItem")

	return node


## Delete selected nodes


func delete_selected() -> int:
	if selected_nodes.is_empty():
		return 0

	var undo: UndoRedo = EditorGlobals.get_undo_redo()
	undo.create_action("Delete %d Objects" % selected_nodes.size())

	var count := 0
	for node in selected_nodes:
		if not is_instance_valid(node):
			continue

		var parent := node.get_parent()
		undo.add_do_method(Callable(parent, "remove_child").bind(node))
		undo.add_do_method(Callable(node, "queue_free"))
		undo.add_undo_method(Callable(parent, "add_child").bind(node))
		undo.add_undo_reference(node)
		count += 1

	undo.commit_action()

	selected_nodes.clear()
	selection_changed.emit(selected_nodes)

	return count


## Move selected nodes by offset


func move_selection(offset: Vector3) -> void:
	if selected_nodes.is_empty():
		return

	var undo: UndoRedo = EditorGlobals.get_undo_redo()
	undo.create_action("Move Selection")

	for node in selected_nodes:
		if is_instance_valid(node):
			var new_pos := node.global_position + offset
			undo.add_do_property(node, "global_position", new_pos)
			undo.add_undo_property(node, "global_position", node.global_position)

	undo.commit_action()


## Rotate selected nodes


func rotate_selection(axis: Vector3, angle: float) -> void:
	if selected_nodes.is_empty():
		return

	var undo: UndoRedo = EditorGlobals.get_undo_redo()
	undo.create_action("Rotate Selection")

	for node in selected_nodes:
		if is_instance_valid(node):
			var new_rot := node.global_rotation + axis * angle
			undo.add_do_property(node, "global_rotation", new_rot)
			undo.add_undo_property(node, "global_rotation", node.global_rotation)

	undo.commit_action()


## Get selection count


func get_selection_count() -> int:
	return selected_nodes.size()


## Check if anything is selected


func has_selection() -> bool:
	return not selected_nodes.is_empty()


## Check if clipboard has content


func has_clipboard() -> bool:
	return not clipboard.is_empty()
