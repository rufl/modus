## InventoryData - Data model for inventory storage
##
## Manages item storage with slots, provides add/remove/query operations,
## and emits signals for inventory changes.
##
## Requirements: 4.3
class_name InventoryData
extends RefCounted

## Emitted when an item is added to the inventory
signal item_added(item: Dictionary, slot_index: int)

## Emitted when an item is removed from the inventory
signal item_removed(item: Dictionary, slot_index: int)

## Emitted when inventory is full and cannot accept more items
signal inventory_full

## Maximum number of slots in this inventory
var max_slots: int = 20

## Whether auto-stacking is enabled
var auto_stack: bool = true

## Whether overflow is allowed
var allow_overflow: bool = false

## Array of items stored in slots (Dictionary or null for empty slots)
var items: Array = []


## Initialize the inventory with empty slots
func _init() -> void:
	# Ensure max_slots is at least 1
	if max_slots < 1:
		max_slots = 1
	items.resize(max_slots)
	for i in range(max_slots):
		items[i] = null


## Add an item to the inventory
## Returns true if successful, false if inventory is full
func add_item(item: Dictionary, quantity: int = 1) -> bool:
	if not item or quantity <= 0:
		return false

	# Try to stack with existing items if auto_stack is enabled
	if auto_stack and item.has("max_stack") and item.get("max_stack", 1) > 1:
		var remaining: int = quantity

		# Find existing stacks of this item
		for i in range(items.size()):
			if items[i] and items[i].get("id") == item.get("id"):
				var current_stack: int = items[i].get("quantity", 1)
				var max_stack: int = item.get("max_stack", 99)
				var can_add: int = max_stack - current_stack

				if can_add > 0:
					var to_add: int = min(can_add, remaining)
					items[i]["quantity"] = current_stack + to_add
					remaining -= to_add
					item_added.emit(item, i)

					if remaining <= 0:
						return true

		# If there's still remaining quantity, add to new slot
		if remaining > 0:
			var slot_index: int = _find_empty_slot()
			if slot_index >= 0:
				var new_item: Dictionary = item.duplicate()
				new_item["quantity"] = remaining
				items[slot_index] = new_item
				item_added.emit(new_item, slot_index)
				return true
			if not allow_overflow:
				inventory_full.emit()
				return false
	# Non-stackable item or auto_stack disabled
	var slot_index: int = _find_empty_slot()
	if slot_index >= 0:
		var new_item: Dictionary = item.duplicate()
		new_item["quantity"] = quantity
		items[slot_index] = new_item
		item_added.emit(new_item, slot_index)
		return true
	if not allow_overflow:
		inventory_full.emit()
		return false

	return false


## Remove an item from the inventory by slot index
## Returns true if successful, false if slot is empty or invalid
func remove_item(slot_index: int, quantity: int = 1) -> bool:
	if slot_index < 0 or slot_index >= items.size():
		return false

	if items[slot_index] == null:
		return false

	var item: Dictionary = items[slot_index]
	var current_quantity: int = item.get("quantity", 1)

	if quantity >= current_quantity:
		# Remove entire stack
		var removed_item: Dictionary = items[slot_index]
		items[slot_index] = null
		item_removed.emit(removed_item, slot_index)
		return true
	# Reduce stack quantity
	items[slot_index]["quantity"] = current_quantity - quantity
	item_removed.emit(item, slot_index)
	return true


## Check if inventory has a specific item
## Returns true if the item exists in any quantity
func has_item(item_id: String) -> bool:
	for item in items:
		if item and item.get("id") == item_id:
			return true
	return false


## Get the total quantity of a specific item
func get_item_quantity(item_id: String) -> int:
	var total: int = 0
	for item in items:
		if item and item.get("id") == item_id:
			total += item.get("quantity", 1)
	return total


## Get item at a specific slot index
func get_item_at(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= items.size():
		return {}

	if items[slot_index] == null:
		return {}
	return items[slot_index]


## Get the number of used slots
func get_used_slots() -> int:
	var count: int = 0
	for item in items:
		if item != null:
			count += 1
	return count


## Get the number of empty slots
func get_empty_slots() -> int:
	return max_slots - get_used_slots()


## Check if inventory is full
func is_full() -> bool:
	return get_empty_slots() == 0


## Clear all items from inventory
func clear() -> void:
	for i in range(items.size()):
		if items[i] != null:
			var removed_item: Dictionary = items[i]
			items[i] = null
			item_removed.emit(removed_item, i)


## Find the first empty slot index
## Returns -1 if no empty slots
func _find_empty_slot() -> int:
	for i in range(items.size()):
		if items[i] == null:
			return i
	return -1
