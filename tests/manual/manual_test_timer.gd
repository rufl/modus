extends Node
class_name ManualTestTimer

## Records reviewed manual test rows and writes validator-compatible CSV evidence.

signal test_started(test_name: String)
signal test_completed(test_name: String, duration: float)
signal session_started(session_name: String)
signal session_completed(session_name: String, total_duration: float)

const DEFAULT_OUTPUT_DIRECTORY := "user://manual_test_logs"
const VALID_RESULTS: Array[String] = ["pass", "fail", "skip", "incomplete"]

var is_tracking: bool = false
var session_name: String = ""
var session_start_time: float = 0.0
var current_test_name: String = ""
var current_test_start_time: float = 0.0
var completed_tests: Array[Dictionary] = []
var output_directory: String = ""
var log_file_path: String = ""
var session_metadata: Dictionary = {}
var log_file: FileAccess = null


func _ready() -> void:
	print("[ManualTestTimer] Manual test timer ready")


func start_session(p_session_name: String = "", metadata: Dictionary = {}) -> String:
	if is_tracking:
		push_warning("[ManualTestTimer] Session already in progress")
		return session_name

	if p_session_name.is_empty():
		var datetime: Dictionary = Time.get_datetime_dict_from_system()
		p_session_name = (
			"manual_test_%04d%02d%02d_%02d%02d%02d"
			% [
				datetime.year,
				datetime.month,
				datetime.day,
				datetime.hour,
				datetime.minute,
				datetime.second,
			]
		)

	session_name = _safe_session_name(p_session_name)
	session_metadata = _metadata_with_defaults(metadata)
	completed_tests.clear()
	current_test_name = ""
	current_test_start_time = 0.0

	if not _create_log_file():
		session_name = ""
		session_metadata.clear()
		return ""

	session_start_time = Time.get_ticks_msec() / 1000.0
	is_tracking = true
	session_started.emit(session_name)
	_telemetry_checkpoint(
		"manual_session_started", {"session_name": session_name, "metadata": session_metadata}
	)
	print("[ManualTestTimer] Started session: %s" % session_name)
	return session_name


func start_test(test_name: String) -> void:
	if not is_tracking:
		push_warning("[ManualTestTimer] No session in progress. Call start_session() first")
		return

	if not current_test_name.is_empty():
		push_warning(
			(
				"[ManualTestTimer] Test '%s' still in progress. Completing it first."
				% current_test_name
			)
		)
		complete_test("incomplete", "A new test started before this item was reviewed")
	current_test_name = _clean_csv_value(test_name)
	current_test_start_time = Time.get_ticks_msec() / 1000.0
	test_started.emit(current_test_name)
	_telemetry_checkpoint("manual_test_started", {"test_name": current_test_name})
	print("[ManualTestTimer] Started test: %s" % current_test_name)


func complete_test(result: String = "pass", notes: String = "") -> void:
	if not is_tracking:
		push_warning("[ManualTestTimer] No session in progress")
		return
	if current_test_name.is_empty():
		push_warning("[ManualTestTimer] No test in progress")
		return

	var normalized_result := result.to_lower().strip_edges()
	if normalized_result not in VALID_RESULTS:
		normalized_result = "incomplete"

	var duration := Time.get_ticks_msec() / 1000.0 - current_test_start_time
	var test_result: Dictionary = {
		"name": current_test_name,
		"duration": duration,
		"result": normalized_result,
		"notes": _clean_csv_value(notes),
		"timestamp": Time.get_datetime_string_from_system(),
	}
	completed_tests.append(test_result)

	if log_file:
		(
			log_file
			. store_line(
				(
					"%s,%s,%.2f,%s,%s"
					% [
						test_result.timestamp,
						test_result.name,
						test_result.duration,
						test_result.result,
						test_result.notes,
					]
				)
			)
		)
		log_file.flush()

	test_completed.emit(current_test_name, duration)
	_telemetry_checkpoint(
		"manual_test_completed",
		{
			"test_name": current_test_name,
			"result": normalized_result,
			"duration": duration,
			"notes": test_result.notes
		}
	)
	print(
		(
			"[ManualTestTimer] Completed test: %s (%.2fs, %s)"
			% [current_test_name, duration, normalized_result]
		)
	)
	current_test_name = ""
	current_test_start_time = 0.0


func end_session() -> Dictionary:
	if not is_tracking:
		push_warning("[ManualTestTimer] No session in progress")
		return {}

	if not current_test_name.is_empty():
		complete_test("incomplete", "Session ended while test was in progress")

	var total_duration := Time.get_ticks_msec() / 1000.0 - session_start_time
	var stats := _calculate_statistics(total_duration)
	if log_file:
		_write_summary(stats)
		log_file.close()
	session_completed.emit(session_name, total_duration)
	_telemetry_checkpoint(
		"manual_session_completed", {"session_name": session_name, "stats": stats}
	)
	is_tracking = false
	print("[ManualTestTimer] Session completed: %s (%.2fs)" % [session_name, total_duration])
	return stats


func get_statistics() -> Dictionary:
	if not is_tracking:
		return {}
	return _calculate_statistics(Time.get_ticks_msec() / 1000.0 - session_start_time)


func _calculate_statistics(total_duration: float) -> Dictionary:
	var passed := 0
	var failed := 0
	var skipped := 0
	var incomplete := 0
	var total_test_time := 0.0
	var test_durations: Array[float] = []

	for test: Dictionary in completed_tests:
		total_test_time += test.duration
		test_durations.append(test.duration)
		match test.result:
			"pass":
				passed += 1
			"fail":
				failed += 1
			"skip":
				skipped += 1
			_:
				incomplete += 1

	var average := 0.0
	var minimum := 0.0
	var maximum := 0.0
	if not test_durations.is_empty():
		average = total_test_time / float(test_durations.size())
		minimum = test_durations.min()
		maximum = test_durations.max()

	return {
		"session_name": session_name,
		"total_duration": total_duration,
		"total_tests": completed_tests.size(),
		"passed": passed,
		"failed": failed,
		"skipped": skipped,
		"incomplete": incomplete,
		"total_test_time": total_test_time,
		"avg_test_duration": average,
		"min_test_duration": minimum,
		"max_test_duration": maximum,
		"overhead_time": maxf(total_duration - total_test_time, 0.0),
		"tests": completed_tests.duplicate(true),
		"metadata": session_metadata.duplicate(true),
		"log_file_path": log_file_path,
	}


func _create_log_file() -> bool:
	var directory := _resolved_output_directory()
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("[ManualTestTimer] Failed to create log directory: %s" % directory)
		return false

	log_file_path = directory.path_join("%s.csv" % session_name)
	log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if not log_file:
		push_error("[ManualTestTimer] Failed to create log file: %s" % log_file_path)
		return false

	log_file.store_line("Timestamp,TestName,Duration,Result,Notes")
	log_file.flush()
	print("[ManualTestTimer] Created log file: %s" % log_file_path)
	return true


func _resolved_output_directory() -> String:
	var configured := output_directory.strip_edges()
	if configured.is_empty():
		configured = OS.get_environment("MODUS_MANUAL_EVIDENCE_DIR").strip_edges()
	if configured.is_empty():
		configured = DEFAULT_OUTPUT_DIRECTORY
	if configured.begins_with("res://") or configured.begins_with("user://"):
		return ProjectSettings.globalize_path(configured)
	if configured.is_absolute_path():
		return configured
	return ProjectSettings.globalize_path("res://" + configured.trim_prefix("./"))


func _metadata_with_defaults(metadata: Dictionary) -> Dictionary:
	var viewport_size := DisplayServer.window_get_size()
	var scene_path := "unknown"
	if get_tree() and get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path
	var build_identity := "unknown"
	if GameManager:
		build_identity = GameManager.GAME_VERSION

	var values: Dictionary = {
		"tester": OS.get_environment("MODUS_MANUAL_TESTER"),
		"os": OS.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"resolution": "%dx%d" % [viewport_size.x, viewport_size.y],
		"input_devices": OS.get_environment("MODUS_MANUAL_INPUTS"),
		"scene": scene_path,
		"build_identity": build_identity,
	}
	for key: Variant in metadata:
		values[str(key)] = _clean_csv_value(str(metadata[key]))
	return values


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
	log_file.store_line("skipped,%d" % stats.skipped)
	log_file.store_line("incomplete,%d" % stats.incomplete)
	log_file.store_line("total_test_time,%.2f" % stats.total_test_time)
	log_file.store_line("avg_test_duration,%.2f" % stats.avg_test_duration)
	log_file.store_line("min_test_duration,%.2f" % stats.min_test_duration)
	log_file.store_line("max_test_duration,%.2f" % stats.max_test_duration)
	log_file.store_line("overhead_time,%.2f" % stats.overhead_time)
	for key: String in [
		"tester", "os", "renderer", "resolution", "input_devices", "scene", "build_identity"
	]:
		log_file.store_line(
			"metadata_%s,%s" % [key, _clean_csv_value(session_metadata.get(key, ""))]
		)
	log_file.flush()


func _safe_session_name(value: String) -> String:
	var safe := ""
	var allowed := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
	for index: int in value.strip_edges().length():
		var character := value.substr(index, 1)
		safe += character if allowed.contains(character) else "_"
	while safe.contains("__"):
		safe = safe.replace("__", "_")
	while safe.begins_with("_"):
		safe = safe.substr(1)
	while safe.ends_with("_"):
		safe = safe.left(-1)
	return safe if not safe.is_empty() else "manual_test"


func _clean_csv_value(value: String) -> String:
	return value.replace("\r", " ").replace("\n", " ").replace(",", ";").strip_edges()


func _telemetry_checkpoint(event_name: String, fields: Dictionary) -> void:
	var telemetry := get_node_or_null("/root/LocalValidationTelemetry")
	if telemetry and telemetry.has_method("checkpoint"):
		telemetry.checkpoint(event_name, fields)


func print_statistics() -> void:
	var stats := get_statistics()
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
	print("  Skipped: %d" % stats.skipped)
	print("  Incomplete: %d" % stats.incomplete)
	print("Average Test Duration: %.2fs" % stats.avg_test_duration)
	print(
		"Min/Max Test Duration: %.2fs / %.2fs" % [stats.min_test_duration, stats.max_test_duration]
	)
	print(
		(
			"Overhead Time: %.2fs (%.1f%%)"
			% [
				stats.overhead_time,
				(
					(stats.overhead_time / stats.total_duration * 100.0)
					if stats.total_duration > 0
					else 0.0
				),
			]
		)
	)
	print("=".repeat(60) + "\n")
