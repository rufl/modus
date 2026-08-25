extends Control
class_name SkillTreeUI

## Frontend UI for skill tree system
## Displays skills, allows point distribution, shows requirements

signal skill_tree_closed

@export var skill_button_scene: PackedScene

@onready var category_tabs: TabContainer = $Panel/VBoxContainer/CategoryTabs
@onready var skill_points_label: Label = $Panel/VBoxContainer/Header/SkillPointsLabel
@onready var player_level_label: Label = $Panel/VBoxContainer/Header/PlayerLevelLabel
@onready var close_button: Button = $Panel/VBoxContainer/Header/CloseButton
@onready var reset_button: Button = $Panel/VBoxContainer/Footer/ResetButton
@onready var skill_detail_panel: Panel = $SkillDetailPanel
@onready var skill_detail_name: Label = $SkillDetailPanel/VBox/SkillName
@onready var skill_detail_desc: RichTextLabel = $SkillDetailPanel/VBox/Description
@onready var skill_detail_level: Label = $SkillDetailPanel/VBox/LevelInfo
@onready var skill_detail_requirements: Label = $SkillDetailPanel/VBox/Requirements
@onready var skill_detail_unlock_btn: Button = $SkillDetailPanel/VBox/UnlockButton
@onready var main_panel: Panel = $Panel

var skill_tree_manager: SkillTreeManager = null
var player_progression: PlayerProgression = null
var skill_buttons: Dictionary = {}  # skill_id -> SkillButton
var selected_skill_id: String = ""


func _ready() -> void:
	# Skip in editor
	if Engine.is_editor_hint():
		return

	# Hide by default
	visible = false

	# Connect signals
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	if skill_detail_unlock_btn:
		skill_detail_unlock_btn.pressed.connect(_on_unlock_skill_pressed)

	# Hide detail panel initially
	if skill_detail_panel:
		skill_detail_panel.visible = false

	# Handle input
	set_process_input(true)
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()


func _input(_event: InputEvent) -> void:
	# DISABLED: UIInputManager now handles skill tree input
	# This prevents conflicts with centralized UI input management
	return


func initialize(
	p_skill_tree_manager: SkillTreeManager, p_player_progression: PlayerProgression
) -> void:
	## Initialize with player's skill tree manager
	skill_tree_manager = p_skill_tree_manager
	player_progression = p_player_progression

	if not skill_tree_manager:
		push_error("[SkillTreeUI] No SkillTreeManager provided")
		return

	# Connect to skill tree signals
	skill_tree_manager.skill_unlocked.connect(_on_skill_unlocked)
	skill_tree_manager.skill_points_changed.connect(_on_skill_points_changed)

	# Build UI
	_build_skill_tree_ui()
	_update_header()


func _build_skill_tree_ui() -> void:
	## Build skill tree UI with categories
	if not category_tabs:
		return

	# Clear existing tabs
	for child in category_tabs.get_children():
		child.queue_free()

	skill_buttons.clear()

	# Create tabs for each category
	var categories := skill_tree_manager.get_tree_names()
	var category_names := {"combat": "Combat", "survival": "Survival", "utility": "Utility"}

	for category in categories:
		var skills := skill_tree_manager.get_skill_tree(category)
		if skills.is_empty():
			continue

		# Create tab
		var tab := ScrollContainer.new()
		tab.name = category_names.get(category, category)
		category_tabs.add_child(tab)

		# Create grid for skills
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		tab.add_child(grid)

		# Add skill buttons
		for skill in skills:
			var skill_btn := _create_skill_button(skill)
			grid.add_child(skill_btn)
			skill_buttons[skill.skill_id] = skill_btn


func _create_skill_button(skill: SkillNode) -> Control:
	## Create a skill button
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(200, 120)
	container.tooltip_text = skill.description

	var vbox := VBoxContainer.new()
	container.add_child(vbox)

	# Skill name
	var name_label := Label.new()
	name_label.text = skill.skill_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# Level indicator
	var level_label := Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "%d / %d" % [skill.current_level, skill.max_level]
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_label)

	# Cost
	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "Cost: %d SP" % skill.cost_per_level
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(cost_label)

	# Requirements
	if not skill.prerequisites.is_empty() or skill.required_player_level > 1:
		var req_label := Label.new()
		req_label.name = "RequirementsLabel"
		var req_text := ""
		if skill.required_player_level > 1:
			req_text += "Lvl %d" % skill.required_player_level
		if not skill.prerequisites.is_empty():
			if req_text != "":
				req_text += ", "
			req_text += "Requires skills"
		req_label.text = req_text
		req_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		req_label.add_theme_font_size_override("font_size", 9)
		req_label.add_theme_color_override("font_color", Color.YELLOW)
		vbox.add_child(req_label)

	# Button
	var button := Button.new()
	button.name = "SelectButton"
	button.custom_minimum_size.y = 48
	button.focus_mode = Control.FOCUS_ALL
	button.text = "View"
	button.pressed.connect(_on_skill_button_pressed.bind(skill.skill_id))
	vbox.add_child(button)

	# Store skill ID in metadata
	container.set_meta("skill_id", skill.skill_id)

	# Update visual state
	_update_skill_button_state(container, skill)

	return container


func _update_skill_button_state(container: Control, skill: SkillNode) -> void:
	## Update skill button visual state based on unlock status
	var is_unlocked := skill.current_level > 0
	var is_maxed := skill.current_level >= skill.max_level

	# Update colors
	var panel := container as PanelContainer
	if panel:
		var style := StyleBoxFlat.new()
		if is_maxed:
			style.bg_color = Color(0.2, 0.6, 0.2, 0.8)  # Green for maxed
		elif is_unlocked:
			style.bg_color = Color(0.3, 0.5, 0.8, 0.8)  # Blue for unlocked
		else:
			style.bg_color = Color(0.3, 0.3, 0.3, 0.8)  # Gray for locked
		panel.add_theme_stylebox_override("panel", style)

	# Update level label
	var level_label := container.find_child("LevelLabel", true, false) as Label
	if level_label:
		level_label.text = "%d / %d" % [skill.current_level, skill.max_level]


func _on_skill_button_pressed(skill_id: String) -> void:
	## Handle skill button press - show detail panel
	selected_skill_id = skill_id
	_show_skill_detail(skill_id)


func _show_skill_detail(skill_id: String) -> void:
	## Show skill detail panel
	if not skill_detail_panel:
		return

	var skill: SkillNode = skill_tree_manager.get_skill(skill_id)
	if not skill:
		return

	# Update detail panel
	if skill_detail_name:
		skill_detail_name.text = skill.skill_name

	if skill_detail_desc:
		var desc: String = skill.description
		# Replace {value} placeholder with actual value
		if skill.current_level > 0:
			var level_str: String = str(skill.current_level)
			var effects: Dictionary = skill.effects.get(level_str, {})
			for key: String in effects:
				var value: Variant = effects[key]
				if value is float:
					var display_val: float = value * 100 if value < 10 else value
					desc = desc.replace("{value}", "%.1f" % display_val)
				else:
					desc = desc.replace("{value}", str(value))
		skill_detail_desc.text = desc

	if skill_detail_level:
		skill_detail_level.text = "Level: %d / %d" % [skill.current_level, skill.max_level]

	if skill_detail_requirements:
		var req_text: String = ""
		if skill.required_player_level > 1:
			req_text += "Player Level: %d\n" % skill.required_player_level
		if not skill.prerequisites.is_empty():
			req_text += "Required Skills:\n"
			for req_id: String in skill.prerequisites:
				var req_skill: SkillNode = skill_tree_manager.get_skill(req_id)
				var req_name: String = req_skill.skill_name if req_skill else req_id
				var is_met: bool = skill_tree_manager.is_skill_unlocked(req_id)
				req_text += "  - %s (%s)\n" % [req_name, "met" if is_met else "missing"]
		skill_detail_requirements.text = req_text if req_text != "" else "No requirements"

	# Update unlock button
	if skill_detail_unlock_btn:
		var can_unlock: bool = skill_tree_manager.can_unlock_skill(skill_id)
		var has_points: bool = (
			skill_tree_manager.get_available_skill_points() >= skill.cost_per_level
		)

		if skill.current_level >= skill.max_level:
			skill_detail_unlock_btn.text = "MAXED"
			skill_detail_unlock_btn.disabled = true
		elif can_unlock and has_points:
			skill_detail_unlock_btn.text = "Unlock (%d SP)" % skill.cost_per_level
			skill_detail_unlock_btn.disabled = false
		elif not can_unlock:
			skill_detail_unlock_btn.text = "Prerequisites not met"
			skill_detail_unlock_btn.disabled = true
		else:
			skill_detail_unlock_btn.text = "Not enough SP"
			skill_detail_unlock_btn.disabled = true

	skill_detail_panel.visible = true


func _on_unlock_skill_pressed() -> void:
	## Handle unlock skill button press
	if selected_skill_id == "":
		return

	var player_level: int = player_progression.get_level() if player_progression else 1
	var success: bool = skill_tree_manager.unlock_skill_with_points(selected_skill_id, player_level)

	if success:
		# Update UI
		_refresh_skill_buttons()
		_show_skill_detail(selected_skill_id)  # Refresh detail panel
		_update_header()

		# Play sound
		_play_unlock_sound()


func _refresh_skill_buttons() -> void:
	## Refresh all skill button states
	for skill_id: String in skill_buttons:
		var container: Control = skill_buttons[skill_id]
		var skill: SkillNode = skill_tree_manager.get_skill(skill_id)
		if skill:
			_update_skill_button_state(container, skill)


func _update_header() -> void:
	## Update header with current skill points and level
	if skill_points_label:
		var points: int = skill_tree_manager.get_available_skill_points()
		skill_points_label.text = "Skill Points: %d" % points

	if player_level_label and player_progression:
		var level: int = player_progression.get_level()
		player_level_label.text = "Level: %d" % level


func _on_skill_unlocked(_skill_id: String) -> void:
	## Handle skill unlocked signal
	_refresh_skill_buttons()


func _on_skill_points_changed(_available_points: int) -> void:
	## Handle skill points changed signal
	_update_header()


func _on_close_pressed() -> void:
	## Handle close button press
	close_skill_tree()


func _on_reset_pressed() -> void:
	## Handle reset button press
	# Show confirmation dialog
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Reset all skills? You will get 50% of spent points back."
	dialog.confirmed.connect(_confirm_reset)
	add_child(dialog)
	dialog.popup_centered()


func _confirm_reset() -> void:
	## Confirm skill tree reset
	skill_tree_manager.reset_all_skills()


func open_skill_tree() -> void:
	## Open skill tree UI
	visible = true
	_update_header()
	_refresh_skill_buttons()
	if not skill_buttons.is_empty():
		var first_container := skill_buttons.values()[0] as Control
		var first_button := first_container.find_child("SelectButton", true, false) as Control
		if first_button:
			first_button.grab_focus()
	elif close_button:
		close_button.grab_focus()

	# Pause game
	get_tree().paused = true

	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_skill_tree() -> void:
	## Close skill tree UI
	visible = false

	# Hide detail panel
	if skill_detail_panel:
		skill_detail_panel.visible = false

	# Unpause game
	get_tree().paused = false

	# Release mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	skill_tree_closed.emit()


func _update_responsive_layout() -> void:
	if not main_panel or not skill_detail_panel:
		return
	var edge := 16.0
	var panel_width := clampf(size.x - edge * 2.0, 320.0, 800.0)
	var panel_height := clampf(size.y - edge * 2.0, 360.0, 600.0)
	main_panel.offset_left = -panel_width / 2.0
	main_panel.offset_right = panel_width / 2.0
	main_panel.offset_top = -panel_height / 2.0
	main_panel.offset_bottom = panel_height / 2.0
	var detail_width := minf(300.0, size.x - edge * 2.0)
	skill_detail_panel.offset_left = -detail_width
	skill_detail_panel.offset_top = -minf(200.0, panel_height / 2.0)
	skill_detail_panel.offset_bottom = minf(200.0, panel_height / 2.0)


func _play_unlock_sound() -> void:
	## Play unlock sound effect
	var audio := GameManager.get_core_system("audio")
	if audio and audio.has_method("play_ui_sound"):
		audio.play_ui_sound("skill_unlock")
