extends Node
class_name InputService

const CONFIG_PATH = "user://input.json5"
const DEFAULTS_PATH = "res://game/config/gameplay/input.json5"

var remappable_actions: Array[String] = []
var action_names: Dictionary = {}
var default_keys: Dictionary = {}


func initialize() -> void:
	_load_defaults()
	_load_user_config()


func _load_defaults() -> void:
	if not JSON5Loader.file_exists(DEFAULTS_PATH):
		push_error("[InputService] Defaults file not found: %s" % DEFAULTS_PATH)
		return

	var data: Variant = JSON5Loader.load_file(DEFAULTS_PATH)
	if not data or not (data is Dictionary and data.has("actions")):
		push_error("[InputService] Invalid defaults format")
		return

	var actions: Variant = data["actions"]
	if actions is Dictionary:
		for action: String in actions:
			var info: Dictionary = actions[action]
			remappable_actions.append(action)
			if info.has("label"):
				action_names[action] = info["label"]
			if info.has("default"):
				default_keys[action] = info["default"]


func _load_user_config() -> void:
	if not JSON5Loader.file_exists(CONFIG_PATH):
		return

	var data: Variant = JSON5Loader.load_file(CONFIG_PATH)
	if not data or not (data is Dictionary):
		return

	for action: String in data:
		if not action in remappable_actions:
			continue

		var key_str: String = data[action]
		_apply_input_string(action, key_str)


func save_config() -> void:
	var data: Dictionary = {}

	for action: String in remappable_actions:
		var key_str: String = get_action_key_string(action)
		# Only save if different from default? Or just save all?
		# Saving all is safer for persistence.
		if key_str != "Unbound":
			data[action] = key_str

	# Check if we have anything to save
	if not data.is_empty():
		JSON5Loader.save_file(CONFIG_PATH, data, "User Input Configuration")


func remap_action(action: String, event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	save_config()


func _apply_input_string(action: String, input_str: String) -> void:
	# Parse custom strings for Mouse
	var event: InputEvent

	if input_str == "MouseLeft" or input_str == "LMB":
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
	elif input_str == "MouseRight" or input_str == "RMB":
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = true
	elif input_str == "MouseMiddle" or input_str == "MMB":
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_MIDDLE
		event.pressed = true
	else:
		# Assume Key
		var keycode: int = OS.find_keycode_from_string(input_str)
		if keycode != 0:
			event = InputEventKey.new()
			event.keycode = keycode

	if event:
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)


func get_action_key_string(action: String) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			var keycode: int = (
				event.physical_keycode if event.physical_keycode != 0 else event.keycode
			)
			return OS.get_keycode_string(keycode)

		# Separate Mouse check
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					return "MouseLeft"
				MOUSE_BUTTON_RIGHT:
					return "MouseRight"
				MOUSE_BUTTON_MIDDLE:
					return "MouseMiddle"
				_:
					return "Mouse" + str(event.button_index)
	return "Unbound"


func get_friendly_name(action: String) -> String:
	return action_names.get(action, action.capitalize())
