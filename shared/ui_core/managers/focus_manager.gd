extends Node


# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger_service: Node = GameManager.get_core_system("logger")
	if logger_service and logger_service.has_method("info"):
		logger_service.info(message, category)
	else:
		print("[%s] %s" % [category, message])


signal focus_changed(control: Control)
signal focus_group_changed(group_id: String)
signal focus_lost

const DEFAULT_GROUP: String = "default"
const ANALOG_THRESHOLD: float = 0.5
const REPEAT_DELAY: float = 0.4
const REPEAT_RATE: float = 0.08

var _focus_groups: Dictionary = {}
var _active_group: String = DEFAULT_GROUP
var _last_focused: Dictionary = {}
var _current_focus: WeakRef = null
var _group_stack: Array[String] = []
var _nav_timer: float = 0.0
var _nav_direction: Vector2 = Vector2.ZERO
var _nav_initial_delay_passed: bool = false
var _wrap_navigation: bool = true
var _show_focus_highlight: bool = true
var _analog_deadzone: float = 0.3
var _enabled: bool = true


func _ready() -> void:
	name = "FocusManager"
	_load_config()

	# Create default group
	_focus_groups[DEFAULT_GROUP] = []

	# Managed by UISystem
	_log("[FocusManager] Initialized", "FocusManager")

	# Connect to viewport focus changes
	get_viewport().gui_focus_changed.connect(_on_viewport_focus_changed)


func _load_config() -> void:
	var config_service: Node = GameManager.get_core_system("config")
	if not config_service:
		return

	if config_service.has_method("get_value"):
		_wrap_navigation = config_service.get_value("ui.focus.wrap_navigation", true)
		_show_focus_highlight = config_service.get_value("ui.focus.show_focus_highlight", true)
		_analog_deadzone = config_service.get_value("ui.focus.analog_deadzone", 0.3)


func _process(delta: float) -> void:
	if not _enabled:
		return

	_handle_gamepad_navigation(delta)


func _input(event: InputEvent) -> void:
	if not _enabled:
		return

	# Handle UI navigation inputs
	if event is InputEventKey or event is InputEventJoypadButton:
		if event.is_action_pressed("ui_up"):
			_navigate(Vector2.UP)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down"):
			_navigate(Vector2.DOWN)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left"):
			_navigate(Vector2.LEFT)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_navigate(Vector2.RIGHT)
			get_viewport().set_input_as_handled()


# ============================================================================
# FOCUS GROUPS
# ============================================================================

## Register a focus group with controls


func register_focus_group(
	group_id: String, controls: Array[Control], auto_order: bool = true
) -> void:
	var refs: Array[WeakRef] = []

	for control: Control in controls:
		if control:
			refs.append(weakref(control))
			# Ensure focus mode is enabled
			if control.focus_mode == Control.FOCUS_NONE:
				control.focus_mode = Control.FOCUS_ALL

	# Sort by position if requested
	if auto_order:
		refs.sort_custom(
			func(a: WeakRef, b: WeakRef) -> bool:
				var ca: Control = a.get_ref()
				var cb: Control = b.get_ref()
				if not ca or not cb:
					return false
				# Sort top-to-bottom, then left-to-right
				if abs(ca.global_position.y - cb.global_position.y) > 10:
					return ca.global_position.y < cb.global_position.y
				return ca.global_position.x < cb.global_position.x
		)

	_focus_groups[group_id] = refs

	if GameManager:
		var logger_service: Node = GameManager.get_core_system("logger")
		if logger_service and logger_service.has_method("debug"):
			logger_service.debug(
				"[FocusManager] Registered group '%s' with %d controls" % [group_id, refs.size()],
				"FocusManager"
			)


## Add a control to an existing group


func add_control_to_group(group_id: String, control: Control) -> void:
	if not _focus_groups.has(group_id):
		_focus_groups[group_id] = []

	# Check if already in group
	for ref: WeakRef in _focus_groups[group_id]:
		if ref.get_ref() == control:
			return

	_focus_groups[group_id].append(weakref(control))

	if control.focus_mode == Control.FOCUS_NONE:
		control.focus_mode = Control.FOCUS_ALL


## Remove a control from a group


func remove_control_from_group(group_id: String, control: Control) -> void:
	if not _focus_groups.has(group_id):
		return

	for i: int in range(_focus_groups[group_id].size() - 1, -1, -1):
		if _focus_groups[group_id][i].get_ref() == control:
			_focus_groups[group_id].remove_at(i)
			break


## Remove a focus group


func unregister_focus_group(group_id: String) -> void:
	_focus_groups.erase(group_id)
	_last_focused.erase(group_id)


## Set the active focus group


func set_active_group(group_id: String, restore_last_focus: bool = true) -> void:
	if not _focus_groups.has(group_id):
		push_warning("[FocusManager] Unknown focus group: %s" % group_id)
		return

	_active_group = group_id
	focus_group_changed.emit(group_id)

	if GameManager:
		GameManager.emit_event("focus_group_changed", {"group_id": group_id})

	if restore_last_focus:
		focus_last_or_first()


## Get the active focus group ID


func get_active_group() -> String:
	return _active_group


## Push a new active group (saves previous)


func push_active_group(group_id: String) -> void:
	if group_id == _active_group:
		return

	_group_stack.append(_active_group)
	set_active_group(group_id)


## Pop the active group (restore previous)


func pop_active_group() -> void:
	if _group_stack.is_empty():
		return

	var prev_group: String = _group_stack.pop_back()
	set_active_group(prev_group)


# ============================================================================
# FOCUS CONTROL
# ============================================================================

## Focus the first control in the active group


func focus_first() -> void:
	var controls: Array[Control] = _get_valid_controls(_active_group)
	if controls.is_empty():
		focus_lost.emit()
		return

	_set_focus(controls[0])


## Focus the last control in the active group


func focus_last() -> void:
	var controls: Array[Control] = _get_valid_controls(_active_group)
	if controls.is_empty():
		focus_lost.emit()
		return

	_set_focus(controls.back())


## Focus the last focused control, or first if none


func focus_last_or_first() -> void:
	# Try to restore last focused
	if _last_focused.has(_active_group):
		var last: Control = _last_focused[_active_group].get_ref()
		if last and last.is_visible_in_tree() and last.focus_mode != Control.FOCUS_NONE:
			_set_focus(last)
			return

	# Fall back to first
	focus_first()


## Focus a specific control


func focus_control(control: Control) -> void:
	if not control:
		return

	_set_focus(control)


## Clear focus


func clear_focus() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()

	_current_focus = null
	focus_lost.emit()


## Get the currently focused control
## Returns the focused Control if available, null if no control has focus
## Null is a valid return value when no control is focused
func get_focused_control() -> Control:
	if _current_focus:
		return _current_focus.get_ref()
	return null  # No control currently focused


func _set_focus(control: Control) -> void:
	if not control or not control.is_visible_in_tree():
		return

	control.grab_focus()
	_current_focus = weakref(control)
	_last_focused[_active_group] = weakref(control)

	focus_changed.emit(control)


# ============================================================================
# NAVIGATION
# ============================================================================


func _navigate(direction: Vector2) -> void:
	var controls: Array[Control] = _get_valid_controls(_active_group)
	if controls.is_empty():
		return

	var current: Control = get_focused_control()
	if not current:
		focus_first()
		return

	# Find current index
	var current_index: int = -1
	for i: int in range(controls.size()):
		if controls[i] == current:
			current_index = i
			break

	if current_index == -1:
		focus_first()
		return

	# Calculate next index based on direction
	var next_index: int = current_index

	if direction == Vector2.UP or direction == Vector2.LEFT:
		next_index = current_index - 1
	elif direction == Vector2.DOWN or direction == Vector2.RIGHT:
		next_index = current_index + 1

	# Handle wrap-around
	if _wrap_navigation:
		if next_index < 0:
			next_index = controls.size() - 1
		elif next_index >= controls.size():
			next_index = 0
	else:
		next_index = clampi(next_index, 0, controls.size() - 1)

	if next_index != current_index:
		_set_focus(controls[next_index])
		_play_navigate_sound()


func _handle_gamepad_navigation(delta: float) -> void:
	# Get analog stick input
	var joy_vec: Vector2 = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)

	# Apply deadzone
	if joy_vec.length() < _analog_deadzone:
		_nav_timer = 0.0
		_nav_direction = Vector2.ZERO
		_nav_initial_delay_passed = false
		return

	# Normalize direction
	var direction: Vector2 = Vector2.ZERO
	if abs(joy_vec.x) > abs(joy_vec.y):
		direction = Vector2.RIGHT if joy_vec.x > 0 else Vector2.LEFT
	else:
		direction = Vector2.DOWN if joy_vec.y > 0 else Vector2.UP

	# Handle direction change
	if direction != _nav_direction:
		_nav_direction = direction
		_nav_timer = 0.0
		_nav_initial_delay_passed = false
		_navigate(direction)
		return

	# Handle repeat
	_nav_timer += delta

	if not _nav_initial_delay_passed:
		if _nav_timer >= REPEAT_DELAY:
			_nav_initial_delay_passed = true
			_nav_timer = 0.0
			_navigate(direction)
	else:
		if _nav_timer >= REPEAT_RATE:
			_nav_timer = 0.0
			_navigate(direction)


func _on_viewport_focus_changed(control: Control) -> void:
	if control:
		_current_focus = weakref(control)
		_last_focused[_active_group] = weakref(control)
		focus_changed.emit(control)


# ============================================================================
# UTILITIES
# ============================================================================


func _get_valid_controls(group_id: String) -> Array[Control]:
	var result: Array[Control] = []

	if not _focus_groups.has(group_id):
		return result

	var refs: Array = _focus_groups[group_id]
	var valid_refs: Array[WeakRef] = []

	for ref: WeakRef in refs:
		var control: Control = ref.get_ref()
		if control and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
			result.append(control)
			valid_refs.append(ref)

	# Clean up dead refs
	_focus_groups[group_id] = valid_refs

	return result


func _play_navigate_sound() -> void:
	if GameManager:
		var audio_service: Node = GameManager.get_core_system("audio")
		if audio_service and audio_service.has_method("play_sound"):
			audio_service.play_sound("ui_navigate")


# ============================================================================
# SETTINGS
# ============================================================================

## Enable/disable focus management


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


## Set wrap-around navigation


func set_wrap_navigation(enable_wrap: bool) -> void:
	_wrap_navigation = enable_wrap

	var config_service: Node = GameManager.get_core_system("config")
	if config_service and config_service.has_method("set_value"):
		config_service.set_value("ui.focus.wrap_navigation", enable_wrap, true)


## Set analog deadzone


func set_analog_deadzone(deadzone: float) -> void:
	_analog_deadzone = clampf(deadzone, 0.1, 0.9)

	var config_service: Node = GameManager.get_core_system("config")
	if config_service and config_service.has_method("set_value"):
		config_service.set_value("ui.focus.analog_deadzone", _analog_deadzone, true)


## Check if wrap navigation is enabled


func is_wrap_navigation() -> bool:
	return _wrap_navigation


func _exit_tree() -> void:
	# Disconnect viewport signal to prevent memory leak
	var viewport := get_viewport()
	if viewport and viewport.gui_focus_changed.is_connected(_on_viewport_focus_changed):
		viewport.gui_focus_changed.disconnect(_on_viewport_focus_changed)
