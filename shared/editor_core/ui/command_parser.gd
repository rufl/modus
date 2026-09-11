@tool
class_name CommandParser
extends RefCounted

var commands: Dictionary = {}
var reference_position: Vector3 = Vector3.ZERO


class ParseResult:
	var success: bool = false
	var command: String = ""
	var args: Array = []
	var error_msg: String = ""
	var usage: String = ""


## Command definition


class CommandDef:
	var name: String
	var description: String
	var usage: String
	var min_args: int
	var max_args: int
	var arg_types: Array[String]  # "string", "int", "float", "coords", "block_id", "entity_id"

	func _init(
		n: String, desc: String, use: String, min_a: int, max_a: int, types: Array[String]
	) -> void:
		name = n
		description = desc
		usage = use
		min_args = min_a
		max_args = max_a
		arg_types = types


## Registered commands

## Current player/camera position (for relative coordinates)


func _init() -> void:
	_register_default_commands()


## Register default editor commands


func _register_default_commands() -> void:
	# Block manipulation
	register_command(
		CommandDef.new(
			"fill",
			"Fill a region with blocks",
			"/fill <block_id> <x1> <y1> <z1> <x2> <y2> <z2> [replace|hollow|outline]",
			7,
			8,
			["block_id", "coords", "coords", "coords", "coords", "coords", "coords", "string"]
		)
	)

	register_command(
		CommandDef.new(
			"setblock",
			"Place a single block",
			"/setblock <x> <y> <z> <block_id> [destroy|keep]",
			4,
			5,
			["coords", "coords", "coords", "block_id", "string"]
		)
	)

	register_command(
		CommandDef.new(
			"clone",
			"Clone a region to another location",
			"/clone <x1> <y1> <z1> <x2> <y2> <z2> <dest_x> <dest_y> <dest_z>",
			9,
			9,
			[
				"coords",
				"coords",
				"coords",
				"coords",
				"coords",
				"coords",
				"coords",
				"coords",
				"coords"
			]
		)
	)

	# Entity spawning
	register_command(
		CommandDef.new(
			"summon",
			"Spawn an entity",
			"/summon <entity_id> <x> <y> <z> [rotation]",
			4,
			5,
			["entity_id", "coords", "coords", "coords", "float"]
		)
	)

	register_command(
		CommandDef.new(
			"give", "Add item to hotbar", "/give <item_id> [count]", 1, 2, ["string", "int"]
		)
	)

	# Camera/navigation
	register_command(
		CommandDef.new(
			"tp",
			"Teleport camera to position",
			"/tp <x> <y> <z>",
			3,
			3,
			["coords", "coords", "coords"]
		)
	)

	# Undo/redo
	register_command(CommandDef.new("undo", "Undo last action(s)", "/undo [count]", 0, 1, ["int"]))

	register_command(
		CommandDef.new("redo", "Redo undone action(s)", "/redo [count]", 0, 1, ["int"])
	)

	# Level management
	register_command(
		CommandDef.new("save", "Save level to file", "/save <filename>", 1, 1, ["string"])
	)

	register_command(
		CommandDef.new("load", "Load level from file", "/load <filename>", 1, 1, ["string"])
	)

	register_command(
		CommandDef.new(
			"clear",
			"Clear all blocks in region or entire level",
			"/clear [x1 y1 z1 x2 y2 z2]",
			0,
			6,
			["coords", "coords", "coords", "coords", "coords", "coords"]
		)
	)

	# Help
	register_command(
		CommandDef.new("help", "Show help for commands", "/help [command]", 0, 1, ["string"])
	)

	# Grid/snap settings
	register_command(CommandDef.new("grid", "Set grid size", "/grid <size>", 1, 1, ["float"]))

	register_command(
		CommandDef.new("snap", "Toggle grid snapping", "/snap [on|off]", 0, 1, ["string"])
	)


## Register a new command


func register_command(def: CommandDef) -> void:
	commands[def.name.to_lower()] = def


## Parse a command string


func parse(input: String) -> ParseResult:
	var result := ParseResult.new()

	# Trim and check empty
	input = input.strip_edges()
	if input.is_empty():
		result.error_msg = "Empty command"
		return result

	# Remove leading slash if present
	if input.begins_with("/"):
		input = input.substr(1)

	# Tokenize
	var tokens: Array[String] = _tokenize(input)
	if tokens.is_empty():
		result.error_msg = "Empty command"
		return result

	# Get command name
	result.command = tokens[0].to_lower()

	# Check if command exists
	if not commands.has(result.command):
		result.error_msg = "Unknown command: /%s" % result.command
		result.usage = "Type /help for available commands"
		return result

	var cmd_def: CommandDef = commands[result.command]

	# Get args (everything after command name)
	var raw_args: Array[String] = []
	for i: int in range(1, tokens.size()):
		raw_args.append(tokens[i])

	# Validate arg count
	if result.command == "clear" and raw_args.size() != 0 and raw_args.size() != 6:
		result.error_msg = "Invalid argument count (expected exactly 0 or 6)"
		result.usage = cmd_def.usage
		return result

	if raw_args.size() < cmd_def.min_args:
		result.error_msg = "Too few arguments (expected at least %d)" % cmd_def.min_args
		result.usage = cmd_def.usage
		return result

	if raw_args.size() > cmd_def.max_args:
		result.error_msg = "Too many arguments (expected at most %d)" % cmd_def.max_args
		result.usage = cmd_def.usage
		return result
	# Parse and validate each argument
	for i: int in range(raw_args.size()):
		var arg_type: String = "string"
		if i < cmd_def.arg_types.size():
			arg_type = cmd_def.arg_types[i]

		var parsed: Variant = _parse_argument(raw_args[i], arg_type)
		if parsed == null:
			result.error_msg = (
				"Invalid argument %d: '%s' (expected %s)" % [i + 1, raw_args[i], arg_type]
			)
			result.usage = cmd_def.usage
			return result

		result.args.append(parsed)

	result.success = true
	return result


## Tokenize command string (handles quoted strings)


func _tokenize(input: String) -> Array[String]:
	var tokens: Array[String] = []
	var current := ""
	var in_quotes := false
	var quote_char := ""

	for ch: String in input:
		if in_quotes:
			if ch == quote_char:
				in_quotes = false
				if not current.is_empty():
					tokens.append(current)
					current = ""
			else:
				current += ch
		elif ch == '"' or ch == "'":
			in_quotes = true
			quote_char = ch
		elif ch == " " or ch == "\t":
			if not current.is_empty():
				tokens.append(current)
				current = ""
		else:
			current += ch

	if not current.is_empty():
		tokens.append(current)

	return tokens


## Parse a single argument based on expected type


func _parse_argument(arg: String, arg_type: String) -> Variant:
	match arg_type:
		"string", "block_id", "entity_id":
			return arg

		"int":
			if arg.is_valid_int():
				return arg.to_int()
			return null

		"float":
			if arg.is_valid_float():
				return arg.to_float()
			return null

		"coords":
			return _parse_coordinate(arg)

		_:
			return arg


## Parse a coordinate value (supports relative ~)


func _parse_coordinate(arg: String) -> Variant:
	if arg.begins_with("~"):
		# Relative coordinate
		var offset_str: String = arg.substr(1)
		var offset: float = 0.0

		if not offset_str.is_empty():
			if offset_str.is_valid_float():
				offset = offset_str.to_float()
			else:
				return null

		# Return as dictionary to indicate relative
		return {"relative": true, "offset": offset}

	# Absolute coordinate
	if arg.is_valid_float():
		return {"relative": false, "value": arg.to_float()}
	return null


## Resolve coordinate to absolute value


func resolve_coordinate(coord: Variant, axis: int) -> float:
	if coord is Dictionary:
		if coord.get("relative", false):
			match axis:
				0:
					return reference_position.x + coord.get("offset", 0.0)
				1:
					return reference_position.y + coord.get("offset", 0.0)
				2:
					return reference_position.z + coord.get("offset", 0.0)
		else:
			return coord.get("value", 0.0)
	elif coord is float:
		return coord
	elif coord is int:
		return float(coord)
	return 0.0


## Resolve 3 coordinates to Vector3


func resolve_coordinates(x: Variant, y: Variant, z: Variant) -> Vector3:
	return Vector3(resolve_coordinate(x, 0), resolve_coordinate(y, 1), resolve_coordinate(z, 2))


## Set reference position for relative coordinates


func set_reference_position(pos: Vector3) -> void:
	reference_position = pos


## Get autocomplete suggestions


func get_autocomplete(partial: String) -> Array[String]:
	var suggestions: Array[String] = []

	# Remove leading slash
	if partial.begins_with("/"):
		partial = partial.substr(1)

	var tokens: Array[String] = _tokenize(partial)

	if tokens.is_empty():
		# Show all commands
		for cmd_name: String in commands:
			suggestions.append("/" + cmd_name)
	elif tokens.size() == 1:
		# Autocomplete command name
		var cmd_partial: String = tokens[0].to_lower()
		for cmd_name: String in commands:
			if cmd_name.begins_with(cmd_partial):
				suggestions.append("/" + cmd_name)

	suggestions.sort()
	return suggestions


## Get help text for a command


func get_help(command_name: String = "") -> String:
	if command_name.is_empty():
		# Show all commands
		var help := "Available commands:\n"
		var names: Array = commands.keys()
		names.sort()
		for name: String in names:
			var cmd: CommandDef = commands[name]
			help += "  /%s - %s\n" % [name, cmd.description]
		return help

	command_name = command_name.to_lower()
	if commands.has(command_name):
		var cmd: CommandDef = commands[command_name]
		return "%s\n\nUsage: %s\n\n%s" % [cmd.name, cmd.usage, cmd.description]

	return "Unknown command: " + command_name


## Get all command names


func get_command_names() -> Array[String]:
	var names: Array[String] = []
	for name: String in commands:
		names.append(name)
	names.sort()
	return names
