extends Control
class_name InventorySlot

signal slot_clicked(slot_index: int, button: int)
signal slot_hovered(slot_index: int)
signal slot_unhovered(slot_index: int)
signal item_dropped(from_index: int, to_index: int)
signal item_dropped_split(from_index: int, to_index: int)

const RARITY_COLORS: Dictionary = {
	0: Color(0.7, 0.7, 0.7),  # Common - Gray
	1: Color(0.3, 0.8, 0.3),  # Uncommon - Green
	2: Color(0.3, 0.5, 1.0),  # Rare - Blue
	3: Color(0.7, 0.3, 0.9),  # Epic - Purple
	4: Color(1.0, 0.6, 0.1),  # Legendary - Orange
}

@export var slot_index: int = 0
@export var is_equipment_slot: bool = false
@export var equipment_type: String = ""  # "weapon", "armor", "accessory"

var item: InventoryItem = null
var is_dragging: bool = false

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $CountLabel
@onready var rarity_frame: Panel = $RarityFrame
@onready var selection_highlight: Panel = $SelectionHighlight


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	# Hide elements initially
	count_label.hide()
	selection_highlight.hide()
	_clear_display()


func set_item(new_item: InventoryItem) -> void:
	item = new_item
	_update_display()


func clear_item() -> void:
	item = null
	_clear_display()


func get_item() -> InventoryItem:
	return item


func has_item() -> bool:
	return item != null


func _update_display() -> void:
	if not item:
		_clear_display()
		return

	# Set icon
	if item.icon:
		icon.texture = item.icon
		icon.show()
	else:
		icon.hide()

	# Set stack count (only show if > 1)
	if item.current_stack > 1:
		count_label.text = str(item.current_stack)
		count_label.show()
	else:
		count_label.hide()

	# Set rarity frame color
	var rarity: int = item.rarity if "rarity" in item else 0
	if RARITY_COLORS.has(rarity):
		rarity_frame.modulate = RARITY_COLORS[rarity]
		rarity_frame.show()
	else:
		rarity_frame.hide()


func _clear_display() -> void:
	icon.texture = null
	icon.hide()
	count_label.hide()
	rarity_frame.hide()


func _on_mouse_entered() -> void:
	slot_hovered.emit(slot_index)
	if item:
		selection_highlight.show()


func _on_mouse_exited() -> void:
	slot_unhovered.emit(slot_index)
	selection_highlight.hide()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			slot_clicked.emit(slot_index, event.button_index)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not item:
		return null

	# Check for shift key to split stack
	var is_split: bool = Input.is_key_pressed(KEY_SHIFT) and item.current_stack > 1

	if is_split:
		# We don't actually modify the inventory yet, just the drag data
		# But visually we should show half stack
		pass  # Logic handled in drop or specific split handler

	is_dragging = true

	# Create drag preview
	var preview: TextureRect = TextureRect.new()
	preview.texture = icon.texture
	preview.custom_minimum_size = Vector2(48, 48)
	preview.modulate = Color(1, 1, 1, 0.7)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Center the preview on mouse
	var control: Control = Control.new()
	control.add_child(preview)
	preview.position = -preview.custom_minimum_size / 2
	set_drag_preview(control)

	return {"slot_index": slot_index, "item": item, "split_drag": is_split}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("slot_index"):
		# Prevent dropping on itself
		if data["slot_index"] == slot_index:
			return false

		# Can drop if empty or same item type (for stacking)
		if not item:
			return true
		if data.has("item") and item.can_stack_with(data["item"]):
			return true

		# If we are dragging a split stack, valid if target is empty
		if data.get("split_drag", false):
			return not item  # Can only split into empty slot for now

		return true  # Allow swap
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("slot_index"):
		var from_index: int = data["slot_index"]
		var is_split: bool = data.get("split_drag", false)

		if from_index != slot_index:
			if is_split:
				item_dropped_split.emit(from_index, slot_index)
			else:
				item_dropped.emit(from_index, slot_index)


func set_selected(selected: bool) -> void:
	if selected:
		selection_highlight.show()
	else:
		selection_highlight.hide()
