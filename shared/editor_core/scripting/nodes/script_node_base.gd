@tool
class_name ScriptNodeBase
extends GraphNode

signal node_executed(output_slot: int, data: Dictionary)

const SLOT_EXEC := 0  # Execution flow (white arrow)
const SLOT_BOOL := 1  # Boolean (red)
const SLOT_INT := 2  # Integer (cyan)
const SLOT_FLOAT := 3  # Float (green)
const SLOT_STRING := 4  # String (magenta)
const SLOT_OBJECT := 5  # Object reference (blue)
const SLOT_ANY := 6  # Any type (grey)

var node_id: String = ""
var node_data: Dictionary = {}


func _ready() -> void:
	# Generate unique ID
	if node_id.is_empty():
		node_id = "%s_%d" % [get_class(), randi()]

	# Setup basic appearance
	custom_minimum_size = Vector2(180, 0)
	resizable = true

	# Connect signals
	delete_request.connect(_on_delete_request)
	resize_request.connect(_on_resize_request)

	# Setup slots
	_setup_slots()


## Override in subclasses to define input/output slots


func _setup_slots() -> void:
	pass


## Execute this node (called at runtime)
## Returns output slot index to continue execution, or -1 to stop


func execute(input_data: Dictionary = {}) -> int:
	node_executed.emit(0, input_data)
	return 0


## Get connected target nodes for a specific output slot


func get_output_targets(_slot_idx: int) -> Array:
	var parent := get_parent()
	if not parent is GraphEdit:
		return []

	var targets := []
	# Will be populated by VisualScriptEditor
	return targets


## Serialize node state


func serialize() -> Dictionary:
	return {
		"id": node_id,
		"type": get_class(),
		"position": Vector2(position_offset.x, position_offset.y),
		"data": node_data.duplicate(true)
	}


## Deserialize node state


func deserialize(data: Dictionary) -> void:
	node_id = data.get("id", node_id)
	position_offset = data.get("position", Vector2.ZERO)
	node_data = data.get("data", {}).duplicate(true)
	_apply_data()


## Override to apply node_data to UI


func _apply_data() -> void:
	pass


func _on_delete_request() -> void:
	# Emit signal for editor to handle deletion with undo
	var editor := get_parent()
	if editor and editor.has_method("request_node_deletion"):
		editor.request_node_deletion(self)


func _on_resize_request(new_size: Vector2) -> void:
	size = new_size


## Helper to add a slot pair


func add_slot_pair(
	left_type: int,
	left_color: Color,
	left_name: String,
	right_type: int,
	right_color: Color,
	right_name: String,
	slot_idx: int
) -> void:
	# Create labels for slot
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if not left_name.is_empty():
		var left_label := Label.new()
		left_label.text = left_name
		left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(left_label)
	else:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(spacer)

	if not right_name.is_empty():
		var right_label := Label.new()
		right_label.text = right_name
		right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(right_label)

	add_child(hbox)

	# Enable slots
	set_slot(
		slot_idx,
		left_type >= 0,
		left_type if left_type >= 0 else 0,
		left_color,
		right_type >= 0,
		right_type if right_type >= 0 else 0,
		right_color
	)


## Slot type constants


static func get_slot_color(slot_type: int) -> Color:
	match slot_type:
		SLOT_EXEC:
			return Color(1.0, 1.0, 1.0)
		SLOT_BOOL:
			return Color(0.9, 0.2, 0.2)
		SLOT_INT:
			return Color(0.2, 0.8, 0.9)
		SLOT_FLOAT:
			return Color(0.2, 0.9, 0.4)
		SLOT_STRING:
			return Color(0.9, 0.2, 0.8)
		SLOT_OBJECT:
			return Color(0.2, 0.4, 0.9)
		SLOT_ANY:
			return Color(0.6, 0.6, 0.6)
		_:
			return Color(0.5, 0.5, 0.5)
