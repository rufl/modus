@tool
class_name ActorBase
extends Node3D

signal activated(data: Dictionary)
signal deactivated
signal state_changed(new_state: bool)

@export var actor_id: String = ""
@export var actor_name: String = "Actor"
@export var actor_category: String = "generic"
@export var actor_description: String = ""
@export var output_channel: String = ""
@export var input_channels: PackedStringArray = []
@export var is_enabled: bool = true
@export var starts_active: bool = false
@export var one_shot: bool = false
@export var activation_delay: float = 0.0
@export var deactivation_delay: float = 0.0
@export var cooldown: float = 0.0

var is_active: bool = false
var activation_count: int = 0

var _cooldown_timer: float = 0.0
var _delay_timer: float = 0.0
var _is_delaying: bool = false
var _pending_action: String = ""  # "activate" or "deactivate"


func _ready() -> void:
	# Mark as editor-placed
	set_meta("level_editor_placed", true)
	set_meta("actor_type", actor_category)

	# Initialize state
	if starts_active:
		call_deferred("_do_activate", {})

	_on_actor_ready()


func _process(delta: float) -> void:
	# Handle cooldown
	if _cooldown_timer > 0:
		_cooldown_timer -= delta

	# Handle delayed activation
	if _is_delaying:
		_delay_timer -= delta
		if _delay_timer <= 0:
			_is_delaying = false
			if _pending_action == "activate":
				_do_activate({})
			elif _pending_action == "deactivate":
				_do_deactivate()
			_pending_action = ""


## Override in subclasses for custom ready logic


func _on_actor_ready() -> void:
	pass


## Trigger activation from external source


func trigger(source: Node = null, data: Dictionary = {}) -> void:
	if not is_enabled:
		return

	if one_shot and activation_count > 0:
		return

	if _cooldown_timer > 0:
		return

	# Add source to data
	data["source"] = source

	# Handle delay
	if activation_delay > 0 and not _is_delaying:
		_is_delaying = true
		_delay_timer = activation_delay
		_pending_action = "activate"
		return

	_do_activate(data)


## Internal activation


func _do_activate(data: Dictionary) -> void:
	is_active = true
	activation_count += 1

	if cooldown > 0:
		_cooldown_timer = cooldown

	# Notify
	activated.emit(data)
	state_changed.emit(true)

	# Override point
	_on_activated(data)

	# Emit to output channel
	_emit_to_channel(true, data)


## Override in subclasses


func _on_activated(_data: Dictionary) -> void:
	pass


## Deactivate the actor


func deactivate() -> void:
	if not is_active:
		return

	# Handle delay
	if deactivation_delay > 0 and not _is_delaying:
		_is_delaying = true
		_delay_timer = deactivation_delay
		_pending_action = "deactivate"
		return

	_do_deactivate()


## Internal deactivation


func _do_deactivate() -> void:
	is_active = false

	deactivated.emit()
	state_changed.emit(false)

	_on_deactivated()

	_emit_to_channel(false, {})


## Override in subclasses


func _on_deactivated() -> void:
	pass


## Toggle state


func toggle() -> void:
	if is_active:
		deactivate()
	else:
		trigger(null, {})


## Emit to output channel


func _emit_to_channel(value: bool, data: Dictionary) -> void:
	if output_channel.is_empty():
		return

	# Find ChannelSystem
	var channel_system: Node = _find_channel_system()
	if channel_system and channel_system.has_method("emit"):
		data["value"] = value
		channel_system.emit(output_channel, data)


## Find ChannelSystem in tree


func _find_channel_system() -> Node:
	var current: Node = self
	while current:
		if current.has_node("ChannelSystem"):
			return current.get_node("ChannelSystem")
		current = current.get_parent()
	return null


## Handle input from channel


func receive_channel_input(channel: String, data: Dictionary) -> void:
	if channel in input_channels:
		var value: bool = data.get("value", true)
		if value:
			trigger(data.get("source"), data)
		else:
			deactivate()


## Reset to initial state


func reset() -> void:
	is_active = starts_active
	activation_count = 0
	_cooldown_timer = 0.0
	_delay_timer = 0.0
	_is_delaying = false
	_pending_action = ""

	_on_reset()


## Override for custom reset


func _on_reset() -> void:
	pass


## Get inspector properties for editor UI


func get_inspector_properties() -> Array[Dictionary]:
	return [
		{
			"name": "is_enabled",
			"type": TYPE_BOOL,
			"label": "Enabled",
			"description": "Whether this actor responds to triggers"
		},
		{
			"name": "starts_active",
			"type": TYPE_BOOL,
			"label": "Starts Active",
			"description": "Whether this actor is active when the level starts"
		},
		{
			"name": "one_shot",
			"type": TYPE_BOOL,
			"label": "One Shot",
			"description": "If true, can only be activated once"
		},
		{
			"name": "activation_delay",
			"type": TYPE_FLOAT,
			"label": "Activation Delay",
			"description": "Delay before activation (seconds)"
		},
		{
			"name": "cooldown",
			"type": TYPE_FLOAT,
			"label": "Cooldown",
			"description": "Time before can be triggered again"
		},
		{
			"name": "output_channel",
			"type": TYPE_STRING,
			"label": "Output Channel",
			"description": "Channel to emit to when activated"
		}
	]


## Get gizmo data for editor visualization


func get_gizmo_data() -> Dictionary:
	return {
		"type": "actor",
		"category": actor_category,
		"color": _get_category_color(),
		"icon": _get_category_icon(),
		"connections": _get_connection_targets()
	}


func _get_category_color() -> Color:
	match actor_category:
		"activator":
			return Color(0.4, 0.8, 0.4)  # Green
		"effect":
			return Color(0.8, 0.8, 0.4)  # Yellow
		"hazard":
			return Color(0.9, 0.3, 0.1)  # Orange-red
		"mover":
			return Color(0.6, 0.4, 0.8)  # Purple
		"trigger":
			return Color(0.4, 0.6, 0.8)  # Blue
		_:
			return Color(0.5, 0.5, 0.5)  # Gray


func _get_category_icon() -> String:
	match actor_category:
		"activator":
			return "⚡"
		"effect":
			return "✨"
		"hazard":
			return "☠️"
		"mover":
			return "🚪"
		"trigger":
			return "🎯"
		_:
			return "📦"


func _get_connection_targets() -> Array[NodePath]:
	# Would return paths to connected actors
	var targets: Array[NodePath] = []
	if has_meta("level_editor_channels"):
		var channels: Array = get_meta("level_editor_channels")
		for conn: Dictionary in channels:
			if conn.has("target_path"):
				targets.append(conn.target_path)
	return targets
