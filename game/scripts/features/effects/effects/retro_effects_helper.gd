class_name RetroEffectsHelper
extends RefCounted

## Helper for creating retro-pixelated effect materials and textures
## All effects should use these to maintain consistent retro aesthetic

const RETRO_PARTICLE_SHADER = preload("res://game/art/shaders/retro_particle.gdshader")
const RETRO_DECAL_SHADER = preload("res://game/art/shaders/retro_decal.gdshader")

const PIXEL_SIZE: int = 8  # Base pixel size for textures
const PALETTE_BLOOD: Array[Color] = [
	Color(0.6, 0.0, 0.0),  # Dark red
	Color(0.4, 0.0, 0.0),  # Darker
	Color(0.2, 0.0, 0.0),  # Near black
]
const PALETTE_SMOKE: Array[Color] = [
	Color(0.3, 0.3, 0.3),
	Color(0.2, 0.2, 0.2),
	Color(0.1, 0.1, 0.1),
]
const PALETTE_FIRE: Array[Color] = [
	Color(1.0, 0.6, 0.0),  # Orange
	Color(1.0, 0.3, 0.0),  # Red-orange
	Color(1.0, 1.0, 0.0),  # Yellow
]


static func create_retro_particle_material(color: Color, pixel_size: float = 4.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = RETRO_PARTICLE_SHADER
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("pixel_size", pixel_size)
	mat.set_shader_parameter("use_dither", true)
	return mat


static func create_retro_decal_material(color: Color, pixel_size: float = 8.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = RETRO_DECAL_SHADER
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("pixel_size", pixel_size)
	mat.set_shader_parameter("edge_hardness", 0.7)
	return mat


static func create_pixelated_circle_texture(
	size: int = 16, color: Color = Color.WHITE
) -> ImageTexture:
	## Creates a chunky pixelated circle texture
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius: float = size / 2.0 - 1.0

	for y in size:
		for x in size:
			var dist: float = Vector2(x, y).distance_to(center)
			if dist <= radius:
				image.set_pixel(x, y, color)
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))

	return ImageTexture.create_from_image(image)


static func create_pixelated_splat_texture(
	size: int = 16, color: Color = Color.RED
) -> ImageTexture:
	## Creates a chunky blood splat texture with irregular edges
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var base_radius: float = size / 2.0 - 2.0

	for y in size:
		for x in size:
			var dist: float = Vector2(x, y).distance_to(center)
			# Add some irregularity
			var angle: float = atan2(y - center.y, x - center.x)
			var wobble: float = sin(angle * 3.0) * 1.5 + cos(angle * 5.0) * 1.0
			var radius: float = base_radius + wobble

			if dist <= radius:
				# Darker towards edges
				var darkness: float = dist / radius
				var final_color := color.darkened(darkness * 0.3)
				image.set_pixel(x, y, final_color)
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))

	return ImageTexture.create_from_image(image)


static func create_retro_particle_mesh(color: Color) -> QuadMesh:
	## Creates a simple quad mesh with retro material for particles
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.1, 0.1)
	mesh.material = create_retro_particle_material(color)
	return mesh


static func apply_retro_style_to_particles(particles: GPUParticles3D, color: Color) -> void:
	## Apply retro pixelated look to existing particles
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.08, 0.08)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.albedo_texture = create_pixelated_circle_texture(8, Color.WHITE)

	mesh.material = mat
	particles.draw_pass_1 = mesh


static func get_blood_color() -> Color:
	return PALETTE_BLOOD[randi() % PALETTE_BLOOD.size()]


static func get_smoke_color() -> Color:
	return PALETTE_SMOKE[randi() % PALETTE_SMOKE.size()]


static func get_fire_color() -> Color:
	return PALETTE_FIRE[randi() % PALETTE_FIRE.size()]
