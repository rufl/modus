class_name LevelUpNotification
extends Control

signal notification_finished

@export var xp_gain_duration: float = 2.0
@export var level_up_duration: float = 4.0
@export var slide_distance: float = 50.0

var _queue: Array[Dictionary] = []
var _is_showing: bool = false
var _container: PanelContainer = null
var _title_label: Label = null
var _details_label: Label = null
var _xp_bar: ProgressBar = null


func _ready() -> void:
	_create_ui()
	hide()

	# Connect to PlayerProgression if available
	call_deferred("_connect_to_progression")


func _create_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Center top positioning
	anchor_left = 0.3
	anchor_right = 0.7
	anchor_top = 0.15
	anchor_bottom = 0.3

	# Main container
	_container = PanelContainer.new()
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Style the panel
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.8, 0.7, 0.2)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.shadow_color = Color(0.8, 0.7, 0.2, 0.3)
	panel_style.shadow_size = 8
	_container.add_theme_stylebox_override("panel", panel_style)

	# Content VBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "LEVEL UP!"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vbox.add_child(_title_label)

	# Details
	_details_label = Label.new()
	_details_label.text = "Level 2 reached!"
	_details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details_label.add_theme_font_size_override("font_size", 18)
	_details_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(_details_label)

	# XP Bar (for XP gain notifications)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(0, 12)
	_xp_bar.max_value = 100
	_xp_bar.value = 50
	_xp_bar.show_percentage = false
	vbox.add_child(_xp_bar)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.8, 1.0)
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	_xp_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.25)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	_xp_bar.add_theme_stylebox_override("background", bg_style)


func _connect_to_progression() -> void:
	# Retry multiple times in case player isn't spawned yet
	for attempt in range(10):
		for node: Node in get_tree().get_nodes_in_group("player"):
			if not node.is_multiplayer_authority():
				continue

			var progression: Node = node.get_node_or_null("PlayerProgression")
			if progression:
				if progression.has_signal("leveled_up"):
					progression.leveled_up.connect(_on_level_up)
				if progression.has_signal("xp_gained"):
					progression.xp_gained.connect(_on_xp_gained_internal)
				return

		await get_tree().create_timer(0.5).timeout


func show_level_up(new_level: int, skill_points: int = 1) -> void:
	_queue.append({"type": "level_up", "level": new_level, "skill_points": skill_points})
	_process_queue()


func show_xp_gain(amount: int, current_xp: int, xp_to_next: int, source: String = "") -> void:
	_queue.append(
		{
			"type": "xp_gain",
			"amount": amount,
			"current": current_xp,
			"required": xp_to_next,
			"source": source
		}
	)
	_process_queue()


func _process_queue() -> void:
	if _is_showing or _queue.is_empty():
		return

	var notif_data: Dictionary = _queue.pop_front()
	_is_showing = true

	match notif_data.type:
		"level_up":
			_show_level_up_notification(notif_data)
		"xp_gain":
			_show_xp_gain_notification(notif_data)


func _show_level_up_notification(data: Dictionary) -> void:
	_title_label.text = "LEVEL UP!"
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))

	var skill_text := ""
	if data.skill_points > 0:
		var plural := "s" if data.skill_points > 1 else ""
		skill_text = "\n+%d Skill Point%s" % [data.skill_points, plural]

	_details_label.text = "Level %d reached!%s" % [data.level, skill_text]
	_xp_bar.hide()

	# Update border to gold
	var panel_style: StyleBoxFlat = _container.get_theme_stylebox("panel").duplicate()
	panel_style.border_color = Color(1.0, 0.8, 0.2)
	panel_style.shadow_color = Color(1.0, 0.8, 0.2, 0.4)
	_container.add_theme_stylebox_override("panel", panel_style)

	# Animate in
	modulate.a = 0.0
	_container.position.y = -slide_distance
	show()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	var pos_tween := tween.tween_property(_container, "position:y", 0.0, 0.4)
	pos_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Scale pulse effect
	_title_label.scale = Vector2(0.5, 0.5)
	var scale_tween := tween.tween_property(_title_label, "scale", Vector2(1.0, 1.0), 0.5)
	scale_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	await tween.finished
	await get_tree().create_timer(level_up_duration - 0.7).timeout

	# Animate out
	var out_tween := create_tween()
	out_tween.set_parallel(true)
	out_tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	out_tween.tween_property(_container, "position:y", -slide_distance, 0.3).set_ease(Tween.EASE_IN)

	await out_tween.finished
	hide()
	_is_showing = false
	notification_finished.emit()
	_process_queue()


func _show_xp_gain_notification(data: Dictionary) -> void:
	_title_label.text = "+%d XP" % data.amount
	_title_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))

	if data.source.length() > 0:
		_details_label.text = data.source
	else:
		_details_label.text = ""

	_xp_bar.show()
	_xp_bar.max_value = data.required
	_xp_bar.value = data.current

	# Update border to blue
	var panel_style: StyleBoxFlat = _container.get_theme_stylebox("panel").duplicate()
	panel_style.border_color = Color(0.3, 0.7, 1.0)
	panel_style.shadow_color = Color(0.3, 0.7, 1.0, 0.3)
	_container.add_theme_stylebox_override("panel", panel_style)

	# Animate in (subtle)
	modulate.a = 0.0
	_container.scale = Vector2(0.9, 0.9)
	show()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(_container, "scale", Vector2(1.0, 1.0), 0.2)

	await tween.finished
	await get_tree().create_timer(xp_gain_duration - 0.4).timeout

	# Animate out
	var out_tween := create_tween()
	out_tween.tween_property(self, "modulate:a", 0.0, 0.2)

	await out_tween.finished
	hide()
	_is_showing = false
	notification_finished.emit()
	_process_queue()


func _on_level_up(new_level: int, _skill_points: int = 1) -> void:
	show_level_up(new_level, _skill_points)


## Internal callback matching xp_gained signal signature (amount, new_xp, xp_to_next)


func _on_xp_gained_internal(amount: int, current_xp: int, xp_to_next: int) -> void:
	show_xp_gain(amount, current_xp, xp_to_next, "Enemy Killed")


func _on_xp_gained(amount: int, source: String) -> void:
	# Get current XP info from progression
	for node: Node in get_tree().get_nodes_in_group("player"):
		if not node.is_multiplayer_authority():
			continue

		var progression: Node = node.get_node_or_null("PlayerProgression")
		if progression and "current_xp" in progression:
			var xp_to_next: int = 100
			if progression.has_method("get_xp_to_next_level"):
				xp_to_next = progression.get_xp_to_next_level()
			show_xp_gain(amount, progression.current_xp, xp_to_next, source)
			return

	# Fallback without details
	show_xp_gain(amount, 0, 100, source)
