extends Button


func _ready() -> void:
	pressed.connect(_on_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		grab_focus()
		get_viewport().set_input_as_handled()


func _on_pressed() -> void:
	# Resume Game
	var tree := get_tree()
	tree.paused = false

	# Release mouse if needed (though Player input component handles capture)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Close Menu
	# Try UIManager first
	var manager: Node = get_node_or_null("/root/GameManager")
	var ui_svc: Node = manager.get_core_system("ui") if manager else null
	if ui_svc and "ui_manager" in ui_svc and ui_svc.ui_manager:
		# If it's a modal
		if ui_svc.ui_manager.has_open_modal():
			ui_svc.ui_manager.dismiss_all_modals()
		# If it's a screen
		elif ui_svc.ui_manager.get_stack_depth() > 1:
			ui_svc.ui_manager.back()
	else:
		# Fallback: Hide parent if it's a dedicated pause menu layer
		var parent_menu: Node = find_parent("PauseMenu")
		if parent_menu:
			parent_menu.visible = false
		else:
			# No pause layer is available; avoid hiding an unrelated ancestor.
			pass
