extends Node

signal log_emitted(entry: Dictionary)

enum LogLevel { TRACE, DEBUG, INFO, WARNING, ERROR, NONE }

var current_level: LogLevel = LogLevel.INFO
var log_to_file: bool = false
var log_file_path: String = "user://game.log"
var log_buffer: Array[Dictionary] = []
var max_buffer_size: int = 1000

var _log_file: FileAccess = null


func initialize() -> void:
	# Create logs directory in project folder for easy access
	var base_path: String = "res://" if OS.has_feature("editor") else "user://"
	var logs_dir: String = base_path + "logs"

	var dir: DirAccess = DirAccess.open(base_path)
	if dir and not dir.dir_exists("logs"):
		dir.make_dir_recursive("logs")

	# Generate timestamped filename
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	log_file_path = logs_dir + "/session_%s.log" % timestamp

	# Enable file logging by default
	log_to_file = true

	if log_to_file:
		_open_log_file()


func trace(message: String, context: String = "") -> void:
	if current_level <= LogLevel.TRACE:
		_log("[TRACE]", context, message)


func debug(message: String, context: String = "") -> void:
	if current_level <= LogLevel.DEBUG:
		_log("[DEBUG]", context, message)


func info(message: String, context: String = "") -> void:
	if current_level <= LogLevel.INFO:
		_log("[INFO]", context, message)


func warning(message: String, context: String = "") -> void:
	if current_level <= LogLevel.WARNING:
		_log("[WARNING]", context, message)


func error(message: String, context: String = "") -> void:
	if current_level <= LogLevel.ERROR:
		_log("[ERROR]", context, message)


func set_log_level(level: LogLevel) -> void:
	current_level = level
	info("Log level changed to: %s" % LogLevel.keys()[level], "Logger")


func set_file_logging(enabled: bool) -> void:
	if enabled and not log_to_file:
		log_to_file = true
		_open_log_file()
		info("File logging enabled", "Logger")
	elif not enabled and log_to_file:
		log_to_file = false
		if _log_file:
			_log_file.close()
			_log_file = null
		info("File logging disabled", "Logger")


func _log(level: String, context: String, message: String) -> void:
	var timestamp: String = Time.get_datetime_string_from_system()
	var ctx: String = "[%s]" % context if context else ""

	# Avoid double tagging if message already starts with the context tag
	var clean_message: String = message
	if not context.is_empty() and message.begins_with(ctx):
		clean_message = message.trim_prefix(ctx).strip_edges()

	var full_message: String = "%s %s %s %s" % [timestamp, level, ctx, clean_message]

	print(full_message)

	# Buffer for console
	var entry: Dictionary = {
		"timestamp": timestamp, "level": level, "context": context, "message": message
	}
	log_buffer.append(entry)
	if log_buffer.size() > max_buffer_size:
		log_buffer.pop_front()
	log_emitted.emit(entry)

	if log_to_file and _log_file and _log_file.is_open():
		_log_file.store_line(full_message)
		_log_file.flush()


func _open_log_file() -> void:
	_log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if not _log_file:
		push_error("Failed to open log file: %s" % log_file_path)
	else:
		_log_file.store_line(
			"=== Game Log Started: %s ===" % Time.get_datetime_string_from_system()
		)
		_log_file.flush()


func _exit_tree() -> void:
	if _log_file:
		if _log_file.is_open():
			_log_file.store_line("=== Game Log Ended: %s ===" % Time.get_datetime_string_from_system())
			_log_file.close()
		_log_file = null


func export_log(filepath: String = "") -> String:
	var timestamp_str: String = str(Time.get_unix_time_from_system()).replace(".", "_")
	var path: String = filepath if filepath else "user://session_log_%s.txt" % timestamp_str
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return "Failed to open: %s" % path

	file.store_line("=== Session Log Export ===")
	file.store_line("Exported: %s" % Time.get_datetime_string_from_system())
	file.store_line("Total entries: %d" % log_buffer.size())
	file.store_line("")

	for entry in log_buffer:
		var ctx: String = "[%s]" % entry.context if entry.context else ""
		file.store_line("%s %s %s %s" % [entry.timestamp, entry.level, ctx, entry.message])

	file.close()
	info("Log exported: %s (%d entries)" % [path, log_buffer.size()], "Logger")
	return "Exported %d lines to: %s" % [log_buffer.size(), path]
