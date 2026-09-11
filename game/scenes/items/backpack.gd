class_name Backpack
extends RigidBody3D

signal collected(by_peer_id: int)

@export var owner_uuid: String = ""
@export var owner_peer_id: int = 0
@export var inventory_data: Dictionary = {}
@export var xp_amount: int = 0
@export var owner_name: String = "Unknown"

var interactable_type: String = "Backpack"
var interaction_text: String = "Retrieve Backpack"

@onready var interaction_area: Area3D = $InteractionArea
@onready var label_3d: Label3D = $Label3D
@onready var visual_node: Node3D = $Visuals


func _ready() -> void:
	# Initial setup
	if owner_name != "":
		update_label()

	# Setup interaction
	collision_layer = CollisionLayers.LAYER_INTERACTABLES

	# Only server needs to process physics logic for pickup?
	# Actually, client initiates interaction.

	# Visual flare
	_spawn_effect()


func setup(uuid: String, peer_id: int, name_str: String, inv: Dictionary, xp: int) -> void:
	owner_uuid = uuid
	owner_peer_id = peer_id
	owner_name = name_str
	inventory_data = inv
	xp_amount = xp

	update_label()

	# Sync vital data to clients if spawned on server
	if multiplayer.is_server():
		_sync_backpack_data.rpc(uuid, peer_id, name_str, xp)


func update_label() -> void:
	if label_3d:
		label_3d.text = "%s's Backpack\n(XP: %d)" % [owner_name, xp_amount]
		# Color code?


func interact(interactor: Node) -> void:
	# Check if interactor is the owner
	# We need to check UUID match.
	# Assuming 'interactor' is the Player node.

	var is_owner: bool = false
	var interactor_uuid: String = ""

	if "uuid" in interactor:
		interactor_uuid = interactor.uuid
	else:
		var gs := GameManager.get_core_system("gameplay") as GameplaySvc
		if gs and gs.player:
			# Fallback to looking up UUID by peer ID if available
			var pid: int = interactor.get_multiplayer_authority()
			interactor_uuid = gs.player.get_player_uuid(pid)

	if interactor_uuid == owner_uuid:
		is_owner = true

	if not is_owner:
		# Show feedback: "Not your backpack"
		# (Implementation dep on HUD messaging system)
		return

	# Request retrieval
	if multiplayer.is_server():
		_retrieve(interactor)
	else:
		_request_retrieve.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_retrieve() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return

	# Find sender player node
	var player: Node = _get_player_by_id(sender_id)
	if (
		not player
		or not player is Node3D
		or player.global_position.distance_to(global_position) > 3.5
	):
		return

	# Double check ownership on server
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.player:
		var p_uuid: String = gs.player.get_player_uuid(sender_id)
		if p_uuid == owner_uuid:
			_retrieve(player)


func _retrieve(player: Node) -> void:
	# 1. Restore Inventory
	# We need to MERGE or REPLACE?
	# Implementation: Merge contents back.
	# If player has items, we add to them.
	# Actually, dead player spawns empty, so this fills it up.

	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	var player_inv: Inventory = null
	if gs and gs.inventory:
		player_inv = gs.inventory.get_inventory(player.get_multiplayer_authority())
	if player_inv:
		var saved_inv: Inventory = Inventory.new()
		saved_inv.from_dict(inventory_data)

		# Transfer all items from slots
		for slot_item: InventoryItem in saved_inv.slots:
			if slot_item:
				player_inv.add_item(slot_item)

		# Sync update
		# If we wanted to SWAP inventory (e.g. finding a bigger backpack):
		# gs.inventory.register_inventory(player.get_multiplayer_authority(), player_inv)
		# Trigger visual update on client? gs.inventory handles this via signals?
		# Actually we might need to explicit sync.
		# But gs.inventory.register_inventory just sets local ref.
		# We should probably force a save/load or sync.
		# Use gs.inventory logic? It doesn't have a "replace whole inventory"
		# RPC publicly exposed easily.
		# We'll rely on PlayerService saving and syncing?

		# Let's assume we modified the server-side inventory object directly.
		# We need to tell the client to refresh.
		_sync_inventory_restored.rpc_id(player.get_multiplayer_authority(), inventory_data)

	# 2. Restore XP
	if "progression" in player and player.progression:
		player.progression.add_xp(xp_amount)

	# 3. Emit collected signal for tracking/stats
	collected.emit(player.get_multiplayer_authority())

	# 4. Destroy Backpack
	queue_free()


@rpc("authority", "call_local", "reliable")
func _sync_backpack_data(uuid: String, peer_id: int, name_str: String, xp: int) -> void:
	owner_uuid = uuid
	owner_peer_id = peer_id
	owner_name = name_str
	xp_amount = xp
	update_label()


@rpc("authority", "call_local", "reliable")
func _sync_inventory_restored(data_dict: Dictionary) -> void:
	# Client side refresh
	# Re-import data into local inventory view
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	var local_inv: Inventory = (
		gs.inventory.get_inventory(multiplayer.get_unique_id()) if gs and gs.inventory else null
	)
	if local_inv:
		# This is a bit brute force, merging might be valid if they picked up stuff since respawn.
		# But 'data_dict' is the backpack contents. We should ADD them.
		var pack_inv: Inventory = Inventory.new()
		pack_inv.from_dict(data_dict)
		for slot: String in pack_inv.items:
			local_inv.add_item(pack_inv.items[slot])
		local_inv.inventory_changed.emit()


func _spawn_effect() -> void:
	# Optional logic for spawn particle
	pass


func _get_player_by_id(pid: int) -> Node:
	for node in get_tree().get_nodes_in_group("player"):
		if node.get_multiplayer_authority() == pid:
			return node
	return null
