extends "res://game/ui/console/command_module.gd"


func register_commands(registry: Object) -> void:
	super.register_commands(registry)

	register(
		"help", _cmd_help, "List all commands or get help for a specific command", "help [command]"
	)
	register("clear", _cmd_clear, "Clear console output")
	register("quit", _cmd_quit, "Exit the game")
	register("export", _cmd_export, "Export session log to file", "export [filename]")


func _cmd_help(args: Array) -> String:
	if args.size() > 0:
		var cmd_name: String = args[0].to_lower()
		var info: Dictionary = _registry.get_command_info(cmd_name)
		if not info.is_empty():
			return (
				"[color=yellow]%s[/color] - %s\nUsage: %s"
				% [cmd_name, info.description, info.usage]
			)
		return "[color=red]Unknown command: %s[/color]" % cmd_name

	# List all commands
	var output: String = "[color=yellow]Available Commands:[/color]\n"
	var cmds: Array = _registry.get_all_commands()
	for cmd: Variant in cmds:
		var info: Dictionary = _registry.get_command_info(cmd)
		output += "  [color=green]%s[/color] - %s\n" % [cmd, info.description]
	output += "\nType 'help <command>' for detailed usage."
	return output


func _cmd_clear(_args: Array) -> String:
	if _registry and _registry.has_method("clear_console"):
		_registry.clear_console()
	return ""


func _cmd_quit(_args: Array) -> String:
	Engine.get_main_loop().quit()
	return "Goodbye!"


func _cmd_export(args: Array) -> String:
	var filename: String = ""
	if args.size() > 0:
		filename = args[0]

	# Use GameManager.get_core_system("logger") consolidated API
	if (
		GameManager
		and GameManager.get_core_system("logger")
		and GameManager.get_core_system("logger").has_method("export_log")
	):
		return GameManager.get_core_system("logger").export_log(filename)
	return '[color=red]GameManager.get_core_system("logger").export_log() not available[/color]'
