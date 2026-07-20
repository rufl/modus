extends Control

signal blood_added(intensity: float)
signal blood_cleared

const CONFIG_PATH := "res://game/config/gameplay/blood_effects_config.json"
const VIGNETTE_SHADER := """
shader_type canvas_item;

uniform vec4 blood_color : source_color = vec4(0.4, 0.0, 0.0, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float border_size : hint_range(0.0, 0.5) = 0.25;
uniform float softness : hint_range(0.0, 1.0) = 0.4;
uniform vec2 directional_bias = vec2(0.0, 0.0);

void fragment() {
	vec2 uv = UV - 0.5 + directional_bias * 0.2;
	float dist = length(uv * vec2(1.0, 0.7));
	float vignette = smoothstep(0.5 - border_size, 0.5 - border_size + softness, dist);
	COLOR = vec4(blood_color.rgb, vignette * intensity * blood_color.a);
}
"""

@export_group("Overlay Settings")
@export var enabled: bool = true
@export var max_intensity: float = 0.6
@export var intensity_per_damage: float = 0.02
@export var fade_delay: float = 0.8
@export var fade_duration: float = 1.5
@export_group("Visual")
@export var blood_color: Color = Color(0.4, 0.0, 0.0, 1.0)
@export var border_softness: float = 0.4
@export var border_size: float = 0.25

var current_intensity: float = 0.0
var directional_bias: Vector2 = Vector2.ZERO

var _vignette_rect: ColorRect
var _fade_tween: Tween
var _pulse_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_config()
	_setup_vignette()


func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return
	var config: Dictionary = json.data
	_apply_config(config)


func _apply_config(config: Dictionary) -> void:
	if config.has("screen_blood"):
		var blood: Dictionary = config["screen_blood"]
		enabled = blood.get("enabled", enabled)
		max_intensity = blood.get("max_intensity", max_intensity)
		intensity_per_damage = blood.get("intensity_per_damage", intensity_per_damage)
		fade_delay = blood.get("fade_delay", fade_delay)
		fade_duration = blood.get("fade_duration", fade_duration)
		border_softness = blood.get("border_softness", border_softness)
		border_size = blood.get("border_size", border_size)
		if blood.has("blood_color"):
			var c: Dictionary = blood["blood_color"]
			blood_color = Color(
				c.get("r", blood_color.r),
				c.get("g", blood_color.g),
				c.get("b", blood_color.b),
				c.get("a", blood_color.a)
			)


func _setup_vignette() -> void:
	_vignette_rect = ColorRect.new()
	_vignette_rect.name = "BloodVignette"
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_vignette_rect)
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("blood_color", blood_color)
	mat.set_shader_parameter("intensity", 0.0)
	mat.set_shader_parameter("border_size", border_size)
	mat.set_shader_parameter("softness", border_softness)
	mat.set_shader_parameter("directional_bias", Vector2.ZERO)
	_vignette_rect.material = mat


func show_damage(intensity: float = 0.5, hit_direction: Vector3 = Vector3.ZERO) -> void:
	if not enabled:
		return
	var intensity_increase := intensity * intensity_per_damage * 40.0
	current_intensity = minf(current_intensity + intensity_increase, max_intensity)
	if hit_direction.length() > 0.1:
		directional_bias = Vector2(hit_direction.x, -hit_direction.y).normalized()
	else:
		directional_bias = Vector2.ZERO
	_update_shader()
	_do_pulse()
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_callback(_start_fade).set_delay(fade_delay)
	blood_added.emit(current_intensity)


func add_blood_from_damage(damage: int, hit_direction: Vector3 = Vector3.ZERO) -> void:
	show_damage(float(damage) / 100.0, hit_direction)


func clear_blood_immediate() -> void:
	current_intensity = 0.0
	directional_bias = Vector2.ZERO
	_update_shader()
	blood_cleared.emit()


func _update_shader() -> void:
	if not _vignette_rect or not _vignette_rect.material:
		return
	var mat: ShaderMaterial = _vignette_rect.material
	mat.set_shader_parameter("intensity", current_intensity)
	mat.set_shader_parameter("directional_bias", directional_bias)
	mat.set_shader_parameter("blood_color", blood_color)
	mat.set_shader_parameter("border_size", border_size)
	mat.set_shader_parameter("softness", border_softness)


func _do_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	if not _vignette_rect or not _vignette_rect.material:
		return
	var mat: ShaderMaterial = _vignette_rect.material
	var pulse_intensity := minf(current_intensity + 0.15, max_intensity + 0.1)
	_pulse_tween = create_tween()
	(
		_pulse_tween
		. tween_method(
			func(val: float) -> void: mat.set_shader_parameter("intensity", val),
			pulse_intensity,
			current_intensity,
			0.2
		)
		. set_ease(Tween.EASE_OUT)
	)


func _start_fade() -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_method(_set_intensity, current_intensity, 0.0, fade_duration)
	_fade_tween.parallel().tween_method(
		func(val: Vector2) -> void:
			directional_bias = val
			_update_shader(),
		directional_bias,
		Vector2.ZERO,
		fade_duration
	)


func _set_intensity(value: float) -> void:
	current_intensity = value
	_update_shader()


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		clear_blood_immediate()


func get_current_intensity() -> float:
	return current_intensity


func show_flash(flash_color: Color, intensity: float = 0.3, duration: float = 0.3) -> void:
	if not _vignette_rect:
		return
	var flash_rect := ColorRect.new()
	flash_rect.name = "FlashOverlay"
	flash_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, intensity)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tween := create_tween()
	tween.tween_property(flash_rect, "color:a", 0.0, duration)
	tween.tween_callback(flash_rect.queue_free)


func show_health_flash(intensity: float = 0.25) -> void:
	show_flash(Color.GREEN, intensity, 0.4)


func show_powerup_flash(intensity: float = 0.3) -> void:
	show_flash(Color.GOLD, intensity, 0.5)


func show_ammo_flash(intensity: float = 0.15) -> void:
	show_flash(Color.DODGER_BLUE, intensity, 0.25)
