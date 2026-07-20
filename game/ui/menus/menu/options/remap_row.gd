extends HBoxContainer

signal rebind_requested(action_name: String, button: Button)

var action_name: String
var input_service: Node

@onready var label: Label = $Label
@onready var button: Button = $Button


func setup(action: String, service: Node) -> void:
	action_name = action
	input_service = service
	label.text = service.get_friendly_name(action)
	update_key_display()


func update_key_display() -> void:
	button.text = input_service.get_action_key_string(action_name)


func _on_button_pressed() -> void:
	rebind_requested.emit(action_name, button)
