class_name ProgressionHUD
extends Control

const MAX_CONNECTION_RETRIES: int = 10

@onready var xp_bar: ProgressBar = %XPBar
@onready var level_label: Label = %LevelLabel
@onready var skill_points_label: Label = %SkillPointsLabel
@onready var xp_text_label: Label = get_node_or_null("VBoxContainer/XPLabel")

var _progression: PlayerProgression = null
var _connection_retries: int = 0
var _warned_once: bool = false


func _ready() -> void:
	# Check if skills feature is enabled
	if not GameManager.is_feature_enabled("skills"):
		visible = false
		return

	# Ensure visibility if enabled
	visible = true

	# Try to find player and connect to progression
	_connect_to_player()


## Find the local player and connect to their progression system


func _connect_to_player() -> void:
	# Try to find local player immediately
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for player: Node in players:
		if player.is_multiplayer_authority():
			_setup_progression(player)
			return

	# Limit retries to prevent infinite loop in menus
	_connection_retries += 1
	if _connection_retries > MAX_CONNECTION_RETRIES:
		if not _warned_once:
			var msg := "ProgressionHUD: Player not found after %d attempts."
			push_warning(msg % MAX_CONNECTION_RETRIES)
			_warned_once = true
		return

	# Retry after delay (silent - no spam)
	await get_tree().create_timer(1.0).timeout
	_connect_to_player()


## Setup progression tracking for a player


func _setup_progression(player: Node) -> void:
	if not player.has_node("PlayerProgression"):
		push_warning("Player has no PlayerProgression component")
		return

	_progression = player.get_node("PlayerProgression")

	# Connect to progression signals
	_progression.xp_gained.connect(_on_xp_gained)
	_progression.leveled_up.connect(_on_leveled_up)
	_progression.skill_points_changed.connect(_on_skill_points_changed)

	# Initialize UI with current values
	_update_ui()


## Update all UI elements


func _update_ui() -> void:
	if not _progression:
		return

	# Update level
	if level_label:
		level_label.text = "Level %d" % _progression.current_level

	# Update skill points
	if skill_points_label:
		skill_points_label.text = "Skill Points: %d" % _progression.skill_points

	# Update XP bar
	if xp_bar:
		var progress: float = _progression.get_level_progress()
		xp_bar.value = progress * 100.0  # ProgressBar expects 0-100

		# Update XP Text Label if it exists
		if xp_text_label:
			var lvl: int = _progression.current_level
			var current_lvl_xp: int = _progression.get_xp_required_for_level(lvl)
			var next_lvl_xp: int = _progression.get_xp_required_for_level(lvl + 1)

			var current_xp_in_level: int = _progression.current_xp - current_lvl_xp
			var xp_needed_for_level: int = next_lvl_xp - current_lvl_xp

			if _progression.current_level >= _progression.max_level:
				xp_text_label.text = "MAX LEVEL"
			else:
				xp_text_label.text = "XP: %d / %d" % [current_xp_in_level, xp_needed_for_level]

		# Optional: Show XP numbers in tooltip or label
		var xp_to_next: int = _progression.get_xp_to_next_level()
		xp_bar.tooltip_text = "%d XP to next level" % xp_to_next


## Called when XP is gained


func _on_xp_gained(_amount: int, _new_xp: int, _xp_to_next: int) -> void:
	_update_ui()


## Called when player levels up


func _on_leveled_up(new_level: int, skill_points_gained: int) -> void:
	_update_ui()

	# Show level-up notification
	_show_level_up_notification(new_level, skill_points_gained)


## Called when skill points change


func _on_skill_points_changed(_new_amount: int) -> void:
	_update_ui()


## Show a level-up notification popup


func _show_level_up_notification(level: int, points: int) -> void:
	# Create popup dynamically
	var level_up_popup: PanelContainer = PanelContainer.new()
	level_up_popup.name = "LevelUpNotification"

	var vbox: VBoxContainer = VBoxContainer.new()
	level_up_popup.add_child(vbox)

	var title: Label = Label.new()
	title.text = "LEVEL UP!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var level_text: Label = Label.new()
	level_text.text = "Level %d" % level
	level_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_text.add_theme_font_size_override("font_size", 24)
	vbox.add_child(level_text)

	var points_text: Label = Label.new()
	points_text.text = "+%d Skill Point%s" % [points, "s" if points != 1 else ""]
	points_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(points_text)

	# Position at center of screen
	level_up_popup.position = get_viewport_rect().size / 2 - Vector2(150, 75)
	level_up_popup.size = Vector2(300, 150)

	add_child(level_up_popup)

	# Animate fade in
	level_up_popup.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(level_up_popup, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.5)
	tween.tween_property(level_up_popup, "modulate:a", 0.0, 0.3)
	tween.tween_callback(level_up_popup.queue_free)
