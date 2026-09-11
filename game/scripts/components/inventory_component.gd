## InventoryComponent - Component for entity inventory management
##
## Provides inventory functionality to entities (players, NPCs, containers).
## Integrates with InventoryFeature to create and manage inventory data.
##
## Requirements: 4.3
class_name InventoryComponent
extends GameComponent
## Signals forwarded from the owned inventory data.
signal item_added(item: Dictionary, slot_index: int)
signal item_removed(item: Dictionary, slot_index: int)
signal inventory_full

## Reference to the inventory data
var inventory: InventoryData = null

## Reference to the InventoryFeature
var inventory_feature: InventoryFeature = null

## Component configuration
var component_config: Dictionary = {}


## Initialize the component
func _ready() -> void:
	# Get InventoryFeature from GameManager
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("get_feature"):
		inventory_feature = game_manager.get_feature("inventory")

	if not inventory_feature:
		push_error("InventoryComponent: InventoryFeature not available")
		return

	# Create inventory using feature
	var max_slots: int = component_config.get("max_slots", -1)
	inventory = inventory_feature.create_inventory(max_slots)

	# Connect inventory signals
	if inventory:
		inventory.item_added.connect(_on_item_added)
		inventory.item_removed.connect(_on_item_removed)
		inventory.inventory_full.connect(_on_inventory_full)


## Add an item to the inventory
func add_item(item: Dictionary, quantity: int = 1) -> bool:
	if not inventory:
		return false
	return inventory.add_item(item, quantity)


## Remove an item from the inventory
func remove_item(slot_index: int, quantity: int = 1) -> bool:
	if not inventory:
		return false
	return inventory.remove_item(slot_index, quantity)


## Check if inventory has a specific item
func has_item(item_id: String) -> bool:
	if not inventory:
		return false
	return inventory.has_item(item_id)


## Get the total quantity of a specific item
func get_item_quantity(item_id: String) -> int:
	if not inventory:
		return 0
	return inventory.get_item_quantity(item_id)


## Get item at a specific slot
func get_item_at(slot_index: int) -> Dictionary:
	if not inventory:
		return {}
	return inventory.get_item_at(slot_index)


## Check if inventory is full
func is_full() -> bool:
	if not inventory:
		return true
	return inventory.is_full()


## Get the number of empty slots
func get_empty_slots() -> int:
	if not inventory:
		return 0
	return inventory.get_empty_slots()


## Clear all items from inventory
func clear_inventory() -> void:
	if inventory:
		inventory.clear()


## Signal handler for item added.
## Subclasses may extend this hook; observers can use the component signal.
func _on_item_added(item: Dictionary, slot_index: int) -> void:
	item_added.emit(item, slot_index)


## Signal handler for item removed.
## Subclasses may extend this hook; observers can use the component signal.
func _on_item_removed(item: Dictionary, slot_index: int) -> void:
	item_removed.emit(item, slot_index)


## Signal handler for inventory full.
## Subclasses may extend this hook; observers can use the component signal.
func _on_inventory_full() -> void:
	inventory_full.emit()


## Cleanup
func cleanup() -> void:
	if inventory:
		inventory.item_added.disconnect(_on_item_added)
		inventory.item_removed.disconnect(_on_item_removed)
		inventory.inventory_full.disconnect(_on_inventory_full)
		inventory = null
