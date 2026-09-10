class_name TestingTimeOverlay
extends CanvasLayer

## Testing Time Overlay
## Displays current testing session time and statistics

@onready var panel: PanelContainer = $Panel
@onready var time_label: Label = $Panel/VBox/TimeLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var milestone_label: Label = $Panel/VBox/MilestoneLabel

var profiler: TestingTimeProfiler
var update_interval: float = 1.0
var time_since_update: float = 0.0


func _ready() -> void:
	profiler = GameManager.get_core_system("testing_time_profiler")
	if not profiler:
		push_error("[TestingTimeOverlay] TestingTimeProfiler not found")
		queue_free()
		return

	profiler.session_started.connect(_on_session_started)
	profiler.session_ended.connect(_on_session_ended)
	profiler.milestone_reached.connect(_on_milestone_reached)

	_update_display()


func _exit_tree() -> void:
	if profiler:
		if profiler.session_started.is_connected(_on_session_started):
			profiler.session_started.disconnect(_on_session_started)
		if profiler.session_ended.is_connected(_on_session_ended):
			profiler.session_ended.disconnect(_on_session_ended)
		if profiler.milestone_reached.is_connected(_on_milestone_reached):
			profiler.milestone_reached.disconnect(_on_milestone_reached)


func _process(delta: float) -> void:
	if not profiler or not profiler.is_session_active:
		return

	time_since_update += delta
	if time_since_update >= update_interval:
		time_since_update = 0.0
		_update_display()


func _update_display() -> void:
	if not profiler:
		return

	var stats: Dictionary = profiler.get_statistics()

	# Current session time
	if stats["is_session_active"]:
		time_label.text = "Testing: %.2f hours" % stats["current_session_hours"]
	else:
		time_label.text = "No active session"

	# Total statistics
	stats_label.text = (
		"Total: %.2f hours | Sessions: %d" % [stats["total_hours"], stats["total_sessions"]]
	)

	# Next milestone
	var next_milestone: float = stats["next_milestone"]
	if next_milestone > 0:
		var hours_remaining: float = next_milestone - stats["total_hours"]
		milestone_label.text = "Next: %.0fh (%.2fh remaining)" % [next_milestone, hours_remaining]
	else:
		milestone_label.text = "All milestones reached! 🎉"


func _on_session_started(_session_id: String, _timestamp: float) -> void:
	_update_display()


func _on_session_ended(_session_id: String, _duration: float) -> void:
	_update_display()


func _on_milestone_reached(hours: float) -> void:
	_show_milestone_notification(hours)
	_update_display()


func _show_milestone_notification(hours: float) -> void:
	var notification := PanelContainer.new()
	notification.name = "MilestoneNotification"
	notification.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notification.position = Vector2(-180, 48)
	notification.custom_minimum_size = Vector2(360, 56)
	var label := Label.new()
	label.text = "Milestone reached: %.0f hours" % hours
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification.add_child(label)
	add_child(notification)

	var tween := create_tween()
	notification.modulate.a = 0.0
	tween.tween_property(notification, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.5)
	tween.tween_property(notification, "modulate:a", 0.0, 0.4)
	tween.tween_callback(notification.queue_free)
