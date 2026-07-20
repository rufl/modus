class_name PlayerCameraComponent
extends GameComponent

var standing_height: float = 1.6
var crouching_height: float = 1.0
var transition_speed: float = 10.0
var look_down_lean: float = 0.15  # GTA6 Trick: Move camera forward when looking down to clear chest
var strafe_roll: float = 0.02  # Cinematic camera bank when strafing

var _player: Player
var _camera: Camera3D
var _mouse_captured: bool = false

enum CameraMode { FIRST_PERSON, THIRD_PERSON }
var current_mode: CameraMode = CameraMode.FIRST_PERSON
var tp_distance: float = 3.0
var target_tp_distance: float = 3.0

signal camera_mode_changed(new_mode: int)


func _log(message: String, category: String = "PlayerCameraComponent") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info(message, category)
	else:
		print(message)


func setup(player: Player, camera: Camera3D) -> void:
	_player = player
	_camera = camera

	# Initial Setup - in single player (no peer), always setup for local player
	var is_local: bool = (
		not multiplayer.has_multiplayer_peer() or _player.is_multiplayer_authority()
	)
	if is_local:
		# Use a dedicated initialization function with a delay
		# We must use call_deferred to ensure this runs after the current frame
		call_deferred("_init_mouse_mode_async")


func _init_mouse_mode_async() -> void:
	# Wait for window to be fully ready (especially on Wayland)
	if not is_inside_tree():
		return

	await get_tree().process_frame
	await get_tree().process_frame

	var is_local: bool = (
		_player and (not multiplayer.has_multiplayer_peer() or _player.is_multiplayer_authority())
	)
	if is_local:
		_log("[Camera] Initializing mouse capture (async)", "Player")
		_ensure_mouse_captured()


func _input(event: InputEvent) -> void:
	var is_local: bool = (
		not _player
		or (not multiplayer.has_multiplayer_peer() or _player.is_multiplayer_authority())
	)
	if not is_local:
		return
	if get_tree().paused:
		return

	# Capture mouse on click if lost
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_ensure_mouse_captured()
			return  # Consume this click so we don't shoot immediately upon capturing


func cycle_camera_mode() -> void:
	if current_mode == CameraMode.FIRST_PERSON:
		current_mode = CameraMode.THIRD_PERSON
	else:
		current_mode = CameraMode.FIRST_PERSON

	camera_mode_changed.emit(current_mode)
	_log("[Camera] Switched to mode: " + str(current_mode), "Player")

	# Update FirstPersonBodyShader if it exists
	if _player.has_node("FirstPersonBodyShader"):
		var fp_shader := _player.get_node("FirstPersonBodyShader")
		fp_shader.set_first_person_mode(current_mode == CameraMode.FIRST_PERSON)


func _process(delta: float) -> void:
	var is_local: bool = (
		not _player
		or (not multiplayer.has_multiplayer_peer() or _player.is_multiplayer_authority())
	)
	if not is_local:
		return
	if get_tree().paused:
		return

	if current_mode == CameraMode.FIRST_PERSON:
		_update_camera_height(delta)
	else:
		_update_third_person(delta)

	# Keep checking capture state in case Alt-Tab or Menu lost it
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_captured = true
	else:
		_mouse_captured = false


func _update_camera_height(delta: float) -> void:
	if not _camera:
		return

	var target_h: float = standing_height
	if _player.is_crouching:
		target_h = crouching_height

	# GTA6 Trick: Dynamic Forward Offset
	var pitch: float = _camera.rotation.x
	var target_z: float = 0.0
	if pitch > 0:  # Looking down
		target_z = -sin(pitch) * look_down_lean

	# Standard smooth transition logic (Standing / Crouching)
	_camera.position.y = lerp(_camera.position.y, target_h, delta * transition_speed)
	_camera.position.z = lerp(_camera.position.z, target_z, delta * transition_speed)

	# Strafe Roll (Cinematic Banking)
	var local_vel: Vector3 = _player.global_transform.basis.inverse() * _player.velocity
	var target_roll: float = -local_vel.x * strafe_roll

	_camera.rotation.z = lerp(_camera.rotation.z, target_roll, delta * transition_speed)


func _update_third_person(delta: float) -> void:
	if not _camera:
		return

	# Position camera behind player
	var target_h: float = standing_height
	if _player.is_crouching:
		target_h = crouching_height

	# Basic collision check for third person
	var space_state := _player.get_world_3d().direct_space_state
	var offset := Vector3(0, target_h, 0)

	var back_dir := _camera.global_transform.basis.z.normalized()

	var query := PhysicsRayQueryParameters3D.create(
		_player.global_position + offset,
		_player.global_position + offset + back_dir * target_tp_distance,
		1  # World layer
	)
	query.exclude = [_player.get_rid()]

	var result := space_state.intersect_ray(query)
	var actual_dist := target_tp_distance
	if not result.is_empty():
		actual_dist = (_player.global_position + offset).distance_to(result.position) - 0.2

	tp_distance = lerp(tp_distance, actual_dist, delta * transition_speed)

	var tp_offset: Vector3 = (Vector3.BACK * tp_distance).rotated(Vector3.RIGHT, _camera.rotation.x)
	_camera.position = Vector3(0, target_h, 0) + tp_offset


func play_next_song() -> void:
	if (
		GameManager.get_core_system("audio")
		and GameManager.get_core_system("audio").has_method("play_next_track")
	):
		GameManager.get_core_system("audio").play_next_track()
		_log("[Camera] Song skipped (Page Up)", "Player")


func play_prev_song() -> void:
	if (
		GameManager.get_core_system("audio")
		and GameManager.get_core_system("audio").has_method("play_previous_track")
	):
		GameManager.get_core_system("audio").play_previous_track()
		_log("[Camera] Song previous (Page Down)", "Player")


func _ensure_mouse_captured() -> void:
	if _player.is_dead:
		return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true
