extends GutTest


func _item(item_id: String, amount: int, stack_limit: int = 10) -> InventoryItem:
	var item := InventoryItem.new()
	item.id = item_id
	item.current_stack = amount
	item.max_stack = stack_limit
	return item


func _fill_inventory(inventory: Inventory) -> void:
	for slot in Inventory.MAX_SLOTS:
		inventory.slots[slot] = _item("filler_%d" % slot, 10)


func test_insufficient_partial_capacity_preserves_bag_and_incoming_item() -> void:
	var inventory := Inventory.new()
	_fill_inventory(inventory)
	inventory.slots[0] = _item("cells", 9)
	inventory.slots[1] = _item("cells", 8)
	var incoming := _item("cells", 4)
	var before: Dictionary = inventory.to_dict()
	var incoming_before: Dictionary = incoming.to_dict()

	assert_false(inventory.add_item(incoming))
	assert_eq(inventory.to_dict(), before, "Failed add must not partially fill existing stacks")
	assert_eq(incoming.to_dict(), incoming_before, "Rejected source remains available for retry")

	inventory.remove_item_at(2)
	assert_true(inventory.add_item(incoming))
	assert_eq(inventory.count_item("cells"), 21, "Retry adds the original quantity exactly once")
	assert_eq(inventory.slots[0].current_stack, 10)
	assert_eq(inventory.slots[1].current_stack, 10)
	assert_eq(inventory.slots[2].current_stack, 1)


func test_insufficient_empty_slot_capacity_rejects_oversized_stack_atomically() -> void:
	var inventory := Inventory.new()
	_fill_inventory(inventory)
	inventory.slots[0] = _item("cells", 9)
	inventory.slots[1] = null
	var incoming := _item("cells", 12)
	var before: Dictionary = inventory.to_dict()
	var incoming_before: Dictionary = incoming.to_dict()

	assert_false(
		inventory.add_item(incoming), "One free slot plus one merge space only fits eleven"
	)
	assert_eq(inventory.to_dict(), before)
	assert_eq(incoming.to_dict(), incoming_before)


func test_oversized_add_fills_existing_stacks_and_distributes_independent_stacks() -> void:
	var inventory := Inventory.new()
	inventory.slots[0] = _item("cells", 8)
	inventory.slots[1] = _item("cells", 7)
	var incoming := _item("cells", 28)
	var total: int = inventory.count_item("cells") + incoming.current_stack

	assert_true(inventory.add_item(incoming))
	assert_eq(inventory.count_item("cells"), total, "Distribution conserves all incoming items")
	var expected: Array[int] = [10, 10, 10, 10, 3]
	for slot in expected.size():
		assert_not_null(inventory.slots[slot])
		if inventory.slots[slot]:
			assert_eq(inventory.slots[slot].current_stack, expected[slot])
	for item in inventory.slots:
		if item:
			assert_lte(item.current_stack, item.max_stack, "Every stored stack obeys its limit")

	var removed: InventoryItem = inventory.remove_item_at(2, 1)
	assert_not_null(removed)
	if removed:
		assert_eq(removed.current_stack, 1)
	assert_eq(
		inventory.count_item("cells"), total - 1, "Split stacks must not share mutable counts"
	)


func test_nonstackable_batch_uses_one_slot_per_item() -> void:
	var inventory := Inventory.new()
	assert_true(inventory.add_item(_item("sword", 3, 1)))
	assert_eq(inventory.count_item("sword"), 3)
	for slot in 3:
		assert_not_null(inventory.slots[slot])
		if inventory.slots[slot]:
			assert_eq(inventory.slots[slot].current_stack, 1)


func test_short_snapshot_replaces_tail_and_equipment_without_losing_owner() -> void:
	var inventory := Inventory.new()
	_fill_inventory(inventory)
	inventory.owner_peer_id = 7
	inventory.equipment["head"] = _item("old_helmet", 1, 1)
	var weapon := _item("new_weapon", 1, 1)
	weapon.equip_slot = "weapon_primary"
	var snapshot: Dictionary = {
		"slots": [_item("cells", 3).to_dict(), null],
		"equipment": {"weapon_primary": weapon.to_dict()},
		"owner_peer_id": 42,
	}

	inventory.from_dict(snapshot)

	assert_eq(inventory.count_item("cells"), 3)
	for slot in range(1, Inventory.MAX_SLOTS):
		assert_null(
			inventory.slots[slot], "Null and omitted trailing slots clear previous contents"
		)
	assert_eq(inventory.owner_peer_id, 42)
	assert_null(inventory.get_equipped("head"))
	var equipped: InventoryItem = inventory.get_equipped("weapon_primary")
	assert_not_null(equipped)
	if equipped:
		assert_eq(equipped.to_dict(), weapon.to_dict())


func test_empty_snapshot_clears_previously_populated_inventory() -> void:
	var inventory := Inventory.new()
	_fill_inventory(inventory)
	inventory.equipment["head"] = _item("old_helmet", 1, 1)
	inventory.owner_peer_id = 7

	inventory.from_dict({"slots": []})

	for item in inventory.slots:
		assert_null(item)
	assert_null(inventory.get_equipped("head"))
	assert_eq(inventory.owner_peer_id, 0)


func test_omitted_slots_replace_existing_contents() -> void:
	var inventory := Inventory.new()
	_fill_inventory(inventory)

	inventory.from_dict({"owner_peer_id": 42})

	for item in inventory.slots:
		assert_null(item, "An omitted slots array is an empty authoritative snapshot")
	assert_eq(inventory.owner_peer_id, 42)
