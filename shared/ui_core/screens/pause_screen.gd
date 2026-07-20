class_name PauseScreen
extends BaseScreen

const OPTIONS_SCREEN: String = "res://shared/ui_core/screens/options_screen.tscn"
const SAVE_LOAD_SCREEN: String = "res://shared/ui_core/screens/save_load_screen.tscn"
const MAIN_MENU_SCREEN: String = "res://shared/ui_core/screens/main_menu_screen.tscn"


func _on_ready() -> void:
	pause_on_show = true
	_build_pause_ui()


func is_transitioning() -> bool:
	var ui_svc := UISystem.get_service()
	if ui_svc and ui_svc.ui_manager:
		return ui_svc.ui_manager.is_transitioning()
	return false


func _on_screen_enter(_params: Dictionary) -> void:
	# Ensure focus manager is active and initial button has focus
	var ui_svc := UISystem.get_service()
	if ui_svc and ui_svc.focus_manager:
		ui_svc.focus_manager.set_enabled(true)
		ui_svc.focus_manager.set_active_group("pause_menu")

	# Defer focus grab to ensure UI is ready
	if is_inside_tree():
		await get_tree().process_frame
	var resume_btn: Button = _find_resume_button()
	if resume_btn:
		resume_btn.grab_focus()


func _find_resume_button() -> Button:
	# Find the Resume button in the UI hierarchy
	var buttons: Array[Node] = find_children("*", "Button", true, false)
	for btn: Node in buttons:
		if btn is Button and btn.text == "Resume":
			return btn as Button
	return null


func _build_pause_ui() -> void:
	var margins: MarginContainer = MarginContainer.new()
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 100)
	margins.add_theme_constant_override("margin_right", 100)
	margins.add_theme_constant_override("margin_top", 100)
	margins.add_theme_constant_override("margin_bottom", 100)
	add_child(margins)

	var center: CenterContainer = CenterContainer.new()
	margins.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 200)
	center.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var resume_btn := _create_menu_button("Resume", _on_resume_pressed)
	vbox.add_child(resume_btn)

	var options_btn := _create_menu_button("Options", _on_options_pressed)
	vbox.add_child(options_btn)

	var save_btn := _create_menu_button("Save / Load", _on_save_load_pressed)
	vbox.add_child(save_btn)

	# Open to LAN button (only show if not already in multiplayer)
	var lan_btn: Button = null
	if not multiplayer.has_multiplayer_peer():
		lan_btn = _create_menu_button("Open to LAN", _on_open_to_lan_pressed)
		vbox.add_child(lan_btn)

	var quit_menu_btn := _create_menu_button("Quit to Main Menu", _on_quit_menu_pressed)
	vbox.add_child(quit_menu_btn)

	var quit_desk_btn := _create_menu_button("Quit to Desktop", _on_quit_desktop_pressed)
	vbox.add_child(quit_desk_btn)

	# Initial focus
	resume_btn.grab_focus()
	
	# Build focus list dynamically
	var focus_list: Array[Control] = [resume_btn, options_btn, save_btn]
	
	# Add LAN button to focus if it exists
	for child in vbox.get_children():
		if child is Button and child.text == "Open to LAN":
			focus_list.append(child)
			break
	
	focus_list.append(quit_menu_btn)
	focus_list.append(quit_desk_btn)
	
	register_focus_controls(focus_list, "pause_menu")


func _create_menu_button(label: String, callback: Callable) -> Button:
	var btn: Button
	# Force CustomButton usage if possible, otherwise plain Button
	if ClassDB.class_exists("CustomButton"):
		btn = ClassDB.instantiate("CustomButton")
	else:
		btn = Button.new()

	btn.text = label
	btn.custom_minimum_size = Vector2(250, 45)
	
	# Wrap callback to prevent spam during transitions
	var wrapped_callback := func() -> void:
		if is_transitioning():
			return
		callback.call()
	
	btn.pressed.connect(wrapped_callback)
	return btn


func _on_resume_pressed() -> void:
	# Prevent multiple clicks during transition
	if is_transitioning():
		return
	go_back()


func _on_options_pressed() -> void:
	navigate_to(OPTIONS_SCREEN)


func _on_save_load_pressed() -> void:
	navigate_to(SAVE_LOAD_SCREEN)


func _on_open_to_lan_pressed() -> void:
	# Show a simple dialog to open the game to LAN
	await show_modal(
		"res://shared/ui_core/components/modal_popup.tscn",
		{
			"title": "Open to LAN",
			"message":
			(
				"Open your game to LAN? Other players can join via the multiplayer menu."
				+ "\n\nDefault port: 7777\nMax players: 8"
			),
			"buttons":
			[
				{
					"text": "Open to LAN",
					"callback": _start_lan_server,
					"style": "primary"
				},
				{"text": "Cancel", "is_cancel": true}
			]
		}
	)


func _start_lan_server() -> void:
	# Get network manager and start hosting
	var ns := NetworkSvc.get_service()
	if ns and ns.network_manager:
		var err: Error = ns.network_manager.host_game(7777, 8)
		if err == OK:
			# Show success message
			await show_modal(
				"res://shared/ui_core/components/modal_popup.tscn",
				{
					"title": "LAN Server Started",
					"message":
					(
						"Your game is now open to LAN!\n\n"
						+ "Other players can join via:\nIP: Your local IP\nPort: 7777"
					),
					"buttons": [{"text": "OK"}]
				}
			)
			# Resume game
			go_back()
		else:
			# Show error
			await show_modal(
				"res://shared/ui_core/components/modal_popup.tscn",
				{
					"title": "Error",
					"message": "Failed to start LAN server. Error: " + error_string(err),
					"buttons": [{"text": "OK"}]
				}
			)
	else:
		push_error("[PauseScreen] NetworkManager not found")


func _on_quit_menu_pressed() -> void:
	# Handle cleanup, then back to menu
	var ui_svc := UISystem.get_service()
	if ui_svc and ui_svc.ui_manager:
		ui_svc.ui_manager.clear_all()
		ui_svc.ui_manager.open_screen(MAIN_MENU_SCREEN)

		# Also ensure game state is reset
		GameManager.change_state(GameManager.State.READY)
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCREEN)


func _on_quit_desktop_pressed() -> void:
	await show_modal(
		"res://shared/ui_core/components/modal_popup.tscn",
		{
			"title": "Quit Game",
			"message": "Are you sure you want to exit to desktop?",
			"buttons":
			[
				{"text": "Yes", "callback": func() -> void: get_tree().quit(), "style": "danger"},
				{"text": "No", "is_cancel": true}
			]
		}
	)
