extends Button

var _confirmation_dialog: ConfirmationDialog = null


func _ready() -> void:
	_create_confirmation_dialog()


func _create_confirmation_dialog() -> void:
	_confirmation_dialog = ConfirmationDialog.new()
	_confirmation_dialog.title = "Quit Game"
	_confirmation_dialog.dialog_text = "Are you sure you want to exit?"
	_confirmation_dialog.ok_button_text = "Quit"
	_confirmation_dialog.cancel_button_text = "Cancel"
	_confirmation_dialog.min_size = Vector2i(300, 100)
	_confirmation_dialog.confirmed.connect(_on_quit_confirmed)
	add_child(_confirmation_dialog)


func _pressed() -> void:
	_confirmation_dialog.popup_centered()


func _on_quit_confirmed() -> void:
	get_tree().quit()
