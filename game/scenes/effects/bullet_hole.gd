extends Decal


func _ready() -> void:
	# Configure decal properties
	# Note: Decal nodes work with Vulkan renderer
	# For GLES3 compatibility, consider using Sprite3D instead
	layers = 0xFFFFF

	# Defer heavy operations to not block ready signal
	call_deferred("_setup_bullet_hole")


func reset() -> void:
	# Regenerate for variety when pooled
	_setup_bullet_hole()


func _setup_bullet_hole() -> void:
	# Generate procedural bullet hole texture
	texture_albedo = _create_bullet_hole_texture()

	# Randomize size
	var rand_size: float = randf_range(0.08, 0.15)
	size = Vector3(rand_size, rand_size, 0.1)

	# Random rotation
	rotation_degrees.z = randf() * 360.0


func _create_bullet_hole_texture() -> ImageTexture:
	var img_size: int = 256  # Increased from 128 for sharper detail
	var image: Image = Image.create(img_size, img_size, false, Image.FORMAT_RGBA8)

	var center: Vector2 = Vector2(img_size / 2.0, img_size / 2.0)
	var radius: float = img_size * 0.4  # Slightly larger

	# Noise for irregular edges
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.1  # Increased for more detail

	for y in range(img_size):
		for x in range(img_size):
			var uv: Vector2 = Vector2(x, y)
			var dist: float = uv.distance_to(center)

			# Noise-based radius variation for jagged edges
			var noise_val: float = noise.get_noise_2d(x, y)
			var varied_radius: float = radius * (1.0 + noise_val * 0.25)

			var alpha: float = 0.0

			if dist < varied_radius * 0.5:
				# Dark center (the actual hole) - MORE OPAQUE
				alpha = 1.0  # Fully opaque
				image.set_pixel(x, y, Color(0.02, 0.02, 0.02, alpha))
			elif dist < varied_radius:
				# Fade out at edges (scorching effect) - SHARPER FALLOFF
				var fade: float = 1.0 - ((dist - varied_radius * 0.5) / (varied_radius * 0.5))
				fade = pow(fade, 2.0)  # Sharper falloff (was 1.5)
				alpha = fade * 0.85  # More opaque (was 0.6)
				var brightness: float = 0.1 + (1.0 - fade) * 0.15
				image.set_pixel(x, y, Color(brightness, brightness, brightness, alpha))
			else:
				# Transparent outside
				image.set_pixel(x, y, Color(0, 0, 0, 0))

	var tex: ImageTexture = ImageTexture.create_from_image(image)

	# CRITICAL: Disable filtering for sharp, pixelated Quake-style look
	# This prevents the blurring/smudging
	tex.set_meta("import_settings", {"filter": false, "mipmaps": false})

	return tex
