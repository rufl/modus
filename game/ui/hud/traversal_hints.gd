extends Control
class_name TraversalHints

signal hint_shown(hint_id: String)
signal hint_hidden(hint_id: String)

@export_group("Display Settings")
@export var fade_in_duration: float = 0.3
@export var display_duration: float = 5.0
@export var fade_out_duration: float = 0.5
@export var hint_color: Color = Color(1.0, 1.0, 0.8, 1.0)
@export_group("Position")
@export var display_position: Vector2 = Vector2(0.5, 0.8)  # Normalized screen pos
@export var display_offset: Vector2 = Vector2.ZERO

var current_hint_id: String = ""
var display_timer: float = 0.0
var is_displaying: bool = false
var shown_hints: Dictionary = {}  # Track shown hints to avoid spam

var _panel: PanelContainer = null
var _vbox: VBoxContainer = null
var _title_label: Label = null
var _hint_label: Label = null
var _controls_label: Label = null
var _fade_tween: Tween = null


func _ready() -> void:
	modulate.a = 0.0
	_setup_ui()
	add_to_group("traversal_hint_display")


func _process(delta: float) -> void:
	if is_displaying:
		display_timer -= delta

		if display_timer <= 0.0:
			hide_hint()


func _setup_ui() -> void:
	## Create the hint display UI
	_panel = PanelContainer.new()
	_panel.name = "HintPanel"
	add_child(_panel)

	# Apply dark semi-transparent style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	_panel.add_theme_stylebox_override("panel", style)

	_vbox = VBoxContainer.new()
	_vbox.name = "Content"
	_panel.add_child(_vbox)

	# Title label
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color.GOLD)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_title_label)

	# Separator
	var separator: HSeparator = HSeparator.new()
	_vbox.add_child(separator)

	# Hint label
	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", hint_color)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size.x = 300
	_vbox.add_child(_hint_label)

	# Controls label
	_controls_label = Label.new()
	_controls_label.name = "ControlsLabel"
	_controls_label.add_theme_font_size_override("font_size", 12)
	_controls_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_controls_label)

	# Position the panel
	_update_position()


func _update_position() -> void:
	## Update panel position based on display_position
	if not _panel:
		return

	await get_tree().process_frame  # Wait for size calculation

	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = _panel.size

	var pos: Vector2 = Vector2(
		viewport_size.x * display_position.x - panel_size.x / 2.0,
		viewport_size.y * display_position.y - panel_size.y / 2.0
	)
	pos += display_offset

	_panel.position = pos


func show_hint(
	hint_id: String, title: String, hint: String, controls: String = "", force: bool = false
) -> void:
	## Display a traversal hint
	## Args:
	##   hint_id: Unique identifier for this hint (to avoid showing same hint repeatedly)
	##   title: Title of the hint (e.g., "Rope Swinging")
	##   hint: Main hint text
	##   controls: Control instructions (e.g., "Hold SPACE to swing")
	##   force: If true, show even if already shown before

	# Check if already shown (unless forced)
	if not force and shown_hints.has(hint_id):
		return

	# Mark as shown
	shown_hints[hint_id] = true

	current_hint_id = hint_id

	if _title_label:
		_title_label.text = title

	if _hint_label:
		_hint_label.text = hint

	if _controls_label:
		_controls_label.text = controls
		_controls_label.visible = not controls.is_empty()

	is_displaying = true
	display_timer = display_duration

	visible = true
	_update_position()

	# Cancel existing tween
	if _fade_tween:
		_fade_tween.kill()

	# Fade in animation
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, fade_in_duration)

	hint_shown.emit(hint_id)


func hide_hint() -> void:
	## Hide the current hint with fade out
	if not is_displaying:
		return

	is_displaying = false

	# Cancel existing tween
	if _fade_tween:
		_fade_tween.kill()

	# Fade out animation
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, fade_out_duration)
	_fade_tween.tween_callback(func() -> void: visible = false)

	hint_hidden.emit(current_hint_id)
	current_hint_id = ""


func hide_immediate() -> void:
	## Immediately hide the hint without animation
	is_displaying = false
	modulate.a = 0.0
	visible = false
	current_hint_id = ""


func extend_display_time(additional_time: float) -> void:
	## Extend the display time of current hint
	if is_displaying:
		display_timer += additional_time


func is_showing_hint() -> bool:
	## Check if currently showing a hint
	return is_displaying


func reset_shown_hints() -> void:
	## Reset the shown hints dictionary (allows hints to show again)
	shown_hints.clear()


func mark_hint_shown(hint_id: String) -> void:
	## Manually mark a hint as shown
	shown_hints[hint_id] = true


func was_hint_shown(hint_id: String) -> bool:
	## Check if a specific hint was already shown
	return shown_hints.has(hint_id)


# =============================================================================
# PRESET HINTS
# =============================================================================


func show_rope_hint() -> void:
	## Show hint for rope swinging
	show_hint(
		"rope_swing",
		"Rope Swinging",
		"Grab the rope to swing across gaps. Build momentum by timing your movements!",
		"Press E to grab • WASD to swing • SPACE to release"
	)


func show_ladder_hint() -> void:
	## Show hint for ladder climbing
	show_hint(
		"ladder_climb",
		"Ladder Climbing",
		"Climb up or down ladders to reach new areas.",
		"W/S to climb • SPACE to jump off"
	)


func show_horizontal_ladder_hint() -> void:
	## Show hint for horizontal ladder/monkey bars
	show_hint(
		"horizontal_ladder",
		"Monkey Bars",
		"Hang and traverse along horizontal bars to cross gaps.",
		"Press E to grab • A/D to traverse • SPACE to drop"
	)


func show_wall_run_hint() -> void:
	## Show hint for wall running
	show_hint(
		"wall_run",
		"Wall Running",
		"Sprint toward walls to run along them momentarily.",
		"Sprint + approach wall • SPACE to jump off"
	)


func show_slide_hint() -> void:
	## Show hint for sliding
	show_hint("slide", "Slide", "Slide under obstacles while sprinting.", "CTRL while sprinting")
