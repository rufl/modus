class_name WelcomeScreen
extends Control

## Player-visible entry overlay for the maintained showcase route.

@onready var _safe_margins: MarginContainer = $SafeMargins
@onready var _panel: PanelContainer = $SafeMargins/CenterContainer/WelcomePanel
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _body: Label = %BodyLabel
@onready var _route: Label = %RouteLabel
@onready var _evidence: Label = %EvidenceLabel
@onready var _begin_button: Button = %BeginButton
@onready var _input_hint: Label = %InputHint

var _dismissed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_apply_theme()
	_refresh_copy()
	_begin_button.pressed.connect(_dismiss)
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()
	_begin_button.call_deferred("grab_focus")

	var localization: Node = GameManager.get_core_system("localization")
	if localization and localization.has_signal("language_changed"):
		localization.language_changed.connect(_on_language_changed)


func _exit_tree() -> void:
	var ui_service := UISystem.get_service()
	if ui_service and ui_service.theme_manager:
		ui_service.theme_manager.unregister_themeable(self)


func _input(event: InputEvent) -> void:
	if _dismissed or not visible:
		return
	if event.is_action_pressed("ui_accept"):
		_dismiss()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_dismiss()
		get_viewport().set_input_as_handled()


func _dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var match_service: MatchSvc = MatchSvc.get_instance()
	if match_service:
		match_service.start_match({"time_limit": 0, "frag_limit": 0})
	else:
		push_warning("[WelcomeScreen] MatchSvc not found - match not started")

	var parent_layer: Node = get_parent()
	if parent_layer:
		parent_layer.queue_free()


func _apply_theme() -> void:
	var ui_service := UISystem.get_service()
	if ui_service and ui_service.theme_manager:
		ui_service.theme_manager.register_themeable(self)


func _refresh_copy() -> void:
	_title.text = _tr("showcase_welcome_title", "MODUS SHOWCASE")
	_subtitle.text = _tr(
		"showcase_welcome_subtitle", "A guided route through the framework"
	)
	_body.text = _tr(
		"showcase_welcome_body",
		"Explore the maintained map and exercise movement, combat, loot, saving, and mods."
	)
	var route_fallback := (
		"MOVE through the hub\n"
		+ "FIGHT in the projectile range\n"
		+ "COLLECT a pickup\n"
		+ "SAVE and reload before exit"
	)
	_route.text = _tr("showcase_welcome_route", route_fallback)
	_evidence.text = _tr(
		"showcase_welcome_evidence",
		"A run becomes evidence only after its timer CSV, notes, and captures are retained."
	)
	_begin_button.text = _tr("showcase_welcome_begin", "Begin Showcase")
	_input_hint.text = _tr("showcase_welcome_hint", "Enter / Space / Gamepad A")


func _update_responsive_layout() -> void:
	if not _panel or not _title:
		return
	var narrow := size.x < 700.0 or size.y < 650.0
	var edge := 16 if narrow else 24
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_safe_margins.add_theme_constant_override(side, edge)
	_panel.custom_minimum_size.x = clampf(size.x - edge * 2.0, 280.0, 560.0)
	_title.add_theme_font_size_override("font_size", 38 if narrow else 54)


func _on_language_changed(_language: String) -> void:
	_refresh_copy()


func _tr(key: String, fallback: String) -> String:
	var localization: Node = GameManager.get_core_system("localization")
	if not localization or not localization.has_method("translate"):
		return fallback
	var translated: String = localization.translate(key)
	return translated if translated != key else fallback
