extends Node
class_name ManualTestTimer

## Manual Test Timing Tracker
## Tracks time spent on manual testing sessions and individual test cases

signal test_started(test_name: String)
signal test_completed(test_name: String, duration: float)
signal session_started(session_name: String)
signal session_completed(session_name: String, total_duration: float)

var is_tracking: bool = false
var session_name: String = ""
var session_start_time: float = 0.0
var current_test_name: String = ""
var current_test_start_time: float = 0.0

# Test results tracking
var completed_tests: Array[Dictionary] = []
var log_file: FileAccess = null


func _ready() -> void:
	print("[ManualTestTimer] Manual test timer ready")


## Start a new testing session
func start_session(p_session_name: String = "") -> String:
	if is_tracking:
		push_warning("[ManualTestTimer] Session already in progress")
		return session_name
	
	# Generate session name if not provided
	if p_session_name.is_empty():
		var datetime: Dictionary = Time.get_datetime_dict_from_system()
		p_session_name = "manual_test_%04d%02d%02d_%02d%02d%02d" % [
			datetime.year, datetime.month, datetime.day,
			datetime.hour, datetime.minute, datetime.second
		]
	
	session_name = p_session_name
	session_start_time = Time.get_ticks_msec() / 1000.0
	is_tracking = true
	completed_tests.clear()
	
	# Create log file
	_create_log_file()
	
	session_started.emit(session_name)
	print("[ManualTestTimer] Started session: %s" % session_name)
	
	return session_name


## Start timing a specific test
func start_test(test_name: String) -> void:
	if not is_tracking:
		push_warning("[ManualTestTimer] No session in progress. Call start_session() first")
		return
	
	if not current_test_name.is_empty():
		push_warning("[ManualTestTimer] Test '%s' still in progress. Completing it first." % current_test_name)
		complete_test("incomplete")
	
	current_test_name = test_name
	current_test_start_time = Time.get_ticks_msec() / 1000.0
	
	test_started.emit(test_name)
	print("[ManualTestTimer] Started test: %s" % test_name)


## Complete the current test
func complete_test(result: String = "pass", notes: String = "") -> void:
	if not is_tracking:
		push_warning("[ManualTestTimer] No session in progress")
		return
	
	if current_test_name.is_empty():
		push_warning("[ManualTestTimer] No test in progress")
		return
	
	var end_time: float = Time.get_ticks_msec() / 1000.0
	var duration: float = end_time - current_test_start_time
	
	var test_result: Dictionary = {
		"name": current_test_name,
		"duration": duration,
		"result": result,
		"notes": notes,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	completed_tests.append(test_result)
	
	# Log to file
	if log_file:
		log_file.store_line("%s,%s,%.2f,%s,%s" % [
			test_result.timestamp,
			test_result.name,
			test_result.duration,
			test_result.result,
			test_result.notes.replace(",", ";")  # Escape commas in notes
		])
		log_file.flush()
	
	test_completed.emit(current_test_name, duration)
	print("[ManualTestTimer] Completed test: %s (%.2fs, %s)" % [current_test_name, duration, result])
	
	current_test_name = ""
	current_test_start_time = 0.0


## End the testing session
func end_session() -> Dictionary:
	if not is_tracking:
		push_warning("[ManualTestTimer] No session in progress")
		return {}
	
	# Complete any in-progress test
	if not current_test_name.is_empty():
		complete_test("incomplete", "Session ended while test was in progress")
	
	var end_time: float = Time.get_ticks_msec() / 1000.0
	var total_duration: float = end_time - session_start_time
	
	# Calculate statistics
	var stats: Dictionary = _calculate_statistics(total_duration)
	
	# Write summary to log
	if log_file:
		_write_summary(stats)
		log_file.close()
		log_file = null
	
	is_tracking = false
	
	session_completed.emit(session_name, total_duration)
	print("[ManualTestTimer] Session completed: %s (%.2fs)" % [session_name, total_duration])
	
	return stats


## Get current session statistics
func get_statistics() -> Dictionary:
	if not is_tracking:
		return {}
	
	var current_time: float = Time.get_ticks_msec() / 1000.0
	var duration: float = current_time - session_start_time
	
	return _calculate_statistics(duration)


func _calculate_statistics(total_duration: float) -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var incomplete: int = 0
	var total_test_time: float = 0.0
	var test_durations: Array[float] = []
	
	for test: Dictionary in completed_tests:
		total_test_time += test.duration
		test_durations.append(test.duration)
		
		match test.result:
			"pass":
				passed += 1
			"fail":
				failed += 1
			_:
				incomplete += 1
	
	var avg_test_duration: float = 0.0
	var min_test_duration: float = 0.0
	var max_test_duration: float = 0.0
	
	if not test_durations.is_empty():
		avg_test_duration = total_test_time / float(test_durations.size())
		min_test_duration = test_durations.min()
		max_test_duration = test_durations.max()
	
	return {
		"session_name": session_name,
		"total_duration": total_duration,
		"total_tests": completed_tests.size(),
		"passed": passed,
		"failed": failed,
		"incomplete": incomplete,
		"total_test_time": total_test_time,
		"avg_test_duration": avg_test_duration,
		"min_test_duration": min_test_duration,
		"max_test_duration": max_test_duration,
		"overhead_time": total_duration - total_test_time,
		"tests": completed_tests.duplicate()
	}


func _create_log_file() -> void:
	# Create logs directory
	var log_dir: String = "user://manual_test_logs"
	if not DirAccess.dir_exists_absolute(log_dir):
		DirAccess.make_dir_recursive_absolute(log_dir)
	
	# Create log file
	var file_path: String = "%s/%s.csv" % [log_dir, session_name]
	log_file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if not log_file:
		push_error("[ManualTestTimer] Failed to create log file: %s" % file_path)
		return
	
	# Write CSV header
	log_file.store_line("Timestamp,TestName,Duration,Result,Notes")
	print("[ManualTestTimer] Created log file: %s" % file_path)


func _write_summary(stats: Dictionary) -> void:
	if not log_file:
		return
	
	log_file.store_line("")
	log_file.store_line("# Session Summary")
	log_file.store_line("session_name,%s" % stats.session_name)
	log_file.store_line("total_duration,%.2f" % stats.total_duration)
	log_file.store_line("total_tests,%d" % stats.total_tests)
	log_file.store_line("passed,%d" % stats.passed)
	log_file.store_line("failed,%d" % stats.failed)
	log_file.store_line("incomplete,%d" % stats.incomplete)
	log_file.store_line("total_test_time,%.2f" % stats.total_test_time)
	log_file.store_line("avg_test_duration,%.2f" % stats.avg_test_duration)
	log_file.store_line("min_test_duration,%.2f" % stats.min_test_duration)
	log_file.store_line("max_test_duration,%.2f" % stats.max_test_duration)
	log_file.store_line("overhead_time,%.2f" % stats.overhead_time)


## Print current statistics to console
func print_statistics() -> void:
	var stats: Dictionary = get_statistics()
	if stats.is_empty():
		print("[ManualTestTimer] No session in progress")
		return
	
	print("\n" + "=".repeat(60))
	print("  MANUAL TEST SESSION STATISTICS")
	print("=".repeat(60))
	print("Session: %s" % stats.session_name)
	print("Duration: %.2fs (%.1f minutes)" % [stats.total_duration, stats.total_duration / 60.0])
	print("Tests Completed: %d" % stats.total_tests)
	print("  Passed: %d" % stats.passed)
	print("  Failed: %d" % stats.failed)
	print("  Incomplete: %d" % stats.incomplete)
	print("Average Test Duration: %.2fs" % stats.avg_test_duration)
	print("Min/Max Test Duration: %.2fs / %.2fs" % [stats.min_test_duration, stats.max_test_duration])
	print("Overhead Time: %.2fs (%.1f%%)" % [
		stats.overhead_time,
		(stats.overhead_time / stats.total_duration * 100.0) if stats.total_duration > 0 else 0.0
	])
	print("=".repeat(60) + "\n")
