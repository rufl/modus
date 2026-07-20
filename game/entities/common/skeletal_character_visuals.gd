class_name SkeletalCharacterVisuals
extends Node3D

## Clean skeletal character visuals system
## Built entirely around the mannequin GLB - no legacy code

const MANNEQUIN_PATH := "res://game/art/models/mannequin_mesh.glb"
const ANIM_LIBRARY_PATH := "res://game/art/anims/AnimationLibrary_Godot.glb"

@export var character_color: Color = Color(0.5, 0.5, 0.9)

# Alias property for backwards compatibility with dismemberment system
var color: Color:
	get:
		return character_color
	set(value):
		character_color = value
		_apply_color()

var mannequin_root: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var dismemberment_controller: DismembermentController


## Compatibility mapping retained for callers that used the pre-extraction API.
func _get_anim_mapping() -> Dictionary:
	return {
		"idle": "Idle",
		"walk": "Walk",
		"run": "Jog_Fwd",
		"crouch_idle": "Crouch_Idle",
		"jump": "Jump",
		"death": "Death01",
		"pistol_idle": "Pistol_Idle",
		"pistol_shoot": "Pistol_Shoot",
		"pistol_reload": "Pistol_Reload",
	}


## Return the canonical mannequin bone aliases without requiring model import.
func _create_bone_mapping() -> Dictionary:
	return {
		"head": "DEF-head",
		"neck": "DEF-spine.004",
		"spine": "DEF-spine.003",
		"left_hand": "DEF-hand.L",
		"right_hand": "DEF-hand.R",
		"left_foot": "DEF-foot.L",
		"right_foot": "DEF-foot.R",
	}


# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info(message, category)
			return
	print("[%s] %s" % [category, message])


func _ready() -> void:
	_load_mannequin()
	_setup_animations()
	_setup_dismemberment()
	_apply_color()

	# Debug: Check visibility and setup
	_log("[SkeletalVisuals] Ready complete:")
	_log(
		(
			"  - mannequin_root: "
			+ str(mannequin_root)
			+ " visible: "
			+ (str(mannequin_root.visible) if mannequin_root else "N/A")
		)
	)
	_log(
		(
			"  - skeleton: "
			+ str(skeleton)
			+ " bones: "
			+ (str(skeleton.get_bone_count()) if skeleton else "N/A")
		)
	)
	_log(
		(
			"  - anim_player: "
			+ str(anim_player)
			+ " active: "
			+ (str(anim_player.active) if anim_player else "N/A")
		)
	)

	# Play idle animation by default
	call_deferred("_play_default_animation")


## Load the mannequin model and find its skeleton
func _load_mannequin() -> bool:
	if not ResourceLoader.exists(MANNEQUIN_PATH):
		push_error("[SkeletalVisuals] Mannequin not found: %s" % MANNEQUIN_PATH)
		return false

	var scene: PackedScene = load(MANNEQUIN_PATH)
	mannequin_root = scene.instantiate()
	add_child(mannequin_root)

	# NOTE: Mannequin scale adjustment
	# If mannequins are invisible, the scale might be wrong
	# Try: 1.0 (no scale), 0.1 (10x reduction), 0.01 (100x reduction)
	# Default: 1.0 (use model's original scale)
	mannequin_root.scale = Vector3(1.0, 1.0, 1.0)

	# Fix model orientation - mannequin faces backwards by default
	mannequin_root.rotation_degrees.y = 180

	# Find skeleton in the instantiated scene
	skeleton = _find_node_by_type(mannequin_root, Skeleton3D)
	if not skeleton:
		push_error("[SkeletalVisuals] No Skeleton3D found in mannequin")
		return false

	_log("[SkeletalVisuals] Loaded skeleton with %d bones" % skeleton.get_bone_count())

	# Debug: Check skeleton height to determine if scaling is needed
	var head_idx := skeleton.find_bone("DEF-head")
	if head_idx != -1:
		var head_pose := skeleton.get_bone_global_pose(head_idx)
		var head_height := head_pose.origin.y
		_log("[SkeletalVisuals] Head bone height: %.2f units" % head_height)
		_log("[SkeletalVisuals] Recommended scale for 1.7m character: %.4f" % (1.7 / head_height))
	else:
		_log("[SkeletalVisuals] Could not find head bone for height measurement")

	# CRITICAL: Ensure all MeshInstance3D nodes reference the skeleton
	var meshes := _find_all_nodes_by_type(mannequin_root, MeshInstance3D)
	for mesh_inst in meshes:
		if mesh_inst.skeleton.is_empty():
			# Set skeleton path relative to the mesh
			mesh_inst.skeleton = mesh_inst.get_path_to(skeleton)
			_log("[SkeletalVisuals] Set skeleton path for mesh: " + " " + str(mesh_inst.name))

	return true


## Setup animations from the animation library
func _setup_animations() -> void:
	if not skeleton:
		return

	# Create AnimationPlayer
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	skeleton.add_child(anim_player)

	# CRITICAL: Set root node so animation tracks resolve correctly
	# Tracks are like "Rig/Skeleton3D:bone_name", and we need to point to the parent
	# that contains both Rig and Skeleton3D
	anim_player.root_node = anim_player.get_path_to(mannequin_root)

	# Ensure AnimationPlayer is active
	anim_player.active = true
	anim_player.speed_scale = 1.0

	# Load animation library
	if not ResourceLoader.exists(ANIM_LIBRARY_PATH):
		push_warning("[SkeletalVisuals] Animation library not found: %s" % ANIM_LIBRARY_PATH)
		return

	var loaded_resource: Resource = load(ANIM_LIBRARY_PATH)

	# Check if it's a PackedScene or AnimationLibrary
	if loaded_resource is PackedScene:
		var anim_scene: PackedScene = loaded_resource
		var anim_root: Node = anim_scene.instantiate()
		var source_player: AnimationPlayer = _find_node_by_type(anim_root, AnimationPlayer)

		if source_player:
			# Copy all animation libraries
			for lib_name in source_player.get_animation_library_list():
				var lib: AnimationLibrary = source_player.get_animation_library(lib_name)
				if lib:
					anim_player.add_animation_library(lib_name, lib)
					_log(
						(
							"Loaded animation library: %s with %d animations"
							% [lib_name, lib.get_animation_list().size()]
						)
					)

		anim_root.queue_free()

	elif loaded_resource is AnimationLibrary:
		# Direct AnimationLibrary resource
		anim_player.add_animation_library("", loaded_resource)
		_log(
			(
				"Loaded animation library with %d animations"
				% loaded_resource.get_animation_list().size()
			)
		)
	else:
		push_error("[SkeletalVisuals] Unexpected resource type: %s" % loaded_resource.get_class())

	# Create AnimationTree for blending
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	skeleton.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)

	# Setup animation tree for upper/lower body blending
	_setup_animation_tree()

	_log(
		(
			"AnimationPlayer setup complete - active: "
			+ " "
			+ str(anim_player.active)
			+ " "
			+ " speed: "
			+ " "
			+ str(anim_player.speed_scale)
			+ " "
			+ " root_node: "
			+ " "
			+ str(anim_player.root_node)
		)
	)


## Setup animation tree for upper/lower body blending
func _setup_animation_tree() -> void:
	if not anim_tree or not skeleton:
		return

	_log("[SkeletalVisuals] Setting up AnimationTree for body blending...")

	# Create animation tree structure programmatically
	# Root: AnimationNodeBlendTree
	var blend_tree := AnimationNodeBlendTree.new()

	# Node 1: Lower body locomotion (legs, hips)
	var lower_body_anim := AnimationNodeAnimation.new()
	lower_body_anim.animation = "Idle"  # Default
	blend_tree.add_node("lower_body", lower_body_anim, Vector2(0, 0))

	# Node 2: Upper body weapon holding (arms, spine, head)
	var upper_body_anim := AnimationNodeAnimation.new()
	upper_body_anim.animation = "Pistol_Aim_Neutral"  # Default weapon holding pose
	blend_tree.add_node("upper_body", upper_body_anim, Vector2(0, 100))

	# Node 3: Blend2 to combine lower and upper body
	var body_blend := AnimationNodeBlend2.new()
	body_blend.filter_enabled = true
	blend_tree.add_node("body_blend", body_blend, Vector2(200, 50))

	# Connect nodes
	blend_tree.connect_node("body_blend", 0, "lower_body")
	blend_tree.connect_node("body_blend", 1, "upper_body")
	blend_tree.connect_node("output", 0, "body_blend")

	# Setup bone filter for upper body (only affect upper body bones)
	_setup_upper_body_filter(body_blend)

	# Set the tree root
	anim_tree.tree_root = blend_tree

	# Activate the tree
	anim_tree.active = true

	_log("[SkeletalVisuals] AnimationTree activated with body blending")


## Setup bone filter for upper body animations
func _setup_upper_body_filter(blend_node: AnimationNodeBlend2) -> void:
	if not skeleton:
		return

	# Upper body bones (spine, arms, head) - these will use weapon holding animations
	var upper_body_bones: Array[String] = [
		"DEF-spine.002",  # Mid spine
		"DEF-spine.003",  # Upper spine/chest
		"DEF-spine.004",  # Neck
		"DEF-spine.006",  # Head
		"DEF-shoulder.L",
		"DEF-shoulder.R",
		"DEF-upper_arm.L",
		"DEF-upper_arm.R",
		"DEF-forearm.L",
		"DEF-forearm.R",
		"DEF-hand.L",
		"DEF-hand.R",
	]

	# Enable filter for these bones
	for bone_name in upper_body_bones:
		var bone_idx := skeleton.find_bone(bone_name)
		if bone_idx != -1:
			var track_path := "%s:%s" % [skeleton.get_path(), bone_name]
			blend_node.set_filter_path(NodePath(track_path), true)
			_log("[SkeletalVisuals] Filtered upper body bone: " + " " + str(bone_name))


## Set locomotion animation (lower body)
func set_locomotion_animation(anim_name: String) -> void:
	if not anim_tree or not anim_tree.active:
		# Fallback to direct animation player
		play_animation(anim_name)
		return

	var root: AnimationNodeBlendTree = anim_tree.tree_root as AnimationNodeBlendTree
	if not root:
		return

	var node: AnimationNode = root.get_node("lower_body")
	if node and node is AnimationNodeAnimation:
		(node as AnimationNodeAnimation).animation = anim_name


## Set upper body animation (weapon holding)
func set_upper_body_animation(anim_name: String) -> void:
	if not anim_tree or not anim_tree.active:
		return

	var root: AnimationNodeBlendTree = anim_tree.tree_root as AnimationNodeBlendTree
	if root:
		var node: AnimationNode = root.get_node("upper_body")
		if node and node is AnimationNodeAnimation:
			(node as AnimationNodeAnimation).animation = anim_name

	anim_tree.set("parameters/body_blend/blend_amount", 1.0)  # Full upper body override


## Disable upper body override (use full body animations)
func disable_upper_body_override() -> void:
	if not anim_tree or not anim_tree.active:
		return

	anim_tree.set("parameters/body_blend/blend_amount", 0.0)  # No upper body override
	_log("[SkeletalVisuals] Disabled upper body override")


# =============================================================================
# WEAPON ANIMATION HELPERS
# =============================================================================


## Set pistol aim direction (up, neutral, down)
func set_pistol_aim(direction: String = "neutral") -> void:
	var anim_name: String
	match direction.to_lower():
		"up":
			anim_name = "Pistol_Aim_Up"
		"down":
			anim_name = "Pistol_Aim_Down"
		_:
			anim_name = "Pistol_Aim_Neutral"

	set_upper_body_animation(anim_name)


## Play pistol idle animation (upper body only)
func play_pistol_idle() -> void:
	set_upper_body_animation("Pistol_Idle")


## Play pistol shoot animation (upper body only)
func play_pistol_shoot() -> void:
	set_upper_body_animation("Pistol_Shoot")


## Play pistol reload animation (upper body only)
func play_pistol_reload() -> void:
	set_upper_body_animation("Pistol_Reload")


## Get the hand bone for weapon attachment
func get_weapon_hand_bone() -> String:
	# Right hand bone for weapon attachment
	return "DEF-hand.R"


## Setup dismemberment controller
func _setup_dismemberment() -> void:
	if not skeleton or not mannequin_root:
		return

	dismemberment_controller = DismembermentController.new()
	dismemberment_controller.name = "DismembermentController"
	add_child(dismemberment_controller)
	dismemberment_controller.setup(skeleton, mannequin_root)

	# Setup ragdoll physics on the skeleton
	call_deferred("setup_ragdoll")


## Setup physical bones for ragdoll physics
func setup_ragdoll() -> void:
	if not skeleton:
		push_error("[SkeletalVisuals] Cannot setup ragdoll - no skeleton")
		return

	_log("[SkeletalVisuals] Setting up ragdoll physics...")

	# Key bones for ragdoll (using DEF- prefix from mannequin)
	var ragdoll_bones: Array[String] = [
		"DEF-spine",
		"DEF-spine.001",
		"DEF-spine.002",
		"DEF-spine.003",  # Upper spine/chest
		"DEF-spine.004",  # Neck
		"DEF-spine.006",  # Head
		"DEF-shoulder.L",
		"DEF-upper_arm.L",
		"DEF-forearm.L",
		"DEF-hand.L",
		"DEF-shoulder.R",
		"DEF-upper_arm.R",
		"DEF-forearm.R",
		"DEF-hand.R",
		"DEF-thigh.L",
		"DEF-shin.L",
		"DEF-foot.L",
		"DEF-thigh.R",
		"DEF-shin.R",
		"DEF-foot.R",
	]

	var created_count: int = 0

	for bone_name in ragdoll_bones:
		var bone_idx := skeleton.find_bone(bone_name)
		if bone_idx == -1:
			continue

		# Create PhysicalBone3D
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bone_name
		pb.bone_name = bone_name

		# Bone-specific mass (Half-Life 2 / Painkiller / Bulletstorm style)
		# Realistic mass distribution - bodies should feel SOLID and HEAVY
		if "spine" in bone_name.to_lower():
			if "004" in bone_name:  # Neck
				pb.mass = 4.0  # Neck has weight
			elif "006" in bone_name:  # Head
				pb.mass = 5.5  # Head is heavy (realistic human head ~5kg)
			else:
				pb.mass = 15.0  # Torso is HEAVY - most body mass concentrated here
		elif "thigh" in bone_name.to_lower():
			pb.mass = 8.0  # Upper legs are heavy
		elif "shin" in bone_name.to_lower():
			pb.mass = 4.0  # Lower legs have weight
		elif "upper_arm" in bone_name.to_lower():
			pb.mass = 3.5  # Upper arms have substance
		elif "forearm" in bone_name.to_lower():
			pb.mass = 2.0  # Lower arms
		elif "shoulder" in bone_name.to_lower():
			pb.mass = 3.0  # Shoulders connect to heavy torso
		elif "hand" in bone_name.to_lower():
			pb.mass = 0.8  # Hands are lighter
		elif "foot" in bone_name.to_lower():
			pb.mass = 1.2  # Feet have some weight
		else:
			pb.mass = 2.0  # Default

		pb.gravity_scale = 1.0

		# Note: PhysicalBone3D doesn't support physics_material_override in Godot 4.x
		# Friction and bounce are controlled through damping and other properties

		# CRITICAL: Low damping for realistic ballistic motion
		# Half-Life 2 style - bodies fly through the air naturally, then settle
		pb.linear_damp = 0.1  # Very low - allows bodies to fly and tumble naturally
		pb.angular_damp = 0.3  # Low - allows natural rotation without excessive spinning

		# Collision
		pb.collision_layer = 64  # LAYER_DEBRIS
		pb.collision_mask = 1  # LAYER_WORLD
		pb.can_sleep = false

		# Create collision shape based on bone
		var shape: CollisionShape3D = CollisionShape3D.new()

		if "head" in bone_name.to_lower():
			var sphere := SphereShape3D.new()
			sphere.radius = 0.12
			shape.shape = sphere
		elif "hand" in bone_name.to_lower() or "foot" in bone_name.to_lower():
			var box := BoxShape3D.new()
			box.size = Vector3(0.08, 0.08, 0.15)
			shape.shape = box
		elif (
			"arm" in bone_name.to_lower()
			or "leg" in bone_name.to_lower()
			or "shin" in bone_name.to_lower()
			or "forearm" in bone_name.to_lower()
			or "thigh" in bone_name.to_lower()
		):
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.06
			capsule.height = 0.3
			shape.shape = capsule
		else:
			# Spine/torso
			var box := BoxShape3D.new()
			box.size = Vector3(0.3, 0.15, 0.2)
			shape.shape = box

		pb.add_child(shape)

		# Joint configuration - TIGHT constraints for solid, humanoid movement
		# Half-Life 2 / Painkiller style - bodies maintain structure, don't flop
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE

		# Configure joint limits based on bone type
		if "head" in bone_name.to_lower() or "004" in bone_name:  # Neck
			# Neck - limited but natural range
			pb.set("joint_constraints/swing_span", deg_to_rad(35))
			pb.set("joint_constraints/twist_span", deg_to_rad(45))
		elif "shoulder" in bone_name.to_lower():
			# Shoulders - moderate range but constrained
			pb.set("joint_constraints/swing_span", deg_to_rad(70))
			pb.set("joint_constraints/twist_span", deg_to_rad(30))
		elif "upper_arm" in bone_name.to_lower():
			# Upper arms - ball joint with limits
			pb.set("joint_constraints/swing_span", deg_to_rad(80))
			pb.set("joint_constraints/twist_span", deg_to_rad(40))
		elif "forearm" in bone_name.to_lower():
			# Elbows - hinge joint, can only bend one way
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
			pb.set("joint_constraints/angular_limit_lower", deg_to_rad(-140))
			pb.set("joint_constraints/angular_limit_upper", deg_to_rad(0))
		elif "thigh" in bone_name.to_lower():
			# Hips - moderate range, prevents excessive splits
			pb.set("joint_constraints/swing_span", deg_to_rad(60))
			pb.set("joint_constraints/twist_span", deg_to_rad(25))
		elif "shin" in bone_name.to_lower():
			# Knees - hinge joint, forward bend only
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
			pb.set("joint_constraints/angular_limit_lower", deg_to_rad(0))
			pb.set("joint_constraints/angular_limit_upper", deg_to_rad(140))
		elif "hand" in bone_name.to_lower():
			# Wrists - limited rotation
			pb.set("joint_constraints/swing_span", deg_to_rad(40))
			pb.set("joint_constraints/twist_span", deg_to_rad(60))
		elif "foot" in bone_name.to_lower():
			# Ankles - limited but natural
			pb.set("joint_constraints/swing_span", deg_to_rad(30))
			pb.set("joint_constraints/twist_span", deg_to_rad(20))
		else:
			# Spine: TIGHT constraints for structural rigidity - prevents noodle spine
			pb.set("joint_constraints/swing_span", deg_to_rad(15))
			pb.set("joint_constraints/twist_span", deg_to_rad(10))

		# Add to skeleton
		skeleton.add_child(pb)
		created_count += 1

	_log(
		(
			"[SkeletalVisuals] Created "
			+ " "
			+ str(created_count)
			+ " "
			+ " physical bones for ragdoll"
		)
	)


## Start ragdoll physics simulation
func start_ragdoll(impulse_dir: Vector3 = Vector3.ZERO, impulse_force: float = 0.0) -> void:
	if not skeleton:
		return

	_log(
		(
			"Starting ragdoll simulation with impulse: "
			+ " "
			+ str(impulse_dir)
			+ " "
			+ " force: "
			+ " "
			+ str(impulse_force)
		)
	)

	# CRITICAL: Store current bone poses BEFORE stopping animation
	# This preserves the death animation pose for more natural ragdolling
	var bone_poses: Dictionary = {}
	for i: int in range(skeleton.get_bone_count()):
		bone_poses[i] = skeleton.get_bone_pose(i)

	# Stop any playing animations AFTER capturing poses
	if anim_player:
		anim_player.stop()

	# Start physical bone simulation
	skeleton.physical_bones_start_simulation()

	# Apply stored poses to physical bones for smooth transition
	for bone_idx: int in bone_poses:
		var bone_name := skeleton.get_bone_name(bone_idx)
		var pb_node: Node = skeleton.get_node_or_null("PB_" + bone_name)
		if pb_node and pb_node is PhysicalBone3D:
			var pb: PhysicalBone3D = pb_node as PhysicalBone3D
			# Set initial transform from animation pose
			pb.global_transform = (
				skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)
			)

	# Apply death impulse if provided (with momentum conservation)
	if impulse_dir != Vector3.ZERO and impulse_force > 0.0:
		call_deferred("_apply_ragdoll_impulse", impulse_dir, impulse_force)


## Apply impulse to ragdoll (must be deferred to allow physics to initialize)
func _apply_ragdoll_impulse(direction: Vector3, force: float) -> void:
	if not skeleton:
		return

	_log(
		(
			"[SkeletalVisuals] Applying ragdoll impulse: dir="
			+ " "
			+ str(direction)
			+ " "
			+ " force="
			+ " "
			+ str(force)
		)
	)

	# Half-Life 2 / GTA V style: Apply impulse to multiple bones for realistic momentum
	# Primary impact on spine/chest, secondary on limbs

	var impulse: Vector3 = direction.normalized() * force

	# Primary bones (torso) - receive full force
	var primary_bones: Array[String] = [
		"DEF-spine.002",  # Mid spine
		"DEF-spine.003",  # Upper spine/chest
	]

	# Secondary bones (limbs/head) - receive partial force for natural motion
	var secondary_bones: Array[String] = [
		"DEF-spine.006",  # Head
		"DEF-upper_arm.L",
		"DEF-upper_arm.R",
		"DEF-thigh.L",
		"DEF-thigh.R",
	]

	# Apply primary impulse to torso
	for bone_name in primary_bones:
		var pb_node: Node = skeleton.get_node_or_null("PB_" + bone_name)
		if pb_node and pb_node is PhysicalBone3D:
			var pb: PhysicalBone3D = pb_node as PhysicalBone3D
			pb.apply_central_impulse(impulse)
			_log("[SkeletalVisuals] Applied primary impulse to " + " " + str(bone_name))

	# Apply secondary impulse to limbs (60% of primary)
	var secondary_impulse := impulse * 0.6
	for bone_name in secondary_bones:
		var pb_node: Node = skeleton.get_node_or_null("PB_" + bone_name)
		if pb_node and pb_node is PhysicalBone3D:
			var pb: PhysicalBone3D = pb_node as PhysicalBone3D
			pb.apply_central_impulse(secondary_impulse)

	# Add slight angular velocity for more dynamic ragdolls (Painkiller style)
	var torque := Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	for bone_name in primary_bones:
		var pb_node: Node = skeleton.get_node_or_null("PB_" + bone_name)
		if pb_node and pb_node is PhysicalBone3D:
			var pb: PhysicalBone3D = pb_node as PhysicalBone3D
			pb.apply_torque_impulse(torque * force * 0.1)


## Apply velocity to all ragdoll bones (for momentum conservation)
func _apply_velocity_to_ragdoll(velocity: Vector3) -> void:
	if not skeleton:
		return

	_log("[SkeletalVisuals] Applying velocity to ragdoll: " + " " + str(velocity))

	# Apply velocity to all physical bones
	for i in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(i)
		var pb_node: Node = skeleton.get_node_or_null("PB_" + bone_name)
		if pb_node and pb_node is PhysicalBone3D:
			var pb: PhysicalBone3D = pb_node as PhysicalBone3D
			pb.linear_velocity = velocity


## Stop ragdoll physics simulation
func stop_ragdoll() -> void:
	if not skeleton:
		return

	skeleton.physical_bones_stop_simulation()


## Play default idle animation after setup
func _play_default_animation() -> void:
	# Try common idle animation names
	var idle_anims := ["Idle", "idle", "T-Pose", "A_Tpose"]
	for anim_name: String in idle_anims:
		if anim_player and anim_player.has_animation(anim_name):
			_log("[SkeletalVisuals] Playing default animation: %s" % anim_name)

			# Debug: Check animation tracks
			var anim: Animation = anim_player.get_animation(anim_name)
			if anim:
				_log(
					(
						"Animation '%s' has %d tracks, length: %.2f"
						% [anim_name, anim.get_track_count(), anim.length]
					)
				)
				# Print first few track paths to verify they target the skeleton
				for i in range(min(3, anim.get_track_count())):
					_log("  Track %d: %s" % [i, anim.track_get_path(i)])

			anim_player.play(anim_name)
			_log(
				"[SkeletalVisuals] After play - is_playing: " + " " + str(anim_player.is_playing())
			)
			return

	# If no idle found, just play the first available animation
	if anim_player:
		var libs := anim_player.get_animation_library_list()
		if libs.size() > 0:
			var lib: AnimationLibrary = anim_player.get_animation_library(libs[0])
			if lib:
				var anims := lib.get_animation_list()
				if anims.size() > 0:
					anim_player.play(anims[0])
					_log("[SkeletalVisuals] Playing first available animation: %s" % anims[0])


## Apply color to all meshes
func _apply_color() -> void:
	if not mannequin_root:
		return

	var meshes := _find_all_nodes_by_type(mannequin_root, MeshInstance3D)
	for mesh_inst in meshes:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = character_color
		mesh_inst.material_override = mat


## Play an animation by name
func play_animation(anim_name: String, blend_time: float = 0.1) -> void:
	_log(
		(
			"[SkeletalVisuals] play_animation called: "
			+ " "
			+ str(anim_name)
			+ " "
			+ " blend: "
			+ " "
			+ str(blend_time)
		)
	)

	if not anim_player:
		push_warning("[SkeletalVisuals] Cannot play animation - anim_player is null")
		_log("[SkeletalVisuals] ERROR: anim_player is null!")
		return

	_log("[SkeletalVisuals] anim_player exists, checking if animation exists...")

	if anim_player.has_animation(anim_name):
		_log("[SkeletalVisuals] Animation found, playing: " + " " + str(anim_name))
		anim_player.play(anim_name, blend_time)
		_log(
			(
				"After play - is_playing: "
				+ " "
				+ str(anim_player.is_playing())
				+ " "
				+ " current: "
				+ " "
				+ str(anim_player.current_animation)
				+ " "
				+ " speed: "
				+ " "
				+ str(anim_player.speed_scale)
			)
		)
	else:
		push_warning("[SkeletalVisuals] Animation not found: %s" % anim_name)
		_log("[SkeletalVisuals] ERROR: Animation not found: " + " " + str(anim_name))
		_log("[SkeletalVisuals] Available animations:")
		var available := get_available_animations()
		for i in range(min(10, available.size())):
			_log("  - " + " " + str(available[i]))


## Stop current animation
func stop_animation() -> void:
	if anim_player:
		anim_player.stop()


## Check if animation is playing
func is_playing_animation(anim_name: String = "") -> bool:
	if not anim_player:
		return false

	if anim_name.is_empty():
		return anim_player.is_playing()

	return anim_player.current_animation == anim_name


## Get list of all available animations
func get_available_animations() -> Array[String]:
	var anims: Array[String] = []
	if not anim_player:
		return anims

	for lib_name in anim_player.get_animation_library_list():
		var lib: AnimationLibrary = anim_player.get_animation_library(lib_name)
		if lib:
			anims.append_array(lib.get_animation_list())

	return anims


## Find matching bone name with various naming conventions
func find_matching_bone(bone_name: String) -> String:
	return MannequinBoneMap.resolve(skeleton, bone_name)


## Attach a node to a bone (e.g., weapon to hand)
func attach_to_bone(node: Node3D, bone_name: String) -> bool:
	if not skeleton:
		return false

	var bone_idx := skeleton.find_bone(bone_name)
	if bone_idx == -1:
		push_warning("[SkeletalVisuals] Bone not found: %s" % bone_name)
		return false

	# Create or reuse BoneAttachment3D
	var attachment_name := "Attachment_" + bone_name
	var attachment: BoneAttachment3D = skeleton.get_node_or_null(attachment_name)

	if not attachment:
		attachment = BoneAttachment3D.new()
		attachment.name = attachment_name
		attachment.bone_name = bone_name
		skeleton.add_child(attachment)

	# Reparent node to attachment
	if node.get_parent():
		node.get_parent().remove_child(node)

	attachment.add_child(node)
	node.position = Vector3.ZERO
	node.rotation = Vector3.ZERO

	return true


## Set character color
func set_character_color(new_color: Color) -> void:
	character_color = new_color
	_apply_color()


## Alias for backwards compatibility
func set_color(new_color: Color) -> void:
	set_character_color(new_color)


## Flash the character with a color (for damage feedback)
func flash(flash_color: Color, duration: float = 0.2) -> void:
	if not mannequin_root:
		return

	var meshes := _find_all_nodes_by_type(mannequin_root, MeshInstance3D)
	for mesh_inst in meshes:
		# Store original color if not already flashing
		if not mesh_inst.has_meta("original_color"):
			var current_mat: Material = mesh_inst.material_override
			if current_mat and current_mat is StandardMaterial3D:
				var std_mat := current_mat as StandardMaterial3D
				mesh_inst.set_meta("original_color", std_mat.albedo_color)

		# Apply flash color
		var flash_mat := StandardMaterial3D.new()
		flash_mat.albedo_color = flash_color
		mesh_inst.material_override = flash_mat

	# Restore original color after duration
	await get_tree().create_timer(duration).timeout

	for mesh_inst in meshes:
		if mesh_inst.has_meta("original_color"):
			var original_color: Color = mesh_inst.get_meta("original_color")
			var restore_mat := StandardMaterial3D.new()
			restore_mat.albedo_color = original_color
			mesh_inst.material_override = restore_mat
			mesh_inst.remove_meta("original_color")


## Hide/show head (for first-person view)
func set_head_visible(should_show: bool) -> void:
	if not skeleton:
		return

	var bone_idx := skeleton.find_bone("Head")
	if bone_idx != -1:
		skeleton.set_bone_pose_scale(bone_idx, Vector3.ONE if should_show else Vector3.ZERO)


## Get bone global position
func get_bone_global_position(bone_name: String) -> Vector3:
	if not skeleton:
		return Vector3.ZERO

	var bone_idx := skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return Vector3.ZERO

	return skeleton.to_global(skeleton.get_bone_global_pose(bone_idx).origin)


# =============================================================================
# ANIMATION WRAPPER METHODS (for backwards compatibility with enemy AI)
# =============================================================================


## Play roll animation
func play_roll() -> void:
	play_animation("Roll")


## Play telegraph/attack windup animation
func play_telegraph() -> void:
	# Use punch enter as telegraph
	play_animation("PunchKick_Enter")


## Play hurt/flinch animation
func play_hurt() -> void:
	# Use random hit animation
	var hit_anims := ["Hit_Chest", "Hit_Stomach", "Hit_Head"]
	play_animation(hit_anims[randi() % hit_anims.size()])


## Play hit animation based on location
func play_hit_animation(hit_location: String = "chest", _is_heavy: bool = false) -> void:
	var anim_name := "Hit_Chest"

	match hit_location.to_lower():
		"head":
			anim_name = "Hit_Head"
		"stomach", "gut":
			anim_name = "Hit_Stomach"
		"shoulder_left", "arm_left":
			anim_name = "Hit_Shoulder_L"
		"shoulder_right", "arm_right":
			anim_name = "Hit_Shoulder_R"
		_:
			anim_name = "Hit_Chest"

	play_animation(anim_name)


## Play knockdown animation
func play_knockdown_animation() -> void:
	# Use death animation for knockdown
	play_animation("Death01")


## Play death animation
func play_death_animation(anim_name: String = "") -> void:
	_log("[SkeletalVisuals] play_death_animation called with: " + " " + str(anim_name))

	if anim_name.is_empty():
		# Random death animation
		var death_anims := ["Death01", "Death02"]
		anim_name = death_anims[randi() % death_anims.size()]
		_log("[SkeletalVisuals] Selected random death animation: " + " " + str(anim_name))

	_log("[SkeletalVisuals] Calling play_animation(" + " " + str(anim_name) + " " + ")")
	play_animation(anim_name)

	# Verify it's playing
	if anim_player:
		_log("[SkeletalVisuals] After play_animation:")
		_log("  - is_playing: " + " " + str(anim_player.is_playing()))
		_log("  - current_animation: " + " " + str(anim_player.current_animation))
		_log(
			(
				"  - has_animation("
				+ " "
				+ str(anim_name)
				+ " "
				+ "): "
				+ " "
				+ str(anim_player.has_animation(anim_name))
			)
		)


## Play stomp animation (for boss)
func play_stomp() -> void:
	# Use kick as stomp
	play_animation("Kick")


# =============================================================================
# PLAYER ANIMATION ALIASES
# =============================================================================


## Play idle animation (player compatibility)
func play_idle() -> void:
	play_animation("Idle")


## Play move/walk animation (player compatibility)
func play_move() -> void:
	play_animation("Jog_Fwd")


## Play melee animation (player compatibility)
func play_melee() -> void:
	play_animation("Punch_Jab")


## Helper: Find first node of specific type in tree
func _find_node_by_type(root: Node, type: Variant) -> Node:
	if is_instance_of(root, type):
		return root

	for child in root.get_children():
		var result := _find_node_by_type(child, type)
		if result:
			return result

	return null


## Helper: Find all nodes of specific type in tree
func _find_all_nodes_by_type(root: Node, type: Variant) -> Array[Node]:
	var results: Array[Node] = []

	if is_instance_of(root, type):
		results.append(root)

	for child in root.get_children():
		results.append_array(_find_all_nodes_by_type(child, type))

	return results


## Attach weapon node to hand bone (for weapon system)
func attach_weapon_node(
	weapon_node: Node3D, hand: String = "right", offset: Vector3 = Vector3.ZERO
) -> void:
	if not skeleton:
		push_warning("[SkeletalVisuals] Cannot attach weapon: no skeleton")
		return

	# DEBUG: Print all available bone names to help identify correct hand bone
	_log("[SkeletalVisuals] DEBUG: Skeleton has %d bones:" % skeleton.get_bone_count())
	var hand_related_bones: Array[String] = []
	for i in range(skeleton.get_bone_count()):
		var bone_name_debug: String = skeleton.get_bone_name(i)
		# Filter for hand/wrist bones to reduce noise
		var lower_name: String = bone_name_debug.to_lower()
		if "hand" in lower_name or "wrist" in lower_name or "finger" in lower_name:
			hand_related_bones.append(bone_name_debug)

	if hand_related_bones.size() > 0:
		_log("[SkeletalVisuals] DEBUG: Hand/Wrist bones found: %s" % str(hand_related_bones))
	else:
		_log("[SkeletalVisuals] DEBUG: No hand/wrist bones found. Printing all bone names:")
		for i in range(min(skeleton.get_bone_count(), 20)):  # Print first 20 bones
			_log("  [%d] %s" % [i, skeleton.get_bone_name(i)])

	# Determine bone name
	var bone_name: String = "DEF-hand.R" if hand == "right" else "DEF-hand.L"

	# Try to find the bone (with fallback variations)
	var bone_idx := skeleton.find_bone(bone_name)
	if bone_idx == -1:
		# Try alternative names including mixamorig prefix and legacy names
		var alternatives: Array[String] = []
		if hand == "right":
			alternatives = [
				"RightHand",
				"mixamorig:RightHand",
				"mixamorig_RightHand",
				"Right_Hand",
				"R_Hand",
				"hand_R",
				"righthand",
			]
		else:
			alternatives = [
				"LeftHand",
				"mixamorig:LeftHand",
				"mixamorig_LeftHand",
				"Left_Hand",
				"L_Hand",
				"hand_L",
				"lefthand",
			]

		for alt in alternatives:
			bone_idx = skeleton.find_bone(alt)
			if bone_idx != -1:
				bone_name = alt
				break

	if bone_idx == -1:
		push_warning("[SkeletalVisuals] Hand bone not found: %s" % bone_name)
		return

	# Create or reuse BoneAttachment3D for weapon
	var attachment_name := "WeaponAttachment_" + hand
	var attachment: BoneAttachment3D = skeleton.get_node_or_null(attachment_name)

	if not attachment:
		attachment = BoneAttachment3D.new()
		attachment.name = attachment_name
		attachment.bone_name = bone_name
		skeleton.add_child(attachment)

	# Reparent weapon to attachment
	if weapon_node.get_parent():
		weapon_node.get_parent().remove_child(weapon_node)

	attachment.add_child(weapon_node)

	# Apply offset if provided, otherwise use default palm offset
	if offset != Vector3.ZERO:
		weapon_node.position = offset
	else:
		# Default: position in palm (forward from wrist)
		weapon_node.position = Vector3(0, 0, 0.08)

	weapon_node.rotation = Vector3.ZERO


## Equip a simple knife model to hand (for melee enemies)
func equip_knife(hand: String = "right") -> void:
	if not skeleton:
		return

	# Create knife model
	var knife_root: Node3D = Node3D.new()
	knife_root.name = "Knife"

	# Handle
	var handle: MeshInstance3D = MeshInstance3D.new()
	handle.mesh = BoxMesh.new()
	handle.mesh.size = Vector3(0.04, 0.12, 0.04)
	var handle_mat: StandardMaterial3D = StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.2, 0.1, 0.05)  # Brown
	handle.material_override = handle_mat
	knife_root.add_child(handle)

	# Blade
	var blade: MeshInstance3D = MeshInstance3D.new()
	blade.mesh = PrismMesh.new()
	blade.mesh.size = Vector3(0.02, 0.2, 0.05)
	var blade_mat: StandardMaterial3D = StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.7, 0.7, 0.8)  # Silver
	blade_mat.metallic = 0.8
	blade_mat.roughness = 0.2
	blade.material_override = blade_mat
	knife_root.add_child(blade)

	# Positioning
	blade.position = Vector3(0, 0.16, 0)
	blade.rotation = Vector3(PI, 0, 0)

	# Attach to hand (with palm offset already applied by attach_weapon_node)
	attach_weapon_node(knife_root, hand)

	# Adjust orientation for proper grip
	# Rotate to point blade forward, handle in palm
	knife_root.rotation_degrees = Vector3(0, 0, -90)  # Point blade forward


# =============================================================================
# DISMEMBERMENT
# =============================================================================


## Dismember a limb (hide it on the character model)
func dismember(limb_id: String) -> void:
	if dismemberment_controller:
		dismemberment_controller.dismember(limb_id)


## Check if a limb is dismembered
func is_limb_dismembered(limb_id: String) -> bool:
	if dismemberment_controller:
		return dismemberment_controller.is_limb_dismembered(limb_id)
	return false


## Find which limb was hit based on position
func find_hit_limb(hit_pos: Vector3) -> String:
	if dismemberment_controller:
		return dismemberment_controller.find_hit_limb(hit_pos, global_transform)
	return "torso"


# =============================================================================
# DEBUG VISUALS (X-RAY MODE)
# =============================================================================

var _xray_material: StandardMaterial3D


## Enable/disable x-ray vision for debug mode (F5)
func set_xray_enabled(enabled: bool) -> void:
	if enabled and not _xray_material:
		# Create x-ray material (red, transparent, no depth test)
		_xray_material = StandardMaterial3D.new()
		_xray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_xray_material.albedo_color = Color(1.0, 0.2, 0.2, 0.6)
		_xray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_xray_material.no_depth_test = true  # Render through walls
		_xray_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_xray_material.render_priority = 127  # Render on top

	# Apply x-ray material to all meshes
	_apply_xray_recursive(mannequin_root, enabled)


## Recursively apply x-ray material to all MeshInstance3D nodes
func _apply_xray_recursive(node: Node, enabled: bool) -> void:
	if not node:
		return

	if node is MeshInstance3D:
		# Use material_overlay to preserve original material
		node.material_overlay = _xray_material if enabled else null

	for child in node.get_children():
		_apply_xray_recursive(child, enabled)
