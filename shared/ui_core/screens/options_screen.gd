class_name OptionsScreen
extends BaseScreen

const Constants = preload("res://game/core/constants.gd")

var _panel: PanelContainer = null
var _tab_container: TabContainer = null
var _back_btn: Button = null
var _general_tab: Control = null
var _graphics_tab: Control = null
var _audio_tab: Control = null
var _controls_tab: Control = null


func _on_ready() -> void:
	_build_ui()
	_setup_focus()

	# Connect to localization
	var localization: Node = GameManager.get_core_system("localization")
	if localization and localization.has_signal("language_changed"):
		var lang_connected: bool = localization.language_changed.is_connected(_on_language_changed)
		if not lang_connected:
			if not localization.language_changed.is_connected(_on_language_changed):
				localization.language_changed.connect(_on_language_changed)


func _on_screen_enter(_params: Dictionary) -> void:
	# Select first tab
	if _tab_container:
		_tab_container.current_tab = 0

	if _back_btn:
		_back_btn.grab_focus()


# ============================================================================
# UI BUILDING
# ============================================================================


func _build_ui() -> void:
	# Main panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.anchor_left = 0.1
	_panel.anchor_right = 0.9
	_panel.anchor_top = 0.1
	_panel.anchor_bottom = 0.9
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(vbox)

	# Title
	var title: Label = Label.new()
	title.text = _tr("menu_options", "Options")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	# Tab container
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tab_container)

	# Build tabs
	_build_general_tab()
	_build_graphics_tab()
	_build_audio_tab()
	_build_controls_tab()

	# Back button
	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)

	_back_btn = _create_button("menu_back", "Back")
	_back_btn.pressed.connect(go_back)
	btn_container.add_child(_back_btn)


func _build_general_tab() -> void:
	_general_tab = VBoxContainer.new()
	_general_tab.name = "General"
	_general_tab.add_theme_constant_override("separation", 12)
	_tab_container.add_child(_general_tab)

	# Player Name
	var name_row: HBoxContainer = _create_row(_tr("options_player_name", "Player Name"))
	_general_tab.add_child(name_row)

	var name_input: LineEdit = LineEdit.new()
	name_input.name = "PlayerNameInput"
	name_input.custom_minimum_size.x = 160
	name_input.placeholder_text = "Enter Name"

	# Load current name
	var config: Node = GameManager.get_core_system("config")
	if config and config.has_method("get_value"):
		var current_name: String = config.get_value("gameplay.player_name", "Player")
		name_input.text = current_name

	name_input.text_changed.connect(
		func(new_text: String) -> void:
			var cfg: Node = GameManager.get_core_system("config")
			if cfg and cfg.has_method("set_value"):
				cfg.set_value("gameplay.player_name", new_text)
	)
	name_row.add_child(name_input)

	# Language selector
	var lang_row: HBoxContainer = _create_row(_tr("menu_language", "Language"))
	_general_tab.add_child(lang_row)

	var lang_option: OptionButton = OptionButton.new()
	lang_option.name = "LangOption"
	lang_option.custom_minimum_size.x = 160
	lang_row.add_child(lang_option)

	# Populate languages
	var localization: Node = GameManager.get_core_system("localization")
	if localization and localization.has_method("get_available_languages"):
		var available: Array = localization.get_available_languages()
		var current: String = (
			localization.current_language if "current_language" in localization else "en"
		)
		for i: int in range(available.size()):
			var code: String = available[i]
			var lang_name: String = (
				localization.get_language_name(code)
				if localization.has_method("get_language_name")
				else code
			)
			lang_option.add_item(lang_name, i)
			lang_option.set_item_metadata(i, code)
			if code == current:
				lang_option.selected = i
		lang_option.item_selected.connect(_on_language_selected.bind(lang_option))

	# MapTheme selector
	var theme_row: HBoxContainer = _create_row(_tr("options_theme", "MapTheme"))
	_general_tab.add_child(theme_row)

	var theme_option: OptionButton = OptionButton.new()
	theme_option.name = "ThemeOption"
	theme_option.custom_minimum_size.x = 160

	var theme_mgr: Node = get_node_or_null("/root/ThemeManager")
	if theme_mgr:
		var presets: Array = theme_mgr.get_available_presets()
		var current_theme: String = theme_mgr.get_current_theme_id()
		for i: int in range(presets.size()):
			var preset_id: String = presets[i]
			theme_option.add_item(preset_id.capitalize(), i)
			theme_option.set_item_metadata(i, preset_id)
			if preset_id == current_theme:
				theme_option.selected = i
		theme_option.item_selected.connect(_on_theme_selected.bind(theme_option))

	theme_row.add_child(theme_option)

	# Accessibility - Reduced Motion
	var motion_row: HBoxContainer = _create_row(_tr("options_reduced_motion", "Reduced Motion"))
	_general_tab.add_child(motion_row)

	var motion_check: CheckBox = CheckBox.new()
	var is_reduced: bool = theme_mgr.get_accessibility("reduced_motion") if theme_mgr else false
	motion_check.button_pressed = is_reduced
	motion_check.toggled.connect(_on_reduced_motion_toggled)
	motion_row.add_child(motion_check)


func _build_graphics_tab() -> void:
	_graphics_tab = VBoxContainer.new()
	_graphics_tab.name = "Graphics"
	_graphics_tab.add_theme_constant_override("separation", 12)
	_tab_container.add_child(_graphics_tab)

	# Fullscreen toggle
	var fs_row: HBoxContainer = _create_row(_tr("options_fullscreen", "Fullscreen"))
	_graphics_tab.add_child(fs_row)

	var fs_check: CheckBox = CheckBox.new()
	var current_mode: int = DisplayServer.window_get_mode()
	var is_fullscreen: bool = current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs_check.button_pressed = is_fullscreen
	fs_check.toggled.connect(_on_fullscreen_toggled)
	fs_row.add_child(fs_check)

	# VSync toggle
	var vsync_row: HBoxContainer = _create_row(_tr("options_vsync", "VSync"))
	_graphics_tab.add_child(vsync_row)

	var vsync_check: CheckBox = CheckBox.new()
	var vsync_on: bool = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	vsync_check.button_pressed = vsync_on
	vsync_check.toggled.connect(_on_vsync_toggled)
	vsync_row.add_child(vsync_check)


func _build_audio_tab() -> void:
	_audio_tab = VBoxContainer.new()
	_audio_tab.name = "Audio"
	_audio_tab.add_theme_constant_override("separation", 16)
	_tab_container.add_child(_audio_tab)

	# Master Volume
	_create_volume_slider(
		_audio_tab, "Master", "audio.master_volume", AudioServer.get_bus_index("Master")
	)

	# SFX Volume
	_create_volume_slider(
		_audio_tab,
		Constants.BUS_SFX,
		"audio.sfx_volume",
		AudioServer.get_bus_index(Constants.BUS_SFX)
	)

	# Music Volume
	_create_volume_slider(
		_audio_tab,
		Constants.BUS_MUSIC,
		"audio.music_volume",
		AudioServer.get_bus_index(Constants.BUS_MUSIC)
	)

	# Voice Volume
	_create_volume_slider(_audio_tab, "Voice", "audio.voice_volume", 3)


func _create_volume_slider(
	parent: Control, label_text: String, config_key: String, bus_idx: int
) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	var label: Label = Label.new()
	label.text = _tr("audio_" + label_text.to_lower(), label_text)
	label.custom_minimum_size.x = 100
	row.add_child(label)

	var slider: HSlider
	if ClassDB.class_exists("CustomSlider"):
		slider = CustomSlider.new()
		slider.config_key = config_key
		slider.show_value = true
		slider.value_format = "%.0f"
		slider.value_suffix = "%"
		slider.display_multiplier = 100.0
	else:
		slider = HSlider.new()

	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size.x = 160
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Load from AudioService (Source of Truth) or Config
	var audio_svc: Node = GameManager.get_core_system("audio")

	if audio_svc:
		var db: float = 0.0
		if "master" in config_key:
			db = audio_svc.master_volume
		elif "sfx" in config_key:
			db = audio_svc.sfx_volume
		elif "music" in config_key:
			db = audio_svc.music_volume
		else:
			if bus_idx >= 0 and bus_idx < AudioServer.bus_count:
				db = AudioServer.get_bus_volume_db(bus_idx)
			else:
				db = 0.0

		slider.value = db_to_linear(db)
	else:
		var config_vol: Node = GameManager.get_core_system("config")
		if config_vol and config_vol.has_method("get_value"):
			slider.value = config_vol.get_value(config_key, 1.0)
		else:
			slider.value = 1.0

	slider.value_changed.connect(_on_volume_changed.bind(bus_idx, config_key))
	row.add_child(slider)


func _build_controls_tab() -> void:
	_controls_tab = VBoxContainer.new()
	_controls_tab.name = "Controls"
	_controls_tab.add_theme_constant_override("separation", 12)
	_tab_container.add_child(_controls_tab)

	# Mouse sensitivity
	var sens_row: HBoxContainer = _create_row(_tr("options_sensitivity", "Mouse Sensitivity"))
	_controls_tab.add_child(sens_row)

	var sens_slider: HSlider = HSlider.new()
	sens_slider.min_value = 0.1
	sens_slider.max_value = 3.0
	sens_slider.step = 0.1
	var default_sens: float = 1.0
	var config: Node = GameManager.get_core_system("config")
	var sens_value: float = default_sens
	if config and config.has_method("get_value"):
		sens_value = config.get_value("controls.mouse_sensitivity", default_sens)
	sens_slider.value = sens_value
	sens_slider.custom_minimum_size.x = 160
	sens_slider.value_changed.connect(
		func(v: float) -> void:
			var cfg: Node = GameManager.get_core_system("config")
			if cfg and cfg.has_method("set_value"):
				cfg.set_value("controls.mouse_sensitivity", v)
	)
	sens_row.add_child(sens_slider)

	# Invert Y
	var invert_row: HBoxContainer = _create_row(_tr("options_invert_y", "Invert Y Axis"))
	_controls_tab.add_child(invert_row)

	var invert_check: CheckBox = CheckBox.new()
	var invert_default: bool = false
	var config_inv: Node = GameManager.get_core_system("config")
	var is_inverted: bool = invert_default
	if config_inv and config_inv.has_method("get_value"):
		is_inverted = config_inv.get_value("controls.invert_y", invert_default)
	invert_check.button_pressed = is_inverted
	invert_check.toggled.connect(
		func(pressed: bool) -> void:
			var cfg: Node = GameManager.get_core_system("config")
			if cfg and cfg.has_method("set_value"):
				cfg.set_value("controls.invert_y", pressed)
	)
	invert_row.add_child(invert_check)


# ============================================================================
# HELPERS
# ============================================================================


func _create_row(label_text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


func _setup_focus() -> void:
	# Focus the back button by default
	if _back_btn:
		register_focus_controls([_back_btn], "options_main")


# ============================================================================
# EVENT HANDLERS
# ============================================================================


func _on_language_selected(index: int, btn: OptionButton) -> void:
	var code: String = btn.get_item_metadata(index)
	var localization: Node = GameManager.get_core_system("localization")
	if localization and localization.has_method("load_language"):
		localization.load_language(code)


func _on_theme_selected(index: int, btn: OptionButton) -> void:
	var theme_id: String = btn.get_item_metadata(index)
	var theme_mgr: Node = get_node_or_null("/root/ThemeManager")
	if theme_mgr:
		theme_mgr.set_theme(theme_id)


func _on_reduced_motion_toggled(pressed: bool) -> void:
	var theme_mgr: Node = get_node_or_null("/root/ThemeManager")
	if theme_mgr:
		theme_mgr.set_accessibility("reduced_motion", pressed)


func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var config: Node = GameManager.get_core_system("config")
	if config and config.has_method("set_value"):
		config.set_value("graphics.fullscreen", pressed)


func _on_vsync_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	var config: Node = GameManager.get_core_system("config")
	if config and config.has_method("set_value"):
		config.set_value("graphics.vsync", pressed)


func _on_volume_changed(value: float, bus_idx: int, config_key: String) -> void:
	# Delegate to AudioService if available (preferred)
	# This ensures ducking and other service-level logic works
	var audio_svc: Node = GameManager.get_core_system("audio")

	if audio_svc:
		var db: float = linear_to_db(value)
		# Map config key to service method
		if "master" in config_key:
			audio_svc.set_master_volume(db)
		elif "sfx" in config_key:
			audio_svc.set_sfx_volume(db)
		elif "music" in config_key:
			audio_svc.set_music_volume(db)
		else:
			# Fallback for voice or unknown
			AudioServer.set_bus_volume_db(bus_idx, db)
	else:
		# Fallback direct
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))

	# Save to config
	var config: Node = GameManager.get_core_system("config")
	if config and config.has_method("set_value"):
		config.set_value(config_key, value)


func _on_language_changed(_lang: String) -> void:
	# Rebuild UI with new translations
	# For simplicity, just update tab titles
	if _tab_container:
		_tab_container.set_tab_title(0, _tr("tab_general", "General"))
		_tab_container.set_tab_title(1, _tr("tab_graphics", "Graphics"))
		_tab_container.set_tab_title(2, _tr("tab_audio", "Audio"))
		_tab_container.set_tab_title(3, _tr("tab_controls", "Controls"))

	if _back_btn:
		_back_btn.text = _tr("menu_back", "Back")
