class_name SaveLoadScreen
extends BaseScreen

var _slot_list: ItemList = null
var _new_save_input: LineEdit = null
var _save_btn: Button = null
var _load_btn: Button = null
var _delete_btn: Button = null


func _on_ready() -> void:
	_build_ui()
	_refresh_slots()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 0.1
	panel.anchor_bottom = 0.9
	add_child(panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 20)
	margins.add_theme_constant_override("margin_right", 20)
	margins.add_theme_constant_override("margin_top", 20)
	margins.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margins)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margins.add_child(vbox)

	var title := Label.new()
	title.text = "SAVE & LOAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	# Left Column: List
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_vbox)

	var slot_label := Label.new()
	slot_label.text = "Select Slot"
	left_vbox.add_child(slot_label)
	_slot_list = ItemList.new()
	_slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(_slot_list)

	# Right Column: Controls
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 15)
	hbox.add_child(right_vbox)

	var name_label := Label.new()
	name_label.text = "Save Name"
	right_vbox.add_child(name_label)
	_new_save_input = LineEdit.new()
	_new_save_input.placeholder_text = "Enter name..."
	right_vbox.add_child(_new_save_input)

	_save_btn = _create_btn("SAVE", _on_save_pressed)
	right_vbox.add_child(_save_btn)

	right_vbox.add_child(HSeparator.new())

	_load_btn = _create_btn("LOAD / PLAY", _on_load_pressed)
	right_vbox.add_child(_load_btn)

	_delete_btn = _create_btn("DELETE", _on_delete_pressed)
	_delete_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	right_vbox.add_child(_delete_btn)

	# Footer
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(footer)

	var back_btn := _create_btn("BACK", go_back)
	footer.add_child(back_btn)

	register_focus_controls(
		[_new_save_input, _save_btn, _load_btn, _delete_btn, back_btn], "save_load"
	)


func _create_btn(text: String, callback: Callable) -> Button:
	var btn: Button
	if ClassDB.class_exists("CustomButton"):
		btn = CustomButton.new()
	else:
		btn = Button.new()
	btn.text = text
	btn.custom_minimum_size.y = 40
	btn.pressed.connect(callback)
	return btn


func _refresh_slots() -> void:
	if not _slot_list:
		return
	_slot_list.clear()

	var save_dir := "user://saves/"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

	var dir := DirAccess.open(save_dir)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with("_progression.json"):
				var slot_name := file_name.replace("_progression.json", "")
				_slot_list.add_item(slot_name)
			file_name = dir.get_next()


func _get_local_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p.is_multiplayer_authority():
			return p
	return null


func _on_save_pressed() -> void:
	var slot_name := _new_save_input.text.strip_edges()
	if slot_name.is_empty() and _slot_list.is_anything_selected():
		slot_name = _slot_list.get_item_text(_slot_list.get_selected_items()[0])

	if slot_name.is_empty():
		return

	var player: Player = _get_local_player() as Player
	if player and player.has_node("Progression"):
		player.get_node("Progression").save_progression(slot_name)
		_new_save_input.text = ""
		_refresh_slots()
	else:
		# If in lobby, we start session with this slot
		_start_session(slot_name)


func _on_load_pressed() -> void:
	if not _slot_list.is_anything_selected():
		return
	var slot_name := _slot_list.get_item_text(_slot_list.get_selected_items()[0])

	var player: Player = _get_local_player() as Player
	if player and player.has_node("Progression"):
		var globals: Node = GameManager.get_core_system("globals")
		if globals and "current_save_slot" in globals:
			globals.current_save_slot = slot_name
		player.get_node("Progression").load_progression(slot_name)
		var us := UISystem.get_service()
		if us and us.ui_manager:
			us.ui_manager.back()
	else:
		_start_session(slot_name)


func _on_delete_pressed() -> void:
	if not _slot_list.is_anything_selected():
		return
	var slot_name := _slot_list.get_item_text(_slot_list.get_selected_items()[0])

	await show_modal(
		"res://shared/ui_core/components/modal_popup.tscn",
		{
			"title": "Delete Save",
			"message": "Are you sure you want to delete '%s'?" % slot_name,
			"buttons":
			[
				{
					"text": "Delete",
					"callback": func() -> void: _do_delete(slot_name),
					"style": "danger"
				},
				{"text": "Cancel", "is_cancel": true}
			]
		}
	)


func _do_delete(slot_name: String) -> void:
	var path := "user://saves/" + slot_name + "_progression.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_refresh_slots()


func _start_session(slot_name: String) -> void:
	var globals: Node = GameManager.get_core_system("globals")
	if globals and "current_save_slot" in globals:
		globals.current_save_slot = slot_name
	# Trigger match start via EventBus or direct world call
	if GameManager and GameManager.has_method("emit_event"):
		GameManager.emit_event("play_requested", {"slot_name": slot_name})

	# Normally we'd transition to the world scene or just start if already there
	# For now, let's assume world.gd listens for "play_requested" if we are in Lobby
	var us := UISystem.get_service()
	if us and us.ui_manager:
		us.ui_manager.back()  # Return to where we came from, or direct to world
