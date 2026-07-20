extends Node

var sensitivity: float = 0.005
var controller_sensitivity: float = 0.010
var current_save_slot: String = "default"
var join_as_editor: bool = false
var player_controls_active: bool = false


func initialize() -> void:
	# Load saved preferences if they exist
	_load_preferences()


func _load_preferences() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load("user://preferences.cfg")
	if err != OK:
		return

	sensitivity = config.get_value("input", "sensitivity", 0.005)
	controller_sensitivity = config.get_value("input", "controller_sensitivity", 0.010)
	current_save_slot = config.get_value("save", "current_slot", "default")


func save_preferences() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("input", "sensitivity", sensitivity)
	config.set_value("input", "controller_sensitivity", controller_sensitivity)
	config.set_value("save", "current_slot", current_save_slot)
	config.save("user://preferences.cfg")
