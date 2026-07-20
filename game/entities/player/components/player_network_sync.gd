class_name PlayerNetworkSync
extends GameComponent

const REMOTE_INTERP_SPEED: float = 12.0

var _player: CharacterBody3D
var _camera: Camera3D
var _target_position: Vector3 = Vector3.ZERO
var _target_rotation_y: float = 0.0
var _target_camera_rotation_x: float = 0.0
var _is_remote: bool = false


func setup(player: CharacterBody3D, camera: Camera3D, is_remote_player: bool) -> void:
	_player = player
	_camera = camera
	_is_remote = is_remote_player

	if _is_remote:
		_target_position = _player.global_position
		_target_rotation_y = _player.rotation.y
		if _camera:
			_target_camera_rotation_x = _camera.rotation.x


func process_interpolation(delta: float) -> void:
	## Smooth interpolation for remote players (eliminates rubberbanding)
	if not _is_remote:
		return

	# If we have a dedicated RemoteInterpolator component, it handles physics interpolation
	# We only need manual lerp if that component is missing.
	var interpolator: Node = _player.get_node_or_null("RemoteInterpolator")
	if interpolator:
		return

	# Smoothly interpolate to target position (Fallback)
	_player.global_position = _player.global_position.lerp(
		_target_position, REMOTE_INTERP_SPEED * delta
	)

	# Smoothly interpolate rotation (use lerp_angle for proper wrapping)
	_player.rotation.y = lerp_angle(
		_player.rotation.y, _target_rotation_y, REMOTE_INTERP_SPEED * delta
	)

	# Smoothly interpolate camera rotation
	if _camera:
		_camera.rotation.x = lerp_angle(
			_camera.rotation.x, _target_camera_rotation_x, REMOTE_INTERP_SPEED * delta
		)


# === SETTERS (Called by Player sync properties) ===


func set_target_position(value: Vector3) -> void:
	if _is_remote:
		_target_position = value
	else:
		_player.global_position = value


func set_target_rotation(value: Vector3) -> void:
	if _is_remote:
		_target_rotation_y = value.y
	else:
		_player.rotation = value


func set_target_camera_rotation(value: float) -> void:
	if _is_remote:
		_target_camera_rotation_x = value
	else:
		if _camera:
			_camera.rotation.x = value


# === STATE SYNC ===


func sync_movement_state(crouching: bool, sprinting: bool) -> void:
	# Applied directly to player state variables
	# Note: This requires Player to expose these vars or methods
	if _player.get("is_crouching") != null:
		_player.is_crouching = crouching
	if _player.get("is_sprinting") != null:
		_player.is_sprinting = sprinting
