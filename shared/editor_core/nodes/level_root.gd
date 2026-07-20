@tool
extends Node3D

signal level_modified

@export_group("Level Info")
@export var level_name: String = "Untitled Level"
@export var level_author: String = ""
@export_multiline var level_description: String = ""
@export var level_tags: Array[String] = []
@export_group("Settings")
@export var grid_size: float = 1.0
@export var default_theme: String = "default"

var channels: Dictionary = {}
var debug_overlay: CanvasLayer = null


func _ready() -> void:
	if Engine.is_editor_hint():
		_setup_editor()
	else:
		_setup_runtime()


func _setup_editor() -> void:
	# Ensure proper grouping
	if not is_in_group("level_root"):
		add_to_group("level_root")


func _setup_runtime() -> void:
	# Add to level root group for runtime access
	if not is_in_group("level_root"):
		add_to_group("level_root")

	# Create debug overlay (toggle with F3)
	var DebugOverlay := load("res://shared/editor_core/ui/debug_overlay.gd")
	if DebugOverlay:
		debug_overlay = DebugOverlay.new()
		debug_overlay.name = "DebugOverlay"
		add_child(debug_overlay)
		debug_overlay.setup(self, null)


## Register a node to a channel as source or target


func register_to_channel(node: Node, channel_name: String, is_source: bool) -> void:
	if not channels.has(channel_name):
		channels[channel_name] = {"sources": [], "targets": []}

	var path := get_path_to(node)
	var key := "sources" if is_source else "targets"

	if not channels[channel_name][key].has(path):
		channels[channel_name][key].append(path)
		level_modified.emit()


## Unregister a node from a channel


func unregister_from_channel(node: Node, channel_name: String) -> void:
	if not channels.has(channel_name):
		return

	var path := get_path_to(node)
	channels[channel_name]["sources"].erase(path)
	channels[channel_name]["targets"].erase(path)

	# Cleanup empty channels
	var sources_list: Array = channels[channel_name]["sources"]
	var targets_list: Array = channels[channel_name]["targets"]
	var sources_empty: bool = sources_list.is_empty()
	var targets_empty: bool = targets_list.is_empty()
	if sources_empty and targets_empty:
		channels.erase(channel_name)

	level_modified.emit()


## Get all connections for a node


func get_node_connections(node: Node) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []
	var node_path := get_path_to(node)

	for channel_name: String in channels:
		var channel: Dictionary = channels[channel_name]

		# Check if node is a source
		if channel["sources"].has(node_path):
			for target_path: NodePath in channel["targets"]:
				connections.append(
					{"channel": channel_name, "role": "source", "target_path": target_path}
				)

		# Check if node is a target
		if channel["targets"].has(node_path):
			for source_path: NodePath in channel["sources"]:
				connections.append(
					{"channel": channel_name, "role": "target", "source_path": source_path}
				)

	return connections


## Emit a channel event (runtime)


func emit_channel(channel_name: String, data: Dictionary = {}) -> void:
	if not channels.has(channel_name):
		return

	for target_path: NodePath in channels[channel_name]["targets"]:
		var target := get_node_or_null(target_path)
		if target and target.has_method("on_channel_triggered"):
			target.on_channel_triggered(channel_name, data)


## Get all registered channels


func get_channel_names() -> Array[String]:
	var names: Array[String] = []
	for key: String in channels.keys():
		names.append(key)
	return names


## Find all spawn points of a type


func get_spawn_points(spawn_type: String = "") -> Array[Node3D]:
	var points: Array[Node3D] = []

	for child in get_children():
		if child.has_method("get_spawn_type"):
			if spawn_type.is_empty() or child.get_spawn_type() == spawn_type:
				points.append(child)

	return points


## Validate level (check for required elements)


func validate_level() -> Dictionary:
	var result := {"valid": true, "errors": [], "warnings": []}

	# Check for player spawn
	var player_spawns := get_spawn_points("player")
	if player_spawns.is_empty():
		result.valid = false
		result.errors.append("No player spawn point found")

	# Check for level name
	if level_name.is_empty() or level_name == "Untitled Level":
		result.warnings.append("Level has default name")

	# Check for orphan channels (sources without targets or vice versa)
	for channel_name: String in channels:
		var channel: Dictionary = channels[channel_name]
		if channel["sources"].is_empty():
			result.warnings.append("Channel '%s' has no sources" % channel_name)
		if channel["targets"].is_empty():
			result.warnings.append("Channel '%s' has no targets" % channel_name)

	return result


## Serialize level data to dictionary


func serialize() -> Dictionary:
	return {
		"level_name": level_name,
		"level_author": level_author,
		"level_description": level_description,
		"level_tags": level_tags,
		"grid_size": grid_size,
		"default_theme": default_theme,
		"channels": channels.duplicate(true)
	}


## Deserialize level data from dictionary


func deserialize(data: Dictionary) -> void:
	level_name = data.get("level_name", "Untitled Level")
	level_author = data.get("level_author", "")
	level_description = data.get("level_description", "")
	level_tags = data.get("level_tags", [])
	grid_size = data.get("grid_size", 1.0)
	default_theme = data.get("default_theme", "default")
	channels = data.get("channels", {}).duplicate(true)
