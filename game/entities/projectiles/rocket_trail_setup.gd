extends Node

## Sets up retro pixelated smoke trail for rocket projectile
## Call this from rocket._ready() to configure trails

const SMOKE_SHADER = preload("res://game/art/shaders/retro_smoke_trail.gdshader")
const EMBER_SHADER = preload("res://game/art/shaders/retro_ember_trail.gdshader")


static func setup_smoke_trail(rocket: Node3D) -> void:
	var smoke: GPUParticles3D = rocket.get_node_or_null("SmokeTrail")
	if not smoke:
		return

	# Configure smoke particles for retro look
	smoke.amount = 80  # Reduced from 100
	smoke.lifetime = 1.5  # Slightly longer
	smoke.local_coords = false
	smoke.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))

	# Create process material
	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke_mat.emission_sphere_radius = 0.15
	smoke_mat.direction = Vector3(0, 0, 1)  # Behind rocket
	smoke_mat.spread = 15.0
	smoke_mat.initial_velocity_min = 0.5
	smoke_mat.initial_velocity_max = 1.5
	smoke_mat.gravity = Vector3(0, 0.5, 0)  # Slight upward drift
	smoke_mat.damping_min = 1.0
	smoke_mat.damping_max = 2.0

	# Scale curve - start small, grow larger
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(0.5, 1.0))
	scale_curve.add_point(Vector2(1.0, 1.8))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	smoke_mat.scale_curve = scale_tex
	smoke_mat.scale_min = 0.4
	smoke_mat.scale_max = 0.6

	# Alpha fade curve - fade out over lifetime
	var alpha_curve := Curve.new()
	alpha_curve.add_point(Vector2(0.0, 0.8))
	alpha_curve.add_point(Vector2(0.3, 0.6))
	alpha_curve.add_point(Vector2(1.0, 0.0))
	var alpha_tex := CurveTexture.new()
	alpha_tex.curve = alpha_curve
	smoke_mat.alpha_curve = alpha_tex

	smoke.process_material = smoke_mat

	# Create shader material for pixelated smoke
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = SMOKE_SHADER

	# Generate noise texture for smoke turbulence
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05
	noise.fractal_octaves = 3

	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.width = 128
	noise_tex.height = 128

	shader_mat.set_shader_parameter("noise_texture", noise_tex)
	shader_mat.set_shader_parameter("smoke_color", Color(0.6, 0.6, 0.65, 1.0))
	shader_mat.set_shader_parameter("alpha_multiplier", 0.2)  # Very transparent
	shader_mat.set_shader_parameter("pixel_size", 4.0)  # Chunky pixels
	shader_mat.set_shader_parameter("noise_scale", 2.0)
	shader_mat.set_shader_parameter("time_scale", 0.3)

	# Create quad mesh with shader
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	quad.material = shader_mat

	smoke.draw_pass_1 = quad


static func setup_ember_trail(rocket: Node3D) -> void:
	var ember: GPUParticles3D = rocket.get_node_or_null("EmberTrail")
	if not ember:
		return

	# Configure ember particles
	ember.amount = 40  # Reduced from 60
	ember.lifetime = 0.6
	ember.local_coords = false
	ember.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))

	# Create process material
	var ember_mat := ParticleProcessMaterial.new()
	ember_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	ember_mat.emission_sphere_radius = 0.1
	ember_mat.direction = Vector3(0, 0, 1)  # Behind rocket
	ember_mat.spread = 10.0
	ember_mat.initial_velocity_min = 0.3
	ember_mat.initial_velocity_max = 1.0
	ember_mat.gravity = Vector3(0, -2.0, 0)  # Fall down
	ember_mat.damping_min = 2.0
	ember_mat.damping_max = 3.0

	# Scale - keep small
	ember_mat.scale_min = 0.15
	ember_mat.scale_max = 0.25

	# Alpha fade
	var alpha_curve := Curve.new()
	alpha_curve.add_point(Vector2(0.0, 1.0))
	alpha_curve.add_point(Vector2(0.5, 0.6))
	alpha_curve.add_point(Vector2(1.0, 0.0))
	var alpha_tex := CurveTexture.new()
	alpha_tex.curve = alpha_curve
	ember_mat.alpha_curve = alpha_tex

	# Color gradient - bright orange to dark red
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.8, 0.3, 1.0))  # Bright yellow-orange
	gradient.add_point(0.5, Color(1.0, 0.4, 0.1, 1.0))  # Orange
	gradient.add_point(1.0, Color(0.6, 0.1, 0.0, 1.0))  # Dark red
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	ember_mat.color_ramp = grad_tex

	ember.process_material = ember_mat

	# Create shader material for pixelated embers
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = EMBER_SHADER
	shader_mat.set_shader_parameter("ember_color", Color(1.0, 0.5, 0.1, 1.0))
	shader_mat.set_shader_parameter("alpha_multiplier", 0.35)  # Semi-transparent
	shader_mat.set_shader_parameter("pixel_size", 6.0)  # Chunky pixels
	shader_mat.set_shader_parameter("glow_intensity", 2.5)

	# Create quad mesh with shader
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	quad.material = shader_mat

	ember.draw_pass_1 = quad
