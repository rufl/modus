@tool
extends ScriptNodeBase
class_name ConditionNode

enum ConditionType {
	COMPARE_EQUAL,
	COMPARE_NOT_EQUAL,
	COMPARE_GREATER,
	COMPARE_LESS,
	PLAYER_HAS_ITEM,
	ENEMIES_DEFEATED,
	VARIABLE_TRUE,
	VARIABLE_FALSE
}

@export var condition_type: ConditionType = ConditionType.COMPARE_EQUAL
@export var item_id: String = ""
@export var variable_name: String = ""
@export var zone_path: NodePath = NodePath()


func _ready() -> void:
	super._ready()
	_update_title()


func _update_title() -> void:
	match condition_type:
		ConditionType.COMPARE_EQUAL:
			title = "A == B"
		ConditionType.COMPARE_NOT_EQUAL:
			title = "A != B"
		ConditionType.COMPARE_GREATER:
			title = "A > B"
		ConditionType.COMPARE_LESS:
			title = "A < B"
		ConditionType.PLAYER_HAS_ITEM:
			title = "Has Item?"
		ConditionType.ENEMIES_DEFEATED:
			title = "Area Clear?"
		ConditionType.VARIABLE_TRUE:
			title = "Var True?"
		ConditionType.VARIABLE_FALSE:
			title = "Var False?"


func _setup_slots() -> void:
	for child in get_children():
		if child is HBoxContainer:
			child.queue_free()

	var exec_color := get_slot_color(SLOT_EXEC)
	var bool_color := get_slot_color(SLOT_BOOL)
	var any_color := get_slot_color(SLOT_ANY)
	var str_color := get_slot_color(SLOT_STRING)

	# Based on condition type
	match condition_type:
		ConditionType.COMPARE_EQUAL, ConditionType.COMPARE_NOT_EQUAL, ConditionType.COMPARE_GREATER, ConditionType.COMPARE_LESS:
			add_slot_pair(SLOT_ANY, any_color, "A", SLOT_BOOL, bool_color, "Result", 0)
			add_slot_pair(SLOT_ANY, any_color, "B", -1, Color.WHITE, "", 1)
		ConditionType.PLAYER_HAS_ITEM:
			add_slot_pair(SLOT_STRING, str_color, "Item", SLOT_BOOL, bool_color, "Has?", 0)
		ConditionType.ENEMIES_DEFEATED:
			add_slot_pair(-1, Color.WHITE, "", SLOT_BOOL, bool_color, "Clear?", 0)
		ConditionType.VARIABLE_TRUE, ConditionType.VARIABLE_FALSE:
			add_slot_pair(SLOT_STRING, str_color, "Var", SLOT_BOOL, bool_color, "Check", 0)


func execute(input_data: Dictionary = {}) -> int:
	var result := false

	match condition_type:
		ConditionType.COMPARE_EQUAL:
			result = input_data.get("A") == input_data.get("B")
		ConditionType.COMPARE_NOT_EQUAL:
			result = input_data.get("A") != input_data.get("B")
		ConditionType.COMPARE_GREATER:
			result = input_data.get("A", 0) > input_data.get("B", 0)
		ConditionType.COMPARE_LESS:
			result = input_data.get("A", 0) < input_data.get("B", 0)
		ConditionType.PLAYER_HAS_ITEM:
			result = _check_player_has_item()
		ConditionType.ENEMIES_DEFEATED:
			result = _check_enemies_defeated()
		ConditionType.VARIABLE_TRUE:
			result = _get_variable() == true
		ConditionType.VARIABLE_FALSE:
			result = _get_variable() == false

	var output_data := input_data.duplicate()
	output_data["result"] = result
	node_executed.emit(0, output_data)
	return 0


func _check_player_has_item() -> bool:
	# Would check player inventory
	return false


func _check_enemies_defeated() -> bool:
	var zone := get_node_or_null(zone_path)
	if not zone:
		return true

	# Check for enemies in zone
	if zone.has_method("get_enemy_count"):
		return zone.get_enemy_count() == 0
	return true


func _get_variable() -> Variant:
	# Would fetch from level root variables
	return false


func serialize() -> Dictionary:
	var data := super.serialize()
	data.data["condition_type"] = condition_type
	data.data["item_id"] = item_id
	data.data["variable_name"] = variable_name
	data.data["zone_path"] = str(zone_path)
	return data


func _apply_data() -> void:
	if node_data.has("condition_type"):
		condition_type = node_data.condition_type
	if node_data.has("item_id"):
		item_id = node_data.item_id
	if node_data.has("variable_name"):
		variable_name = node_data.variable_name
	if node_data.has("zone_path"):
		zone_path = NodePath(node_data.zone_path)
