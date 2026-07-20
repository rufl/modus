@tool
class_name ChannelSystem
extends Node

signal channel_emitted(channel_name: String, data: Dictionary)
signal connection_created(source: Node, target: Node, channel: String)
signal connection_removed(source: Node, target: Node, channel: String)

const CHANNEL_COLORS := {
	"default": Color(0.3, 0.7, 0.3),
	"trigger": Color(0.9, 0.6, 0.2),
	"door": Color(0.2, 0.5, 0.9),
	"hazard": Color(0.9, 0.2, 0.2),
	"effect": Color(0.7, 0.3, 0.9),
}

var channels: Dictionary = {}


func create_channel(channel_name: String, color: Color = Color.WHITE) -> void:
	if channels.has(channel_name):
		return

	channels[channel_name] = {
		"sources": [],
		"targets": [],
		"color": color,
		"enabled": true,
		"delay": 0.0,
		"inverted": false
	}


## Delete a channel and all its connections


func delete_channel(channel_name: String) -> void:
	if not channels.has(channel_name):
		return

	# Notify all connected nodes
	var channel: Dictionary = channels[channel_name]
	for source: Node in channel.sources:
		for target: Node in channel.targets:
			connection_removed.emit(source, target, channel_name)

	channels.erase(channel_name)


## Connect a source node to a channel


func connect_source(node: Node, channel_name: String) -> void:
	if not channels.has(channel_name):
		create_channel(channel_name)

	if node not in channels[channel_name].sources:
		channels[channel_name].sources.append(node)

		# Emit connection created for each existing target
		for target: Node in channels[channel_name].targets:
			connection_created.emit(node, target, channel_name)


## Connect a target node to a channel


func connect_target(node: Node, channel_name: String) -> void:
	if not channels.has(channel_name):
		create_channel(channel_name)

	if node not in channels[channel_name].targets:
		channels[channel_name].targets.append(node)

		# Emit connection created for each existing source
		for source: Node in channels[channel_name].sources:
			connection_created.emit(source, node, channel_name)


## Disconnect a node from a channel


func disconnect_node(node: Node, channel_name: String) -> void:
	if not channels.has(channel_name):
		return

	var channel: Dictionary = channels[channel_name]
	var was_source: bool = node in channel.sources
	var was_target: bool = node in channel.targets

	channel.sources.erase(node)
	channel.targets.erase(node)

	# Emit removal events
	if was_source:
		for target: Node in channel.targets:
			connection_removed.emit(node, target, channel_name)
	if was_target:
		for source: Node in channel.sources:
			connection_removed.emit(source, node, channel_name)


## Create a direct connection from source to target


func create_connection(source: Node, target: Node, channel_name: String = "") -> String:
	# Auto-generate channel name if not provided
	if channel_name.is_empty():
		channel_name = "channel_%d" % channels.size()

	if not channels.has(channel_name):
		# Pick a color based on channel count
		var color_keys := CHANNEL_COLORS.keys()
		var color: Color = CHANNEL_COLORS[color_keys[channels.size() % color_keys.size()]]
		create_channel(channel_name, color)

	connect_source(source, channel_name)
	connect_target(target, channel_name)

	# Store connection metadata on source node for gizmo rendering
	_store_connection_metadata(source, target, channel_name)

	return channel_name


## Emit a channel event (called by sources at runtime)


func emit(channel_name: String, data: Dictionary = {}) -> void:
	if not channels.has(channel_name):
		return

	var channel: Dictionary = channels[channel_name]
	if not channel.enabled:
		return

	channel_emitted.emit(channel_name, data)

	# Apply delay if configured
	if channel.delay > 0:
		await get_tree().create_timer(channel.delay).timeout

	# Trigger targets
	var trigger_value: bool = not channel.inverted
	for target: Node in channel.targets:
		if is_instance_valid(target):
			_trigger_target(target, channel_name, data, trigger_value)


func _trigger_target(target: Node, channel_name: String, data: Dictionary, value: bool) -> void:
	# Try various callback methods
	if target.has_method("on_channel_triggered"):
		target.on_channel_triggered(channel_name, data, value)
	elif target.has_method("trigger"):
		target.trigger()
	elif target.has_method("activate"):
		target.activate()
	elif target.has_method("toggle"):
		target.toggle()
	# Handle common interactables
	elif target.has_method("open_door"):
		if value:
			target.open_door()
		else:
			target.close_door()


func _store_connection_metadata(source: Node, target: Node, channel_name: String) -> void:
	# Store for gizmo visualization
	var connections: Array = []
	if source.has_meta("level_editor_channels"):
		connections = source.get_meta("level_editor_channels")

	connections.append(
		{
			"channel": channel_name,
			"target_path": source.get_path_to(target),
			"color": channels[channel_name].color
		}
	)

	source.set_meta("level_editor_channels", connections)


## Get all channels a node is connected to


func get_node_channels(node: Node) -> Array[String]:
	var result: Array[String] = []

	for channel_name: String in channels:
		var channel: Dictionary = channels[channel_name]
		if node in channel.sources or node in channel.targets:
			result.append(channel_name)

	return result


## Get all connections for a node (for inspector/gizmo)


func get_node_connections(node: Node) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []

	for channel_name: String in channels:
		var channel: Dictionary = channels[channel_name]

		if node in channel.sources:
			for target: Node in channel.targets:
				connections.append(
					{
						"channel": channel_name,
						"role": "source",
						"other": target,
						"color": channel.color
					}
				)

		if node in channel.targets:
			for source: Node in channel.sources:
				connections.append(
					{
						"channel": channel_name,
						"role": "target",
						"other": source,
						"color": channel.color
					}
				)

	return connections


## Set channel properties


func set_channel_enabled(channel_name: String, enabled: bool) -> void:
	if channels.has(channel_name):
		channels[channel_name].enabled = enabled


func set_channel_delay(channel_name: String, delay: float) -> void:
	if channels.has(channel_name):
		channels[channel_name].delay = maxf(0, delay)


func set_channel_inverted(channel_name: String, inverted: bool) -> void:
	if channels.has(channel_name):
		channels[channel_name].inverted = inverted


func set_channel_color(channel_name: String, color: Color) -> void:
	if channels.has(channel_name):
		channels[channel_name].color = color


## Serialize all channels to dictionary


func serialize() -> Dictionary:
	var data := {}

	for channel_name: String in channels:
		var channel: Dictionary = channels[channel_name]
		data[channel_name] = {
			"sources": _paths_from_nodes(channel.sources),
			"targets": _paths_from_nodes(channel.targets),
			"color": channel.color.to_html(),
			"enabled": channel.enabled,
			"delay": channel.delay,
			"inverted": channel.inverted
		}

	return data


## Deserialize channels from dictionary


func deserialize(data: Dictionary, root_node: Node) -> void:
	channels.clear()

	for channel_name: String in data:
		var channel_data: Dictionary = data[channel_name]

		channels[channel_name] = {
			"sources": _nodes_from_paths(channel_data.sources, root_node),
			"targets": _nodes_from_paths(channel_data.targets, root_node),
			"color": Color.html(channel_data.get("color", "#ffffff")),
			"enabled": channel_data.get("enabled", true),
			"delay": channel_data.get("delay", 0.0),
			"inverted": channel_data.get("inverted", false)
		}


func _paths_from_nodes(nodes: Array) -> Array:
	var paths := []
	for node: Node in nodes:
		if is_instance_valid(node):
			paths.append(node.get_path())
	return paths


func _nodes_from_paths(paths: Array, root: Node) -> Array:
	var nodes := []
	for path: NodePath in paths:
		var node := root.get_node_or_null(path)
		if node:
			nodes.append(node)
	return nodes
