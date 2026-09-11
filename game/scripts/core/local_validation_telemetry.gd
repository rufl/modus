extends Node

## Opt-in, local-only validation telemetry for testplay sessions.
## No network transport, analytics SDK, or automatic upload is used.

const DEFAULT_OUTPUT_DIRECTORY := "user://validation_telemetry"
const SAMPLE_INTERVAL_SECONDS := 5.0
const ALLOWED_INPUT_ACTIONS: Array[String] = [
	"up",
	"down",
	"left",
	"right",
	"jump",
	"pause",
	"shoot",
	"respawn",
	"capture",
	"look_up",
	"look_down",
	"look_left",
	"look_right",
	"chat_toggle",
	"inventory",
	"scoreboard",
	"crouch",
	"sprint",
	"aim",
	"reload",
	"interact",
	"quick_weapon_switch",
	"melee",
	"skill_tree",
]

var enabled: bool = false
var session_id: String = ""
var output_directory: String = ""
var log_file_path: String = ""
var _log_file: FileAccess = null
var _started_at: float = 0.0
var _last_sample_at: float = 0.0


func _ready() -> void:
	if _env_truthy("MODUS_LOCAL_TELEMETRY"):
		enabled = true
	if not enabled:
		return
	start_session()
	var logger := get_node_or_null("/root/GameManager")
	if logger and logger.has_method("get_core_system"):
		var log_service: Node = logger.get_core_system("logger")
		if log_service and log_service.has_signal("log_emitted"):
			log_service.log_emitted.connect(_on_log_emitted)


func _process(_delta: float) -> void:
	if not enabled or _log_file == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_sample_at < SAMPLE_INTERVAL_SECONDS:
		return
	_last_sample_at = now
	record_event(
		"runtime_sample",
		{
			"fps": Engine.get_frames_per_second(),
			"frame_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0,
			"scene": _current_scene_path(),
		}
	)


func _input(event: InputEvent) -> void:
	if not enabled or _log_file == null or not event.is_action_type():
		return
	if _is_detectable_text_entry(event):
		return
	for action_name: String in ALLOWED_INPUT_ACTIONS:
		var pressed := event.is_action_pressed(action_name)
		var released := event.is_action_released(action_name)
		if not pressed and not released:
			continue
		record_event(
			"input_action",
			{
				"action": action_name,
				"state": "pressed" if pressed else "released",
				"strength": event.get_action_strength(action_name),
			}
		)


func start_session(p_session_id: String = "") -> String:
	if not enabled:
		return ""
	if _log_file != null:
		return session_id
	if p_session_id.is_empty():
		var datetime: Dictionary = Time.get_datetime_dict_from_system()
		p_session_id = (
			"validation_%04d%02d%02d_%02d%02d%02d"
			% [
				datetime.year,
				datetime.month,
				datetime.day,
				datetime.hour,
				datetime.minute,
				datetime.second,
			]
		)
	session_id = _safe_name(p_session_id)
	var directory := _resolved_output_directory()
	if (
		DirAccess.make_dir_recursive_absolute(directory) != OK
		and not DirAccess.dir_exists_absolute(directory)
	):
		push_error("[LocalValidationTelemetry] Failed to create: %s" % directory)
		return ""
	var available_path := _next_available_log_path(directory, session_id)
	session_id = available_path.get_file().get_basename()
	log_file_path = available_path
	_log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if _log_file == null:
		push_error("[LocalValidationTelemetry] Failed to open: %s" % log_file_path)
		return ""
	_started_at = Time.get_ticks_msec() / 1000.0
	_last_sample_at = _started_at
	set_process(true)
	record_event(
		"session_started",
		{
			"application": ProjectSettings.get_setting("application/config/name", "MODUS"),
			"version": ProjectSettings.get_setting("application/config/version", "unknown"),
			"os": OS.get_name(),
			"renderer": RenderingServer.get_current_rendering_method(),
			"resolution":
			"%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
			"tester": OS.get_environment("MODUS_MANUAL_TESTER"),
			"input_devices": OS.get_environment("MODUS_MANUAL_INPUTS"),
		}
	)
	return log_file_path


func record_event(event_name: String, fields: Dictionary = {}) -> void:
	if not enabled or _log_file == null:
		return
	var event := {
		"timestamp": Time.get_datetime_string_from_system(),
		"elapsed_seconds": (Time.get_ticks_msec() / 1000.0) - _started_at,
		"session_id": session_id,
		"event": event_name.strip_edges(),
		"scene": _current_scene_path(),
		"fields": fields.duplicate(true),
	}
	_log_file.store_line(JSON.stringify(event))
	_log_file.flush()


func checkpoint(name: String, fields: Dictionary = {}) -> void:
	record_event("checkpoint", {"name": name, "data": fields})


func stop_session() -> void:
	if _log_file == null:
		return
	record_event(
		"session_stopped", {"duration_seconds": (Time.get_ticks_msec() / 1000.0) - _started_at}
	)
	_log_file.close()
	_log_file = null
	set_process(false)


func _on_log_emitted(entry: Dictionary) -> void:
	var level: String = str(entry.get("level", ""))
	if level in ["[WARNING]", "[ERROR]"]:
		record_event(
			"log_signal",
			{
				"level": level,
				"context": entry.get("context", ""),
				"message": entry.get("message", "")
			}
		)


func _current_scene_path() -> String:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return ""
	return tree.current_scene.scene_file_path


func _resolved_output_directory() -> String:
	var configured := output_directory.strip_edges()
	if configured.is_empty():
		configured = OS.get_environment("MODUS_LOCAL_TELEMETRY_DIR").strip_edges()
	if configured.is_empty():
		configured = DEFAULT_OUTPUT_DIRECTORY
	if configured.begins_with("res://") or configured.begins_with("user://"):
		return ProjectSettings.globalize_path(configured)
	if configured.is_absolute_path():
		return configured
	return ProjectSettings.globalize_path("res://" + configured.trim_prefix("./"))


func _safe_name(value: String) -> String:
	var cleaned := value.strip_edges().to_lower()
	cleaned = cleaned.replace(" ", "_").replace("/", "_").replace("\\", "_")
	return cleaned if not cleaned.is_empty() else "validation_session"


func _next_available_log_path(directory: String, base_name: String) -> String:
	var candidate := directory.path_join("%s.jsonl" % base_name)
	var suffix := 1
	while FileAccess.file_exists(candidate):
		candidate = directory.path_join("%s_%d.jsonl" % [base_name, suffix])
		suffix += 1
	return candidate


func _is_detectable_text_entry(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	# Text-entry events have Unicode data without a physical/key mapping. Never
	# record their text; mapped controls are represented by semantic action names.
	return (
		key_event.unicode > 0
		and key_event.keycode == 0
		and key_event.physical_keycode == 0
		and key_event.key_label == 0
	)


func _env_truthy(name: String) -> bool:
	return OS.get_environment(name).strip_edges().to_lower() in ["1", "true", "yes", "on"]


func _exit_tree() -> void:
	stop_session()
