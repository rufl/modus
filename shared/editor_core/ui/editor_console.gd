@tool
extends PanelContainer

signal command_executed(command: String, result: Dictionary)
signal console_closed

const MAX_HISTORY := 100
const MAX_OUTPUT_LINES := 200

var parser: CommandParser
var command_history: Array[String] = []
var history_index: int = -1
var output_label: RichTextLabel
var input_line: LineEdit
var autocomplete_popup: PopupMenu
var editor_state: Node = null
var level_root: Node3D = null
var grid_system: Node = null
var undo_system: Object = null
var hotbar: Node = null
var asset_registry: Node = null


func _ready() -> void:
	parser = CommandParser.new()
	_create_ui()
	visible = false


func setup(state: Node, level: Node3D = null, grid: Node = null, registry: Node = null) -> void:
	editor_state = state
	level_root = level
	grid_system = grid
	asset_registry = registry


func _create_ui() -> void:
	# Main styling
	custom_minimum_size = Vector2(600, 300)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Console"
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.flat = true
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	# Output area
	output_label = RichTextLabel.new()
	output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_label.bbcode_enabled = true
	output_label.scroll_following = true
	output_label.selection_enabled = true
	output_label.add_theme_font_size_override("normal_font_size", 12)
	vbox.add_child(output_label)

	# Initial message
	_print_info("Type /help for available commands. Press Tab for autocomplete.")

	# Input area
	var input_hbox := HBoxContainer.new()
	vbox.add_child(input_hbox)

	var prompt := Label.new()
	prompt.text = "> "
	prompt.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	input_hbox.add_child(prompt)

	input_line = LineEdit.new()
	input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_line.placeholder_text = "/command args..."
	input_line.text_submitted.connect(_on_command_submitted)
	input_line.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	input_hbox.add_child(input_line)

	# Autocomplete popup
	autocomplete_popup = PopupMenu.new()
	autocomplete_popup.id_pressed.connect(_on_autocomplete_selected)
	add_child(autocomplete_popup)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				close()
				get_viewport().set_input_as_handled()

			KEY_UP:
				_history_previous()
				get_viewport().set_input_as_handled()

			KEY_DOWN:
				_history_next()
				get_viewport().set_input_as_handled()

			KEY_TAB:
				_show_autocomplete()
				get_viewport().set_input_as_handled()


## Open the console


func open() -> void:
	visible = true
	input_line.grab_focus()
	input_line.clear()
	history_index = -1


## Close the console


func close() -> void:
	visible = false
	autocomplete_popup.hide()
	console_closed.emit()


func _on_close_pressed() -> void:
	close()


## Submit a command programmatically


func submit_command(text: String) -> void:
	_process_command(text)


## Handle command submission from UI


func _on_command_submitted(text: String) -> void:
	_process_command(text)


## Internal: process a command string


func _process_command(text: String) -> void:
	if text.strip_edges().is_empty():
		return

	# Add to history
	if command_history.is_empty() or command_history[0] != text:
		command_history.insert(0, text)
		if command_history.size() > MAX_HISTORY:
			command_history.pop_back()
	history_index = -1

	# Echo command
	_print_command(text)

	# Parse and execute
	var result: CommandParser.ParseResult = parser.parse(text)

	if not result.success:
		_print_error(result.error_msg)
		if not result.usage.is_empty():
			_print_info("Usage: " + result.usage)
	else:
		_execute_command(result)

	# Clear input
	input_line.clear()


## Execute a parsed command


func _execute_command(result: CommandParser.ParseResult) -> void:
	var cmd: String = result.command
	var args: Array = result.args

	var exec_result := {"success": false, "message": ""}

	match cmd:
		"help":
			var help_cmd: String = args[0] if args.size() > 0 else ""
			var help_text: String = parser.get_help(help_cmd)
			_print_info(help_text)
			exec_result.success = true

		"fill":
			exec_result = _exec_fill(args)

		"setblock":
			exec_result = _exec_setblock(args)

		"summon":
			exec_result = _exec_summon(args)

		"tp":
			exec_result = _exec_tp(args)

		"undo":
			exec_result = _exec_undo(args)

		"redo":
			exec_result = _exec_redo(args)

		"save":
			exec_result = _exec_save(args)

		"load":
			exec_result = _exec_load(args)

		"clear":
			exec_result = _exec_clear(args)

		"grid":
			exec_result = _exec_grid(args)

		"snap":
			exec_result = _exec_snap(args)

		"clone":
			exec_result = _exec_clone(args)

		"give":
			exec_result = _exec_give(args)

		_:
			exec_result.message = "Command not implemented: " + cmd

	if exec_result.success:
		if not exec_result.get("message", "").is_empty():
			_print_success(exec_result.message)
	else:
		if not exec_result.get("message", "").is_empty():
			_print_error(exec_result.message)

	command_executed.emit(cmd, exec_result)


## Fill command


func _exec_fill(args: Array) -> Dictionary:
	if args.size() < 7 or args.size() > 8:
		return {"success": false, "message": "Invalid fill arguments"}

	var block_id: String = args[0]
	var pos1: Vector3 = parser.resolve_coordinates(args[1], args[2], args[3])
	var pos2: Vector3 = parser.resolve_coordinates(args[4], args[5], args[6])
	var mode: String = args[7].to_lower() if args.size() > 7 else "replace"

	if mode != "replace" and mode != "hollow" and mode != "outline":
		return {"success": false, "message": "Unsupported fill mode: %s" % mode}

	if not level_root:
		return {"success": false, "message": "No level root set"}

	# Calculate inclusive bounds in grid-cell coordinates.
	var min_pos := Vector3(minf(pos1.x, pos2.x), minf(pos1.y, pos2.y), minf(pos1.z, pos2.z))
	var max_pos := Vector3(maxf(pos1.x, pos2.x), maxf(pos1.y, pos2.y), maxf(pos1.z, pos2.z))

	var cell_size: float = 1.0
	if grid_system and grid_system.has_method("get_cell_size"):
		cell_size = grid_system.get_cell_size()
	elif grid_system and "cell_size" in grid_system:
		cell_size = grid_system.cell_size
	if cell_size <= 0.0 or not is_finite(cell_size):
		return {"success": false, "message": "Invalid grid cell size"}

	var count_x := maxi(1, int(round((max_pos.x - min_pos.x) / cell_size)) + 1)
	var count_y := maxi(1, int(round((max_pos.y - min_pos.y) / cell_size)) + 1)
	var count_z := maxi(1, int(round((max_pos.z - min_pos.z) / cell_size)) + 1)
	var material: Material = _get_block_material(block_id)
	var placed := 0

	for x: int in range(count_x):
		for y: int in range(count_y):
			for z: int in range(count_z):
				var boundary_axes := int(x == 0 or x == count_x - 1)
				boundary_axes += int(y == 0 or y == count_y - 1)
				boundary_axes += int(z == 0 or z == count_z - 1)
				if mode == "hollow" and boundary_axes == 0:
					continue
				if mode == "outline" and boundary_axes < 2:
					continue

				var block := CSGBox3D.new()
				block.size = Vector3.ONE * cell_size
				block.position = min_pos + Vector3(x, y, z) * cell_size
				block.set_meta("level_editor_placed", true)
				block.set_meta("fill_command", true)
				block.set_meta("block_id", block_id)
				if material:
					block.material = material
				level_root.add_child(block)
				_set_owner_recursive(block, _level_owner())
				placed += 1

	return {"success": true, "message": "Filled %d blocks with %s (%s)" % [placed, block_id, mode]}


func _get_block_material(block_id: String) -> Material:
	var registry := _resolve_asset_registry()
	if registry and registry.has_method("get_asset_by_id"):
		var asset: Dictionary = registry.get_asset_by_id(block_id)
		if asset.get("material") is Material:
			return asset["material"]
	return null


func _resolve_asset_registry() -> Node:
	if is_instance_valid(asset_registry):
		return asset_registry
	if editor_state:
		var state_parent := editor_state.get_parent()
		if state_parent:
			var sibling := state_parent.get_node_or_null("AssetRegistry")
			if sibling:
				asset_registry = sibling
				return asset_registry
	var features := get_parent()
	if features and "asset_registry" in features:
		var registered: Variant = features.get("asset_registry")
		if registered is Node:
			asset_registry = registered
			return asset_registry
	return null


func _resolve_hotbar() -> Node:
	if is_instance_valid(hotbar):
		return hotbar
	var features := get_parent()
	if features:
		if features.has_method("get_hotbar"):
			var resolved: Control = features.get_hotbar()
			if resolved:
				hotbar = resolved
				return hotbar
		if "hotbar" in features:
			var owned: Variant = features.get("hotbar")
			if owned is Node:
				hotbar = owned
				return hotbar
	return null


func _level_owner() -> Node:
	return level_root


func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	if not node:
		return
	node.owner = owner_node
	for child: Node in node.get_children():
		_set_owner_recursive(child, owner_node)


func _exec_setblock(args: Array) -> Dictionary:
	var pos: Vector3 = parser.resolve_coordinates(args[0], args[1], args[2])
	var block_id: String = args[3]
	var mode: String = args[4] if args.size() > 4 else "replace"

	if not level_root:
		return {"success": false, "message": "No level root set"}

	var cell_size: float = 1.0
	if grid_system:
		cell_size = grid_system.cell_size if "cell_size" in grid_system else 1.0

	# Keep mode only places into an empty grid cell.
	if mode == "keep" and _is_grid_cell_occupied(pos, cell_size):
		return {"success": false, "message": "Cell at %s is occupied" % pos}

	# Create block
	var block := CSGBox3D.new()
	block.size = Vector3.ONE * cell_size
	block.position = pos
	block.set_meta("level_editor_placed", true)
	level_root.add_child(block)

	return {"success": true, "message": "Placed %s at %s" % [block_id, pos]}


func _is_grid_cell_occupied(pos: Vector3, cell_size: float) -> bool:
	if not level_root:
		return false
	var half := maxf(cell_size * 0.5, 0.01)
	var query_box := AABB(pos - Vector3.ONE * half, Vector3.ONE * cell_size)
	for node in level_root.find_children("*", "Node3D", true, false):
		if not is_instance_valid(node) or not node.get_meta("level_editor_placed", false):
			continue
		var bounds := _get_node_bounds(node, cell_size)
		if bounds.intersects(query_box):
			return true
	return false


func _get_node_bounds(node: Node3D, fallback_size: float) -> AABB:
	if node is CSGShape3D:
		var shape := node as CSGShape3D
		return AABB(shape.global_position - shape.size * 0.5, shape.size)
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mesh_instance := node as MeshInstance3D
		var local_bounds := mesh_instance.mesh.get_aabb()
		return AABB(mesh_instance.global_transform * local_bounds.position, local_bounds.size)
	return AABB(
		node.global_position - Vector3.ONE * fallback_size * 0.5, Vector3.ONE * fallback_size
	)


## Summon command


func _exec_summon(args: Array) -> Dictionary:
	var entity_id: String = args[0]
	var pos: Vector3 = parser.resolve_coordinates(args[1], args[2], args[3])
	var rotation: float = args[4] if args.size() > 4 else 0.0

	if not level_root:
		return {"success": false, "message": "No level root set"}

	# Create spawn point marker
	var spawn := Node3D.new()
	spawn.name = "SpawnPoint_" + entity_id
	spawn.position = pos
	spawn.rotation.y = deg_to_rad(rotation)
	spawn.set_meta("level_editor_placed", true)
	spawn.set_meta("spawn_type", entity_id)
	level_root.add_child(spawn)

	return {"success": true, "message": "Summoned %s at %s" % [entity_id, pos]}


## Teleport command


func _exec_tp(args: Array) -> Dictionary:
	var pos: Vector3 = parser.resolve_coordinates(args[0], args[1], args[2])

	if editor_state and editor_state.has_method("teleport_camera"):
		editor_state.teleport_camera(pos)
	else:
		# Try to find camera directly
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			camera.global_position = pos

	parser.set_reference_position(pos)

	return {"success": true, "message": "Teleported to %s" % pos}


## Undo command


func _exec_undo(args: Array) -> Dictionary:
	var count: int = args[0] if args.size() > 0 else 1

	if undo_system:
		for i: int in range(count):
			undo_system.undo()
		return {"success": true, "message": "Undone %d action(s)" % count}

	return {"success": false, "message": "Undo system not available"}


## Redo command


func _exec_redo(args: Array) -> Dictionary:
	var count: int = args[0] if args.size() > 0 else 1

	if undo_system:
		for i: int in range(count):
			undo_system.redo()
		return {"success": true, "message": "Redone %d action(s)" % count}

	return {"success": false, "message": "Redo system not available"}


## Save command


func _exec_save(args: Array) -> Dictionary:
	var filename: String = args[0]

	if not level_root:
		return {"success": false, "message": "No level to save"}

	# Ensure .tscn extension
	if not filename.ends_with(".tscn"):
		filename += ".tscn"

	var path: String = "user://levels/" + filename

	# Create directory if needed
	DirAccess.make_dir_recursive_absolute("user://levels")

	var packed := PackedScene.new()
	for child: Node in level_root.get_children():
		_set_owner_recursive(child, _level_owner())
	var err: Error = packed.pack(level_root)
	if err != OK:
		return {"success": false, "message": "Failed to pack level: %s" % error_string(err)}

	err = ResourceSaver.save(packed, path)
	if err != OK:
		return {"success": false, "message": "Failed to save level: %s" % error_string(err)}

	return {"success": true, "message": "Saved level to %s" % path}


## Load command


func _exec_load(args: Array) -> Dictionary:
	if args.size() != 1:
		return {"success": false, "message": "Invalid load arguments"}

	var filename: String = args[0]

	if not level_root:
		return {"success": false, "message": "No level root set"}

	# Ensure .tscn extension
	if not filename.ends_with(".tscn"):
		filename += ".tscn"

	var path: String = "user://levels/" + filename

	if not ResourceLoader.exists(path):
		return {"success": false, "message": "Level not found: %s" % path}

	var scene: PackedScene = load(path)
	if not scene:
		return {"success": false, "message": "Failed to load level: %s" % path}

	# Instantiate and validate before touching the current level.
	var instance: Node = scene.instantiate()
	if not is_instance_valid(instance):
		return {"success": false, "message": "Failed to instantiate level: %s" % path}

	var loaded_children: Array[Node] = instance.get_children()
	var owner_node := _level_owner()
	for child: Node in level_root.get_children():
		child.free()

	for child: Node in loaded_children:
		_set_owner_recursive(child, null)
		child.reparent(level_root, false)
		_set_owner_recursive(child, owner_node)
	instance.free()

	return {"success": true, "message": "Loaded level from %s" % path}


## Clear command


func _exec_clear(args: Array) -> Dictionary:
	if args.size() != 0 and args.size() != 6:
		return {"success": false, "message": "Invalid clear arguments (expected 0 or 6)"}
	if not level_root:
		return {"success": false, "message": "No level root set"}

	var cleared: int = 0

	if args.size() == 6:
		# Clear region
		var min_pos: Vector3 = parser.resolve_coordinates(args[0], args[1], args[2])
		var max_pos: Vector3 = parser.resolve_coordinates(args[3], args[4], args[5])

		for child: Node in level_root.get_children():
			if child is Node3D:
				var pos: Vector3 = child.global_position
				if (
					pos.x >= min_pos.x
					and pos.x <= max_pos.x
					and pos.y >= min_pos.y
					and pos.y <= max_pos.y
					and pos.z >= min_pos.z
					and pos.z <= max_pos.z
				):
					child.free()
					cleared += 1
	else:
		# Clear all
		for child: Node in level_root.get_children():
			child.free()
			cleared += 1

	return {"success": true, "message": "Cleared %d objects" % cleared}


## Grid command


func _exec_grid(args: Array) -> Dictionary:
	var size: float = args[0]

	if grid_system and "cell_size" in grid_system:
		grid_system.cell_size = size
		return {"success": true, "message": "Grid size set to %s" % size}

	return {"success": false, "message": "Grid system not available"}


## Snap command


func _exec_snap(args: Array) -> Dictionary:
	var enabled: bool = true

	if args.size() > 0:
		enabled = args[0].to_lower() == "on"
	elif grid_system and "snap_enabled" in grid_system:
		enabled = not grid_system.snap_enabled

	if grid_system and "snap_enabled" in grid_system:
		grid_system.snap_enabled = enabled
		var status: String = "enabled" if enabled else "disabled"
		return {"success": true, "message": "Grid snapping %s" % status}

	return {"success": false, "message": "Grid system not available"}


## Clone command


func _exec_clone(args: Array) -> Dictionary:
	var src_min: Vector3 = parser.resolve_coordinates(args[0], args[1], args[2])
	var src_max: Vector3 = parser.resolve_coordinates(args[3], args[4], args[5])
	var dest: Vector3 = parser.resolve_coordinates(args[6], args[7], args[8])

	if not level_root:
		return {"success": false, "message": "No level root set"}

	var offset: Vector3 = dest - src_min
	var cloned: int = 0

	for child: Node in level_root.get_children():
		if child is Node3D:
			var pos: Vector3 = child.global_position
			if (
				pos.x >= src_min.x
				and pos.x <= src_max.x
				and pos.y >= src_min.y
				and pos.y <= src_max.y
				and pos.z >= src_min.z
				and pos.z <= src_max.z
			):
				var clone: Node = child.duplicate()
				clone.global_position = pos + offset
				level_root.add_child(clone)
				cloned += 1

	return {"success": true, "message": "Cloned %d objects" % cloned}


## Give command


func _exec_give(args: Array) -> Dictionary:
	if args.size() < 1 or args.size() > 2:
		return {"success": false, "message": "Invalid give arguments"}

	var item_id: String = args[0]
	var count: int = args[1] if args.size() > 1 else 1
	if count <= 0:
		return {"success": false, "message": "Give count must be positive"}

	var target_hotbar := _resolve_hotbar()
	var registry := _resolve_asset_registry()
	if not target_hotbar or not target_hotbar.has_method("add_asset"):
		return {"success": false, "message": "Hotbar mutation is not supported"}
	if not registry or not registry.has_method("get_asset_by_id"):
		return {"success": false, "message": "Asset registry is not available"}

	var asset: Dictionary = registry.get_asset_by_id(item_id)
	if asset.is_empty():
		return {"success": false, "message": "Unknown item: %s" % item_id}
	asset["count"] = count
	var slot: int = target_hotbar.add_asset(asset)
	if slot < 0:
		return {"success": false, "message": "Failed to add %s to hotbar" % item_id}

	return {"success": true, "message": "Added %dx %s to hotbar" % [count, item_id]}


## History navigation


func _history_previous() -> void:
	if command_history.is_empty():
		return

	history_index = mini(history_index + 1, command_history.size() - 1)
	input_line.text = command_history[history_index]
	input_line.caret_column = input_line.text.length()


func _history_next() -> void:
	if history_index <= 0:
		history_index = -1
		input_line.clear()
		return

	history_index -= 1
	input_line.text = command_history[history_index]
	input_line.caret_column = input_line.text.length()


## Autocomplete


func _show_autocomplete() -> void:
	var suggestions: Array[String] = parser.get_autocomplete(input_line.text)

	if suggestions.is_empty():
		return

	if suggestions.size() == 1:
		# Single match - complete it
		input_line.text = suggestions[0] + " "
		input_line.caret_column = input_line.text.length()
		return

	# Multiple matches - show popup
	autocomplete_popup.clear()
	for i: int in range(suggestions.size()):
		autocomplete_popup.add_item(suggestions[i], i)

	var popup_height: float = autocomplete_popup.get_contents_minimum_size().y
	var popup_pos: Vector2 = input_line.global_position + Vector2(0, -popup_height)
	autocomplete_popup.position = popup_pos
	autocomplete_popup.popup()


func _on_autocomplete_selected(id: int) -> void:
	var text: String = autocomplete_popup.get_item_text(id)
	input_line.text = text + " "
	input_line.caret_column = input_line.text.length()
	input_line.grab_focus()


## Print helpers


func _print_command(text: String) -> void:
	output_label.append_text("[color=#88aaff]> %s[/color]\n" % text)
	_trim_output()


func _print_info(text: String) -> void:
	output_label.append_text("[color=#aaaaaa]%s[/color]\n" % text)
	_trim_output()


func _print_success(text: String) -> void:
	output_label.append_text("[color=#88ff88]%s[/color]\n" % text)
	_trim_output()


func _print_error(text: String) -> void:
	output_label.append_text("[color=#ff8888]Error: %s[/color]\n" % text)
	_trim_output()


func _trim_output() -> void:
	# Limit output lines
	var text: String = output_label.text
	var lines: PackedStringArray = text.split("\n")
	if lines.size() > MAX_OUTPUT_LINES:
		var keep_lines: PackedStringArray = lines.slice(-MAX_OUTPUT_LINES)
		output_label.clear()
		output_label.append_text("\n".join(keep_lines))
