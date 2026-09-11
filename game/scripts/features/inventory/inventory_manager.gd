class_name InventoryMgr
extends Node

signal item_given(from_peer: int, to_peer: int, item: InventoryItem)
signal item_received(from_peer: int, item: InventoryItem)
signal transfer_failed(reason: String)
signal item_consumed(peer_id: int, item: InventoryItem)

const TRADE_DISTANCE: float = 5.0  # Max distance for item trading

var _inventories: Dictionary = {}


static func get_instance() -> InventoryMgr:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return null
	var manager: Node = tree.root.get_node_or_null("GameManager")
	if not manager or not manager.has_method("get_core_system"):
		return null
	var gs := manager.get_core_system("gameplay") as GameplaySvc
	return gs.inventory as InventoryMgr if gs else null


## Inventory Manager - Handles multiplayer item transfers
##
## Server-authoritative item transfers between players.

# Service preloads to resolve lints

## Player inventories (peer_id -> Inventory)


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _exit_tree() -> void:
	# === SIGNAL HYGIENE ===
	if multiplayer and multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)


## Register inventory for a player


func register_inventory(peer_id: int, inventory: Inventory) -> void:
	_inventories[peer_id] = inventory
	inventory.owner_peer_id = peer_id


func unregister_inventory(peer_id: int, inventory: Inventory) -> void:
	if _inventories.get(peer_id) == inventory:
		_inventories.erase(peer_id)


## Get player's inventory


func get_inventory(peer_id: int) -> Inventory:
	return _inventories.get(peer_id)


func _validate_inventory_rpc(sender_id: int, method: String, args: Array) -> bool:
	if not multiplayer.is_server() or sender_id <= 0:
		return false
	var network_svc := GameManager.get_core_system("network") as NetworkSvc
	return (
		not network_svc
		or not network_svc.network_manager
		or network_svc.network_manager.validate_rpc(sender_id, method, args)
	)


## Give item to another player (client request)


func give_item(to_peer_id: int, from_slot: int, amount: int = -1) -> void:
	var my_id: int = multiplayer.get_unique_id()

	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_process_give_item(my_id, to_peer_id, from_slot, amount)
	else:
		_request_give_item.rpc_id(1, to_peer_id, from_slot, amount)


## Server RPC to process give request

@rpc("any_peer", "reliable")
func _request_give_item(to_peer_id: int, from_slot: int, amount: int) -> void:
	var from_peer_id: int = multiplayer.get_remote_sender_id()
	if not _validate_inventory_rpc(from_peer_id, "give_item", [amount]):
		return
	_process_give_item(from_peer_id, to_peer_id, from_slot, amount)


## Get player node by peer ID


func _get_player_node(peer_id: int) -> Node3D:
	var entities: Node = GameManager.get_core_system("entities")
	if entities:
		var player := entities.get_player(peer_id) as Node3D
		if player and player.multiplayer == multiplayer:
			return player

	# Fallback
	for node in get_tree().get_nodes_in_group("player"):
		if (
			node is Node3D
			and node.multiplayer == multiplayer
			and node.get_multiplayer_authority() == peer_id
		):
			return node
	return null


## Server processes the item transfer


func _process_give_item(from_peer_id: int, to_peer_id: int, from_slot: int, amount: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if from_peer_id == to_peer_id:
		_send_transfer_failed(from_peer_id, "Cannot give items to yourself")
		return
	if amount != -1 and amount <= 0:
		_send_transfer_failed(from_peer_id, "Invalid transfer amount")
		return

	var from_inv: Inventory = _inventories.get(from_peer_id)
	if not from_inv:
		_send_transfer_failed(from_peer_id, "Your inventory not found")
		return
	var to_inv: Inventory = _inventories.get(to_peer_id)
	if not to_inv:
		_send_transfer_failed(from_peer_id, "Target player not found")
		return

	var from_player: Node3D = _get_player_node(from_peer_id)
	var to_player: Node3D = _get_player_node(to_peer_id)
	if not from_player or not to_player:
		_send_transfer_failed(from_peer_id, "Cannot find players")
		return
	if from_player.global_position.distance_to(to_player.global_position) > TRADE_DISTANCE:
		_send_transfer_failed(from_peer_id, "Player too far away")
		return

	var item: InventoryItem = from_inv.get_item_at(from_slot)
	if not item:
		_send_transfer_failed(from_peer_id, "No item in that slot")
		return
	var transfer_amount: int = item.current_stack if amount == -1 else amount
	if transfer_amount <= 0 or transfer_amount > item.current_stack:
		_send_transfer_failed(from_peer_id, "Invalid transfer amount")
		return

	# Atomic insertion checks merge capacity too, without disturbing the source on failure.
	var transferred_item: InventoryItem = item.duplicate_with_stack(transfer_amount)
	var transfer_data: Dictionary = transferred_item.to_dict()
	if not to_inv.add_item(transferred_item):
		_send_transfer_failed(from_peer_id, "Target inventory full")
		return
	if transfer_amount == item.current_stack:
		from_inv.remove_item_at(from_slot)
	else:
		item.remove_from_stack(transfer_amount)
		from_inv.inventory_changed.emit()

	_sync_inventory_owner(from_peer_id, from_inv)
	_sync_inventory_owner(to_peer_id, to_inv)

	_save_inventory(from_peer_id, from_inv)
	_save_inventory(to_peer_id, to_inv)

	# Insertion can change the incoming stack; the event describes the requested transfer.
	if multiplayer.has_multiplayer_peer():
		_sync_item_given.rpc(from_peer_id, to_peer_id, transfer_data)
	else:
		_sync_item_given(from_peer_id, to_peer_id, transfer_data)


## Sync item given to all clients

@rpc("authority", "call_local", "reliable")
func _sync_item_given(from_peer: int, to_peer: int, item_data: Dictionary) -> void:
	var item: InventoryItem = InventoryItem.from_dict(item_data)
	item_given.emit(from_peer, to_peer, item)

	# Notify receiver specifically
	if multiplayer.get_unique_id() == to_peer:
		item_received.emit(from_peer, item)
		GameManager.get_core_system("logger").info(
			"[Inventory] Received item from player %d: %s" % [from_peer, item.display_name], "Core"
		)


func _send_transfer_failed(peer_id: int, reason: String) -> void:
	if not multiplayer.has_multiplayer_peer() or peer_id == multiplayer.get_unique_id():
		_notify_transfer_failed(reason)
	else:
		_notify_transfer_failed.rpc_id(peer_id, reason)


## Notify client of transfer failure

@rpc("authority", "reliable")
func _notify_transfer_failed(reason: String) -> void:
	transfer_failed.emit(reason)
	push_warning("[Inventory] Transfer failed: " + reason)


## Drop item into world for another player to pick up


func drop_item_for_player(target_peer_id: int, from_slot: int, drop_position: Vector3) -> void:
	if multiplayer.is_server():
		_process_drop_for_player(
			multiplayer.get_unique_id(), target_peer_id, from_slot, drop_position
		)
	else:
		_request_drop_for_player.rpc_id(1, target_peer_id, from_slot, drop_position)


@rpc("any_peer", "reliable")
func _request_drop_for_player(target_peer_id: int, from_slot: int, drop_position: Vector3) -> void:
	var from_peer_id: int = multiplayer.get_remote_sender_id()
	if not _validate_inventory_rpc(from_peer_id, "request_drop", []):
		return
	_process_drop_for_player(from_peer_id, target_peer_id, from_slot, drop_position)


func _process_drop_for_player(
	from_peer_id: int, target_peer_id: int, from_slot: int, drop_position: Vector3
) -> void:
	if not multiplayer.is_server():
		return
	var from_inv: Inventory = _inventories.get(from_peer_id)
	var from_player: Node3D = _get_player_node(from_peer_id)
	if not from_inv or not from_player:
		_send_transfer_failed(from_peer_id, "Cannot find dropping player")
		return
	if not _inventories.has(target_peer_id) or not _get_player_node(target_peer_id):
		_send_transfer_failed(from_peer_id, "Target player not found")
		return
	if (
		not drop_position.is_finite()
		or from_player.global_position.distance_to(drop_position) > TRADE_DISTANCE
	):
		_send_transfer_failed(from_peer_id, "Invalid drop position")
		return
	var item: InventoryItem = from_inv.get_item_at(from_slot)
	if not item or item.current_stack <= 0:
		_send_transfer_failed(from_peer_id, "No item in that slot")
		return

	var loot := LootSvc.get_instance()
	if not loot or not loot.spawn_inventory_item(item, drop_position, target_peer_id):
		_send_transfer_failed(from_peer_id, "Could not spawn dropped item")
		return
	# The authoritative scene is ready before the stack leaves the inventory.
	# MultiplayerSpawner replicates it once, including its complete spawn data.
	from_inv.remove_item_at(from_slot)
	_sync_inventory_owner(from_peer_id, from_inv)
	_save_inventory(from_peer_id, from_inv)


func _on_peer_disconnected(peer_id: int) -> void:
	_inventories.erase(peer_id)


# ============================================================================
# Item Consumption (Server-Authoritative)
# ============================================================================

## Use a consumable item (client request)


func use_consumable(from_slot: int) -> void:
	var my_id: int = multiplayer.get_unique_id()

	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_process_use_consumable(my_id, from_slot)
	else:
		_request_use_consumable.rpc_id(1, from_slot)


## Server RPC to process use consumable request

@rpc("any_peer", "reliable")
func _request_use_consumable(from_slot: int) -> void:
	if not multiplayer.is_server():
		return

	var peer_id: int = multiplayer.get_remote_sender_id()

	# Apply the existing item-use whitelist and rate limit.
	var ns := GameManager.get_core_system("network") as NetworkSvc
	if ns and ns.network_manager:
		if not ns.network_manager.validate_rpc(peer_id, "request_use_item", []):
			return

	_process_use_consumable(peer_id, from_slot)


## Server processes the item consumption


func _process_use_consumable(peer_id: int, from_slot: int) -> void:
	if not multiplayer.is_server():
		return
	var inv: Inventory = _inventories.get(peer_id)
	if not inv:
		_send_transfer_failed(peer_id, "Inventory not found")
		return

	var item: InventoryItem = inv.get_item_at(from_slot)
	if not item or item.current_stack <= 0:
		_send_transfer_failed(peer_id, "No item in that slot")
		return
	if item.item_type != InventoryItem.ItemType.CONSUMABLE:
		_send_transfer_failed(peer_id, "Item is not consumable")
		return
	if not is_finite(item.effect_value) or item.effect_value <= 0:
		_send_transfer_failed(peer_id, "Invalid consumable effect")
		return

	var player: Node3D = _get_player_node(peer_id)
	if not player:
		_send_transfer_failed(peer_id, "Player node not found")
		return
	var health: HealthComponent = player.health_component if "health_component" in player else null
	var effect_applied: bool = false
	match item.effect_type:
		"heal":
			if health:
				var previous: float = health.current_health
				health.heal(item.effect_value)
				effect_applied = health.current_health > previous
			elif "health" in player:
				var previous: float = player.health
				var maximum: float = player.max_health if "max_health" in player else 100.0
				if previous > 0 and previous < maximum:
					player.health = minf(previous + item.effect_value, maximum)
					effect_applied = player.health > previous
		"armor":
			if health:
				var previous: float = health.current_armor
				if previous < health.max_armor:
					health.add_armor(item.effect_value)
					effect_applied = health.current_armor > previous
			elif "armor" in player and (not "health" in player or player.health > 0):
				var previous: float = player.armor
				var maximum: float = player.max_armor if "max_armor" in player else 100.0
				if previous < maximum:
					player.armor = minf(previous + item.effect_value, maximum)
					effect_applied = player.armor > previous
		"buff_speed", "buff_damage":
			var effects := player.get_node_or_null("StatusEffectManager") as StatusEffectManager
			if effects:
				effect_applied = effects.apply_consumable_buff(item.effect_type, item.effect_value)

	if not effect_applied:
		_send_transfer_failed(peer_id, "Could not apply consumable effect")
		return

	var consumed: InventoryItem = inv.remove_item_at(from_slot, 1)
	_sync_inventory_owner(peer_id, inv)
	_save_inventory(peer_id, inv)
	if not multiplayer.has_multiplayer_peer() or peer_id == multiplayer.get_unique_id():
		_sync_item_consumed(consumed.to_dict())
	elif multiplayer.get_peers().has(peer_id):
		_sync_item_consumed.rpc_id(peer_id, consumed.to_dict())


## Sync item consumption to client

@rpc("authority", "reliable")
func _sync_item_consumed(item_data: Dictionary) -> void:
	var item: InventoryItem = InventoryItem.from_dict(item_data)
	item_consumed.emit(multiplayer.get_unique_id(), item)
	GameManager.get_core_system("logger").info("[Inventory] Used: " + item.display_name, "Core")


## Clear inventory for a player (Server only)


func clear_inventory(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var inv: Inventory = _inventories.get(peer_id)
	if inv:
		inv.clear()
		_sync_inventory_owner(peer_id, inv)
		_save_inventory(peer_id, inv)


# ============================================================================
# DEBUG / CHEATS
# ============================================================================


func give_debug_items() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_request_debug_items.rpc_id(1)
	else:
		_process_give_debug_items(multiplayer.get_unique_id())


@rpc("any_peer", "call_remote", "reliable")
func _request_debug_items() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	_process_give_debug_items(sender_id)


func _process_give_debug_items(peer_id: int) -> void:
	var inv: Inventory = _inventories.get(peer_id)
	if not inv:
		return

	# Add one of each item from database (sample_items.json5)
	var data_service: Node = GameManager.get_core_system("data")
	var items_db: Dictionary = data_service.items if data_service else {}
	if not items_db.is_empty():
		for item_id: String in items_db:
			var data: Dictionary = items_db[item_id]
			# Ensure the id is set
			data["id"] = item_id
			var item: InventoryItem = InventoryItem.from_dict(data)
			if item:
				inv.add_item(item)
		var logger_service: Node = GameManager.get_core_system("logger")
		if logger_service:
			logger_service.info(
				"[InventoryManager] Added %d items from sample_items.json5" % items_db.size(),
				"Core"
			)
	else:
		push_warning("[InventoryManager] No items found in database")

	# And weapons? Weapons are usually separate or items too?
	# If weapons are items, they are in "items" DB or separate?
	# Usually separate. Let's try adding weapons as items too if supported.
	var weapons_db: Dictionary = data_service.weapons if data_service else {}
	if not weapons_db.is_empty():
		for weapon_id: String in weapons_db:
			# Create item representation of weapon
			# Assuming InventoryItem can represent a weapon
			var w_data: Dictionary = weapons_db[weapon_id]
			var item: InventoryItem = InventoryItem.new()
			item.id = weapon_id
			item.display_name = w_data.get("name", weapon_id)
			item.item_type = InventoryItem.ItemType.WEAPON
			# Hacky: Try to determine slot
			var slot: String = w_data.get("slot_type", "weapon_primary")
			item.equip_slot = slot

			inv.add_item(item)

	# Sync whole inventory to client (heavy, but it's debug)
	# Inventory changes sync automatically if implemented in Inventory.gd?
	# Usually add_item triggers a signal or RPC.
	# But if we did it on server, we need to ensure client sees it.
	inv.inventory_changed.emit()

	# Force full sync
	_sync_full_inventory.rpc_id(peer_id, inv.to_dict())


@rpc("authority", "call_local", "reliable")
func _sync_full_inventory(data: Dictionary) -> void:
	var my_id: int = multiplayer.get_unique_id()
	var inv: Inventory = _inventories.get(my_id)
	if inv:
		inv.from_dict(data)


func _sync_inventory_owner(peer_id: int, inv: Inventory) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	if peer_id == multiplayer.get_unique_id() or not multiplayer.get_peers().has(peer_id):
		return
	_sync_full_inventory.rpc_id(peer_id, inv.to_dict())


func _save_inventory(peer_id: int, inv: Inventory) -> void:
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.player:
		var data: Dictionary = gs.player.get_player_data(peer_id)
		data["inventory"] = inv.to_dict()
		gs.player.save_player_data(peer_id)


# ------------------------------------------------------------------------------
# Item Movement (Drag & Drop)
# ------------------------------------------------------------------------------

## Request to move item (Client -> Server)


func request_move_item(from_slot: int, to_slot: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_request_move_item.rpc_id(1, from_slot, to_slot)
	else:
		_process_move_item(multiplayer.get_unique_id(), from_slot, to_slot)


@rpc("any_peer", "reliable")
func _request_move_item(from_slot: int, to_slot: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()

	# Rate Limit
	var ns := GameManager.get_core_system("network") as NetworkSvc
	if ns and ns.network_manager:
		if not ns.network_manager.validate_rpc(sender_id, "move_item", []):
			return

	_process_move_item(sender_id, from_slot, to_slot)


func _process_move_item(peer_id: int, from_slot: int, to_slot: int) -> void:
	if not multiplayer.is_server():
		return
	var inv: Inventory = get_inventory(peer_id)
	if not inv:
		return

	# Inventory validates both indices before performing its legal slot swap.
	inv.move_item(from_slot, to_slot)
	_sync_inventory_owner(peer_id, inv)


# ------------------------------------------------------------------------------
# Split Stack
# ------------------------------------------------------------------------------


func request_split_stack(from_slot: int, to_slot: int, amount: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_request_split_stack.rpc_id(1, from_slot, to_slot, amount)
	else:
		_process_split_stack(multiplayer.get_unique_id(), from_slot, to_slot, amount)


@rpc("any_peer", "reliable")
func _request_split_stack(from_slot: int, to_slot: int, amount: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not _validate_inventory_rpc(sender_id, "split_stack", [amount]):
		return
	_process_split_stack(sender_id, from_slot, to_slot, amount)


func _process_split_stack(peer_id: int, from_slot: int, to_slot: int, amount: int) -> void:
	if not multiplayer.is_server():
		return
	var inv: Inventory = get_inventory(peer_id)
	if not inv:
		return

	if (
		from_slot < 0
		or from_slot >= inv.slots.size()
		or to_slot < 0
		or to_slot >= inv.slots.size()
		or from_slot == to_slot
		or amount <= 0
	):
		_sync_inventory_owner(peer_id, inv)
		return

	var from_item: InventoryItem = inv.get_item_at(from_slot)
	if not from_item or amount >= from_item.current_stack:
		_sync_inventory_owner(peer_id, inv)
		return

	var to_item: InventoryItem = inv.get_item_at(to_slot)
	if to_item:
		if to_item.id == from_item.id and to_item.max_stack > 1:
			# Leave excess in the source instead of removing and reinserting it.
			var moved: int = mini(amount, to_item.max_stack - to_item.current_stack)
			if moved > 0:
				from_item.current_stack -= moved
				to_item.current_stack += moved
				inv.inventory_changed.emit()
		else:
			# Preserve the existing whole-item swap for incompatible destinations.
			inv.move_item(from_slot, to_slot)
	elif amount <= from_item.max_stack:
		inv.slots[to_slot] = from_item.duplicate_with_stack(amount)
		from_item.current_stack -= amount
		inv.inventory_changed.emit()

	_sync_inventory_owner(peer_id, inv)


# ------------------------------------------------------------------------------
# Equipment Transfer
# ------------------------------------------------------------------------------


func request_equip_item(inv_slot: int, equip_slot_name: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_request_equip_item.rpc_id(1, inv_slot, equip_slot_name)
	else:
		_process_equip_item(multiplayer.get_unique_id(), inv_slot, equip_slot_name)


@rpc("any_peer", "reliable")
func _request_equip_item(inv_slot: int, equip_slot_name: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not _validate_inventory_rpc(sender_id, "equip_item", [inv_slot, equip_slot_name]):
		return
	_process_equip_item(sender_id, inv_slot, equip_slot_name)


func _process_equip_item(peer_id: int, inv_slot: int, equip_slot_name: String) -> void:
	if not multiplayer.is_server():
		return
	var inv: Inventory = get_inventory(peer_id)
	if not inv:
		return

	var item: InventoryItem = inv.get_item_at(inv_slot)
	if (
		item
		and equip_slot_name in Inventory.EQUIPMENT_SLOTS
		and (item.equip_slot == "" or item.equip_slot == equip_slot_name)
	):
		# Prevalidate: equip_item's null return also means a rejected operation.
		# Update the bag first so equipment signals observe the completed swap.
		inv.slots[inv_slot] = inv.get_equipped(equip_slot_name)
		inv.equip_item(item, equip_slot_name)

	_sync_inventory_owner(peer_id, inv)


func request_unequip_item(equip_slot_name: String, to_inv_slot: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_request_unequip_item.rpc_id(1, equip_slot_name, to_inv_slot)
	else:
		_process_unequip_item(multiplayer.get_unique_id(), equip_slot_name, to_inv_slot)


@rpc("any_peer", "reliable")
func _request_unequip_item(equip_slot_name: String, to_inv_slot: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not _validate_inventory_rpc(sender_id, "unequip_item", [equip_slot_name, to_inv_slot]):
		return
	_process_unequip_item(sender_id, equip_slot_name, to_inv_slot)


func _process_unequip_item(peer_id: int, equip_slot_name: String, to_inv_slot: int) -> void:
	if not multiplayer.is_server():
		return
	var inv: Inventory = get_inventory(peer_id)
	if not inv:
		return

	if (
		equip_slot_name not in Inventory.EQUIPMENT_SLOTS
		or to_inv_slot < 0
		or to_inv_slot >= inv.slots.size()
	):
		_sync_inventory_owner(peer_id, inv)
		return

	var item: InventoryItem = inv.get_equipped(equip_slot_name)
	var swapped: InventoryItem = inv.get_item_at(to_inv_slot)
	if item and (not swapped or swapped.equip_slot == "" or swapped.equip_slot == equip_slot_name):
		inv.slots[to_inv_slot] = item
		if swapped:
			inv.equip_item(swapped, equip_slot_name)
		else:
			inv.unequip_item(equip_slot_name)

	_sync_inventory_owner(peer_id, inv)
