extends Sprite3D

@export var grow_time: float = 2.0
@export var lifetime: float = 30.0
@export var fade_time: float = 2.0
@export var max_size: float = 1.0


func _ready() -> void:
	# Configure as decal-like sprite for GLES3 compatibility
	billboard = BaseMaterial3D.BILLBOARD_DISABLED
	shaded = false
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	no_depth_test = false
	layers = 0xFFFFF

	# Load blood color from config for consistency with other gore effects
	_apply_blood_color()

	# Start small
	var target_scale: Vector3 = scale
	scale = Vector3(0.1, 0.1, 0.1)

	# Grow tween
	var tween: Tween = create_tween()
	(
		tween
		. tween_property(self, "scale", target_scale * max_size, grow_time)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)

	# Lifetime timer
	get_tree().create_timer(lifetime).timeout.connect(_on_timeout, CONNECT_ONE_SHOT)


func _apply_blood_color() -> void:
	# Load color from gore config for consistency
	var color_cfg: Dictionary = GameManager.get_core_system("config").get_value(
		"visuals.gore.blood_spray.color", {}
	)
	if not color_cfg.is_empty():
		var blood_color := Color(
			color_cfg.get("r", 0.6), color_cfg.get("g", 0.0), color_cfg.get("b", 0.0)
		)
		modulate = blood_color


func _on_timeout() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)
