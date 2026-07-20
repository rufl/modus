@tool
extends ScriptNodeBase
class_name LogicNode

enum LogicType { BRANCH, SEQUENCE, AND_GATE, OR_GATE, NOT_GATE, DELAY, FOR_LOOP, RANDOM }  # If condition, exec True or False path  # Execute all outputs in order  # Boolean AND  # Boolean OR  # Boolean NOT  # Wait then continue  # Repeat N times  # Random chance to execute

@export var logic_type: LogicType = LogicType.BRANCH
@export var delay_seconds: float = 1.0
@export var loop_count: int = 3
@export var random_chance: float = 0.5


func _ready() -> void:
	super._ready()
	_update_title()


func _update_title() -> void:
	match logic_type:
		LogicType.BRANCH:
			title = "Branch"
		LogicType.SEQUENCE:
			title = "Sequence"
		LogicType.AND_GATE:
			title = "AND"
		LogicType.OR_GATE:
			title = "OR"
		LogicType.NOT_GATE:
			title = "NOT"
		LogicType.DELAY:
			title = "Delay (%.1fs)" % delay_seconds
		LogicType.FOR_LOOP:
			title = "Loop (%d)" % loop_count
		LogicType.RANDOM:
			title = "Random (%d%%)" % int(random_chance * 100)


func _setup_slots() -> void:
	for child in get_children():
		if child is HBoxContainer:
			child.queue_free()

	var exec_color := get_slot_color(SLOT_EXEC)
	var bool_color := get_slot_color(SLOT_BOOL)
	var int_color := get_slot_color(SLOT_INT)

	match logic_type:
		LogicType.BRANCH:
			add_slot_pair(SLOT_EXEC, exec_color, "Exec", SLOT_EXEC, exec_color, "True", 0)
			add_slot_pair(SLOT_BOOL, bool_color, "Condition", SLOT_EXEC, exec_color, "False", 1)
		LogicType.SEQUENCE:
			add_slot_pair(SLOT_EXEC, exec_color, "Exec", SLOT_EXEC, exec_color, "Then 1", 0)
			add_slot_pair(-1, Color.WHITE, "", SLOT_EXEC, exec_color, "Then 2", 1)
			add_slot_pair(-1, Color.WHITE, "", SLOT_EXEC, exec_color, "Then 3", 2)
		LogicType.AND_GATE:
			add_slot_pair(SLOT_BOOL, bool_color, "A", SLOT_BOOL, bool_color, "Result", 0)
			add_slot_pair(SLOT_BOOL, bool_color, "B", -1, Color.WHITE, "", 1)
		LogicType.OR_GATE:
			add_slot_pair(SLOT_BOOL, bool_color, "A", SLOT_BOOL, bool_color, "Result", 0)
			add_slot_pair(SLOT_BOOL, bool_color, "B", -1, Color.WHITE, "", 1)
		LogicType.NOT_GATE:
			add_slot_pair(SLOT_BOOL, bool_color, "In", SLOT_BOOL, bool_color, "Out", 0)
		LogicType.DELAY:
			add_slot_pair(SLOT_EXEC, exec_color, "Exec", SLOT_EXEC, exec_color, "Done", 0)
		LogicType.FOR_LOOP:
			add_slot_pair(SLOT_EXEC, exec_color, "Exec", SLOT_EXEC, exec_color, "Loop", 0)
			add_slot_pair(SLOT_INT, int_color, "Count", SLOT_EXEC, exec_color, "Done", 1)
			add_slot_pair(-1, Color.WHITE, "", SLOT_INT, int_color, "Index", 2)
		LogicType.RANDOM:
			add_slot_pair(SLOT_EXEC, exec_color, "Exec", SLOT_EXEC, exec_color, "Success", 0)
			add_slot_pair(-1, Color.WHITE, "", SLOT_EXEC, exec_color, "Fail", 1)


func execute(input_data: Dictionary = {}) -> int:
	match logic_type:
		LogicType.BRANCH:
			var condition: bool = input_data.get("condition", false)
			node_executed.emit(0 if condition else 1, input_data)
			return 0 if condition else 1
		LogicType.SEQUENCE:
			# Execute all outputs in order
			for i in range(3):
				node_executed.emit(i, input_data)
			return 0
		LogicType.AND_GATE:
			var result: bool = input_data.get("A", false) and input_data.get("B", false)
			var out := input_data.duplicate()
			out["result"] = result
			node_executed.emit(0, out)
			return 0
		LogicType.OR_GATE:
			var result: bool = input_data.get("A", false) or input_data.get("B", false)
			var out := input_data.duplicate()
			out["result"] = result
			node_executed.emit(0, out)
			return 0
		LogicType.NOT_GATE:
			var result: bool = not input_data.get("in", false)
			var out := input_data.duplicate()
			out["out"] = result
			node_executed.emit(0, out)
			return 0
		LogicType.DELAY:
			# In real implementation would use timer
			node_executed.emit(0, input_data)
			return 0
		LogicType.FOR_LOOP:
			var count: int = input_data.get("count", loop_count)
			for i in range(count):
				var loop_data := input_data.duplicate()
				loop_data["index"] = i
				node_executed.emit(0, loop_data)  # Loop body
			node_executed.emit(1, input_data)  # Done
			return 1
		LogicType.RANDOM:
			var success := randf() < random_chance
			node_executed.emit(0 if success else 1, input_data)
			return 0 if success else 1

	return 0


func serialize() -> Dictionary:
	var data := super.serialize()
	data.data["logic_type"] = logic_type
	data.data["delay_seconds"] = delay_seconds
	data.data["loop_count"] = loop_count
	data.data["random_chance"] = random_chance
	return data


func _apply_data() -> void:
	if node_data.has("logic_type"):
		logic_type = node_data.logic_type
	if node_data.has("delay_seconds"):
		delay_seconds = node_data.delay_seconds
	if node_data.has("loop_count"):
		loop_count = node_data.loop_count
	if node_data.has("random_chance"):
		random_chance = node_data.random_chance
