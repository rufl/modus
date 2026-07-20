extends PanelContainer

signal back_pressed
signal host_setup_requested
signal join_requested(address: String)

@onready var address_input: LineEdit = %AddressInput


func _ready() -> void:
	hide()


func show_menu() -> void:
	show()
	if address_input:
		address_input.grab_focus()


func hide_menu() -> void:
	hide()
	back_pressed.emit()


func _on_host_pressed() -> void:
	host_setup_requested.emit()


func _on_join_pressed() -> void:
	var address: String = address_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1:9999"
	join_requested.emit(address)


func _on_back_pressed() -> void:
	hide_menu()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		hide_menu()
		get_viewport().set_input_as_handled()
