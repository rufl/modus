class_name TestingTimeProfiler
extends Node

## Testing Time Profiler
## Tracks and logs actual testing time with session management
## Provides verifiable data for testing hours

signal session_started(session_id: String, timestamp: float)
signal session_ended(session_id: String, duration: float)
signal milestone_reached(hours: float)

const LOG_FILE := "user://testing_time_log.json"
const SESSION_FILE := "user://current_test_session.json"

var current_session: Dictionary = {}
var total_testing_time: float = 0.0
var session_start_time: float = 0.0
var is_session_active: bool = false

# Statistics
var total_sessions: int = 0
var longest_session: float = 0.0
var average_session: float = 0.0

# Milestones (in hours)
const MILESTONES := [1.0, 5.0, 10.0, 20.0, 40.0, 60.0, 80.0, 100.0]
var reached_milestones: Array[float] = []


func _ready() -> void:
	_load_history()
	_check_for_crashed_session()

	# Auto-start session if in testing mode
	if OS.has_feature("editor") or OS.is_debug_build():
		start_session("auto")


func _exit_tree() -> void:
	if is_session_active:
		end_session()


## Start a new testing session
func start_session(session_type: String = "manual") -> String:
	if is_session_active:
		push_warning("[TestingTimeProfiler] Session already active, ending previous session")
		end_session()

	var session_id := _generate_session_id()
	session_start_time = Time.get_unix_time_from_system()
	is_session_active = true

	current_session = {
		"id": session_id,
		"type": session_type,
		"start_time": session_start_time,
		"start_datetime": Time.get_datetime_string_from_system(),
		"platform": OS.get_name(),
		"debug_build": OS.is_debug_build(),
		"events": []
	}

	_save_current_session()
	session_started.emit(session_id, session_start_time)

	var logger := GameManager.get_core_system("logger")
	if logger:
		logger.info(
			"[TestingTimeProfiler] Session started: %s (%s)" % [session_id, session_type], "Testing"
		)

	return session_id


## End the current testing session
func end_session() -> float:
	if not is_session_active:
		push_warning("[TestingTimeProfiler] No active session to end")
		return 0.0

	var end_time := Time.get_unix_time_from_system()
	var duration := end_time - session_start_time

	current_session["end_time"] = end_time
	current_session["end_datetime"] = Time.get_datetime_string_from_system()
	current_session["duration_seconds"] = duration
	current_session["duration_hours"] = duration / 3600.0

	# Update statistics
	total_testing_time += duration
	total_sessions += 1
	if duration > longest_session:
		longest_session = duration
	average_session = total_testing_time / total_sessions

	# Check for milestones
	_check_milestones()

	# Save to history
	_append_to_history(current_session)
	_delete_current_session()

	is_session_active = false
	session_ended.emit(current_session["id"], duration)

	var logger := GameManager.get_core_system("logger")
	if logger:
		logger.info(
			(
				"[TestingTimeProfiler] Session ended: %s (%.2f hours, Total: %.2f hours)"
				% [current_session["id"], duration / 3600.0, total_testing_time / 3600.0]
			),
			"Testing"
		)

	var session_duration := duration
	current_session = {}

	return session_duration


## Log a testing event (feature tested, bug found, etc.)
func log_event(event_type: String, description: String, metadata: Dictionary = {}) -> void:
	if not is_session_active:
		push_warning("[TestingTimeProfiler] Cannot log event: No active session")
		return

	var event := {
		"timestamp": Time.get_unix_time_from_system(),
		"datetime": Time.get_datetime_string_from_system(),
		"type": event_type,
		"description": description,
		"metadata": metadata
	}

	current_session["events"].append(event)
	_save_current_session()

	var logger := GameManager.get_core_system("logger")
	if logger:
		logger.info("[TestingTimeProfiler] Event: %s - %s" % [event_type, description], "Testing")


## Get current session duration
func get_current_session_duration() -> float:
	if not is_session_active:
		return 0.0
	return Time.get_unix_time_from_system() - session_start_time


## Get total testing time in hours
func get_total_hours() -> float:
	var current_duration := get_current_session_duration() if is_session_active else 0.0
	return (total_testing_time + current_duration) / 3600.0


## Get testing statistics
func get_statistics() -> Dictionary:
	return {
		"total_hours": get_total_hours(),
		"total_sessions": total_sessions + (1 if is_session_active else 0),
		"longest_session_hours": longest_session / 3600.0,
		"average_session_hours": average_session / 3600.0,
		"current_session_hours": get_current_session_duration() / 3600.0,
		"is_session_active": is_session_active,
		"milestones_reached": reached_milestones.size(),
		"next_milestone": _get_next_milestone()
	}


## Generate a summary report
func generate_report() -> String:
	var stats := get_statistics()
	var report := ""

	report += "=== TESTING TIME REPORT ===\n"
	report += "Generated: %s\n\n" % Time.get_datetime_string_from_system()

	report += "TOTAL TESTING TIME: %.2f hours\n" % stats["total_hours"]
	report += "Total Sessions: %d\n" % stats["total_sessions"]
	report += "Longest Session: %.2f hours\n" % stats["longest_session_hours"]
	report += "Average Session: %.2f hours\n" % stats["average_session_hours"]

	if stats["is_session_active"]:
		report += "\nCURRENT SESSION: %.2f hours (active)\n" % stats["current_session_hours"]

	report += "\nMILESTONES REACHED: %d\n" % stats["milestones_reached"]
	for milestone: float in reached_milestones:
		report += "  ✓ %.0f hours\n" % milestone

	var next_milestone: float = stats["next_milestone"]
	if next_milestone > 0:
		var hours_to_next: float = next_milestone - stats["total_hours"]
		report += (
			"\nNEXT MILESTONE: %.0f hours (%.2f hours remaining)\n"
			% [next_milestone, hours_to_next]
		)

	report += "\n=========================\n"

	return report


## Export detailed log to file
func export_detailed_log(filepath: String = "user://testing_time_detailed.txt") -> bool:
	var history := _load_history_data()
	if history.is_empty():
		push_error("[TestingTimeProfiler] No history to export")
		return false

	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if not file:
		push_error("[TestingTimeProfiler] Failed to open file for export: %s" % filepath)
		return false

	file.store_string("TESTING TIME DETAILED LOG\n")
	file.store_string("Generated: %s\n\n" % Time.get_datetime_string_from_system())
	file.store_string("=".repeat(80) + "\n\n")

	# Summary
	file.store_string(generate_report())
	file.store_string("\n" + "=".repeat(80) + "\n\n")

	# Detailed sessions
	file.store_string("DETAILED SESSION LOG\n\n")

	for session: Dictionary in history:
		file.store_string("Session: %s\n" % session.get("id", "unknown"))
		file.store_string("  Type: %s\n" % session.get("type", "unknown"))
		file.store_string("  Start: %s\n" % session.get("start_datetime", "unknown"))
		file.store_string("  End: %s\n" % session.get("end_datetime", "unknown"))
		file.store_string("  Duration: %.2f hours\n" % session.get("duration_hours", 0.0))
		file.store_string("  Platform: %s\n" % session.get("platform", "unknown"))

		var events: Array = session.get("events", [])
		if not events.is_empty():
			file.store_string("  Events: %d\n" % events.size())
			for event: Dictionary in events:
				file.store_string(
					(
						"    - [%s] %s: %s\n"
						% [
							event.get("datetime", ""),
							event.get("type", ""),
							event.get("description", "")
						]
					)
				)

		file.store_string("\n")

	file.close()

	var logger := GameManager.get_core_system("logger")
	if logger:
		logger.info("[TestingTimeProfiler] Detailed log exported to: %s" % filepath, "Testing")

	return true


## Private Methods


func _generate_session_id() -> String:
	var timestamp := Time.get_unix_time_from_system()
	return "test_session_%d" % int(timestamp)


func _save_current_session() -> void:
	var file := FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if not file:
		push_error("[TestingTimeProfiler] Failed to save current session")
		return

	file.store_string(JSONHelper.safe_stringify(current_session, "\t"))
	file.close()


func _delete_current_session() -> void:
	if FileAccess.file_exists(SESSION_FILE):
		DirAccess.remove_absolute(SESSION_FILE)


func _check_for_crashed_session() -> void:
	if not FileAccess.file_exists(SESSION_FILE):
		return

	var file := FileAccess.open(SESSION_FILE, FileAccess.READ)
	if not file:
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_warning("[TestingTimeProfiler] Corrupted session file, deleting")
		_delete_current_session()
		return

	var crashed_session: Dictionary = json.data

	# Calculate duration up to now (crashed session)
	var start_time: float = crashed_session.get("start_time", 0.0)
	var duration := Time.get_unix_time_from_system() - start_time

	# Only recover if session was less than 24 hours ago
	if duration < 86400:
		crashed_session["end_time"] = Time.get_unix_time_from_system()
		crashed_session["end_datetime"] = Time.get_datetime_string_from_system()
		crashed_session["duration_seconds"] = duration
		crashed_session["duration_hours"] = duration / 3600.0
		crashed_session["crashed"] = true

		_append_to_history(crashed_session)

		total_testing_time += duration
		total_sessions += 1

		var logger := GameManager.get_core_system("logger")
		if logger:
			logger.warning(
				"[TestingTimeProfiler] Recovered crashed session: %.2f hours" % (duration / 3600.0),
				"Testing"
			)

	_delete_current_session()


func _load_history() -> void:
	var history := _load_history_data()

	total_testing_time = 0.0
	total_sessions = history.size()
	longest_session = 0.0

	for session: Dictionary in history:
		var duration: float = session.get("duration_seconds", 0.0)
		total_testing_time += duration
		if duration > longest_session:
			longest_session = duration

	if total_sessions > 0:
		average_session = total_testing_time / total_sessions

	# Load reached milestones
	reached_milestones.clear()
	for milestone: float in MILESTONES:
		if get_total_hours() >= milestone:
			reached_milestones.append(milestone)


func _load_history_data() -> Array:
	if not FileAccess.file_exists(LOG_FILE):
		return []

	var file := FileAccess.open(LOG_FILE, FileAccess.READ)
	if not file:
		return []

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_error("[TestingTimeProfiler] Failed to parse history file")
		return []

	if json.data is Array:
		return json.data

	return []


func _append_to_history(session: Dictionary) -> void:
	var history := _load_history_data()
	history.append(session)

	var file := FileAccess.open(LOG_FILE, FileAccess.WRITE)
	if not file:
		push_error("[TestingTimeProfiler] Failed to save history")
		return

	file.store_string(JSONHelper.safe_stringify(history, "\t"))
	file.close()


func _check_milestones() -> void:
	var total_hours := get_total_hours()

	for milestone: float in MILESTONES:
		if total_hours >= milestone and not milestone in reached_milestones:
			reached_milestones.append(milestone)
			milestone_reached.emit(milestone)

			var logger := GameManager.get_core_system("logger")
			if logger:
				logger.info(
					"[TestingTimeProfiler] 🎉 MILESTONE REACHED: %.0f hours of testing!" % milestone,
					"Testing"
				)


func _get_next_milestone() -> float:
	var total_hours := get_total_hours()

	for milestone: float in MILESTONES:
		if total_hours < milestone:
			return milestone

	return 0.0  # All milestones reached
