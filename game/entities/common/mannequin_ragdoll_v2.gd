class_name MannequinRagdollV2
extends Node3D
## Refactored ragdoll system with improved physics and stability
## Based on Godot 4.7+ best practices and community research

const MANNEQUIN_GLB_PATH: String = "res://game/art/models/mannequin_mesh.glb"
const RagdollPartScript: Script = preload(
	"res://game/entities/enemies/dummy/physical_ragdoll_part.gd"
)
const GIB_THRESHOLD: float = 50.0
const CLEANUP_TIME: float = 30.0

signal blood_effect_requested(position: Vector3, direction: Vector3, intensity: float)

@export var color: Color = Color(0.5, 0.5, 0.9)
@export var enable_dismemberment: bool = true

var skeleton: Skeleton3D
var physical_bone_simulator: PhysicalBoneSimulator3D
var physical_bones: Dictionary = {}  # BoneName -> PhysicalBone3D
var _is_simulation_active: bool = false
var _pending_impulse: Dictionary = {}


func _ready() -> void:
	_load_mannequin()

	# Auto cleanup after timeout
	get_tree().create_timer(CLEANUP_TIME).timeout.connect(queue_free, CONNECT_ONE_SHOT)


func setup(_mesh: Mesh, _trans: Transform3D, _color: Color) -> void:
	## Setup ragdoll with custom color
	color = _color
	if skeleton:
		_apply_color(skeleton.get_parent(), color)


func apply_death_impulse(direction: Vector3, force: float, spin: Vector3 = Vector3.ZERO) -> void:
	## Apply death impulse to ragdoll - queues impulse if simulation not ready
	# Store impulse for application after simulation starts
	_pending_impulse = {"direction": direction, "force": force, "spin": spin}

	# If simulation is already active, apply immediately
	if _is_simulation_active:
		_apply_stored_impulse()


func apply_central_impulse(impulse: Vector3) -> void:
	## Apply central impulse to torso
	var target: PhysicalBone3D = _get_torso_bone()
	if target:
		target.apply_central_impulse(impulse)


func apply_torque_impulse(torque: Vector3) -> void:
	## Apply torque impulse to torso
	var target: PhysicalBone3D = _get_torso_bone()
	if target:
		_apply_angular_impulse(target, torque)


func _apply_angular_impulse(bone: PhysicalBone3D, torque: Vector3) -> void:
	# PhysicalBone3D no longer exposes apply_torque_impulse in Godot 4.7.
	bone.angular_velocity += torque / maxf(bone.mass, 0.001)


func _get_torso_bone() -> PhysicalBone3D:
	## Get the primary torso bone for impulse application
	for bone_name: String in ["Spine1", "Spine", "Hips"]:
		if physical_bones.has(bone_name):
			return physical_bones[bone_name]
	return null


func _load_mannequin() -> void:
	## Load mannequin model and setup ragdoll
	if not ResourceLoader.exists(MANNEQUIN_GLB_PATH):
		push_error("[MannequinRagdollV2] GLB not found: %s" % MANNEQUIN_GLB_PATH)
		return

	var scene: PackedScene = load(MANNEQUIN_GLB_PATH)
	if not scene:
		push_error("[MannequinRagdollV2] Failed to load GLB!")
		return

	var instance: Node3D = scene.instantiate()
	add_child(instance)
	instance.rotation.y = PI

	# Find skeleton
	skeleton = _find_skeleton(instance)
	if not skeleton:
		push_error("[MannequinRagdollV2] No skeleton found!")
		return

	# Apply color tint
	_apply_color(instance, color)

	# Create PhysicalBoneSimulator3D node
	_setup_physical_bone_simulator()

	# Generate physical bones under the simulator in Godot 4.7.
	_generate_physical_bones()

	# Start simulation on next frame (allows physics to initialize)
	call_deferred("_start_simulation")


func _find_skeleton(node: Node) -> Skeleton3D:
	## Recursively find Skeleton3D node
	if node is Skeleton3D:
		return node
	for child: Node in node.get_children():
		var result: Skeleton3D = _find_skeleton(child)
		if result:
			return result
	return null


func _setup_physical_bone_simulator() -> void:
	## Create and configure PhysicalBoneSimulator3D
	physical_bone_simulator = PhysicalBoneSimulator3D.new()
	physical_bone_simulator.name = "PhysicalBoneSimulator"
	skeleton.add_child(physical_bone_simulator)


func _start_simulation() -> void:
	## Start ragdoll physics simulation
	if not skeleton or not is_instance_valid(skeleton):
		return

	if not physical_bone_simulator or not is_instance_valid(physical_bone_simulator):
		return

	# Start simulation using PhysicalBoneSimulator3D
	physical_bone_simulator.physical_bones_start_simulation()
	_is_simulation_active = true

	# Apply any pending impulse
	if not _pending_impulse.is_empty():
		# Wait one more frame for physics to fully initialize
		await get_tree().process_frame
		_apply_stored_impulse()


func _apply_stored_impulse() -> void:
	## Apply stored death impulse to ragdoll
	if _pending_impulse.is_empty():
		return

	var direction: Vector3 = _pending_impulse.get("direction", Vector3.ZERO)
	var force: float = _pending_impulse.get("force", 0.0)
	var spin: Vector3 = _pending_impulse.get("spin", Vector3.ZERO)

	# Apply realistic force scaling
	var realistic_force: float = force * 0.6
	var main_impulse: Vector3 = direction * realistic_force

	# Clamp maximum impulse
	var max_impulse: float = 25.0
	if main_impulse.length() > max_impulse:
		main_impulse = main_impulse.normalized() * max_impulse

	# Apply to primary bones (torso)
	var primary_bones: Array[String] = ["Spine1", "Spine", "Hips"]
	for bone_name: String in primary_bones:
		if physical_bones.has(bone_name):
			var bone: PhysicalBone3D = physical_bones[bone_name]
			bone.apply_central_impulse(main_impulse)
			if spin != Vector3.ZERO:
				_apply_angular_impulse(bone, spin * 0.2)

	# Apply to secondary bones (limbs) with reduced force
	var secondary_bones: Array[String] = ["Head", "LeftArm", "RightArm", "LeftUpLeg", "RightUpLeg"]
	for bone_name: String in secondary_bones:
		if physical_bones.has(bone_name):
			var bone: PhysicalBone3D = physical_bones[bone_name]
			var limb_impulse: Vector3 = main_impulse * 0.5
			bone.apply_central_impulse(limb_impulse)
			if spin != Vector3.ZERO:
				_apply_angular_impulse(bone, spin * 0.15)

	# Clear pending impulse
	_pending_impulse.clear()


func _apply_color(node: Node, c: Color) -> void:
	## Apply color tint to all mesh instances
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = c
	_recursive_apply_mat(node, mat)


func _recursive_apply_mat(node: Node, mat: Material) -> void:
	## Recursively apply material to mesh instances
	if node is MeshInstance3D:
		node.material_override = mat
	for child: Node in node.get_children():
		_recursive_apply_mat(child, mat)


func _generate_physical_bones() -> void:
	## Generate physical bones with improved configuration
	if not skeleton:
		return

	# Bone configuration with sizes and joint types
	var bone_config: Dictionary = {
		"Hips":
		{
			"size": Vector3(0.3, 0.2, 0.2),
			"mass": 25.0,
			"joint_type": PhysicalBone3D.JOINT_TYPE_CONE,
			"swing_span": 15.0,
			"twist_span": 20.0
		},
		"Spine":
		{
			"size": Vector3(0.3, 0.3, 0.2),
			"mass": 10.0,
			"joint_type": PhysicalBone3D.JOINT_TYPE_CONE,
			"swing_span": 10.0,
			"twist_span": 5.0
		},
		"Spine1":
		{
			"size": Vector3(0.35, 0.4, 0.25),
			"mass": 10.0,
			"joint_type": PhysicalBone3D.JOINT_TYPE_CONE,
			"swing_span": 10.0,
			"twist_span": 5.0
		},
		"Head":
		{
			"size": Vector3(0.25, 0.25, 0.25),
			"mass": 5.0,
			"joint_type": PhysicalBone3D.JOINT_TYPE_CONE,
			"swing_span": 35.0,
			"twist_span": 45.0
		},
		"LeftArm":
		{
			"size": Vector3(0.1, 0.3, 0.1),
			"mass": 4.0,
			"joint_type": PhysicalBone3D.JOINT_TYPE_CONE,
			"swing_span": 80.0,
			"twist_span": 40.0
		},
		"LeftForeArm":
		{
			"size": Vector3(0.09, 0.3, 0.09),
			"mass": 2.5,
			"joint_type": PhysicalBone3D.JOINT_TYPE_HINGE,
			"angular_limit_lower": -140.0,
			"angular_limit_upper": 0.0
		},
		"RightArm":
		{
			"size": Vector3(0.1, 0.3, 0.1),
			"mass": 4.0,
			"joint_type": PhysicalBone3D.JOINT_TYPE_CONE,
			"swing_span": 80.0,
			"twist_span": 40.0
		},
		"RightForeArm":
		{
			"size": Vector3(0.09, 0.3, 0.09),
			"mass": 2.5,
			"joint_type": PhysicalBone3D.JOINT_TYPE_HINGE,
			"angular_limit_lower": -140.0,
			"angular_limit_upper": 0.0
		},
		"LeftUpLeg":
		{
			"size": Vector3(0.15, 0.4, 0.15),
			"mass": 10.0,
			"joint_type": PhysicalBone3D.JOINT_TYPE_CONE,
			"swing_span": 60.0,
			"twist_span": 25.0
		},
		"LeftLeg":
		{
			"size": Vector3(0.12, 0.4, 0.12),
			"mass": 5.0,
			"joint_type": PhysicalBone3D.JOINT_TYPE_HINGE,
			"angular_limit_lower": 0.0,
			"angular_limit_upper": 140.0
		},
		"RightUpLeg":
		{
			"size": Vector3(0.15, 0.4, 0.15),
			"mass": 10.0,
			"joint_type": PhysicalBone3D.JOINT_TYPE_CONE,
			"swing_span": 60.0,
			"twist_span": 25.0
		},
		"RightLeg":
		{
			"size": Vector3(0.12, 0.4, 0.12),
			"mass": 5.0,
			"joint_type": PhysicalBone3D.JOINT_TYPE_HINGE,
			"angular_limit_lower": 0.0,
			"angular_limit_upper": 140.0
		},
	}

	for bone_name: String in bone_config:
		_create_physical_bone(bone_name, bone_config[bone_name])


func _create_physical_bone(bone_name: String, config: Dictionary) -> void:
	## Create a single physical bone with configuration
	var skeleton_bone_name: String = get_skeleton_bone_name(bone_name)
	var bone_idx: int = skeleton.find_bone(skeleton_bone_name)
	if bone_idx == -1:
		return

	var pb: PhysicalBone3D = PhysicalBone3D.new()
	pb.bone_name = skeleton_bone_name
	pb.name = "PB_" + bone_name

	# Add collision shape
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = config.get("size", Vector3(0.2, 0.2, 0.2))
	col.shape = shape
	pb.add_child(col)

	# Physics properties
	pb.collision_layer = CollisionLayers.LAYER_DEBRIS
	pb.collision_mask = CollisionLayers.LAYER_WORLD

	# PhysicalBone3D exposes contact material values directly in Godot 4.7.
	pb.bounce = 0.05  # Minimal bounce
	pb.friction = 0.9  # High friction

	# Mass
	pb.mass = config.get("mass", 2.0)

	# Damping - CRITICAL for natural motion
	pb.linear_damp = 0.02  # Minimal linear damping
	pb.angular_damp = 0.1  # Controlled angular damping
	pb.gravity_scale = 1.0  # Full gravity

	# Joint configuration
	pb.joint_type = config.get("joint_type", PhysicalBone3D.JOINT_TYPE_CONE)

	# Configure joint limits based on type
	if pb.joint_type == PhysicalBone3D.JOINT_TYPE_CONE:
		pb.set("joint_constraints/swing_span", deg_to_rad(config.get("swing_span", 45.0)))
		pb.set("joint_constraints/twist_span", deg_to_rad(config.get("twist_span", 30.0)))
	elif pb.joint_type == PhysicalBone3D.JOINT_TYPE_HINGE:
		pb.set(
			"joint_constraints/angular_limit_lower",
			deg_to_rad(config.get("angular_limit_lower", -90.0))
		)
		pb.set(
			"joint_constraints/angular_limit_upper",
			deg_to_rad(config.get("angular_limit_upper", 90.0))
		)

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

	# Add to skeleton
	physical_bone_simulator.add_child(pb)
	physical_bones[bone_name] = pb

	# Attach damage handling script
	pb.set_script(RagdollPartScript)
	pb.set("root", self)
	pb.set("part_id", bone_name)


func get_skeleton_bone_name(part_id: String) -> String:
	return MannequinBoneMap.resolve(skeleton, part_id)


# --- Gibbing and Dismemberment ---


func on_part_hit(part: PhysicsBody3D, info_or_damage: Variant) -> void:
	## Handle damage to ragdoll part
	if not enable_dismemberment:
		return

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

	# Spawn blood effect
	var blood_direction: Vector3 = bullet_dir * -1.0
	blood_effect_requested.emit(hit_pos, blood_direction, 0.5)
	var effects: Node = GameManager.get_core_system("effects")
	if effects and effects.has_method("spawn_blood_synced"):
		effects.spawn_blood_synced(hit_pos, blood_direction, 0.5)

	# Check for torso gibbing (total explosion)
	if p_id in ["Torso", "Spine", "Spine1", "Hips"] and dmg > GIB_THRESHOLD:
		_explode_into_parts(hit_pos, bullet_dir)
		return

	# Check for dismemberment
	if dmg > 15.0:
		_dismember_limb(p_id, bullet_dir)


func _explode_into_parts(hit_origin: Vector3, force_dir: Vector3) -> void:
	## Explode ragdoll into gibs
	var effects: Node = GameManager.get_core_system("effects")
	if not effects or not effects.has_method("spawn_limb_gib"):
		queue_free()
		return

	# Explode all physical parts
	for bone_name: String in physical_bones:
		# Skip if already dismembered
		var bone_idx: int = skeleton.find_bone(get_skeleton_bone_name(bone_name))
		if bone_idx != -1:
			var bone_scale: Vector3 = skeleton.get_bone_pose_scale(bone_idx)
			if bone_scale.length_squared() < 0.01:
				continue

		var pb: PhysicalBone3D = physical_bones[bone_name]
		var pos: Vector3 = pb.global_position

		# Calculate launch direction
		var dir: Vector3 = (pos - hit_origin).normalized()
		var launch_dir: Vector3 = (dir + force_dir * 0.5 + Vector3.UP * 0.5).normalized()

		effects.spawn_limb_gib(pos, bone_name, color, launch_dir)

	# Final blood cloud
	if effects.has_method("spawn_blood_synced"):
		effects.spawn_blood_synced(global_position, Vector3.UP, 2.0)

	queue_free()


func _dismember_limb(bone_name: String, impulse: Vector3) -> void:
	## Dismember a single limb
	var bone_idx: int = skeleton.find_bone(get_skeleton_bone_name(bone_name))
	if bone_idx == -1:
		return

	# Scale bone to zero to hide it
	skeleton.set_bone_pose_scale(bone_idx, Vector3.ZERO)

	# Spawn limb gib
	var effects: Node = GameManager.get_core_system("effects")
	if effects and effects.has_method("spawn_limb_gib"):
		var bone_xform: Transform3D = skeleton.get_bone_global_pose(bone_idx)
		var global_pos: Vector3 = skeleton.to_global(bone_xform.origin)
		var launch_dir: Vector3 = (impulse + Vector3.UP * 2.0).normalized()
		effects.spawn_limb_gib(global_pos, bone_name, color, launch_dir)
	elif effects and effects.has_method("spawn_gore_effect"):
		# Fallback to generic gore
		var bone_xform: Transform3D = skeleton.get_bone_global_pose(bone_idx)
		var global_pos: Vector3 = skeleton.to_global(bone_xform.origin)
		effects.spawn_gore_effect(global_pos, impulse, 1.0)
