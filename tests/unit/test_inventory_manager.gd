extends ModusGutTestBase

var _roots: Array[Node] = []
var _apis: Array[SceneMultiplayer] = []
var _peers: Array[ENetMultiplayerPeer] = []
var _manager: InventoryMgr
var _inventory: Inventory


func before_each() -> void:
	await modus_setup()
	_manager = _add_manager()
	_inventory = Inventory.new()
	_manager.register_inventory(1, _inventory)


func after_each() -> void:
	for root: Node in _roots:
		var root_path: NodePath = root.get_path()
		root.free()
		get_tree().set_multiplayer(null, root_path)
	for api: SceneMultiplayer in _apis:
		api.multiplayer_peer = null
	for peer: ENetMultiplayerPeer in _peers:
		peer.close()
	_roots.clear()
	_apis.clear()
	_peers.clear()
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


func _item(
	id: String, count: int = 1, max_stack: int = 1, equip_slot: String = ""
) -> InventoryItem:
	var item := InventoryItem.new()
	item.id = id
	item.current_stack = count
	item.max_stack = max_stack
	item.equip_slot = equip_slot
	return item


func _totals(inv: Inventory) -> Dictionary:
	var totals: Dictionary = {}
	for item: InventoryItem in inv.slots:
		if item:
			totals[item.id] = totals.get(item.id, 0) + item.current_stack
	for slot_name: String in Inventory.EQUIPMENT_SLOTS:
		var item: InventoryItem = inv.get_equipped(slot_name)
		if item:
			totals[item.id] = totals.get(item.id, 0) + item.current_stack
	return totals


func _wait_for_network(condition: Callable) -> bool:
	for attempt: int in range(200):
		if condition.call():
			return true
		await get_tree().create_timer(0.01).timeout
	return false


func _connect_client() -> InventoryMgr:
	var server := ENetMultiplayerPeer.new()
	_peers.append(server)
	var error: Error = server.create_server(0)
	assert_eq(error, OK)
	if error != OK:
		return null
	_manager.multiplayer.multiplayer_peer = server
	var client := ENetMultiplayerPeer.new()
	_peers.append(client)
	error = client.create_client("127.0.0.1", server.get_host().get_local_port())
	assert_eq(error, OK)
	if error != OK:
		return null
	var manager: InventoryMgr = _add_manager(client)
	var connected: bool = await _wait_for_network(
		func() -> bool:
			return (
				client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
				and _manager.multiplayer.get_peers().has(client.get_unique_id())
			)
	)
	assert_true(connected, "The inventory owner must connect over real ENet")
	return manager if connected else null


func test_move_rejects_invalid_slots_and_preserves_legal_swaps() -> void:
	var ore: InventoryItem = _item("ore", 8, 10)
	var tool: InventoryItem = _item("tool")
	_inventory.slots[0] = ore
	_inventory.slots[1] = tool
	var before: Dictionary = _inventory.to_dict()
	for operation: Array in [
		[-1, 1], [Inventory.MAX_SLOTS, 1], [0, -1], [0, Inventory.MAX_SLOTS], [2, 1], [0, 0]
	]:
		_manager.request_move_item(operation[0], operation[1])
		assert_eq(_inventory.to_dict(), before)
	_manager.request_move_item(0, 1)
	assert_same(_inventory.slots[0], tool)
	assert_same(_inventory.slots[1], ore)
	assert_eq(_totals(_inventory), {"ore": 8, "tool": 1})


func test_invalid_split_boundaries_preserve_entire_inventory() -> void:
	_inventory.slots[0] = _item("ore", 8, 10)
	_inventory.slots[1] = _item("ore", 4, 10)
	var before: Dictionary = _inventory.to_dict()
	# Distinct rejection boundaries: indices, aliasing, amount sign, whole stack, empty source.
	for operation: Array in [
		[-1, 1, 2],
		[Inventory.MAX_SLOTS, 1, 2],
		[0, -1, 2],
		[0, Inventory.MAX_SLOTS, 2],
		[0, 0, 2],
		[0, 1, 0],
		[0, 1, -1],
		[0, 1, 8],
		[2, 1, 2]
	]:
		_manager.request_split_stack(operation[0], operation[1], operation[2])
		assert_eq(
			_inventory.to_dict(), before, "Rejected split %s must preserve all items" % [operation]
		)


func test_split_and_partial_merge_keep_excess_in_source_even_when_full() -> void:
	_inventory.slots[0] = _item("ore", 8, 10)
	_manager.request_split_stack(0, 1, 3)
	assert_eq(_inventory.slots[0].current_stack, 5)
	assert_eq(_inventory.slots[1].current_stack, 3)
	assert_eq(_totals(_inventory), {"ore": 8})
	_inventory.slots[1].current_stack = 9
	for index: int in range(2, Inventory.MAX_SLOTS):
		_inventory.slots[index] = _item("filler")
	var before: Dictionary = _totals(_inventory)
	_manager.request_split_stack(0, 1, 4)
	assert_eq(_inventory.slots[0].current_stack, 4, "Only destination capacity leaves the source")
	assert_eq(_inventory.slots[1].current_stack, 10)
	assert_eq(_totals(_inventory), before)
	var full_snapshot: Dictionary = _inventory.to_dict()
	_manager.request_split_stack(0, 1, 2)
	assert_eq(_inventory.to_dict(), full_snapshot, "A full merge destination must remain bounded")


func test_incompatible_split_destination_keeps_legal_whole_slot_swap() -> void:
	var ore: InventoryItem = _item("ore", 8, 10)
	var tool: InventoryItem = _item("tool")
	_inventory.slots[0] = ore
	_inventory.slots[1] = tool
	_manager.request_split_stack(0, 1, 3)
	assert_same(_inventory.slots[0], tool)
	assert_same(_inventory.slots[1], ore)
	assert_eq(_totals(_inventory), {"ore": 8, "tool": 1})


func test_invalid_equipment_operations_preserve_bag_and_equipment() -> void:
	_inventory.slots[0] = _item("helmet", 1, 1, "head")
	_inventory.slots[1] = _item("boots", 1, 1, "feet")
	_inventory.equipment["head"] = _item("old_helmet", 1, 1, "head")
	var before: Dictionary = _inventory.to_dict()
	_manager.request_equip_item(0, "feet")
	assert_eq(_inventory.to_dict(), before, "An incompatible equip cannot erase its source")
	_manager.request_equip_item(0, "unknown")
	_manager.request_equip_item(-1, "head")
	_manager.request_equip_item(Inventory.MAX_SLOTS, "head")
	assert_eq(_inventory.to_dict(), before, "Invalid equip indices and names cannot mutate items")
	_manager.request_unequip_item("head", 1)
	assert_eq(_inventory.to_dict(), before, "An incompatible displaced item must not be discarded")
	_manager.request_unequip_item("head", -1)
	_manager.request_unequip_item("head", Inventory.MAX_SLOTS)
	_manager.request_unequip_item("unknown", 0)
	assert_eq(_inventory.to_dict(), before, "Invalid unequip destinations cannot remove equipment")


func test_equipment_swaps_publish_completed_conserved_state() -> void:
	var helmet: InventoryItem = _item("helmet", 1, 1, "head")
	var old_helmet: InventoryItem = _item("old_helmet", 1, 1, "head")
	_inventory.slots[0] = helmet
	_inventory.equipment["head"] = old_helmet
	var expected: Dictionary = _totals(_inventory)
	var observed: Array[Dictionary] = []
	_inventory.inventory_changed.connect(func() -> void: observed.append(_totals(_inventory)))
	_manager.request_equip_item(0, "head")
	assert_same(_inventory.slots[0], old_helmet)
	assert_same(_inventory.get_equipped("head"), helmet)
	_manager.request_unequip_item("head", 0)
	assert_same(_inventory.slots[0], helmet)
	assert_same(_inventory.get_equipped("head"), old_helmet)
	_manager.request_unequip_item("head", 1)
	assert_null(_inventory.get_equipped("head"))
	assert_same(_inventory.slots[1], old_helmet)
	assert_eq(_totals(_inventory), expected)
	assert_eq(
		observed,
		[expected, expected, expected],
		"Each completed equipment transfer must notify the UI with conserved state"
	)
	# Empty equip_slot remains compatible with any legal equipment slot.
	_inventory.slots[2] = _item("unrestricted")
	_manager.request_equip_item(2, "head")
	assert_null(_inventory.slots[2])
	assert_eq(_inventory.get_equipped("head").id, "unrestricted")


func test_host_requests_move_once_without_replacing_item_resources() -> void:
	var server := ENetMultiplayerPeer.new()
	_peers.append(server)
	assert_eq(server.create_server(0), OK)
	_manager.multiplayer.multiplayer_peer = server
	var ore: InventoryItem = _item("ore", 8, 10)
	_inventory.slots[0] = ore
	_manager.request_move_item(0, 1)
	assert_null(_inventory.slots[0])
	assert_same(_inventory.slots[1], ore, "Host sync must not deserialize its own inventory")
	_manager.request_split_stack(1, 2, 3)
	assert_same(_inventory.slots[1], ore)
	assert_eq(_inventory.slots[1].current_stack, 5)
	_manager.request_equip_item(1, "head")
	assert_same(_inventory.get_equipped("head"), ore)
	_manager.request_unequip_item("head", 3)
	assert_same(_inventory.slots[3], ore)
	assert_null(_inventory.get_equipped("head"))
	assert_eq(_totals(_inventory), {"ore": 8})


func test_enet_owner_receives_moves_splits_equipment_and_rejection_correction() -> void:
	var client: InventoryMgr = await _connect_client()
	if not client:
		return
	var owner_id: int = client.multiplayer.get_unique_id()
	var authoritative := Inventory.new()
	authoritative.slots[0] = _item("ore", 8, 10)
	authoritative.slots[2] = _item("helmet", 1, 1, "head")
	authoritative.equipment["head"] = _item("old_helmet", 1, 1, "head")
	_manager.register_inventory(owner_id, authoritative)
	var replica := Inventory.new()
	replica.from_dict(authoritative.to_dict())
	client.register_inventory(owner_id, replica)
	var expected: Dictionary = _totals(authoritative)
	var host_before: Dictionary = _inventory.to_dict()

	client.request_move_item(0, 1)
	assert_true(
		await _wait_for_network(
			func() -> bool: return replica.slots[0] == null and replica.slots[1] != null
		)
	)
	assert_eq(replica.to_dict(), authoritative.to_dict())
	client.request_split_stack(1, 3, 3)
	assert_true(await _wait_for_network(func() -> bool: return replica.slots[3] != null))
	assert_eq(replica.slots[1].current_stack, 5)
	assert_eq(replica.slots[3].current_stack, 3)
	assert_eq(replica.to_dict(), authoritative.to_dict())
	client.request_equip_item(2, "head")
	assert_true(
		await _wait_for_network(func() -> bool: return replica.get_equipped("head").id == "helmet")
	)
	assert_eq(replica.slots[2].id, "old_helmet")
	assert_eq(replica.to_dict(), authoritative.to_dict())
	await get_tree().create_timer(0.11).timeout
	client.request_unequip_item("head", 2)
	assert_true(
		await _wait_for_network(
			func() -> bool: return replica.get_equipped("head").id == "old_helmet"
		)
	)
	assert_eq(replica.slots[2].id, "helmet")
	assert_eq(replica.to_dict(), authoritative.to_dict())
	await get_tree().create_timer(0.11).timeout
	client.request_unequip_item("head", 4)
	assert_true(
		await _wait_for_network(func() -> bool: return replica.get_equipped("head") == null)
	)
	assert_eq(replica.slots[4].id, "old_helmet")
	assert_eq(_totals(replica), expected)
	assert_eq(_totals(authoritative), expected)

	var before_rejection: Dictionary = authoritative.to_dict()
	replica.slots[2] = null  # Deliberately stale owner state must be corrected on rejection.
	client.request_equip_item(2, "feet")
	assert_true(
		await _wait_for_network(func() -> bool: return replica.to_dict() == before_rejection)
	)
	assert_eq(authoritative.to_dict(), before_rejection)
	assert_eq(
		_inventory.to_dict(), host_before, "A client request must only affect its own inventory"
	)


func test_client_rejects_server_only_requests_and_direct_process_calls() -> void:
	var client: InventoryMgr = await _connect_client()
	if not client:
		return
	var foreign := Inventory.new()
	foreign.slots[0] = _item("ore", 8, 10)
	foreign.slots[2] = _item("helmet", 1, 1, "head")
	foreign.equipment["head"] = _item("old_helmet", 1, 1, "head")
	client.register_inventory(1, foreign)
	var before: Dictionary = foreign.to_dict()
	client._process_move_item(1, 0, 1)
	client._process_split_stack(1, 0, 1, 2)
	client._process_equip_item(1, 2, "head")
	client._process_unequip_item(1, "head", 3)
	assert_eq(foreign.to_dict(), before, "Client process calls cannot mutate server-owned bags")

	var owner_id: int = client.multiplayer.get_unique_id()
	var owner := Inventory.new()
	_manager.register_inventory(owner_id, owner)
	var replica := Inventory.new()
	client.register_inventory(owner_id, replica)
	# The remote sender is 1; without server gates these any_peer handlers mutate foreign.
	_manager._request_move_item.rpc_id(owner_id, 0, 1)
	_manager._request_split_stack.rpc_id(owner_id, 0, 4, 2)
	_manager._request_equip_item.rpc_id(owner_id, 2, "head")
	_manager._request_unequip_item.rpc_id(owner_id, "head", 3)
	# A later reliable message on the same route proves preceding requests were delivered.
	owner.slots[0] = _item("delivery_marker")
	_manager._sync_inventory_owner(owner_id, owner)
	assert_true(await _wait_for_network(func() -> bool: return replica.slots[0] != null))
	assert_eq(foreign.to_dict(), before, "RPC requests received by a client must never mutate bags")
