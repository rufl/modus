extends PanelContainer

signal back_pressed
signal play_requested(slot_name: String)

@onready var slot_list: ItemList = %SlotList


func _ready() -> void:
	hide()
	_populate_slots()


func show_menu() -> void:
	_populate_slots()
	show()


func hide_menu() -> void:
	hide()
	back_pressed.emit()


func _populate_slots() -> void:
	if not slot_list:
		return

	slot_list.clear()

	# For now, just add some dummy slots
	var slots: Array[String] = ["Slot 1", "Slot 2", "Slot 3"]
	for slot in slots:
		slot_list.add_item(slot)


func _on_load_pressed() -> void:
	var selected: Array[int] = slot_list.get_selected_items()
	if selected.size() > 0:
		var slot_name: String = slot_list.get_item_text(selected[0])
		play_requested.emit(slot_name.to_lower().replace(" ", "_"))


func _on_back_pressed() -> void:
	hide_menu()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		hide_menu()
		get_viewport().set_input_as_handled()
