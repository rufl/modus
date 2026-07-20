extends Node

## Performance Profiler for Splitscreen Multiplayer
## Tracks FPS, frame time, memory usage, and rendering performance

signal performance_data_updated(data: Dictionary)
signal performance_warning(message: String)
signal performance_critical(message: String)

## Performance thresholds (constants for maintainability)
const TARGET_FPS: float = 60.0
const WARNING_FPS_THRESHOLD: float = TARGET_FPS * 0.83  # 83% of target (50 FPS)
const CRITICAL_FPS_THRESHOLD: float = TARGET_FPS * 0.5  # 50% of target (30 FPS)
const WARNING_FRAME_TIME_MS: float = 1000.0 / WARNING_FPS_THRESHOLD  # ~20ms
const CRITICAL_FRAME_TIME_MS: float = 1000.0 / CRITICAL_FPS_THRESHOLD  # ~33.3ms
const HISTORY_DURATION_SECONDS: float = 5.0
const HISTORY_SIZE: int = int(TARGET_FPS * HISTORY_DURATION_SECONDS)  # 300 samples

## Performance thresholds (runtime configurable)
var target_fps: float = TARGET_FPS
var warning_fps_threshold: float = WARNING_FPS_THRESHOLD
var critical_fps_threshold: float = CRITICAL_FPS_THRESHOLD
var warning_frame_time_ms: float = WARNING_FRAME_TIME_MS
var critical_frame_time_ms: float = CRITICAL_FRAME_TIME_MS

## Tracking data
var _fps_history: Array[float] = []
var _frame_time_history: Array[float] = []
var _memory_history: Array[int] = []
var _history_size: int = HISTORY_SIZE

## Statistics
var _min_fps: float = INF
var _max_fps: float = 0.0
var _avg_fps: float = 0.0
var _min_frame_time: float = INF
var _max_frame_time: float = 0.0
var _avg_frame_time: float = 0.0
var _peak_memory: int = 0

## Profiling state
var _profiling_enabled: bool = false
var _start_time: int = 0
var _frame_count: int = 0
var _last_report_time: float = 0.0
var _report_interval: float = 1.0  # Report every second


func _ready() -> void:
	set_process(false)


func start_profiling() -> void:
	if _profiling_enabled:
		return

	_profiling_enabled = true
	_start_time = Time.get_ticks_msec()
	_frame_count = 0
	_reset_statistics()
	set_process(true)

	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info("Profiling started", "PerformanceProfiler")


func stop_profiling() -> Dictionary:
	if not _profiling_enabled:
		return {}

	_profiling_enabled = false
	set_process(false)

	var report: Dictionary = generate_report()
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info("Profiling stopped", "PerformanceProfiler")
	return report


func _process(delta: float) -> void:
	if not _profiling_enabled:
		return

	_frame_count += 1

	# Collect metrics
	var current_fps: float = Engine.get_frames_per_second()
	var frame_time_ms: float = delta * 1000.0
	var memory_usage: int = OS.get_static_memory_usage()

	# Update history
	_fps_history.append(current_fps)
	_frame_time_history.append(frame_time_ms)
	_memory_history.append(memory_usage)

	# Trim history
	if _fps_history.size() > _history_size:
		_fps_history.pop_front()
	if _frame_time_history.size() > _history_size:
		_frame_time_history.pop_front()
	if _memory_history.size() > _history_size:
		_memory_history.pop_front()

	# Update statistics
	_update_statistics(current_fps, frame_time_ms, memory_usage)

	# Check thresholds
	_check_performance_thresholds(current_fps, frame_time_ms)

	# Periodic reporting
	_last_report_time += delta
	if _last_report_time >= _report_interval:
		_last_report_time = 0.0
		var data: Dictionary = get_current_metrics()
		performance_data_updated.emit(data)


func _update_statistics(fps: float, frame_time: float, memory: int) -> void:
	# FPS statistics
	_min_fps = min(_min_fps, fps)
	_max_fps = max(_max_fps, fps)

	# Frame time statistics
	_min_frame_time = min(_min_frame_time, frame_time)
	_max_frame_time = max(_max_frame_time, frame_time)

	# Memory statistics
	_peak_memory = max(_peak_memory, memory)

	# Calculate averages
	if _fps_history.size() > 0:
		var fps_sum: float = 0.0
		for f in _fps_history:
			fps_sum += f
		_avg_fps = fps_sum / _fps_history.size()

	if _frame_time_history.size() > 0:
		var ft_sum: float = 0.0
		for ft in _frame_time_history:
			ft_sum += ft
		_avg_frame_time = ft_sum / _frame_time_history.size()


func _check_performance_thresholds(fps: float, frame_time: float) -> void:
	# Check FPS thresholds
	if fps < critical_fps_threshold:
		performance_critical.emit("Critical FPS: %.1f (target: %.1f)" % [fps, target_fps])
	elif fps < warning_fps_threshold:
		performance_warning.emit("Low FPS: %.1f (target: %.1f)" % [fps, target_fps])

	# Check frame time thresholds
	if frame_time > critical_frame_time_ms:
		performance_critical.emit(
			"Critical frame time: %.2fms (max: %.2fms)" % [frame_time, critical_frame_time_ms]
		)
	elif frame_time > warning_frame_time_ms:
		performance_warning.emit(
			"High frame time: %.2fms (max: %.2fms)" % [frame_time, warning_frame_time_ms]
		)


func _reset_statistics() -> void:
	_fps_history.clear()
	_frame_time_history.clear()
	_memory_history.clear()
	_min_fps = INF
	_max_fps = 0.0
	_avg_fps = 0.0
	_min_frame_time = INF
	_max_frame_time = 0.0
	_avg_frame_time = 0.0
	_peak_memory = 0
	_last_report_time = 0.0


func get_current_metrics() -> Dictionary:
	return {
		"fps":
		{
			"current": Engine.get_frames_per_second(),
			"min": _min_fps if _min_fps != INF else 0.0,
			"max": _max_fps,
			"avg": _avg_fps,
			"target": target_fps
		},
		"frame_time":
		{
			"current":
			(
				(1.0 / Engine.get_frames_per_second()) * 1000.0
				if Engine.get_frames_per_second() > 0
				else 0.0
			),
			"min": _min_frame_time if _min_frame_time != INF else 0.0,
			"max": _max_frame_time,
			"avg": _avg_frame_time
		},
		"memory":
		{
			"current": OS.get_static_memory_usage(),
			"peak": _peak_memory,
			"current_mb": OS.get_static_memory_usage() / 1024.0 / 1024.0,
			"peak_mb": _peak_memory / 1024.0 / 1024.0
		},
		"session":
		{
			"duration_seconds": (Time.get_ticks_msec() - _start_time) / 1000.0,
			"frame_count": _frame_count
		}
	}


func generate_report() -> Dictionary:
	var metrics: Dictionary = get_current_metrics()

	# Add analysis
	metrics["analysis"] = {
		"fps_stable": _is_fps_stable(),
		"frame_time_stable": _is_frame_time_stable(),
		"memory_leak_detected": _detect_memory_leak(),
		"performance_grade": _calculate_performance_grade(),
		"bottlenecks": _identify_bottlenecks()
	}

	return metrics


func _is_fps_stable() -> bool:
	if _fps_history.size() < 60:
		return true  # Not enough data

	var variance: float = _calculate_variance(_fps_history)
	return variance < 100.0  # Low variance = stable


func _is_frame_time_stable() -> bool:
	if _frame_time_history.size() < 60:
		return true

	var variance: float = _calculate_variance(_frame_time_history)
	return variance < 5.0  # Low variance = stable


func _detect_memory_leak() -> bool:
	if _memory_history.size() < 180:  # Need 3 seconds of data
		return false

	# Check if memory is consistently increasing
	var first_third: Array = _memory_history.slice(0, 60)
	var last_third: Array = _memory_history.slice(-60, _memory_history.size())

	var first_avg: float = _calculate_average(first_third)
	var last_avg: float = _calculate_average(last_third)

	# If memory increased by more than 10MB, potential leak
	var increase_mb: float = (last_avg - first_avg) / 1024.0 / 1024.0

	# Additional check: verify trend is consistent
	if increase_mb > 10.0:
		# Check middle third to confirm trend
		var middle_third: Array = _memory_history.slice(60, 120)
		var middle_avg: float = _calculate_average(middle_third)

		# Memory should be increasing consistently
		if middle_avg > first_avg and last_avg > middle_avg:
			# Calculate leak rate (MB per second)
			var duration_seconds: float = _history_size / 60.0  # Assuming 60fps
			var leak_rate: float = increase_mb / duration_seconds

			push_warning(
				(
					"[PerformanceProfiler] Memory leak detected: %.2f MB increase (%.2f MB/s)"
					% [increase_mb, leak_rate]
				)
			)
			return true

	return false


func _calculate_performance_grade() -> String:
	if _avg_fps >= target_fps * 0.95:
		return "A"
	if _avg_fps >= target_fps * 0.85:
		return "B"
	if _avg_fps >= target_fps * 0.70:
		return "C"
	if _avg_fps >= target_fps * 0.50:
		return "D"
	return "F"


func _identify_bottlenecks() -> Array[String]:
	var bottlenecks: Array[String] = []

	if _avg_fps < target_fps * 0.9:
		bottlenecks.append("Low average FPS (%.1f)" % _avg_fps)

	if _max_frame_time > critical_frame_time_ms:
		bottlenecks.append("Frame time spikes (%.2fms)" % _max_frame_time)

	if _peak_memory > 1024 * 1024 * 1024:  # 1GB
		bottlenecks.append("High memory usage (%.1fMB)" % (_peak_memory / 1024.0 / 1024.0))

	if not _is_fps_stable():
		bottlenecks.append("Unstable FPS")

	return bottlenecks


func _calculate_variance(data: Array) -> float:
	if data.size() == 0:
		return 0.0

	var mean: float = _calculate_average(data)
	var sum_squared_diff: float = 0.0

	for value: float in data:
		var diff: float = value - mean
		sum_squared_diff += diff * diff

	return sum_squared_diff / data.size()


func _calculate_average(data: Array) -> float:
	if data.size() == 0:
		return 0.0

	var sum: float = 0.0
	for value: float in data:
		sum += value

	return sum / data.size()


func export_report_to_file(filepath: String) -> bool:
	var report: Dictionary = generate_report()
	var file: FileAccess = FileAccess.open(filepath, FileAccess.WRITE)

	if file == null:
		push_error("Failed to open file for writing: %s" % filepath)
		return false

	file.store_string(JSONHelper.safe_stringify(report, "\t"))
	file.close()

	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info("Report exported to: %s" % filepath, "PerformanceProfiler")
	return true


func is_profiling() -> bool:
	return _profiling_enabled
