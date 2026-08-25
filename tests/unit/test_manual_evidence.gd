extends ModusGutTestBase

const TEST_OUTPUT := "user://manual_evidence_unit"


func before_each() -> void:
	await modus_setup()
	_remove_test_output()


func after_each() -> void:
	_remove_test_output()
	modus_teardown()


func test_manual_timer_writes_reviewable_metadata_and_skip_result() -> void:
	var timer := ManualTestTimer.new()
	timer.output_directory = TEST_OUTPUT
	add_child_autofree(timer)

	var session := timer.start_session(
		"showcase reviewer / unsafe name",
		{
			"tester": "QA One",
			"os": "Linux",
			"renderer": "gl_compatibility",
			"resolution": "1280x720",
			"input_devices": "keyboard_mouse",
			"scene": "main_menu_to_showcase",
			"build_identity": "0.9.5-beta+test",
		}
	)
	assert_eq(session, "showcase_reviewer_unsafe_name", "Session names should be filesystem-safe")
	assert_true(timer.is_tracking, "Timer should track only after its CSV opens")

	timer.start_test("gamepad_control")
	await get_tree().process_frame
	timer.complete_test("skip", "No physical gamepad connected")
	var stats := timer.end_session()

	assert_eq(stats.skipped, 1, "Skipped observations should remain distinct")
	assert_eq(stats.incomplete, 0, "A reviewed skip should not become incomplete")
	assert_true(FileAccess.file_exists(stats.log_file_path), "Timer should expose its evidence path")
	var csv := FileAccess.get_file_as_string(stats.log_file_path)
	assert_true(csv.contains("gamepad_control"), "CSV should retain the stable checklist ID")
	assert_true(csv.contains("metadata_tester,QA One"), "CSV should retain reviewer identity")
	assert_true(csv.contains("metadata_build_identity,0.9.5-beta+test"), "CSV should retain build identity")


func test_manual_overlay_is_responsive_and_keyboard_ready() -> void:
	var scene := load("res://tests/manual/manual_evidence_overlay.tscn") as PackedScene
	assert_not_null(scene, "Manual evidence overlay should load")
	if not scene:
		return

	var overlay := scene.instantiate() as ManualEvidenceOverlay
	overlay.auto_start = false
	add_child_autofree(overlay)
	await get_tree().process_frame

	var root := overlay.get_node("Root") as Control
	root.size = Vector2(640, 480)
	overlay.call("_update_responsive_layout")
	await get_tree().process_frame

	var panel := overlay.find_child("ReviewPanel", true, false) as PanelContainer
	var notes := overlay.find_child("Notes", true, false) as TextEdit
	var buttons := overlay.find_child("ResultButtons", true, false) as BoxContainer
	var skip_button := overlay.find_child("SkipButton", true, false) as Button
	var fail_button := overlay.find_child("FailButton", true, false) as Button
	var pass_button := overlay.find_child("PassButton", true, false) as Button

	assert_not_null(panel, "Recorder should use a bounded review panel")
	assert_not_null(notes, "Recorder should preserve observation notes")
	assert_not_null(buttons, "Recorder should group all result actions responsively")
	assert_lte(panel.custom_minimum_size.x, 640.0, "Recorder should fit the target viewport")
	assert_gte(skip_button.custom_minimum_size.y, 48.0, "Skip should meet the logical target floor")
	assert_gte(fail_button.custom_minimum_size.y, 48.0, "Fail should meet the logical target floor")
	assert_gte(pass_button.custom_minimum_size.y, 48.0, "Pass should meet the logical target floor")
	assert_eq(pass_button.focus_mode, Control.FOCUS_ALL, "Primary result action should accept focus")
	assert_ne(pass_button.focus_neighbor_left, NodePath(), "Result focus order should be explicit")
	assert_eq(overlay.CHECKLIST.size(), 20, "Showcase recorder should expose the bounded route")


func _remove_test_output() -> void:
	var path := ProjectSettings.globalize_path(TEST_OUTPUT)
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
