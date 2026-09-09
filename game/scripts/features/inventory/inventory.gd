class_name Inventory
extends Resource

signal inventory_changed
signal item_added(item: InventoryItem, slot: int)
signal item_removed(item: InventoryItem, slot: int)
signal equipment_changed(slot_name: String, item: InventoryItem)

const MAX_SLOTS: int = 40
const EQUIPMENT_SLOTS: Array[String] = [
	"head", "chest", "legs", "feet", "hands", "weapon_primary", "weapon_secondary"
]

var slots: Array[InventoryItem] = []
var equipment: Dictionary = {}
var owner_peer_id: int = 0


func _init() -> void:
	# Initialize empty slots
	slots.resize(MAX_SLOTS)
	for i in MAX_SLOTS:
		slots[i] = null

	# Initialize equipment slots
	for slot_name in EQUIPMENT_SLOTS:
		equipment[slot_name] = null


## Add item to inventory, returns true if successful


func add_item(item: InventoryItem) -> bool:
	if not item or item.current_stack <= 0 or item.max_stack <= 0:
		return false

	# Check the entire transfer before mutating either inventory or incoming stack.
	var required: int = item.current_stack
	for slot in slots:
		if not slot:
			required -= mini(required, item.max_stack)
		elif item.max_stack > 1 and slot.can_stack_with(item):
			required -= mini(required, slot.max_stack - slot.current_stack)
		if required == 0:
			break
	if required > 0:
		return false

	var remaining: int = item.current_stack
	if item.max_stack > 1:
		for slot in slots:
			if slot and slot.can_stack_with(item):
				remaining = slot.add_to_stack(remaining)
				if remaining == 0:
					inventory_changed.emit()
					return true

	for i in slots.size():
		if slots[i] != null:
			continue
		var amount: int = mini(remaining, item.max_stack)
		# Reuse the incoming resource for the final stack, including single-slot adds.
		var added: InventoryItem = item
		if remaining > amount:
			added = item.duplicate_with_stack(amount)
		else:
			added.current_stack = amount
		slots[i] = added
		remaining -= amount
		item_added.emit(added, i)
		if remaining == 0:
			break

	inventory_changed.emit()
	return true


## Remove item from specific slot


func remove_item_at(slot: int, amount: int = -1) -> InventoryItem:
	if slot < 0 or slot >= slots.size():
		return null
	if slots[slot] == null:
		return null

	var item: InventoryItem = slots[slot]

	if amount < 0 or amount >= item.current_stack:
		# Remove entire stack
		slots[slot] = null
		item_removed.emit(item, slot)
		inventory_changed.emit()
		return item
	# Remove partial stack
	var removed: InventoryItem = item.duplicate_with_stack(amount)
	item.remove_from_stack(amount)
	if item.is_empty():
		slots[slot] = null
	inventory_changed.emit()
	return removed


## Get item at slot


func get_item_at(slot: int) -> InventoryItem:
	if slot < 0 or slot >= slots.size():
		return null
	return slots[slot]


## Move item between slots


func move_item(from_slot: int, to_slot: int) -> bool:
	if from_slot < 0 or from_slot >= slots.size():
		return false
	if to_slot < 0 or to_slot >= slots.size():
		return false
	if slots[from_slot] == null:
		return false

	# Swap items
	var temp: InventoryItem = slots[to_slot]
	slots[to_slot] = slots[from_slot]
	slots[from_slot] = temp

	inventory_changed.emit()
	return true


## Equip item to slot


func equip_item(item: InventoryItem, slot_name: String) -> InventoryItem:
	if not item:
		return null
	if slot_name not in EQUIPMENT_SLOTS:
		return null
	if item.equip_slot != "" and item.equip_slot != slot_name:
		return null

	var old_item: InventoryItem = equipment.get(slot_name)
	equipment[slot_name] = item

	equipment_changed.emit(slot_name, item)
	inventory_changed.emit()

	return old_item  # Return unequipped item


## Unequip item from slot


func unequip_item(slot_name: String) -> InventoryItem:
	if slot_name not in EQUIPMENT_SLOTS:
		return null

	var item: InventoryItem = equipment.get(slot_name)
	equipment[slot_name] = null

	if item:
		equipment_changed.emit(slot_name, null)
		inventory_changed.emit()

	return item


## Get equipped item


func get_equipped(slot_name: String) -> InventoryItem:
	return equipment.get(slot_name)


## Find item by ID


func find_item(item_id: String) -> int:
	for i in slots.size():
		if slots[i] and slots[i].id == item_id:
			return i
	return -1


## Count total of item type


func count_item(item_id: String) -> int:
	var total: int = 0
	for slot in slots:
		if slot and slot.id == item_id:
			total += slot.current_stack
	return total


## Check if inventory has space


func has_space() -> bool:
	for slot in slots:
		if slot == null:
			return true
	return false


## Get number of empty slots


func get_empty_slot_count() -> int:
	var count: int = 0
	for slot in slots:
		if slot == null:
			count += 1
	return count


## Clear all items


func clear() -> void:
	for i in slots.size():
		slots[i] = null
	for slot_name in EQUIPMENT_SLOTS:
		equipment[slot_name] = null
	inventory_changed.emit()


## Serialize for network/save


func to_dict() -> Dictionary:
	var slots_data: Array = []
	for slot in slots:
		if slot:
			slots_data.append(slot.to_dict())
		else:
			slots_data.append(null)

	var equipment_data: Dictionary = {}
	for slot_name: String in equipment:
		if equipment[slot_name]:
			equipment_data[slot_name] = equipment[slot_name].to_dict()
		else:
			equipment_data[slot_name] = null

	return {"slots": slots_data, "equipment": equipment_data, "owner_peer_id": owner_peer_id}


## Deserialize from network/save


func from_dict(data: Dictionary) -> void:
	owner_peer_id = data.get("owner_peer_id", 0)

	# Load slots
	var slots_data: Array = data.get("slots", [])
	slots.resize(MAX_SLOTS)
	for i in MAX_SLOTS:
		if i < slots_data.size() and slots_data[i]:
			slots[i] = InventoryItem.from_dict(slots_data[i])
		else:
			slots[i] = null

	# Load equipment
	var equipment_data: Dictionary = data.get("equipment", {})
	for slot_name in EQUIPMENT_SLOTS:
		if equipment_data.has(slot_name) and equipment_data[slot_name]:
			equipment[slot_name] = InventoryItem.from_dict(equipment_data[slot_name])
		else:
			equipment[slot_name] = null

	inventory_changed.emit()
