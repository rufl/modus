class_name DummyVisuals
extends Node3D

enum VisualState {
	IDLE,
	WALK,
	RUN,
	JUMP,
	CRAWL,
	HEAL,
	SHOOT,
	MELEE,
	FIGHTING_STANCE,
	PUNCH_LEFT,
	PUNCH_RIGHT,
	HURT,
	DEAD
}

const WALK_SPEED_THRESHOLD: float = 0.1
const RUN_SPEED_THRESHOLD: float = 6.0
const SPRINT_FREQ_MULT: float = 1.6

@export var color: Color = Color(0.5, 0.5, 0.9)

var current_state: VisualState = VisualState.IDLE
var override_state: VisualState = VisualState.IDLE  # For one-shots like Melee
var override_timer: float = 0.0
var fighting_stance_enabled: bool = false  # Toggle for melee combat pose
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var body_pivot: Node3D
var head_mesh: Node3D
var smoothed_speed: float = 0.0

var _base_material: StandardMaterial3D
var _flash_tween: Tween


func _ready() -> void:
	_base_material = StandardMaterial3D.new()
	_base_material.albedo_color = color

	# Create body pivot for bobbing
	body_pivot = Node3D.new()
	add_child(body_pivot)
	body_pivot.name = "BodyPivot"

	# Hips (Center of mass)
	_create_part_local(body_pivot, Vector3(0, 1.0, 0), Vector3(0.4, 0.3, 0.25), _base_material)

	# Torso
	_create_part_local(body_pivot, Vector3(0, 1.45, 0), Vector3(0.4, 0.5, 0.25), _base_material)

	# Head
	head_mesh = _create_part_local(
		body_pivot, Vector3(0, 1.85, 0), Vector3(0.25, 0.25, 0.25), _base_material, true
	)
	head_mesh.name = "Head"

	# Arms (Shoulder height 1.55)
	var shoulder_y: float = 1.55
	left_arm_pivot = _build_limb_hierarchy(
		body_pivot, Vector3(-0.35, shoulder_y, 0), Vector3(-1, 0, 0), _base_material
	)
	right_arm_pivot = _build_limb_hierarchy(
		body_pivot, Vector3(0.35, shoulder_y, 0), Vector3(1, 0, 0), _base_material
	)

	# Legs (Hip height 0.9)
	var hip_y: float = 0.9
	left_leg_pivot = _build_limb_hierarchy(
		body_pivot, Vector3(-0.15, hip_y, 0), Vector3(0, -1, 0), _base_material, true
	)
	right_leg_pivot = _build_limb_hierarchy(
		body_pivot, Vector3(0.15, hip_y, 0), Vector3(0, -1, 0), _base_material, true
	)


func _create_part_local(
	parent: Node, pos: Vector3, size: Vector3, mat: Material, has_face: bool = false
) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	mesh_inst.material_override = mat
	parent.add_child(mesh_inst)
	mesh_inst.position = pos

	if has_face:
		var face := MeshInstance3D.new()
		var f_mesh := BoxMesh.new()
		f_mesh.size = Vector3(0.15, 0.15, 0.05)
		face.mesh = f_mesh
		face.position = Vector3(0, 0, -size.z * 0.5 - 0.01)
		var f_mat := StandardMaterial3D.new()
		f_mat.albedo_color = Color(0.2, 0.2, 0.2)
		face.material_override = f_mat
		mesh_inst.add_child(face)

	return mesh_inst


func _process(delta: float) -> void:
	_update_state_logic(delta)
	_animate_state(delta)
	_animate_head(delta)  # Always track head independently


func _update_state_logic(delta: float) -> void:
	# Decrease override timer
	if override_timer > 0:
		override_timer -= delta
		if override_timer <= 0:
			override_state = VisualState.IDLE  # Reset override

	# 1. Gather Data
	var parent: Node = get_parent()
	if not parent:
		return

	var velocity: Vector3 = Vector3.ZERO
	if "velocity" in parent:
		velocity = parent.velocity

	var is_on_floor: bool = true
	if parent.has_method("is_on_floor"):
		is_on_floor = parent.is_on_floor()

	var speed: float = velocity.length()
	smoothed_speed = lerp(smoothed_speed, speed, 10.0 * delta)

	# 2. Determine State
	if override_state != VisualState.IDLE:
		current_state = override_state
		return

	if not is_on_floor:
		current_state = VisualState.JUMP
	elif fighting_stance_enabled and speed > WALK_SPEED_THRESHOLD:
		# Use fighting stance when moving in combat mode
		current_state = VisualState.FIGHTING_STANCE
	elif speed > RUN_SPEED_THRESHOLD:
		current_state = VisualState.RUN
	elif speed > WALK_SPEED_THRESHOLD:
		current_state = VisualState.WALK
	else:
		if fighting_stance_enabled:
			# Idle in fighting stance
			current_state = VisualState.FIGHTING_STANCE
		else:
			current_state = VisualState.IDLE

	# Check specialized parents props
	if "is_crouching" in parent and parent.is_crouching:
		current_state = VisualState.CRAWL


# --- Public API for Action Triggers ---


func set_fighting_stance(enabled: bool) -> void:
	## Enable/disable fighting stance (both arms up)
	fighting_stance_enabled = enabled


func play_melee() -> void:
	## Play random punch (for backward compatibility)
	if randf() > 0.5:
		play_punch_left()
	else:
		play_punch_right()


func play_punch_left() -> void:
	## Play left arm punch
	override_state = VisualState.PUNCH_LEFT
	override_timer = 0.35  # Snappy punch duration


func play_punch_right() -> void:
	## Play right arm punch
	override_state = VisualState.PUNCH_RIGHT
	override_timer = 0.35  # Snappy punch duration


func play_shoot() -> void:
	override_state = VisualState.SHOOT
	override_timer = 0.2  # Recoil


func play_heal() -> void:
	override_state = VisualState.HEAL
	override_timer = 1.0


func play_hurt() -> void:
	## Play hurt/flinch animation
	override_state = VisualState.HURT
	override_timer = 0.3


func flash(flash_color: Color, duration: float = 0.15) -> void:
	## Flash the enemy a color (RED for damage)
	if not _base_material:
		return

	# Kill any existing flash tween
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	# Set flash color
	_base_material.albedo_color = flash_color

	# Tween back to original color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_base_material, "albedo_color", color, duration).set_ease(
		Tween.EASE_OUT
	)


func set_color(c: Color) -> void:
	color = c
	if _base_material:
		_base_material.albedo_color = c


func apply_tier_effects(tier: int) -> void:
	# Add tier-specific visual flair
	if tier >= 3:  # Elite/Boss
		if _base_material:
			_base_material.emission_enabled = true
			_base_material.emission = color
			_base_material.emission_energy_multiplier = 0.5 if tier == 3 else 1.0


# --- Animation Logic ---


func _animate_state(delta: float) -> void:
	match current_state:
		VisualState.IDLE:
			_anim_idle(delta)
		VisualState.WALK:
			_anim_walk(delta, 1.0)
		VisualState.RUN:
			_anim_walk(delta, SPRINT_FREQ_MULT)  # Run is just fast walk
		VisualState.JUMP:
			_anim_jump(delta)
		VisualState.CRAWL:
			_anim_crawl(delta)
		VisualState.MELEE:
			_anim_melee(delta)
		VisualState.FIGHTING_STANCE:
			_anim_fighting_stance(delta)
		VisualState.PUNCH_LEFT:
			_anim_punch_left(delta)
		VisualState.PUNCH_RIGHT:
			_anim_punch_right(delta)
		VisualState.SHOOT:
			_anim_shoot(delta)
		VisualState.HEAL:
			_anim_heal(delta)
		VisualState.HURT:
			_anim_hurt(delta)
		_:
			_anim_idle(delta)


func _anim_idle(delta: float) -> void:
	_reset_limbs(delta)
	# Breathing bob
	var current_time: float = Time.get_ticks_msec() / 1000.0
	body_pivot.position.y = lerp(body_pivot.position.y, sin(current_time * 2.0) * 0.02, 5.0 * delta)


func _anim_walk(delta: float, freq_mult: float) -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var speed_scale: float = maxf(smoothed_speed, 1.0)  # Ensure minimal movement
	var freq: float = 8.0 * freq_mult  # Constant rhythm

	# Limb swing
	var leg_angle: float = sin(current_time * freq) * 0.8 * min(speed_scale * 0.2, 1.2)
	var arm_angle: float = sin(current_time * freq) * 0.8 * min(speed_scale * 0.2, 1.2)

	_set_limb_rot(left_leg_pivot, leg_angle, delta)
	_set_limb_rot(right_leg_pivot, -leg_angle, delta)
	_set_limb_rot(left_arm_pivot, arm_angle, delta)
	_set_limb_rot(right_arm_pivot, -arm_angle, delta)

	# Bob
	var bob: float = abs(sin(current_time * freq * 2.0)) * 0.1
	body_pivot.position.y = lerp(body_pivot.position.y, bob, 10.0 * delta)


func _anim_jump(delta: float) -> void:
	# Legs up, arms up
	_set_limb_rot(left_leg_pivot, deg_to_rad(-45), delta)
	_set_limb_rot(right_leg_pivot, deg_to_rad(-60), delta)  # Asymmetric
	_set_limb_rot(left_arm_pivot, deg_to_rad(-120), delta)  # Hands up
	_set_limb_rot(right_arm_pivot, deg_to_rad(-120), delta)

	body_pivot.position.y = lerp(body_pivot.position.y, 0.2, 5.0 * delta)


func _anim_crawl(delta: float) -> void:
	# Lower body, splay limbs
	body_pivot.position.y = lerp(body_pivot.position.y, -0.5, 5.0 * delta)
	_anim_walk(delta, 0.5)  # Slow walk


func _anim_melee(delta: float) -> void:
	## Deprecated - use punch_left/right instead
	_anim_punch_right(delta)


func _anim_fighting_stance(delta: float) -> void:
	## Fighting stance - both arms up like a boxer
	# Lower body slightly for crouch
	body_pivot.position.y = lerp(body_pivot.position.y, -0.15, 5.0 * delta)

	# Both arms raised to guard position (shoulder height, bent)
	var guard_angle: float = deg_to_rad(-90)  # Arms up
	_set_limb_rot(left_arm_pivot, guard_angle, delta * 8.0)
	_set_limb_rot(right_arm_pivot, guard_angle, delta * 8.0)

	# Slight breathing bob
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var bob: float = sin(current_time * 3.0) * 0.03
	body_pivot.position.y += bob

	# Keep legs ready
	_set_limb_rot(left_leg_pivot, deg_to_rad(-10), delta)
	_set_limb_rot(right_leg_pivot, deg_to_rad(-10), delta)


func _anim_punch_left(delta: float) -> void:
	## Left arm punch animation
	# Right arm stays in guard
	_set_limb_rot(right_arm_pivot, deg_to_rad(-90), delta * 15.0)

	# Left arm extends forward rapidly
	# Use override_timer for punch progression (starts at 0.35, counts down)
	var punch_progress: float = 1.0 - (override_timer / 0.35)
	var punch_angle: float = lerp(deg_to_rad(-90), deg_to_rad(-160), punch_progress)
	_set_limb_rot(left_arm_pivot, punch_angle, delta * 25.0)  # Fast snap

	# Add slight torso rotation for impact
	body_pivot.rotation.y = lerp(body_pivot.rotation.y, deg_to_rad(15), 20.0 * delta)

	# Crouch stance
	body_pivot.position.y = lerp(body_pivot.position.y, -0.15, 8.0 * delta)


func _anim_punch_right(delta: float) -> void:
	## Right arm punch animation
	# Left arm stays in guard
	_set_limb_rot(left_arm_pivot, deg_to_rad(-90), delta * 15.0)

	# Right arm extends forward rapidly
	var punch_progress: float = 1.0 - (override_timer / 0.35)
	var punch_angle: float = lerp(deg_to_rad(-90), deg_to_rad(-160), punch_progress)
	_set_limb_rot(right_arm_pivot, punch_angle, delta * 25.0)  # Fast snap

	# Add slight torso rotation for impact (opposite direction)
	body_pivot.rotation.y = lerp(body_pivot.rotation.y, deg_to_rad(-15), 20.0 * delta)

	# Crouch stance
	body_pivot.position.y = lerp(body_pivot.position.y, -0.15, 8.0 * delta)


func _anim_shoot(delta: float) -> void:
	# Arms point forward
	_set_limb_rot(left_arm_pivot, deg_to_rad(-80), delta * 15.0)
	_set_limb_rot(right_arm_pivot, deg_to_rad(-90), delta * 15.0)
	# Recoil handled by head/body?


func _anim_heal(delta: float) -> void:
	# Arms glow/raise
	_set_limb_rot(left_arm_pivot, deg_to_rad(-150), delta)
	_set_limb_rot(right_arm_pivot, deg_to_rad(-150), delta)
	# Maybe spin?


func _anim_hurt(delta: float) -> void:
	## Hurt/flinch animation - body recoils back
	# Lean back
	var flinch_t: float = override_timer / 0.3  # 0 to 1
	var lean_angle: float = deg_to_rad(-20) * flinch_t

	# Apply lean to body
	body_pivot.rotation.x = lerp(body_pivot.rotation.x, lean_angle, 15.0 * delta)

	# Arms go up defensively
	_set_limb_rot(left_arm_pivot, deg_to_rad(-60), delta * 20.0)
	_set_limb_rot(right_arm_pivot, deg_to_rad(-60), delta * 20.0)


func _reset_limbs(delta: float) -> void:
	_set_limb_rot(left_leg_pivot, 0.0, delta)
	_set_limb_rot(right_leg_pivot, 0.0, delta)
	_set_limb_rot(left_arm_pivot, 0.0, delta)
	_set_limb_rot(right_arm_pivot, 0.0, delta)


func _set_limb_rot(node: Node3D, x_angle: float, delta: float) -> void:
	if node:
		node.rotation.x = lerp(node.rotation.x, x_angle, 10.0 * delta)


# --- Head Logic (Preserved) ---


func _animate_head(delta: float) -> void:
	if not head_mesh:
		return
	var parent: Node = get_parent()
	if not parent:
		return

	var target_pos: Vector3 = Vector3.ZERO
	var has_target: bool = false

	if "ai_controller" in parent and parent.ai_controller:
		var ai: Node = parent.ai_controller
		if "target" in ai and ai.target:
			target_pos = ai.target.global_position
			has_target = true

	if not has_target and "velocity" in parent:
		var vel: Vector3 = parent.velocity
		if vel.length_squared() > 0.1:
			target_pos = head_mesh.global_position + vel.normalized() * 5.0
			has_target = true

	if has_target:
		var to_target: Vector3 = (target_pos - head_mesh.global_position).normalized()
		if abs(to_target.dot(Vector3.UP)) > 0.99:
			return

		# Safety check: ensure Basis is valid before converting to Quaternion
		var current_basis: Basis = head_mesh.global_transform.basis
		if abs(current_basis.determinant()) < 0.001:
			return  # Invalid basis, skip this frame

		var current_rot: Quaternion = current_basis.get_rotation_quaternion()
		var look_t: Transform3D = head_mesh.global_transform.looking_at(target_pos, Vector3.UP)

		if abs(look_t.basis.determinant()) < 0.001:
			return  # Invalid basis, skip this frame

		var target_rot: Quaternion = look_t.basis.get_rotation_quaternion()
		var new_rot: Quaternion = current_rot.slerp(target_rot, 5.0 * delta)

		var parent_basis: Basis = body_pivot.global_transform.basis
		if abs(parent_basis.determinant()) < 0.001:
			return  # Invalid basis, skip this frame

		var local_qs: Quaternion = parent_basis.inverse().get_rotation_quaternion() * new_rot
		var local_euler: Vector3 = local_qs.get_euler()

		local_euler.y = clamp(local_euler.y, deg_to_rad(-80), deg_to_rad(80))
		local_euler.x = clamp(local_euler.x, deg_to_rad(-60), deg_to_rad(60))
		local_euler.z = 0
		head_mesh.rotation = local_euler
	else:
		head_mesh.rotation = head_mesh.rotation.lerp(Vector3.ZERO, 5.0 * delta)


func _build_limb_hierarchy(
	parent: Node, pos: Vector3, dir: Vector3, mat: Material, is_leg: bool = false
) -> Node3D:
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.position = pos

	var upper_len: float = 0.5 if is_leg else 0.4
	var width: float = 0.15
	var u_size: Vector3 = (
		Vector3(width, upper_len, width) if is_leg else Vector3(upper_len, width, width)
	)
	var offset: Vector3
	if is_leg:
		offset = Vector3(0, -upper_len * 0.5, 0)
	else:
		offset = dir * (upper_len * 0.5)

	_create_part_local(pivot, offset, u_size, mat)
	return pivot
