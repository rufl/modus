extends VBoxContainer

const REMAP_ROW_SCENE = preload("res://game/ui/menus/menu/options/remap_row.tscn")

var input_service: Node
var is_remapping: bool = false
var action_to_remap: String
var remapping_button: Button


func _ready() -> void:
	# Add a small delay to ensure GameCore is initialized if this is tested in isolation,
	# though usually OptionsMenu is part of the main game which has GameCore.
	if not input_service:
		var manager: Node = get_node_or_null("/root/GameManager")
		if manager and "input" in manager:
			input_service = manager.input

	if input_service:
		_create_remap_rows()
	else:
		push_warning("InputOptionsPanel: InputService not found")


func _create_remap_rows() -> void:
	# Spacers
	add_child(HSeparator.new())

	var header: Label = Label.new()
	header.text = "Key Bindings"
	# header.add_theme_font_size_override("font_size", 24) # Ensure this looks okay
	add_child(header)

	for action: String in input_service.remappable_actions:
		var row: Control = REMAP_ROW_SCENE.instantiate()
		add_child(row)
		if row.has_method("setup"):
			row.setup(action, input_service)
			row.rebind_requested.connect(_on_rebind_requested)


func _on_rebind_requested(action_name: String, button: Button) -> void:
	if is_remapping:
		return

	is_remapping = true
	action_to_remap = action_name
	remapping_button = button
	button.text = "..."
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not is_remapping:
		return

	if event is InputEventKey and event.pressed:
		# Allow canceling with Escape
		if event.keycode == KEY_ESCAPE:
			_cancel_remapping()
			get_viewport().set_input_as_handled()
			return

		input_service.remap_action(action_to_remap, event)
		remapping_button.text = input_service.get_action_key_string(action_to_remap)
		is_remapping = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		# InputService currently remaps keyboard events only; leave mouse bindings unchanged.
		pass


func _cancel_remapping() -> void:
	is_remapping = false
	if remapping_button and input_service:
		remapping_button.text = input_service.get_action_key_string(action_to_remap)
