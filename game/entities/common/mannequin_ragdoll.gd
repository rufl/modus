class_name MannequinRagdoll
extends Node3D

const MANNEQUIN_GLB_PATH: String = "res://game/art/models/mannequin_mesh.glb"
const RagdollPartScript = preload(
	"res://game/entities/enemies/dummy/physical_ragdoll_part.gd"
)
const GIB_THRESHOLD: float = 50.0

signal blood_effect_requested(position: Vector3, direction: Vector3, intensity: float)

@export var color: Color = Color(0.5, 0.5, 0.9)

var skeleton: Skeleton3D
var physical_bone_simulator: PhysicalBoneSimulator3D
var physical_bones: Dictionary = {}  # BoneName -> PhysicalBone3D
var _is_simulation_active: bool = false
var _pending_impulse: Dictionary = {}


func _ready() -> void:
	_load_mannequin()

	# Auto cleanup
	get_tree().create_timer(30.0).timeout.connect(queue_free, CONNECT_ONE_SHOT)


func setup(_mesh: Mesh, _trans: Transform3D, _color: Color) -> void:
	color = _color
	# Re-apply color if mannequin is already loaded
	if skeleton:
		_apply_color(skeleton.get_parent(), color)


func apply_central_impulse(impulse: Vector3) -> void:
	var target: PhysicalBone3D = null
	if physical_bones.has("Spine"):
		target = physical_bones["Spine"]
	elif physical_bones.has("Hips"):
		target = physical_bones["Hips"]
	elif physical_bones.has("Torso"):
		target = physical_bones["Torso"]

	if target:
		target.apply_central_impulse(impulse)


func apply_torque_impulse(torque: Vector3) -> void:
	var target: PhysicalBone3D = null
	if physical_bones.has("Spine"):
		target = physical_bones["Spine"]
	elif physical_bones.has("Hips"):
		target = physical_bones["Hips"]

	if target:
		_apply_angular_impulse(target, torque)


func _apply_angular_impulse(bone: PhysicalBone3D, torque: Vector3) -> void:
	# PhysicalBone3D no longer exposes apply_torque_impulse in Godot 4.7.
	# Convert the impulse to an angular-velocity delta using the configured mass.
	bone.angular_velocity += torque / maxf(bone.mass, 0.001)


func apply_death_impulse(direction: Vector3, force: float, spin: Vector3 = Vector3.ZERO) -> void:
	## Realistic death impulse - Half-Life 2 / Painkiller / Bulletstorm style
	## Bodies should fly naturally with weight, not float like balloons
	_pending_impulse = {"direction": direction, "force": force, "spin": spin}
	if _is_simulation_active:
		_apply_pending_impulse()


func _apply_pending_impulse() -> void:
	if _pending_impulse.is_empty():
		return

	var direction: Vector3 = _pending_impulse.get("direction", Vector3.ZERO)
	var force: float = _pending_impulse.get("force", 0.0)
	var spin: Vector3 = _pending_impulse.get("spin", Vector3.ZERO)

	# Use realistic force scaling - bodies have mass and should react accordingly
	var realistic_force: float = force * 0.6  # Moderate scaling for natural motion
	var main_impulse: Vector3 = direction * realistic_force

	# Clamp maximum impulse to prevent unrealistic flying
	var max_impulse: float = 25.0  # Reasonable limit for heavy bodies
	if main_impulse.length() > max_impulse:
		main_impulse = main_impulse.normalized() * max_impulse

	# Apply to multiple bones for distributed, natural motion
	var primary_bones: Array[String] = ["Spine", "Hips", "Spine1"]
	var secondary_bones: Array[String] = ["Head", "LeftArm", "RightArm", "LeftUpLeg", "RightUpLeg"]

	# Primary impact on torso (main force)
	for bone_name in primary_bones:
		if physical_bones.has(bone_name):
			var bone: PhysicalBone3D = physical_bones[bone_name]
			bone.apply_central_impulse(main_impulse)
			if spin != Vector3.ZERO:
				# Moderate spin for natural rotation
				_apply_angular_impulse(bone, spin * 0.2)

	# Secondary impact on limbs (follow naturally)
	for bone_name in secondary_bones:
		if physical_bones.has(bone_name):
			var bone: PhysicalBone3D = physical_bones[bone_name]
			# Limbs follow the body naturally
			var limb_impulse: Vector3 = main_impulse * 0.5
			bone.apply_central_impulse(limb_impulse)
			if spin != Vector3.ZERO:
				_apply_angular_impulse(bone, spin * 0.15)

	_pending_impulse.clear()


func _load_mannequin() -> void:
	if not ResourceLoader.exists(MANNEQUIN_GLB_PATH):
		push_error("[MannequinRagdoll] GLB not found!")
		return

	var scene: PackedScene = load(MANNEQUIN_GLB_PATH)
	if not scene:
		push_error("[MannequinRagdoll] Failed to load GLB!")
		return

	var instance: Node3D = scene.instantiate()
	add_child(instance)
	instance.rotation.y = PI

	# Find skeleton
	skeleton = _find_skeleton(instance)
	if not skeleton:
		push_error("[MannequinRagdoll] No skeleton found!")
		return

	# Tint materials
	_apply_color(instance, color)

	# Godot 4.7 owns PhysicalBone3D nodes through a simulator child.
	physical_bone_simulator = PhysicalBoneSimulator3D.new()
	physical_bone_simulator.name = "PhysicalBoneSimulator"
	skeleton.add_child(physical_bone_simulator)

	# Generate Physical Bones
	_generate_physical_bones()

	# Start Simulation - must be deferred to allow physics setup
	call_deferred("_start_simulation")


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var res: Skeleton3D = _find_skeleton(child)
		if res:
			return res
	return null


func _start_simulation() -> void:
	if physical_bone_simulator and is_instance_valid(physical_bone_simulator):
		physical_bone_simulator.physical_bones_start_simulation()
		_is_simulation_active = true
		# The bodies register after simulation starts in Godot 4.7. Preserve
		# impulses requested during spawn until that registration completes.
		await get_tree().process_frame
		_apply_pending_impulse()


func _apply_color(node: Node, c: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c

	_recursive_apply_mat(node, mat)


func _recursive_apply_mat(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_recursive_apply_mat(child, mat)


func _generate_physical_bones() -> void:
	if not skeleton:
		return

	# Define bone chains to physicalize
	var config: Dictionary = {
		"Hips": {"size": Vector3(0.3, 0.2, 0.2)},
		"Spine": {"size": Vector3(0.3, 0.3, 0.2)},
		"Spine1": {"size": Vector3(0.35, 0.4, 0.25)},
		"Head": {"size": Vector3(0.25, 0.25, 0.25)},
		"LeftArm": {"size": Vector3(0.1, 0.3, 0.1)},
		"LeftForeArm": {"size": Vector3(0.09, 0.3, 0.09)},
		"RightArm": {"size": Vector3(0.1, 0.3, 0.1)},
		"RightForeArm": {"size": Vector3(0.09, 0.3, 0.09)},
		"LeftUpLeg": {"size": Vector3(0.15, 0.4, 0.15)},
		"LeftLeg": {"size": Vector3(0.12, 0.4, 0.12)},
		"RightUpLeg": {"size": Vector3(0.15, 0.4, 0.15)},
		"RightLeg": {"size": Vector3(0.12, 0.4, 0.12)},
	}

	for bone_name: String in config:
		_create_physical_bone(bone_name, config[bone_name].size)


func _create_physical_bone(bone_name: String, size: Vector3) -> void:
	var skeleton_bone_name: String = get_skeleton_bone_name(bone_name)
	var bone_idx: int = skeleton.find_bone(skeleton_bone_name)
	if bone_idx == -1:
		return

	var pb := PhysicalBone3D.new()
	pb.bone_name = skeleton_bone_name
	pb.name = "PB_" + bone_name

	# Add collision shape
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	pb.add_child(col)

	# Realistic physics properties (HL2/Painkiller/Bulletstorm style)
	pb.collision_layer = CollisionLayers.LAYER_DEBRIS
	pb.collision_mask = CollisionLayers.LAYER_WORLD

	# PhysicalBone3D exposes contact material values directly in Godot 4.7.
	pb.bounce = 0.05  # Minimal bounce - bodies are solid, not bouncy
	pb.friction = 0.9  # High friction - bodies don't slide unrealistically

	# Realistic mass distribution - HEAVY bodies that feel solid
	# Updated mass values for proper momentum transfer and natural physics
	match bone_name:
		"Head":
			pb.mass = 5.0  # Realistic head weight (~5kg)
		"Hips":
			pb.mass = 25.0  # Concentrates most body mass
		"Spine", "Spine1":
			pb.mass = 10.0  # Torso mass distributed across spine segments
		"LeftArm", "RightArm":
			pb.mass = 4.0  # Upper arms
		"LeftForeArm", "RightForeArm":
			pb.mass = 2.5  # Forearms
		"LeftUpLeg", "RightUpLeg":
			pb.mass = 10.0  # Upper legs are heavy
		"LeftLeg", "RightLeg":
			pb.mass = 5.0  # Lower legs
		_:
			pb.mass = 2.0  # Default weight

	# CRITICAL: Low damping for natural ballistic motion (Half-Life 2 style)
	# Bodies should fly through the air naturally, then settle realistically
	pb.linear_damp = 0.02  # Minimal damping - natural ballistic motion
	pb.angular_damp = 0.1  # Controlled rotation without killing momentum

	# CRITICAL: Enable gravity for ragdoll parts
	pb.gravity_scale = 1.0  # Ensure gravity is enabled

	# CRITICAL: Add joint constraints for human-like movement
	# Tight constraints prevent "deflated beach toy" effect
	pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE

	# Configure joint limits based on bone type for solid, humanoid movement
	match bone_name:
		"Head":
			# Neck - limited but natural rotation
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.set("joint_constraints/swing_span", deg_to_rad(35))
			pb.set("joint_constraints/twist_span", deg_to_rad(45))

		"LeftArm", "RightArm":
			# Shoulders - moderate range but constrained
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.set("joint_constraints/swing_span", deg_to_rad(80))
			pb.set("joint_constraints/twist_span", deg_to_rad(40))

		"LeftForeArm", "RightForeArm":
			# Elbows - hinge joint, can only bend one way
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
			pb.set("joint_constraints/angular_limit_lower", deg_to_rad(-140))
			pb.set("joint_constraints/angular_limit_upper", deg_to_rad(0))

		"LeftUpLeg", "RightUpLeg":
			# Hips - moderate range, prevents excessive splits
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.set("joint_constraints/swing_span", deg_to_rad(60))
			pb.set("joint_constraints/twist_span", deg_to_rad(25))

		"LeftLeg", "RightLeg":
			# Knees - hinge joint, forward bend only
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
			pb.set("joint_constraints/angular_limit_lower", deg_to_rad(0))
			pb.set("joint_constraints/angular_limit_upper", deg_to_rad(140))

		"Spine", "Spine1":
			# Spine - TIGHTER constraints for structural rigidity (prevents collapse)
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.set("joint_constraints/swing_span", deg_to_rad(10))  # Reduced from 15° to 10°
			pb.set("joint_constraints/twist_span", deg_to_rad(5))  # Reduced from 10° to 5°

		"Hips":
			# Hips - root, tighter constraints to prevent excessive movement
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.set("joint_constraints/swing_span", deg_to_rad(15))  # Reduced from 25° to 15°
			pb.set("joint_constraints/twist_span", deg_to_rad(20))

	# Godot 4.7 exposes joint stabilization through bias/softness/relaxation.
	if pb.joint_type == PhysicalBone3D.JOINT_TYPE_CONE:
		pb.set("joint_constraints/bias", 0.6)
		pb.set("joint_constraints/softness", 0.9)
		pb.set("joint_constraints/relaxation", 1.0)
	elif pb.joint_type == PhysicalBone3D.JOINT_TYPE_HINGE:
		pb.set("joint_constraints/angular_limit_enabled", true)
		pb.set("joint_constraints/angular_limit_bias", 0.6)
		pb.set("joint_constraints/angular_limit_softness", 0.9)
		pb.set("joint_constraints/angular_limit_relaxation", 1.0)

	physical_bone_simulator.add_child(pb)
	physical_bones[bone_name] = pb

	# Bind script to handle damage
	pb.set_script(RagdollPartScript)
	pb.set("root", self)
	pb.set("part_id", bone_name)


func get_skeleton_bone_name(part_id: String) -> String:
	return MannequinBoneMap.resolve(skeleton, part_id)


# --- Gibbing Logic ---


func on_part_hit(part: PhysicsBody3D, info_or_damage: Variant) -> void:
	var dmg: float = 0.0
	var hit_pos: Vector3 = part.global_position
	var bullet_dir: Vector3 = Vector3.ZERO
	var p_id: String = part.get("part_id") if part.get("part_id") else ""

	if info_or_damage is DamageInfo:
		dmg = info_or_damage.base_amount
		hit_pos = info_or_damage.hit_position
		bullet_dir = info_or_damage.knockback_direction
	else:
		dmg = float(info_or_damage)

	# Spawn Blood (Only blood, no generic gibs)
	var blood_direction: Vector3 = bullet_dir * -1.0
	blood_effect_requested.emit(hit_pos, blood_direction, 0.5)
	var effects: Node = GameManager.get_core_system("effects")
	if effects and effects.has_method("spawn_blood_synced"):
		effects.spawn_blood_synced(hit_pos, blood_direction, 0.5)

	# Check for Overkill (Torso Gibbing = Total Explosion)
	if p_id in ["Torso", "Spine", "Spine1", "Hips"] and dmg > GIB_THRESHOLD:
		_explode_into_parts(hit_pos, bullet_dir)
		return

	# Check for Dismemberment
	if dmg > 15.0:
		_dismember_limb(p_id, bullet_dir)


func _explode_into_parts(hit_origin: Vector3, force_dir: Vector3) -> void:
	var effects: Node = GameManager.get_core_system("effects")
	if not effects or not effects.has_method("spawn_limb_gib"):
		queue_free()
		return

	# Explode all physical parts
	for bone_name: String in physical_bones:
		# check if already dismembered to avoid duplicates?
		# Actually, physical_bones exists in raqdoll. Disabling them hides them.
		# If we are exploding, we spawn everything remaining.

		# Skip if hidden/disabled (already dismembered)
		var bone_idx: int = skeleton.find_bone(get_skeleton_bone_name(bone_name))
		if bone_idx != -1:
			var bone_scale: Vector3 = skeleton.get_bone_pose_scale(bone_idx)
			if bone_scale.length_squared() < 0.01:
				continue  # Already gone

		var pb: PhysicalBone3D = physical_bones[bone_name]
		var pos: Vector3 = pb.global_position

		# Calculate launch direction
		var dir: Vector3 = (pos - hit_origin).normalized()
		# Blend with impact force
		var launch_dir: Vector3 = (dir + force_dir * 0.5 + Vector3.UP * 0.5).normalized()

		effects.spawn_limb_gib(pos, bone_name, color, launch_dir)

	# Final blood cloud
	if effects.has_method("spawn_blood_synced"):
		effects.spawn_blood_synced(global_position, Vector3.UP, 2.0)

	queue_free()


func _dismember_limb(bone_name: String, impulse: Vector3) -> void:
	# For visual dismemberment on a single mesh, we can scale the bone to 0.
	var bone_idx: int = skeleton.find_bone(get_skeleton_bone_name(bone_name))
	if bone_idx != -1:
		skeleton.set_bone_pose_scale(bone_idx, Vector3.ZERO)

		# Spawn high-fidelity mannequin limb gib
		var effects: Node = GameManager.get_core_system("effects")
		if effects and effects.has_method("spawn_limb_gib"):
			var bone_xform: Transform3D = skeleton.get_bone_global_pose(bone_idx)
			var global_pos: Vector3 = skeleton.to_global(bone_xform.origin)
			# Find a good launch direction
			var launch_dir: Vector3 = (impulse + Vector3.UP * 2.0).normalized()
			effects.spawn_limb_gib(global_pos, bone_name, color, launch_dir)
		else:
			# Fallback to generic gore
			var bone_xform: Transform3D = skeleton.get_bone_global_pose(bone_idx)
			var global_pos: Vector3 = skeleton.to_global(bone_xform.origin)
			if effects:
				effects.spawn_gore_effect(global_pos, impulse, 1.0)
