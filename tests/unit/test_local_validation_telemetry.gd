extends ModusGutTestBase

const TEST_OUTPUT := "user://local_validation_telemetry_unit"
const TelemetryScript = preload("res://game/scripts/core/local_validation_telemetry.gd")
const ManualTimerScript = preload("res://tests/manual/manual_test_timer.gd")


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
func test_session_does_not_overwrite_existing_file() -> void:
	var directory := ProjectSettings.globalize_path(TEST_OUTPUT)
	DirAccess.make_dir_recursive_absolute(directory)
	var existing_path := directory.path_join("collision.jsonl")
	var existing := FileAccess.open(existing_path, FileAccess.WRITE)
	existing.store_line("keep this evidence")
	existing.close()

	var telemetry := TelemetryScript.new()
	telemetry.enabled = true
	telemetry.output_directory = TEST_OUTPUT
	add_child_autofree(telemetry)
	telemetry.stop_session()

	var path := telemetry.start_session("collision")
	assert_true(path.ends_with("collision_1.jsonl"))
	telemetry.stop_session()
	assert_eq(FileAccess.get_file_as_string(existing_path).strip_edges(), "keep this evidence")


func test_disabled_explicit_start_is_a_no_op() -> void:
	var telemetry := TelemetryScript.new()
	telemetry.output_directory = TEST_OUTPUT
	add_child_autofree(telemetry)
	var path := telemetry.start_session("disabled")
	assert_eq(path, "")
	assert_eq(telemetry.log_file_path, "")
	assert_false(
		FileAccess.file_exists(ProjectSettings.globalize_path(TEST_OUTPUT).path_join("disabled.jsonl"))
	)


func test_input_telemetry_records_allowlisted_semantics_not_text() -> void:
	var telemetry := TelemetryScript.new()
	telemetry.enabled = true
	telemetry.output_directory = TEST_OUTPUT
	add_child_autofree(telemetry)
	telemetry.stop_session()
	var path := telemetry.start_session("input privacy")

	var text_event := InputEventKey.new()
	text_event.pressed = true
	text_event.unicode = ord("S")
	telemetry._input(text_event)

	var jump_event := InputEventKey.new()
	jump_event.pressed = true
	jump_event.physical_keycode = KEY_SPACE
	jump_event.unicode = 32
	telemetry._input(jump_event)
	telemetry.stop_session()

	var content := FileAccess.get_file_as_string(path)
	assert_false(content.contains("\"input\""))
	assert_false(content.contains("\"S\""))
	assert_true(content.contains("\"event\":\"input_action\""))
	assert_true(content.contains("\"action\":\"jump\""))

func test_manual_timer_checkpoints_are_captured() -> void:
	var telemetry := get_node("/root/LocalValidationTelemetry")
	telemetry.enabled = true
	telemetry.output_directory = TEST_OUTPUT
	telemetry.start_session("manual timer integration")

	var timer := ManualTimerScript.new()
	timer.output_directory = TEST_OUTPUT
	add_child_autofree(timer)
	timer.start_session("review")
	timer.start_test("gamepad_control")
	await get_tree().process_frame
	timer.complete_test("pass", "Observed")
	timer.end_session()
	telemetry.stop_session()

	var telemetry_path := ProjectSettings.globalize_path(TEST_OUTPUT).path_join(
		"manual_timer_integration.jsonl"
	)
	var content := FileAccess.get_file_as_string(telemetry_path)
	assert_true(content.contains("\"event\":\"checkpoint\""))
	assert_true(content.contains("\"name\":\"manual_test_started\""))
	assert_true(content.contains("\"name\":\"manual_test_completed\""))
	assert_true(content.contains("\"result\":\"pass\""))


func _remove_test_output() -> void:
	var path := ProjectSettings.globalize_path(TEST_OUTPUT)
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
