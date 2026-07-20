extends Sprite3D


func _ready() -> void:
	# Configure as decal-like sprite for GLES3 compatibility
	billboard = BaseMaterial3D.BILLBOARD_DISABLED
	shaded = false
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	no_depth_test = false
	layers = 0xFFFFF

	# Defer to avoid blocking ready signal
	call_deferred("_setup_blood_decal")


func _setup_blood_decal() -> void:
	# Generate procedural blood splat texture (using global class)
	texture = ProceduralSplatGenerator.create_blood_splat_texture()

	# Randomize size
	var rand_size: float = randf_range(0.4, 0.8)
	pixel_size = rand_size / 64.0

	# Random rotation
	rotation_degrees.z = randf() * 360.0

	# Slight red tint variation
	modulate = Color(randf_range(0.8, 1.0), randf_range(0.1, 0.15), randf_range(0.1, 0.15))
