extends PanelContainer

signal back_pressed
signal host_requested(connection_settings: Dictionary, match_settings: Dictionary)

@onready var max_players_spin: SpinBox = %MaxPlayersSpin
@onready var port_spin: SpinBox = %PortSpin
@onready var upnp_check: CheckBox = %UPNPCheck
@onready var difficulty_option: OptionButton = %DifficultyOption


func _ready() -> void:
	# Hide by default
	hide()


func show_menu() -> void:
	show()
	# Focus first control
	if max_players_spin:
		max_players_spin.grab_focus()


func hide_menu() -> void:
	hide()
	back_pressed.emit()


func _on_host_pressed() -> void:
	var connection_settings: Dictionary = {
		"max_players": int(max_players_spin.value),
		"port": int(port_spin.value),
		"use_upnp": upnp_check.button_pressed
	}

	var match_settings: Dictionary = {"difficulty": difficulty_option.selected}

	host_requested.emit(connection_settings, match_settings)


func _on_back_pressed() -> void:
	hide_menu()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		hide_menu()
		get_viewport().set_input_as_handled()
