class_name ProceduralSplatGenerator
extends RefCounted

static var _texture_cache: Dictionary = {}


static func create_gib_splat_texture() -> ImageTexture:
	## Create dark red, chunky gore splat texture
	# Increased from 64 to 128
	return _get_cached_splat("gib", Color(0.7, 0.0, 0.0), 128, 0.9, true)


static func create_bullet_mark_texture() -> ImageTexture:
	## Create gray/black bullet impact mark texture
	# Increased from 32 to 64
	return _get_cached_splat("bullet", Color(0.15, 0.15, 0.15), 64, 0.7, false)


static func create_blood_splat_texture() -> ImageTexture:
	## Create standard blood splatter texture
	# Increased from 64 to 128
	return _get_cached_splat("blood", Color(0.9, 0.02, 0.02), 128, 0.8, true)


static func _get_cached_splat(
	key: String, color: Color, size: int, opacity: float, chunky: bool
) -> ImageTexture:
	# Add some variety to the cache (e.g. 5 variations per type)
	var variant := randi() % 5
	var full_key := "%s_%d" % [key, variant]

	if _texture_cache.has(full_key):
		return _texture_cache[full_key]

	var tex := _create_splat(color, size, opacity, chunky)
	_texture_cache[full_key] = tex
	return tex


static func _create_splat(color: Color, size: int, opacity: float, chunky: bool) -> ImageTexture:
	## Core splat generation logic (Optimized)
	# Use PackedByteArray for direct memory manipulation (faster than set_pixel)
	var data := PackedByteArray()
	data.resize(size * size * 4)

	var center_x: float = size * 0.5
	var center_y: float = size * 0.5
	var max_dist_sq: float = (size * 0.4) ** 2

	# Pre-calculate colors
	var r: float = color.r
	var g: float = color.g
	var b: float = color.b

	for y in range(size):
		for x in range(size):
			var idx: int = (y * size + x) * 4

			var dx: float = x - center_x
			var dy: float = y - center_y
			var dist_sq: float = dx * dx + dy * dy

			# Create irregular shape with noise
			var noise: float = randf_range(0.7, 1.3) if chunky else 1.0
			var max_d: float = max_dist_sq * (noise * noise)  # Square noise to match dist_sq

			if dist_sq >= max_d:
				# Transparent pixel (default 0, 0, 0, 0)
				data[idx] = 0
				data[idx + 1] = 0
				data[idx + 2] = 0
				data[idx + 3] = 0
				continue

			var ratio: float = sqrt(dist_sq) / (size * 0.4 * noise)
			var alpha: float = 1.0 - ratio
			alpha = clampf(alpha, 0.0, 1.0) * opacity

			# Add splattery edges for chunky mode
			if chunky and alpha > 0.2:
				if randf() > 0.85:
					alpha *= 0.3  # Random droplets

			if alpha > 0.05:
				data[idx] = int(r * 255)
				data[idx + 1] = int(g * 255)
				data[idx + 2] = int(b * 255)
				data[idx + 3] = int(alpha * 255)
			else:
				data[idx] = 0
				data[idx + 1] = 0
				data[idx + 2] = 0
				data[idx + 3] = 0

	var image := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)

	# CRITICAL: Generate mipmaps for better quality at distance
	image.generate_mipmaps()

	# Create texture with proper filtering for sharp, retro look
	var texture := ImageTexture.create_from_image(image)

	# RETRO FPS: Use nearest-neighbor filtering for pixelated look
	# This prevents blurriness and gives that classic DOOM/Quake aesthetic
	# Note: In Godot 4, texture filtering is set on the material, not the texture itself
	# But we can hint it by using specific import settings

	return texture
