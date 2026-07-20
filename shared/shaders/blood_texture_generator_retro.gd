@tool
extends Node
class_name BloodTextureGeneratorRetro

## Generates retro/pixelated blood textures for Quake-style effects


static func create_retro_blood_gradient_texture(size: int = 64) -> GradientTexture2D:
	# Use smaller size for more pixelated look
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


static func create_retro_blood_splat_texture(size: int = 64) -> ImageTexture:
	# Create pixelated blood splat
	var image := Image.create(size, size, false, Image.FORMAT_L8)
	var center := Vector2(size / 2.0, size / 2.0)
	var max_radius := size / 2.0

	# Pixelation factor
	var pixel_size := 4

	for y in range(0, size, pixel_size):
		for x in range(0, size, pixel_size):
			var pos := Vector2(x + pixel_size / 2.0, y + pixel_size / 2.0)
			var dist := pos.distance_to(center)
			var normalized_dist := dist / max_radius

			# Add jagged edges for retro look
			var noise := randf_range(-0.3, 0.3)
			normalized_dist += noise

			# Create hard falloff (less smooth) - CORRECT: 1.0 at center (blood), 0.0 at edges
			var value := clampf(1.0 - normalized_dist, 0.0, 1.0)
			value = floor(value * 4.0) / 4.0  # Quantize to 4 levels

			# Fill pixel block
			for py in range(pixel_size):
				for px in range(pixel_size):
					var fx: int = x + px
					var fy: int = y + py
					if fx < size and fy < size:
						image.set_pixel(fx, fy, Color(value, value, value))

	return ImageTexture.create_from_image(image)


static func create_quake_style_blood_texture(size: int = 64) -> ImageTexture:
	# Create Quake-style blood with dithering
	var image := Image.create(size, size, false, Image.FORMAT_L8)
	var center := Vector2(size / 2.0, size / 2.0)
	var max_radius := size / 2.0

	for y in range(size):
		for x in range(size):
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)
			var normalized_dist := dist / max_radius

			# Dithering pattern (Bayer matrix style)
			var dither := fmod(float(x + y), 2.0) * 0.1

			# Create value with dithering - CORRECT: 1.0 at center (blood), 0.0 at edges
			var value := clampf(1.0 - normalized_dist - dither, 0.0, 1.0)

			# Quantize to limited colors (Quake had 256 color palette)
			value = floor(value * 8.0) / 8.0

			image.set_pixel(x, y, Color(value, value, value))

	return ImageTexture.create_from_image(image)


static func create_pixelated_blood_pool(size: int = 32) -> ImageTexture:
	# Very pixelated blood pool for extreme retro look
	var image := Image.create(size, size, false, Image.FORMAT_L8)
	var center := Vector2(size / 2.0, size / 2.0)
	var max_radius := size / 2.0

	for y in range(size):
		for x in range(size):
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)
			var normalized_dist := dist / max_radius

			# Very hard falloff - CORRECT: 1.0 at center (blood), 0.0 at edges
			var value := 1.0 if normalized_dist < 0.8 else 0.0

			# Add some variation
			if normalized_dist > 0.5 and normalized_dist < 0.8:
				value = 0.5 if randf() > 0.5 else 0.0

			image.set_pixel(x, y, Color(value, value, value))

	return ImageTexture.create_from_image(image)
