class_name DirectionalBloodSpray
extends Node

signal spray_spawned(position: Vector3, direction: Vector3)

const CONFIG_PATH := "res://game/config/gameplay/blood_effects_config.json"
const PROCEDURAL_SPLAT_GENERATOR := preload(
	"res://game/scripts/features/effects/effects/procedural_splat_generator.gd"
)
const RETRO_BLOOD_SHADER = preload("res://game/art/shaders/retro_blood.gdshader")

@export_group("Spray Settings")
@export var enabled: bool = true
@export var spray_distance: float = 5.0
@export var spray_particle_count: int = 30
@export var spray_cone_angle: float = 45.0
@export var spray_velocity_min: float = 8.0
@export var spray_velocity_max: float = 15.0
@export_group("Decal Settings")
@export var spawn_wall_decals: bool = true
@export var decal_count_min: int = 3
@export var decal_count_max: int = 8
@export var decal_size_min: float = 0.3
@export var decal_size_max: float = 0.8
@export var decal_lifetime: float = 30.0
@export_group("Visual")
@export var blood_color: Color = Color(0.9, 0.02, 0.02)
@export var spray_opacity: float = 0.8


func _ready() -> void:
	_load_config()


func _load_config() -> void:
	## Load configuration from JSON
	if not FileAccess.file_exists(CONFIG_PATH):
		return

	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		return

	var config: Dictionary = json.data
	_apply_config(config)


func _apply_config(config: Dictionary) -> void:
	## Apply loaded configuration values
	if config.has("advanced_gore"):
		var gore: Dictionary = config["advanced_gore"]
		enabled = gore.get("directional_spray_enabled", enabled)


func spawn_directional_spray(
	hit_position: Vector3, hit_direction: Vector3, damage: int = 10
) -> void:
	## Spawn directional blood spray based on projectile direction
	if not enabled:
		return

	# Cap damage influence on counts to prevent exponential lag
	var effective_damage: int = clampi(damage, 0, 50)

	# Spawn particle spray
	_spawn_spray_particles(hit_position, hit_direction, effective_damage)

	# Raycast to find surfaces for decals
	if spawn_wall_decals:
		_spawn_surface_decals(hit_position, hit_direction, effective_damage)

	spray_spawned.emit(hit_position, hit_direction)


func _spawn_spray_particles(spray_position: Vector3, direction: Vector3, damage: int) -> void:
	## Spawn GPU particle spray in hit direction
	var particles := GPUParticles3D.new()

	# Add to current scene or GameCore instead of root
	var parent: Node = get_tree().current_scene
	if not parent:
		parent = get_tree().root
	parent.add_child(particles)

	particles.global_position = spray_position

	# Scale particle count more conservatively
	var particle_count := spray_particle_count + int(damage * 0.3)
	particle_count = clampi(particle_count, 5, 40)  # Lower cap

	particles.emitting = true
	particles.one_shot = true
	particles.amount = particle_count
	particles.lifetime = 1.0  # Shorter lifetime
	particles.explosiveness = 0.9

	# Create directional spray material
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.1

	# Spray in hit direction
	material.direction = direction
	material.spread = spray_cone_angle
	material.initial_velocity_min = spray_velocity_min * 0.5
	material.initial_velocity_max = spray_velocity_max
	material.gravity = Vector3(0, -12, 0)
	material.scale_min = 0.04
	material.scale_max = 0.08
	material.color = blood_color

	particles.process_material = material

	# Create particle mesh
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06

	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = blood_color
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mesh_mat

	particles.draw_pass_1 = mesh

	# Cleanup
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(particles.queue_free)


func _spawn_surface_decals(spray_origin: Vector3, direction: Vector3, damage: int) -> void:
	## Raycast in spray cone to find surfaces and spawn decals
	var decal_count := randi_range(decal_count_min, decal_count_max)
	decal_count += int(damage * 0.05)
	decal_count = clampi(decal_count, 1, 6)  # Much more conservative

	var world := get_tree().root.get_world_3d()
	if not world:
		return

	var space_state := world.direct_space_state

	for i: int in range(decal_count):
		# Random direction within spray cone
		var spray_dir := _get_random_spray_direction(direction)

		# Raycast to find surface
		var ray_end := spray_origin + spray_dir * spray_distance
		var query := PhysicsRayQueryParameters3D.create(spray_origin, ray_end)
		query.collision_mask = 1  # World geometry

		var result := space_state.intersect_ray(query)
		if result:
			_spawn_blood_decal_on_surface(result.position, result.normal)


func _get_random_spray_direction(base_direction: Vector3) -> Vector3:
	## Get random direction within spray cone
	var cone_rad := deg_to_rad(spray_cone_angle)

	# Random angle within cone
	var angle := randf_range(0, TAU)
	var radius := randf_range(0, tan(cone_rad))

	# Create perpendicular vectors
	var up := Vector3.UP
	if abs(base_direction.dot(Vector3.UP)) > 0.9:
		up = Vector3.RIGHT
	var right := base_direction.cross(up).normalized()
	up = right.cross(base_direction).normalized()

	# Apply cone offset
	var offset := right * cos(angle) * radius + up * sin(angle) * radius
	return (base_direction + offset).normalized()


func _spawn_blood_decal_on_surface(decal_position: Vector3, normal: Vector3) -> void:
	## Spawn blood decal on any surface (wall, ceiling, floor)
	var decal := Sprite3D.new()

	# Configure as decal-like sprite for GLES3 compatibility
	decal.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	decal.shaded = false
	decal.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	decal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	decal.no_depth_test = false
	decal.layers = 0xFFFFF

	var parent: Node = get_tree().current_scene
	if not parent:
		parent = get_tree().root
	parent.add_child(decal)

	# Position and orient to surface
	decal.global_position = decal_position + normal * 0.01

	# Orient to normal - check for colinear vectors to avoid warnings
	if normal != Vector3.ZERO:
		var up := Vector3.UP
		# If normal is parallel to up vector, use a different up vector
		if abs(normal.dot(up)) > 0.99:
			up = Vector3.RIGHT
		decal.look_at(decal_position + normal, up)

	# Random size
	var decal_size := randf_range(decal_size_min, decal_size_max) * 0.6
	decal.pixel_size = decal_size / 64.0

	# Use cached blood texture
	decal.texture = PROCEDURAL_SPLAT_GENERATOR.create_blood_splat_texture()

	# Apply random rotation
	decal.rotate_object_local(Vector3.FORWARD, randf_range(0, TAU))

	# Schedule cleanup
	var tween := decal.create_tween()
	tween.tween_interval(decal_lifetime * 0.5)  # Shorter lifetime
	tween.tween_property(decal, "modulate:a", 0.0, 3.0)
	tween.tween_callback(decal.queue_free)

	# 15% chance to drip on non-horizontal surfaces (Reduced from 30%)
	if randf() < 0.15 and abs(normal.dot(Vector3.UP)) < 0.9:
		_make_decal_drip(decal, normal)


func _make_decal_drip(decal: Sprite3D, surface_normal: Vector3) -> void:
	## Make decal slide down surface with drip trail
	# Calculate slide direction (gravity projected onto surface)
	var gravity_dir := Vector3.DOWN
	var slide_dir := (gravity_dir - surface_normal * gravity_dir.dot(surface_normal)).normalized()

	# Slide parameters
	var slide_speed := randf_range(0.04, 0.1)
	var slide_distance := randf_range(0.3, 1.0)  # Reduced distance
	var drip_duration := slide_distance / slide_speed

	# Animate sliding down
	var slide_tween := decal.create_tween()
	slide_tween.tween_property(
		decal, "global_position", decal.global_position + slide_dir * slide_distance, drip_duration
	)

	# Spawn drip trail during slide
	_spawn_drip_trail(decal, drip_duration)

	# Try to spawn pool when slide finishes
	slide_tween.tween_callback(_on_drip_slide_finished.bind(decal, slide_dir))


func _spawn_drip_trail(decal: Sprite3D, duration: float) -> void:
	## Spawn dripping particles during slide
	var drip_count := int(duration / 0.5)  # Drip every 0.5s

	for i in drip_count:
		var delay := i * 0.5
		get_tree().create_timer(delay).timeout.connect(
			_spawn_single_drip.bind(decal), CONNECT_ONE_SHOT
		)


func _spawn_single_drip(decal: Sprite3D) -> void:
	if not is_instance_valid(decal):
		return

	# Small drip particle spray
	var drip := GPUParticles3D.new()
	get_tree().root.add_child(drip)
	drip.global_position = decal.global_position

	drip.one_shot = true
	drip.emitting = true
	drip.amount = 3
	drip.lifetime = 1.0

	# Drip material
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.DOWN
	mat.gravity = Vector3(0, -9.8, 0)
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.5
	mat.scale_min = 0.02
	mat.scale_max = 0.04
	mat.color = blood_color

	drip.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.02
	mesh.height = 0.04

	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = RETRO_BLOOD_SHADER
	shader_mat.set_shader_parameter("flow_speed", 0.5)
	mesh.material = shader_mat

	drip.draw_pass_1 = mesh

	# Cleanup
	get_tree().create_timer(2.0).timeout.connect(drip.queue_free)


func _on_drip_slide_finished(decal: Sprite3D, slide_dir: Vector3) -> void:
	_try_spawn_pool(decal, slide_dir)


func _try_spawn_pool(decal: Sprite3D, _fall_direction: Vector3) -> void:
	## Raycast down to find ground and spawn pool
	if not is_instance_valid(decal):
		return

	var space_state := get_tree().root.get_world_3d().direct_space_state
	var ray_origin := decal.global_position
	var ray_end := ray_origin + Vector3.DOWN * 10.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 1  # World geometry

	var result := space_state.intersect_ray(query)
	if result:
		_spawn_blood_pool(result.position, result.normal)


func _spawn_blood_pool(position: Vector3, normal: Vector3) -> void:
	## Spawn blood pool decal on ground
	var pool := Sprite3D.new()

	# Configure as decal-like sprite for GLES3 compatibility
	pool.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	pool.shaded = false
	pool.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	pool.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool.no_depth_test = false
	pool.layers = 0xFFFFF

	get_tree().root.add_child(pool)

	pool.global_position = position + normal * 0.01
	pool.look_at(position + normal, Vector3.FORWARD)
	# Use procedural blood splat (larger for pool)
	pool.texture = PROCEDURAL_SPLAT_GENERATOR.create_blood_splat_texture()

	# Larger pool size
	var pool_size := randf_range(0.8, 1.6)
	pool.pixel_size = pool_size / 100.0  # Sprite3D uses pixel_size, not size
	pool.rotation.z = randf() * TAU

	# Pools last longer before fading
	var tween := pool.create_tween()
	tween.tween_interval(60.0)  # Stay for 1 minute
	tween.tween_property(pool, "modulate:a", 0.0, 10.0)
	tween.tween_callback(pool.queue_free)


func _spawn_micro_gibs_on_decal(
	decal: Decal, _slide_direction: Vector3, slide_duration: float
) -> void:
	## Spawn small gore chunks attached to dripping decal
	var gib_count := randi_range(1, 3)

	for i in gib_count:
		# Create tiny gib mesh
		var micro_gib := MeshInstance3D.new()
		decal.add_child(micro_gib)

		# Small irregular chunk
		var box := BoxMesh.new()
		box.size = Vector3(
			randf_range(0.02, 0.05), randf_range(0.02, 0.05), randf_range(0.02, 0.05)
		)
		micro_gib.mesh = box

		# Dark gore material - using retro blood shader
		var mat := ShaderMaterial.new()
		mat.shader = RETRO_BLOOD_SHADER
		mat.set_shader_parameter("flow_speed", 0.2)
		mat.set_shader_parameter("deep_blood", Color(0.2, 0.0, 0.0))
		mat.set_shader_parameter("fresh_blood", Color(0.5, 0.0, 0.0))
		micro_gib.set_surface_override_material(0, mat)

		# Random position on decal
		micro_gib.position = Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1))

		# Random rotation
		micro_gib.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

		# Detach and fall when slide finishes
		get_tree().create_timer(slide_duration).timeout.connect(
			_detach_and_drop_gib.bind(micro_gib, decal)
		)


func _detach_and_drop_gib(gib: MeshInstance3D, parent_decal: Decal) -> void:
	## Convert micro-gib to physics object and drop
	if not is_instance_valid(gib) or not is_instance_valid(parent_decal):
		return

	# Convert to RigidBody3D for physics
	var rigid_gib := RigidBody3D.new()
	get_tree().root.add_child(rigid_gib)

	# Copy transform
	rigid_gib.global_transform = gib.global_transform

	# Move mesh to rigid body
	gib.reparent(rigid_gib)
	gib.position = Vector3.ZERO

	# Add collision shape
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = (gib.mesh as BoxMesh).size
	collision.shape = shape
	rigid_gib.add_child(collision)

	# Physics properties
	rigid_gib.mass = 0.1  # Very light
	rigid_gib.gravity_scale = 1.0

	# Small downward impulse
	rigid_gib.apply_central_impulse(Vector3.DOWN * 0.5)

	# Cleanup after 5s
	get_tree().create_timer(5.0).timeout.connect(rigid_gib.queue_free)


func set_enabled(value: bool) -> void:
	## Enable or disable the spray system
	enabled = value
