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
const SHOWCASE_SCENE: String = "res://game/world/maps/comprehensive_showcase.tscn"

var _background_viewport: SubViewportContainer = null
var _menu_container: VBoxContainer = null
var _play_btn: Button = null
var _multiplayer_btn: Button = null
var _options_btn: Button = null
var _mods_btn: Button = null
var _quit_btn: Button = null
var _editor_btn: Button = null


func _on_ready() -> void:
	_setup_3d_background()
	_build_menu_ui()
	_setup_focus()

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
	_background_viewport.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background_viewport)
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

	# Floating geometry
	for i: int in range(20):
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(randf_range(1, 4), randf_range(5, 15), randf_range(1, 4))
		mesh_instance.mesh = box
		mesh_instance.position = Vector3(randf_range(-50, 50), box.size.y / 2, randf_range(-50, 50))
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(randf() * 0.5, randf() * 0.5, randf() * 0.8)
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

	# Rotating camera animation
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(cam_pivot, "rotation:y", deg_to_rad(360), 60.0).from(0.0)


# ============================================================================
# MENU UI
# ============================================================================


func _build_menu_ui() -> void:
	# Create layout structure
	# MarginContainer -> CenterContainer -> VBoxContainer

	var margins: MarginContainer = MarginContainer.new()
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Add some padding from screen edges
	margins.add_theme_constant_override("margin_left", 30)
	margins.add_theme_constant_override("margin_right", 30)
	margins.add_theme_constant_override("margin_top", 30)
	margins.add_theme_constant_override("margin_bottom", 30)
	add_child(margins)

	var center: CenterContainer = CenterContainer.new()
	# Make sure center container fills the margins
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margins.add_child(center)

	# Main container
	_menu_container = VBoxContainer.new()
	_menu_container.custom_minimum_size = Vector2(300, 100)
	_menu_container.add_theme_constant_override("separation", 12)
	center.add_child(_menu_container)

	# Title
	var title: Label = Label.new()
	title.text = "MODUS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.modulate = Color(0.9, 0.9, 1.0)  # Subtle blue-white
	_menu_container.add_child(title)

	_menu_container.add_child(HSeparator.new())

	# Play Button
	_play_btn = _create_menu_button("menu_play", "Start Game")
	_play_btn.pressed.connect(_on_play_pressed)
	_menu_container.add_child(_play_btn)

	# Multiplayer Button
	_multiplayer_btn = _create_menu_button("menu_multiplayer", "Multiplayer")
	_multiplayer_btn.pressed.connect(_on_multiplayer_pressed)
	_menu_container.add_child(_multiplayer_btn)

	# Options Button
	_options_btn = _create_menu_button("menu_options", "Options")
	_options_btn.pressed.connect(_on_options_pressed)
	_menu_container.add_child(_options_btn)

	# Mods Button
	_mods_btn = _create_menu_button("menu_mods", "Mods")
	_mods_btn.pressed.connect(_on_mods_pressed)
	_menu_container.add_child(_mods_btn)

	_menu_container.add_child(HSeparator.new())

	# Editor Button
	_editor_btn = _create_menu_button("menu_editor", "Editor")
	_editor_btn.pressed.connect(_on_editor_pressed)
	_menu_container.add_child(_editor_btn)

	# Quit Button (last)
	_quit_btn = _create_menu_button("menu_quit", "Quit")
	_quit_btn.pressed.connect(_on_quit_pressed)
	_menu_container.add_child(_quit_btn)


func _create_menu_button(loc_key: String, fallback: String) -> Button:
	var btn: Button

	# Use CustomButton if available
	if ClassDB.class_exists("CustomButton"):
		btn = CustomButton.new()
	else:
		btn = Button.new()

	btn.custom_minimum_size = Vector2(200, 40)

	# Try to localize
	var localization: Node = GameManager.get_core_system("localization")
	if localization and localization.has_method("translate"):
		var translated: String = localization.translate(loc_key)
		btn.text = translated if translated != loc_key else fallback
	else:
		btn.text = fallback

	return btn


func _setup_focus() -> void:
	var buttons: Array[Control] = []
	if _play_btn:
		buttons.append(_play_btn)
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


# ============================================================================
# BUTTON HANDLERS
# ============================================================================


func _on_play_pressed() -> void:
	# Launch singleplayer game
	if ResourceLoader.exists(WORLD_SCENE):
		# Set state to INITIALIZING so world.gd doesn't self-destruct
		GameManager.change_state(GameManager.State.INITIALIZING)

		# Clear UI screens first, then change scene
		var us := UISystem.get_service()
		if us and us.ui_manager:
			us.ui_manager.clear_all()
		get_tree().change_scene_to_file(WORLD_SCENE)
	else:
		push_error("[MainMenuScreen] World scene not found: %s" % WORLD_SCENE)


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
	print("[MainMenu] Options button pressed")
	print("[MainMenu] OPTIONS_SCREEN exists: ", ResourceLoader.exists(OPTIONS_SCREEN))
	
	if ResourceLoader.exists(OPTIONS_SCREEN):
		print("[MainMenu] Calling navigate_to...")
		navigate_to(OPTIONS_SCREEN)
	else:
		push_error("[MainMenuScreen] Options screen not found: %s" % OPTIONS_SCREEN)


func _on_mods_pressed() -> void:
	print("[MainMenu] Mods button pressed")
	print("[MainMenu] MOD_MANAGER_SCREEN exists: ", ResourceLoader.exists(MOD_MANAGER_SCREEN))
	
	if ResourceLoader.exists(MOD_MANAGER_SCREEN):
		print("[MainMenu] Calling show_modal...")
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
	GameManager.change_state(GameManager.State.INITIALIZING)

	if ResourceLoader.exists(SHOWCASE_SCENE):
		# Clear UI screens first
		var us := UISystem.get_service()
		if us and us.ui_manager:
			us.ui_manager.clear_all()

		get_tree().change_scene_to_file(SHOWCASE_SCENE)
	else:
		push_error("[MainMenuScreen] Showcase scene not found: %s" % SHOWCASE_SCENE)


# ============================================================================
# LOCALIZATION
# ============================================================================


func _on_language_changed(_lang: String) -> void:
	var localization: Node = GameManager.get_core_system("localization")
	if not localization or not localization.has_method("translate"):
		return
	
	if _play_btn:
		_play_btn.text = localization.translate("menu_play")
	if _multiplayer_btn:
		_multiplayer_btn.text = localization.translate("menu_multiplayer")
	if _options_btn:
		_options_btn.text = localization.translate("menu_options")
	if _mods_btn:
		_mods_btn.text = localization.translate("menu_mods")
	if _editor_btn:
		_editor_btn.text = localization.translate("menu_editor")
	if _quit_btn:
		_quit_btn.text = localization.translate("menu_quit")
