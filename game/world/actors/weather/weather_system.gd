class_name WeatherSys
extends Node

signal weather_changed(new_weather: int)
signal wind_changed(strength: float, direction: Vector3)

enum WeatherType { CLEAR = 0, RAIN = 1, SNOW = 2, STORM = 3, WINDY = 4 }

var current_weather: int = WeatherType.CLEAR
var current_wind_strength: float = 0.0
var current_wind_direction: Vector3 = Vector3.FORWARD
var transition_duration: float = 5.0


static func get_instance() -> WeatherSys:
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	return gs.weather as WeatherSys if gs else null


## Weather System - Global Weather State Manager
##
## Manages global weather state and synchronizes it across clients.
## Compatible with both real-time gameplay and Level Editor configuration.

# Current state

# Configuration (could be loaded from Level Data)


func _ready() -> void:
	name = "WeatherSystem"
	# Initialize default
	set_weather(WeatherType.CLEAR)


## Set weather type
## @param type: WeatherType enum
## @param instant: If true, skip transition


func set_weather(type: int, _instant: bool = false) -> void:
	if current_weather == type:
		return

	current_weather = type
	weather_changed.emit(current_weather)

	_update_wind_for_weather(type)


## Update wind parameters based on weather


func _update_wind_for_weather(type: int) -> void:
	var target_strength: float = 0.0

	match type:
		WeatherType.CLEAR:
			target_strength = 0.1
		WeatherType.RAIN:
			target_strength = 0.5
		WeatherType.SNOW:
			target_strength = 0.3
		WeatherType.STORM:
			target_strength = 1.0
		WeatherType.WINDY:
			target_strength = 0.8

	set_wind(target_strength, current_wind_direction)


## Set wind parameters


func set_wind(strength: float, direction: Vector3 = Vector3.ZERO) -> void:
	current_wind_strength = clampf(strength, 0.0, 1.0)
	if direction != Vector3.ZERO:
		current_wind_direction = direction.normalized()

	wind_changed.emit(current_wind_strength, current_wind_direction)
	# Update global shader parameters if any
	RenderingServer.global_shader_parameter_set("wind_strength", current_wind_strength)
	RenderingServer.global_shader_parameter_set("wind_direction", current_wind_direction)


## Get current weather name


func get_weather_name() -> String:
	return WeatherType.keys()[current_weather]
