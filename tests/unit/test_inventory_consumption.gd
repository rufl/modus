extends ModusGutTestBase


class Collector:
	extends CharacterBody3D
	var inventory: Inventory
	var health_component: HealthComponent


class LegacyCollector:
	extends CharacterBody3D
	var health: float = 40.25
	var max_health: float = 100.0
	var armor: float = 1.5
	var max_armor: float = 50.0


class EffectObserver:
	extends Node
	var heals: Array[float] = []

	func spawn_heal_effect(_position: Vector3, amount: float) -> void:
		heals.append(amount)


var _roots: Array[Node] = []
var _apis: Array[SceneMultiplayer] = []
var _peers: Array[ENetMultiplayerPeer] = []
var _save_paths: Array[String] = []
var _manager: InventoryMgr
var _inventory: Inventory
var _player: Collector
var _service: PlayerSvc
var _previous_service: Node
var _gameplay: GameplaySvc
var _previous_effects: Node
var _effects: EffectObserver
var _consumed: Array[int] = []
var _failures: Array[String] = []


func before_each() -> void:
	await modus_setup()
	_gameplay = GameManager.get_core_system("gameplay") as GameplaySvc
	_previous_service = _gameplay.player
	_service = PlayerSvc.new()
	add_child(_service)
	_gameplay.player = _service
	_previous_effects = _gameplay.effects
	_effects = EffectObserver.new()
	add_child(_effects)
	_gameplay.effects = _effects
	_manager = _add_manager()
	_inventory = Inventory.new()
	_manager.register_inventory(1, _inventory)
	_profile(1)
	_player = _add_player(_manager, 1)
	_player.inventory = _inventory
	_player.health_component.current_health = 40.0
	_manager.item_consumed.connect(
		func(_id: int, item: InventoryItem): _consumed.append(item.current_stack)
	)
	_manager.transfer_failed.connect(func(reason: String): _failures.append(reason))


func after_each() -> void:
	_gameplay.player = _previous_service
	_service.free()
	_gameplay.effects = _previous_effects
	_effects.free()
	for root: Node in _roots:
		var path := root.get_path()
		root.free()
		get_tree().set_multiplayer(null, path)
	for api: SceneMultiplayer in _apis:
		api.multiplayer_peer = null
	for peer: ENetMultiplayerPeer in _peers:
		peer.close()
	for path: String in _save_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_roots.clear()
	_apis.clear()
	_peers.clear()
	_save_paths.clear()
	_consumed.clear()
	_failures.clear()
	modus_teardown()


func _add_manager(peer: ENetMultiplayerPeer = null) -> InventoryMgr:
	var root := Node.new()
	add_child(root)
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, root.get_path())
	if peer:
		api.multiplayer_peer = peer
	_roots.append(root)
	_apis.append(api)
	var manager := InventoryMgr.new()
	manager.name = "Inventory"
	root.add_child(manager)
	return manager


func _add_player(manager: InventoryMgr, owner_id: int) -> Collector:
	var player := Collector.new()
	player.name = "Player"
	manager.get_parent().add_child(player)
	player.add_to_group("player")
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	player.add_child(health)
	player.health_component = health
	player.set_multiplayer_authority(owner_id)
	return player


func _profile(peer_id: int) -> void:
	var data: Dictionary = _service._create_default_data(peer_id)
	_service._player_data[peer_id] = data
	_save_paths.append(_service._get_save_path(data.uuid))


func _item(effect: String = "heal", value: float = 25.0, count: int = 3) -> InventoryItem:
	var item := InventoryItem.new()
	item.id = "consumable"
	item.item_type = InventoryItem.ItemType.CONSUMABLE
	item.effect_type = effect
	item.effect_value = value
	item.max_stack = 10
	item.current_stack = count
	return item


func _assert_persisted(peer_id: int, inventory: Inventory) -> void:
	var data: Dictionary = _service.get_player_data(peer_id)
	var saved: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(_service._get_save_path(data.uuid))
	)
	var restored := Inventory.new()
	restored.from_dict(saved.inventory)
	assert_eq(restored.to_dict(), inventory.to_dict())


func _wait_for_network(condition: Callable) -> bool:
	for attempt in 200:
		if condition.call():
			return true
		await get_tree().create_timer(0.01).timeout
	return false


func test_healing_consumes_one_and_persists_before_notification() -> void:
	_inventory.slots[0] = _item()
	var observed: Array[int] = []
	_manager.item_consumed.connect(
		func(_id, _item): observed.append(_service.get_inventory(1).count_item("consumable"))
	)
	_manager.use_consumable(0)
	assert_eq(_player.health_component.current_health, 65.0)
	assert_eq(_inventory.slots[0].current_stack, 2)
	assert_eq(_consumed, [1])
	assert_eq(observed, [2])
	_assert_persisted(1, _inventory)


func test_unsupported_invalid_and_ineffective_items_are_preserved() -> void:
	for item: InventoryItem in [
		_item("unknown_effect"),
		_item("heal", 0),
		_item("heal", -5),
		_item("armor", NAN),
		_item("armor", INF)
	]:
		_inventory.slots[0] = item
		_manager.use_consumable(0)
		assert_same(_inventory.slots[0], item)
		assert_eq(item.current_stack, 3)
	assert_eq(_player.health_component.current_health, 40.0)
	assert_eq(_player.health_component.current_armor, 0.0)
	_inventory.slots[0] = _item()
	_player.health_component.current_health = _player.health_component.max_health
	_manager.use_consumable(0)
	assert_eq(_inventory.slots[0].current_stack, 3)
	_player.health_component.die(-1)
	_player.health_component.current_health = 0.0
	_manager.use_consumable(0)
	assert_eq(_inventory.slots[0].current_stack, 3)
	assert_eq(_player.health_component.current_health, 0.0)
	assert_eq(_consumed.size(), 0)
	assert_eq(_failures.size(), 7)


func test_armor_consumes_last_item_but_preserves_it_at_capacity() -> void:
	_inventory.slots[0] = _item("armor", 25.0, 1)
	_player.health_component.current_armor = 190.0
	_manager.use_consumable(0)
	assert_eq(_player.health_component.current_armor, 200.0)
	assert_null(_inventory.slots[0])
	assert_eq(_consumed, [1])
	_inventory.slots[0] = _item("armor", 25.0, 1)
	_manager.use_consumable(0)
	assert_eq(_inventory.slots[0].current_stack, 1)
	assert_eq(_consumed, [1])
	_player.health_component.current_armor = 225.0
	_manager.use_consumable(0)
	assert_eq(_player.health_component.current_armor, 225.0)
	assert_eq(_inventory.slots[0].current_stack, 1)


func test_legacy_player_effects_preserve_fractional_values() -> void:
	_player.remove_from_group("player")
	var legacy := LegacyCollector.new()
	_manager.get_parent().add_child(legacy)
	legacy.add_to_group("player")
	_inventory.slots[0] = _item("heal", 0.5)
	_inventory.slots[1] = _item("armor", 0.75)
	_manager.use_consumable(0)
	_manager.use_consumable(1)
	assert_eq(legacy.health, 40.75)
	assert_eq(legacy.armor, 2.25)
	assert_eq(_inventory.slots[0].current_stack, 2)
	assert_eq(_inventory.slots[1].current_stack, 2)


func test_host_clear_persists_bag_and_equipment_once() -> void:
	_inventory.slots[0] = _item()
	_inventory.equipment.head = _item()
	var changes := [0]
	_inventory.inventory_changed.connect(func(): changes[0] += 1)
	_manager.clear_inventory(1)
	assert_eq(_inventory.count_item("consumable"), 0)
	assert_null(_inventory.get_equipped("head"))
	assert_eq(changes[0], 1)
	_assert_persisted(1, _inventory)


func test_enet_consumption_and_clear_update_owner_before_events() -> void:
	var server := ENetMultiplayerPeer.new()
	_peers.append(server)
	assert_eq(server.create_server(0), OK)
	_manager.multiplayer.multiplayer_peer = server
	var client := ENetMultiplayerPeer.new()
	_peers.append(client)
	assert_eq(client.create_client("127.0.0.1", server.get_host().get_local_port()), OK)
	var client_manager := _add_manager(client)
	var connected := func() -> bool:
		return (
			client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
			and _manager.multiplayer.get_peers().has(client.get_unique_id())
		)
	assert_true(await _wait_for_network(connected))
	var owner_id := client.get_unique_id()
	_manager.unregister_inventory(1, _inventory)
	_manager.register_inventory(owner_id, _inventory)
	_profile(owner_id)
	_player.set_multiplayer_authority(owner_id)
	_inventory.slots[0] = _item()
	_inventory.equipment.head = _item()
	var replica := Inventory.new()
	replica.from_dict(_inventory.to_dict())
	client_manager.register_inventory(owner_id, replica)
	var client_player := _add_player(client_manager, owner_id)
	client_player.inventory = replica
	client_player.health_component.current_health = 40.0
	var received: Array[int] = []
	var seen: Array[int] = []
	client_manager.item_consumed.connect(
		func(_id, item):
			received.append(item.current_stack)
			seen.append(replica.count_item("consumable"))
	)
	client_manager._process_use_consumable(owner_id, 0)
	client_manager.clear_inventory(owner_id)
	assert_eq(replica.count_item("consumable"), 3)
	assert_eq(client_player.health_component.current_health, 40.0)
	client_manager.use_consumable(0)
	assert_true(await _wait_for_network(func() -> bool: return received.size() == 1))
	assert_eq(received, [1])
	assert_eq(seen, [2])
	assert_eq(replica.to_dict(), _inventory.to_dict())
	assert_eq(client_player.health_component.current_health, 65.0)
	_assert_persisted(owner_id, _inventory)
	assert_eq(_effects.heals, [25.0, 25.0], "The server and owner receive the legitimate effect")
	client_player.health_component.rpc_id(1, "_sync_heal_visual", Vector3.ZERO, 999.0)
	client_manager.request_move_item(0, 1)
	var moved := func() -> bool:
		return replica.get_item_at(0) == null and replica.get_item_at(1) != null
	assert_true(await _wait_for_network(moved))
	assert_eq(_effects.heals, [25.0, 25.0], "Client-forged healing visuals are rejected")
	_manager.clear_inventory(owner_id)
	var cleared := func() -> bool:
		return replica.count_item("consumable") == 0 and replica.get_equipped("head") == null
	assert_true(await _wait_for_network(cleared))
	assert_eq(replica.to_dict(), _inventory.to_dict())
	_assert_persisted(owner_id, _inventory)


func test_consumable_buffs_apply_before_removal_and_preserve_dead_players_items() -> void:
	var effects := StatusEffectManager.new()
	effects.name = "StatusEffectManager"
	_player.add_child(effects)
	_inventory.slots[0] = _item("buff_speed", 2.0)
	_inventory.slots[1] = _item("buff_damage", 3.0)
	_manager.use_consumable(0)
	_manager.use_consumable(1)
	effects.set_process(false)
	assert_eq(effects.get_movement_modifier(), 1.5)
	assert_eq(effects.get_damage_modifier(), 1.25)
	assert_eq(_inventory.slots[0].current_stack, 2)
	assert_eq(_inventory.slots[1].current_stack, 2)
	assert_eq(_consumed, [1, 1])
	_assert_persisted(1, _inventory)
	effects._process(2.0)
	assert_eq(effects.get_movement_modifier(), 1.0)
	assert_eq(effects.get_damage_modifier(), 1.25)
	_player.health_component.die(-1)
	_manager.use_consumable(0)
	assert_eq(_inventory.slots[0].current_stack, 2)
	assert_eq(effects.get_damage_modifier(), 1.0)
	assert_eq(_consumed, [1, 1])
