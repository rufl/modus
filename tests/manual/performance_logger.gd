extends Node
class_name PerformanceLogger

## Performance Logger for Manual Testing
## Logs frame-by-frame performance metrics to CSV file for analysis

signal logging_started(session_name: String)
signal logging_stopped(session_name: String, file_path: String)

var is_logging: bool = false
var log_file: FileAccess = null
var session_name: String = ""
var start_time: float = 0.0
var frame_count: int = 0

# Statistics tracking
var fps_samples: Array[float] = []
var memory_samples: Array[float] = []
var frame_time_samples: Array[float] = []

# Configuration
var sample_interval: float = 1.0  # Log every second
var last_sample_time: float = 0.0


func _ready() -> void:
	set_process(false)  # Don't process until logging starts


## Start logging performance metrics
func start_logging(p_session_name: String = "") -> String:
	if is_logging:
		push_warning("[PerformanceLogger] Already logging")
		return ""

	# Generate session name if not provided
	if p_session_name.is_empty():
		var datetime: Dictionary = Time.get_datetime_dict_from_system()
		p_session_name = (
			"session_%04d%02d%02d_%02d%02d%02d"
			% [
				datetime.year,
				datetime.month,
				datetime.day,
				datetime.hour,
				datetime.minute,
				datetime.second
			]
		)

	session_name = p_session_name

	# Create logs directory
	var log_dir: String = "user://performance_logs"
	if not DirAccess.dir_exists_absolute(log_dir):
		DirAccess.make_dir_recursive_absolute(log_dir)

	# Create log file
	var file_path: String = "%s/%s.csv" % [log_dir, session_name]
	log_file = FileAccess.open(file_path, FileAccess.WRITE)

	if not log_file:
		push_error("[PerformanceLogger] Failed to create log file: %s" % file_path)
		return ""

	# Write CSV header
	log_file.store_line("Time,FPS,FrameTime,Memory,ActivePools,VisibleEnemies")

	# Initialize tracking
	is_logging = true
	start_time = Time.get_ticks_msec() / 1000.0
	last_sample_time = start_time
	frame_count = 0
	fps_samples.clear()
	memory_samples.clear()
	frame_time_samples.clear()

	set_process(true)

	logging_started.emit(session_name)
	print("[PerformanceLogger] Started logging: %s" % file_path)

	return file_path


## Stop logging and generate statistics
func stop_logging() -> void:
	if not is_logging:
		push_warning("[PerformanceLogger] Not currently logging")
		return

	is_logging = false
	set_process(false)

	# Write statistics summary
	_write_statistics()

	# Close file
	var file_path: String = log_file.get_path_absolute()
	log_file.close()
	log_file = null

	logging_stopped.emit(session_name, file_path)
	print("[PerformanceLogger] Stopped logging: %s" % file_path)
	print("[PerformanceLogger] Frames logged: %d" % frame_count)


func _process(_delta: float) -> void:
	if not is_logging:
		return

	var current_time: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = current_time - last_sample_time

	# Sample at configured interval
	if elapsed >= sample_interval:
		_log_frame()
		last_sample_time = current_time


func _log_frame() -> void:
	if not log_file:
		return

	# Calculate metrics
	var elapsed_time: float = (Time.get_ticks_msec() / 1000.0) - start_time
	var fps: float = Engine.get_frames_per_second()
	# Convert to ms
	var frame_time: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	# Convert to MB
	var memory: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0

	# Get game-specific metrics
	var active_pools: int = _get_active_pool_count()
	var visible_enemies: int = _get_visible_enemy_count()

	# Store samples for statistics
	fps_samples.append(fps)
	memory_samples.append(memory)
	frame_time_samples.append(frame_time)

	# Write to CSV
	log_file.store_line(
		(
			"%.1f,%.1f,%.2f,%.1f,%d,%d"
			% [elapsed_time, fps, frame_time, memory, active_pools, visible_enemies]
		)
	)

	frame_count += 1


func _write_statistics() -> void:
	if not log_file or fps_samples.is_empty():
		return

	# Calculate statistics
	var avg_fps: float = _calculate_average(fps_samples)
	var min_fps: float = _calculate_min(fps_samples)
	var max_fps: float = _calculate_max(fps_samples)
	var avg_memory: float = _calculate_average(memory_samples)
	var max_memory: float = _calculate_max(memory_samples)
	var avg_frame_time: float = _calculate_average(frame_time_samples)
	var max_frame_time: float = _calculate_max(frame_time_samples)

	# Write statistics section
	log_file.store_line("")
	log_file.store_line("# Statistics")
	log_file.store_line("avg_fps,%.1f" % avg_fps)
	log_file.store_line("min_fps,%.1f" % min_fps)
	log_file.store_line("max_fps,%.1f" % max_fps)
	log_file.store_line("avg_frame_time,%.2f" % avg_frame_time)
	log_file.store_line("max_frame_time,%.2f" % max_frame_time)
	log_file.store_line("avg_memory,%.1f" % avg_memory)
	log_file.store_line("max_memory,%.1f" % max_memory)
	log_file.store_line("total_frames,%d" % frame_count)
	log_file.store_line("duration,%.1f" % ((Time.get_ticks_msec() / 1000.0) - start_time))


func _get_active_pool_count() -> int:
	## Get count of active object pools from GameManager
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return 0
	var pools_service: Node = gm.get_core_system("pools")
	if not pools_service or not pools_service.has_method("get_pool_count"):
		return 0
	return pools_service.get_pool_count()


func _get_visible_enemy_count() -> int:
	## Get count of visible enemies from gameplay service
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return 0
	var gameplay_service: Node = gm.get_core_system("gameplay")
	if not gameplay_service:
		return 0

	# Try to get entity registry
	if not ("entity_registry" in gameplay_service):
		return 0

	var entity_registry: Node = gameplay_service.entity_registry
	if not entity_registry or not entity_registry.has_method("get_all_enemies"):
		return 0

	var enemies: Array = entity_registry.get_all_enemies()

	# Count visible enemies (in camera frustum)
	var visible_count: int = 0
	for enemy: Node in enemies:
		if enemy is Node3D and enemy.is_visible_in_tree():
			visible_count += 1

	return visible_count


## Calculate average of array
func _calculate_average(samples: Array[float]) -> float:
	if samples.is_empty():
		return 0.0
	var sum: float = 0.0
	for value: float in samples:
		sum += value
	return sum / float(samples.size())


## Calculate minimum of array
func _calculate_min(samples: Array[float]) -> float:
	if samples.is_empty():
		return 0.0
	var min_val: float = samples[0]
	for value: float in samples:
		if value < min_val:
			min_val = value
	return min_val


## Calculate maximum of array
func _calculate_max(samples: Array[float]) -> float:
	if samples.is_empty():
		return 0.0
	var max_val: float = samples[0]
	for value: float in samples:
		if value > max_val:
			max_val = value
	return max_val


## Get current statistics without stopping logging
func get_current_statistics() -> Dictionary:
	if fps_samples.is_empty():
		return {}

	return {
		"avg_fps": _calculate_average(fps_samples),
		"min_fps": _calculate_min(fps_samples),
		"max_fps": _calculate_max(fps_samples),
		"avg_memory": _calculate_average(memory_samples),
		"max_memory": _calculate_max(memory_samples),
		"avg_frame_time": _calculate_average(frame_time_samples),
		"max_frame_time": _calculate_max(frame_time_samples),
		"frame_count": frame_count,
		"duration": (Time.get_ticks_msec() / 1000.0) - start_time
	}
