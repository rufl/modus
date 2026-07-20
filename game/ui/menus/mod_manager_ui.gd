class_name ModManagerUI
extends Control

@onready var mod_list: VBoxContainer = %ModList
@onready var description_label: Label = %DescriptionLabel
@onready var author_label: Label = %AuthorLabel
@onready var version_label: Label = %VersionLabel
@onready var enable_button: Button = %EnableButton
@onready var move_up_button: Button = %MoveUpButton
@onready var move_down_button: Button = %MoveDownButton
@onready var reload_button: Button = %ReloadButton
@onready var close_button: Button = %CloseButton

var _mod_loader: Node = null
var _selected_mod: Dictionary = {}
var _mod_buttons: Dictionary = {}  # mod_id -> Button


func _ready() -> void:
	# Add to group so other systems can find us
	add_to_group("mod_manager_ui")
	add_to_group("mouse_stealers")

	# Find mod loader
	_mod_loader = get_tree().get_first_node_in_group("mod_loader")
	if not _mod_loader:
		# Try autoload
		_mod_loader = GameManager.get_core_system("mod_loader")

	# Connect buttons
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if enable_button:
		enable_button.pressed.connect(_on_enable_pressed)
	if move_up_button:
		move_up_button.pressed.connect(_on_move_up_pressed)
	if move_down_button:
		move_down_button.pressed.connect(_on_move_down_pressed)
	if reload_button:
		reload_button.pressed.connect(_on_reload_pressed)

	# Initial populate
	_populate_mod_list()

	# Hide by default
	visible = false


func _input(event: InputEvent) -> void:
	if InputMap.has_action("mod_manager") and event.is_action_pressed("mod_manager"):
		toggle_visibility()
		get_viewport().set_input_as_handled()

	# Close on ESC
	if event.is_action_pressed("ui_cancel") and visible:
		hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


## Toggle visibility


func toggle_visibility() -> void:
	if visible:
		hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		show_manager()


## Show the mod manager


func show_manager() -> void:
	_populate_mod_list()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Populate the mod list


func _populate_mod_list() -> void:
	if not mod_list:
		return

	# Clear existing
	for child: Node in mod_list.get_children():
		child.queue_free()
	_mod_buttons.clear()

	# Get mods from loader
	if not _mod_loader:
		_add_no_mods_label()
		return

	var mods: Array = []
	if _mod_loader.has_method("get_installed_mods"):
		mods = _mod_loader.get_installed_mods()

	if mods.is_empty():
		_add_no_mods_label()
		return

	# Add mod entries
	for mod_info: Dictionary in mods:
		_add_mod_entry(mod_info)


func _add_no_mods_label() -> void:
	var label: Label = Label.new()
	label.text = "No mods installed.\nPlace mods in the 'mods' folder."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mod_list.add_child(label)


func _add_mod_entry(mod_info: Dictionary) -> void:
	var mod_id: String = mod_info.get("id", "unknown")
	var mod_name: String = mod_info.get("name", mod_id)
	var enabled: bool = mod_info.get("enabled", true)
	var priority: int = mod_info.get("priority", 0)

	var button: Button = Button.new()
	button.text = "[%s] %s (Priority: %d)" % ["ON" if enabled else "OFF", mod_name, priority]
	button.toggle_mode = false
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(func() -> void: _on_mod_selected(mod_info))

	# Style based on enabled state
	if not enabled:
		button.modulate = Color(0.6, 0.6, 0.6, 1.0)

	mod_list.add_child(button)
	_mod_buttons[mod_id] = button


## Called when a mod is selected


func _on_mod_selected(mod_info: Dictionary) -> void:
	_selected_mod = mod_info

	# Update info panel
	if description_label:
		description_label.text = mod_info.get("description", "No description")
	if author_label:
		author_label.text = "Author: %s" % mod_info.get("author", "Unknown")
	if version_label:
		version_label.text = "Version: %s" % mod_info.get("version", "1.0.0")

	# Update enable button text
	if enable_button:
		var enabled: bool = mod_info.get("enabled", true)
		enable_button.text = "Disable" if enabled else "Enable"


func _on_enable_pressed() -> void:
	if _selected_mod.is_empty():
		return

	var mod_id: String = _selected_mod.get("id", "")
	if mod_id.is_empty():
		return

	# Toggle enabled state
	var enabled: bool = _selected_mod.get("enabled", true)
	_selected_mod["enabled"] = not enabled

	# Update mod loader config
	if _mod_loader and _mod_loader.has_method("set_mod_enabled"):
		_mod_loader.set_mod_enabled(mod_id, not enabled)

	# Refresh UI
	_populate_mod_list()
	_on_mod_selected(_selected_mod)


func _on_move_up_pressed() -> void:
	if _selected_mod.is_empty():
		return

	var mod_id: String = _selected_mod.get("id", "")
	if mod_id.is_empty():
		return

	# Increase priority (lower number = loads first)
	if _mod_loader and _mod_loader.has_method("change_mod_priority"):
		_mod_loader.change_mod_priority(mod_id, -1)
		_populate_mod_list()


func _on_move_down_pressed() -> void:
	if _selected_mod.is_empty():
		return

	var mod_id: String = _selected_mod.get("id", "")
	if mod_id.is_empty():
		return

	# Decrease priority (higher number = loads later)
	if _mod_loader and _mod_loader.has_method("change_mod_priority"):
		_mod_loader.change_mod_priority(mod_id, 1)
		_populate_mod_list()


func _on_reload_pressed() -> void:
	if _mod_loader and _mod_loader.has_method("reload_mods"):
		_mod_loader.reload_mods()
		_populate_mod_list()
		GameManager.get_core_system("logger").info("[ModManagerUI] Mods reloaded", "UI")


func _on_close_pressed() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
