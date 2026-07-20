class_name RopeMovementComponent
extends GameComponent

const ROPE_CLIMB_SPEED: float = 4.0
const ROPE_SWING_FORCE: float = 20.0
const ROPE_JUMP_OFF_FORCE: float = 12.0

var is_active: bool = false
var can_grab: bool = false

var _player: CharacterBody3D
var _camera: Camera3D
var _current_rope: Node3D = null
var _current_rope_segment_index: int = -1
var _available_rope_ref: Node3D = null  # The rope we are touching
var _available_rope_segment: RigidBody3D = null
var _rope_cooldown: float = 0.0  # Timer to prevent instant re-grab


func setup(player: CharacterBody3D, camera: Camera3D) -> void:
	_player = player
	_camera = camera


func process_physics(delta: float) -> void:
	if _rope_cooldown > 0:
		_rope_cooldown -= delta

	if not is_active:
		return

	if _current_rope_segment_index == -1:
		detach_from_rope()
		return

	# 1. Position Snapping (Stick to current segment)
	if not _current_rope or not _current_rope.segments:
		detach_from_rope()
		return

	var seg: RigidBody3D = _current_rope.segments[_current_rope_segment_index]
	if not is_instance_valid(seg):
		detach_from_rope()
		return

	# Match position + offset (hang slightly below/centered)
	var target_pos: Vector3 = seg.global_position - Vector3(0, 0.5, 0)
	_player.global_position = _player.global_position.lerp(target_pos, 20.0 * delta)

	# 2. Climbing (Switch Segments)
	if Input.is_action_just_pressed("move_forward"):  # W = Climb Up
		if _current_rope_segment_index > 0:
			_current_rope_segment_index -= 1
	elif Input.is_action_just_pressed("move_backward"):  # S = Climb Down
		if _current_rope_segment_index < _current_rope.segments.size() - 1:
			_current_rope_segment_index += 1

	# 3. Swinging (Add force to segment)
	var swing_input: float = Input.get_axis("move_left", "move_right")
	if abs(swing_input) > 0.1:
		# Force direction: Camera Right * input
		var force_dir: Vector3 = _camera.global_transform.basis.x * swing_input
		if _current_rope.has_method("apply_swing_force"):
			_current_rope.apply_swing_force(force_dir)

	# 4. Jump Off
	if Input.is_action_just_pressed("jump"):
		# Calculate launch vector
		# Velocity of rope + Jump Up + Look Direction
		var rope_vel: Vector3 = seg.linear_velocity
		var look_dir: Vector3 = _camera.global_transform.basis.z * -1.0  # Forward
		var jump_vec: Vector3 = (
			(Vector3.UP * 0.8 + look_dir * 0.5).normalized() * ROPE_JUMP_OFF_FORCE
		)

		detach_from_rope(rope_vel + jump_vec)


func set_available_rope(rope: Node3D, segment: RigidBody3D) -> void:
	# Called by Rope Area3D body_entered
	_available_rope_ref = rope
	_available_rope_segment = segment


func clear_available_rope(rope: Node3D) -> void:
	if _available_rope_ref == rope:
		_available_rope_ref = null
		_available_rope_segment = null


func attach_to_rope() -> void:
	if is_active or _rope_cooldown > 0:
		return
	if not _available_rope_ref:
		return

	var rope: Node3D = _available_rope_ref
	var segment: RigidBody3D = _available_rope_segment

	if not rope.segments.has(segment):
		return

	_current_rope = rope
	_current_rope_segment_index = rope.segments.find(segment)

	# Snap to rope
	_player.velocity = Vector3.ZERO
	# _player.is_climbing = true # Handled by is_active property + Player checking it

	# Notify rope
	if rope.has_method("attach_player"):
		rope.attach_player(_player, segment)

	# Animation
	if _player.anim_player:
		_player.anim_player.play("Idle")


func detach_from_rope(impulse: Vector3 = Vector3.ZERO) -> void:
	if not is_active:
		return

	# Notify rope
	if _current_rope.has_method("detach_player"):
		_current_rope.detach_player(_player)

	_current_rope = null
	_current_rope_segment_index = -1
	# _player.is_climbing = false

	# Apply launch
	_player.velocity = impulse

	# Cooldown
	_rope_cooldown = 0.5
