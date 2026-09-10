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
			_do_teleport(input_data)
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
	if sound_path.is_empty():
		return
	var stream := load(sound_path) as AudioStream
	if not stream:
		push_warning("[LevelActionNode] Could not load sound: %s" % sound_path)
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = "SFX"
	player.global_position = global_position
	var world := get_tree().current_scene
	if world:
		world.add_child(player)
	else:
		add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _do_spawn() -> void:
	if not entity_scene:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var entity: Node = entity_scene.instantiate()
	if entity is Node3D:
		entity.global_position = global_position
	var world = get_tree().current_scene
	if world:
		world.add_child(entity)
	else:
		add_child(entity)


func _do_destroy() -> void:
	var target := get_node_or_null(target_path)
	if target:
		target.queue_free()


func _do_set_variable(data: Dictionary) -> void:
	var variable := variable_name.strip_edges()
	if variable.is_empty():
		variable = str(data.get("variable_name", "")).strip_edges()
	if variable.is_empty():
		return
	var value: Variant = data.get("value", data.get(variable, null))
	var root := _get_runtime_root()
	if not root:
		return
	var variables: Dictionary = root.get_meta("level_variables", {}).duplicate(true)
	variables[variable] = value
	root.set_meta("level_variables", variables)
	if root.has_method("set_level_variable"):
		root.set_level_variable(variable, value)


func _do_teleport(data: Dictionary) -> void:
	var destination := _resolve_target(data)
	if not destination:
		return
	var player := _find_player()
	if player is Node3D:
		(player as Node3D).global_position = destination.global_position
		if player.has_method("on_teleported"):
			player.on_teleported(destination.global_position)


func _resolve_target(data: Dictionary) -> Node3D:
	var candidate: Variant = data.get("target", data.get("to_point", null))
	if candidate is Node3D:
		return candidate
	if not target_path.is_empty():
		var target := get_node_or_null(target_path)
		if target is Node3D:
			return target
	return null


func _find_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		players = get_tree().get_nodes_in_group("players")
	return players[0] if not players.is_empty() else null


func _get_runtime_root() -> Node:
	var scene := get_tree().current_scene
	return scene if scene else get_parent()


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
