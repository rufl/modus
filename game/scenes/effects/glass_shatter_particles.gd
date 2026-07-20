extends GPUParticles3D


func _ready() -> void:
	# Particle settings
	amount = 30
	lifetime = 1.5
	one_shot = true
	explosiveness = 0.8
	randomness = 0.3

	# Create process material
	var mat := ParticleProcessMaterial.new()

	# Emission
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.5

	# Direction (outward burst)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 6.0

	# Gravity
	mat.gravity = Vector3(0, -9.8, 0)

	# Scale (small sparkles)
	mat.scale_min = 0.05
	mat.scale_max = 0.15

	# Color (glass blue-white with transparency)
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.9, 0.95, 1.0, 1.0))
	gradient.add_point(0.5, Color(0.8, 0.9, 1.0, 0.8))
	gradient.add_point(1.0, Color(0.7, 0.85, 1.0, 0.0))  # Fade out

	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex

	# Damping (air resistance)
	mat.damping_min = 0.5
	mat.damping_max = 1.0

	process_material = mat

	# Create mesh (retro squared glass shards)
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.05, 0.05, 0.05)  # Small cubes for glass shards
	draw_pass_1 = box_mesh

	# Material (additive for sparkle)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.vertex_color_use_as_albedo = true
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh_mat.albedo_color = Color(1, 1, 1, 0.8)
	draw_pass_1.surface_set_material(0, mesh_mat)

	# Auto-cleanup
	await get_tree().create_timer(lifetime + 0.5).timeout
	queue_free()
