class_name ProceduralRagdoll
extends Node3D

const RagdollPartScript = preload("res://game/entities/enemies/dummy/ragdoll_part.gd")

@export var color: Color = Color(0.8, 0.2, 0.2)

var parts: Dictionary = {}  # Name -> RigidBody3D
var joints: Dictionary = {}  # Child Part Name -> Joint (The joint holding this part)


func _ready() -> void:
	_build_ragdoll()

	# Auto cleanup
	get_tree().create_timer(30.0).timeout.connect(queue_free, CONNECT_ONE_SHOT)


func on_part_hit(part: RigidBody3D, info_or_damage: Variant) -> void:
	var dmg: float = 0.0
	var hit_pos: Vector3 = part.global_position
	var bullet_dir: Vector3 = Vector3.ZERO
	var p_id: String = part.get("part_id") if part.get("part_id") else ""

	# Parse damage info
	if info_or_damage is DamageInfo:
		dmg = info_or_damage.base_amount
		hit_pos = info_or_damage.hit_position
		bullet_dir = info_or_damage.knockback_direction
	else:
		dmg = float(info_or_damage)

	# 1. Spawn Blood Spray
	var effects_service: Node = GameManager.get_core_system("effects")
	if effects_service and effects_service.has_method("spawn_gore_effect"):
		# Spawn a small blood hit
		effects_service.spawn_gore_effect(hit_pos, bullet_dir, 0.5)

	# 2. Check for Dismemberment (Threshold: > 15 damage)
	if dmg > 15.0:
		_dismember_part(part, bullet_dir * 2.0)

	# 3. Check for Torso Gibbing (Overkill: > 50 damage on Torso)
	if p_id == "Torso" and dmg > 50.0:
		_gib_everything(bullet_dir)


func _dismember_part(part: RigidBody3D, impulse: Vector3) -> void:
	var p_id: String = part.get("part_id") if part.get("part_id") else ""

	# Don't dismember Hips (Root) or Torso (unless gibbing)
	if p_id == "Hips" or p_id == "Torso":
		return

	if joints.has(p_id):
		var joint: Joint3D = joints[p_id]
		if is_instance_valid(joint):
			joint.queue_free()
			joints.erase(p_id)

			# Add impulse to severed limb
			part.apply_central_impulse(impulse)

			# Spawn extra blood/gibs at joint
			var effects_service: Node = GameManager.get_core_system("effects")
			if effects_service:
				effects_service.spawn_gore_effect(part.global_position, impulse.normalized(), 1.0)


func _gib_everything(dir: Vector3) -> void:
	# Trigger gib effects
	var effects_service: Node = GameManager.get_core_system("effects")
	if effects_service:
		effects_service.spawn_gore_effect(global_position, dir, 2.0)  # High intensity

	# Destroy ragdoll
	queue_free()


func _build_ragdoll() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color

	# Root offset (Hips)
	parts["hips"] = _create_part("Hips", Vector3(0, 1.0, 0), Vector3(0.4, 0.3, 0.25), mat)

	# Torso (Spine Joint - Limited Cone)
	parts["torso"] = _create_part("Torso", Vector3(0, 1.45, 0), Vector3(0.4, 0.5, 0.25), mat)
	_create_joint(parts["hips"], parts["torso"], Vector3(0, 1.2, 0), "Torso", "cone")

	# Head (Neck - Limited Cone)
	parts["head"] = _create_part("Head", Vector3(0, 1.85, 0), Vector3(0.25, 0.25, 0.25), mat)
	_create_joint(parts["torso"], parts["head"], Vector3(0, 1.7, 0), "Head", "cone")

	# Arms
	_build_limb("LeftArm", Vector3(-0.35, 1.5, 0), Vector3(-1, 0, 0), mat)
	_build_limb("RightArm", Vector3(0.35, 1.5, 0), Vector3(1, 0, 0), mat)

	# Legs
	_build_limb("LeftLeg", Vector3(-0.15, 0.8, 0), Vector3(0, -1, 0), mat, true)
	_build_limb("RightLeg", Vector3(0.15, 0.8, 0), Vector3(0, -1, 0), mat, true)


func _build_limb(
	prefix: String, h_pos: Vector3, dir: Vector3, mat: Material, is_leg: bool = false
) -> void:
	var upper_len: float = 0.5 if is_leg else 0.4
	var width: float = 0.15
	var u_pos: Vector3
	var u_size: Vector3 = (
		Vector3(width, upper_len, width) if is_leg else Vector3(upper_len, width, width)
	)

	# Upper
	if is_leg:
		u_pos = h_pos + Vector3(0, -upper_len * 0.5, 0)
	else:
		u_pos = h_pos + (dir * (upper_len * 0.5))

	var upper: RigidBody3D = _create_part(prefix + "Upper", u_pos, u_size, mat)
	var parent_body: RigidBody3D = parts["hips"] if is_leg else parts["torso"]

	# Shoulder/Hip: Cone Joint
	_create_joint(parent_body, upper, h_pos, prefix + "Upper", "cone")

	# Lower
	var lower_len: float = 0.5 if is_leg else 0.4
	var knee_pos: Vector3
	var l_pos: Vector3
	var l_size: Vector3 = u_size

	if is_leg:
		knee_pos = u_pos + Vector3(0, -upper_len * 0.5, 0)
		l_pos = knee_pos + Vector3(0, -lower_len * 0.5, 0)
	else:
		knee_pos = u_pos + (dir * (upper_len * 0.5))
		l_pos = knee_pos + (dir * (lower_len * 0.5))

	var lower: RigidBody3D = _create_part(prefix + "Lower", l_pos, l_size, mat)

	# Knee/Elbow: Hinge Joint
	# Hinge Axis (Local Z) defaults to World Z.
	# Knee bends around X axis -> Rotate joint 90 deg around Y -> Z becomes X.
	# Elbow bends around Y axis (Forward) -> Rotate joint -90 deg around X -> Z becomes Y.
	var hinge_rot: Vector3
	if is_leg:
		hinge_rot = Vector3(0, 90, 0)
	else:
		hinge_rot = Vector3(-90, 0, 0)

	_create_joint(upper, lower, knee_pos, prefix + "Lower", "hinge", hinge_rot)

	parts[prefix + "Upper"] = upper
	parts[prefix + "Lower"] = lower


func _create_part(part_name: String, pos: Vector3, size: Vector3, mat: Material) -> RigidBody3D:
	var body: RigidBody3D = RagdollPartScript.new()
	body.name = part_name
	body.set("root", self)
	body.set("part_id", part_name)

	add_child(body)
	body.position = pos

	body.collision_layer = CollisionLayers.LAYER_DEBRIS
	body.collision_mask = CollisionLayers.LAYER_WORLD

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	return body


func _create_joint(
	body_a: RigidBody3D,
	body_b: RigidBody3D,
	pos: Vector3,
	child_name: String = "",
	type: String = "pin",
	rot: Vector3 = Vector3.ZERO
) -> void:
	var joint: Joint3D

	if type == "cone":
		var cone := ConeTwistJoint3D.new()
		cone.swing_span = deg_to_rad(45)
		cone.twist_span = deg_to_rad(15)  # Minimal twist
		joint = cone
	elif type == "hinge":
		var hinge := HingeJoint3D.new()
		hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(0))  # Straight
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(-120))  # Bend back
		joint = hinge
	else:
		joint = PinJoint3D.new()  # Fallback

	add_child(joint)
	joint.position = pos
	if rot != Vector3.ZERO:
		joint.rotation_degrees = rot

	joint.node_a = body_a.get_path()
	joint.node_b = body_b.get_path()

	if child_name != "":
		joints[child_name] = joint


# --- Compatibility API for Enemy.gd ---


func setup(_mesh: Mesh, _trans: Transform3D, _color: Color) -> void:
	color = _color
	# Update all existing parts with new color
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color

	for key: Variant in parts:
		var body: RigidBody3D = parts[key]
		for child in body.get_children():
			if child is MeshInstance3D:
				child.material_override = mat


func apply_central_impulse(impulse: Vector3) -> void:
	if parts.has("torso"):
		parts["torso"].apply_central_impulse(impulse)


func apply_torque_impulse(torque: Vector3) -> void:
	if parts.has("torso"):
		parts["torso"].apply_torque_impulse(torque)
