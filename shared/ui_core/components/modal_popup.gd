class_name ModalPopup
extends Control

signal confirmed(data: Variant)
signal cancelled
signal closed

@export_group("Content")
@export var title: String = "Modal"
@export var message: String = ""
@export_group("Behavior")
@export var close_on_escape: bool = true
@export var close_on_backdrop_click: bool = false
@export var play_close_sound: bool = true
@export_group("Appearance")
@export var min_size: Vector2 = Vector2(300, 150)
@export var max_size: Vector2 = Vector2(600, 400)

var _panel: PanelContainer = null
var _vbox: VBoxContainer = null
var _title_label: Label = null
var _message_label: Label = null
var _content_container: VBoxContainer = null
var _button_container: HBoxContainer = null
var _close_button: Button = null
var _buttons: Array[Dictionary] = []
var _result_data: Variant = null
var _focus_group_id: String = ""


func _ready() -> void:
	_focus_group_id = "modal_%d" % get_instance_id()
	_build_ui()
	_connect_signals()

	# Register with ThemeManager
	var theme_mgr: Node = get_node_or_null("/root/ThemeManager")
	if theme_mgr:
		theme_mgr.register_themeable(self)

	# Initial focus registration (if default buttons exist)
	call_deferred("_update_focus_management")


func _exit_tree() -> void:
	_cleanup_focus_management()
	
	# Disconnect close button signal to prevent memory leak
	if _close_button and _close_button.pressed.is_connected(_on_close_pressed):
		_close_button.pressed.disconnect(_on_close_pressed)
	
	# Disconnect all button callbacks
	for btn_data: Dictionary in _buttons:
		if btn_data.has("button") and btn_data.button:
			var button: Button = btn_data.button
			var callback: Callable = btn_data.get("callback", Callable())
			
			if callback.is_valid() and button.pressed.is_connected(callback):
				button.pressed.disconnect(callback)
			elif btn_data.get("is_cancel", false) and button.pressed.is_connected(cancel):
				button.pressed.disconnect(cancel)
			elif button.pressed.is_connected(_on_default_confirm):
				button.pressed.disconnect(_on_default_confirm)


func _build_ui() -> void:
	# Self setup (full screen container)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Panel (centered)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = min_size
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	# VBox for content
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(_vbox)

	# Header with title and close button
	var header: HBoxContainer = HBoxContainer.new()
	_vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = title
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_close_button = Button.new()
	_close_button.text = "✕"
	_close_button.flat = true
	_close_button.custom_minimum_size = Vector2(32, 32)
	_close_button.pressed.connect(_on_close_pressed)
	header.add_child(_close_button)

	# Separator
	_vbox.add_child(HSeparator.new())

	# Message label
	_message_label = Label.new()
	_message_label.text = message
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.visible = not message.is_empty()
	_vbox.add_child(_message_label)

	# Content container (for subclass additions)
	_content_container = VBoxContainer.new()
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(_content_container)

	# Button container
	_vbox.add_child(HSeparator.new())

	_button_container = HBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_END
	_button_container.add_theme_constant_override("separation", 8)
	_vbox.add_child(_button_container)

	# Add default buttons if none configured
	if _buttons.is_empty():
		call_deferred("_add_default_buttons")


func _add_default_buttons() -> void:
	# Only add if still empty (subclass might have added in _ready)
	if _buttons.is_empty():
		add_button("OK", _on_default_confirm)


func _connect_signals() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if close_on_escape and event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()


# ============================================================================
# BUTTON MANAGEMENT
# ============================================================================

## Add a button to the modal


func add_button(
	text: String, callback: Callable = Callable(), is_cancel: bool = false, style: String = "normal"
) -> Button:
	var button: Button

	# Use CustomButton if available
	if ClassDB.class_exists("CustomButton"):
		button = CustomButton.new()
	else:
		button = Button.new()

	button.text = text

	# Style variants
	match style:
		"primary":
			button.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0))
		"danger":
			button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	# Connect callback
	if callback.is_valid():
		button.pressed.connect(callback)
	elif is_cancel:
		button.pressed.connect(cancel)
	else:
		button.pressed.connect(_on_default_confirm)

	_button_container.add_child(button)

	_buttons.append({"text": text, "callback": callback, "is_cancel": is_cancel, "button": button})

	# Focus first non-cancel button
	if _buttons.size() == 1 or not is_cancel:
		button.call_deferred("grab_focus")

	return button


## Remove all buttons


func clear_buttons() -> void:
	for btn_data: Dictionary in _buttons:
		if btn_data.button:
			btn_data.button.queue_free()
	_buttons.clear()


# ============================================================================
# CONTENT MANAGEMENT
# ============================================================================

## Get the content container (for adding custom content)


func get_content_container() -> VBoxContainer:
	return _content_container


## Add a control to the content area


func add_content(control: Control) -> void:
	_content_container.add_child(control)


# ============================================================================
# SETUP
# ============================================================================

## Called by UIManager when modal is shown with params


func setup(params: Dictionary) -> void:
	if params.has("title"):
		title = params.title
		if _title_label:
			_title_label.text = title

	if params.has("message"):
		message = params.message
		if _message_label:
			_message_label.text = message
			_message_label.visible = not message.is_empty()

	if params.has("buttons"):
		clear_buttons()
		for btn_config: Dictionary in params.buttons:
			add_button(
				btn_config.get("text", "Button"),
				btn_config.get("callback", Callable()),
				btn_config.get("is_cancel", false),
				btn_config.get("style", "normal")
			)

	# Update focus group with new buttons
	call_deferred("_update_focus_management")

	# Subclasses can override for custom params
	_on_setup(params)


## Override in subclass for custom setup handling


func _on_setup(_params: Dictionary) -> void:
	pass


# ============================================================================
# ACTIONS
# ============================================================================

## Confirm and close the modal


func confirm(data: Variant = null) -> void:
	_result_data = data
	confirmed.emit(data)
	_close()


## Cancel and close the modal


func cancel() -> void:
	cancelled.emit()
	_close()


func _close() -> void:
	var audio: Node = GameManager.get_core_system("audio")
	if play_close_sound and GameManager and audio and audio.has_method("play_sound"):
		audio.play_sound("ui_back")

	closed.emit()

	# Let UIManager handle the actual removal
	var ui_mgr: Node = get_node_or_null("/root/UIManager")
	if ui_mgr:
		ui_mgr.dismiss_modal()
	else:
		queue_free()


func _on_close_pressed() -> void:
	cancel()


func _on_default_confirm() -> void:
	confirm()


# ============================================================================
# ACCESSORS
# ============================================================================

## Get the result data (after confirm)


func get_result() -> Variant:
	return _result_data


## Set focus to the first button


func focus_first_button() -> void:
	if not _buttons.is_empty() and _buttons[0].button:
		_buttons[0].button.grab_focus()


## Update focus manager group for this modal


func _update_focus_management() -> void:
	if not GameManager:
		return

	var fm: Object = GameManager.get_core_system("focus")
	if not fm:
		return

	# Collect buttons
	var focus_targets: Array[Control] = []
	for b in _buttons:
		if b.button:
			focus_targets.append(b.button)

	# Register and push group
	if fm.has_method("register_focus_group"):
		fm.register_focus_group(_focus_group_id, focus_targets)
	if fm.has_method("push_active_group"):
		fm.push_active_group(_focus_group_id)


## Cleanup focus group


func _cleanup_focus_management() -> void:
	if not GameManager:
		return

	var fm: Object = GameManager.get_core_system("focus")
	if not fm:
		return

	if fm.has_method("get_active_group") and fm.get_active_group() == _focus_group_id:
		if fm.has_method("pop_active_group"):
			fm.pop_active_group()

	if fm.has_method("unregister_focus_group"):
		fm.unregister_focus_group(_focus_group_id)
