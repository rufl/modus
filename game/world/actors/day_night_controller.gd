@tool
class_name DayNightController
extends Node3D

signal time_changed(hour: float)
signal day_started
signal night_started
signal cycle_completed

const SUNRISE_HOUR: float = 6.0
const SUNSET_HOUR: float = 18.0
const DAWN_DURATION: float = 1.5  # Hours
const DUSK_DURATION: float = 1.5

@export var directional_light: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export_group("Cycle Settings")
@export var cycle_enabled: bool = true
@export var cycle_duration_minutes: float = 10.0  ## Real-time minutes for full day
@export var start_hour: float = 8.0  ## 0-24 hour to start at
@export_group("Sun Settings")
@export var sun_color_day: Color = Color(1.0, 0.95, 0.85)
@export var sun_color_sunset: Color = Color(1.0, 0.5, 0.2)
@export var sun_color_night: Color = Color(0.2, 0.2, 0.4)
@export var sun_intensity_day: float = 1.0
@export var sun_intensity_night: float = 0.1
@export_group("Sky Settings")
@export var sky_top_day: Color = Color(0.3, 0.5, 0.9)
@export var sky_top_sunset: Color = Color(0.8, 0.4, 0.3)
@export var sky_top_night: Color = Color(0.05, 0.05, 0.15)
@export var sky_horizon_day: Color = Color(0.6, 0.7, 0.9)
@export var sky_horizon_sunset: Color = Color(1.0, 0.6, 0.3)
@export var sky_horizon_night: Color = Color(0.1, 0.1, 0.2)
@export_group("Ambient Settings")
@export var ambient_day: Color = Color(0.4, 0.45, 0.55)
@export var ambient_night: Color = Color(0.05, 0.05, 0.15)

var _current_hour: float = 8.0
var _cycle_speed: float = 0.0
var _is_day: bool = true
var _sky_material: ProceduralSkyMaterial


func _ready() -> void:
	_current_hour = start_hour
	_calculate_cycle_speed()
	_load_config()
	_setup_sky_material()
	_update_visuals(_current_hour)

	# Initial day/night state
	_is_day = _current_hour >= SUNRISE_HOUR and _current_hour < SUNSET_HOUR
	if _is_day:
		day_started.emit()
	else:
		night_started.emit()


func _process(delta: float) -> void:
	if not cycle_enabled:
		return

	# Advance time
	var previous_hour: float = _current_hour
	_current_hour += _cycle_speed * delta

	# Wrap at 24 hours
	if _current_hour >= 24.0:
		_current_hour -= 24.0
		cycle_completed.emit()

	# Check for day/night transition
	_check_transitions(previous_hour, _current_hour)

	# Update visuals
	_update_visuals(_current_hour)

	# Emit time change periodically (every ~minute game time)
	if int(previous_hour * 60) != int(_current_hour * 60):
		time_changed.emit(_current_hour)


func _calculate_cycle_speed() -> void:
	# Hours per second = 24 hours / (cycle_duration_minutes * 60 seconds)
	if cycle_duration_minutes > 0:
		_cycle_speed = 24.0 / (cycle_duration_minutes * 60.0)
	else:
		_cycle_speed = 0.0


func _load_config() -> void:
	if not GameManager.get_core_system("config"):
		return

	var cfg: Dictionary = GameManager.get_core_system("config").get_value("visuals.day_night", {})
	if cfg.is_empty():
		return

	cycle_enabled = cfg.get("enabled", cycle_enabled)
	cycle_duration_minutes = cfg.get("cycle_duration_minutes", cycle_duration_minutes)
	start_hour = cfg.get("start_hour", start_hour)

	# Recalculate speed with new config
	_calculate_cycle_speed()
	_current_hour = start_hour

	GameManager.get_core_system("logger").info(
		(
			"[DayNightController] Config loaded: Duration=%dm, Start=%dh"
			% [int(cycle_duration_minutes), int(start_hour)]
		),
		"DayNight"
	)


func _setup_sky_material() -> void:
	if not world_environment or not world_environment.environment:
		return

	var env: Environment = world_environment.environment
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		_sky_material = env.sky.sky_material


func _update_visuals(hour: float) -> void:
	var time_factor: float = _get_time_factor(hour)

	_update_sun(hour, time_factor)
	_update_sky(time_factor)
	_update_ambient(time_factor)


func _get_time_factor(hour: float) -> float:
	## Returns 0.0 (night) to 1.0 (day) with smooth transitions

	# Full night: before dawn
	if hour < SUNRISE_HOUR - DAWN_DURATION:
		return 0.0

	# Dawn transition
	if hour < SUNRISE_HOUR:
		var dawn_progress: float = (hour - (SUNRISE_HOUR - DAWN_DURATION)) / DAWN_DURATION
		return dawn_progress * 0.5  # 0.0 -> 0.5

	# Morning rise
	if hour < SUNRISE_HOUR + DAWN_DURATION:
		var rise_progress: float = (hour - SUNRISE_HOUR) / DAWN_DURATION
		return 0.5 + rise_progress * 0.5  # 0.5 -> 1.0

	# Full day
	if hour < SUNSET_HOUR - DUSK_DURATION:
		return 1.0

	# Sunset begins
	if hour < SUNSET_HOUR:
		var dusk_progress: float = (hour - (SUNSET_HOUR - DUSK_DURATION)) / DUSK_DURATION
		return 1.0 - dusk_progress * 0.5  # 1.0 -> 0.5

	# Dusk fades
	if hour < SUNSET_HOUR + DUSK_DURATION:
		var fade_progress: float = (hour - SUNSET_HOUR) / DUSK_DURATION
		return 0.5 - fade_progress * 0.5  # 0.5 -> 0.0

	# Full night
	return 0.0


func _update_sun(hour: float, time_factor: float) -> void:
	if not directional_light:
		return

	# Rotate sun based on hour (0h = north horizon, 12h = zenith, 24h = north again)
	var sun_angle: float = (hour / 24.0) * 360.0 - 90.0  # -90 so noon is overhead
	directional_light.rotation_degrees.x = sun_angle

	# Color based on time of day
	var sun_color: Color
	if time_factor > 0.7:
		sun_color = sun_color_day
	elif time_factor > 0.3:
		# Sunset/sunrise blend
		var blend: float = (time_factor - 0.3) / 0.4
		sun_color = sun_color_sunset.lerp(sun_color_day, blend)
	else:
		sun_color = sun_color_night.lerp(sun_color_sunset, time_factor / 0.3)

	directional_light.light_color = sun_color
	directional_light.light_energy = lerpf(sun_intensity_night, sun_intensity_day, time_factor)


func _update_sky(time_factor: float) -> void:
	if not _sky_material:
		return

	# Lerp sky colors
	if time_factor > 0.7:
		_sky_material.sky_top_color = sky_top_day
		_sky_material.sky_horizon_color = sky_horizon_day
	elif time_factor > 0.3:
		var blend: float = (time_factor - 0.3) / 0.4
		_sky_material.sky_top_color = sky_top_sunset.lerp(sky_top_day, blend)
		_sky_material.sky_horizon_color = sky_horizon_sunset.lerp(sky_horizon_day, blend)
	else:
		var blend: float = time_factor / 0.3
		_sky_material.sky_top_color = sky_top_night.lerp(sky_top_sunset, blend)
		_sky_material.sky_horizon_color = sky_horizon_night.lerp(sky_horizon_sunset, blend)


func _update_ambient(time_factor: float) -> void:
	if not world_environment or not world_environment.environment:
		return

	var env: Environment = world_environment.environment
	env.ambient_light_color = ambient_night.lerp(ambient_day, time_factor)


func _check_transitions(previous: float, current: float) -> void:
	# Day started
	if previous < SUNRISE_HOUR and current >= SUNRISE_HOUR:
		_is_day = true
		day_started.emit()
		GameManager.get_core_system("logger").info("[DayNightController] Day started", "DayNight")

	# Night started
	if previous < SUNSET_HOUR and current >= SUNSET_HOUR:
		_is_day = false
		night_started.emit()
		GameManager.get_core_system("logger").info("[DayNightController] Night started", "DayNight")


# ============================================================================
# Public API
# ============================================================================

## Set current time (0-24)


func set_time(hour: float) -> void:
	_current_hour = clampf(hour, 0.0, 24.0)
	_update_visuals(_current_hour)
	time_changed.emit(_current_hour)


## Get current hour (0-24)


func get_time() -> float:
	return _current_hour


## Check if it's currently day


func is_daytime() -> bool:
	return _is_day


## Set cycle speed multiplier


func set_time_scale(scale: float) -> void:
	_calculate_cycle_speed()
	_cycle_speed *= scale


## Pause/resume cycle


func set_paused(paused: bool) -> void:
	cycle_enabled = not paused


# ============================================================================
# Multiplayer Sync (Server Authority)
# ============================================================================

@rpc("authority", "call_local", "reliable")
func sync_time(hour: float) -> void:
	_current_hour = hour
	_update_visuals(_current_hour)


## Called by server to sync time to all clients


func broadcast_time() -> void:
	if multiplayer.is_server():
		sync_time.rpc(_current_hour)
