class_name DismembermentSystem
extends Node

signal limb_severed(limb_type: String, position: Vector3)
signal dismemberment_complete(limb_count: int)

enum LimbType { HEAD, ARM_LEFT, ARM_RIGHT, LEG_LEFT, LEG_RIGHT, TORSO }

@export_group("Dismemberment Settings")
@export var enabled: bool = true
@export var overkill_threshold: int = 50
@export var limb_separation_force: float = 8.0
@export var limb_lifetime: float = 20.0
@export_group("Limb Physics")
@export var limb_mass: float = 0.8
@export var limb_bounce: float = 0.4
@export var limb_friction: float = 0.8
@export var limb_gravity_scale: float = 1.5
@export_group("Visual")
@export var blood_color: Color = Color(0.6, 0.0, 0.0)
@export var bone_color: Color = Color(0.9, 0.9, 0.85)
@export var flesh_color: Color = Color(0.6, 0.2, 0.2)
@export var spawn_blood_fountain: bool = true

var _limb_definitions: Dictionary = {}
var visuals: SkeletalCharacterVisuals = null

# FIXED C-05: Store timer references for proper cleanup
var _blood_particle_timers: Array[SceneTreeTimer] = []


func setup(v: SkeletalCharacterVisuals) -> void:
	visuals = v


func _ready() -> void:
	# Check get_node_or_null("/root/GameManager").get_core_system("config") if get_node_or_null("/root/GameManager") else null for enabled state
	var gm: Node = get_node_or_null("/root/GameManager")
	var config: Node = gm.get_core_system("config") if gm else null
	if config and config.has_method("is_feature_enabled"):
		enabled = enabled and config.is_feature_enabled("dismemberment")

	if config:
		if config.has_signal("config_reloaded"):
			config.config_reloaded.connect(_on_config_reloaded)
	_load_config()
	_setup_limb_definitions()


func _on_config_reloaded(_file_path: String = "") -> void:
	_load_config()


func dismember_body(
	body_position: Vector3, velocity: Vector3, damage: int, hit_direction: Vector3 = Vector3.ZERO
) -> void:
	# Server broadcasts to all clients
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_sync_dismemberment.rpc(body_position, velocity, damage, hit_direction)
		# Don't execute locally on server - let RPC handle it
		return

	# Singleplayer path
	call_deferred("_finish_dismember_body", body_position, velocity, damage, hit_direction)


@rpc("authority", "call_local", "reliable")
func _sync_dismemberment(
	body_position: Vector3, velocity: Vector3, damage: int, hit_direction: Vector3
) -> void:
	## RPC: Sync dismemberment effects to all clients
	call_deferred("_finish_dismember_body", body_position, velocity, damage, hit_direction)


func _finish_dismember_body(
	body_position: Vector3, velocity: Vector3, damage: int, hit_direction: Vector3
) -> void:
	## Dismember body into separate limbs
	## Args:
	##   body_position: Body center position
	##   velocity: Body velocity at death
	##   damage: Damage that killed (determines dismemberment level)
	##   hit_direction: Direction of killing blow
	if not enabled:
		return

	var config: Node = get_node_or_null("/root/GameManager").get_core_system("config") if get_node_or_null("/root/GameManager") else null
	if not config or not config.has_method("is_feature_enabled"):
		return
	if not config.is_feature_enabled("dismemberment"):
		return

	var limbs_to_spawn: Array[LimbType] = []

	# Determine which limbs to separate based on damage
	if damage >= overkill_threshold:
		# Full dismemberment
		limbs_to_spawn = [
			LimbType.HEAD,
			LimbType.ARM_LEFT,
			LimbType.ARM_RIGHT,
			LimbType.LEG_LEFT,
			LimbType.LEG_RIGHT,
			LimbType.TORSO
		]
	else:
		# Partial dismemberment (random limbs)
		var limb_count := mini(int(damage / 20.0) + 1, 3)
		for i: int in range(limb_count):
			var random_limb: LimbType = (randi() % LimbType.size()) as LimbType
			if random_limb not in limbs_to_spawn:
				limbs_to_spawn.append(random_limb)

	# Spawn each limb
	for limb_type: LimbType in limbs_to_spawn:
		var limb_name: String = ""
		match limb_type:
			LimbType.HEAD:
				limb_name = "head"
			LimbType.ARM_LEFT:
				limb_name = "arm_l"
			LimbType.ARM_RIGHT:
				limb_name = "arm_r"
			LimbType.LEG_LEFT:
				limb_name = "leg_l"
			LimbType.LEG_RIGHT:
				limb_name = "leg_r"
			LimbType.TORSO:
				limb_name = "torso"

		_spawn_limb(limb_type, body_position, velocity, hit_direction)

		# Hide the limb on the main character model
		if visuals and not limb_name.is_empty():
			visuals.dismember(limb_name)

	# Spawn blood fountain at separation point
	if spawn_blood_fountain:
		_spawn_blood_fountain(body_position)

	dismemberment_complete.emit(limbs_to_spawn.size())


func _spawn_limb(
	limb_type: LimbType, base_position: Vector3, base_velocity: Vector3, hit_direction: Vector3
) -> void:
	var limb_def: Dictionary = _limb_definitions.get(limb_type, {})
	var bone_name: String = limb_def.get("bone", "")

	if bone_name.is_empty():
		# Fallback to old procedural spawning if no bone defined
		_spawn_limb_procedural(limb_type, base_position, base_velocity, hit_direction)
		return

	var gs := get_node_or_null("/root/GameManager").get_core_system("gameplay") if get_node_or_null("/root/GameManager") else null as GameplaySvc
	if not gs or not gs.effects:
		return

	var limb_color: Color = visuals.color if visuals else Color(0.5, 0.5, 0.5)
	var separation_dir := _get_limb_separation_direction(limb_type, hit_direction)

	# Position with skeleton offset if available
	var spawn_pos: Vector3 = base_position
	if visuals and visuals.skeleton:
		var b_idx: int = visuals.skeleton.find_bone(visuals.find_matching_bone(bone_name))
		if b_idx != -1:
			spawn_pos = visuals.to_global(visuals.skeleton.get_bone_global_pose(b_idx).origin)

	gs.effects.spawn_limb_gib(spawn_pos, bone_name, limb_color, separation_dir)

	limb_severed.emit(LimbType.keys()[limb_type], spawn_pos)


func _spawn_limb_procedural(
	limb_type: LimbType, base_position: Vector3, base_velocity: Vector3, hit_direction: Vector3
) -> void:
	## Spawn a single dismembered limb (LEGACY fallback)
	var limb_def: Dictionary = _limb_definitions.get(limb_type, {})
	var limb := RigidBody3D.new()

	# Create limb mesh
	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()

	_create_limb_mesh(limb_type, mesh_instance, collision, limb_def)

	limb.add_child(mesh_instance)
	limb.add_child(collision)

	# Physics properties
	limb.collision_layer = CollisionLayers.LAYER_DEBRIS
	limb.collision_mask = CollisionLayers.MASK_WORLD_ONLY
	limb.mass = limb_mass * limb_def.get("mass_multiplier", 1.0)
	limb.gravity_scale = limb_gravity_scale
	limb.physics_material_override = PhysicsMaterial.new()
	limb.physics_material_override.bounce = limb_bounce
	limb.physics_material_override.friction = limb_friction
	limb.contact_monitor = true
	limb.max_contacts_reported = 4

	# Position with offset
	var offset: Vector3 = limb_def.get("offset", Vector3.ZERO)
	limb.position = base_position + offset

	# Add to scene
	get_tree().root.add_child(limb)
	limb.global_position = limb.position

	# Calculate launch velocity
	var separation_dir := _get_limb_separation_direction(limb_type, hit_direction)
	var launch_velocity := (
		base_velocity * 0.5
		+ separation_dir * limb_separation_force
		+ Vector3.UP * randf_range(3.0, 6.0)
	)

	limb.linear_velocity = launch_velocity

	# Random spin
	limb.angular_velocity = Vector3(
		randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)
	)

	# Add blood trail
	_add_limb_blood_trail(limb)

	# Setup cleanup
	_setup_limb_cleanup(limb)

	# Spawn blood burst at separation point
	_spawn_separation_burst(base_position + offset)

	limb_severed.emit(LimbType.keys()[limb_type], base_position + offset)


func _create_limb_mesh(
	limb_type: LimbType,
	mesh_instance: MeshInstance3D,
	collision: CollisionShape3D,
	limb_def: Dictionary
) -> void:
	## Create mesh and collision for specific limb type
	var limb_size: Vector3 = limb_def.get("size", Vector3(0.3, 0.6, 0.3))
	var shape_type: String = limb_def.get("shape", "capsule")

	match shape_type:
		"capsule":
			var capsule_mesh := CapsuleMesh.new()
			capsule_mesh.radius = limb_size.x
			capsule_mesh.height = limb_size.y
			mesh_instance.mesh = capsule_mesh

			var capsule_shape := CapsuleShape3D.new()
			capsule_shape.radius = limb_size.x
			capsule_shape.height = limb_size.y
			collision.shape = capsule_shape

		"box":
			var box_mesh := BoxMesh.new()
			box_mesh.size = limb_size
			mesh_instance.mesh = box_mesh

			var box_shape := BoxShape3D.new()
			box_shape.size = limb_size
			collision.shape = box_shape

		"sphere":
			var sphere_mesh := SphereMesh.new()
			sphere_mesh.radius = limb_size.x
			mesh_instance.mesh = sphere_mesh

			var sphere_shape := SphereShape3D.new()
			sphere_shape.radius = limb_size.x
			collision.shape = sphere_shape

	# Apply material based on limb type
	var material := StandardMaterial3D.new()

	if limb_type == LimbType.HEAD:
		material.albedo_color = flesh_color.lightened(0.1)
	else:
		material.albedo_color = flesh_color

	material.roughness = 0.9
	material.metallic = 0.0
	mesh_instance.set_surface_override_material(0, material)


func _get_limb_separation_direction(limb_type: LimbType, hit_direction: Vector3) -> Vector3:
	## Get direction limb should fly based on type and hit
	var base_dir := Vector3.ZERO

	match limb_type:
		LimbType.HEAD:
			base_dir = Vector3.UP
		LimbType.ARM_LEFT:
			base_dir = Vector3.LEFT
		LimbType.ARM_RIGHT:
			base_dir = Vector3.RIGHT
		LimbType.LEG_LEFT:
			base_dir = Vector3.LEFT + Vector3.DOWN * 0.5
		LimbType.LEG_RIGHT:
			base_dir = Vector3.RIGHT + Vector3.DOWN * 0.5
		LimbType.TORSO:
			base_dir = Vector3.FORWARD

	# Blend with hit direction if provided
	if hit_direction.length() > 0.1:
		base_dir = (base_dir + hit_direction.normalized()).normalized()

	# Add randomness
	base_dir += Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.2), randf_range(-0.3, 0.3))

	return base_dir.normalized()


func _add_limb_blood_trail(limb: RigidBody3D) -> void:
	## Add blood particle trail to severed limb
	var particles := GPUParticles3D.new()
	limb.add_child(particles)

	particles.emitting = true
	particles.amount = 50
	particles.lifetime = 1.5
	particles.explosiveness = 0.0
	particles.randomness = 0.3

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.2
	material.direction = Vector3(0, -1, 0)
	material.spread = 30.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3(0, -10, 0)
	material.scale_min = 0.04
	material.scale_max = 0.1
	material.color = blood_color

	particles.process_material = material

	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	particles.draw_pass_1 = mesh

	# FIXED C-05: Store timer reference and use named method
	var timer := get_tree().create_timer(3.0)
	_blood_particle_timers.append(timer)
	timer.timeout.connect(_on_blood_particle_timeout.bind(particles))


func _on_blood_particle_timeout(particles: GPUParticles3D) -> void:
	## Called when blood particle timer completes
	if is_instance_valid(particles):
		particles.emitting = false


func _exit_tree() -> void:
	## FIXED C-05: Cleanup signal connections to prevent memory leaks
	for timer in _blood_particle_timers:
		if timer and timer.timeout.is_connected(_on_blood_particle_timeout):
			timer.timeout.disconnect(_on_blood_particle_timeout)
	_blood_particle_timers.clear()


func _spawn_separation_burst(burst_position: Vector3) -> void:
	## Spawn blood burst at limb separation point
	var particles := GPUParticles3D.new()
	get_tree().root.add_child(particles)
	particles.global_position = burst_position

	particles.emitting = true
	particles.one_shot = true
	particles.amount = 40
	particles.lifetime = 1.2
	particles.explosiveness = 1.0

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.2
	material.direction = Vector3.UP
	material.spread = 180.0
	material.initial_velocity_min = 6.0
	material.initial_velocity_max = 12.0
	material.gravity = Vector3(0, -15, 0)
	material.scale_min = 0.05
	material.scale_max = 0.12
	material.color = blood_color

	particles.process_material = material

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh

	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(particles.queue_free)


func _spawn_blood_fountain(fountain_position: Vector3) -> void:
	## Spawn continuous blood fountain effect
	var particles := GPUParticles3D.new()
	get_tree().root.add_child(particles)
	particles.global_position = fountain_position + Vector3.UP * 0.5

	particles.emitting = true
	particles.amount = 60
	particles.lifetime = 2.0
	particles.explosiveness = 0.0

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.3
	material.direction = Vector3.UP
	material.spread = 45.0
	material.initial_velocity_min = 4.0
	material.initial_velocity_max = 8.0
	material.gravity = Vector3(0, -12, 0)
	material.scale_min = 0.05
	material.scale_max = 0.1
	material.color = blood_color

	particles.process_material = material

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh

	# Stop fountain after 2 seconds
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(
		func() -> void:
			particles.emitting = false
			var cleanup := get_tree().create_timer(2.0)
			cleanup.timeout.connect(particles.queue_free)
	)


func _setup_limb_cleanup(limb: RigidBody3D) -> void:
	## Fade out and remove limb after lifetime
	await get_tree().create_timer(limb_lifetime * 0.7).timeout

	if not is_instance_valid(limb):
		return

	var mesh_instance := limb.get_child(0) as MeshInstance3D
	if mesh_instance:
		var mat: StandardMaterial3D = mesh_instance.get_surface_override_material(0)
		if mat:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var tween := limb.create_tween()
			tween.tween_property(mat, "albedo_color:a", 0.0, limb_lifetime * 0.3)
			tween.tween_callback(limb.queue_free)


func _setup_limb_definitions() -> void:
	## Define properties for each limb type
	_limb_definitions = {
		LimbType.HEAD:
		{
			"bone": "Head",
			"shape": "sphere",
			"size": Vector3(0.35, 0.35, 0.35),
			"offset": Vector3(0, 1.5, 0),
			"mass_multiplier": 1.2
		},
		LimbType.ARM_LEFT:
		{
			"bone": "LeftArm",
			"shape": "capsule",
			"size": Vector3(0.12, 0.7, 0.12),
			"offset": Vector3(-0.5, 1.0, 0),
			"mass_multiplier": 0.6
		},
		LimbType.ARM_RIGHT:
		{
			"bone": "RightArm",
			"shape": "capsule",
			"size": Vector3(0.12, 0.7, 0.12),
			"offset": Vector3(0.5, 1.0, 0),
			"mass_multiplier": 0.6
		},
		LimbType.LEG_LEFT:
		{
			"bone": "LeftUpLeg",
			"shape": "capsule",
			"size": Vector3(0.15, 0.9, 0.15),
			"offset": Vector3(-0.3, 0.3, 0),
			"mass_multiplier": 0.8
		},
		LimbType.LEG_RIGHT:
		{
			"bone": "RightUpLeg",
			"shape": "capsule",
			"size": Vector3(0.15, 0.9, 0.15),
			"offset": Vector3(0.3, 0.3, 0),
			"mass_multiplier": 0.8
		},
		LimbType.TORSO:
		{
			"bone": "Spine",
			"shape": "box",
			"size": Vector3(0.6, 0.8, 0.4),
			"offset": Vector3(0, 1.0, 0),
			"mass_multiplier": 2.0
		}
	}


func _load_config() -> void:
	## Load configuration from get_node_or_null("/root/GameManager").get_core_system("config") if get_node_or_null("/root/GameManager") else null
	var config: Node = get_node_or_null("/root/GameManager").get_core_system("config") if get_node_or_null("/root/GameManager") else null
	if not config or not config.has_method("get_value"):
		return

	var config_result: Variant = config.get_value("visuals.gore")
	if config_result == null or not config_result is Dictionary:
		return

	var config_data: Dictionary = config_result
	if not config_data.is_empty():
		_apply_config(config_data)


func _apply_config(config: Dictionary) -> void:
	## Apply loaded configuration
	if config.has("advanced_gore"):
		var gore: Dictionary = config["advanced_gore"]
		enabled = gore.get("dismemberment_enabled", enabled)

	if config.has("dismemberment"):
		var dismember: Dictionary = config["dismemberment"]
		overkill_threshold = dismember.get("overkill_threshold", overkill_threshold)
		limb_separation_force = dismember.get("separation_force", limb_separation_force)
		limb_lifetime = dismember.get("lifetime", limb_lifetime)
		limb_mass = dismember.get("mass", limb_mass)
		limb_bounce = dismember.get("bounce", limb_bounce)
		limb_friction = dismember.get("friction", limb_friction)
		limb_gravity_scale = dismember.get("gravity_scale", limb_gravity_scale)
		spawn_blood_fountain = dismember.get("blood_fountain", spawn_blood_fountain)
		var logger: Node = get_node_or_null("/root/GameManager").get_core_system("logger") if get_node_or_null("/root/GameManager") else null
		if logger and logger.has_method("info"):
			logger.info(
				"[DismembermentSystem] Config loaded - overkill_threshold: %d" % overkill_threshold,
				"Core"
			)


func set_enabled(value: bool) -> void:
	## Enable or disable dismemberment
	enabled = value
