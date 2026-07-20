extends Control

var objective_label: Label

@onready var time_label: Label = $TimerLabel
@onready var state_label: Label = $StateLabel
@onready var background: ColorRect = $Background

var _last_killed_count: int = -1


func _ready() -> void:
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		gs.match_service.match_timer_updated.connect(_on_timer_updated)
		gs.match_service.match_state_changed.connect(_on_match_state_changed)

		# Initial state
		_on_match_state_changed(gs.match_service.current_match_state)
		_on_timer_updated(gs.match_service.time_left)

	# Fix layout (Collision with Compass)
	time_label.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE, 20
	)

	_setup_objective_label()

	if gs and gs.mission:
		gs.mission.mission_started.connect(_on_mission_started)
		gs.mission.objective_updated.connect(_on_objective_updated)


func _exit_tree() -> void:
	# === SIGNAL HYGIENE ===
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		if gs.match_service.match_timer_updated.is_connected(_on_timer_updated):
			gs.match_service.match_timer_updated.disconnect(_on_timer_updated)
		if gs.match_service.match_state_changed.is_connected(_on_match_state_changed):
			gs.match_service.match_state_changed.disconnect(_on_match_state_changed)

	if gs and gs.mission:
		if gs.mission.mission_started.is_connected(_on_mission_started):
			gs.mission.mission_started.disconnect(_on_mission_started)
		if gs.mission.objective_updated.is_connected(_on_objective_updated):
			gs.mission.objective_updated.disconnect(_on_objective_updated)


func _on_timer_updated(time_left: float) -> void:
	@warning_ignore("integer_division")
	var minutes: int = int(time_left) / 60
	var seconds: int = int(time_left) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]

	# Urgent color when low time
	if time_left < 30.0:
		time_label.modulate = Color.RED
	else:
		time_label.modulate = Color.WHITE


func _on_match_state_changed(state: int) -> void:
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if not gs or not gs.match_service:
		return

	match state:
		gs.match_service.MatchState.WAITING:
			state_label.text = "WAITING FOR PLAYERS"
			state_label.show()
			background.hide()
		gs.match_service.MatchState.PLAYING:
			state_label.hide()
			background.hide()
		gs.match_service.MatchState.ENDED:
			state_label.hide()
			background.hide()


func _setup_objective_label() -> void:
	objective_label = Label.new()
	objective_label.name = "ObjectiveLabel"
	objective_label.add_theme_font_size_override("font_size", 24)
	objective_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))  # Quake Gold
	objective_label.add_theme_constant_override("outline_size", 6)
	objective_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))

	add_child(objective_label)

	# Initial positioning (will be overridden by config if present)
	objective_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	objective_label.position = Vector2(20, 60)

	# CRITICAL: Make sure it's visible by default
	objective_label.visible = true
	objective_label.text = "Waiting for mission..."

	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(
			"[MatchHUD] Objective label created and visible: " + " " + str(objective_label.visible),
			"UI"
		)

	_apply_layout_config()


func _apply_layout_config() -> void:
	var config: Node = GameManager.get_core_system("config")
	if not config or not config.has_method("get_value"):
		return

	var layout: Variant = config.get_value("visuals.hud.layout.objective_tracker")
	if not layout is Dictionary:
		return

	if layout.has("anchor_preset"):
		objective_label.set_anchors_preset(_get_preset_enum(layout.anchor_preset))

	if layout.has("position"):
		var pos: Dictionary = layout.position
		if pos.has("offset_x"):
			objective_label.position.x = pos.offset_x
		if pos.has("offset_y"):
			objective_label.position.y = pos.offset_y

	if layout.has("z_index"):
		objective_label.z_index = layout.z_index


func _get_preset_enum(preset_name: String) -> Control.LayoutPreset:
	match preset_name:
		"TOP_LEFT":
			return Control.PRESET_TOP_LEFT
		"TOP_CENTER":
			return Control.PRESET_TOP_WIDE
		"TOP_RIGHT":
			return Control.PRESET_TOP_RIGHT
		"CENTER_LEFT":
			return Control.PRESET_CENTER_LEFT
		"CENTER":
			return Control.PRESET_CENTER
		"CENTER_RIGHT":
			return Control.PRESET_CENTER_RIGHT
		"BOTTOM_LEFT":
			return Control.PRESET_BOTTOM_LEFT
		"BOTTOM_CENTER":
			return Control.PRESET_BOTTOM_WIDE
		"BOTTOM_RIGHT":
			return Control.PRESET_BOTTOM_RIGHT
		"FULL_RECT":
			return Control.PRESET_FULL_RECT
		_:
			return Control.PRESET_TOP_LEFT


func _on_mission_started(_mission_id: String) -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info("[MatchHUD] Mission started: " + " " + str(_mission_id), "UI")
	objective_label.show()
	objective_label.text = "Mission Started"
	print(
		"[MatchHUD] Objective label visible: ",
		objective_label.visible,
		" text: ",
		objective_label.text
	)


func _on_objective_updated(_mission_id: String, _obj_id: String, current: int, total: int) -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(
			"[MatchHUD] Objective updated: " + " " + str(current) + " " + "/" + " " + str(total),
			"UI"
		)

	if current == _last_killed_count:
		return

	_last_killed_count = current

	# Quake-style formatting
	objective_label.text = "Enemies Killed - %d/%d" % [current, total]
	objective_label.visible = true

	if logger and logger.has_method("info"):
		logger.info("[MatchHUD] Updated objective label: " + " " + str(objective_label.text), "UI")

	# Flash effect on update
	var tween: Tween = create_tween()
	tween.tween_property(objective_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(objective_label, "scale", Vector2(1.0, 1.0), 0.2)


func _on_pause_pressed() -> void:
	var us := UISystem.get_service()
	if us and us.ui_manager:
		us.ui_manager.open_screen("PauseScreen")
