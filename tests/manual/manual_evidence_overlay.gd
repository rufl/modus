class_name ManualEvidenceOverlay
extends CanvasLayer

## Test-only recorder overlay. F8 switches between gameplay and evidence review.

const CHECKLIST: Array[Dictionary] = [
	{"id": "main_menu_actions", "title": "Main menu opens and every visible primary action responds."},
	{"id": "showcase_route", "title": "Showcase loads through the intended main-menu route."},
	{"id": "player_spawn", "title": "The local player spawns safely without falling through geometry."},
	{"id": "pause_resume_exit", "title": "Pause, resume, and clean exit behavior work without trapping input."},
	{"id": "keyboard_mouse_movement", "title": "Keyboard and mouse movement, look, jump, sprint, crouch, and pause work."},
	{"id": "gamepad_control", "title": "A real gamepad navigates UI and controls the player without keyboard cross-talk."},
	{"id": "advanced_movement", "title": "Available slide, dash, dodge, wall-run, rope, rocket-jump, and fly paths recover cleanly."},
	{"id": "collision_recovery", "title": "Slopes, stairs, ceilings, ledges, collisions, and respawn do not trap the player."},
	{"id": "weapon_loop", "title": "A loaded weapon is visible and can fire, reload, and switch."},
	{"id": "ammo_hud", "title": "Ammo and weapon HUD state match every action performed."},
	{"id": "enemy_result", "title": "A valid enemy receives damage and reaches a bounded death state."},
	{"id": "combat_feedback", "title": "Muzzle, tracer, impact, blood, hit, audio, and directional feedback are readable."},
	{"id": "world_rendering", "title": "Collision, lighting, environment, and navigation-visible areas render as intended."},
	{"id": "interaction_hazard", "title": "At least one visible interactable or hazard responds, or its absence is recorded."},
	{"id": "pickup_inventory", "title": "A loot or inventory pickup is collected and used where available."},
	{"id": "save_load", "title": "Save, reload, and restored state are observed through the gameplay path."},
	{"id": "sample_mod", "title": "Bundled sample-mod behavior is observed separately from automated proof."},
	{"id": "hud_readability", "title": "Crosshair, health, ammo, prompts, and pause surfaces remain readable."},
	{"id": "focus_accessibility", "title": "Keyboard/gamepad focus, clipping, contrast, scaling, color, and motion comfort are reviewed."},
	{"id": "runtime_log_review", "title": "The runtime log and teardown are reviewed for errors, repeated exceptions, and severe warnings."},
]

@export var auto_start: bool = true

@onready var _root: Control = $Root
@onready var _compact_panel: PanelContainer = $Root/CompactMargins/CompactAlign/CompactPanel
@onready var _compact_status: Label = %CompactStatus
@onready var _review_shade: ColorRect = %ReviewShade
@onready var _safe_margins: MarginContainer = %SafeMargins
@onready var _review_panel: PanelContainer = %ReviewPanel
@onready var _panel_margins: MarginContainer = $Root/SafeMargins/ReviewAlign/ReviewPanel/PanelMargins
@onready var _content: VBoxContainer = $Root/SafeMargins/ReviewAlign/ReviewPanel/PanelMargins/Content
@onready var _title_label: Label = $Root/SafeMargins/ReviewAlign/ReviewPanel/PanelMargins/Content/TitleLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _current_test_label: Label = %CurrentTestLabel
@onready var _instruction_label: Label = $Root/SafeMargins/ReviewAlign/ReviewPanel/PanelMargins/Content/InstructionLabel
@onready var _notes_label: Label = $Root/SafeMargins/ReviewAlign/ReviewPanel/PanelMargins/Content/NotesLabel
@onready var _notes: TextEdit = %Notes
@onready var _result_status: Label = %ResultStatus
@onready var _result_buttons: BoxContainer = %ResultButtons
@onready var _skip_button: Button = %SkipButton
@onready var _fail_button: Button = %FailButton
@onready var _pass_button: Button = %PassButton
@onready var _end_button: Button = %EndButton

var _timer: ManualTestTimer
var _current_index: int = 0
var _review_mode: bool = false
var _finished: bool = false
var _setup_failed: bool = false
var _resume_paused: bool = false
var _resume_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timer = ManualTestTimer.new()
	_timer.name = "ManualTestTimer"
	add_child(_timer)

	_skip_button.pressed.connect(_record_result.bind("skip"))
	_fail_button.pressed.connect(_record_result.bind("fail"))
	_pass_button.pressed.connect(_record_result.bind("pass"))
	_end_button.pressed.connect(_on_end_pressed)
	_root.resized.connect(_update_responsive_layout)
	_wire_focus()
	_update_responsive_layout()

	if auto_start:
		_start_session()
	else:
		_set_result_controls_disabled(true)
		_review_shade.visible = true
		_safe_margins.visible = true
		_compact_panel.visible = false


func _exit_tree() -> void:
	if _timer and _timer.is_tracking:
		_timer.end_session()
	_restore_game_state()


func _input(event: InputEvent) -> void:
	var keyboard_toggle: bool = false
	var gamepad_toggle: bool = false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		keyboard_toggle = key_event.pressed and not key_event.echo and key_event.keycode == KEY_F8
	elif event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		gamepad_toggle = joy_event.pressed and joy_event.button_index == JOY_BUTTON_BACK
	if keyboard_toggle or gamepad_toggle:
		if not _setup_failed and not _finished:
			_set_review_mode(not _review_mode)
		get_viewport().set_input_as_handled()


func _start_session() -> void:
	var tester := OS.get_environment("MODUS_MANUAL_TESTER").strip_edges()
	var input_devices := OS.get_environment("MODUS_MANUAL_INPUTS").strip_edges()
	if tester.is_empty() or input_devices.is_empty():
		_show_setup_failure(
			"Tester and input-device metadata are required. Launch with "
			+ "tools/run_manual_showcase_session.sh --tester NAME --input DEVICES."
		)
		return

	_timer.output_directory = OS.get_environment("MODUS_MANUAL_EVIDENCE_DIR")
	var session := OS.get_environment("MODUS_MANUAL_SESSION").strip_edges()
	var metadata: Dictionary = {
		"tester": tester,
		"input_devices": input_devices,
		"scene": "main_menu_to_showcase",
		"build_identity": OS.get_environment("MODUS_MANUAL_BUILD"),
		"renderer": RenderingServer.get_current_rendering_method(),
		"resolution": "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
	}
	if _timer.start_session(session, metadata).is_empty():
		_show_setup_failure("The evidence CSV could not be created. Check the configured output directory.")
		return

	_current_index = 0
	_start_current_test()
	_set_review_mode(true)


func _start_current_test() -> void:
	var item: Dictionary = CHECKLIST[_current_index]
	_timer.start_test(item.id)
	_notes.clear()
	_result_status.text = "PASS may omit notes. FAIL and SKIP require a reason."
	_result_status.add_theme_color_override("font_color", Color(0.66, 0.76, 0.88))
	_refresh_progress()


func _record_result(result: String) -> void:
	if _setup_failed or _finished or not _timer.is_tracking:
		return
	var notes := _notes.text.strip_edges()
	if result != "pass" and notes.is_empty():
		_result_status.text = "%s needs a short reason before it can be recorded." % result.to_upper()
		_result_status.add_theme_color_override("font_color", Color(1.0, 0.58, 0.58))
		_notes.grab_focus()
		return

	_timer.complete_test(result, notes)
	_current_index += 1
	if _current_index >= CHECKLIST.size():
		_finish_session()
		return
	_start_current_test()
	_set_review_mode(false)


func _finish_session() -> void:
	if _finished:
		return
	_finished = true
	var stats := _timer.end_session()
	_set_result_controls_disabled(true)
	_notes.editable = false
	_progress_label.text = "%d / %d complete" % [CHECKLIST.size(), CHECKLIST.size()]
	_progress_bar.value = 100.0
	_current_test_label.text = "Session saved"
	_result_status.text = (
		"%d pass • %d fail • %d skip • %d incomplete\n%s"
		% [stats.passed, stats.failed, stats.skipped, stats.incomplete, stats.log_file_path]
	)
	_result_status.add_theme_color_override("font_color", Color(0.64, 0.9, 0.72))
	_end_button.text = "Close Recorder"
	_end_button.disabled = false
	_set_review_mode(true)
	_end_button.grab_focus()


func _on_end_pressed() -> void:
	if _finished or _setup_failed:
		_restore_game_state()
		queue_free()
		return
	_finish_session()


func _set_review_mode(enabled: bool) -> void:
	if enabled == _review_mode and not _finished:
		return
	if enabled and not _review_mode:
		_resume_paused = get_tree().paused
		_resume_mouse_mode = Input.mouse_mode
	_review_mode = enabled
	_review_shade.visible = enabled
	_safe_margins.visible = enabled
	_compact_panel.visible = not enabled

	if enabled:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_pass_button.call_deferred("grab_focus")
	else:
		_restore_game_state()
	_refresh_progress()


func _restore_game_state() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = _resume_paused
	Input.mouse_mode = _resume_mouse_mode


func _refresh_progress() -> void:
	if _current_index >= CHECKLIST.size():
		return
	var item: Dictionary = CHECKLIST[_current_index]
	var shown_index := _current_index + 1
	_progress_label.text = "%d / %d" % [shown_index, CHECKLIST.size()]
	_progress_bar.value = float(shown_index - 1) / float(CHECKLIST.size()) * 100.0
	_current_test_label.text = item.title
	_compact_status.text = "MANUAL SESSION • %d / %d" % [shown_index, CHECKLIST.size()]


func _show_setup_failure(message: String) -> void:
	_setup_failed = true
	_set_result_controls_disabled(true)
	_notes.editable = false
	_current_test_label.text = "Recorder setup is incomplete"
	_result_status.text = message
	_result_status.add_theme_color_override("font_color", Color(1.0, 0.58, 0.58))
	_end_button.text = "Close Recorder"
	_end_button.disabled = false
	_review_shade.visible = true
	_safe_margins.visible = true
	_compact_panel.visible = false
	_resume_paused = get_tree().paused
	_resume_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_end_button.grab_focus()


func _set_result_controls_disabled(disabled: bool) -> void:
	_skip_button.disabled = disabled
	_fail_button.disabled = disabled
	_pass_button.disabled = disabled


func _wire_focus() -> void:
	_skip_button.focus_neighbor_right = _fail_button.get_path()
	_fail_button.focus_neighbor_left = _skip_button.get_path()
	_fail_button.focus_neighbor_right = _pass_button.get_path()
	_pass_button.focus_neighbor_left = _fail_button.get_path()
	_pass_button.focus_neighbor_bottom = _end_button.get_path()
	_end_button.focus_neighbor_top = _pass_button.get_path()


func _update_responsive_layout() -> void:
	if not _root or not _review_panel:
		return
	var window_size := DisplayServer.window_get_size()
	var compact_window := window_size.x <= 900 or window_size.y <= 650
	var narrow := window_size.x < 520
	var short := window_size.y < 680
	var edge := 14 if narrow or short else 24
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_safe_margins.add_theme_constant_override(side, edge)
	_review_panel.custom_minimum_size.x = clampf(
		_root.size.x - edge * 2.0, 280.0, 560.0 if compact_window else 470.0
	)
	_result_buttons.vertical = narrow
	_panel_margins.add_theme_constant_override("margin_left", 18 if short else 26)
	_panel_margins.add_theme_constant_override("margin_right", 18 if short else 26)
	_panel_margins.add_theme_constant_override("margin_top", 14 if short else 24)
	_panel_margins.add_theme_constant_override("margin_bottom", 14 if short else 24)
	_content.add_theme_constant_override("separation", 10 if compact_window else 12)
	_title_label.add_theme_font_size_override("font_size", 32 if compact_window else 30)
	_progress_label.add_theme_font_size_override("font_size", 17 if compact_window else 14)
	_current_test_label.add_theme_font_size_override("font_size", 22 if compact_window else 20)
	_current_test_label.custom_minimum_size.y = 68.0 if compact_window else 72.0
	_instruction_label.add_theme_font_size_override("font_size", 16 if compact_window else 14)
	_notes_label.add_theme_font_size_override("font_size", 16 if compact_window else 14)
	_notes.add_theme_font_size_override("font_size", 18 if compact_window else 16)
	_notes.custom_minimum_size.y = 84.0 if compact_window else 100.0
	_result_status.add_theme_font_size_override("font_size", 16 if compact_window else 13)
	var action_height := 68.0 if compact_window else 48.0
	for button: Button in [_skip_button, _fail_button, _pass_button, _end_button]:
		button.custom_minimum_size.y = action_height
		button.add_theme_font_size_override("font_size", 20 if compact_window else 16)
