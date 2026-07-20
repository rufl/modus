extends GPUParticles3D


func _ready() -> void:
	# Particle settings
	amount = 60
	lifetime = 2.5
	one_shot = true
	explosiveness = 0.9
	randomness = 0.2

	# Create process material
	var mat := ParticleProcessMaterial.new()

	# Emission
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3

	# Direction (explosive burst)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0

	# Gravity (smoke rises, debris falls)
	mat.gravity = Vector3(0, -2.0, 0)

	# Scale (large smoke puffs)
	mat.scale_min = 0.3
	mat.scale_max = 1.0

	var scale_curve_tex := CurveTexture.new()
	scale_curve_tex.curve = _create_scale_curve()
	mat.scale_curve = scale_curve_tex

	# Color (fire to smoke)
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.8, 0.3, 1.0))  # Bright yellow
	gradient.add_point(0.1, Color(1.0, 0.4, 0.1, 0.9))  # Orange fire
	gradient.add_point(0.3, Color(0.3, 0.3, 0.3, 0.7))  # Dark smoke
	gradient.add_point(1.0, Color(0.2, 0.2, 0.2, 0.0))  # Fade out

	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex

	# Damping
	mat.damping_min = 0.5
	mat.damping_max = 1.5

	# Turbulence (smoke swirls)
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 4.0
	mat.turbulence_noise_scale = 2.0
	mat.turbulence_influence_min = 0.1
	mat.turbulence_influence_max = 0.5

	process_material = mat

	# Create mesh (retro squared particles - DOOM/Quake style)
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.5, 0.5, 0.5)  # Chunky cubes
	draw_pass_1 = box_mesh

	# Material (additive for fire, alpha for smoke)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.vertex_color_use_as_albedo = true
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh_mat.albedo_color = Color(1, 1, 1, 0.8)
	draw_pass_1.surface_set_material(0, mesh_mat)

	# Auto-cleanup
	await get_tree().create_timer(lifetime + 0.5).timeout
	queue_free()


func _create_scale_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))  # Start small
	curve.add_point(Vector2(0.2, 1.0))  # Expand quickly
	curve.add_point(Vector2(1.0, 1.5))  # Keep expanding
	return curve
