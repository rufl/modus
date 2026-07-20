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


## Get player's inventory


func get_inventory(peer_id: int) -> Inventory:
	return _inventories.get(peer_id)


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
	if not multiplayer.is_server():
		return

	var from_peer_id: int = multiplayer.get_remote_sender_id()

	# Rate Limited
	var ns := GameManager.get_core_system("network") as NetworkSvc
	if ns and ns.network_manager:
		if not ns.network_manager.validate_rpc(from_peer_id, "give_item", [amount]):
			return

	_process_give_item(from_peer_id, to_peer_id, from_slot, amount)


## Get player node by peer ID


func _get_player_node(peer_id: int) -> Node3D:
	if GameManager.get_core_system("entities"):
		return GameManager.get_core_system("entities").get_player(peer_id)

	# Fallback
	for node in get_tree().get_nodes_in_group("player"):
		if node.get_multiplayer_authority() == peer_id:
			return node
	return null


## Server processes the item transfer


func _process_give_item(from_peer_id: int, to_peer_id: int, from_slot: int, amount: int) -> void:
	# Validate sender inventory
	var from_inv: Inventory = _inventories.get(from_peer_id)
	if not from_inv:
		_notify_transfer_failed.rpc_id(from_peer_id, "Your inventory not found")
		return

	# Validate receiver inventory
	var to_inv: Inventory = _inventories.get(to_peer_id)
	if not to_inv:
		_notify_transfer_failed.rpc_id(from_peer_id, "Target player not found")
		return

	# Proximity check - players must be nearby
	var from_player: Node3D = _get_player_node(from_peer_id)
	var to_player: Node3D = _get_player_node(to_peer_id)

	if from_player and to_player:
		var distance: float = from_player.global_position.distance_to(to_player.global_position)
		if distance > TRADE_DISTANCE:
			_notify_transfer_failed.rpc_id(from_peer_id, "Player too far away")
			return
	else:
		_notify_transfer_failed.rpc_id(from_peer_id, "Cannot find players")
		return

	# Get item from sender
	var item: InventoryItem = from_inv.get_item_at(from_slot)
	if not item:
		_notify_transfer_failed.rpc_id(from_peer_id, "No item in that slot")
		return

	# Check receiver has space
	if not to_inv.has_space():
		_notify_transfer_failed.rpc_id(from_peer_id, "Target inventory full")
		return

	# Remove from sender
	var transferred_item: InventoryItem = from_inv.remove_item_at(from_slot, amount)
	if not transferred_item:
		_notify_transfer_failed.rpc_id(from_peer_id, "Failed to remove item")
		return

	# Add to receiver
	if not to_inv.add_item(transferred_item):
		# Rollback - give back to sender
		from_inv.add_item(transferred_item)
		_notify_transfer_failed.rpc_id(from_peer_id, "Failed to give item")
		return

	# Sync to all clients
	if multiplayer.has_multiplayer_peer():
		_sync_item_given.rpc(from_peer_id, to_peer_id, transferred_item.to_dict())
	else:
		# Offline: just emit locally since we are both server and client
		_sync_item_given(from_peer_id, to_peer_id, transferred_item.to_dict())

	# Save both players
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.player:
		gs.player.update_inventory(from_peer_id, from_inv)
		gs.player.update_inventory(to_peer_id, to_inv)
		gs.player.save_player(from_peer_id)
		gs.player.save_player(to_peer_id)


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
	if not multiplayer.is_server():
		return

	var from_peer_id: int = multiplayer.get_remote_sender_id()

	# Rate	# Validate
	var ns := GameManager.get_core_system("network") as NetworkSvc
	if ns and ns.network_manager:
		if not ns.network_manager.validate_rpc(from_peer_id, "drop_item", []):
			return

	_process_drop_for_player(from_peer_id, target_peer_id, from_slot, drop_position)


func _process_drop_for_player(
	from_peer_id: int, target_peer_id: int, from_slot: int, drop_position: Vector3
) -> void:
	var from_inv: Inventory = _inventories.get(from_peer_id)
	if not from_inv:
		return

	var item: InventoryItem = from_inv.remove_item_at(from_slot)
	if not item:
		return

	# Spawn pickup in world with owner restriction
	_spawn_owned_pickup.rpc(item.to_dict(), drop_position, target_peer_id)


@rpc("authority", "call_local", "reliable")
func _spawn_owned_pickup(item_data: Dictionary, position: Vector3, owner_peer_id: int) -> void:
	call_deferred("_finish_spawn_owned_pickup", item_data, position, owner_peer_id)


func _finish_spawn_owned_pickup(
	item_data: Dictionary, position: Vector3, owner_peer_id: int
) -> void:
	# Create pickup that only target player can collect
	var pickup_scene: Resource = load("res://game/scenes/items/pickups/pickup_base.tscn")
	if not pickup_scene:
		return

	var pickup: Node3D = pickup_scene.instantiate()
	pickup.owner_peer_id = owner_peer_id
	pickup.pickup_name = item_data.get("display_name", "Item")
	pickup.description = item_data.get("description", "")

	get_tree().current_scene.add_child(pickup)
	pickup.global_position = position

	# Pass item data to pickup so it can be restored
	if "item_data" in pickup:
		pickup.item_data = item_data


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

	# Rate	# Validate
	var ns := GameManager.get_core_system("network") as NetworkSvc
	if ns and ns.network_manager:
		if not ns.network_manager.validate_rpc(peer_id, "use_item", []):
			return

	_process_use_consumable(peer_id, from_slot)


## Server processes the item consumption


func _process_use_consumable(peer_id: int, from_slot: int) -> void:
	var inv: Inventory = _inventories.get(peer_id)
	if not inv:
		_notify_transfer_failed.rpc_id(peer_id, "Inventory not found")
		return

	var item: InventoryItem = inv.get_item_at(from_slot)
	if not item:
		_notify_transfer_failed.rpc_id(peer_id, "No item in that slot")
		return

	# Check if it's a consumable
	if item.item_type != InventoryItem.ItemType.CONSUMABLE:
		_notify_transfer_failed.rpc_id(peer_id, "Item is not consumable")
		return

	# Find the player node
	var player: Node3D = _get_player_node(peer_id)
	if not player:
		_notify_transfer_failed.rpc_id(peer_id, "Player node not found")
		return

	# Apply the consumable effect
	var effect_applied: bool = false

	match item.effect_type:
		"heal":
			if "health_component" in player and player.health_component:
				player.health_component.heal(item.effect_value)
				effect_applied = true
			elif "health" in player:
				var max_hp: int = player.max_health if "max_health" in player else 100
				player.health = mini(player.health + int(item.effect_value), max_hp)
				effect_applied = true
		"armor":
			if "health_component" in player and player.health_component:
				player.health_component.add_armor(item.effect_value)
				effect_applied = true
			elif "armor" in player:
				var max_armor: int = player.max_armor if "max_armor" in player else 100
				player.armor = mini(player.armor + int(item.effect_value), max_armor)
				effect_applied = true
		_:
			# Generic consumable - just consume it
			effect_applied = true

	if not effect_applied:
		_notify_transfer_failed.rpc_id(peer_id, "Could not apply effect")
		return

	# Remove one from stack
	var removed: InventoryItem = inv.remove_item_at(from_slot, 1)
	if removed:
		if multiplayer.has_multiplayer_peer():
			_sync_item_consumed.rpc_id(peer_id, from_slot, item.to_dict())
		else:
			_sync_item_consumed(from_slot, item.to_dict())

		GameManager.get_core_system("logger").info(
			"[InventoryManager] Player %d used %s" % [peer_id, item.display_name], "Inventory"
		)


## Sync item consumption to client

@rpc("authority", "reliable")
func _sync_item_consumed(_slot: int, item_data: Dictionary) -> void:
	var item: InventoryItem = InventoryItem.from_dict(item_data)
	item_consumed.emit(multiplayer.get_unique_id(), item)

	# Trigger local inventory refresh
	var my_inv: Inventory = _inventories.get(multiplayer.get_unique_id())
	if my_inv:
		my_inv.inventory_changed.emit()

	GameManager.get_core_system("logger").info("[Inventory] Used: " + item.display_name, "Core")


## Clear inventory for a player (Server only)


func clear_inventory(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var inv: Inventory = _inventories.get(peer_id)
	if inv:
		inv.clear()
		_sync_clear_inventory.rpc_id(peer_id)

		# Persist empty state
		var gs := GameManager.get_core_system("gameplay") as GameplaySvc
		if gs and gs.player:
			gs.player.update_inventory(peer_id, inv)
			gs.player.save_player(peer_id)


@rpc("authority", "call_local", "reliable")
func _sync_clear_inventory() -> void:
	var my_id: int = multiplayer.get_unique_id()
	var inv: Inventory = _inventories.get(my_id)
	if inv:
		inv.clear()
		GameManager.get_core_system("logger").info(
			"[Inventory] Inventory cleared by server command.", "Core"
		)


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
		inv.load_from_dict(data)
		inv.inventory_changed.emit()
		GameManager.get_core_system("logger").info("[Inventory] Debug items received.", "Core")


# ------------------------------------------------------------------------------
# Item Movement (Drag & Drop)
# ------------------------------------------------------------------------------

## Request to move item (Client -> Server)


func request_move_item(from_slot: int, to_slot: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_request_move_item.rpc_id(1, from_slot, to_slot)
	else:
		if multiplayer.is_server():
			var my_id: int = multiplayer.get_unique_id()
			_process_move_item(my_id, from_slot, to_slot)


@rpc("any_peer", "reliable")
func _request_move_item(from_slot: int, to_slot: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()

	# Rate Limit
	var ns := GameManager.get_core_system("network") as NetworkSvc
	if ns and ns.network_manager:
		if not ns.network_manager.validate_rpc(sender_id, "move_item", []):
			return

	_process_move_item(sender_id, from_slot, to_slot)


func _process_move_item(peer_id: int, from_slot: int, to_slot: int) -> void:
	var inv: Inventory = get_inventory(peer_id)
	if not inv:
		return

	# Perform the move on server authority
	if inv.move_item(from_slot, to_slot):
		pass
	else:
		# Failed (e.g. invalid index). Revert client.
		_sync_full_inventory.rpc_id(peer_id, inv.to_dict())


# ------------------------------------------------------------------------------
# Split Stack
# ------------------------------------------------------------------------------


func request_split_stack(from_slot: int, to_slot: int, amount: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_request_split_stack.rpc_id(1, from_slot, to_slot, amount)
	else:
		if multiplayer.is_server():
			_process_split_stack(multiplayer.get_unique_id(), from_slot, to_slot, amount)


@rpc("any_peer", "reliable")
func _request_split_stack(from_slot: int, to_slot: int, amount: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	_process_split_stack(sender_id, from_slot, to_slot, amount)


func _process_split_stack(peer_id: int, from_slot: int, to_slot: int, amount: int) -> void:
	var inv: Inventory = get_inventory(peer_id)
	if not inv:
		return

	var from_item: InventoryItem = inv.get_item_at(from_slot)
	if not from_item or from_item.current_stack <= 1 or amount >= from_item.current_stack:
		_sync_full_inventory.rpc_id(peer_id, inv.to_dict())
		return

	var to_item: InventoryItem = inv.get_item_at(to_slot)
	if to_item:
		if to_item.can_stack_with(from_item):
			var moved: InventoryItem = inv.remove_item_at(from_slot, amount)
			if moved:
				var overflow: int = to_item.add_to_stack(moved.current_stack)
				if overflow > 0:
					moved.current_stack = overflow
					inv.add_item(moved)
		else:
			# Fallback to simple move/swap if target occupied and not stackable
			# effectively cancelling split but moving item
			inv.move_item(from_slot, to_slot)
	else:
		var moved_item: InventoryItem = inv.remove_item_at(from_slot, amount)
		if moved_item:
			inv.slots[to_slot] = moved_item
			inv.inventory_changed.emit()

	# Sync always to be safe
	_sync_full_inventory.rpc_id(peer_id, inv.to_dict())


# ------------------------------------------------------------------------------
# Equipment Transfer
# ------------------------------------------------------------------------------


func request_equip_item(inv_slot: int, equip_slot_name: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_request_equip_item.rpc_id(1, inv_slot, equip_slot_name)
	else:
		if multiplayer.is_server():
			_process_equip_item(multiplayer.get_unique_id(), inv_slot, equip_slot_name)


@rpc("any_peer", "reliable")
func _request_equip_item(inv_slot: int, equip_slot_name: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	_process_equip_item(sender_id, inv_slot, equip_slot_name)


func _process_equip_item(peer_id: int, inv_slot: int, equip_slot_name: String) -> void:
	var inv: Inventory = get_inventory(peer_id)
	if not inv:
		return

	var item: InventoryItem = inv.get_item_at(inv_slot)
	if item:
		var old_item: InventoryItem = inv.equip_item(item, equip_slot_name)
		inv.slots[inv_slot] = old_item  # Swap with unequipped
		# equip_item returns the previously equipped item but doesn't clear source
		# so we update the source slot with the swapped item (or null)

	_sync_full_inventory.rpc_id(peer_id, inv.to_dict())


func request_unequip_item(equip_slot_name: String, to_inv_slot: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_request_unequip_item.rpc_id(1, equip_slot_name, to_inv_slot)
	else:
		if multiplayer.is_server():
			_process_unequip_item(multiplayer.get_unique_id(), equip_slot_name, to_inv_slot)


@rpc("any_peer", "reliable")
func _request_unequip_item(equip_slot_name: String, to_inv_slot: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	_process_unequip_item(sender_id, equip_slot_name, to_inv_slot)


func _process_unequip_item(peer_id: int, equip_slot_name: String, to_inv_slot: int) -> void:
	var inv: Inventory = get_inventory(peer_id)
	if not inv:
		return

	var item: InventoryItem = inv.unequip_item(equip_slot_name)
	if item:
		# If target slot occupied, swap?
		if inv.slots[to_inv_slot] != null:
			var swapped: InventoryItem = inv.slots[to_inv_slot]
			inv.slots[to_inv_slot] = item
			# Equip swapped item?
			inv.equip_item(swapped, equip_slot_name)
		else:
			inv.slots[to_inv_slot] = item

	_sync_full_inventory.rpc_id(peer_id, inv.to_dict())
