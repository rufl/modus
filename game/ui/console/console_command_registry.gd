class_name ConsoleCommandRegistry
extends RefCounted

# MODUS Framework Console Command Registry
# Manages registration and execution of console commands

var _commands: Dictionary = {}


func _init() -> void:
	_register_default_commands()


func _register_default_commands() -> void:
	register_command("help", _help_command, "Show available commands")
	register_command("clear", _clear_command, "Clear console output")


func register_command(name: String, callable: Callable, description: String = "") -> void:
	_commands[name] = {"callable": callable, "description": description}


func execute_command(command_line: String) -> String:
	var parts: PackedStringArray = command_line.split(" ", false)
	if parts.is_empty():
		return "No command entered"

	var command_name: String = parts[0]
	var args: PackedStringArray = parts.slice(1)

	if not _commands.has(command_name):
		return "Unknown command: " + command_name

	var command_data: Dictionary = _commands[command_name]
	var callable: Callable = command_data.callable

	if callable.is_valid():
		var result: Variant = callable.call(args)
		return str(result) if result != null else "Command executed"
	return "Error executing command: " + command_name


func get_commands() -> Dictionary:
	return _commands.duplicate()


func _help_command(_args: PackedStringArray) -> String:
	var help_text: String = "Available commands:\n"
	for cmd_name: String in _commands.keys():
		var cmd_data: Dictionary = _commands[cmd_name]
		help_text += "  %s - %s\n" % [cmd_name, cmd_data.description]
	return help_text


func _clear_command(_args: PackedStringArray) -> String:
	return "Console cleared"
