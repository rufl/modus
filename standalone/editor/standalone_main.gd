extends Control

const EmbeddedEditor = preload("res://game/editor/embedded_level_editor.gd")

var _editor: Control
var _current_save_path: String = ""


func _ready() -> void:
	name = "StandaloneLevelEditor"
	get_window().title = "MODUS Level Editor"
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Create the embedded editor (it's the same core, just different entry point)
	_editor = EmbeddedEditor.new()
	add_child(_editor)

	# Open immediately since we're standalone
	_editor.open()

	# Add menu bar for file operations
	_create_menu_bar()


func _create_menu_bar() -> void:
	var menu_bar: MenuBar = MenuBar.new()
	add_child(menu_bar)
	move_child(menu_bar, 0)

	# File Menu
	var file_menu: PopupMenu = PopupMenu.new()
	file_menu.name = "FileMenu"
	file_menu.add_item("New Level", 0)
	file_menu.add_item("Open Level...", 1)
	file_menu.add_separator()
	file_menu.add_item("Save", 2)
	file_menu.add_item("Save As...", 3)
	file_menu.add_separator()
	file_menu.add_item("Export as Mod...", 4)
	file_menu.add_separator()
	file_menu.add_item("Exit", 5)
	file_menu.id_pressed.connect(_on_file_menu_pressed)

	menu_bar.add_child(file_menu)
	menu_bar.set_menu_title(0, "File")

	# Edit Menu
	var edit_menu: PopupMenu = PopupMenu.new()
	edit_menu.name = "EditMenu"
	edit_menu.add_item("Undo", 0)
	edit_menu.add_item("Redo", 1)
	edit_menu.add_separator()
	edit_menu.add_item("Cut", 2)
	edit_menu.add_item("Copy", 3)
	edit_menu.add_item("Paste", 4)
	edit_menu.add_separator()
	edit_menu.add_item("Select All", 5)
	edit_menu.id_pressed.connect(_on_edit_menu_pressed)

	menu_bar.add_child(edit_menu)
	menu_bar.set_menu_title(1, "Edit")

	# View Menu
	var view_menu: PopupMenu = PopupMenu.new()
	view_menu.name = "ViewMenu"
	view_menu.add_check_item("Show Grid", 0)
	view_menu.add_check_item("Show Spawn Points", 1)
	view_menu.add_check_item("Show Connections", 2)
	view_menu.set_item_checked(0, true)
	view_menu.set_item_checked(1, true)
	view_menu.set_item_checked(2, true)
	view_menu.id_pressed.connect(_on_view_menu_pressed)

	menu_bar.add_child(view_menu)
	menu_bar.set_menu_title(2, "View")

	# Help Menu
	var help_menu: PopupMenu = PopupMenu.new()
	help_menu.name = "HelpMenu"
	help_menu.add_item("Documentation", 0)
	help_menu.add_item("Keyboard Shortcuts", 1)
	help_menu.add_separator()
	help_menu.add_item("About", 2)
	help_menu.id_pressed.connect(_on_help_menu_pressed)

	menu_bar.add_child(help_menu)
	menu_bar.set_menu_title(3, "Help")


func _on_file_menu_pressed(id: int) -> void:
	match id:
		0:  # New Level
			_new_level()
		1:  # Open Level
			_open_level_dialog()
		2:  # Save
			_quick_save()
		3:  # Save As
			_save_as_dialog()
		4:  # Export as Mod
			_export_mod_dialog()
		5:  # Exit
			get_tree().quit()


func _on_edit_menu_pressed(id: int) -> void:
	match id:
		0:  # Undo
			# TODO(v1.0): Implement custom UndoRedo system for standalone editor
			# EditorInterface is only available in Godot Editor, not standalone builds
			var dialog: AcceptDialog = AcceptDialog.new()
			dialog.title = "Undo Not Available"
			dialog.dialog_text = (
				"Undo/Redo system is planned for v1.0.\n\n"
				+ "Currently only available when running as Godot Editor plugin."
			)
			add_child(dialog)
			dialog.popup_centered()
			dialog.confirmed.connect(func() -> void: dialog.queue_free())
		1:  # Redo
			# TODO(v1.0): Implement custom UndoRedo system for standalone editor
			var dialog: AcceptDialog = AcceptDialog.new()
			dialog.title = "Redo Not Available"
			dialog.dialog_text = (
				"Undo/Redo system is planned for v1.0.\n\n"
				+ "Currently only available when running as Godot Editor plugin."
			)
			add_child(dialog)
			dialog.popup_centered()
			dialog.confirmed.connect(func() -> void: dialog.queue_free())


func _on_view_menu_pressed(id: int) -> void:
	var menu: PopupMenu = get_node("ViewMenu")
	menu.toggle_item_checked(id)


func _on_help_menu_pressed(id: int) -> void:
	match id:
		0:  # Documentation
			OS.shell_open("https://github.com/your-repo/wiki")
		2:  # About
			_show_about_dialog()


func _new_level() -> void:
	# Clear the level root
	if _editor and _editor.level_root:
		for child: Node in _editor.level_root.get_children():
			child.queue_free()


func _open_level_dialog() -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.tscn ; Level Files", "*.scn ; Scene Files"]
	dialog.file_selected.connect(
		func(path: String) -> void:
			if _editor:
				_editor.load_level(path)
			dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


func _quick_save() -> void:
	if _current_save_path.is_empty():
		_save_as_dialog()
	elif _editor:
		_editor.save_level(_current_save_path)


func _save_as_dialog() -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.tscn ; Level Files"]
	dialog.file_selected.connect(
		func(path: String) -> void:
			_current_save_path = path
			if _editor:
				_editor.save_level(path)
			dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


func _export_mod_dialog() -> void:
	# TODO(v1.1, @modding-team): Implement mod export system
	# Implementation plan:
	# 1. Create export dialog UI with mod metadata fields
	# 2. Implement PCK packing for mod files
	# 3. Add manifest.json generation
	# 4. Implement file validation (check for required files)
	# 5. Add compression options
	# 6. Test with example mods
	# Estimated effort: 20-30 hours
	# Priority: MEDIUM (modders can manually create PCKs for now)
	
	# Temporary: Show not implemented message
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Mod Export"
	dialog.dialog_text = (
		"Mod export system is planned for v1.1.\n\n"
		+ "For now, manually create PCK files using Godot's export system."
	)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func() -> void: dialog.queue_free())


func _show_about_dialog() -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "About MODUS Level Editor"
	dialog.dialog_text = """MODUS Level Editor v1.0

A brush-based FPS level editor.

Keyboard Shortcuts:
  B - Block Brush
  P - Paint Brush
  E - Eraser
  T - Entity Placer
  S - Spawn Point
  C - Connect Tool
  G - Toggle Grid
  R - Rotate Preview
  [ / ] - Brush Size

Hold RMB + WASD to fly camera."""
	add_child(dialog)
	dialog.popup_centered()
