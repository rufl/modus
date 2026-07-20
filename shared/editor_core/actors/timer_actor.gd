@tool
class_name TimerActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum TimerMode { DELAY, REPEATING, COUNTDOWN }  ## Waits then activates once  ## Activates repeatedly at interval  ## Activates after countdown, then deactivates

@export var timer_mode: TimerMode = TimerMode.DELAY
@export var duration: float = 3.0
@export var repeat_count: int = 0  ## 0 = infinite for REPEATING mode
@export var auto_start: bool = false

var _time_remaining: float = 0.0
var _repeat_counter: int = 0
var _timer_running: bool = false


func _init() -> void:
	actor_category = "activator"
	actor_name = "Timer"
	actor_description = "Delayed or repeating activation"


func _on_actor_ready() -> void:
	if auto_start and starts_active:
		start_timer()


func _process(delta: float) -> void:
	super._process(delta)

	if not _timer_running:
		return

	_time_remaining -= delta

	if _time_remaining <= 0:
		_on_timer_complete()


func _on_activated(_data: Dictionary) -> void:
	start_timer()


func _on_deactivated() -> void:
	stop_timer()


func start_timer() -> void:
	_time_remaining = duration
	_timer_running = true
	_repeat_counter = 0


func stop_timer() -> void:
	_timer_running = false


func _on_timer_complete() -> void:
	match timer_mode:
		TimerMode.DELAY:
			_timer_running = false
			_emit_to_channel(true, {"timer_complete": true})

		TimerMode.REPEATING:
			_repeat_counter += 1
			_emit_to_channel(true, {"repeat": _repeat_counter})

			if repeat_count > 0 and _repeat_counter >= repeat_count:
				_timer_running = false
			else:
				_time_remaining = duration

		TimerMode.COUNTDOWN:
			_timer_running = false
			_emit_to_channel(true, {"countdown_complete": true})
			# Auto-deactivate after countdown
			call_deferred("deactivate")


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "timer_mode",
				"type": TYPE_INT,
				"label": "Mode",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Delay,Repeating,Countdown"
			},
			{"name": "duration", "type": TYPE_FLOAT, "label": "Duration"},
			{
				"name": "repeat_count",
				"type": TYPE_INT,
				"label": "Repeat Count",
				"description": "0 = infinite"
			},
			{"name": "auto_start", "type": TYPE_BOOL, "label": "Auto Start"}
		]
	)
	return props
