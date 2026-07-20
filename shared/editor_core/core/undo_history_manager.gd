@tool
class_name UndoHistoryManager
extends Node

signal history_changed
signal action_performed(description: String)
signal action_undone(description: String)
signal action_redone(description: String)

var undo_stack: Array[HistoryEntry] = []
var redo_stack: Array[HistoryEntry] = []
var max_undo_stack: int = 0
var max_redo_stack: int = 100

var _current_action: HistoryEntry = null
var _is_building_action: bool = false
var _current_group_id: String = ""
var _is_grouping: bool = false


class HistoryEntry:
	var description: String
	var timestamp: int
	var do_actions: Array[Callable]
	var undo_actions: Array[Callable]
	var is_grouped: bool
	var group_id: String

	func _init(desc: String = "") -> void:
		description = desc
		timestamp = Time.get_unix_time_from_system()
		do_actions = []
		undo_actions = []
		is_grouped = false
		group_id = ""


## Undo/redo stacks

## Current action being built

## Grouping

## Stack limits (0 = unlimited)


func _ready() -> void:
	name = "UndoHistoryManager"


## Start a new action


func create_action(description: String) -> void:
	_current_action = HistoryEntry.new(description)
	_is_building_action = true

	if _is_grouping:
		_current_action.is_grouped = true
		_current_action.group_id = _current_group_id


## Add a do method to current action


func add_do_method(callable: Callable) -> void:
	if _current_action:
		_current_action.do_actions.append(callable)


## Add an undo method to current action


func add_undo_method(callable: Callable) -> void:
	if _current_action:
		_current_action.undo_actions.append(callable)


## Add a do property change


func add_do_property(obj: Object, property: StringName, value: Variant) -> void:
	if _current_action:
		_current_action.do_actions.append(func() -> void: obj.set(property, value))


## Add an undo property change


func add_undo_property(obj: Object, property: StringName, value: Variant) -> void:
	if _current_action:
		_current_action.undo_actions.append(func() -> void: obj.set(property, value))


## Commit the current action


func commit_action(execute: bool = true) -> void:
	if not _current_action:
		return

	_is_building_action = false

	# Execute do actions
	if execute:
		for action: Callable in _current_action.do_actions:
			action.call()

	# Add to undo stack
	undo_stack.append(_current_action)

	# Clear redo stack (new action invalidates redo)
	redo_stack.clear()

	# Enforce stack limit
	if max_undo_stack > 0:
		while undo_stack.size() > max_undo_stack:
			undo_stack.pop_front()

	action_performed.emit(_current_action.description)
	history_changed.emit()

	_current_action = null


## Undo last action


func undo() -> bool:
	if undo_stack.is_empty():
		return false

	var entry: HistoryEntry = undo_stack.pop_back()

	# Execute undo actions in reverse order
	for i: int in range(entry.undo_actions.size() - 1, -1, -1):
		entry.undo_actions[i].call()

	# Add to redo stack
	redo_stack.append(entry)

	# Enforce redo stack limit
	if max_redo_stack > 0:
		while redo_stack.size() > max_redo_stack:
			redo_stack.pop_front()

	action_undone.emit(entry.description)
	history_changed.emit()

	return true


## Redo last undone action


func redo() -> bool:
	if redo_stack.is_empty():
		return false

	var entry: HistoryEntry = redo_stack.pop_back()

	# Execute do actions
	for action: Callable in entry.do_actions:
		action.call()

	# Add back to undo stack
	undo_stack.append(entry)

	action_redone.emit(entry.description)
	history_changed.emit()

	return true


## Undo multiple actions


func undo_multiple(count: int) -> int:
	var undone: int = 0
	for i: int in range(count):
		if undo():
			undone += 1
		else:
			break
	return undone


## Redo multiple actions


func redo_multiple(count: int) -> int:
	var redone: int = 0
	for i: int in range(count):
		if redo():
			redone += 1
		else:
			break
	return redone


## Start grouping actions


func begin_group(description: String = "") -> void:
	_is_grouping = true
	_current_group_id = str(Time.get_unix_time_from_system())
	if not description.is_empty():
		create_action(description + " (Group Start)")
		commit_action(false)


## End grouping and merge grouped actions


func end_group() -> void:
	if not _is_grouping:
		return

	_is_grouping = false

	# Find all actions in this group and merge them
	var group_actions: Array[HistoryEntry] = []
	var non_group: Array[HistoryEntry] = []

	for entry: HistoryEntry in undo_stack:
		if entry.is_grouped and entry.group_id == _current_group_id:
			group_actions.append(entry)
		else:
			non_group.append(entry)

	if group_actions.size() > 1:
		# Merge into single action
		var merged := HistoryEntry.new("Grouped Actions (%d)" % group_actions.size())
		for entry: HistoryEntry in group_actions:
			merged.do_actions.append_array(entry.do_actions)
			merged.undo_actions.append_array(entry.undo_actions)

		non_group.append(merged)
		undo_stack = non_group
		history_changed.emit()

	_current_group_id = ""


## Cancel current action without committing


func cancel_action() -> void:
	_current_action = null
	_is_building_action = false


## Clear all history


func clear_history() -> void:
	undo_stack.clear()
	redo_stack.clear()
	history_changed.emit()


## Get undo history for display


func get_undo_history() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: HistoryEntry in undo_stack:
		result.append(
			{
				"description": entry.description,
				"timestamp": entry.timestamp,
				"is_grouped": entry.is_grouped
			}
		)
	return result


## Get redo history for display


func get_redo_history() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: HistoryEntry in redo_stack:
		result.append(
			{
				"description": entry.description,
				"timestamp": entry.timestamp,
				"is_grouped": entry.is_grouped
			}
		)
	return result


## Check if undo is available


func can_undo() -> bool:
	return not undo_stack.is_empty()


## Check if redo is available


func can_redo() -> bool:
	return not redo_stack.is_empty()


## Get undo stack size


func get_undo_count() -> int:
	return undo_stack.size()


## Get redo stack size


func get_redo_count() -> int:
	return redo_stack.size()
