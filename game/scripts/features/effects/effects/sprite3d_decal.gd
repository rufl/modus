class_name Sprite3DDecal
extends Sprite3D

## GLES3-compatible decal using Sprite3D instead of Decal node
## Decal nodes don't work with gl_compatibility renderer

var lifetime: float = 30.0
var fade_time: float = 2.0
var _age: float = 0.0


func _ready() -> void:
	# Configure for decal-like appearance
	billboard = BaseMaterial3D.BILLBOARD_DISABLED
	shaded = false
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	no_depth_test = false
	fixed_size = false

	# Render on all layers
	layers = 0xFFFFF


func _process(delta: float) -> void:
	_age += delta

	# Start fading near end of lifetime
	if _age >= lifetime - fade_time:
		var fade_progress: float = (_age - (lifetime - fade_time)) / fade_time
		modulate.a = 1.0 - fade_progress

		if _age >= lifetime:
			queue_free()


func setup(
	tex: Texture2D,
	pos: Vector3,
	normal: Vector3,
	decal_size: Vector2 = Vector2(1.0, 1.0),
	life: float = 30.0
) -> void:
	texture = tex
	global_position = pos + normal * 0.01  # Slight offset to avoid z-fighting
	lifetime = life

	# Set pixel size based on desired world size
	pixel_size = decal_size.x / 64.0  # Assuming 64px texture

	# Orient to surface normal
	if normal != Vector3.ZERO:
		# Check if normal is parallel to up vector to avoid colinear warning
		var up := Vector3.UP
		if abs(normal.dot(up)) > 0.99:
			up = Vector3.RIGHT
		look_at(pos + normal, up)

	# Random rotation for variety
	rotate_object_local(Vector3.FORWARD, randf() * TAU)
