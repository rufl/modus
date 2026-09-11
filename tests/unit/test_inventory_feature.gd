extends GutTest

## Unit tests for InventoryFeature module
## Tests inventory creation and management
## Requirements: 12.1

const InventoryFeature = preload("res://game/scripts/features/inventory/inventory_feature.gd")
const InventoryData = preload("res://game/scripts/features/inventory/inventory_data.gd")
const InventoryComponent = preload("res://game/scripts/components/inventory_component.gd")
var inventory_feature: InventoryFeature


func before_each():
	# Wait for autoloads to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Create InventoryFeature instance
	inventory_feature = InventoryFeature.new()
	add_child(inventory_feature)

	# Initialize with test configuration
	inventory_feature.config = {
		"default_max_slots": 20,
		"allow_overflow": false,
		"auto_stack": true,
		"stacking": {"enabled": true, "default_max_stack": 99},
		"pickup": {"pickup_range": 2.0},
		"drop": {"drop_distance": 1.5}
	}

	inventory_feature.initialize()


func after_each():
	if inventory_feature:
		inventory_feature.free()


## Test: InventoryFeature initializes correctly
func test_inventory_feature_initialization():
	assert_not_null(inventory_feature, "InventoryFeature should be created")
	assert_eq(inventory_feature.max_slots, 20, "Max slots should be loaded from config")
	assert_true(inventory_feature.auto_stack, "Auto stack should be enabled")
	assert_false(inventory_feature.allow_overflow, "Overflow should be disabled")


## Test: Create inventory with default slots
func test_create_inventory_default_slots():
	var inventory: InventoryData = inventory_feature.create_inventory()

	assert_not_null(inventory, "Inventory should be created")
	assert_eq(inventory.max_slots, 20, "Inventory should have default max slots")
	assert_true(inventory.auto_stack, "Inventory should have auto_stack enabled")


## Test: Create inventory with custom slots
func test_create_inventory_custom_slots():
	var inventory: InventoryData = inventory_feature.create_inventory(10)

	assert_not_null(inventory, "Inventory should be created")
	assert_eq(inventory.max_slots, 10, "Inventory should have custom max slots")


## Test: InventoryData add item
func test_inventory_data_add_item():
	var inventory: InventoryData = inventory_feature.create_inventory(5)

	var item: Dictionary = {
		"id": "test_item", "display_name": "Test Item", "quantity": 1, "max_stack": 1
	}

	var success: bool = inventory.add_item(item, 1)

	assert_true(success, "Item should be added successfully")
	assert_eq(inventory.get_used_slots(), 1, "Used slots should be 1")
	assert_true(inventory.has_item("test_item"), "Inventory should have the item")


## Test: InventoryData remove item
func test_inventory_data_remove_item():
	var inventory: InventoryData = inventory_feature.create_inventory(5)

	var item: Dictionary = {
		"id": "test_item", "display_name": "Test Item", "quantity": 1, "max_stack": 1
	}

	inventory.add_item(item, 1)
	var success: bool = inventory.remove_item(0, 1)

	assert_true(success, "Item should be removed successfully")
	assert_eq(inventory.get_used_slots(), 0, "Used slots should be 0")
	assert_false(inventory.has_item("test_item"), "Inventory should not have the item")


## Test: InventoryData stacking
func test_inventory_data_stacking():
	var inventory: InventoryData = inventory_feature.create_inventory(5)

	var item: Dictionary = {
		"id": "stackable_item", "display_name": "Stackable Item", "quantity": 1, "max_stack": 10
	}

	inventory.add_item(item, 1)
	inventory.add_item(item, 1)
	inventory.add_item(item, 1)

	assert_eq(inventory.get_used_slots(), 1, "Should only use 1 slot for stacked items")
	assert_eq(inventory.get_item_quantity("stackable_item"), 3, "Should have 3 items stacked")


## Test: InventoryData full inventory
func test_inventory_data_full_inventory():
	var inventory: InventoryData = InventoryData.new()
	inventory.max_slots = 2
	inventory.auto_stack = false
	inventory.allow_overflow = false

	# Re-initialize items array after setting max_slots
	inventory.items.resize(2)
	for i in range(2):
		inventory.items[i] = null

	var item1: Dictionary = {"id": "item1", "display_name": "Item 1", "quantity": 1, "max_stack": 1}

	var item2: Dictionary = {"id": "item2", "display_name": "Item 2", "quantity": 1, "max_stack": 1}

	var item3: Dictionary = {"id": "item3", "display_name": "Item 3", "quantity": 1, "max_stack": 1}

	inventory.add_item(item1, 1)
	inventory.add_item(item2, 1)

	assert_true(inventory.is_full(), "Inventory should be full")

	var success: bool = inventory.add_item(item3, 1)
	assert_false(success, "Should not be able to add item to full inventory")


## Test: InventoryData clear
func test_inventory_data_clear():
	var inventory: InventoryData = inventory_feature.create_inventory(5)

	var item: Dictionary = {
		"id": "test_item", "display_name": "Test Item", "quantity": 1, "max_stack": 1
	}

	inventory.add_item(item, 1)
	inventory.add_item(item.duplicate(), 1)

	inventory.clear()

	assert_eq(inventory.get_used_slots(), 0, "All slots should be empty")
	assert_false(inventory.has_item("test_item"), "Inventory should not have any items")


## Test: InventoryData signals
func test_inventory_data_signals():
	var inventory: InventoryData = inventory_feature.create_inventory(5)

	var signals_received: Dictionary = {"item_added": 0, "item_removed": 0}

	inventory.item_added.connect(func(_item, _slot): signals_received["item_added"] += 1)
	inventory.item_removed.connect(func(_item, _slot): signals_received["item_removed"] += 1)

	var item: Dictionary = {
		"id": "test_item", "display_name": "Test Item", "quantity": 1, "max_stack": 1
	}

	inventory.add_item(item, 1)
	inventory.remove_item(0, 1)

	assert_eq(signals_received["item_added"], 1, "item_added signal should be emitted once")
	assert_eq(signals_received["item_removed"], 1, "item_removed signal should be emitted once")


## Test: InventoryComponent forwards extension hook events
func test_inventory_component_forwards_events():
	var component := InventoryComponent.new()
	var received: Dictionary = {"added": 0, "removed": 0, "full": 0}
	component.item_added.connect(func(_item, _slot): received["added"] += 1)
	component.item_removed.connect(func(_item, _slot): received["removed"] += 1)
	component.inventory_full.connect(func(): received["full"] += 1)

	component._on_item_added({"id": "item"}, 2)
	component._on_item_removed({"id": "item"}, 2)
	component._on_inventory_full()

	assert_eq(received, {"added": 1, "removed": 1, "full": 1})
	component.free()
