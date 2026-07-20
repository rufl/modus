class_name RateLimiter
extends RefCounted

## Rate Limiter for controlling signal emission frequency
## Prevents signal flooding by enforcing minimum time intervals between emissions

## Configuration
var min_interval_seconds: float = 0.1  # Minimum time between emissions
var burst_size: int = 5  # Maximum burst emissions allowed
var burst_window_seconds: float = 1.0  # Time window for burst tracking

## State tracking
var _last_emission_time: float = 0.0
var _emission_count: int = 0
var _burst_window_start: float = 0.0
var _total_emissions: int = 0
var _total_throttled: int = 0


func _init(interval: float = 0.1, burst: int = 5, window: float = 1.0) -> void:
	min_interval_seconds = interval
	burst_size = burst
	burst_window_seconds = window
	_burst_window_start = Time.get_ticks_msec() / 1000.0


## Check if an emission is allowed
## Returns true if the emission should proceed, false if it should be throttled
func should_emit() -> bool:
	var current_time: float = Time.get_ticks_msec() / 1000.0

	# Check minimum interval
	var time_since_last: float = current_time - _last_emission_time
	if time_since_last < min_interval_seconds:
		_total_throttled += 1
		return false

	# Check burst limit
	var time_since_burst_start: float = current_time - _burst_window_start
	if time_since_burst_start >= burst_window_seconds:
		# Reset burst window
		_burst_window_start = current_time
		_emission_count = 0

	if _emission_count >= burst_size:
		_total_throttled += 1
		return false

	# Allow emission
	_last_emission_time = current_time
	_emission_count += 1
	_total_emissions += 1
	return true


## Force allow next emission (bypass rate limiting)
func force_emit() -> void:
	_last_emission_time = Time.get_ticks_msec() / 1000.0
	_emission_count += 1
	_total_emissions += 1


## Reset rate limiter state
func reset() -> void:
	_last_emission_time = 0.0
	_emission_count = 0
	_burst_window_start = Time.get_ticks_msec() / 1000.0


## Get statistics
func get_stats() -> Dictionary:
	return {
		"total_emissions": _total_emissions,
		"total_throttled": _total_throttled,
		"throttle_rate":
		(
			float(_total_throttled) / float(_total_emissions + _total_throttled)
			if (_total_emissions + _total_throttled) > 0
			else 0.0
		)
	}
