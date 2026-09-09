extends ModusGutTestBase


class Collector:
	extends CharacterBody3D
	var health: int = 50
	var max_health: int = 100
	var blood_overlay: Control
	var inventory: Inventory


var _loot_svc: LootSvc
var _world: Node3D
var _previous_scene: Node
var _player: Collector
var _manager: InventoryMgr
var _previous_inventory: Inventory


func before_each() -> void:
	await modus_setup()
	_previous_scene = get_tree().current_scene
	_world = Node3D.new()
	_world.position = Vector3(10, 0, 20)
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	_loot_svc = LootSvc.new()
	_loot_svc.spawn_beacons = false
	_world.add_child(_loot_svc)
	_player = Collector.new()
	_player.inventory = Inventory.new()
	_world.add_child(_player)
	_manager = InventoryMgr.get_instance()
	assert_not_null(_manager, "Gameplay inventory manager must be available")
	if _manager:
		_previous_inventory = _manager.get_inventory(1)
		_manager.register_inventory(1, _player.inventory)


func after_each() -> void:
	if _manager:
		if _previous_inventory:
			_manager.register_inventory(1, _previous_inventory)
		else:
			_manager._inventories.erase(1)
	_previous_inventory = null
	get_tree().current_scene = _previous_scene
	_world.free()
	modus_teardown()


func test_selected_health_tiers_apply_healing_and_overheal() -> void:
	var expected_health: Array[int] = [60, 75, 100, 150]
	for tier: int in range(1, 5):
		_player.health = 50
		_loot_svc._spawn_consumable(_player.global_position, "melee", tier)
		var pickup := _world.get_child(_world.get_child_count() - 1) as HealthPickup
		assert_not_null(pickup)
		if not pickup:
			return
		assert_true(pickup.collect_for_player(_player, 1))
		assert_eq(_player.health, expected_health[tier - 1])


func test_weapon_rarity_survives_ready_and_affix_refresh() -> void:
	var pickup := (
		_loot_svc._spawn_pickup_direct_scene(
			LootSvc.ITEM_SCENE_MAP.weapon_pistol, _player.global_position, ItemRarity.Tier.EPIC
		)
		as WeaponPickup
	)
	assert_not_null(pickup)
	if not pickup:
		return
	assert_eq(pickup.rarity.tier, ItemRarity.Tier.EPIC)
	assert_eq(pickup.base_glow.light_color, Color(0.6, 0.2, 0.9))
	pickup.prefix_index = 1  # Heavy: +40% damage, reduced fire rate.
	pickup._update_from_indices()
	var weapon := WeaponData.new()
	weapon.damage = 100
	pickup.prefix_affix.apply_to_weapon(weapon)
	assert_eq(weapon.damage, 140, "Selected rarity must not disable existing affixes")
	assert_eq(pickup.rarity_color, Color(0.6, 0.2, 0.9))
	assert_eq(pickup.base_glow.light_color, Color(0.6, 0.2, 0.9))


func test_resource_drops_collect_with_inventory_identity_type_and_value() -> void:
	var ammo := ItemData.new("test_cells", "Rare Cells", ItemData.ItemType.AMMO)
	ammo.rarity = ItemRarity.create_rare()
	ammo.base_value = 7
	ammo.max_stack = 20
	var pickup := _loot_svc._spawn_pickup(ammo, _player.global_position, 1) as PickupBase
	assert_not_null(pickup)
	if not pickup:
		return
	assert_true(pickup.collect_for_player(_player, 1))
	var received: InventoryItem = _player.inventory.get_item_at(0)
	assert_not_null(received)
	if not received:
		return
	assert_eq(received.id, "test_cells")
	assert_eq(received.display_name, "Rare Cells")
	assert_eq(received.item_type, InventoryItem.ItemType.AMMO)
	assert_eq(received.rarity, ItemRarity.Tier.RARE)
	assert_eq(received.value, 35)
	assert_eq(received.max_stack, 20)
	assert_false(pickup.collect_for_player(_player, 1), "Collection is single-use")
	assert_eq(received.current_stack, 1)

	var material := ItemData.new("test_scrap", "Scrap", ItemData.ItemType.MISC)
	var scrap := _loot_svc._spawn_pickup(material, _player.global_position, 1) as PickupBase
	assert_true(scrap.collect_for_player(_player, 1))
	assert_eq(_player.inventory.get_item_at(1).item_type, InventoryItem.ItemType.MATERIAL)


func test_owner_sender_and_distance_rejections_preserve_pickup() -> void:
	var item := ItemData.new("restricted", "Restricted", ItemData.ItemType.MISC)
	var pickup := _loot_svc._spawn_pickup(item, _player.global_position, 2) as PickupBase
	assert_false(pickup.collect_for_player(_player, 1), "Non-owner cannot collect")
	assert_false(pickup.collect_for_player(_player, 2), "Sender cannot impersonate player")
	pickup.owner_peer_id = 1
	_player.global_position = pickup.global_position + Vector3(20, 0, 0)
	assert_false(pickup.collect_for_player(_player, 1), "Remote pickup rejected")
	assert_null(_player.inventory.get_item_at(0))
	_player.global_position = pickup.global_position
	assert_true(pickup.collect_for_player(_player, 1), "Rejected pickup remains collectible")
	assert_eq(_player.inventory.get_item_at(0).id, "restricted")


func test_full_inventory_keeps_drop_without_partially_merging() -> void:
	var item := ItemData.new("stackable", "Stackable", ItemData.ItemType.MISC)
	item.max_stack = 10
	for slot: int in range(Inventory.MAX_SLOTS):
		var filler := InventoryItem.from_dict(item.to_inventory_dict())
		filler.id = "filler_%d" % slot
		filler.current_stack = 10
		_player.inventory.slots[slot] = filler
	_player.inventory.slots[0].id = "stackable"
	_player.inventory.slots[0].current_stack = 9
	var pickup := _loot_svc._spawn_pickup(item, _player.global_position, 1) as PickupBase
	pickup.item_data.current_stack = 2
	assert_false(pickup.collect_for_player(_player, 1))
	assert_eq(_player.inventory.slots[0].current_stack, 9, "Rejected transfer is atomic")
	_player.inventory.remove_item_at(1)
	assert_true(pickup.collect_for_player(_player, 1))
	assert_eq(_player.inventory.slots[0].current_stack, 10)
	assert_eq(_player.inventory.slots[1].current_stack, 1)


func test_custom_consumable_scene_preserves_resource_and_inventory_transfer() -> void:
	var item := ItemData.new("custom_tonic", "Custom Tonic", ItemData.ItemType.CONSUMABLE)
	item.world_scene = load("res://game/scenes/items/pickups/consumable_pickup.tscn")
	item.rarity = ItemRarity.create_epic()
	var pickup := _loot_svc._spawn_pickup(item, _player.global_position, 1) as PickupBase
	assert_true(pickup.collect_for_player(_player, 1))
	var received := _player.inventory.get_item_at(0)
	assert_eq(received.id, "custom_tonic")
	assert_eq(received.item_type, InventoryItem.ItemType.CONSUMABLE)
	assert_eq(received.rarity, ItemRarity.Tier.EPIC)


func test_configured_table_weights_produce_collectible_health_with_selected_tier() -> void:
	var table := (
		_loot_svc
		. _create_loot_table_from_data(
			{
				"rolls": 2,
				"entries":
				[
					{"item_id": "health_large", "weight": 0.0, "rarity": "common"},
					{"item_id": "health_small", "weight": 1.0, "rarity": "rare"},
				],
			}
		)
	)
	var rolled := table.roll_loot()
	assert_eq(rolled.size(), 2)
	for item: ItemData in rolled:
		var pickup := _loot_svc._spawn_pickup(item, _player.global_position, 1) as HealthPickup
		assert_not_null(pickup)
		if not pickup:
			return
		assert_eq(pickup.tier, HealthPickup.HealthTier.SMALL)
		assert_eq(pickup.rarity.tier, ItemRarity.Tier.RARE)
		assert_true(pickup.collect_for_player(_player, 1))
	assert_eq(_player.health, 70)
	var empty_table := _loot_svc._create_loot_table_from_data(
		{"rolls": 2, "entries": [{"is_empty": true, "weight": 1.0}]}
	)
	assert_eq(empty_table.roll_loot().size(), 0)
