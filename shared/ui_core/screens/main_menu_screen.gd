extends "res://shared/ui_core/screens/base_screen.gd"

# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])



const WORLD_SCENE: String = "res://game/world/maps/map.tscn"
const OPTIONS_SCREEN: String = "res://shared/ui_core/screens/options_screen.tscn"
const MULTIPLAYER_SCREEN: String = "res://shared/ui_core/screens/multiplayer_menu_screen.tscn"
const MOD_MANAGER_SCREEN: String = "res://shared/ui_core/screens/mod_manager_screen.tscn"
const SHOWCASE_SCENE: String = "res://game/world/maps/showcase.tscn"

var _background_viewport: SubViewportContainer = null
var _safe_margins: MarginContainer = null
var _menu_side: CenterContainer = null
var _art_space: Control = null
var _menu_panel: PanelContainer = null
var _menu_container: VBoxContainer = null
var _title: Label = null
var _menu_hint: Label = null
var _play_btn: Button = null
var _showcase_btn: Button = null
var _multiplayer_btn: Button = null
var _options_btn: Button = null
var _mods_btn: Button = null
var _quit_btn: Button = null
var _editor_btn: Button = null


func _on_ready() -> void:
	_setup_3d_background()
	_build_menu_ui()
	_setup_focus()
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()

	# Start menu music
	_start_menu_music()

	# Connect to localization
	var localization: Node = GameManager.get_core_system("localization")
	if localization and localization.has_signal("language_changed"):
		var lang_signal_connected: bool = (
			localization.language_changed.is_connected(_on_language_changed)
		)
		if not lang_signal_connected:
			if not localization.language_changed.is_connected(_on_language_changed):
				localization.language_changed.connect(_on_language_changed)


func _start_menu_music() -> void:
	# Wait a frame for audio system to be fully initialized
	await get_tree().process_frame
	
	var audio: Node = GameManager.get_core_system("audio")
	if audio and audio.has_method("play_next_track"):
		# Check if music is already playing using public API
		if audio.has_method("is_music_playing") and not audio.is_music_playing():
			audio.play_next_track()
			_log("Started menu music", "MainMenu")
		elif not audio.has_method("is_music_playing"):
			# Fallback if method doesn't exist yet
			audio.play_next_track()
			_log("Started menu music (fallback)", "MainMenu")
	else:
		push_warning("[MainMenu] Audio system not available for menu music")


func _on_screen_enter(_params: Dictionary) -> void:
	# Ensure mouse is visible in menu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Focus first button for gamepad
	if _play_btn:
		_play_btn.grab_focus()


# ============================================================================
# 3D BACKGROUND
# ============================================================================


func _setup_3d_background() -> void:
	# Create SubViewportContainer for 3D background
	_background_viewport = SubViewportContainer.new()
	_background_viewport.stretch = true
	_background_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background_viewport)
	_background_viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(_background_viewport, 0)  # Send to back

	var viewport: SubViewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	_background_viewport.add_child(viewport)

	# Create 3D Scene
	var root_3d: Node3D = Node3D.new()
	viewport.add_child(root_3d)

	# Environment
	var env: WorldEnvironment = WorldEnvironment.new()
	var env_res: Environment = Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.05, 0.05, 0.08)
	env_res.fog_enabled = true
	env_res.fog_light_color = Color(0.1, 0.1, 0.15)
	env_res.fog_density = 0.01
	env.environment = env_res
	root_3d.add_child(env)

	# Light
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.shadow_enabled = true
	root_3d.add_child(light)

	# A deterministic skyline keeps the menu visually stable across launches.
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x4D4F4455
	for i: int in range(14):
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(rng.randf_range(1, 4), rng.randf_range(5, 15), rng.randf_range(1, 4))
		mesh_instance.mesh = box
		mesh_instance.position = Vector3(
			rng.randf_range(-50, 50), box.size.y / 2, rng.randf_range(-50, 50)
		)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(
			rng.randf_range(0.04, 0.16), rng.randf_range(0.08, 0.22), rng.randf_range(0.18, 0.42)
		)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.5
		mesh_instance.material_override = mat
		root_3d.add_child(mesh_instance)

	# Ground
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var g_mat: StandardMaterial3D = StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.02, 0.02, 0.02)
	ground.material_override = g_mat
	root_3d.add_child(ground)

	# Camera with dolly animation
	var cam_pivot: Node3D = Node3D.new()
	root_3d.add_child(cam_pivot)

	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0, 10, 30)
	camera.rotation_degrees.x = -15
	cam_pivot.add_child(camera)

	if not _is_reduced_motion():
		var tween: Tween = create_tween().set_loops()
		tween.tween_property(cam_pivot, "rotation:y", deg_to_rad(360), 90.0).from(0.0)


# ============================================================================
# MENU UI
# ============================================================================


func _build_menu_ui() -> void:
	var veil := ColorRect.new()
	veil.name = "BackdropVeil"
	veil.color = Color(0.015, 0.02, 0.04, 0.58)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_safe_margins = MarginContainer.new()
	_safe_margins.name = "SafeMargins"
	add_child(_safe_margins)
	_safe_margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var split := HBoxContainer.new()
	split.name = "MenuSplit"
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_safe_margins.add_child(split)

	_menu_side = CenterContainer.new()
	_menu_side.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_menu_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_side.custom_minimum_size.x = 480
	split.add_child(_menu_side)

	_art_space = Control.new()
	_art_space.name = "ArtSpace"
	_art_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_art_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art_space.size_flags_stretch_ratio = 1.1
	split.add_child(_art_space)

	_menu_panel = PanelContainer.new()
	_menu_panel.name = "MenuPanel"
	_menu_panel.custom_minimum_size = Vector2(420, 0)
	_menu_panel.add_theme_stylebox_override("panel", _create_menu_panel_style())
	_menu_side.add_child(_menu_panel)

	var panel_margins := MarginContainer.new()
	panel_margins.add_theme_constant_override("margin_left", 32)
	panel_margins.add_theme_constant_override("margin_right", 32)
	panel_margins.add_theme_constant_override("margin_top", 18)
	panel_margins.add_theme_constant_override("margin_bottom", 18)
	_menu_panel.add_child(panel_margins)

	_menu_container = VBoxContainer.new()
	_menu_container.name = "MenuActions"
	_menu_container.add_theme_constant_override("separation", 6)
	panel_margins.add_child(_menu_container)

	_title = Label.new()
	_title.name = "Title"
	_title.text = "MODUS"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	_menu_container.add_child(_title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "BUILD. FIGHT. REWRITE THE RULES."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.58, 0.7, 0.86))
	_menu_container.add_child(subtitle)

	_menu_container.add_child(HSeparator.new())

	# Play Button
	_play_btn = _create_menu_button("menu_play", "Start Game")
	_play_btn.name = "PlayButton"
	_style_primary_button(_play_btn)
	_play_btn.pressed.connect(_on_play_pressed)
	_menu_container.add_child(_play_btn)

	_showcase_btn = _create_menu_button("menu_showcase", "Showcase")
	_showcase_btn.name = "ShowcaseButton"
	_showcase_btn.pressed.connect(_on_showcase_pressed)
	_menu_container.add_child(_showcase_btn)

	# Multiplayer Button
	_multiplayer_btn = _create_menu_button("menu_multiplayer", "Multiplayer")
	_multiplayer_btn.name = "MultiplayerButton"
	_multiplayer_btn.pressed.connect(_on_multiplayer_pressed)
	_menu_container.add_child(_multiplayer_btn)

	# Options Button
	_options_btn = _create_menu_button("menu_options", "Options")
	_options_btn.name = "OptionsButton"
	_options_btn.pressed.connect(_on_options_pressed)
	_menu_container.add_child(_options_btn)

	# Mods Button
	_mods_btn = _create_menu_button("menu_mods", "Mods")
	_mods_btn.name = "ModsButton"
	_mods_btn.pressed.connect(_on_mods_pressed)
	_menu_container.add_child(_mods_btn)

	_menu_container.add_child(HSeparator.new())

	# Editor Button
	_editor_btn = _create_menu_button("menu_editor", "Editor")
	_editor_btn.name = "EditorButton"
	_editor_btn.pressed.connect(_on_editor_pressed)
	_menu_container.add_child(_editor_btn)

	# Quit Button (last)
	_quit_btn = _create_menu_button("menu_quit", "Quit")
	_quit_btn.name = "QuitButton"
	_quit_btn.pressed.connect(_on_quit_pressed)
	_menu_container.add_child(_quit_btn)

	_menu_hint = Label.new()
	_menu_hint.name = "MenuHint"
	_menu_hint.text = "Launch the current single-player build."
	_menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_hint.custom_minimum_size.y = 34
	_menu_hint.add_theme_font_size_override("font_size", 12)
	_menu_hint.add_theme_color_override("font_color", Color(0.62, 0.7, 0.8))
	_menu_container.add_child(_menu_hint)

	_connect_menu_hint(_play_btn, "Launch the current single-player build.")
	_connect_menu_hint(_showcase_btn, "Tour the maintained gameplay showcase and capture route.")
	_connect_menu_hint(_multiplayer_btn, "Host or join through the maintained multiplayer menu.")
	_connect_menu_hint(_options_btn, "Adjust controls, audio, graphics, and accessibility.")
	_connect_menu_hint(_mods_btn, "Review installed mods and local package state.")
	_connect_menu_hint(_editor_btn, "Open the showcase with editor participation enabled.")
	_connect_menu_hint(_quit_btn, "Exit MODUS after confirmation.")

	var version := Label.new()
	version.name = "VersionLabel"
	version.text = "VERSION %s" % GameManager.GAME_VERSION
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 11)
	version.add_theme_color_override("font_color", Color(0.48, 0.55, 0.66))
	_menu_container.add_child(version)


func _create_menu_button(loc_key: String, fallback: String) -> Button:
	var btn: Button

	# Use CustomButton if available
	if ClassDB.class_exists("CustomButton"):
		btn = CustomButton.new()
	else:
		btn = Button.new()

	btn.custom_minimum_size = Vector2(280, 48)
	btn.focus_mode = Control.FOCUS_ALL

	# Try to localize
	var localization: Node = GameManager.get_core_system("localization")
	if localization and localization.has_method("translate"):
		var translated: String = localization.translate(loc_key)
		btn.text = translated if translated != loc_key else fallback
	else:
		btn.text = fallback

	return btn


func _connect_menu_hint(button: Button, hint: String) -> void:
	button.focus_entered.connect(_set_menu_hint.bind(hint))
	button.mouse_entered.connect(_set_menu_hint.bind(hint))


func _set_menu_hint(hint: String) -> void:
	if _menu_hint:
		_menu_hint.text = hint


func _create_menu_panel_style() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.035, 0.045, 0.07, 0.96)
	panel.border_color = Color(0.2, 0.38, 0.62, 0.85)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(12)
	panel.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	panel.shadow_size = 24
	panel.shadow_offset = Vector2(0, 10)
	return panel


func _style_primary_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.38, 0.68)
	normal.border_color = Color(0.42, 0.72, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.16, 0.48, 0.82)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.09, 0.3, 0.56)
	var focus: StyleBoxFlat = normal.duplicate()
	focus.border_color = Color(0.78, 0.91, 1.0)
	focus.set_border_width_all(2)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.08, 0.12, 0.18)
	disabled.border_color = Color(0.28, 0.36, 0.46, 0.65)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.62, 0.72))


func _update_responsive_layout() -> void:
	if not _safe_margins or not _menu_panel or not _title:
		return
	var narrow := size.x < 720.0 or size.y < 720.0
	var edge := 18 if narrow else 40
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_safe_margins.add_theme_constant_override(side, edge)
	_menu_panel.custom_minimum_size.x = minf(420.0, maxf(280.0, size.x - edge * 2.0))
	_title.add_theme_font_size_override("font_size", 46 if narrow else 64)
	if _menu_side:
		_menu_side.custom_minimum_size.x = 0.0 if narrow else 480.0
		_menu_side.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_SHRINK_BEGIN
		)
	if _art_space:
		_art_space.visible = not narrow


func _is_reduced_motion() -> bool:
	var ui_service := UISystem.get_service()
	return (
		ui_service
		and ui_service.theme_manager
		and ui_service.theme_manager.has_method("is_reduced_motion")
		and ui_service.theme_manager.is_reduced_motion()
	)


func _setup_focus() -> void:
	var buttons: Array[Control] = []
	if _play_btn:
		buttons.append(_play_btn)
	if _showcase_btn:
		buttons.append(_showcase_btn)
	if _multiplayer_btn:
		buttons.append(_multiplayer_btn)
	if _options_btn:
		buttons.append(_options_btn)
	if _mods_btn:
		buttons.append(_mods_btn)
	if _editor_btn:
		buttons.append(_editor_btn)
	if _quit_btn:
		buttons.append(_quit_btn)

	register_focus_controls(buttons, "main_menu")
	for i: int in range(buttons.size()):
		buttons[i].focus_neighbor_top = buttons[(i - 1 + buttons.size()) % buttons.size()].get_path()
		buttons[i].focus_neighbor_bottom = buttons[(i + 1) % buttons.size()].get_path()


# ============================================================================
# BUTTON HANDLERS
# ============================================================================


func _on_play_pressed() -> void:
	_launch_scene(WORLD_SCENE)


func _on_showcase_pressed() -> void:
	_launch_scene(SHOWCASE_SCENE)


func _launch_scene(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("[MainMenuScreen] Scene not found: %s" % scene_path)
		return
	GameManager.change_state(GameManager.State.INITIALIZING)
	var ui_service := UISystem.get_service()
	if ui_service and ui_service.ui_manager:
		ui_service.ui_manager.clear_all()
	get_tree().change_scene_to_file(scene_path)


func _on_multiplayer_pressed() -> void:
	if ResourceLoader.exists(MULTIPLAYER_SCREEN):
		navigate_to(MULTIPLAYER_SCREEN)
	else:
		# Fallback: show a simple message
		var dialog: Control = await show_modal(
			"res://shared/ui_core/components/modal_popup.tscn",
			{"title": "Coming Soon", "message": "Multiplayer menu not yet implemented."}
		)
		if dialog:
			pass  # Dialog handles itself


func _on_options_pressed() -> void:
	if ResourceLoader.exists(OPTIONS_SCREEN):
		navigate_to(OPTIONS_SCREEN)
	else:
		push_error("[MainMenuScreen] Options screen not found: %s" % OPTIONS_SCREEN)


func _on_mods_pressed() -> void:
	if ResourceLoader.exists(MOD_MANAGER_SCREEN):
		# Open as modal so we don't lose the 3D background
		show_modal(MOD_MANAGER_SCREEN, {"block_input": true})
	else:
		push_error("[MainMenuScreen] Mod manager screen not found: %s" % MOD_MANAGER_SCREEN)


func _on_quit_pressed() -> void:
	var dialog: Control = await show_modal(
		"res://shared/ui_core/components/modal_popup.tscn",
		{
			"title": "Quit Game",
			"message": "Are you sure you want to exit?",
			"buttons":
			[
				{"text": "Yes", "callback": _quit_game, "style": "danger"},
				{"text": "No", "is_cancel": true}
			]
		}
	)
	if not dialog:
		# Fallback if modal not available
		get_tree().quit()


func _quit_game() -> void:
	get_tree().quit()


func _on_editor_pressed() -> void:
	# Enable editor mode
	var globals: Node = GameManager.get_core_system("globals")
	if globals and "join_as_editor" in globals:
		globals.join_as_editor = true
	_launch_scene(SHOWCASE_SCENE)


# ============================================================================
# LOCALIZATION
# ============================================================================


func _on_language_changed(_lang: String) -> void:
	var localization: Node = GameManager.get_core_system("localization")
	if not localization or not localization.has_method("translate"):
		return
	
	if _play_btn:
		_play_btn.text = _translate_or_fallback(localization, "menu_play", "Play")
	if _showcase_btn:
		_showcase_btn.text = _translate_or_fallback(localization, "menu_showcase", "Showcase")
	if _multiplayer_btn:
		_multiplayer_btn.text = _translate_or_fallback(localization, "menu_multiplayer", "Multiplayer")
	if _options_btn:
		_options_btn.text = _translate_or_fallback(localization, "menu_options", "Options")
	if _mods_btn:
		_mods_btn.text = _translate_or_fallback(localization, "menu_mods", "Mods")
	if _editor_btn:
		_editor_btn.text = _translate_or_fallback(localization, "menu_editor", "Editor")
	if _quit_btn:
		_quit_btn.text = _translate_or_fallback(localization, "menu_quit", "Quit")


func _translate_or_fallback(localization: Node, key: String, fallback: String) -> String:
	var translated: String = localization.translate(key)
	return translated if translated != key else fallback
