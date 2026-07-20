class_name BaseScreen
extends Control

signal screen_entered
signal screen_exiting
signal back_requested

@export_group("Screen Settings")
@export var screen_id: String = ""
@export var focus_group: String = ""
@export var pause_on_show: bool = false
@export var show_cursor: bool = true
@export_group("Navigation")
@export var allow_back: bool = true
@export var back_destination: String = ""

var _screen_params: Dictionary = {}
var _was_paused: bool = false
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	# Full screen by default
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# CRITICAL: Process even while tree is paused (for pause menu to work)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# CRITICAL: Block all mouse clicks from reaching game controls beneath
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Generate screen_id from scene path if not set
	if screen_id.is_empty():
		screen_id = get_scene_file_path().get_file().get_basename()

	# Register with ThemeManager
	# Register with ThemeManager
	# Use UIService to get ThemeManager
	var ui_svc := UISystem.get_service()
	if ui_svc and ui_svc.theme_manager:
		if ui_svc.theme_manager.has_method("register_themeable"):
			ui_svc.theme_manager.register_themeable(self)

	# Call subclass initialization
	_on_ready()


func _enter_tree() -> void:
	if not _screen_params.is_empty():
		_apply_screen_settings()
	_on_enter_tree()


func _exit_tree() -> void:
	_restore_state()
	_on_exit_tree()


func _input(event: InputEvent) -> void:
	# Handle back navigation
	if allow_back and event.is_action_pressed("ui_cancel"):
		_request_back()
		get_viewport().set_input_as_handled()
		return

	# CRITICAL: Consume all game inputs when this menu screen is visible
	# This prevents game controls from firing while in menus
	var game_actions: Array[String] = [
		"jump",
		"reload",
		"crouch",
		"sprint",
		"interact",
		"melee",
		"dodge",
		"respawn",
		"up",
		"down",
		"left",
		"right",
		"pause",
		"scoreboard",
		"weapon_1",
		"weapon_2",
		"weapon_3",
		"weapon_4",
		"weapon_5",
		"weapon_6",
		"weapon_7",
		"weapon_8",
		"weapon_9",
		"quick_weapon_switch",
		"inventory",
		"skill_tree",
		"chat_toggle"
	]

	for action: String in game_actions:
		# Only check if the action exists in InputMap
		if InputMap.has_action(action) and event.is_action(action):
			get_viewport().set_input_as_handled()
			return


# ============================================================================
# SETUP
# ============================================================================

## Called by UIManager when screen is opened


func setup(params: Dictionary) -> void:
	_screen_params = params
	if is_inside_tree():
		_apply_screen_settings()
	_on_screen_enter(params)


func _apply_screen_settings() -> void:
	# Handle pause
	if pause_on_show:
		_was_paused = get_tree().paused
		get_tree().paused = true

	# Handle cursor - make mouse visible for UI interaction
	_prev_mouse_mode = Input.mouse_mode
	if show_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Setup focus group
	# Setup focus group
	var ui_svc := UISystem.get_service()
	if not focus_group.is_empty() and ui_svc and ui_svc.focus_manager:
		if ui_svc.focus_manager.has_method("set_active_group"):
			ui_svc.focus_manager.set_active_group(focus_group)


func _restore_state() -> void:
	# Restore pause state
	if pause_on_show and not _was_paused:
		get_tree().paused = false

	# Restore mouse mode
	Input.mouse_mode = _prev_mouse_mode


# ============================================================================
# NAVIGATION
# ============================================================================


func _request_back() -> void:
	# Prevent multiple back requests during transition
	var ui_svc := UISystem.get_service()
	if (
		ui_svc
		and ui_svc.ui_manager
		and ui_svc.ui_manager.is_transitioning()
	):
		return
	
	screen_exiting.emit()
	back_requested.emit()

	# CRITICAL: Restore state BEFORE navigating back (fixes pause menu resume)
	_restore_state()

	if ui_svc and ui_svc.ui_manager:
		if not back_destination.is_empty():
			ui_svc.ui_manager.open_screen(back_destination)
		else:
			ui_svc.ui_manager.back()


## Navigate to another screen (push to stack)


func navigate_to(screen_path: String, params: Dictionary = {}) -> void:
	print("[BaseScreen] navigate_to called with path: ", screen_path)
	var ui_svc := UISystem.get_service()
	print("[BaseScreen] UISystem.get_service() returned: ", ui_svc)
	
	if not ui_svc:
		push_error("[BaseScreen] UISystem service is null!")
		return
	
	print(
		"[BaseScreen] ui_svc.ui_manager: ",
		ui_svc.ui_manager if "ui_manager" in ui_svc else "property not found"
	)
	
	if not ui_svc.ui_manager:
		push_error("[BaseScreen] ui_manager is null!")
		return
	
	print("[BaseScreen] Calling ui_manager.push_screen...")
	ui_svc.ui_manager.push_screen(screen_path, params)


## Navigate to another screen (replace - no stack)


func switch_to(screen_path: String, params: Dictionary = {}) -> void:
	var ui_svc := UISystem.get_service()
	if ui_svc and ui_svc.ui_manager:
		ui_svc.ui_manager.open_screen(screen_path, params)


## Show a modal dialog


func show_modal(modal_path: String, params: Dictionary = {}) -> Control:
	print("[BaseScreen] show_modal called with path: ", modal_path)
	var ui_svc := UISystem.get_service()
	print("[BaseScreen] UISystem.get_service() returned: ", ui_svc)
	
	if not ui_svc:
		push_error("[BaseScreen] UISystem service is null!")
		return null
	
	print(
		"[BaseScreen] ui_svc.ui_manager: ",
		ui_svc.ui_manager if "ui_manager" in ui_svc else "property not found"
	)
	
	if not ui_svc.ui_manager:
		push_error("[BaseScreen] ui_manager is null!")
		return null
	
	print("[BaseScreen] Calling ui_manager.push_modal...")
	return await ui_svc.ui_manager.push_modal(modal_path, params)


## Go back to previous screen


func go_back() -> void:
	_request_back()


# ============================================================================
# FOCUS MANAGEMENT
# ============================================================================

## Register controls for focus navigation


func register_focus_controls(controls: Array[Control], group_id: String = "") -> void:
	var ui_svc := UISystem.get_service()
	if not ui_svc or not ui_svc.focus_manager:
		return

	var gid: String = group_id if not group_id.is_empty() else screen_id
	focus_group = gid
	if ui_svc.focus_manager.has_method("register_focus_group"):
		ui_svc.focus_manager.register_focus_group(gid, controls)


## Focus the first control in the focus group


func focus_first() -> void:
	var ui_svc := UISystem.get_service()
	if ui_svc and ui_svc.focus_manager:
		if ui_svc.focus_manager.has_method("focus_first"):
			ui_svc.focus_manager.focus_first()


## Focus a specific control


func focus_control(control: Control) -> void:
	var ui_svc := UISystem.get_service()
	if ui_svc and ui_svc.focus_manager:
		if ui_svc.focus_manager.has_method("focus_control"):
			ui_svc.focus_manager.focus_control(control)
	elif control:
		control.grab_focus()


# ============================================================================
# VIRTUAL METHODS (Override in subclasses)
# ============================================================================

## Called during _ready after base initialization


func _on_ready() -> void:
	pass


## Called when entering the scene tree


func _on_enter_tree() -> void:
	pass


## Called when exiting the scene tree


func _on_exit_tree() -> void:
	pass


## Called when screen is opened with params


func _on_screen_enter(screen_setup_params: Dictionary) -> void:
	screen_setup_params.size()  # Suppress unused warning
	screen_entered.emit()


## Called when screen transition completes


func _on_transition_complete() -> void:
	pass


## Called when screen is about to close


func _on_screen_exit() -> void:
	screen_exiting.emit()


# ============================================================================
# UTILITIES
# ============================================================================

## Get a parameter value with default


func get_param(key: String, default: Variant = null) -> Variant:
	return _screen_params.get(key, default)


## Check if a parameter exists


func has_param(key: String) -> bool:
	return _screen_params.has(key)


## Get screen ID


func get_screen_id() -> String:
	return screen_id


## Helper to access UIManager
@warning_ignore("unused_private_class_variable")
var _ui_manager_ref: Node:
	get:
		var svc := UISystem.get_service()
		return svc.ui_manager if svc else null
