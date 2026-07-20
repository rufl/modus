extends CanvasLayer
class_name DropdownConsole

## Debug console with command execution
## Toggle with backtick (`) or tilde (~) key

@onready var panel: PanelContainer = $Panel
@onready var output: RichTextLabel = $Panel/VBox/Output
@onready var input_field: LineEdit = $Panel/VBox/Input

var command_registry: ConsoleCommandRegistry
var is_open: bool = false
var command_history: Array[String] = []
var history_index: int = -1


func _ready() -> void:
	# Skip in editor
	if Engine.is_editor_hint():
		return

	# Initialize command registry
	command_registry = ConsoleCommandRegistry.new()

	# Register all command modules
	CheatCommands.register_commands(command_registry)
	DebugCommands.register_commands(command_registry)
	PlayerCommands.register_commands(command_registry)

	# Setup UI
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect signals
	if input_field:
		input_field.text_submitted.connect(_on_command_submitted)

	# Log
	var logger := GameManager.get_core_system("logger")
	if logger:
		logger.info("[DropdownConsole] Ready - Press ` to toggle", "UI")

	# Show welcome message
	add_output("[color=yellow]MODUS Debug Console[/color]")
	add_output("Type 'help' for available commands")
	add_output("Press ` or ~ to toggle console")


func _input(event: InputEvent) -> void:
	# Skip in editor
	if Engine.is_editor_hint():
		return

	# Toggle console with backtick or tilde
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE:
			toggle()
			get_viewport().set_input_as_handled()
			return

	# Handle history navigation when console is open
	if is_open and event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP:
			_navigate_history(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			_navigate_history(1)
			get_viewport().set_input_as_handled()


func toggle() -> void:
	## Toggle console visibility
	is_open = not is_open
	visible = is_open

	if is_open:
		if input_field:
			input_field.grab_focus()
			input_field.clear()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		history_index = -1


func _on_command_submitted(command: String) -> void:
	## Execute submitted command
	if command.is_empty():
		return

	# Add to history
	command_history.append(command)
	if command_history.size() > 50:  # Limit history
		command_history.pop_front()
	history_index = -1

	# Echo command
	add_output("[color=cyan]> %s[/color]" % command)

	# Execute command
	var result := command_registry.execute_command(command)
	add_output(result)

	# Clear input
	if input_field:
		input_field.clear()


func _navigate_history(direction: int) -> void:
	## Navigate command history with up/down arrows
	if command_history.is_empty():
		return

	if history_index == -1:
		history_index = command_history.size()

	history_index += direction
	history_index = clampi(history_index, 0, command_history.size())

	if history_index < command_history.size():
		if input_field:
			input_field.text = command_history[history_index]
			input_field.caret_column = input_field.text.length()
	else:
		if input_field:
			input_field.clear()


func add_output(text: String) -> void:
	## Add text to console output
	if output:
		output.append_text(text + "\n")
		# Auto-scroll to bottom
		output.scroll_to_line(output.get_line_count())
