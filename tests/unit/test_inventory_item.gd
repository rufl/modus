extends GutTest

const ICON_PATH: String = "res://game/ui/icons/weapons/pistol.svg"
const SLOT_SCENE: PackedScene = preload("res://game/ui/hud/inventory_slot.tscn")


func test_inventory_snapshot_restores_cached_texture_in_slot() -> void:
	var texture: Texture2D = load(ICON_PATH) as Texture2D
	var original := InventoryItem.new()
	original.icon_path = ICON_PATH
	original.icon = texture
	var inventory := Inventory.new()
	inventory.slots[0] = original
	var restored := Inventory.new()
	restored.from_dict(inventory.to_dict())
	var slot: InventorySlot = SLOT_SCENE.instantiate()
	add_child_autofree(slot)
	slot.set_item(restored.get_item_at(0))

	assert_not_null(texture)
	assert_same(slot.icon.texture, texture, "Reconstruction reuses the cached texture")
	assert_true(slot.icon.visible, "A restored inventory item displays its icon")


func test_split_retains_runtime_icon_and_independent_quantities() -> void:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var texture := ImageTexture.create_from_image(image)
	var original := InventoryItem.new()
	original.id = "health_potion"
	original.icon_path = ICON_PATH
	original.icon = texture
	original.max_stack = 10
	original.current_stack = 8
	var inventory := Inventory.new()
	inventory.slots[0] = original

	var split: InventoryItem = inventory.remove_item_at(0, 3)
	assert_not_null(split)
	if not split:
		return
	var slot: InventorySlot = SLOT_SCENE.instantiate()
	add_child_autofree(slot)
	slot.set_item(split)

	assert_same(slot.icon.texture, texture, "Splitting preserves the runtime icon override")
	assert_true(slot.icon.visible)
	assert_true(original.can_stack_with(split), "Split items can merge back into their source")
	assert_eq(original.current_stack, 5)
	assert_eq(split.current_stack, 3)
	split.remove_from_stack(1)
	assert_eq(split.current_stack, 2)
	assert_eq(inventory.count_item("health_potion"), 5, "Removed stack mutations stay independent")
	original.add_to_stack(1)
	assert_eq(original.current_stack, 6)
	assert_eq(split.current_stack, 2)


func test_absent_missing_and_nontexture_icon_paths_stay_null() -> void:
	var slot: InventorySlot = SLOT_SCENE.instantiate()
	add_child_autofree(slot)
	var cases: Array[Dictionary] = [
		{},
		{"icon_path": ""},
		{"icon_path": "res://missing_inventory_icon.png"},
		{"icon_path": "res://game/ui/hud/inventory_slot.tscn"},
		{"icon_path": "res://game/config/items/sample_items.json5"},
	]
	for data in cases:
		var item := InventoryItem.from_dict(data)
		slot.set_item(item)
		assert_null(item.icon, "Invalid icon path stays null: %s" % data)
		assert_false(slot.icon.visible, "An item without a texture does not show an icon")
