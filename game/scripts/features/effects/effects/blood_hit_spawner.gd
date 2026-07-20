class_name BloodHitSpawner
extends Node

signal blood_spawned(droplet_count: int, position: Vector3)

const MAX_POOL_SIZE: int = 100
const CONFIG_PATH := "res://game/config/gameplay/blood_effects_config.json"

@export_group("Droplet Settings")
@export var droplet_count_base: int = 15  # Increased from 5
@export var droplet_count_per_damage: float = 0.2  # Increased from 0.1
@export var droplet_count_min: int = 10  # Increased from 3
@export var droplet_count_max: int = 40  # Increased from 15
@export var blood_spray_multiplier: int = 3  # Number of spray bursts per hit
@export var droplet_size_min: float = 0.015  # Reduced from 0.02
@export var droplet_size_max: float = 0.035  # Reduced from 0.05
@export_group("Velocity")
@export var velocity_min: float = 3.0
@export var velocity_max: float = 8.0
@export var upward_velocity_min: float = 1.0
@export var upward_velocity_max: float = 3.0
@export var spread_angle_horizontal: float = 60.0
@export var spread_angle_vertical: float = 30.0
@export_group("Physics")
@export var droplet_gravity: float = 15.0
@export var bounce_factor: float = 0.2
@export var friction: float = 0.7
@export var lifetime_min: float = 0.8
@export var lifetime_max: float = 1.5
@export var fade_start_percent: float = 0.5
@export_group("Visual")
@export var blood_color: Color = Color(0.9, 0.02, 0.02)  # Brighter arterial red
@export var use_gpu_particles: bool = true
@export var spawn_decals: bool = true
@export var decal_size: float = 0.15
@export_group("Advanced Systems")
@export var use_directional_spray: bool = true
@export var spawn_blood_mist: bool = true  # New blood mist effect
@export var blood_pool_accumulation_chance: float = 0.7  # Chance to spawn pool where spray lands

var _droplet_pool: Array[RigidBody3D] = []
var _active_droplets: Array[RigidBody3D] = []
var _directional_spray: DirectionalBloodSpray


func _ready() -> void:
	_load_config()
	# Ensure color is bright if config failed or was default
	if blood_color.r < 0.7 and blood_color.g < 0.1:
		blood_color = Color(0.9, 0.02, 0.02)

	_prewarm_pool()
	_setup_advanced_systems()


func _setup_advanced_systems() -> void:
	## Initialize advanced gore systems

	if use_directional_spray:
		_directional_spray = DirectionalBloodSpray.new()
		add_child(_directional_spray)


func spawn_blood(
	blood_position: Vector3,
	hit_normal: Vector3,
	damage: int = 10,
	hit_velocity: Vector3 = Vector3.ZERO
) -> void:
	# Optional Gore System
	var gm: Node = get_node_or_null("/root/GameManager")
	var config: Node = gm.get_core_system("config") if gm else null
	if not config or not config.has_method("is_feature_enabled"):
		return
	if not config.is_feature_enabled("gore"):
		return
	call_deferred("_finish_spawn_blood", blood_position, hit_normal, damage, hit_velocity)


func _finish_spawn_blood(
	blood_position: Vector3, hit_normal: Vector3, damage: int, hit_velocity: Vector3
) -> void:
	## Spawn blood droplets at hit position
	## Args:
	##   blood_position: World position of hit
	##   hit_normal: Surface normal (direction blood sprays)
	##   damage: Damage dealt (scales droplet count)
	##   hit_velocity: Velocity of projectile (inherited by droplets)

	# Spawn multiple blood spray bursts for more intense effect
	for i in range(blood_spray_multiplier):
		var offset := Vector3(
			randf_range(-0.1, 0.1), randf_range(-0.05, 0.05), randf_range(-0.1, 0.1)
		)
		var spray_pos := blood_position + offset
		var spray_normal := hit_normal.rotated(Vector3.UP, randf_range(-0.3, 0.3))

		if use_gpu_particles:
			_spawn_gpu_particles(spray_pos, spray_normal, damage, hit_velocity)
		else:
			_spawn_physics_droplets(spray_pos, spray_normal, damage, hit_velocity)

		# Spawn blood pool where spray lands (with chance)
		if randf() < blood_pool_accumulation_chance:
			_spawn_delayed_blood_pool(spray_pos, spray_normal)

	# Spawn blood mist effect
	if spawn_blood_mist:
		_spawn_blood_mist(blood_position, hit_normal, damage)

	# Spawn directional spray if enabled
	if use_directional_spray and _directional_spray and hit_velocity.length() > 0.1:
		var hit_direction := hit_velocity.normalized()
		_directional_spray.spawn_directional_spray(blood_position, hit_direction, damage)


func _spawn_gpu_particles(
	particle_position: Vector3, hit_normal: Vector3, damage: int, hit_velocity: Vector3
) -> void:
	## Spawn GPU-accelerated particle burst with retro pixelated style
	var particles := GPUParticles3D.new()
	get_tree().root.add_child(particles)
	particles.global_position = particle_position

	# Calculate droplet count based on damage
	var count := _calculate_droplet_count(damage)

	particles.emitting = true
	particles.one_shot = true
	particles.amount = count
	particles.lifetime = randf_range(lifetime_min, lifetime_max)
	particles.explosiveness = 0.8

	# Create particle material
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.1

	# Direction based on hit normal
	material.direction = hit_normal
	material.spread = spread_angle_horizontal
	material.flatness = 1.0 - (spread_angle_vertical / 90.0)

	# Velocity
	material.initial_velocity_min = velocity_min
	material.initial_velocity_max = velocity_max
	material.gravity = Vector3(0, -droplet_gravity, 0)

	# Inherit projectile velocity
	if hit_velocity.length() > 0.1:
		material.inherit_velocity_ratio = 0.3

	# Size variation - chunky retro droplets (smaller)
	material.scale_min = droplet_size_min * 1.5  # Reduced multiplier
	material.scale_max = droplet_size_max * 1.5  # Reduced multiplier

	# Color
	material.color = blood_color

	particles.process_material = material

	# Create chunky retro-style BOX mesh (cubic particles, not flat) - smaller size
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 0.035)  # Reduced from 0.05

	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = blood_color
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES  # Proper rotation
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.vertex_color_use_as_albedo = true  # Use particle color
	mesh.material = mesh_mat

	particles.draw_pass_1 = mesh

	# Cleanup
	var timer := get_tree().create_timer(particles.lifetime + 0.5)
	timer.timeout.connect(particles.queue_free)

	blood_spawned.emit(count, particle_position)


func _spawn_physics_droplets(
	droplet_position: Vector3, hit_normal: Vector3, damage: int, hit_velocity: Vector3
) -> void:
	## Spawn individual physics-based droplets (more expensive but bounces)
	var count := _calculate_droplet_count(damage)

	for i: int in range(count):
		var droplet := _get_droplet_from_pool()
		if not droplet:
			continue

		droplet.global_position = droplet_position + hit_normal * 0.1

		# Calculate spray direction
		var h_angle := deg_to_rad(
			randf_range(-spread_angle_horizontal / 2.0, spread_angle_horizontal / 2.0)
		)
		var v_angle := deg_to_rad(
			randf_range(-spread_angle_vertical / 2.0, spread_angle_vertical / 2.0)
		)

		var direction := hit_normal.rotated(Vector3.UP, h_angle)
		direction = direction.rotated(direction.cross(Vector3.UP), v_angle)

		# Apply velocity
		var speed := randf_range(velocity_min, velocity_max)
		var upward := randf_range(upward_velocity_min, upward_velocity_max)
		var velocity := direction * speed + Vector3.UP * upward

		# Inherit some projectile velocity
		velocity += hit_velocity * 0.2

		droplet.linear_velocity = velocity

		# Random spin
		droplet.angular_velocity = Vector3(
			randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5)
		)

		# Setup cleanup
		_setup_droplet_lifetime(droplet)

	blood_spawned.emit(count, droplet_position)


func _get_droplet_from_pool() -> RigidBody3D:
	## Get droplet from pool or create new one
	if _droplet_pool.size() > 0:
		var droplet: RigidBody3D = _droplet_pool.pop_back()
		droplet.show()
		_active_droplets.append(droplet)
		return droplet

	# Create new droplet
	return _create_droplet()


func _create_droplet() -> RigidBody3D:
	## Create a new blood droplet with physics
	var droplet := RigidBody3D.new()
	droplet.add_to_group("blood_droplets")

	# Random size (chunky style)
	var droplet_s := randf_range(droplet_size_min, droplet_size_max)

	# Create mesh - USE BOX for retro cubic droplets
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(droplet_s, droplet_s, droplet_s)  # Cubic droplets
	mesh_instance.mesh = box_mesh

	# Blood material
	var material := StandardMaterial3D.new()
	material.albedo_color = blood_color
	material.roughness = 0.9
	material.metallic = 0.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.set_surface_override_material(0, material)

	# Collision - USE BOX for cubic collision
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(droplet_s, droplet_s, droplet_s)
	collision.shape = box_shape

	droplet.add_child(mesh_instance)
	droplet.add_child(collision)

	# Physics properties
	droplet.mass = 0.05
	droplet.gravity_scale = droplet_gravity / 9.8
	droplet.physics_material_override = PhysicsMaterial.new()
	droplet.physics_material_override.bounce = bounce_factor
	droplet.physics_material_override.friction = friction
	droplet.contact_monitor = true
	droplet.max_contacts_reported = 2

	# Add to scene
	get_tree().root.add_child(droplet)
	_active_droplets.append(droplet)

	# Connect collision for decals
	if spawn_decals:
		droplet.body_entered.connect(_on_droplet_collision.bind(droplet))

	return droplet


func _setup_droplet_lifetime(droplet: RigidBody3D) -> void:
	## Setup fade and cleanup for droplet
	var lifetime := randf_range(lifetime_min, lifetime_max)
	var fade_start := lifetime * fade_start_percent

	await get_tree().create_timer(fade_start).timeout

	if not is_instance_valid(droplet):
		return

	# Start fading
	var mesh_instance := droplet.get_child(0) as MeshInstance3D
	if mesh_instance:
		var mat: StandardMaterial3D = mesh_instance.get_surface_override_material(0)
		if mat:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var tween := droplet.create_tween()
			tween.tween_property(mat, "albedo_color:a", 0.0, lifetime - fade_start)
			tween.tween_callback(_return_droplet_to_pool.bind(droplet))


func _return_droplet_to_pool(droplet: RigidBody3D) -> void:
	## Return droplet to pool for reuse
	if not is_instance_valid(droplet):
		return

	droplet.hide()
	droplet.linear_velocity = Vector3.ZERO
	droplet.angular_velocity = Vector3.ZERO
	_active_droplets.erase(droplet)

	if _droplet_pool.size() < MAX_POOL_SIZE:
		_droplet_pool.append(droplet)
	else:
		droplet.queue_free()


func _on_droplet_collision(_body: Node, droplet: RigidBody3D) -> void:
	## Spawn small blood decal when droplet hits surface
	if not spawn_decals or not is_instance_valid(droplet):
		return

	# Only spawn decal if moving fast enough
	if droplet.linear_velocity.length() < 1.0:
		return

	_spawn_blood_decal(droplet.global_position)


func _spawn_blood_decal(decal_position: Vector3) -> void:
	call_deferred("_finish_spawn_blood_decal", decal_position)


func _finish_spawn_blood_decal(decal_position: Vector3) -> void:
	## Spawn blood pool using shader-based mesh for better visuals
	_spawn_shader_blood_pool(decal_position)


func _spawn_shader_blood_pool(pool_position: Vector3) -> void:
	## Spawn blood pool decal using texture from decals folder
	var decal := Sprite3D.new()
	decal.name = "BloodPoolDecal"

	# Configure as decal-like sprite for GLES3 compatibility
	decal.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	decal.shaded = false
	decal.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	decal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	decal.no_depth_test = false
	decal.layers = 0xFFFFF

	# Random blood splat texture
	var blood_textures: Array[String] = [
		"res://game/art/textures/decals/blood_splat.png",
		"res://game/art/textures/decals/mid_blood_splat.png",
		"res://game/art/textures/decals/smol_blood_splat.png",
	]

	var texture_path: String = blood_textures[randi() % blood_textures.size()]
	decal.texture = load(texture_path)

	# Configure decal
	var pool_size := randf_range(decal_size * 1.5, decal_size * 3.0)
	decal.pixel_size = pool_size / 64.0

	# Random rotation for variety
	decal.rotate_object_local(Vector3.FORWARD, randf_range(0, TAU))

	# Slight offset to prevent z-fighting	pool_position.y += 0.02

	get_tree().root.add_child(decal)
	decal.global_position = pool_position

	# Point decal downward
	decal.rotation.x = -PI / 2.0

	# Fade out and cleanup after delay
	await get_tree().create_timer(15.0).timeout

	if is_instance_valid(decal):
		var tween := decal.create_tween()
		tween.tween_property(decal, "modulate:a", 0.0, 3.0)
		tween.tween_callback(decal.queue_free)


func _calculate_droplet_count(damage: int) -> int:
	## Calculate number of droplets based on damage
	var count := droplet_count_base + int(damage * droplet_count_per_damage)
	return clampi(count, droplet_count_min, droplet_count_max)


func _prewarm_pool() -> void:
	## Pre-create some droplets for the pool
	if use_gpu_particles:
		return

	for i: int in range(10):
		var droplet := _create_droplet()
		droplet.hide()
		_active_droplets.erase(droplet)
		_droplet_pool.append(droplet)


func _load_config() -> void:
	## Load blood effects configuration via GameManager.get_core_system("config")
	var gm: Node = get_node_or_null("/root/GameManager")
	var config: Node = gm.get_core_system("config") if gm else null
	if not config or not config.has_method("get_value"):
		return

	droplet_count_base = int(config.get_value("visuals.gore.gib_count_min", droplet_count_base))
	droplet_count_min = int(config.get_value("visuals.gore.gib_count_min", droplet_count_min))
	droplet_count_max = int(config.get_value("visuals.gore.gib_count_max", droplet_count_max))

	# Load color
	var color_dict: Dictionary = config.get_value("visuals.gore.blood_spray.color", {})
	if not color_dict.is_empty():
		blood_color = Color(
			color_dict.get("r", 0.6), color_dict.get("g", 0.0), color_dict.get("b", 0.0)
		)


func clear_all_blood() -> void:
	## Clear all active blood droplets
	for droplet: RigidBody3D in _active_droplets.duplicate():
		_return_droplet_to_pool(droplet)


var _retro_blood_texture: ImageTexture = null


func _get_retro_blood_texture() -> ImageTexture:
	## Get or create cached retro pixelated blood texture
	if _retro_blood_texture:
		return _retro_blood_texture

	# Create chunky 8x8 pixel texture
	var size: int = 8
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius: float = size / 2.0 - 0.5

	for y in size:
		for x in size:
			var dist: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
			if dist <= radius:
				image.set_pixel(x, y, Color(1, 1, 1, 1))
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))

	_retro_blood_texture = ImageTexture.create_from_image(image)
	return _retro_blood_texture


func _spawn_blood_mist(mist_position: Vector3, hit_normal: Vector3, damage: int) -> void:
	## Spawn blood mist particle effect for visceral impact
	var mist := GPUParticles3D.new()
	get_tree().root.add_child(mist)
	mist.global_position = mist_position

	mist.emitting = true
	mist.one_shot = true
	mist.amount = int(20 + damage * 0.5)  # Scale with damage
	mist.lifetime = 0.8
	mist.explosiveness = 1.0

	# Create mist material
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.2

	# Direction based on hit normal
	material.direction = hit_normal
	material.spread = 80.0  # Wide spread for mist
	material.flatness = 0.3

	# Velocity - slower than droplets
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 3.0
	material.gravity = Vector3(0, -2.0, 0)  # Light gravity

	# Size - larger particles for mist
	material.scale_min = 0.15
	material.scale_max = 0.35
	var scale_curve_tex := CurveTexture.new()
	scale_curve_tex.curve = _create_mist_scale_curve()
	material.scale_curve = scale_curve_tex

	# Color - semi-transparent red mist
	var mist_color := Color(blood_color.r, blood_color.g, blood_color.b, 0.25)
	material.color = mist_color

	# Fade out over lifetime
	var alpha_curve_tex := CurveTexture.new()
	alpha_curve_tex.curve = _create_mist_alpha_curve()
	material.alpha_curve = alpha_curve_tex

	mist.process_material = material

	# Create mist mesh - spherical particles
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 4

	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = mist_color
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.vertex_color_use_as_albedo = true
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mesh_mat

	mist.draw_pass_1 = mesh

	# Cleanup
	var timer := get_tree().create_timer(mist.lifetime + 0.5)
	timer.timeout.connect(mist.queue_free)


func _create_mist_scale_curve() -> Curve:
	## Create curve for mist particle scaling (grow then shrink)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))  # Start small
	curve.add_point(Vector2(0.3, 1.0))  # Grow quickly
	curve.add_point(Vector2(1.0, 0.5))  # Shrink at end
	return curve


func _create_mist_alpha_curve() -> Curve:
	## Create curve for mist particle alpha (fade out)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))  # Start less visible (was 0.8)
	curve.add_point(Vector2(0.5, 0.4))  # Stay subtle (was 0.6)
	curve.add_point(Vector2(1.0, 0.0))  # Fade to transparent
	return curve


func _spawn_delayed_blood_pool(pool_position: Vector3, _hit_normal: Vector3) -> void:
	## Spawn blood pool after a short delay (simulating blood landing)
	await get_tree().create_timer(randf_range(0.1, 0.3)).timeout

	# Raycast downward to find ground
	var space_state := get_tree().root.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		pool_position, pool_position + Vector3.DOWN * 5.0
	)
	query.collision_mask = 1  # World layer

	var result := space_state.intersect_ray(query)
	if result:
		_spawn_shader_blood_pool(result.position)
	else:
		# Fallback to original position
		_spawn_shader_blood_pool(pool_position)
