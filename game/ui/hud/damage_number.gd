class_name DamageNumber
extends Node3D

@export var rise_speed: float = 2.0
@export var duration: float = 0.8
@export var fade_start: float = 0.4

var _time_alive: float = 0.0
var _label: Label3D
var _initial_alpha: float = 1.0
var _font_size: int = 24
var _critical_font_size: int = 32
var _outline_size: int = 2
var _high_damage_threshold: float = 50.0
var _color_normal: Color = Color.WHITE
var _color_critical: Color = Color(1.0, 0.3, 0.1)
var _color_high_damage: Color = Color(1.0, 0.8, 0.2)


func _ready() -> void:
	_load_config()

	# Create Label3D for the damage number
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = _font_size
	_label.outline_size = _outline_size
	_label.modulate = Color.WHITE
	add_child(_label)

	# Start small for pop effect
	scale = Vector3.ZERO


func _load_config() -> void:
	## Try GameManager.get_core_system("config") first, fall back to direct JSON loading
	## This gives buyers flexibility to use either approach

	# Option 1: GameManager.get_core_system("config") (recommended for hot-reload support)
	var config_result: Variant = GameManager.get_core_system("config").get_value("ai_combat")
	if config_result != null and config_result is Dictionary:
		var cm_data: Dictionary = config_result
		if cm_data.has("damage_numbers"):
			_apply_damage_number_config(cm_data["damage_numbers"])
			return

	# Option 2: Direct JSON file loading (fallback)
	const CONFIG_PATH := "res://game/config/gameplay/combat.json5"
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return

	var data: Dictionary = json.data
	if not data.has("damage_numbers"):
		return
	_apply_damage_number_config(data["damage_numbers"])


func _apply_damage_number_config(cfg: Dictionary) -> void:
	rise_speed = cfg.get("rise_speed", rise_speed)
	duration = cfg.get("duration", duration)
	fade_start = cfg.get("fade_start", fade_start)
	_font_size = cfg.get("font_size", _font_size)
	_critical_font_size = cfg.get("critical_font_size", _critical_font_size)
	_outline_size = cfg.get("outline_size", _outline_size)
	_high_damage_threshold = cfg.get("high_damage_threshold", _high_damage_threshold)

	if cfg.has("colors"):
		var colors: Dictionary = cfg["colors"]
		if colors.has("normal"):
			var c: Dictionary = colors["normal"]
			_color_normal = Color(
				c.get("r", 1.0), c.get("g", 1.0), c.get("b", 1.0), c.get("a", 1.0)
			)
		if colors.has("critical"):
			var c: Dictionary = colors["critical"]
			_color_critical = Color(
				c.get("r", 1.0), c.get("g", 0.3), c.get("b", 0.1), c.get("a", 1.0)
			)
		if colors.has("high_damage"):
			var c: Dictionary = colors["high_damage"]
			_color_high_damage = Color(
				c.get("r", 1.0), c.get("g", 0.8), c.get("b", 0.2), c.get("a", 1.0)
			)


func _process(delta: float) -> void:
	_time_alive += delta

	# Rise upward
	global_position.y += rise_speed * delta

	# Enable Pop Animation (Scale)
	if _time_alive < 0.15:
		var s: float = lerp(0.0, 1.5, _time_alive / 0.15)
		scale = Vector3(s, s, s)
	elif _time_alive < 0.25:
		var s: float = lerp(1.5, 1.0, (_time_alive - 0.15) / 0.1)
		scale = Vector3(s, s, s)
	else:
		scale = Vector3(1, 1, 1)

	# Fade out after fade_start time
	if _time_alive > fade_start:
		var fade_progress: float = (_time_alive - fade_start) / (duration - fade_start)
		_label.modulate.a = lerp(_initial_alpha, 0.0, fade_progress)

	# Remove when done
	if _time_alive >= duration:
		queue_free()


## Setup the damage number with value and color


func setup(damage: float, is_critical: bool = false, color_override: Variant = null) -> void:
	if not _label:
		await ready

	var text_val: String = str(int(damage))

	if color_override != null:
		_label.modulate = color_override
	elif is_critical:
		_label.modulate = _color_critical
		_label.outline_modulate = Color(1.0, 1.0, 0.0)  # Yellow outline for crit
		text_val += "!"
	elif damage >= _high_damage_threshold:
		_label.modulate = _color_high_damage
	else:
		_label.modulate = _color_normal

	_label.text = text_val

	if is_critical:
		_label.font_size = _critical_font_size
		_label.outline_size = _outline_size * 2  # Thicker outline
		rise_speed *= 1.5

	_initial_alpha = _label.modulate.a

	# Random horizontal offset for variety
	position.x += randf_range(-0.4, 0.4)
	position.z += randf_range(-0.4, 0.4)  # Increased spread


## Setup as generic floating text


func set_text(text: String, color: Color) -> void:
	if not _label:
		await ready

	_label.text = text
	_label.modulate = color
	_initial_alpha = color.a

	# Random horizontal offset
	position.x += randf_range(-0.2, 0.2)
	position.z += randf_range(-0.2, 0.2)
