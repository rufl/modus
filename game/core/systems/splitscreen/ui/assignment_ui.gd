extends Control

## Assignment UI for splitscreen multiplayer
## Allows players to claim their slots by pressing buttons on their gamepads

signal device_claimed(player_slot: int, device_id: int)

@onready var player_slots: VBoxContainer = %PlayerSlots
@onready var device_list: VBoxContainer = %DeviceList
@onready var progress_label: Label = %ProgressLabel
@onready var cancel_button: Button = %CancelButton
@onready var start_button: Button = %StartButton

var expected_player_count: int = 4
var claimed_slots: Dictionary = {}  # player_slot -> device_id
var device_names: Dictionary = {}  # device_id -> device_name


func _ready() -> void:
	cancel_button.pressed.connect(_on_cancel_pressed)
	start_button.pressed.connect(_on_start_pressed)
	start_button.disabled = true

	_update_ui()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.pressed and joy_event.button_index == JOY_BUTTON_A:
			_try_claim_slot(joy_event.device)


func set_expected_player_count(count: int) -> void:
	expected_player_count = count
	_update_ui()


func set_connected_devices(devices: Array[int]) -> void:
	device_names.clear()
	for device_id in devices:
		device_names[device_id] = Input.get_joy_name(device_id)
	_update_device_list()


func _try_claim_slot(device_id: int) -> void:
	# Check if device already claimed
	for slot in claimed_slots:
		if claimed_slots[slot] == device_id:
			return  # Already claimed

	# Find next available slot
	for slot in range(expected_player_count):
		if not claimed_slots.has(slot):
			claimed_slots[slot] = device_id
			device_claimed.emit(slot, device_id)
			_update_ui()
			_check_completion()
			return


func _check_completion() -> void:
	if claimed_slots.size() >= expected_player_count:
		start_button.disabled = false
	else:
		start_button.disabled = true


func _update_ui() -> void:
	_update_progress()
	_update_player_slots()
	_update_device_list()


func _update_progress() -> void:
	var progress = float(claimed_slots.size()) / float(expected_player_count)
	progress_label.text = "Players Ready: %d/%d" % [claimed_slots.size(), expected_player_count]


func _update_player_slots() -> void:
	if not player_slots:
		return

	# Clear existing slots
	for child in player_slots.get_children():
		child.queue_free()

	# Create slot displays
	for slot in range(expected_player_count):
		var slot_panel = PanelContainer.new()
		var slot_label = Label.new()

		if claimed_slots.has(slot):
			var device_id = claimed_slots[slot]
			var device_name = device_names.get(device_id, "Controller %d" % device_id)
			slot_label.text = "Player %d: %s" % [slot + 1, device_name]
			slot_panel.modulate = Color.GREEN
		else:
			slot_label.text = "Player %d: Press A to Join" % [slot + 1]
			slot_panel.modulate = Color.GRAY

		slot_panel.add_child(slot_label)
		player_slots.add_child(slot_panel)


func _update_device_list() -> void:
	if not device_list:
		return

	# Clear existing list
	for child in device_list.get_children():
		child.queue_free()

	# Show connected devices
	for device_id in device_names:
		var device_panel = PanelContainer.new()
		var device_label = Label.new()

		var device_name = device_names[device_id]
		var is_claimed = device_id in claimed_slots.values()

		device_label.text = "%s %s" % [device_name, "(Claimed)" if is_claimed else ""]
		device_panel.modulate = Color.GREEN if is_claimed else Color.WHITE

		device_panel.add_child(device_label)
		device_list.add_child(device_panel)


func _on_cancel_pressed() -> void:
	queue_free()


func _on_start_pressed() -> void:
	# All players ready, hide UI
	hide()


func unclaim_slot(player_slot: int) -> void:
	if claimed_slots.has(player_slot):
		claimed_slots.erase(player_slot)
		_update_ui()
		_check_completion()


func get_claimed_slots() -> Dictionary:
	return claimed_slots.duplicate()


func is_complete() -> bool:
	return claimed_slots.size() >= expected_player_count
