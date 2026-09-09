extends ModusGutTestBase

const SpawnerScript := preload("res://game/world/actors/props/loot_prop_spawner.gd")


class Collector:
	extends CharacterBody3D
	var health: int = 10
	var max_health: int = 100
	var blood_overlay: Control
	var inventory: Inventory = Inventory.new()
	var ammo_refills: int = 0
	var ammo_by_weapon: Dictionary = {}

	func refill_ammo() -> void:
		ammo_refills += 1

	func add_ammo_for_weapon(kind: int, amount: int) -> void:
		ammo_by_weapon[kind] = ammo_by_weapon.get(kind, 0) + amount


var _world: Node3D
var _previous_scene: Node
var _player: Collector
var _loot: LootSvc
var _previous_beacons: bool


func before_each() -> void:
	await modus_setup()
	_previous_scene = get_tree().current_scene
	_world = Node3D.new()
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	_player = Collector.new()
	_player.add_to_group("player")
	_player.collision_layer = 2
	_world.add_child(_player)
	_loot = LootSvc.get_instance()
	_previous_beacons = _loot.spawn_beacons
	_loot.spawn_beacons = false


func after_each() -> void:
	_loot.spawn_beacons = _previous_beacons
	get_tree().current_scene = _previous_scene
	_world.free()
	modus_teardown()


func _marker(kind: LootPropSpawner.PropType) -> LootPropSpawner:
	var marker := SpawnerScript.new()
	marker.spawn_on_ready = false
	marker.random_rotation = false
	marker.prop_type = kind
	_world.add_child(marker)
	return marker


func _pickups() -> Array[PickupBase]:
	var result: Array[PickupBase] = []
	for child: Node in _world.get_children():
		if child is PickupBase and not child.collected:
			result.append(child)
	return result


func _collect_supplies(expected_count: int) -> void:
	var pickups := _pickups()
	assert_eq(pickups.size(), expected_count, "Default canonical table must produce real pickups")
	for pickup: PickupBase in pickups:
		_player.global_position = pickup.global_position
		var previous_health := _player.health
		var previous_refills := _player.ammo_refills
		assert_true(pickup.collect_for_player(_player, 1))
		assert_true(
			_player.health > previous_health or _player.ammo_refills > previous_refills,
			"Collecting prop loot must heal or refill ammo, not just remove a mesh"
		)
		assert_false(pickup.collect_for_player(_player, 1))


func test_vase_breaks_once_and_drops_default_collectible_supplies() -> void:
	var marker := _marker(LootPropSpawner.PropType.VASE)
	marker.health_multiplier = 2.0
	var vase := marker.spawn_prop() as BreakableProp
	assert_not_null(vase)
	vase.wobble_on_damage = false
	vase.take_damage(30.0)
	assert_false(vase.is_destroyed)
	assert_eq(_pickups().size(), 0)
	vase.take_damage(25.0)
	vase.take_damage(100.0)
	assert_true(vase.is_destroyed)
	assert_false(vase.mesh_instance.visible)
	assert_true(vase.collision_shape.disabled)
	_collect_supplies(1)


func test_corpse_search_checks_range_and_loots_only_once() -> void:
	var pile := _marker(LootPropSpawner.PropType.CORPSE_PILE).spawn_prop() as CorpsePile
	_player.position = Vector3(20, 0, 0)
	pile.interact(_player)
	assert_true(pile.can_be_looted())
	assert_eq(_pickups().size(), 0)
	_player.position = Vector3.ZERO
	pile.interact(_player)
	pile.interact(_player)
	assert_false(pile.can_be_looted())
	assert_false(pile.interaction_label.visible)
	_collect_supplies(1)


func test_corpse_spawner_table_override_changes_real_drop_count() -> void:
	var marker := _marker(LootPropSpawner.PropType.CORPSE_PILE)
	marker.loot_table_override = "hidden_stash"
	var pile := marker.spawn_prop() as CorpsePile
	pile.interact(_player)
	_collect_supplies(2)


func test_stash_interaction_reveals_once_and_drops_after_delay() -> void:
	var stash := _marker(LootPropSpawner.PropType.HIDDEN_STASH).spawn_prop() as HiddenStash
	stash.reveal_trigger = HiddenStash.RevealTrigger.INTERACT
	stash.reveal_delay = 0.02
	stash.interact(_player)
	stash.interact(_player)
	assert_true(stash.is_revealed)
	assert_false(stash.is_looted)
	assert_eq(_pickups().size(), 0)
	await get_tree().create_timer(0.05).timeout
	assert_true(stash.is_looted)
	_collect_supplies(2)


func test_stash_damage_threshold_and_custom_trigger_cannot_bypass_each_other() -> void:
	var stash := _marker(LootPropSpawner.PropType.HIDDEN_STASH).spawn_prop() as HiddenStash
	stash.reveal_trigger = HiddenStash.RevealTrigger.DAMAGE
	stash.reveal_delay = 0.0
	stash.trigger_reveal(_player)
	stash.take_damage(-100.0)
	stash.take_damage(9.0)
	assert_false(stash.is_revealed)
	stash.take_damage(1.0, "generic", _player)
	stash.take_damage(100.0, "generic", _player)
	assert_true(stash.is_looted)
	_collect_supplies(2)


func test_stash_proximity_discovers_player_and_removal_cancels_delayed_loot() -> void:
	var marker := _marker(LootPropSpawner.PropType.HIDDEN_STASH)
	var stash := marker.spawn_prop() as HiddenStash
	stash.reveal_delay = 0.2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	shape.shape = sphere
	_player.add_child(shape)
	for frame in range(4):
		await get_tree().physics_frame
	assert_true(stash.is_revealed, "Actual proximity overlap should reveal the stash")
	marker.despawn_prop()
	await get_tree().create_timer(0.25).timeout
	assert_eq(_pickups().size(), 0, "Removing the owned prop must cancel its pending loot")


func test_weapon_rack_dispenses_configured_shotgun_once_and_collection_gives_shotgun_ammo() -> void:
	var marker := _marker(LootPropSpawner.PropType.WEAPON_RACK)
	marker.weapon_type = "shotgun"
	var rack := marker.spawn_prop()
	rack.interact(_player)
	rack.interact(_player)
	assert_false(rack.has_weapon)
	assert_false(rack.weapon_display.visible)
	var pickups := _pickups()
	assert_eq(pickups.size(), 1)
	if pickups.size() != 1:
		return
	_player.global_position = pickups[0].global_position
	assert_true(pickups[0].collect_for_player(_player, 1))
	assert_eq(_player.ammo_by_weapon.get(WeaponPickup.WeaponType.SHOTGUN, 0), 12)
	assert_false(_player.ammo_by_weapon.has(WeaponPickup.WeaponType.PISTOL))


func test_weapon_rack_rejects_distant_player_and_can_explicitly_restock() -> void:
	var rack := _marker(LootPropSpawner.PropType.WEAPON_RACK).spawn_prop()
	rack.respawn_enabled = true
	rack.respawn_time = 0.02
	_player.position = Vector3(20, 0, 0)
	rack.interact(_player)
	assert_true(rack.has_weapon)
	assert_eq(_pickups().size(), 0)
	_player.position = Vector3.ZERO
	rack.interact(_player)
	assert_false(rack.has_weapon)
	await get_tree().create_timer(0.05).timeout
	assert_true(rack.has_weapon)
	rack.interact(_player)
	assert_eq(_pickups().size(), 2)


func test_stash_line_of_sight_blocks_discovery_until_wall_is_removed() -> void:
	var stash := _marker(LootPropSpawner.PropType.HIDDEN_STASH).spawn_prop() as HiddenStash
	stash.reveal_trigger = HiddenStash.RevealTrigger.INTERACT
	stash.reveal_delay = 0.0
	_player.position = Vector3(1.0, 0, 0)
	var wall := StaticBody3D.new()
	wall.position = Vector3(0.5, 0.5, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.1, 1.0, 2.0)
	shape.shape = box
	wall.add_child(shape)
	_world.add_child(wall)
	await get_tree().physics_frame
	stash.interact(_player)
	assert_false(stash.is_revealed, "A nearby player behind a wall cannot discover the stash")
	wall.free()
	await get_tree().physics_frame
	stash.interact(_player)
	assert_true(stash.is_looted)
	_collect_supplies(2)


func test_client_side_prop_mutations_cannot_create_loot() -> void:
	var pile := _marker(LootPropSpawner.PropType.CORPSE_PILE).spawn_prop() as CorpsePile
	var stash := _marker(LootPropSpawner.PropType.HIDDEN_STASH).spawn_prop() as HiddenStash
	stash.reveal_trigger = HiddenStash.RevealTrigger.CUSTOM
	var rack := _marker(LootPropSpawner.PropType.WEAPON_RACK).spawn_prop()
	var client := ENetMultiplayerPeer.new()
	assert_eq(client.create_client("127.0.0.1", 9), OK)
	var api := SceneMultiplayer.new()
	api.multiplayer_peer = client
	get_tree().set_multiplayer(api, _world.get_path())
	assert_false(_world.multiplayer.is_server())
	pile._loot_pile(1)
	stash.trigger_reveal(_player)
	stash._spawn_loot(1)
	rack._take_weapon(1)
	assert_true(pile.can_be_looted())
	assert_false(stash.is_revealed)
	assert_false(stash.is_looted)
	assert_true(rack.has_weapon)
	assert_eq(_pickups().size(), 0)
	get_tree().set_multiplayer(null, _world.get_path())
	api.multiplayer_peer = null
	client.close()
