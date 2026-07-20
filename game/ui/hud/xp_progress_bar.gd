extends Control
class_name XPProgressBar

## HUD element showing XP progress and level

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var level_label: Label = $LevelLabel
@onready var xp_label: Label = $XPLabel

var player_progression: PlayerProgression = null


func _ready() -> void:
	# Skip in editor
	if Engine.is_editor_hint():
		return


func initialize(p_player_progression: PlayerProgression) -> void:
	## Initialize with player progression
	player_progression = p_player_progression

	if not player_progression:
		visible = false
		return

	# Connect signals
	player_progression.xp_progress_changed.connect(_on_xp_progress_changed)
	player_progression.level_up.connect(_on_level_up)

	# Initial update
	_update_display()


func _update_display() -> void:
	## Update progress bar and labels
	if not player_progression:
		return

	var current_xp: int = player_progression.get_current_xp()
	var xp_needed: int = player_progression.get_xp_for_next_level()
	var progress: float = player_progression.get_xp_progress()
	var level: int = player_progression.get_level()

	if progress_bar:
		progress_bar.value = progress * 100.0

	if level_label:
		level_label.text = "Level %d" % level

	if xp_label:
		xp_label.text = "%d / %d XP" % [current_xp, xp_needed]


func _on_xp_progress_changed(current_xp: int, xp_to_next_level: int, progress: float) -> void:
	## Handle XP progress changed
	_update_display()


func _on_level_up(new_level: int, skill_points_awarded: int) -> void:
	## Handle level up - show animation
	_update_display()
	_play_level_up_animation()


func _play_level_up_animation() -> void:
	## Play level up animation
	if not level_label:
		return

	# Scale animation
	var tween := create_tween()
	tween.set_parallel(true)

	# Scale up
	(
		tween
		. tween_property(level_label, "scale", Vector2(1.5, 1.5), 0.2)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)

	# Color flash
	var original_color := level_label.get_theme_color("font_color", "Label")
	tween.tween_property(level_label, "modulate", Color.YELLOW, 0.2)

	# Scale back down
	(
		tween
		. chain()
		. tween_property(level_label, "scale", Vector2(1.0, 1.0), 0.3)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_IN)
	)
	tween.parallel().tween_property(level_label, "modulate", Color.WHITE, 0.3)
