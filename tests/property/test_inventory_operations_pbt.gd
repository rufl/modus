extends PropertyBasedTesting

## Property-Based Test: Inventory Operations
## Feature: architecture-refactoring, Task 6.4
## Validates: Requirements 12.1

const InventoryFeature = preload("res://game/scripts/features/inventory/inventory_feature.gd")
const InventoryData = preload("res://game/scripts/features/inventory/inventory_data.gd")


func test_property_adding_items_increases_inventory_size() -> void:
	# Property: Adding items to inventory should increase the number of used slots
	# (unless the item stacks with an existing item)
	
	await run_enhanced_property_test(
		"Adding items increases inventory size",
		_test_adding_items_increases_size,
		100,
		SamplingStrategy.MIXED,
		"Adding items should increase used slots count"
	)


func _test_adding_items_increases_size(test_data: Dictionary) -> bool:
	var inventory := InventoryData.new()
	inventory.max_slots = 20
	inventory.auto_stack = false  # Disable stacking for this test
	
	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))
	
	# Generate a random item
	var item: Dictionary = {
		"id": "test_item_%d" % rng.randi(),
		"display_name": "Test Item",
		"quantity": 1,
		"max_stack": 1
	}
	
	var initial_used_slots: int = inventory.get_used_slots()
	var success: bool = inventory.add_item(item, 1)
	var final_used_slots: int = inventory.get_used_slots()
	
	# Property: If add was successful, used slots should increase by 1
	if success:
		return final_used_slots == initial_used_slots + 1
	else:
		# If add failed (inventory full), used slots should not change
		return final_used_slots == initial_used_slots


func test_property_removing_items_decreases_inventory_size() -> void:
	# Property: Removing items from inventory should decrease the number of used slots
	
	await run_enhanced_property_test(
		"Removing items decreases inventory size",
		_test_removing_items_decreases_size,
		100,
		SamplingStrategy.MIXED,
		"Removing items should decrease used slots count"
	)


func _test_removing_items_decreases_size(test_data: Dictionary) -> bool:
	var inventory := InventoryData.new()
	inventory.max_slots = 20
	inventory.auto_stack = false
	
	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))
	
	# Add some items first
	var num_items: int = rng.randi_range(1, 10)
	for i in range(num_items):
		var item: Dictionary = {
			"id": "test_item_%d" % i,
			"display_name": "Test Item %d" % i,
			"quantity": 1,
			"max_stack": 1
		}
		inventory.add_item(item, 1)
	
	var initial_used_slots: int = inventory.get_used_slots()
	
	# Remove an item from a random slot
	var slot_to_remove: int = rng.randi_range(0, num_items - 1)
	var success: bool = inventory.remove_item(slot_to_remove, 1)
	var final_used_slots: int = inventory.get_used_slots()
	
	# Property: If remove was successful, used slots should decrease by 1
	if success:
		return final_used_slots == initial_used_slots - 1
	else:
		# If remove failed (slot was empty), used slots should not change
		return final_used_slots == initial_used_slots


func test_property_inventory_respects_max_size_limit() -> void:
	# Property: Inventory should not accept more items than max_slots
	
	await run_enhanced_property_test(
		"Inventory respects max size limit",
		_test_inventory_respects_max_size,
		100,
		SamplingStrategy.MIXED,
		"Inventory should reject items when full"
	)


func _test_inventory_respects_max_size(test_data: Dictionary) -> bool:
	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))
	
	# Create inventory with random max slots (minimum 1)
	var max_slots: int = rng.randi_range(5, 20)
	var inventory := InventoryData.new()
	inventory.max_slots = max_slots
	inventory.auto_stack = false
	inventory.allow_overflow = false
	
	# Re-initialize items array after setting max_slots
	inventory.items.resize(max_slots)
	for i in range(max_slots):
		inventory.items[i] = null
	
	# Fill inventory to capacity
	for i in range(max_slots):
		var item: Dictionary = {
			"id": "test_item_%d" % i,
			"display_name": "Test Item %d" % i,
			"quantity": 1,
			"max_stack": 1
		}
		var success: bool = inventory.add_item(item, 1)
		if not success:
			# Failed to add before reaching max_slots
			return false
	
	# Inventory should now be full
	if not inventory.is_full():
		return false
	
	# Try to add one more item - should fail
	var overflow_item: Dictionary = {
		"id": "overflow_item",
		"display_name": "Overflow Item",
		"quantity": 1,
		"max_stack": 1
	}
	var overflow_success: bool = inventory.add_item(overflow_item, 1)
	
	# Property: Adding to full inventory should fail
	# and used slots should still equal max_slots
	return not overflow_success and inventory.get_used_slots() == max_slots


func test_property_stacking_combines_same_items() -> void:
	# Property: When auto_stack is enabled, adding the same item multiple times
	# should stack them in the same slot (up to max_stack)
	
	await run_enhanced_property_test(
		"Stacking combines same items",
		_test_stacking_combines_items,
		100,
		SamplingStrategy.MIXED,
		"Auto-stacking should combine identical items"
	)


func _test_stacking_combines_items(test_data: Dictionary) -> bool:
	var inventory := InventoryData.new()
	inventory.max_slots = 20
	inventory.auto_stack = true
	
	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))
	
	# Create a stackable item
	var max_stack: int = rng.randi_range(5, 99)
	var item: Dictionary = {
		"id": "stackable_item",
		"display_name": "Stackable Item",
		"quantity": 1,
		"max_stack": max_stack
	}
	
	# Add the same item multiple times (but not exceeding max_stack)
	var num_to_add: int = rng.randi_range(2, min(max_stack, 10))
	for i in range(num_to_add):
		inventory.add_item(item, 1)
	
	# Property: All items should be in a single stack
	var used_slots: int = inventory.get_used_slots()
	
	# Should only use 1 slot since they stack
	if used_slots != 1:
		return false
	
	# Check the quantity in the first slot
	var first_item: Dictionary = inventory.get_item_at(0)
	return first_item.get("quantity", 0) == num_to_add


func test_property_has_item_reflects_inventory_contents() -> void:
	# Property: has_item() should return true if and only if the item exists in inventory
	
	await run_enhanced_property_test(
		"has_item reflects inventory contents",
		_test_has_item_accuracy,
		100,
		SamplingStrategy.MIXED,
		"has_item should accurately reflect item presence"
	)


func _test_has_item_accuracy(test_data: Dictionary) -> bool:
	var inventory := InventoryData.new()
	inventory.max_slots = 20
	
	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))
	
	var item_id: String = "test_item_%d" % rng.randi()
	var item: Dictionary = {
		"id": item_id,
		"display_name": "Test Item",
		"quantity": 1,
		"max_stack": 1
	}
	
	# Initially, item should not be in inventory
	if inventory.has_item(item_id):
		return false
	
	# Add the item
	inventory.add_item(item, 1)
	
	# Now item should be in inventory
	if not inventory.has_item(item_id):
		return false
	
	# Remove the item
	inventory.remove_item(0, 1)
	
	# Item should no longer be in inventory
	return not inventory.has_item(item_id)
