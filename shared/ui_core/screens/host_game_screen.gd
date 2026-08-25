class_name HostGameScreen
extends BaseScreen

signal host_requested(connection_settings: Dictionary, match_settings: Dictionary)

var _panel: PanelContainer = null
var _port_input: SpinBox = null
var _max_players_input: SpinBox = null
var _password_input: LineEdit = null
var _difficulty_input: OptionButton = null
var _friendly_fire_input: CheckBox = null
var _map_input: OptionButton = null
var _start_btn: Button = null
var _back_btn: Button = null
var _content_width: float = 400.0


func _on_ready() -> void:
	_build_ui()
	_populate_maps()
	_setup_focus()
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()


func _on_screen_enter(_params: Dictionary) -> void:
	if _port_input:
		_port_input.get_line_edit().grab_focus()


# ============================================================================
# UI BUILDING
# ============================================================================


func _build_ui() -> void:
	# Background overlay
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Create layout structure
	var margins: MarginContainer = MarginContainer.new()
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 30)
	margins.add_theme_constant_override("margin_right", 30)
	margins.add_theme_constant_override("margin_top", 30)
	margins.add_theme_constant_override("margin_bottom", 30)
	add_child(margins)

	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margins.add_child(center)

	# Main panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(_content_width, 300)
	center.add_child(_panel)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = _tr("mp_host_game", "Host Game")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Connection Settings Section
	var conn_label: Label = Label.new()
	conn_label.text = _tr("host_connection", "Connection Settings")
	conn_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(conn_label)

	# Port
	var port_row: HBoxContainer = _create_row(_tr("host_port", "Port"))
	vbox.add_child(port_row)

	_port_input = SpinBox.new()
	_port_input.min_value = 1024
	_port_input.max_value = 65535
	_port_input.value = 7777
	_port_input.custom_minimum_size.x = 100
	port_row.add_child(_port_input)

	# Max Players
	var players_row: HBoxContainer = _create_row(_tr("host_max_players", "Max Players"))
	vbox.add_child(players_row)

	_max_players_input = SpinBox.new()
	_max_players_input.min_value = 2
	_max_players_input.max_value = 32
	_max_players_input.value = 8
	_max_players_input.custom_minimum_size.x = 100
	players_row.add_child(_max_players_input)

	# Password
	var pass_row: HBoxContainer = _create_row(_tr("host_password", "Password (optional)"))
	vbox.add_child(pass_row)

	_password_input = LineEdit.new()
	_password_input.placeholder_text = "Leave blank for open server"
	_password_input.secret = true
	_password_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_row.add_child(_password_input)

	vbox.add_child(HSeparator.new())

	# Match Settings Section
	var match_label: Label = Label.new()
	match_label.text = _tr("host_match", "Match Settings")
	match_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(match_label)

	# Map
	var map_row: HBoxContainer = _create_row(_tr("host_map", "Map"))
	vbox.add_child(map_row)

	_map_input = OptionButton.new()
	_map_input.custom_minimum_size.x = 160
	map_row.add_child(_map_input)

	# Difficulty
	var diff_row: HBoxContainer = _create_row(_tr("host_difficulty", "Difficulty"))
	vbox.add_child(diff_row)

	_difficulty_input = OptionButton.new()
	_difficulty_input.add_item("Easy", 0)
	_difficulty_input.add_item("Normal", 1)
	_difficulty_input.add_item("Hard", 2)
	_difficulty_input.selected = 1
	_difficulty_input.custom_minimum_size.x = 150
	diff_row.add_child(_difficulty_input)

	# Friendly Fire
	var ff_row: HBoxContainer = _create_row(_tr("host_friendly_fire", "Friendly Fire"))
	vbox.add_child(ff_row)

	_friendly_fire_input = CheckBox.new()
	_friendly_fire_input.button_pressed = false
	ff_row.add_child(_friendly_fire_input)

	vbox.add_child(HSeparator.new())

	# Buttons
	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_container)

	_back_btn = _create_button("menu_back", "Back")
	_back_btn.pressed.connect(go_back)
	btn_container.add_child(_back_btn)

	_start_btn = _create_button("host_start", "Start Server")
	_start_btn.pressed.connect(_on_start_pressed)
	btn_container.add_child(_start_btn)


func _create_row(label_text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	row.add_child(label)

	return row


func _create_button(loc_key: String, fallback: String) -> Button:
	var btn: Button
	if ClassDB.class_exists("CustomButton"):
		btn = CustomButton.new()
	else:
		btn = Button.new()

	btn.text = _tr(loc_key, fallback)
	btn.custom_minimum_size = Vector2(120, 48)
	btn.focus_mode = Control.FOCUS_ALL
	return btn


func _tr(key: String, fallback: String) -> String:
	var localization: Node = GameManager.get_core_system("localization")
	if localization and localization.has_method("translate"):
		var translated: String = localization.translate(key)
		return translated if translated != key else fallback
	return fallback


func _populate_maps() -> void:
	if not _map_input:
		return

	_map_input.clear()

	var levels_path: String = "res://game/levels/"
	var dir: DirAccess = DirAccess.open(levels_path)

	if not dir:
		_map_input.add_item("Default Map", 0)
		return

	var idx: int = 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			var display_name: String = file_name.get_basename().replace("_", " ").capitalize()
			_map_input.add_item(display_name, idx)
			_map_input.set_item_metadata(idx, levels_path + file_name)
			idx += 1
		file_name = dir.get_next()

	dir.list_dir_end()

	if _map_input.item_count == 0:
		_map_input.add_item("No Maps Found", 0)


func _setup_focus() -> void:
	var controls: Array[Control] = []
	if _port_input:
		controls.append(_port_input)
	if _max_players_input:
		controls.append(_max_players_input)
	if _password_input:
		controls.append(_password_input)
	if _map_input:
		controls.append(_map_input)
	if _difficulty_input:
		controls.append(_difficulty_input)
	if _friendly_fire_input:
		controls.append(_friendly_fire_input)
	if _back_btn:
		controls.append(_back_btn)
	if _start_btn:
		controls.append(_start_btn)

	register_focus_controls(controls, "host_game")


func _update_responsive_layout() -> void:
	if not _panel:
		return
	_content_width = clampf(size.x - 48.0, 300.0, 560.0)
	_panel.custom_minimum_size.x = _content_width


# ============================================================================
# EVENT HANDLERS
# ============================================================================


func _on_start_pressed() -> void:
	var connection_settings: Dictionary = {
		"port": int(_port_input.value) if _port_input else 7777,
		"max_players": int(_max_players_input.value) if _max_players_input else 8,
		"password": _password_input.text if _password_input else ""
	}

	var map_path: String = ""
	if _map_input and _map_input.selected >= 0:
		map_path = _map_input.get_item_metadata(_map_input.selected)

	var match_settings: Dictionary = {
		"difficulty": _difficulty_input.selected if _difficulty_input else 1,
		"friendly_fire": _friendly_fire_input.button_pressed if _friendly_fire_input else false,
		"map_path": map_path
	}

	host_requested.emit(connection_settings, match_settings)

	# Start the server
	var ns := NetworkSvc.get_service()
	if ns and ns.network_manager:
		ns.network_manager.host_server(connection_settings.port, connection_settings.max_players)

		# Load the selected map or default showcase
		var default_world: String = "res://game/world/maps/showcase.tscn"
		var scene_to_load: String = map_path if not map_path.is_empty() else default_world
		if ResourceLoader.exists(scene_to_load):
			get_tree().change_scene_to_file(scene_to_load)
		else:
			push_error("[HostGameScreen] Scene not found: %s" % scene_to_load)
