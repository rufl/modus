extends Control

const EmbeddedEditor = preload("res://game/editor/embedded_level_editor.gd")
const EditorGlobals = preload("res://shared/editor_core/core/editor_globals.gd")
const LevelPackager = preload("res://shared/editor_core/data/level_packager.gd")

var _editor: Control
var _current_save_path: String = ""
var _view_menu: PopupMenu


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
	menu_bar.name = "MenuBar"
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
	_view_menu = PopupMenu.new()
	_view_menu.name = "ViewMenu"
	_view_menu.add_check_item("Show Grid", 0)
	_view_menu.add_check_item("Show Spawn Points", 1)
	_view_menu.add_check_item("Show Connections", 2)
	_view_menu.set_item_checked(0, true)
	_view_menu.set_item_checked(1, true)
	_view_menu.set_item_checked(2, true)
	_view_menu.id_pressed.connect(_on_view_menu_pressed)

	menu_bar.add_child(_view_menu)
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
			EditorGlobals.get_undo_redo().undo()
		1:  # Redo
			EditorGlobals.get_undo_redo().redo()
		2:  # Cut
			if _editor and _editor.selection_manager:
				_editor.selection_manager.copy()
				_editor.selection_manager.delete_selected()
		3:  # Copy
			if _editor and _editor.selection_manager:
				_editor.selection_manager.copy()
		4:  # Paste
			if _editor and _editor.selection_manager and _editor.level_root:
				_editor.selection_manager.paste(Vector3.ZERO, _editor.level_root)
		5:  # Select All
			if _editor and _editor.selection_manager and _editor.level_root:
				var nodes: Array[Node3D] = []
				for child: Node in _editor.level_root.get_children():
					if child is Node3D:
						nodes.append(child)
				_editor.selection_manager.select_multiple(nodes)


func _on_view_menu_pressed(id: int) -> void:
	if _view_menu:
		_view_menu.toggle_item_checked(id)


func _on_help_menu_pressed(id: int) -> void:
	match id:
		0:  # Documentation
			_show_documentation_dialog()
		1:  # Keyboard Shortcuts
			_show_shortcuts_dialog()
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
	if not _editor or not _editor.level_root:
		_show_message("Mod Export", "No level is available to export.")
		return

	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.title = "Choose Mod Export Folder"
	dialog.dir_selected.connect(
		func(path: String) -> void:
			_export_mod_to_directory(path)
			dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


func _export_mod_to_directory(output_dir: String) -> bool:
	if not _editor or not _editor.level_root:
		return false

	var manifest := LevelPackager.LevelManifest.new()
	manifest.name = _editor.level_root.name
	manifest.author = "MODUS Editor"
	manifest.description = "Level exported from the MODUS standalone editor."
	var result = LevelPackager.package_level(_editor.level_root, output_dir, manifest)
	if result.success:
		_show_message("Mod Export Complete", "Created %s" % result.output_path)
	else:
		_show_message("Mod Export Failed", result.error_msg)
	return result.success


func _show_documentation_dialog() -> void:
	_show_message(
		"MODUS Editor Documentation",
		"Use the maintained editor guide at standalone/editor/README.md and the "
		+ "round-trip proof at docs/EDITOR_ROUNDTRIP_PROOF.md."
	)


func _show_shortcuts_dialog() -> void:
	_show_message(
		"Keyboard Shortcuts",
		"B: Block  P: Paint  E: Eraser  T: Entity  S: Spawn  C: Connect\n"
		+ "G: Grid  R: Rotate  [ / ]: Brush Size\n"
		+ "RMB + WASD: Fly camera"
	)


func _show_message(title: String, message: String) -> void:
	if not is_inside_tree():
		return
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.confirmed.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


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
