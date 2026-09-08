class_name ModManagerUI
extends Control

signal close_requested

@onready var safe_margins: MarginContainer = %SafeMargins
@onready var main_panel: PanelContainer = %MainPanel
@onready var main_container: BoxContainer = %MainContainer
@onready var left_panel: VBoxContainer = %LeftPanel
@onready var right_panel: VBoxContainer = %RightPanel
@onready var title_label: Label = %Title
@onready var info_title: Label = %InfoTitle
@onready var scroll_container: ScrollContainer = left_panel.get_node("ScrollContainer")
@onready var mod_list: VBoxContainer = %ModList
@onready var description_label: Label = %DescriptionLabel
@onready var author_label: Label = %AuthorLabel
@onready var version_label: Label = %VersionLabel
@onready var status_label: Label = %StatusLabel
@onready var enable_button: Button = %EnableButton
@onready var move_up_button: Button = %MoveUpButton
@onready var move_down_button: Button = %MoveDownButton
@onready var reload_button: Button = %ReloadButton
@onready var close_button: Button = %CloseButton

var _mod_loader: Node = null
var _selected_mod: Dictionary = {}
var _selected_mod_id: String = ""
var _mod_buttons: Dictionary = {}
var _mod_button_group := ButtonGroup.new()
var _embedded: bool = false


func _ready() -> void:
	add_to_group("mod_manager_ui")
	add_to_group("mouse_stealers")

	_mod_loader = get_tree().get_first_node_in_group("mod_loader")
	if not _mod_loader:
		_mod_loader = GameManager.get_core_system("mod_loader")

	close_button.visible = not _embedded
	close_button.pressed.connect(_request_close)
	enable_button.pressed.connect(_on_enable_pressed)
	move_up_button.pressed.connect(_on_move_up_pressed)
	move_down_button.pressed.connect(_on_move_down_pressed)
	reload_button.pressed.connect(_on_reload_pressed)
	resized.connect(_update_responsive_layout)

	var localization: Node = GameManager.get_core_system("localization")
	if localization and localization.has_signal("language_changed"):
		localization.language_changed.connect(_on_language_changed)

	_refresh_static_copy()
	_populate_mod_list()
	_update_responsive_layout()
	hide()


func _input(event: InputEvent) -> void:
	if InputMap.has_action("mod_manager") and event.is_action_pressed("mod_manager"):
		if visible:
			_request_close()
		else:
			show_manager()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and visible:
		_request_close()
		get_viewport().set_input_as_handled()


func set_embedded(embedded: bool) -> void:
	_embedded = embedded
	if close_button:
		close_button.visible = not embedded


func toggle_visibility() -> void:
	if visible:
		_request_close()
	else:
		show_manager()


func show_manager() -> void:
	_populate_mod_list()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	call_deferred("focus_default")


func focus_default() -> void:
	if not _mod_buttons.is_empty():
		var first_button := _mod_buttons.values()[0] as Button
		if first_button:
			first_button.grab_focus()
	else:
		reload_button.grab_focus()


func _populate_mod_list() -> void:
	if not mod_list:
		return

	for child: Node in mod_list.get_children():
		child.queue_free()
	_mod_buttons.clear()

	if not _mod_loader or not _mod_loader.has_method("get_installed_mods"):
		_add_empty_label(_tr("mods_loader_unavailable", "Mod loader is unavailable."))
		_set_status(_tr("mods_loader_recovery", "Return to the menu and try again."), true)
		_clear_selection()
		return

	var mods: Array = _mod_loader.get_installed_mods()
	if mods.is_empty():
		_add_empty_label(
			_tr("mods_empty", "No mods installed. Place packages in the mods folder, then reload.")
		)
		_clear_selection()
		return

	for mod_info: Dictionary in mods:
		_add_mod_entry(mod_info)

	if not _selected_mod_id.is_empty():
		_select_mod_by_id(_selected_mod_id, mods)
	else:
		_clear_selection()


func _add_empty_label(message: String) -> void:
	var label := Label.new()
	label.custom_minimum_size.y = 72
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mod_list.add_child(label)


func _add_mod_entry(mod_info: Dictionary) -> void:
	var mod_id: String = mod_info.get("id", "unknown")
	var mod_name: String = mod_info.get("name", mod_id)
	var enabled: bool = mod_info.get("enabled", false)
	var priority: int = mod_info.get("priority", 0)
	var state := (
		_tr("mods_state_enabled", "Enabled") if enabled else _tr("mods_state_disabled", "Disabled")
	)

	var button := Button.new()
	button.custom_minimum_size.y = 48
	button.focus_mode = Control.FOCUS_ALL
	button.toggle_mode = true
	button.button_group = _mod_button_group
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "%s — %s · %s %d" % [mod_name, state, _tr("mods_priority", "Priority"), priority]
	button.tooltip_text = mod_info.get("description", "")
	button.pressed.connect(_on_mod_selected.bind(mod_info))
	if not enabled:
		button.modulate = Color(0.72, 0.76, 0.82, 1.0)

	mod_list.add_child(button)
	_mod_buttons[mod_id] = button


func _on_mod_selected(mod_info: Dictionary) -> void:
	_selected_mod = mod_info
	_selected_mod_id = mod_info.get("id", "")
	description_label.text = mod_info.get(
		"description", _tr("mods_no_description", "No description provided.")
	)
	author_label.text = _tr("mods_author", "Author: {author}").format(
		{"author": mod_info.get("author", _tr("mods_unknown", "Unknown"))}
	)
	version_label.text = _tr("mods_version", "Version: {version}").format(
		{"version": mod_info.get("version", "1.0.0")}
	)

	var enabled: bool = mod_info.get("enabled", false)
	enable_button.text = _tr("mods_disable", "Disable") if enabled else _tr("mods_enable", "Enable")
	enable_button.disabled = false
	move_up_button.disabled = false
	move_down_button.disabled = false

	var button: Button = _mod_buttons.get(_selected_mod_id)
	if button:
		button.set_pressed_no_signal(true)


func _clear_selection() -> void:
	_selected_mod = {}
	_selected_mod_id = ""
	description_label.text = _tr("mods_select_prompt", "Select a mod to view details.")
	author_label.text = _tr("mods_author_empty", "Author: -")
	version_label.text = _tr("mods_version_empty", "Version: -")
	enable_button.text = _tr("mods_enable", "Enable")
	enable_button.disabled = true
	move_up_button.disabled = true
	move_down_button.disabled = true


func _select_mod_by_id(mod_id: String, mods: Array) -> void:
	for mod_info: Dictionary in mods:
		if mod_info.get("id", "") == mod_id:
			_on_mod_selected(mod_info)
			return
	_clear_selection()


func _on_enable_pressed() -> void:
	if _selected_mod.is_empty() or not _mod_loader:
		return

	var enabled: bool = _selected_mod.get("enabled", false)
	_mod_loader.set_mod_enabled(_selected_mod_id, not enabled)
	_selected_mod["enabled"] = not enabled
	_set_status(_tr("mods_pending_reload", "Change saved. Reload Mods to apply it."))
	_populate_mod_list()


func _on_move_up_pressed() -> void:
	_change_priority(-1)


func _on_move_down_pressed() -> void:
	_change_priority(1)


func _change_priority(delta: int) -> void:
	if _selected_mod.is_empty() or not _mod_loader:
		return
	_mod_loader.change_mod_priority(_selected_mod_id, delta)
	_set_status(_tr("mods_priority_saved", "Priority saved. Reload Mods to apply it."))
	_populate_mod_list()


func _on_reload_pressed() -> void:
	if not _mod_loader or not _mod_loader.has_method("reload_mods"):
		_set_status(
			_tr("mods_reload_failed", "Reload failed because the mod loader is unavailable."), true
		)
		return

	_mod_loader.reload_mods()
	var loaded_count: int = _mod_loader.get_loaded_mods().size()
	_set_status(
		_tr("mods_reloaded", "Reload complete: {count} enabled mod(s).").format(
			{"count": loaded_count}
		)
	)
	_populate_mod_list()


func _request_close() -> void:
	close_requested.emit()
	if not _embedded:
		hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh_static_copy() -> void:
	title_label.text = _tr("mods_title", "Mod Manager")
	info_title.text = _tr("mods_information", "Mod Information")
	move_up_button.text = _tr("mods_move_up", "Move Up")
	move_down_button.text = _tr("mods_move_down", "Move Down")
	reload_button.text = _tr("mods_reload", "Reload Mods")
	close_button.text = _tr("mods_close", "Close")
	if _selected_mod.is_empty():
		_clear_selection()
	else:
		_on_mod_selected(_selected_mod)


func _on_language_changed(_language: String) -> void:
	_refresh_static_copy()
	_populate_mod_list()


func _update_responsive_layout() -> void:
	if not main_panel or not main_container:
		return
	var narrow := size.x < 760.0 or size.y < 560.0
	var edge := 12 if narrow else 24
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		safe_margins.add_theme_constant_override(side, edge)
	main_panel.custom_minimum_size = Vector2(
		clampf(size.x - edge * 2.0, 320.0, 900.0), clampf(size.y - edge * 2.0, 400.0, 560.0)
	)
	main_container.vertical = narrow
	main_container.add_theme_constant_override("separation", 14 if narrow else 24)
	scroll_container.custom_minimum_size.y = 140.0 if narrow else 220.0
	left_panel.custom_minimum_size.y = 170.0 if narrow else 0.0
	right_panel.custom_minimum_size.y = 190.0 if narrow else 0.0


func _set_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_label.add_theme_color_override(
		"font_color", Color(1.0, 0.58, 0.58) if is_error else Color(0.58, 0.72, 0.9)
	)


func _tr(key: String, fallback: String) -> String:
	var localization: Node = GameManager.get_core_system("localization")
	if localization and localization.has_method("translate"):
		var translated: String = localization.translate(key)
		return translated if translated != key else fallback
	return fallback
