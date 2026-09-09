extends ModusGutTestBase


class Collector:
	extends CharacterBody3D
	var inventory: Inventory


var _world: Node
var _inventory: Inventory
var _ui: InventoryUI
var _manager: InventoryMgr
var _previous_inventory: Inventory
var _peer_id: int


func before_each() -> void:
	await modus_setup()
	_peer_id = multiplayer.get_unique_id()
	_manager = InventoryMgr.get_instance()
	_previous_inventory = _manager.get_inventory(_peer_id)
	_inventory = Inventory.new()
	_manager.register_inventory(_peer_id, _inventory)
	_world = Node.new()
	add_child(_world)
	var player := Collector.new()
	player.inventory = _inventory
	player.set_multiplayer_authority(_peer_id)
	_world.add_child(player)
	player.add_to_group("player")
	_ui = load("res://game/ui/hud/inventory_ui.tscn").instantiate()
	_world.add_child(_ui)
	await get_tree().process_frame
	await get_tree().process_frame
	_ui.open_inventory()


func after_each() -> void:
	_world.free()
	if _previous_inventory:
		_manager.register_inventory(_peer_id, _previous_inventory)
	else:
		_manager.unregister_inventory(_peer_id, _inventory)
	_previous_inventory = null
	modus_teardown()


func test_bag_drop_and_context_split_commit_once_through_host_manager() -> void:
	var cells := InventoryItem.new()
	cells.id = "cells"
	cells.max_stack = 10
	cells.current_stack = 10
	_inventory.add_item(cells)
	_ui.slots[1]._drop_data(Vector2.ZERO, {"slot_index": 0, "item": cells})
	assert_null(_inventory.get_item_at(0))
	assert_same(_inventory.get_item_at(1), cells)
	_ui._split_stack(1)
	assert_eq(_inventory.get_item_at(0).current_stack, 5)
	assert_eq(_inventory.get_item_at(1).current_stack, 5)
	_ui.slots[2]._drop_data(
		Vector2.ZERO, {"slot_index": 1, "item": _inventory.get_item_at(1), "split_drag": true}
	)
	assert_eq(_inventory.get_item_at(1).current_stack, 3)
	assert_eq(_inventory.get_item_at(2).current_stack, 2)
	assert_eq(_inventory.count_item("cells"), 10)
	assert_eq(_ui.slots[1].count_label.text, "3")
	assert_eq(_ui.slots[2].count_label.text, "2")


func test_equipment_drop_rejection_and_return_preserve_both_items() -> void:
	var helmet := InventoryItem.new()
	helmet.id = "helmet"
	helmet.equip_slot = "head"
	var boots := InventoryItem.new()
	boots.id = "boots"
	boots.equip_slot = "feet"
	_inventory.add_item(helmet)
	_inventory.add_item(boots)
	var head_slot: InventorySlot = _ui.equipment_slots.head
	head_slot._drop_data(Vector2.ZERO, {"slot_index": 0, "item": helmet})
	assert_null(_inventory.get_item_at(0))
	assert_same(_inventory.get_equipped("head"), helmet)
	assert_same(head_slot.get_item(), helmet)
	_ui.slots[1]._drop_data(Vector2.ZERO, {"slot_index": head_slot.slot_index, "item": helmet})
	assert_same(_inventory.get_item_at(1), boots)
	assert_same(_inventory.get_equipped("head"), helmet)
	_ui.slots[2]._drop_data(Vector2.ZERO, {"slot_index": head_slot.slot_index, "item": helmet})
	assert_same(_inventory.get_item_at(2), helmet)
	assert_null(_inventory.get_equipped("head"))
	assert_false(head_slot.has_item())
	assert_same(_ui.slots[2].get_item(), helmet)
