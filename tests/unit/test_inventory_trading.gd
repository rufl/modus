extends ModusGutTestBase

const EntityServiceScript = preload("res://game/scripts/features/gameplay/entity_service.gd")

var _roots: Array[Node] = []
var _apis: Array[SceneMultiplayer] = []
var _peers: Array[ENetMultiplayerPeer] = []
var _save_paths: Array[String] = []
var _manager: InventoryMgr
var _sender: Inventory
var _receiver: Inventory
var _receiver_node: Node3D
var _gameplay: GameplaySvc
var _previous_player_service: Node
var _previous_entities: Node
var _player_service: PlayerSvc
var _entities: Node
var _failures: Array[String] = []
var _given: Array[Dictionary] = []


func before_each() -> void:
	await modus_setup()
	_gameplay = GameManager.get_core_system("gameplay") as GameplaySvc
	_previous_player_service = _gameplay.player
	_previous_entities = GameManager.get_core_system("entities")
	_player_service = PlayerSvc.new()
	add_child(_player_service)
	_gameplay.player = _player_service
	_entities = EntityServiceScript.new()
	add_child(_entities)
	GameManager._core_systems["entities"] = _entities
	_manager = _add_manager()
	_sender = _register_inventory(1)
	_receiver = _register_inventory(2)
	_add_player(1)
	_receiver_node = _add_player(2)
	_manager.transfer_failed.connect(func(reason: String) -> void: _failures.append(reason))
	_manager.item_given.connect(
		func(from_peer: int, to_peer: int, item: InventoryItem) -> void:
			_given.append({"from": from_peer, "to": to_peer, "item": item.to_dict()})
	)


func after_each() -> void:
	_gameplay.player = _previous_player_service
	GameManager._core_systems["entities"] = _previous_entities
	_player_service.free()
	_entities.free()
	for root: Node in _roots:
		var root_path: NodePath = root.get_path()
		root.free()
		get_tree().set_multiplayer(null, root_path)
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
	_failures.clear()
	_given.clear()
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


func _register_inventory(peer_id: int) -> Inventory:
	var inventory := Inventory.new()
	_manager.register_inventory(peer_id, inventory)
	# Unique real profiles avoid loading or overwriting the user's host profile.
	var data: Dictionary = _player_service._create_default_data(peer_id)
	_player_service._player_data[peer_id] = data
	_save_paths.append(_player_service._get_save_path(data["uuid"]))
	return inventory


func _add_player(peer_id: int) -> Node3D:
	var player := Node3D.new()
	player.set_multiplayer_authority(peer_id)
	_manager.get_parent().add_child(player)
	player.add_to_group("player")
	return player


func _item(amount: int, id: String = "ore") -> InventoryItem:
	var item := InventoryItem.new()
	item.id = id
	item.current_stack = amount
	item.max_stack = 10
	return item


func _fill_receiver() -> void:
	for slot: int in Inventory.MAX_SLOTS:
		_receiver.slots[slot] = _item(10, "filler_%d" % slot)


func _wait_for_network(condition: Callable) -> bool:
	for attempt: int in range(200):
		if condition.call():
			return true
		await get_tree().create_timer(0.01).timeout
	return false


func _start_server() -> ENetMultiplayerPeer:
	var server := ENetMultiplayerPeer.new()
	_peers.append(server)
	assert_eq(server.create_server(0), OK)
	_manager.multiplayer.multiplayer_peer = server
	return server


func _connect_client(server: ENetMultiplayerPeer) -> InventoryMgr:
	var peer := ENetMultiplayerPeer.new()
	_peers.append(peer)
	var error: Error = peer.create_client("127.0.0.1", server.get_host().get_local_port())
	assert_eq(error, OK)
	if error != OK:
		return null
	var client: InventoryMgr = _add_manager(peer)
	var connected: bool = await _wait_for_network(
		func() -> bool:
			return (
				peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
				and _manager.multiplayer.get_peers().has(peer.get_unique_id())
			)
	)
	assert_true(connected, "Trading owners must connect over real ENet")
	return client if connected else null


func test_full_bag_accepts_all_sentinel_into_partial_stack_using_player_fallback() -> void:
	_sender.slots[7] = _item(3)
	_fill_receiver()
	_receiver.slots[0] = _item(7)
	assert_null(_entities.get_player(1), "The registry deliberately lacks the grouped players")
	_receiver_node.position.x = InventoryMgr.TRADE_DISTANCE

	_manager.give_item(2, 7)

	assert_null(_sender.slots[7])
	assert_eq(_receiver.count_item("ore"), 10)
	assert_eq(_receiver.get_empty_slot_count(), 0)
	assert_eq(_given.size(), 1)
	if _given.size() == 1:
		assert_eq(_given[0]["item"]["current_stack"], 3)
	assert_eq(_failures.size(), 0)


func test_rejected_capacity_keeps_exact_source_slot_and_both_inventory_snapshots() -> void:
	var source: InventoryItem = _item(4)
	_sender.slots[0] = _item(6)
	_sender.slots[7] = source
	_fill_receiver()
	_receiver.slots[0] = _item(9)
	var source_before: Dictionary = _sender.to_dict()
	var destination_before: Dictionary = _receiver.to_dict()
	var changes: Array[String] = []
	_sender.inventory_changed.connect(func() -> void: changes.append("sender"))
	_receiver.inventory_changed.connect(func() -> void: changes.append("receiver"))

	_manager.give_item(2, 7)

	assert_eq(_sender.to_dict(), source_before)
	assert_same(_sender.slots[7], source, "Rejection must not roll the stack into another slot")
	assert_eq(_receiver.to_dict(), destination_before)
	assert_eq(changes.size(), 0, "Rejected transfers must not publish intermediate mutations")
	assert_eq(_failures.size(), 1, "Offline failure is delivered locally, without self-RPC")
	assert_eq(_given.size(), 0)


func test_invalid_amounts_slots_self_and_distance_leave_both_inventories_unchanged() -> void:
	_sender.slots[7] = _item(8)
	var source_before: Dictionary = _sender.to_dict()
	var destination_before: Dictionary = _receiver.to_dict()
	for request: Array in [
		[2, 7, 0],
		[2, 7, -2],
		[2, 7, 9],
		[1, 7, 1],
		[2, -1, 1],
		[2, Inventory.MAX_SLOTS, 1],
		[2, 6, 1]
	]:
		var failures_before: int = _failures.size()
		_manager.give_item(request[0], request[1], request[2])
		assert_eq(_sender.to_dict(), source_before, str(request))
		assert_eq(_receiver.to_dict(), destination_before, str(request))
		assert_eq(_failures.size(), failures_before + 1)
	_receiver_node.position.x = InventoryMgr.TRADE_DISTANCE + 0.1
	_manager.give_item(2, 7, 1)
	_receiver_node.remove_from_group("player")
	_manager.give_item(2, 7, 1)
	assert_eq(_failures.size(), 9, "Distance and absent players also notify the local sender")
	assert_eq(_sender.to_dict(), source_before)
	assert_eq(_receiver.to_dict(), destination_before)
	assert_eq(_given.size(), 0)


func test_partial_merge_event_and_disk_profiles_preserve_actual_transfer_quantity() -> void:
	_sender.slots[7] = _item(8)
	_receiver.slots[0] = _item(8)

	_manager.give_item(2, 7, 6)

	assert_eq(_sender.slots[7].current_stack, 2)
	assert_eq(_receiver.slots[0].current_stack, 10)
	assert_eq(_receiver.slots[1].current_stack, 4)
	assert_eq(_given.size(), 1)
	if _given.size() == 1:
		assert_eq(_given[0]["from"], 1)
		assert_eq(_given[0]["to"], 2)
		assert_eq(_given[0]["item"]["current_stack"], 6, "Event is not the insertion remainder")
	for peer_id: int in [1, 2]:
		var data: Dictionary = _player_service.get_player_data(peer_id)
		var path: String = _player_service._get_save_path(data["uuid"])
		assert_true(FileAccess.file_exists(path), "A committed trade persists each real profile")
		if not FileAccess.file_exists(path):
			continue
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var restored := Inventory.new()
		restored.from_dict(saved["inventory"])
		assert_eq(restored.to_dict(), _manager.get_inventory(peer_id).to_dict())
		assert_eq(_player_service.get_inventory(peer_id).to_dict(), restored.to_dict())


func test_host_rejection_emits_locally_without_self_rpc() -> void:
	_start_server()
	_sender.slots[7] = _item(3)
	var before: Dictionary = _sender.to_dict()

	_manager.give_item(1, 7)

	assert_eq(_failures.size(), 1)
	assert_eq(_sender.to_dict(), before)
	assert_eq(_given.size(), 0)


func test_enet_trade_updates_both_owners_before_event_and_rejects_client_processing() -> void:
	var server: ENetMultiplayerPeer = _start_server()
	var sender_client: InventoryMgr = await _connect_client(server)
	var receiver_client: InventoryMgr = await _connect_client(server)
	if not sender_client or not receiver_client:
		return
	var sender_id: int = sender_client.multiplayer.get_unique_id()
	var receiver_id: int = receiver_client.multiplayer.get_unique_id()
	var authoritative_sender: Inventory = _register_inventory(sender_id)
	var authoritative_receiver: Inventory = _register_inventory(receiver_id)
	_add_player(sender_id)
	_add_player(receiver_id)
	authoritative_sender.slots[7] = _item(8)
	authoritative_receiver.slots[0] = _item(8)
	var sender_replica := Inventory.new()
	sender_replica.from_dict(authoritative_sender.to_dict())
	sender_client.register_inventory(sender_id, sender_replica)
	var receiver_replica := Inventory.new()
	receiver_replica.from_dict(authoritative_receiver.to_dict())
	receiver_client.register_inventory(receiver_id, receiver_replica)
	var received: Array[int] = []
	var event_snapshots: Array[Dictionary] = []
	receiver_client.item_received.connect(
		func(_from: int, item: InventoryItem) -> void:
			received.append(item.current_stack)
			event_snapshots.append(receiver_replica.to_dict())
	)
	var remote_failures: Array[String] = []
	sender_client.transfer_failed.connect(
		func(reason: String) -> void: remote_failures.append(reason)
	)
	# A client with both inventories cannot bypass authority through direct processing.
	var illicit_destination := Inventory.new()
	sender_client.register_inventory(receiver_id, illicit_destination)
	var sender_before: Dictionary = sender_replica.to_dict()
	var destination_before: Dictionary = illicit_destination.to_dict()
	sender_client._process_give_item(sender_id, receiver_id, 7, 6)
	assert_eq(sender_replica.to_dict(), sender_before)
	assert_eq(illicit_destination.to_dict(), destination_before)

	sender_client.give_item(receiver_id, 7, 6)
	var completed := func() -> bool:
		return sender_replica.count_item("ore") == 2 and received.size() == 1
	assert_true(await _wait_for_network(completed))
	assert_eq(sender_replica.to_dict(), authoritative_sender.to_dict())
	assert_eq(receiver_replica.to_dict(), authoritative_receiver.to_dict())
	assert_eq(authoritative_sender.count_item("ore"), 2)
	assert_eq(authoritative_receiver.count_item("ore"), 14)
	assert_eq(received, [6])
	assert_eq(event_snapshots, [authoritative_receiver.to_dict()])

	var committed_sender: Dictionary = authoritative_sender.to_dict()
	var committed_receiver: Dictionary = authoritative_receiver.to_dict()
	# Give requests are limited to five per second; test quantity rejection, not throttling.
	await get_tree().create_timer(0.21).timeout
	sender_client.give_item(receiver_id, 7, 3)
	assert_true(await _wait_for_network(func() -> bool: return remote_failures.size() == 1))
	assert_eq(authoritative_sender.to_dict(), committed_sender)
	assert_eq(authoritative_receiver.to_dict(), committed_receiver)
	assert_eq(sender_replica.to_dict(), committed_sender)
	assert_eq(receiver_replica.to_dict(), committed_receiver)
