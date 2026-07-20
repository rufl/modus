extends GPUParticles3D


func _ready() -> void:
	# Particle settings
	amount = 40
	lifetime = 2.0
	one_shot = true
	explosiveness = 0.7
	randomness = 0.4

	# Create process material
	var mat := ParticleProcessMaterial.new()

	# Emission
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.6

	# Direction (outward and up)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 120.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 4.0

	# Gravity
	mat.gravity = Vector3(0, -5.0, 0)  # Lighter than glass

	# Scale (dust particles)
	mat.scale_min = 0.1
	mat.scale_max = 0.3

	# Color (brown wood dust)
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.6, 0.4, 0.2, 0.8))
	gradient.add_point(0.3, Color(0.5, 0.35, 0.2, 0.6))
	gradient.add_point(1.0, Color(0.4, 0.3, 0.2, 0.0))  # Fade out

	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex

	# Damping (dust settles slowly)
	mat.damping_min = 1.0
	mat.damping_max = 2.0

	# Turbulence (dust swirls)
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 2.0
	mat.turbulence_noise_scale = 4.0

	process_material = mat

	# Create mesh (retro squared wood splinters)
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.08, 0.08, 0.08)  # Small cubes for wood chunks
	draw_pass_1 = box_mesh

	# Material (alpha blend for dust)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.vertex_color_use_as_albedo = true
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh_mat.albedo_color = Color(1, 1, 1, 0.6)
	draw_pass_1.surface_set_material(0, mesh_mat)

	# Auto-cleanup
	await get_tree().create_timer(lifetime + 0.5).timeout
	queue_free()
