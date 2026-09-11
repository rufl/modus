@tool
extends Node3D
class_name WeatherController

@export var rain_particles: GPUParticles3D
@export var snow_particles: GPUParticles3D
@export var audio_player: AudioStreamPlayer

var _default_fog_density: float = 0.0
var _target_fog_density: float = 0.0
var _current_fog_density: float = 0.0
var _weather_override: int = -1  # -1 = No override
var _environment: Environment


func _ready() -> void:
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.weather:
		gs.weather.weather_changed.connect(_on_weather_changed)

		# Init
		_on_weather_changed(gs.weather.current_weather)

	# Cache environment
	var world_env := get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		_environment = world_env.environment
		if _environment.fog_enabled:
			_default_fog_density = _environment.fog_density
			_current_fog_density = _default_fog_density

	# Listen for quality changes
	var graphics_sys: Node = get_node_or_null("/root/GraphicsSystem")
	if graphics_sys:
		graphics_sys.quality_changed.connect(_on_quality_changed)
		# Initial apply
		_on_quality_changed(graphics_sys.current_settings)


func _on_quality_changed(settings: Dictionary) -> void:
	if not settings.has("max_particles"):
		return

	var max_count: int = int(settings.get("max_particles", 200))  # Base max

	# Adjust our particles based on available budget
	# This is a simple scaler, could be more complex
	if rain_particles:
		rain_particles.amount = max_count

	if snow_particles:
		snow_particles.amount = max_count


func _process(delta: float) -> void:
	if not _environment or not _environment.fog_enabled:
		return

	# Smooth fog transition
	if not is_equal_approx(_current_fog_density, _target_fog_density):
		_current_fog_density = move_toward(_current_fog_density, _target_fog_density, delta * 0.001)
		_environment.fog_density = _current_fog_density


func _on_weather_changed(_type: int) -> void:
	_update_visuals()


func set_weather_override(type: int) -> void:
	_weather_override = type
	_update_visuals()


func _update_visuals() -> void:
	# Determine effective weather
	var effective_weather: int = _weather_override
	if effective_weather == -1:
		# Fallback to global system
		var gs := GameManager.get_core_system("gameplay") as GameplaySvc
		if gs and gs.weather:
			effective_weather = gs.weather.current_weather
		else:
			effective_weather = 0  # Clear default

	_update_particles(effective_weather)
	_update_fog(effective_weather)


func _update_particles(type: int) -> void:
	if rain_particles:
		rain_particles.emitting = false
	if snow_particles:
		snow_particles.emitting = false

	match type:
		1:  # RAIN
			if rain_particles:
				rain_particles.emitting = true
		2:  # SNOW
			if snow_particles:
				snow_particles.emitting = true
		3:  # STORM
			if rain_particles:
				rain_particles.emitting = true
				rain_particles.amount_ratio = 1.0  # Max rain


func _update_fog(type: int) -> void:
	match type:
		0:  # CLEAR
			_target_fog_density = 0.0  # Or default
		1:  # RAIN
			_target_fog_density = 0.02
		2:  # SNOW
			_target_fog_density = 0.05
		3:  # STORM
			_target_fog_density = 0.1
		_:
			_target_fog_density = 0.01
