extends ModusGutTestBase


class Collector:
	extends CharacterBody3D
	var inventory: Inventory = Inventory.new()


var _roots: Array[Node3D] = []
var _apis: Array[SceneMultiplayer] = []
var _peers: Array[ENetMultiplayerPeer] = []
var _save_paths: Array[String] = []
var _previous_scene: Node
var _gameplay: GameplaySvc
var _previous_manager: Node
var _previous_loot: Node
var _previous_player: Node
var _world: Node3D
var _manager: InventoryMgr
var _loot: LootSvc
var _profiles: PlayerSvc
var _host: Collector


func before_each() -> void:
	await modus_setup()
	_previous_scene = get_tree().current_scene
	_gameplay = GameManager.get_core_system("gameplay") as GameplaySvc
	_previous_manager = _gameplay.inventory
	_previous_loot = _gameplay.loot
	_previous_player = _gameplay.player
	_world = _add_world()
	get_tree().current_scene = _world
	_manager = _world.get_node("Inventory")
	_gameplay.inventory = _manager
	_loot = LootSvc.new()
	_loot.spawn_beacons = false
	_world.add_child(_loot)
	_gameplay.loot = _loot
	_profiles = PlayerSvc.new()
	add_child(_profiles)
	_gameplay.player = _profiles
	_host = _add_player(_world, 1)
	_profile(1)


func after_each() -> void:
	get_tree().current_scene = _previous_scene
	_gameplay.inventory = _previous_manager
	_gameplay.loot = _previous_loot
	_profiles.free()
	_gameplay.player = _previous_player
	for api: SceneMultiplayer in _apis:
		api.multiplayer_peer = null
	for peer: ENetMultiplayerPeer in _peers:
		peer.close()
	for world: Node3D in _roots:
		var path := world.get_path()
		world.free()
		get_tree().set_multiplayer(null, path)
	for path: String in _save_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_roots.clear()
	_apis.clear()
	_peers.clear()
	_save_paths.clear()
	modus_teardown()


func _add_world(peer: ENetMultiplayerPeer = null) -> Node3D:
	var world := Node3D.new()
	world.position = Vector3(10, 0, 20)
	get_tree().root.add_child(world)
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, world.get_path())
	if peer:
		api.multiplayer_peer = peer
	_roots.append(world)
	_apis.append(api)
	var manager := InventoryMgr.new()
	manager.name = "Inventory"
	world.add_child(manager)
	var spawner := MultiplayerSpawner.new()
	spawner.name = "Spawner"
	spawner.spawn_path = NodePath("..")
	spawner.add_spawnable_scene(LootSvc.PICKUP_SCENE_PATH)
	world.add_child(spawner)
	spawner.spawned.connect(func(node: Node): node.freeze = true)
	return world


func _add_player(world: Node3D, peer_id: int) -> Collector:
	var player := Collector.new()
	player.name = "Player_%d" % peer_id
	player.set_multiplayer_authority(peer_id)
	world.add_child(player)
	player.add_to_group("player")
	(world.get_node("Inventory") as InventoryMgr).register_inventory(peer_id, player.inventory)
	return player


func _profile(peer_id: int) -> void:
	var data: Dictionary = _profiles._create_default_data(peer_id)
	_profiles._player_data[peer_id] = data
	_save_paths.append(_profiles._get_save_path(data.uuid))


func _assert_saved(peer_id: int, inventory: Inventory) -> void:
	var data: Dictionary = _profiles.get_player_data(peer_id)
	var saved: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(_profiles._get_save_path(data.uuid))
	)
	var restored := Inventory.new()
	restored.from_dict(saved.inventory)
	assert_eq(restored.to_dict(), inventory.to_dict())


func _item() -> InventoryItem:
	var item := InventoryItem.new()
	item.id = "owned_tonic"
	item.display_name = "Owned Tonic"
	item.description = "A preserved stack"
	item.item_type = InventoryItem.ItemType.CONSUMABLE
	item.effect_type = "heal"
	item.effect_value = 12.5
	item.rarity = ItemRarity.Tier.EPIC
	item.value = 73
	item.max_stack = 10
	item.current_stack = 3
	return item


func _pickups(world: Node3D) -> Array[PickupBase]:
	var result: Array[PickupBase] = []
	for child: Node in world.get_children():
		if child is PickupBase and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _wait_for_network(condition: Callable) -> bool:
	for attempt in 200:
		if condition.call():
			return true
		await get_tree().create_timer(0.01).timeout
	return false


func test_host_drop_and_recollection_preserve_complete_stack_and_disk_state() -> void:
	var item := _item()
	var expected := item.to_dict()
	_host.inventory.slots[0] = item
	var position := _host.global_position + Vector3(2, 1, 0)
	_manager.drop_item_for_player(1, 0, position)
	assert_null(_host.inventory.get_item_at(0))
	_assert_saved(1, _host.inventory)
	var drops := _pickups(_world)
	assert_eq(drops.size(), 1)
	if drops.size() != 1:
		return
	var pickup := drops[0]
	pickup.freeze = true
	assert_eq(pickup.global_position, position)
	assert_eq(pickup.item_data, expected)
	assert_eq(pickup.rarity.tier, ItemRarity.Tier.EPIC)
	assert_eq(pickup.pickup_name, item.display_name)
	assert_eq(pickup.owner_peer_id, 1)
	assert_eq(_loot.get_stats().active_pickups, 1)
	assert_true(pickup.collect_for_player(_host, 1))
	assert_false(pickup.collect_for_player(_host, 1))
	assert_eq(_host.inventory.get_item_at(0).to_dict(), expected)
	_assert_saved(1, _host.inventory)
	await get_tree().process_frame
	assert_eq(_loot.get_stats().active_pickups, 0)


func test_invalid_or_unavailable_drop_preserves_source_inventory() -> void:
	var item := _item()
	_host.inventory.slots[0] = item
	for position: Vector3 in [Vector3(NAN, 0, 0), Vector3(INF, 0, 0), Vector3(900, 0, 0)]:
		_manager.drop_item_for_player(1, 0, position)
		assert_same(_host.inventory.get_item_at(0), item)
	_manager.drop_item_for_player(9999, 0, _host.global_position)
	_manager.drop_item_for_player(1, -1, _host.global_position)
	get_tree().current_scene = null
	_manager.drop_item_for_player(1, 0, _host.global_position)
	get_tree().current_scene = _world
	assert_same(_host.inventory.get_item_at(0), item)
	assert_eq(item.current_stack, 3)
	assert_eq(_pickups(_world).size(), 0)


func test_enet_drop_spawns_once_for_late_joiners_and_only_owner_can_collect() -> void:
	var server := ENetMultiplayerPeer.new()
	_peers.append(server)
	assert_eq(server.create_server(0), OK)
	_world.multiplayer.multiplayer_peer = server
	var client := ENetMultiplayerPeer.new()
	_peers.append(client)
	assert_eq(client.create_client("127.0.0.1", server.get_host().get_local_port()), OK)
	var client_world := _add_world(client)
	var connected := func() -> bool:
		return (
			client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
			and _world.multiplayer.get_peers().has(client.get_unique_id())
		)
	assert_true(await _wait_for_network(connected))
	var owner_id := client.get_unique_id()
	var source := _add_player(_world, owner_id)
	var replica := _add_player(client_world, owner_id)
	_profile(owner_id)
	var item := _item()
	var expected := item.to_dict()
	source.inventory.slots[0] = item
	replica.inventory.from_dict(source.inventory.to_dict())
	var client_manager := client_world.get_node("Inventory") as InventoryMgr
	client_manager._process_drop_for_player(owner_id, 1, 0, source.global_position)
	assert_eq(replica.inventory.count_item(item.id), 3)
	client_manager.drop_item_for_player(1, 0, source.global_position + Vector3(2, 1, 0))
	var dropped := func() -> bool:
		return _pickups(client_world).size() == 1 and replica.inventory.count_item(item.id) == 0
	assert_true(await _wait_for_network(dropped))
	assert_eq(_pickups(_world).size(), 1)
	if _pickups(_world).is_empty() or _pickups(client_world).is_empty():
		return
	var pickup := _pickups(_world)[0]
	pickup.freeze = true
	assert_eq(source.inventory.count_item(item.id), 0)
	_assert_saved(owner_id, source.inventory)
	var client_pickup := _pickups(client_world)[0]
	assert_eq(client_pickup.item_data, expected)
	assert_eq(client_pickup.owner_peer_id, 1)
	assert_false(client_pickup.visible)
	client_pickup.rpc_id(1, "_request_pickup", NodePath("../Player_%d" % owner_id))
	client_manager.request_move_item(0, 1)
	# A late join exercises current authoritative spawn state, not an old broadcast RPC.
	var late := ENetMultiplayerPeer.new()
	_peers.append(late)
	assert_eq(late.create_client("127.0.0.1", server.get_host().get_local_port()), OK)
	var late_world := _add_world(late)
	assert_true(await _wait_for_network(func() -> bool: return _pickups(late_world).size() == 1))
	assert_eq(_pickups(late_world)[0].item_data, expected)
	assert_false(pickup.collected)
	assert_eq(source.inventory.count_item(item.id), 0)
	for slot: int in range(Inventory.MAX_SLOTS):
		var filler := _item()
		filler.id = "filler_%d" % slot
		_host.inventory.slots[slot] = filler
	assert_false(pickup.collect_for_player(_host, 1))
	assert_eq(pickup.item_data, expected)
	_host.inventory.remove_item_at(0)
	assert_true(pickup.collect_for_player(_host, 1))
	assert_eq(_host.inventory.get_item_at(0).to_dict(), expected)
	_assert_saved(1, _host.inventory)
	var collected := func() -> bool:
		return _pickups(client_world).is_empty() and _pickups(late_world).is_empty()
	assert_true(await _wait_for_network(collected))
	assert_eq(_loot.get_stats().active_pickups, 0)


func test_owned_drop_supports_plain_node_world_roots() -> void:
	var world := Node.new()
	get_tree().root.add_child(world)
	_host.inventory.slots[0] = _item()
	get_tree().current_scene = world
	_manager.drop_item_for_player(1, 0, _host.global_position)
	assert_null(_host.inventory.get_item_at(0))
	assert_eq(world.get_child_count(), 1)
	if world.get_child_count() == 1:
		var pickup := world.get_child(0) as PickupBase
		assert_true(pickup.collect_for_player(_host, 1))
		assert_eq(_host.inventory.count_item("owned_tonic"), 3)
	get_tree().current_scene = _world
	world.free()


func test_saved_world_drop_restores_owner_and_complete_stack() -> void:
	var item := _item()
	var expected := item.to_dict()
	_host.inventory.slots[0] = item
	_manager.drop_item_for_player(1, 0, _host.global_position + Vector3(2, 1, 0))
	var state := GameManager.get_core_system("state_manager")
	var saved: Array = JSON.parse_string(JSON.stringify(state._serialize_items()))
	await state._deserialize_items(saved)
	var drops := _pickups(_world)
	assert_eq(drops.size(), 1)
	if drops.size() != 1:
		return
	assert_eq(drops[0].owner_peer_id, 1)
	assert_eq(drops[0].rarity_tier, ItemRarity.Tier.EPIC)
	assert_true(drops[0].collect_for_player(_host, 1))
	assert_eq(_host.inventory.get_item_at(0).to_dict(), expected)
	_assert_saved(1, _host.inventory)
