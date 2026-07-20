extends "res://game/scripts/features/modding/mod_script.gd"

## Example mod script - Template
## Shows how to create custom mod functionality


func _mod_init() -> void:
	mod_print("Template mod initialized!")


func _mod_cleanup() -> void:
	mod_print("Template mod cleaned up!")
