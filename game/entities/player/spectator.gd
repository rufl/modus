extends Node3D
class_name Spectator

@export var fly_speed: float = 15.0
@export var mouse_sensitivity: float = 0.003

var mode: String = "free"
var follow_index: int = 0
var alive_targets: Array = []

@onready var camera: Camera3D = $Camera3D

var _rotation: Vector2 = Vector2.ZERO
var _respawn_time: float = 0.0
var _countdown_label: Label = null
var _title_label: Label = null
var _target_label: Label = null
var _overlay: CanvasLayer = null
var _editor_instance: Control = null
var _show_overlay: bool = true
var _allow_follow_mode: bool = true
var _allow_first_person_mode: bool = true
var _allow_free_fly: bool = true


func _exit_tree() -> void:
	# === SIGNAL HYGIENE: Disconnect signals to prevent memory leaks ===
	var cfg: Node = GameManager.get_core_system("config")
	if cfg and cfg.config_reloaded.is_connected(_load_config):
		cfg.config_reloaded.disconnect(_load_config)


func _ready() -> void:
	# Load config first
	_load_config()

	# Create camera if not exists
	if not has_node("Camera3D"):
		var cam: Camera3D = Camera3D.new()
		cam.name = "Camera3D"
		add_child(cam)
		camera = cam

	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Broadcast SPEC status to scoreboard
	var match_service: Node = GameManager.get_core_system("match")
	if match_service:
		# Helper to access Enums without circular dependency issues if any
		var state_spec: int = 3  # PlayerState.SPECTATING
		if is_instance_valid(Enums):
			state_spec = Enums.PlayerState.SPECTATING
		var peer_id: int = multiplayer.get_unique_id()
		if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			match_service.update_player_status.rpc_id(1, peer_id, 0, state_spec)
		else:
			match_service.update_player_status(peer_id, 0, state_spec)

	# Create spectator UI overlay
	if _show_overlay:
		_create_overlay()

	# Listen for config reloads
	var cfg2: Node = GameManager.get_core_system("config")
	if cfg2:
		cfg2.config_reloaded.connect(_load_config)


func _load_config(_file_path: String = "") -> void:
	var cfg: Node = GameManager.get_core_system("config")
	if not cfg:
		return

	var cfg_data: Dictionary = cfg.get_value("player_modes.spectator", {})
	if cfg_data.is_empty():
		return

	fly_speed = cfg.get_value("player_modes.spectator.fly_speed", fly_speed)
	mouse_sensitivity = cfg.get_value("player_modes.spectator.mouse_sensitivity", mouse_sensitivity)
	_show_overlay = cfg.get_value("player_modes.spectator.show_overlay", _show_overlay)
	_allow_follow_mode = cfg.get_value(
		"player_modes.spectator.allow_follow_mode", _allow_follow_mode
	)
	_allow_first_person_mode = cfg.get_value(
		"player_modes.spectator.allow_first_person_mode", _allow_first_person_mode
	)
	_allow_free_fly = cfg.get_value("player_modes.spectator.allow_free_fly", _allow_free_fly)


func _create_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 100  # On top of everything
	_overlay.name = "SpectatorOverlay"
	add_child(_overlay)

	# Center container for text
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER_TOP)
	vbox.position = Vector2(0, 50)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.custom_minimum_size = Vector2(400, 0)
	_overlay.add_child(vbox)

	# Title label - "SPECTATOR MODE"
	_title_label = Label.new()
	_title_label.text = "SPECTATOR MODE"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	var title_color: Color = Color(1.0, 0.3, 0.3, 1.0)
	_title_label.add_theme_color_override("font_color", title_color)
	var shadow_color: Color = Color(0, 0, 0, 0.8)
	_title_label.add_theme_color_override("font_shadow_color", shadow_color)
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(_title_label)

	# Target Name Label
	_target_label = Label.new()
	_target_label.text = ""
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.add_theme_font_size_override("font_size", 20)
	_target_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.7))
	vbox.add_child(_target_label)

	# Countdown label - "Respawning in 5..."
	_countdown_label = Label.new()
	_countdown_label.text = ""
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 24)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	_countdown_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_countdown_label.add_theme_constant_override("shadow_offset_x", 2)
	_countdown_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(_countdown_label)

	# Instructions
	var help_label: Label = Label.new()
	var help_text: String = "[TAB] Cycle Targets  •  [SPACE] Toggle Free/Follow"
	help_label.text = help_text + "  •  [V] View Mode (1st/3rd)"
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label.add_theme_font_size_override("font_size", 14)
	help_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.7))
	vbox.add_child(help_label)


## Start the countdown timer (called by player when entering spectator)


func start_countdown(time: float) -> void:
	_respawn_time = time


func _process(delta: float) -> void:
	# Update countdown
	if _respawn_time > 0:
		_respawn_time -= delta
		if _countdown_label:
			var seconds: int = ceili(_respawn_time)
			_countdown_label.text = "Respawning in %d..." % seconds

	if mode != "free":
		_update_target_label()


func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_rotation.x -= motion.relative.y * mouse_sensitivity
		_rotation.y -= motion.relative.x * mouse_sensitivity
		_rotation.x = clamp(_rotation.x, -PI / 2, PI / 2)

	# Tab to cycle players / switch mode
	if event.is_action_pressed("ui_focus_next"):  # Tab key
		_cycle_target()

	# F6 to toggle Editor
	if event is InputEventKey and event.pressed and event.keycode == KEY_F6:
		_toggle_editor()

	# Space to toggle free/follow mode
	if event.is_action_pressed("jump"):
		if mode == "free":
			mode = "follow"
			_update_alive_targets()
		else:
			mode = "free"
			_target_label.text = "Free Fly"

	# V to toggle view (First/Third person)
	var v_pressed: bool = event is InputEventKey and event.pressed and event.keycode == KEY_V
	if v_pressed:
		if mode == "follow":
			mode = "first_person"
		elif mode == "first_person":
			mode = "follow"


func _physics_process(delta: float) -> void:
	if mode == "free":
		_free_fly_movement(delta)
	else:
		_follow_target(delta)

	if mode == "free":
		rotation.y = _rotation.y
		if camera:
			camera.rotation.x = _rotation.x


func _free_fly_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("left", "right", "up", "down")
	var direction: Vector3 = Vector3.ZERO

	direction += global_transform.basis.z * input_dir.y
	direction += global_transform.basis.x * input_dir.x

	# Up/down with jump/crouch
	if Input.is_action_pressed("jump"):
		direction.y += 1.0
	if Input.is_action_pressed("crouch"):
		direction.y -= 1.0

	if direction.length() > 0:
		direction = direction.normalized()

	global_position += direction * fly_speed * delta


func _follow_target(delta: float) -> void:
	_update_alive_targets()

	if alive_targets.is_empty():
		mode = "free"
		return

	follow_index = follow_index % alive_targets.size()
	var target: Node3D = alive_targets[follow_index]

	if is_instance_valid(target):
		var target_pos: Vector3 = target.global_position
		var _look_target: Vector3 = target_pos + Vector3(0, 1.5, 0)

		# Interpolate position for smoothness
		if mode == "first_person":
			# Try to find eye position
			var eye_pos: Vector3 = target_pos + Vector3(0, 1.6, 0)
			# If Player, use standing_camera_height if accessible
			if "standing_camera_height" in target:
				eye_pos = target_pos + Vector3(0, target.standing_camera_height, 0)

			# Snap to eye pos
			global_position = global_position.lerp(eye_pos, delta * 20.0)

			# Match target rotation if possible, otherwise use free look?
			# Usually spec in FPS lets you look around even in body, but better to match view
			# For now, let's allow free look from body position
			rotation.y = _rotation.y
			if camera:
				camera.rotation.x = _rotation.x

		else:  # Third Person Follow
			# Position behind and above
			var _cam_offset: Vector3 = Vector3(0, 2, 3)
			# Rotate offset by camera rotation
			var basis_rot: Basis = Basis.from_euler(Vector3(_rotation.x, _rotation.y, 0))
			var offset: Vector3 = Vector3(0, 1.0, 0) + basis_rot * Vector3(0, 0, 4.0)
			var final_pos: Vector3 = target_pos + offset

			global_position = global_position.lerp(final_pos, delta * 15.0)

			# Look direction controlled by mouse
			rotation.y = _rotation.y
			if camera:
				camera.rotation.x = _rotation.x


func _cycle_target() -> void:
	_update_alive_targets()
	if alive_targets.size() > 1:
		follow_index = (follow_index + 1) % alive_targets.size()

	if mode == "free":
		mode = "follow"


func _update_alive_targets() -> void:
	alive_targets.clear()
	var players: Array = []
	var enemies: Array = []

	# 1. Find Players
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody3D and is_instance_valid(node):
			# Skip self (if somehow included)
			if node.name == str(multiplayer.get_unique_id()):
				continue

			# Check Health
			var is_alive: bool = true
			if "health_component" in node and node.health_component:
				if node.health_component.current_health <= 0:
					is_alive = false
			elif "is_dead" in node and node.is_dead:
				is_alive = false

			if is_alive:
				players.append(node)

	# 2. Find Enemies (if specific request or no players)
	# User wanted to jump between monsters if no player besides server

	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is Node3D and is_instance_valid(node):
			# Check dead state
			if "is_dead" in node and node.is_dead:
				continue
			enemies.append(node)

	# Combine: Players first, then Enemies
	alive_targets.append_array(players)
	alive_targets.append_array(enemies)

	# Auto-switch to first-person when only enemies available (solo server)
	if players.is_empty() and not enemies.is_empty():
		if mode == "follow":
			mode = "first_person"


func _update_target_label() -> void:
	if alive_targets.is_empty():
		_target_label.text = "No Targets"
		return

	if follow_index < alive_targets.size():
		var t: Node = alive_targets[follow_index]
		if is_instance_valid(t):
			var t_name: String = t.name
			# Try to get nicer name
			if t.has_method("get_player_name"):
				t_name = t.get_player_name()
			elif "display_name" in t:
				t_name = t.display_name

			_target_label.text = "Spectating: " + t_name + " (" + mode.capitalize() + ")"


func _toggle_editor() -> void:
	if _editor_instance:
		# Close Editor
		_editor_instance.queue_free()
		_editor_instance = null

		# Restore Spectator
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		set_process(true)
		set_physics_process(true)
		camera.current = true
		if _overlay:
			_overlay.visible = true
	else:
		# Open Editor - FIXED: Check feature tag before attempting to load editor
		# Explicitly block in standalone builds as requested
		if OS.has_feature("standalone"):
			return

		if not OS.has_feature("editor"):
			push_warning("Editor not available in this build - skipping editor toggle")
			return

		var editor_scn: PackedScene = load("res://plugins/editor/editor_runtime.tscn")
		if not editor_scn:
			push_warning("Editor Runtime scene not found - skipping editor toggle")
			return

		_editor_instance = editor_scn.instantiate()
		add_child(_editor_instance)

		# Disable Spectator
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		set_process(false)
		set_physics_process(false)
		if _overlay:
			_overlay.visible = false
