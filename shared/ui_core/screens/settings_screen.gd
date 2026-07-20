class_name SettingsScreen
extends Control

# MODUS Framework Settings Screen
# Provides game settings interface

signal back_pressed

@onready var back_button: Button = $VBoxContainer/BackButton

func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	back_pressed.emit()

	# Close this screen
	if get_parent():
		get_parent().remove_child(self)
		queue_free()