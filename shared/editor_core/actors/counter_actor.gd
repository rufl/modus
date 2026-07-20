@tool
class_name CounterActor
extends "res://shared/editor_core/actors/actor_base.gd"

signal count_changed(new_count: int, target: int)

enum CountMode { EXACT, AT_LEAST, EVERY_N }  ## Activates only when count == target  ## Activates when count >= target  ## Activates every N counts

@export var target_count: int = 3
@export var count_mode: CountMode = CountMode.AT_LEAST
@export var current_count: int = 0
@export var reset_on_activate: bool = false
@export var allow_decrease: bool = true


func _init() -> void:
	actor_category = "activator"
	actor_name = "Counter"
	actor_description = "Counts inputs and activates at target"


func trigger(source: Node = null, data: Dictionary = {}) -> void:
	if not is_enabled:
		return

	# Check for decrement signal
	if data.get("decrement", false) and allow_decrease:
		current_count = maxi(0, current_count - 1)
	else:
		current_count += 1

	count_changed.emit(current_count, target_count)

	# Check activation condition
	var should_activate: bool = false

	match count_mode:
		CountMode.EXACT:
			should_activate = (current_count == target_count)
		CountMode.AT_LEAST:
			should_activate = (current_count >= target_count)
		CountMode.EVERY_N:
			should_activate = (current_count % target_count == 0) and current_count > 0

	if should_activate:
		super.trigger(source, data)
		if reset_on_activate:
			current_count = 0


func reset() -> void:
	super.reset()
	current_count = 0


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{"name": "target_count", "type": TYPE_INT, "label": "Target Count"},
			{
				"name": "count_mode",
				"type": TYPE_INT,
				"label": "Mode",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Exact,At Least,Every N"
			},
			{"name": "reset_on_activate", "type": TYPE_BOOL, "label": "Reset On Activate"}
		]
	)
	return props
