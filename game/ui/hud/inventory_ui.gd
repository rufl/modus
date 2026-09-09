extends Control
class_name InventoryUI

signal inventory_opened
signal inventory_closed

const SLOT_SCENE: String = "res://game/ui/hud/inventory_slot.tscn"
const GRID_COLUMNS: int = 8
const GRID_ROWS: int = 5
const TOTAL_SLOTS: int = 40

var slots: Array[InventorySlot] = []
var equipment_slots: Dictionary = {}
var inventory: Inventory = null
var is_open: bool = false
var context_menu: PopupMenu = null
var context_slot_index: int = -1

@onready var inventory_panel: Panel = $InventoryPanel
@onready var grid_container: GridContainer = $InventoryPanel/GridContainer
@onready var equipment_container: VBoxContainer = $InventoryPanel/EquipmentPanel
@onready var tooltip: ItemTooltip = $ItemTooltip
@onready var close_button: Button = $InventoryPanel/CloseButton


func _ready() -> void:
	add_to_group("mouse_stealers")
	hide()

	context_menu = PopupMenu.new()
	context_menu.add_item("Use", 0)
	context_menu.add_item("Drop", 1)
	context_menu.add_separator()
	context_menu.add_item("Split Stack", 2)
	context_menu.id_pressed.connect(_on_context_menu_pressed)
	add_child(context_menu)

	if close_button:
		close_button.pressed.connect(close_inventory)

	_create_slots()

	await get_tree().process_frame
	_connect_to_player_inventory()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if is_open:
			close_inventory()
		else:
			open_inventory()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_cancel") and is_open:
		close_inventory()
		get_viewport().set_input_as_handled()


func open_inventory() -> void:
	if is_open:
		return

	is_open = true
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_all_slots()
	inventory_opened.emit()


func close_inventory() -> void:
	if not is_open:
		return

	is_open = false
	hide()
	if tooltip:
		tooltip.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	inventory_closed.emit()


func _create_slots() -> void:
	if grid_container:
		grid_container.columns = GRID_COLUMNS

	var slot_scene: PackedScene = null
	if ResourceLoader.exists(SLOT_SCENE):
		slot_scene = load(SLOT_SCENE)

	for i in TOTAL_SLOTS:
		var slot: InventorySlot
		if slot_scene:
			slot = slot_scene.instantiate()
		else:
			slot = _create_slot_code()

		slot.slot_index = i
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_hovered.connect(_on_slot_hovered)
		slot.slot_unhovered.connect(_on_slot_unhovered)
		slot.item_dropped.connect(_on_item_dropped)
		if slot.has_signal("item_dropped_split"):
			slot.item_dropped_split.connect(_on_item_dropped_split)

		if grid_container:
			grid_container.add_child(slot)
			slots.append(slot)
		else:
			slot.queue_free()

	_create_equipment_slots(slot_scene)


func _create_slot_code() -> InventorySlot:
	var slot: InventorySlot = InventorySlot.new()
	slot.custom_minimum_size = Vector2(48, 48)

	var bg: Panel = Panel.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(bg)

	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(icon)

	var count: Label = Label.new()
	count.name = "CountLabel"
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slot.add_child(count)

	var frame: Panel = Panel.new()
	frame.name = "RarityFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(frame)

	var highlight: Panel = Panel.new()
	highlight.name = "SelectionHighlight"
	highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	highlight.modulate = Color(1, 1, 1, 0.3)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(highlight)

	return slot


func _create_equipment_slots(slot_scene: PackedScene) -> void:
	if not equipment_container:
		return

	var types: Array[String] = ["weapon_primary", "weapon_secondary", "head", "chest"]
	var labels: Array[String] = ["Primary", "Secondary", "Head", "Chest"]

	for i in types.size():
		var label: Label = Label.new()
		label.text = labels[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equipment_container.add_child(label)

		var slot: InventorySlot
		if slot_scene:
			var instantiated: Node = slot_scene.instantiate()
			slot = instantiated as InventorySlot
		else:
			slot = _create_slot_code()

		slot.slot_index = 100 + i
		slot.is_equipment_slot = true
		slot.equipment_type = types[i]
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_hovered.connect(_on_slot_hovered)
		slot.slot_unhovered.connect(_on_slot_unhovered)
		slot.item_dropped.connect(_on_item_dropped)
		slot.item_dropped_split.connect(_on_item_dropped_split)

		if equipment_container:
			equipment_container.add_child(slot)
			equipment_slots[types[i]] = slot
		else:
			slot.queue_free()


func _connect_to_player_inventory() -> void:
	var player: Node = _find_local_player()
	if player and "inventory" in player:
		inventory = player.inventory
		if inventory:
			inventory.inventory_changed.connect(_on_inventory_changed)
			_refresh_all_slots()


func _find_local_player() -> Node:
	var local_id: int = multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group("player"):
		if node.get_multiplayer_authority() == local_id:
			return node
	return null


func _refresh_all_slots() -> void:
	if not inventory:
		return

	for i in slots.size():
		var item: InventoryItem = inventory.get_item_at(i)
		if item:
			slots[i].set_item(item)
		else:
			slots[i].clear_item()

	for slot_name: String in equipment_slots.keys():
		var slot: InventorySlot = equipment_slots[slot_name]
		var item: InventoryItem = inventory.get_equipped(slot_name)
		if item:
			slot.set_item(item)
		else:
			slot.clear_item()


func _on_inventory_changed() -> void:
	if is_open:
		_refresh_all_slots()


func _on_slot_clicked(slot_index: int, button: int) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		context_slot_index = slot_index
		var slot: InventorySlot = _get_slot_by_index(slot_index)
		if slot and slot.has_item():
			_update_context_menu(slot_index)
			context_menu.position = get_global_mouse_position()
			context_menu.popup()


func _on_slot_hovered(slot_index: int) -> void:
	var slot: InventorySlot = _get_slot_by_index(slot_index)
	if slot and slot.has_item() and tooltip:
		tooltip.show_item(slot.get_item(), get_global_mouse_position())


func _on_slot_unhovered(_slot_index: int) -> void:
	if tooltip:
		tooltip.hide_tooltip()


func _on_item_dropped(from_index: int, to_index: int) -> void:
	if not inventory:
		return

	if from_index >= 100 or to_index >= 100:
		_handle_equipment_transfer(from_index, to_index)
		return

	var manager := InventoryMgr.get_instance()
	if manager:
		manager.request_move_item(from_index, to_index)


func _on_item_dropped_split(from_index: int, to_index: int) -> void:
	if not inventory:
		return
	if from_index >= 100 or to_index >= 100:
		_handle_equipment_transfer(from_index, to_index)
		return
	var item: InventoryItem = inventory.get_item_at(from_index)
	if not item or item.current_stack <= 1:
		return
	var manager := InventoryMgr.get_instance()
	if manager:
		manager.request_split_stack(from_index, to_index, int(item.current_stack / 2.0))


func _handle_equipment_transfer(from_index: int, to_index: int) -> void:
	var manager := InventoryMgr.get_instance()
	if not manager:
		return
	if from_index >= 100 and to_index >= 0 and to_index < TOTAL_SLOTS:
		manager.request_unequip_item(_get_equipment_slot_name(from_index), to_index)
	elif to_index >= 100 and from_index >= 0 and from_index < TOTAL_SLOTS:
		manager.request_equip_item(from_index, _get_equipment_slot_name(to_index))


func _get_equipment_slot_name(index: int) -> String:
	for slot_name: String in equipment_slots:
		if equipment_slots[slot_name].slot_index == index:
			return slot_name
	return ""


func _get_slot_by_index(index: int) -> InventorySlot:
	if index >= 100:
		var slot_name: String = _get_equipment_slot_name(index)
		return equipment_slots.get(slot_name)
	if index >= 0 and index < slots.size():
		return slots[index]
	return null


func _on_context_menu_pressed(id: int) -> void:
	if context_slot_index < 0:
		return

	var slot: InventorySlot = _get_slot_by_index(context_slot_index)
	if not slot or not slot.has_item():
		return

	match id:
		0:
			_use_item(context_slot_index)
		1:
			_drop_item(context_slot_index)
		2:
			_split_stack(context_slot_index)
		3:
			_delete_item(context_slot_index)
		_:
			# IDs 4+ are "Give to Player X"
			if id >= 4:
				var item_idx: int = context_menu.get_item_index(id)
				if item_idx >= 0:
					var peer_id: Variant = context_menu.get_item_metadata(item_idx)
					if peer_id is int:
						_give_item_to_player(context_slot_index, peer_id)

	context_slot_index = -1


func _use_item(slot_index: int) -> void:
	if not inventory:
		return

	var item: InventoryItem = inventory.get_item_at(slot_index)
	if not item:
		return

	# Use the server-authoritative consumable system
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	var is_cons: bool = "item_type" in item
	is_cons = is_cons and item.item_type == InventoryItem.ItemType.CONSUMABLE
	if gs and gs.inventory and is_cons:
		gs.inventory.use_consumable(slot_index)
		# UI will refresh via inventory_changed signal from InventoryManager
	else:
		# Non-consumable items (equip, etc.) - not yet implemented
		GameManager.get_core_system("logger").info(
			"[InventoryUI] Cannot use non-consumable item: " + " " + str(item.display_name), "UI"
		)


func _drop_item(slot_index: int) -> void:
	if not inventory:
		return

	# Use InventoryManager to handle networked drop
	# This ensures a pickup is spawned on the server and synced to all clients
	var player: Node = _find_local_player()
	if player:
		# Drop slightly in front of player
		var drop_offset: Vector3 = (-player.global_transform.basis.z * 2.0) + Vector3(0, 1, 0)
		var drop_pos: Vector3 = player.global_position + drop_offset
		var gs := GameManager.get_core_system("gameplay") as GameplaySvc
		if gs and gs.inventory:
			gs.inventory.drop_item_for_player(multiplayer.get_unique_id(), slot_index, drop_pos)

		# Local UI update will happen via signal from inventory change
		# But for responsiveness we can refresh (inventory sync might lag slightly)
		# relying on inventory_changed signal is safer to avoid desync


func _split_stack(slot_index: int) -> void:
	if not inventory:
		return

	var item: InventoryItem = inventory.get_item_at(slot_index)
	if not item or item.current_stack < 2:
		return

	var empty_slot: int = inventory.slots.find(null)
	var manager := InventoryMgr.get_instance()
	if empty_slot >= 0 and manager:
		manager.request_split_stack(slot_index, empty_slot, int(item.current_stack / 2.0))


# Handling Drag & Drop to World (Dropping item by dragging outside slots)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("slot_index") and data.has("item"):
		return true
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("slot_index"):
		# Dropped on the UI background -> Drop World Item
		_drop_item(data["slot_index"])


func _update_context_menu(_slot_index: int) -> void:
	context_menu.clear()
	context_menu.add_item("Use/Equip", 0)
	context_menu.add_item("Drop", 1)
	context_menu.add_item("Split Stack", 2)
	context_menu.add_separator()
	context_menu.add_item("Delete", 3)

	# Check for nearby players to give to
	var nearby_players: Array = _find_nearby_players()
	if nearby_players.size() > 0:
		context_menu.add_separator()
		for p: Node in nearby_players:
			var p_name: String = p.name
			if p.has_method("get_player_name"):
				p_name = p.get_player_name()
			context_menu.add_item("Give to " + p_name, 4 + nearby_players.find(p))
			# We store the peer_id in metadata or map by index
			context_menu.set_item_metadata(context_menu.get_item_count() - 1, p.name.to_int())


func _find_nearby_players() -> Array:
	var players: Array = []
	var local_player: Node = _find_local_player()
	if not local_player:
		return players

	for node in get_tree().get_nodes_in_group("player"):
		if node != local_player and node is CharacterBody3D:
			if local_player.global_position.distance_to(node.global_position) < 5.0:
				players.append(node)
	return players


func _delete_item(slot_index: int) -> void:
	if not inventory:
		return
	# Just remove from inventory, no spawn
	inventory.remove_item_at(slot_index)
	_refresh_all_slots()


func _give_item_to_player(slot_index: int, peer_id: int) -> void:
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.inventory:
		gs.inventory.give_item(peer_id, slot_index)
