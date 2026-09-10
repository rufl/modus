@tool
extends Control


# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])


signal connection_selected(connection: Dictionary)
signal connection_created(source: Node, target: Node, channel: String)

var channel_system: Node = null
var level_root: Node = null
var current_filter: String = ""  # Empty = all channels

var connection_list: ItemList = null
var channel_filter: OptionButton = null
var add_btn: Button = null
var delete_btn: Button = null


func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	custom_minimum_size = Vector2(0, 200)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# Header with controls
	var header := HBoxContainer.new()
	header.name = "Header"
	vbox.add_child(header)

	var title := Label.new()
	title.text = "🔗 Channel Connections"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	channel_filter = OptionButton.new()
	channel_filter.name = "ChannelFilter"
	channel_filter.add_item("All Channels")
	channel_filter.item_selected.connect(_on_filter_changed)
	header.add_child(channel_filter)

	add_btn = Button.new()
	add_btn.name = "AddBtn"
	add_btn.text = "+"
	add_btn.tooltip_text = "Add Connection"
	add_btn.pressed.connect(_on_add_pressed)
	header.add_child(add_btn)

	delete_btn = Button.new()
	delete_btn.name = "DeleteBtn"
	delete_btn.text = "−"
	delete_btn.tooltip_text = "Delete Selected"
	delete_btn.pressed.connect(_on_delete_pressed)
	header.add_child(delete_btn)

	# Connection list
	connection_list = ItemList.new()
	connection_list.name = "ConnectionList"
	connection_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	connection_list.select_mode = ItemList.SELECT_SINGLE
	connection_list.item_selected.connect(_on_connection_selected)
	vbox.add_child(connection_list)

	# Info label
	var info := Label.new()
	info.text = "Use Connect tool (C) to create connections in 3D view"
	info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info.add_theme_font_size_override("font_size", 11)
	vbox.add_child(info)


## Setup with channel system reference


func setup(channel_sys: Node, root: Node) -> void:
	channel_system = channel_sys
	level_root = root
	refresh()


## Refresh connection list


func refresh() -> void:
	if not connection_list:
		return

	connection_list.clear()

	if not channel_system:
		return

	# Get all channels
	var channels: Dictionary = channel_system.channels if "channels" in channel_system else {}

	# Update filter dropdown
	_update_filter_options(channels.keys())

	# Populate list
	for channel_name in channels:
		var channel: Dictionary = channels[channel_name]

		for source in channel.get("sources", []):
			for target in channel.get("targets", []):
				# Filter by selected channel
				if not current_filter.is_empty() and channel_name != current_filter:
					continue

				var source_name := _get_node_name(source)
				var target_name := _get_node_name(target)

				var item_text := "%s → %s [%s]" % [source_name, target_name, channel_name]
				var idx := connection_list.add_item(item_text)

				# Store metadata
				connection_list.set_item_metadata(
					idx, {"channel": channel_name, "source": source, "target": target}
				)

				# Color by channel
				var color: Color = channel.get("color", Color.WHITE)
				connection_list.set_item_custom_fg_color(idx, color)


func _get_node_name(node: Node) -> String:
	if not is_instance_valid(node):
		return "(Invalid)"
	return node.name


func _update_filter_options(channel_names: Array) -> void:
	if not channel_filter:
		return

	channel_filter.clear()
	channel_filter.add_item("All Channels")

	for name in channel_names:
		channel_filter.add_item(name)


func _on_filter_changed(index: int) -> void:
	if index == 0:
		# "All Channels" selected
		current_filter = ""
	else:
		# Specific channel selected
		current_filter = channel_filter.get_item_text(index)

	refresh()


func _on_add_pressed() -> void:
	# Start connection mode in editor
	# This should activate the Connect tool
	_log("[VisualScriptEditor] Add connection - use Connect tool (C) in 3D view", "Log")


func _on_delete_pressed() -> void:
	if not connection_list or not channel_system:
		return

	var selected := connection_list.get_selected_items()
	if selected.is_empty():
		return

	var meta: Dictionary = connection_list.get_item_metadata(selected[0])
	if meta.is_empty():
		return

	# Remove connection
	channel_system.disconnect_node(meta.source, meta.channel)
	channel_system.disconnect_node(meta.target, meta.channel)

	refresh()


func _on_connection_selected(index: int) -> void:
	if not connection_list:
		return

	var meta: Dictionary = connection_list.get_item_metadata(index)
	connection_selected.emit(meta)

	# Select nodes in the Godot editor only; runtime callers still receive the signal.
	if Engine.is_editor_hint() and meta.has("source") and is_instance_valid(meta.source):
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(meta.source)
