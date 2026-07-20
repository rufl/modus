extends PanelContainer

signal back_pressed

@onready var tab_container: TabContainer = %TabContainer


func _ready() -> void:
	# Hide by default
	hide()


func show_options() -> void:
	show()
	if tab_container:
		tab_container.current_tab = 0


func hide_options() -> void:
	hide()
	back_pressed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		hide_options()
		get_viewport().set_input_as_handled()
