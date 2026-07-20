@tool
extends ScriptNodeBase
class_name LevelActionNode

# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])



enum ActionType {
	ACTIVATE_OBJECT,
	DEACTIVATE_OBJECT,
	TOGGLE_OBJECT,
	PLAY_SOUND,
	SPAWN_ENTITY,
	DESTROY_ENTITY,
	SET_VARIABLE,
	TELEPORT_PLAYER,
	PRINT_DEBUG
}

@export var action_type: ActionType = ActionType.ACTIVATE_OBJECT
@export var target_path: NodePath = NodePath()
@export var sound_path: String = ""
@export var entity_scene: PackedScene = null
@export var variable_name: String = ""
@export var debug_message: String = "Debug"


func _ready() -> void:
	super._ready()
	_update_title()


func _update_title() -> void:
	match action_type:
		ActionType.ACTIVATE_OBJECT:
			title = "Activate"
		ActionType.DEACTIVATE_OBJECT:
			title = "Deactivate"
		ActionType.TOGGLE_OBJECT:
			title = "Toggle"
		ActionType.PLAY_SOUND:
			title = "Play Sound"
		ActionType.SPAWN_ENTITY:
			title = "Spawn Entity"
		ActionType.DESTROY_ENTITY:
			title = "Destroy"
		ActionType.SET_VARIABLE:
			title = "Set Variable"
		ActionType.TELEPORT_PLAYER:
			title = "Teleport Player"
		ActionType.PRINT_DEBUG:
			title = "Print"


func _setup_slots() -> void:
	for child in get_children():
		if child is HBoxContainer:
			child.queue_free()

	var exec_color := get_slot_color(SLOT_EXEC)
	var obj_color := get_slot_color(SLOT_OBJECT)
	var str_color := get_slot_color(SLOT_STRING)

	# All actions have exec in and out
	add_slot_pair(SLOT_EXEC, exec_color, "Exec", SLOT_EXEC, exec_color, "Done", 0)

	# Additional inputs based on action type
	match action_type:
		ActionType.ACTIVATE_OBJECT, ActionType.DEACTIVATE_OBJECT, ActionType.TOGGLE_OBJECT, ActionType.DESTROY_ENTITY:
			add_slot_pair(SLOT_OBJECT, obj_color, "Target", -1, Color.WHITE, "", 1)
		ActionType.PLAY_SOUND:
			add_slot_pair(SLOT_STRING, str_color, "Sound", -1, Color.WHITE, "", 1)
		ActionType.SPAWN_ENTITY:
			# Position input
			add_slot_pair(SLOT_OBJECT, obj_color, "At Point", -1, Color.WHITE, "", 1)
		ActionType.SET_VARIABLE:
			add_slot_pair(SLOT_STRING, str_color, "Name", -1, Color.WHITE, "", 1)
			add_slot_pair(SLOT_ANY, get_slot_color(SLOT_ANY), "Value", -1, Color.WHITE, "", 2)
		ActionType.TELEPORT_PLAYER:
			add_slot_pair(SLOT_OBJECT, obj_color, "To Point", -1, Color.WHITE, "", 1)
		ActionType.PRINT_DEBUG:
			add_slot_pair(SLOT_STRING, str_color, "Message", -1, Color.WHITE, "", 1)


func execute(input_data: Dictionary = {}) -> int:
	match action_type:
		ActionType.ACTIVATE_OBJECT:
			_do_activate(true)
		ActionType.DEACTIVATE_OBJECT:
			_do_activate(false)
		ActionType.TOGGLE_OBJECT:
			_do_toggle()
		ActionType.PLAY_SOUND:
			_do_play_sound()
		ActionType.SPAWN_ENTITY:
			_do_spawn()
		ActionType.DESTROY_ENTITY:
			_do_destroy()
		ActionType.SET_VARIABLE:
			_do_set_variable(input_data)
		ActionType.TELEPORT_PLAYER:
			_do_teleport()
		ActionType.PRINT_DEBUG:
			_log(str("[LevelScript] %s" % debug_message), "Log")

	node_executed.emit(0, input_data)
	return 0


func _do_activate(activate: bool) -> void:
	var target := get_node_or_null(target_path)
	if not target:
		return

	if target.has_method("set_active"):
		target.set_active(activate)
	elif target.has_method("activate") and activate:
		target.activate()
	elif target.has_method("deactivate") and not activate:
		target.deactivate()


func _do_toggle() -> void:
	var target := get_node_or_null(target_path)
	if target and target.has_method("toggle"):
		target.toggle()


func _do_play_sound() -> void:
	# STUB: Not implemented - editor feature not actively used
	# See docs/PHASE_3_STUB_ANALYSIS.md for details
	# TODO: Implement if visual scripting feature is needed
	pass


func _do_spawn() -> void:
	if not entity_scene:
		return

	# Only server spawns networked entities
	if not multiplayer.is_server():
		return

	# var spawn_pos: Vector3 = Vector3.ZERO
	# Resolve "At Point" input if connected
	# if has_slot_connection(SLOT_OBJECT):
	# pass

	# For now, just spawn at the node's own location if no target

	var entity: Node = entity_scene.instantiate()
	if entity is Node3D:
		entity.global_position = global_position  # Default to self pos

	# Add to World (so MultiplayerSpawner picks it up)
	var world = get_tree().current_scene
	if world:
		world.add_child(entity)
	else:
		add_child(entity)


func _do_destroy() -> void:
	var target := get_node_or_null(target_path)
	if target:
		target.queue_free()


func _do_set_variable(_data: Dictionary) -> void:
	# STUB: Not implemented - editor feature not actively used
	# See docs/PHASE_3_STUB_ANALYSIS.md for details
	# TODO: Implement level variable system if visual scripting feature is needed
	pass


func _do_teleport() -> void:
	# STUB: Not implemented - editor feature not actively used
	# See docs/PHASE_3_STUB_ANALYSIS.md for details
	# TODO: Implement player teleportation if visual scripting feature is needed
	pass


func serialize() -> Dictionary:
	var data := super.serialize()
	data.data["action_type"] = action_type
	data.data["target_path"] = str(target_path)
	data.data["sound_path"] = sound_path
	data.data["variable_name"] = variable_name
	data.data["debug_message"] = debug_message
	return data


func _apply_data() -> void:
	if node_data.has("action_type"):
		action_type = node_data.action_type
	if node_data.has("target_path"):
		target_path = NodePath(node_data.target_path)
	if node_data.has("sound_path"):
		sound_path = node_data.sound_path
	if node_data.has("variable_name"):
		variable_name = node_data.variable_name
	if node_data.has("debug_message"):
		debug_message = node_data.debug_message
