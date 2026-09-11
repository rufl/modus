extends ModusGutTestBase

const TEST_OUTPUT := "user://local_validation_telemetry_unit"
const TelemetryScript = preload("res://game/scripts/core/local_validation_telemetry.gd")


func before_each() -> void:
	await modus_setup()
	_remove_test_output()


func after_each() -> void:
	_remove_test_output()
	modus_teardown()


func test_local_telemetry_writes_jsonl_events_and_checkpoints() -> void:
	var telemetry := TelemetryScript.new()
	telemetry.enabled = true
	telemetry.output_directory = TEST_OUTPUT
	add_child_autofree(telemetry)
	telemetry.stop_session()

	var path := telemetry.start_session("privacy smoke / unsafe name")
	assert_true(path.ends_with("privacy_smoke___unsafe_name.jsonl"))
	telemetry.record_event("scene_loaded", {"scene": "showcase"})
	telemetry.checkpoint("pickup_collected", {"item_id": "ammo_shells"})
	telemetry.stop_session()

	assert_true(FileAccess.file_exists(path), "Telemetry should write a local JSONL file")
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n", false)
	assert_eq(lines.size(), 4, "Session start, event, checkpoint, and stop should be recorded")
	assert_true(lines[1].contains('"event":"scene_loaded"'))
	assert_true(lines[2].contains('"name":"pickup_collected"'))
	assert_false(lines[1].contains("http://"), "Telemetry must not contain upload endpoints")


func _remove_test_output() -> void:
	var path := ProjectSettings.globalize_path(TEST_OUTPUT)
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
