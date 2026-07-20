class_name WelcomeScreen
extends Control

## Welcome overlay shown when entering the showcase map.
## Dismisses on E key press and starts a free-roam match.


func _ready() -> void:
	set_process_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Pause gameplay while welcome is shown
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_dismiss()
			get_viewport().set_input_as_handled()


func _dismiss() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false

	# Recapture mouse for FPS gameplay
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Debug: Verify mouse mode was set
	print("[WelcomeScreen] Dismissed - Mouse mode: ", Input.mouse_mode, " (CAPTURED=2)")
	print("[WelcomeScreen] Game paused: ", get_tree().paused)

	# Start a free-roam match (no time limit, no frag limit)
	var match_svc: MatchSvc = MatchSvc.get_instance()
	if match_svc:
		match_svc.start_match({"time_limit": 0, "frag_limit": 0})
		print("[WelcomeScreen] Match started")
	else:
		push_warning("[WelcomeScreen] MatchSvc not found - match not started")

	# Clean up the welcome layer entirely
	var parent_layer: Node = get_parent()
	if parent_layer:
		parent_layer.queue_free()
