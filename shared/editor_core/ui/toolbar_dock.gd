@tool
extends HBoxContainer

signal tool_selected(tool_type: int)
signal playtest_requested
signal package_requested
signal workshop_requested
signal environment_toggled(is_active: bool)

const LocalEditorGlobals = preload("res://shared/editor_core/core/editor_globals.gd")

var editor_state: Node = null
var tool_buttons: Dictionary = {}


func _ready() -> void:
	_create_toolbar()


## Setup with editor state reference


func setup(state: Node) -> void:
	editor_state = state
	if editor_state:
		editor_state.tool_changed.connect(_on_tool_changed)
		_update_button_states()


func _create_toolbar() -> void:
	# Clear existing children
	for child in get_children():
		child.queue_free()

	add_theme_constant_override("separation", 4)

	# Load tooltip helper
	var TH := preload("res://shared/editor_core/ui/tooltip_helper.gd")

	# Tool buttons with icons - using TooltipHelper for detailed tooltips
	var tools := [
		{"type": 1, "icon": "📦", "tooltip": TH.TOOL_BLOCK_BRUSH},
		{"type": 2, "icon": "🖌️", "tooltip": TH.TOOL_PAINT_BRUSH},
		{"type": 3, "icon": "🗑️", "tooltip": TH.TOOL_ERASER},
		{"type": 4, "icon": "👾", "tooltip": TH.TOOL_ENTITY_PLACER},
		{"type": 5, "icon": "📍", "tooltip": TH.TOOL_SPAWN_POINT},
		{"type": 6, "icon": "🔗", "tooltip": TH.TOOL_CONNECT},
		{"type": 7, "icon": "👆", "tooltip": TH.TOOL_SELECT},
	]

	# Create tool button group
	var tool_group := ButtonGroup.new()

	for tool_data: Dictionary in tools:
		var btn := Button.new()
		btn.text = tool_data.icon
		btn.tooltip_text = tool_data.tooltip
		btn.toggle_mode = true
		btn.button_group = tool_group
		btn.custom_minimum_size = Vector2(32, 32)
		btn.pressed.connect(_on_tool_button_pressed.bind(tool_data.type))
		add_child(btn)
		tool_buttons[tool_data.type] = btn

	# Separator
	var sep1 := VSeparator.new()
	add_child(sep1)

	# Grid toggle button
	var grid_btn := Button.new()
	grid_btn.text = "⊞"
	grid_btn.tooltip_text = TH.GRID_TOGGLE
	grid_btn.toggle_mode = true
	grid_btn.button_pressed = true
	grid_btn.custom_minimum_size = Vector2(32, 32)
	grid_btn.pressed.connect(_on_grid_toggle_pressed)
	add_child(grid_btn)

	# Grid size buttons
	var grid_minus := Button.new()
	grid_minus.text = "-"
	grid_minus.tooltip_text = TH.GRID_DECREASE
	grid_minus.custom_minimum_size = Vector2(24, 32)
	grid_minus.pressed.connect(_on_grid_size_decrease)
	add_child(grid_minus)

	var grid_label := Label.new()
	grid_label.text = "1.0m"
	grid_label.tooltip_text = TH.GRID_SIZE
	grid_label.custom_minimum_size = Vector2(40, 0)
	grid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_label.name = "GridSizeLabel"
	add_child(grid_label)

	var grid_plus := Button.new()
	grid_plus.text = "+"
	grid_plus.tooltip_text = TH.GRID_INCREASE
	grid_plus.custom_minimum_size = Vector2(24, 32)
	grid_plus.pressed.connect(_on_grid_size_increase)
	add_child(grid_plus)

	# Separator
	var sep2 := VSeparator.new()
	add_child(sep2)

	# Play test button
	var play_btn := Button.new()
	play_btn.text = "▶ Test"
	play_btn.tooltip_text = TH.PLAYTEST
	play_btn.custom_minimum_size = Vector2(60, 32)
	play_btn.pressed.connect(_on_playtest_pressed)
	add_child(play_btn)

	# Separator
	var sep3 := VSeparator.new()
	add_child(sep3)

	# Package Button
	var pkg_btn := Button.new()
	pkg_btn.text = "📤"
	pkg_btn.tooltip_text = "Package Level (.mdsl)"
	pkg_btn.custom_minimum_size = Vector2(32, 32)
	pkg_btn.pressed.connect(func() -> void: package_requested.emit())
	add_child(pkg_btn)

	# Workshop Button
	var ws_btn := Button.new()
	ws_btn.text = "🌐"
	ws_btn.tooltip_text = "Steam Workshop"
	ws_btn.custom_minimum_size = Vector2(32, 32)
	ws_btn.pressed.connect(func() -> void: workshop_requested.emit())
	add_child(ws_btn)

	# Environment Button
	var env_btn := Button.new()
	env_btn.text = "☁️"
	env_btn.tooltip_text = "Environment Settings"
	env_btn.toggle_mode = true
	env_btn.custom_minimum_size = Vector2(32, 32)
	env_btn.pressed.connect(func() -> void: environment_toggled.emit(env_btn.button_pressed))
	add_child(env_btn)


func _on_tool_button_pressed(tool_type: int) -> void:
	if editor_state:
		editor_state.select_tool(tool_type)
		editor_state.set_editing_mode(true)
	tool_selected.emit(tool_type)


func _on_tool_changed(_tool_type: int) -> void:
	_update_button_states()


func _update_button_states() -> void:
	if not editor_state:
		return

	for type: int in tool_buttons:
		tool_buttons[type].button_pressed = (type == editor_state.current_tool)


func _on_grid_toggle_pressed() -> void:
	var grid_system := _get_grid_system()
	if grid_system:
		grid_system.toggle_grid()


func _on_grid_size_increase() -> void:
	var grid_system := _get_grid_system()
	if grid_system:
		grid_system.increase_cell_size()
		_update_grid_label()


func _on_grid_size_decrease() -> void:
	var grid_system := _get_grid_system()
	if grid_system:
		grid_system.decrease_cell_size()
		_update_grid_label()


func _update_grid_label() -> void:
	var label := get_node_or_null("GridSizeLabel") as Label
	if label:
		var grid_system := _get_grid_system()
		if grid_system:
			label.text = "%.2fm" % grid_system.cell_size


func _on_playtest_pressed() -> void:
	# Play the current scene
	LocalEditorGlobals.play_current_scene()
	playtest_requested.emit()


func _get_grid_system() -> Node:
	if editor_state:
		return editor_state.get_node_or_null("../GridSystem")
	return null


## Handle keyboard shortcuts


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return

	if not editor_state:
		return

	match event.keycode:
		KEY_B:
			editor_state.select_tool(1)  # Block
		KEY_P:
			editor_state.select_tool(2)  # Paint
		KEY_E:
			editor_state.select_tool(3)  # Erase
		KEY_T:
			editor_state.select_tool(4)  # Entity
		KEY_S:
			if not event.shift_pressed:
				editor_state.select_tool(5)  # Spawn
		KEY_C:
			editor_state.select_tool(6)  # Connect
		KEY_V:
			editor_state.select_tool(7)  # Select
		KEY_G:
			_on_grid_toggle_pressed()
