@tool
extends BreakableProp
class_name BreakableGlass

## Half-Life 2 style breakable glass with shatter effects and physics shards

@export_group("Glass Settings")
@export var glass_type: String = "window"  # window, bottle, monitor
@export var glass_thickness: float = 0.02
@export var shard_count: int = 12
@export var shard_size_min: float = 0.1
@export var shard_size_max: float = 0.3
@export var shatter_force: float = 8.0
@export var glass_tint: Color = Color(0.8, 0.9, 1.0, 0.3)
@export_group("Shatter Effects")
@export var spawn_dust_cloud: bool = true
@export var play_shatter_sound: bool = true
@export var shatter_sound_volume: float = 0.8
@export var shard_lifetime: float = 10.0
@export var shard_fade_time: float = 2.0


func _ready() -> void:
	# Skip initialization in editor
	if Engine.is_editor_hint():
		return

	super._ready()

	# Override base settings for glass
	max_health = 10.0  # Glass is fragile
	damage_resistance = 0.0
	wobble_on_damage = false  # Glass doesn't wobble
	show_damage_cracks = true

	# Glass-specific visuals
	break_particle_color = Color(0.9, 0.95, 1.0, 0.6)
	debris_count = shard_count

	# Make glass transparent
	_setup_glass_material()


func _setup_glass_material() -> void:
	if not mesh_instance:
		return

	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = glass_tint
	glass_mat.metallic = 0.1
	glass_mat.roughness = 0.1
	glass_mat.refraction_enabled = true
	glass_mat.refraction_scale = 0.05
	glass_mat.rim_enabled = true
	glass_mat.rim = 0.3
	glass_mat.rim_tint = 0.5

	mesh_instance.material_override = glass_mat


@rpc("authority", "call_local", "reliable")
func _play_destruction() -> void:
	# Skip in editor
	if Engine.is_editor_hint():
		return

	is_destroyed = true
	prop_destroyed.emit(prop_type, global_position)

	# Spawn glass shards with physics
	_spawn_glass_shards()

	# Spawn shatter particles
	_spawn_shatter_particles()

	# Spawn dust cloud
	if spawn_dust_cloud:
		_spawn_dust_cloud()

	# Play shatter sound
	if play_shatter_sound:
		_play_shatter_sound()

	# Disable collision and hide
	if collision_shape:
		collision_shape.disabled = true
	if mesh_instance:
		mesh_instance.visible = false

	# Cleanup
	get_tree().create_timer(0.5).timeout.connect(queue_free)


func _spawn_glass_shards() -> void:
	var effect_parent: Node = _get_effect_parent()
	if not effect_parent:
		return
	var break_position: Vector3 = global_position

	for i in range(shard_count):
		var shard := _create_glass_shard(i)
		if not shard:
			continue

		effect_parent.add_child(shard)
		shard.global_position = (
			break_position
			+ Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
		)

		# Calculate launch direction (radial from impact)
		var angle := (TAU / shard_count) * i + randf_range(-0.3, 0.3)
		var direction := Vector3(cos(angle), randf_range(0.2, 0.8), sin(angle)).normalized()
		var force := direction * randf_range(shatter_force * 0.7, shatter_force * 1.3)

		# Apply impulse
		shard.apply_central_impulse(force)
		shard.apply_torque_impulse(
			Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
		)

		# Fade out and cleanup
		_fade_and_cleanup_shard(shard)


func _create_glass_shard(index: int) -> RigidBody3D:
	var shard := RigidBody3D.new()
	shard.name = "GlassShard_%d" % index
	shard.mass = 0.1
	shard.gravity_scale = 1.0
	shard.contact_monitor = true
	shard.max_contacts_reported = 1

	# Create shard mesh (irregular triangle)
	var mesh_inst := MeshInstance3D.new()
	var shard_mesh := _create_shard_mesh()
	mesh_inst.mesh = shard_mesh
	shard.add_child(mesh_inst)

	# Create collision shape
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var size := randf_range(shard_size_min, shard_size_max)
	shape.size = Vector3(size, glass_thickness, size * 0.7)
	collision.shape = shape
	shard.add_child(collision)

	# Play tinkle sound on impact
	shard.body_entered.connect(_on_shard_impact.bind(shard))

	return shard


func _create_shard_mesh() -> Mesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	# Create irregular triangle shard
	var size := randf_range(shard_size_min, shard_size_max)
	var vertices := PackedVector3Array(
		[
			Vector3(-size * 0.5, 0, -size * 0.3),
			Vector3(size * 0.5, 0, -size * 0.2),
			Vector3(randf_range(-0.1, 0.1) * size, 0, size * 0.5),
		]
	)

	var normals := PackedVector3Array(
		[
			Vector3(0, 1, 0),
			Vector3(0, 1, 0),
			Vector3(0, 1, 0),
		]
	)

	var indices := PackedInt32Array([0, 1, 2])

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Apply glass material
	var shard_mat := StandardMaterial3D.new()
	shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard_mat.albedo_color = glass_tint
	shard_mat.metallic = 0.1
	shard_mat.roughness = 0.1
	shard_mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # Double-sided

	array_mesh.surface_set_material(0, shard_mat)

	return array_mesh


func _on_shard_impact(_body: Node, shard: RigidBody3D) -> void:
	if not is_instance_valid(shard):
		return

	# Play tinkle sound
	var audio := AudioStreamPlayer3D.new()
	var impact_position: Vector3 = shard.global_position
	audio.bus = "SFX"
	audio.volume_db = -15.0
	audio.pitch_scale = randf_range(0.9, 1.2)
	audio.max_distance = 10.0

	var effect_parent: Node = _get_effect_parent()
	if not effect_parent:
		audio.free()
		return
	effect_parent.add_child(audio)
	audio.global_position = impact_position

	audio.stream = SoundGenerator.generate_hit_sound()


	audio.finished.connect(audio.queue_free)
	if audio.stream:
		audio.play()
	else:
		get_tree().create_timer(0.5).timeout.connect(audio.queue_free)


func _fade_and_cleanup_shard(shard: RigidBody3D) -> void:
	await get_tree().create_timer(shard_lifetime - shard_fade_time).timeout

	if not is_instance_valid(shard):
		return

	var mesh_inst := shard.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_inst:
		shard.queue_free()
		return

	# Fade out
	var tween := shard.create_tween()
	var mat := mesh_inst.get_active_material(0) as StandardMaterial3D
	if mat:
		var start_alpha := mat.albedo_color.a
		tween.tween_method(
			func(alpha: float) -> void:
				if is_instance_valid(mat):
					mat.albedo_color.a = alpha,
			start_alpha,
			0.0,
			shard_fade_time
		)

	await tween.finished
	if is_instance_valid(shard):
		shard.queue_free()


func _spawn_shatter_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "ShatterParticles"
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 50
	particles.lifetime = 1.0
	particles.explosiveness = 1.0

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.3
	material.direction = Vector3(0, 0.5, 0)
	material.spread = 180.0
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 7.0
	material.gravity = Vector3(0, -9.8, 0)
	material.scale_min = 0.05
	material.scale_max = 0.15
	material.damping_min = 2.0
	material.damping_max = 4.0

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 0.8))
	gradient.add_point(0.5, Color(0.9, 0.95, 1.0, 0.4))
	gradient.add_point(1.0, Color(0.8, 0.9, 1.0, 0.0))

	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	particles.process_material = material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = quad_mat
	particles.draw_pass_1 = quad

	var effect_parent: Node = _get_effect_parent()
	if not effect_parent:
		particles.free()
		return
	effect_parent.add_child(particles)
	particles.global_position = global_position
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(particles.queue_free)


func _spawn_dust_cloud() -> void:
	var dust := GPUParticles3D.new()
	dust.name = "DustCloud"
	dust.emitting = true
	dust.one_shot = true
	dust.amount = 20
	dust.lifetime = 2.0
	dust.explosiveness = 0.8

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.5
	material.direction = Vector3(0, 1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 1.5
	material.gravity = Vector3(0, 0.5, 0)  # Slight upward drift
	material.scale_min = 0.3
	material.scale_max = 0.8
	material.damping_min = 1.0
	material.damping_max = 2.0

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.9, 0.9, 0.9, 0.3))
	gradient.add_point(0.5, Color(0.8, 0.8, 0.8, 0.2))
	gradient.add_point(1.0, Color(0.7, 0.7, 0.7, 0.0))

	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	dust.process_material = material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = quad_mat
	dust.draw_pass_1 = quad

	var effect_parent: Node = _get_effect_parent()
	if not effect_parent:
		dust.free()
		return
	effect_parent.add_child(dust)
	dust.global_position = global_position
	get_tree().create_timer(dust.lifetime + 0.5).timeout.connect(dust.queue_free)


func _play_shatter_sound() -> void:
	var audio := AudioStreamPlayer3D.new()
	audio.name = "ShatterSound"
	audio.bus = "SFX"
	audio.volume_db = linear_to_db(shatter_sound_volume)
	audio.pitch_scale = randf_range(0.95, 1.05)
	audio.max_distance = 25.0

	var effect_parent: Node = _get_effect_parent()
	if not effect_parent:
		audio.free()
		return
	effect_parent.add_child(audio)
	audio.global_position = global_position

	audio.stream = SoundGenerator.generate_crit_sound()

	audio.finished.connect(audio.queue_free)
	if audio.stream:
		audio.play()
	else:
		get_tree().create_timer(0.5).timeout.connect(audio.queue_free)
