class_name GoreSystem
extends Node

## Manages gore effects (blood, gibs, dismemberment)
## Extracted from EffectsService for better separation
## Now includes blood pool shader integration

var spawn_gibs: bool = true
var gib_count_min: int = 3  # Increased from 2
var gib_count_max: int = 6  # Increased from 4
var gib_lifetime: float = 10.0
var gib_force_multiplier: float = 5.0
var blood_spray_intensity: float = 2.0  # Increased from 1.0
var blood_decal_count: int = 8  # Increased from 3
var blood_color: Color = Color(0.6, 0.0, 0.0)

# Blood pool shader settings
var enable_blood_pools: bool = true  # Re-enabled with fixed textures
var blood_pool_intensity: float = 1.0
var blood_trail_enabled: bool = true
var blood_trail_density: int = 3

var _decal_spawner: DecalSpawner
var _particle_spawner: ParticleSpawner
var _blood_pool_manager: BloodPoolManager


func setup(
	decal_spawn: DecalSpawner,
	particle_spawn: ParticleSpawner,
	blood_pool_mgr: BloodPoolManager = null
) -> void:
	_decal_spawner = decal_spawn
	_particle_spawner = particle_spawn
	_blood_pool_manager = blood_pool_mgr


func load_config(config_getter: Callable) -> void:
	spawn_gibs = config_getter.call("visuals.gore.spawn_gibs", spawn_gibs)
	gib_count_min = int(config_getter.call("visuals.gore.gib_count_min", gib_count_min))
	gib_count_max = int(config_getter.call("visuals.gore.gib_count_max", gib_count_max))
	gib_lifetime = config_getter.call("visuals.gore.gib_lifetime", gib_lifetime)
	gib_force_multiplier = config_getter.call(
		"visuals.gore.gib_force_multiplier", gib_force_multiplier
	)
	blood_spray_intensity = config_getter.call(
		"visuals.gore.blood_spray.intensity", blood_spray_intensity
	)
	blood_decal_count = int(
		config_getter.call("visuals.gore.blood_spray.decal_count", blood_decal_count)
	)

	# Blood pool shader settings
	enable_blood_pools = config_getter.call("visuals.gore.blood_pools.enabled", enable_blood_pools)
	blood_pool_intensity = config_getter.call(
		"visuals.gore.blood_pools.intensity", blood_pool_intensity
	)
	blood_trail_enabled = config_getter.call(
		"visuals.gore.blood_pools.trail_enabled", blood_trail_enabled
	)
	blood_trail_density = int(
		config_getter.call("visuals.gore.blood_pools.trail_density", blood_trail_density)
	)

	var spray_color: Dictionary = config_getter.call("visuals.gore.blood_spray.color", {})
	if not spray_color.is_empty():
		blood_color = Color(
			spray_color.get("r", 0.6), spray_color.get("g", 0.0), spray_color.get("b", 0.0)
		)


func spawn_gore_effect(
	position: Vector3, death_direction: Vector3 = Vector3.ZERO, intensity: float = 1.0
) -> void:
	# Spawn gibs
	if spawn_gibs:
		_spawn_gibs(position, death_direction, intensity)

	# Spawn blood spray
	_spawn_blood_spray(position, death_direction, intensity)

	# Spawn blood decals
	for i in range(blood_decal_count):
		var offset: Vector3 = Vector3(
			randf_range(-0.5, 0.5), randf_range(-0.2, 0.2), randf_range(-0.5, 0.5)
		)
		var decal_pos: Vector3 = position + offset
		var normal: Vector3 = (
			Vector3.DOWN
			if i == 0
			else Vector3(randf_range(-1, 1), -1, randf_range(-1, 1)).normalized()
		)

		if _decal_spawner:
			_decal_spawner.spawn_blood_decal(decal_pos, normal)

	# Spawn blood pool shader effect
	if enable_blood_pools and _blood_pool_manager:
		_spawn_blood_pool_splatter(position, intensity)


func spawn_blood_synced(position: Vector3, normal: Vector3, intensity: float = 1.0) -> void:
	if not _particle_spawner:
		return

	# Spawn multiple blood spray bursts for more intense effect
	var spray_count := int(2 + intensity)
	for i in range(spray_count):
		var offset := Vector3(
			randf_range(-0.15, 0.15), randf_range(-0.1, 0.1), randf_range(-0.15, 0.15)
		)
		var spray_pos := position + offset
		var spray_normal := normal.rotated(Vector3.UP, randf_range(-0.4, 0.4))

		var particles: GPUParticles3D = _particle_spawner.spawn_particles(
			"res://game/scenes/effects/blood_spray.tscn", spray_pos, Vector3.ZERO, null, 1.0
		)

		if particles:
			var mat: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
			if mat:
				mat.direction = spray_normal
				mat.initial_velocity_min *= intensity
				mat.initial_velocity_max *= intensity

	# Add blood pool effects
	if enable_blood_pools and _blood_pool_manager:
		# Spawn multiple blood pools
		for i in range(int(3 + intensity * 2)):
			var offset := Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
			_blood_pool_manager.spawn_blood_at_world_position(position + offset)

	# NEW: Spawn a blood decal on the surface for every hit
	if _decal_spawner:
		_decal_spawner.spawn_blood_decal(position, normal)


func _spawn_gibs(position: Vector3, direction: Vector3, intensity: float) -> void:
	var pool_service: Node = GameManager.get_core_system("pools")
	if not pool_service:
		return

	var gib_count: int = randi_range(gib_count_min, gib_count_max)
	gib_count = int(gib_count * intensity)

	for i in range(gib_count):
		var gib: Node3D = (
			pool_service.get_instance("gib") if pool_service.has_method("get_instance") else null
		)
		if not gib:
			continue

		if not gib.get_parent():
			get_tree().root.add_child(gib)

		gib.global_position = position

		# Apply force
		if gib is RigidBody3D:
			var force_dir: Vector3 = (
				direction
				if direction != Vector3.ZERO
				else (
					Vector3(randf_range(-1, 1), randf_range(0.5, 1), randf_range(-1, 1))
					. normalized()
				)
			)

			var force: Vector3 = force_dir * randf_range(3, 8) * gib_force_multiplier
			gib.linear_velocity = force
			gib.angular_velocity = Vector3(
				randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)
			)

		# Cleanup
		var pool_ref: Node = pool_service
		get_tree().create_timer(gib_lifetime).timeout.connect(
			func() -> void:
				if is_instance_valid(gib) and pool_ref and pool_ref.has_method("return_instance"):
					pool_ref.return_instance(gib)
		)


func _spawn_blood_spray(position: Vector3, direction: Vector3, intensity: float) -> void:
	if not _particle_spawner:
		return

	# Spawn multiple blood spray bursts for more intense effect
	var spray_count := int(2 + intensity)
	for i in range(spray_count):
		var offset := Vector3(
			randf_range(-0.2, 0.2), randf_range(-0.1, 0.1), randf_range(-0.2, 0.2)
		)
		var spray_pos := position + offset
		var spray_dir := direction if direction != Vector3.ZERO else Vector3.UP
		spray_dir = spray_dir.rotated(Vector3.UP, randf_range(-0.5, 0.5))

		var particles: GPUParticles3D = _particle_spawner.spawn_particles(
			"res://game/scenes/effects/blood_spray.tscn", spray_pos, Vector3.ZERO, null, 2.0
		)

		if particles:
			var mat: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
			if mat:
				mat.direction = spray_dir
				mat.initial_velocity_min *= blood_spray_intensity * intensity
				mat.initial_velocity_max *= blood_spray_intensity * intensity
				mat.color = blood_color


## Spawn a limb gib (for dismemberment)
func spawn_limb_gib(
	position: Vector3, bone_name: String, limb_color: Color, launch_direction: Vector3
) -> void:
	# CRITICAL: Spawn actual limb mesh, not procedural gib chunks
	# Load the mannequin limb scene based on bone name
	var limb_scene_path: String = _get_limb_scene_path(bone_name)

	if limb_scene_path.is_empty() or not ResourceLoader.exists(limb_scene_path):
		# Fallback to generic gib if limb scene not found
		_spawn_generic_gib(position, limb_color, launch_direction)
		return

	var limb_scene: PackedScene = load(limb_scene_path)
	if not limb_scene:
		_spawn_generic_gib(position, limb_color, launch_direction)
		return

	var limb: Node3D = limb_scene.instantiate()
	if not limb:
		return

	get_tree().root.add_child(limb)
	limb.global_position = position

	# Set color if the limb supports it
	if limb.has_method("set_color"):
		limb.set_color(limb_color)
	elif "modulate" in limb:
		limb.modulate = limb_color

	# Apply launch force
	if limb is RigidBody3D:
		var force: Vector3 = launch_direction * randf_range(5, 10) * gib_force_multiplier
		limb.linear_velocity = force
		limb.angular_velocity = Vector3(
			randf_range(-15, 15), randf_range(-15, 15), randf_range(-15, 15)
		)

	# Cleanup after lifetime
	get_tree().create_timer(gib_lifetime).timeout.connect(
		func() -> void:
			if is_instance_valid(limb):
				limb.queue_free()
	)

	# Spawn blood trail effect
	if _particle_spawner:
		_particle_spawner.spawn_particles(
			"res://game/scenes/effects/blood_spray.tscn", position, Vector3.ZERO, null, 1.0
		)


func _get_limb_scene_path(bone_name: String) -> String:
	## Map bone names to limb scene paths
	var bone_lower: String = bone_name.to_lower()

	# Check for specific limb types
	if "head" in bone_lower or "skull" in bone_lower:
		return "res://game/entities/effects/limbs/head_gib.tscn"
	if "arm" in bone_lower or "hand" in bone_lower or "shoulder" in bone_lower:
		if "left" in bone_lower or "l_" in bone_lower:
			return "res://game/entities/effects/limbs/left_arm_gib.tscn"
		return "res://game/entities/effects/limbs/right_arm_gib.tscn"
	if "leg" in bone_lower or "foot" in bone_lower or "thigh" in bone_lower or "calf" in bone_lower:
		if "left" in bone_lower or "l_" in bone_lower:
			return "res://game/entities/effects/limbs/left_leg_gib.tscn"
		return "res://game/entities/effects/limbs/right_leg_gib.tscn"
	if "torso" in bone_lower or "spine" in bone_lower or "chest" in bone_lower:
		return "res://game/entities/effects/limbs/torso_gib.tscn"

	return ""  # No specific limb found


func _spawn_generic_gib(position: Vector3, limb_color: Color, launch_direction: Vector3) -> void:
	## Fallback: spawn generic gib chunk
	var pool_service: Node = GameManager.get_core_system("pools")
	if not pool_service:
		return

	var gib: Node3D = (
		pool_service.get_instance("gib") if pool_service.has_method("get_instance") else null
	)
	if not gib:
		return

	if not gib.get_parent():
		get_tree().root.add_child(gib)

	gib.global_position = position

	# Set color if the gib supports it
	if gib.has_method("set_color"):
		gib.set_color(limb_color)
	elif "color" in gib:
		gib.color = limb_color

	# Apply launch force
	if gib is RigidBody3D:
		var force: Vector3 = launch_direction * randf_range(5, 10) * gib_force_multiplier
		gib.linear_velocity = force
		gib.angular_velocity = Vector3(
			randf_range(-15, 15), randf_range(-15, 15), randf_range(-15, 15)
		)

	# Cleanup after lifetime
	var pool_ref: Node = pool_service
	get_tree().create_timer(gib_lifetime).timeout.connect(
		func() -> void:
			if is_instance_valid(gib) and pool_ref and pool_ref.has_method("return_instance"):
				pool_ref.return_instance(gib)
	)


## Spawn blood pool splatter effect
func _spawn_blood_pool_splatter(position: Vector3, intensity: float) -> void:
	if not _blood_pool_manager:
		return

	var adjusted_intensity: float = intensity * blood_pool_intensity
	var radius: float = 0.3 + (adjusted_intensity * 0.5)
	var drop_count: int = int(5 + (adjusted_intensity * 10))

	_blood_pool_manager.spawn_blood_splatter(position, radius, drop_count)


## Spawn blood trail for moving/bleeding entities
func spawn_blood_trail(start_pos: Vector3, end_pos: Vector3, intensity: float = 1.0) -> void:
	if not enable_blood_pools or not blood_trail_enabled or not _blood_pool_manager:
		return

	var drops: int = int(blood_trail_density * intensity)
	_blood_pool_manager.spawn_blood_trail(start_pos, end_pos, drops)


## Spawn single blood drop at position
func spawn_blood_drop(position: Vector3) -> void:
	if not enable_blood_pools or not _blood_pool_manager:
		return

	_blood_pool_manager.spawn_blood_at_world_position(position)


## Set blood pool manager reference (can be called after setup)
func set_blood_pool_manager(manager: BloodPoolManager) -> void:
	_blood_pool_manager = manager


## Check if blood pools are available
func has_blood_pools() -> bool:
	return enable_blood_pools and _blood_pool_manager != null
