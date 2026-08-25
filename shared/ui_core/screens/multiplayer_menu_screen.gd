class_name MultiplayerMenuScreen
extends BaseScreen

# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])



const HOST_GAME_SCREEN: String = "res://shared/ui_core/screens/host_game_screen.tscn"

var _panel: PanelContainer = null
var _address_input: LineEdit = null
var _join_btn: Button = null
var _host_btn: Button = null
var _back_btn: Button = null
var _content_width: float = 400.0


func _on_ready() -> void:
	_build_ui()
	_setup_focus()
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()


func _on_screen_enter(_params: Dictionary) -> void:
	if _address_input:
		_address_input.grab_focus()


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

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = _tr("menu_multiplayer", "Multiplayer")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Join section
	var join_label: Label = Label.new()
	join_label.text = _tr("mp_join_server", "Join Server")
	join_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(join_label)

	var join_row: VBoxContainer = VBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	vbox.add_child(join_row)

	var ip_label: Label = Label.new()
	ip_label.text = _tr("mp_ip_address", "IP Address:")
	join_row.add_child(ip_label)

	var address_row: HBoxContainer = HBoxContainer.new()
	address_row.add_theme_constant_override("separation", 8)
	join_row.add_child(address_row)

	_address_input = LineEdit.new()
	_address_input.placeholder_text = "127.0.0.1"
	_address_input.custom_minimum_size.x = 120
	_address_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address_row.add_child(_address_input)

	_join_btn = _create_button("mp_join", "Join")
	_join_btn.pressed.connect(_on_join_pressed)
	address_row.add_child(_join_btn)

	vbox.add_child(HSeparator.new())

	# Host section
	var host_label: Label = Label.new()
	host_label.text = _tr("mp_host_game", "Host Game")
	host_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(host_label)

	_host_btn = _create_button("mp_host_setup", "Setup & Host")
	_host_btn.pressed.connect(_on_host_pressed)
	_host_btn.custom_minimum_size.x = 200
	vbox.add_child(_host_btn)

	vbox.add_child(HSeparator.new())

	# Back button
	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)

	_back_btn = _create_button("menu_back", "Back")
	_back_btn.pressed.connect(go_back)
	btn_container.add_child(_back_btn)


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


func _setup_focus() -> void:
	var controls: Array[Control] = []
	if _address_input:
		controls.append(_address_input)
	if _join_btn:
		controls.append(_join_btn)
	if _host_btn:
		controls.append(_host_btn)
	if _back_btn:
		controls.append(_back_btn)

	register_focus_controls(controls, "multiplayer_menu")


func _update_responsive_layout() -> void:
	if not _panel:
		return
	_content_width = clampf(size.x - 48.0, 280.0, 520.0)
	_panel.custom_minimum_size.x = _content_width


# ============================================================================
# EVENT HANDLERS
# ============================================================================


func _on_join_pressed() -> void:
	var ip: String = _address_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"

	# Start joining the server
	var ns := NetworkSvc.get_service()
	if ns and ns.network_manager:
		_log(str("[MultiplayerMenuScreen] Joining server: %s" % ip), "Log")
		ns.network_manager.join_server(ip)

		# Transition to loading or game
		get_tree().change_scene_to_file("res://game/world/maps/showcase.tscn")
	else:
		push_error("[MultiplayerMenuScreen] NetworkManager not found")


func _on_host_pressed() -> void:
	if ResourceLoader.exists(HOST_GAME_SCREEN):
		navigate_to(HOST_GAME_SCREEN)
	else:
		push_error("[MultiplayerMenuScreen] Host game screen not found: %s" % HOST_GAME_SCREEN)


func _on_host_requested(connection_settings: Dictionary, match_settings: Dictionary) -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(
			str("[MultiplayerMenuScreen] Hosting with: %s, %s" % [connection_settings, match_settings]),
			"Log"
		)

	var ns := NetworkSvc.get_service()
	if ns and ns.network_manager:
		var port: int = connection_settings.get("port", 7777)
		var max_players: int = connection_settings.get("max_players", 8)
		ns.network_manager.host_server(port, max_players)

		# Start the game
		get_tree().change_scene_to_file("res://game/world/maps/showcase.tscn")
