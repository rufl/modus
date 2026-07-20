class_name IntermissionScreen
extends Control

signal harder_match_requested
signal replay_requested
signal main_menu_requested

const STAT_REVEAL_DELAY: float = 0.3
const COUNT_DURATION: float = 0.5

var _panel: PanelContainer
var _stats_container: VBoxContainer
var _buttons_container: HBoxContainer
var _stats: Dictionary = {}
var _stat_labels: Dictionary = {}
var _animating: bool = false
var _current_stat_index: int = 0
var _stat_keys: Array[String] = []


func _ready() -> void:
	name = "IntermissionScreen"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	# Don't hide by default if UIManager opens it, but good practice for manual instantiation
	hide()

	# Check if stats were provided before ready
	if not _stats.is_empty():
		show_intermission(_stats)


func _build_ui() -> void:
	# Full-screen semi-transparent background
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.0, 0.0, 0.0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# IMPROVED LAYOUT: Use CenterContainer for reliable centering
	var center_cont: CenterContainer = CenterContainer.new()
	center_cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass to panel/bg
	bg.add_child(center_cont)

	# Center panel
	_panel = PanelContainer.new()
	_panel.name = "StatsPanel"
	_panel.custom_minimum_size = Vector2(500, 400)
	# Anchors not needed when inside CenterContainer

	# Style the panel
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.6, 0.9, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", style)

	center_cont.add_child(_panel)

	# Main VBox
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	_panel.add_child(main_vbox)

	# Title
	var title: Label = Label.new()
	title.name = "Title"
	title.text = "MISSION COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	main_vbox.add_child(title)

	# Separator
	var sep1: HSeparator = HSeparator.new()
	main_vbox.add_child(sep1)

	# Stats container (will be populated dynamically)
	_stats_container = VBoxContainer.new()
	_stats_container.name = "StatsContainer"
	_stats_container.add_theme_constant_override("separation", 8)
	main_vbox.add_child(_stats_container)

	# Separator
	var sep2: HSeparator = HSeparator.new()
	main_vbox.add_child(sep2)

	# XP Summary line
	var xp_label: Label = Label.new()
	xp_label.name = "XPSummary"
	xp_label.text = "XP Earned: 0"
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.add_theme_font_size_override("font_size", 22)
	xp_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	main_vbox.add_child(xp_label)

	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer)

	# Buttons container
	_buttons_container = HBoxContainer.new()
	_buttons_container.name = "ButtonsContainer"
	_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons_container.add_theme_constant_override("separation", 20)
	main_vbox.add_child(_buttons_container)

	# Replay button
	var replay_btn: Button = Button.new()
	replay_btn.text = "Replay Match"
	replay_btn.custom_minimum_size = Vector2(140, 40)
	replay_btn.pressed.connect(_on_replay_pressed)
	_buttons_container.add_child(replay_btn)

	# Harder match button
	var harder_btn: Button = Button.new()
	harder_btn.text = "Harder Match"
	harder_btn.custom_minimum_size = Vector2(140, 40)
	harder_btn.pressed.connect(_on_harder_pressed)
	_buttons_container.add_child(harder_btn)

	# Main menu button
	var menu_btn: Button = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(140, 40)
	menu_btn.pressed.connect(_on_menu_pressed)
	_buttons_container.add_child(menu_btn)


## Setup method called by UIManager


func setup(params: Dictionary) -> void:
	if params.has("stats"):
		_stats = params.stats

		# If ready, show immediately. If not, _ready() will handle it.
		if is_node_ready():
			show_intermission(_stats)


## Show the intermission with stats


func show_intermission(stats: Dictionary) -> void:
	_stats = stats

	# Ensure UI is built
	if not _stats_container:
		if is_node_ready():
			_build_ui()
		else:
			# Should be handled by _ready -> show_intermission logic, but safeguard:
			return

	_populate_stats()
	visible = true  # Ensure visibility (UIManager doesn't force it)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_animate_stats()


func _populate_stats() -> void:
	# Clear existing
	for child in _stats_container.get_children():
		child.queue_free()
	_stat_labels.clear()

	# Define stats to show with display names
	var stat_display: Array = [
		["enemies_killed", "Enemies Killed"],
		["shots_fired", "Shots Fired"],
		["shots_hit", "Shots Hit"],
		["accuracy", "Accuracy"],
		["damage_dealt", "Damage Dealt"],
		["damage_taken", "Damage Taken"],
		["critical_hits", "Critical Hits"],
		["items_collected", "Items Collected"],
	]

	_stat_keys.clear()
	for entry: Array in stat_display:
		var key: String = entry[0]
		var label_text: String = entry[1]

		# Calculate accuracy if it's that key
		var value: Variant
		if key == "accuracy":
			var shots: int = _stats.get("shots_fired", 0)
			var hits: int = _stats.get("shots_hit", 0)
			if shots > 0:
				value = "%.1f%%" % ((float(hits) / float(shots)) * 100.0)
			else:
				value = "N/A"
		else:
			value = _stats.get(key, 0)

		# Create row
		var row: HBoxContainer = HBoxContainer.new()
		row.modulate.a = 0.0  # Start invisible for animation

		var name_label: Label = Label.new()
		name_label.text = label_text + ":"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		row.add_child(name_label)

		var value_label: Label = Label.new()
		value_label.text = "0" if value is int or value is float else str(value)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", 18)
		value_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		row.add_child(value_label)

		_stats_container.add_child(row)
		_stat_labels[key] = {"row": row, "value_label": value_label, "final_value": value}
		_stat_keys.append(key)


func _animate_stats() -> void:
	_animating = true
	_current_stat_index = 0
	_reveal_next_stat()


func _reveal_next_stat() -> void:
	if not is_inside_tree():
		_animating = false
		return

	if _current_stat_index >= _stat_keys.size():
		_animating = false
		return

	var key: String = _stat_keys[_current_stat_index]
	var data: Dictionary = _stat_labels[key]
	var row: HBoxContainer = data["row"]
	var value_label: Label = data["value_label"]
	var final_value: Variant = data["final_value"]

	# Fade in row
	var tween: Tween = create_tween()
	tween.tween_property(row, "modulate:a", 1.0, 0.15)

	# Animate counter if numeric
	if final_value is int or final_value is float:
		var target: float = float(final_value)
		var counter_tween: Tween = create_tween()
		counter_tween.tween_method(
			func(val: float) -> void:
				if final_value is int:
					value_label.text = str(int(val))
				else:
					value_label.text = "%.0f" % val,
			0.0,
			target,
			COUNT_DURATION
		)

	# Schedule next stat
	_current_stat_index += 1
	get_tree().create_timer(STAT_REVEAL_DELAY).timeout.connect(_reveal_next_stat)


func _on_replay_pressed() -> void:
	hide()
	replay_requested.emit()
	GameManager.emit_event("intermission_replay", {})


func _on_harder_pressed() -> void:
	hide()
	harder_match_requested.emit()
	GameManager.emit_event("intermission_harder", {})


func _on_menu_pressed() -> void:
	hide()
	main_menu_requested.emit()
	GameManager.emit_event("intermission_main_menu", {})
