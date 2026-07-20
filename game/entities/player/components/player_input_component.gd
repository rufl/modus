class_name PlayerInputComponent
extends GameComponent

signal interact_pressed
signal skill_tree_toggled
signal inventory_toggled
signal melee_pressed
signal weapon_switch_requested(index: int)
signal quick_switch_requested
signal flashlight_toggled
signal pause_toggled

@export var mouse_sensitivity: float = 0.005
@export var controller_sensitivity: float = 0.020

var move_vector: Vector2 = Vector2.ZERO
var start_sprinting: bool = false
var is_sprinting: bool = false
var is_crouching: bool = false
var wish_jump: bool = false
var wish_shoot: bool = false
var wish_reload: bool = false
var last_input_time: float = 0.0
var camera: Camera3D

var _mouse_mode_captured: bool = false


## Helper method for safe debug logging
func _log_debug(message: String) -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("debug"):
		logger.debug(message, "PlayerInput")


func _ready() -> void:
	_log_debug("_ready() called")

	# CRITICAL: Set process mode to ALWAYS so we can detect input state changes
	# even when the game is paused (e.g., welcome screen, pause menu)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Disable input accumulation for lower latency/smoother mouse feel
	# See: https://yosoyfreeman.github.io/article/godot/tutorial/
	#      achieving-better-mouse-input-in-godot-4-the-perfect-camera-controller/
	Input.use_accumulated_input = false

	# CRITICAL: Initialize mouse capture state from actual Input.mouse_mode
	# This ensures we start with the correct state even if set before _ready()
	_mouse_mode_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_log_debug("_ready() complete - initial mouse_captured: %s" % _mouse_mode_captured)


func setup(p_camera: Camera3D) -> void:
	camera = p_camera
	_log_debug("setup() called with camera: %s" % p_camera)
	# Initialize mouse mode (deferred to ensure window is ready)
	# This fixes "Parameter 'pointed_win' is null" errors on Wayland
	set_mouse_captured.call_deferred(true)


func _input(event: InputEvent) -> void:
	if not _is_local_authority():
		return

	# Sync mouse capture state
	_mouse_mode_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	# Handle pause input even when paused or mouse not captured
	if event.is_action_pressed("pause"):
		pause_toggled.emit()
		return

	if get_tree().paused:
		return
	if not _mouse_mode_captured:
		return

	last_input_time = Time.get_ticks_msec() / 1000.0

	# Camera Mode Toggle (C key) - Changed from V to avoid conflict with melee
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		var player: Node = get_parent()
		if player:
			# Use CameraComponent (refactored name)
			if player.has_node("CameraComponent"):
				var cam_comp: Node = player.get_node("CameraComponent")
				if cam_comp.has_method("cycle_camera_mode"):
					cam_comp.cycle_camera_mode()
					var logger: Node = GameManager.get_core_system("logger")
					if logger:
						logger.info("[Input] Camera mode cycled", "Player")
			else:
				var logger: Node = GameManager.get_core_system("logger")
				if logger:
					logger.info("[Input] CameraComponent not found", "Player")

	# Music Controls (PageUp / PageDown)
	if event is InputEventKey and event.pressed and not event.echo:
		var player: Node = get_parent()
		if player and player.has_node("CameraComponent"):
			var cam_comp: Node = player.get_node("CameraComponent")
			if event.keycode == KEY_PAGEUP:
				if cam_comp.has_method("play_next_song"):
					cam_comp.play_next_song()
			elif event.keycode == KEY_PAGEDOWN:
				if cam_comp.has_method("play_prev_song"):
					cam_comp.play_prev_song()

	# Mouse Look

	if event is InputEventMouseMotion and _mouse_mode_captured:
		if camera:
			# Correct for viewport stretch/scaling to keep sensitivity consistent
			var viewport_transform: Transform2D = get_tree().root.get_final_transform()
			var corrected_relative: Vector2 = event.xformed_by(viewport_transform).relative
			_apply_mouse_look(corrected_relative)

	# Actions not handled by _physics_process polling
	if event.is_action_pressed("interact"):
		interact_pressed.emit()

	if event.is_action_pressed("inventory"):
		inventory_toggled.emit()

	if event.is_action_pressed("skill_tree"):
		skill_tree_toggled.emit()

	if event.is_action_pressed("melee"):
		melee_pressed.emit()

	if event.is_action_pressed("quick_weapon_switch"):
		quick_switch_requested.emit()

	if InputMap.has_action("flashlight") and event.is_action_pressed("flashlight"):
		flashlight_toggled.emit()

	# Weapon Switching (1-9)
	for i in range(1, 10):
		var action_name: String = "weapon_%d" % i
		if InputMap.has_action(action_name) and event.is_action_pressed(action_name):
			weapon_switch_requested.emit(i - 1)


func _physics_process(_delta: float) -> void:
	if not _is_local_authority():
		return

	# CRITICAL: Always sync mouse capture state with actual Input.mouse_mode
	# This ensures we detect when mouse is captured by welcome screen or other systems
	_mouse_mode_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	# Debug: Print state every 60 frames (once per second at 60fps)
	if Engine.get_frames_drawn() % 60 == 0:
		_log_debug(
			(
				"_physics_process - mouse_captured: %s | paused: %s | Input.mouse_mode: %s"
				% [_mouse_mode_captured, get_tree().paused, Input.mouse_mode]
			)
		)

	# Allow pause input even when paused or mouse not captured
	# This is handled in _input() method

	if get_tree().paused:
		return

	if not _mouse_mode_captured:
		return

	# Poll Continous Inputs
	move_vector = Input.get_vector("left", "right", "up", "down")
	if move_vector != Vector2.ZERO:
		last_input_time = Time.get_ticks_msec() / 1000.0
		# Debug movement input
		if Engine.get_frames_drawn() % 60 == 0:
			_log_debug("Movement input: %s" % move_vector)

	# Poll Continous Inputs

	wish_jump = Input.is_action_pressed("jump")
	is_crouching = Input.is_action_pressed("crouch")
	is_sprinting = Input.is_action_pressed("sprint")
	wish_shoot = Input.is_action_pressed("shoot")
	wish_reload = Input.is_action_pressed("reload")

	# Controller Look
	var joy_look: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if joy_look.length() > 0:
		if camera:
			_apply_controller_look(joy_look)


func _apply_mouse_look(relative: Vector2) -> void:
	var player: Node = get_parent()
	if not player or not player is CharacterBody3D:
		return

	# Rotate Body Y (Yaw)
	player.rotate_y(-relative.x * mouse_sensitivity)
	player.orthonormalize()

	# Rotate Camera X (Pitch)
	if camera:
		camera.rotate_x(-relative.y * mouse_sensitivity)
		# Slightly reduced clamp to prevent gimbal lock feeling (89 degrees instead of 90)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		camera.orthonormalize()


func _apply_controller_look(vector: Vector2) -> void:
	var player: Node = get_parent()
	if not player or not player is CharacterBody3D:
		return

	var look_step: Vector2 = vector * controller_sensitivity

	# Rotate Body Y
	player.rotate_y(-look_step.x)

	# Rotate Camera X
	camera.rotate_x(-look_step.y)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))


func set_mouse_captured(captured: bool) -> void:
	_mouse_mode_captured = captured
	var mode_str: String = "CAPTURED" if captured else "VISIBLE"
	_log_debug("set_mouse_captured(%s) - Setting Input.mouse_mode to: %s" % [captured, mode_str])
	if captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Returns combined fire input state


func get_fire_input() -> Dictionary:
	var mouse_captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var just_pressed: bool = Input.is_action_just_pressed("shoot") and mouse_captured
	return {"is_pressed": wish_shoot, "just_pressed": just_pressed}


## Check if this is the local player's input component
func _is_local_authority() -> bool:
	var player: Node = get_parent()
	if player and player.has_method("is_multiplayer_authority"):
		# In multiplayer, use the player's authority
		if multiplayer.has_multiplayer_peer():
			return player.is_multiplayer_authority()
		# In single player, always return true
		return true
	# Fallback: if no multiplayer peer, assume local authority
	return not multiplayer.has_multiplayer_peer()
