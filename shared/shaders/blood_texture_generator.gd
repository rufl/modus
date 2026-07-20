@tool
extends Node
class_name BloodTextureGenerator

## Generates a radial gradient texture for blood drops
## Creates a white-centered gradient that fades to black at edges


static func create_blood_gradient_texture(size: int = 256) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.BLACK)  # Center = BLACK (blood)
	gradient.set_color(1, Color.WHITE)  # Edges = WHITE (no blood)

	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	gradient_texture.fill_to = Vector2(1.0, 0.5)
	gradient_texture.width = size
	gradient_texture.height = size

	return gradient_texture


static func create_blood_splat_texture(size: int = 256, irregularity: float = 0.3) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_L8)
	var center := Vector2(size / 2.0, size / 2.0)
	var max_radius := size / 2.0

	for y in range(size):
		for x in range(size):
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)
			var normalized_dist := dist / max_radius

			# Add some noise for irregular edges
			var noise := randf_range(-irregularity, irregularity)
			normalized_dist += noise

			# Create smooth falloff - INVERTED: 0.0 at center (blood), 1.0 at edges (no blood)
			var value := clampf(normalized_dist, 0.0, 1.0)
			value = smoothstep(0.0, 1.0, value)

			image.set_pixel(x, y, Color(value, value, value))

	return ImageTexture.create_from_image(image)
