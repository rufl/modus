@tool
extends ScriptNodeBase
class_name EventNode

enum EventType {
	ON_LEVEL_START,
	ON_TRIGGER_ENTER,
	ON_TRIGGER_EXIT,
	ON_PLAYER_INTERACT,
	ON_TIMER,
	ON_ENEMY_DEATH,
	ON_ITEM_PICKUP
}

@export var event_type: EventType = EventType.ON_LEVEL_START
@export var timer_interval: float = 1.0
@export var target_node: NodePath = NodePath()


func _ready() -> void:
	super._ready()
	_update_title()


func _update_title() -> void:
	match event_type:
		EventType.ON_LEVEL_START:
			title = "On Level Start"
		EventType.ON_TRIGGER_ENTER:
			title = "On Trigger Enter"
		EventType.ON_TRIGGER_EXIT:
			title = "On Trigger Exit"
		EventType.ON_PLAYER_INTERACT:
			title = "On Interact"
		EventType.ON_TIMER:
			title = "On Timer (%.1fs)" % timer_interval
		EventType.ON_ENEMY_DEATH:
			title = "On Enemy Death"
		EventType.ON_ITEM_PICKUP:
			title = "On Item Pickup"


func _setup_slots() -> void:
	# Clear existing children (except built-in)
	for child in get_children():
		if child is HBoxContainer:
			child.queue_free()

	# Event nodes only have output (execution flow)
	var exec_color := get_slot_color(SLOT_EXEC)
	var obj_color := get_slot_color(SLOT_OBJECT)

	add_slot_pair(-1, Color.WHITE, "", SLOT_EXEC, exec_color, "Exec", 0)

	# Add context output based on event type
	match event_type:
		EventType.ON_TRIGGER_ENTER, EventType.ON_TRIGGER_EXIT:
			add_slot_pair(-1, Color.WHITE, "", SLOT_OBJECT, obj_color, "Body", 1)
		EventType.ON_ENEMY_DEATH:
			add_slot_pair(-1, Color.WHITE, "", SLOT_OBJECT, obj_color, "Enemy", 1)
		EventType.ON_ITEM_PICKUP:
			add_slot_pair(-1, Color.WHITE, "", SLOT_OBJECT, obj_color, "Item", 1)


func execute(input_data: Dictionary = {}) -> int:
	# Events are entry points, they emit to their output on trigger
	node_executed.emit(0, input_data)
	return 0


func serialize() -> Dictionary:
	var data := super.serialize()
	data.data["event_type"] = event_type
	data.data["timer_interval"] = timer_interval
	data.data["target_node"] = str(target_node)
	return data


func _apply_data() -> void:
	if node_data.has("event_type"):
		event_type = node_data.event_type
	if node_data.has("timer_interval"):
		timer_interval = node_data.timer_interval
	if node_data.has("target_node"):
		target_node = NodePath(node_data.target_node)
