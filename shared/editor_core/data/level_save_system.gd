@tool
class_name LevelSaveSystem
extends RefCounted


# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])


signal save_completed(path: String)
signal load_completed(path: String)
signal autosave_completed

const QUICKSAVE_PATH := "user://level_editor_quicksave.tscn"
const AUTOSAVE_DIR := "user://level_editor_autosaves/"
const MAX_AUTOSAVES := 5
const THUMBNAIL_SIZE := Vector2i(256, 144)
const JSONHelperClass = preload("res://game/core/json_helper.gd")

var autosave_timer: Timer = null
var autosave_interval: float = 300.0  # 5 minutes
var scene_root: Node = null


func setup(root: Node) -> void:
	cleanup()
	scene_root = root
	if scene_root and is_instance_valid(scene_root) and scene_root.has_signal("tree_exiting"):
		scene_root.tree_exiting.connect(_on_scene_root_exiting)


## Release the timer and scene lifecycle connection.
func cleanup() -> void:
	stop_autosave()
	if autosave_timer and is_instance_valid(autosave_timer):
		var timer_parent: Node = autosave_timer.get_parent()
		if timer_parent:
			timer_parent.remove_child(autosave_timer)
		autosave_timer.queue_free()
	autosave_timer = null

	if scene_root and is_instance_valid(scene_root) and scene_root.has_signal("tree_exiting"):
		var exiting_callable := Callable(self, "_on_scene_root_exiting")
		if scene_root.tree_exiting.is_connected(exiting_callable):
			scene_root.tree_exiting.disconnect(exiting_callable)
	scene_root = null


func _on_scene_root_exiting() -> void:
	cleanup()


## Quick save current level


func quick_save() -> bool:
	if not scene_root:
		push_error("LevelSaveSystem: No scene root set")
		return false

	var level_root := _find_level_root()
	if not level_root:
		push_warning("LevelSaveSystem: No LevelRoot found, saving entire scene")

	var packed := PackedScene.new()
	var result := packed.pack(scene_root)

	if result != OK:
		push_error("LevelSaveSystem: Failed to pack scene")
		return false

	var err := ResourceSaver.save(packed, QUICKSAVE_PATH)
	if err != OK:
		push_error("LevelSaveSystem: Failed to save: %s" % error_string(err))
		return false

	_log(str("[LevelSaveSystem] Quick save completed: %s" % QUICKSAVE_PATH), "Log")
	save_completed.emit(QUICKSAVE_PATH)
	return true


## Quick load last quick save


func quick_load() -> bool:
	if not ResourceLoader.exists(QUICKSAVE_PATH):
		push_warning("LevelSaveSystem: No quick save found")
		return false
	if not Engine.is_editor_hint():
		push_warning("LevelSaveSystem: Quick load requires the Godot editor")
		return false

	EditorInterface.open_scene_from_path(QUICKSAVE_PATH)

	_log(str("[LevelSaveSystem] Quick load completed: %s" % QUICKSAVE_PATH), "Log")
	load_completed.emit(QUICKSAVE_PATH)
	return true


## Save level to specific path


func save_level(path: String, include_thumbnail: bool = true) -> bool:
	if not scene_root:
		push_error("LevelSaveSystem: No scene root set")
		return false

	var level_root := _find_level_root()

	# Update metadata
	if level_root and level_root.has_method("serialize"):
		var metadata: Dictionary = level_root.serialize()
		level_root.set_meta("level_editor_metadata", metadata)

	# Pack scene
	var packed := PackedScene.new()
	var result := packed.pack(scene_root)

	if result != OK:
		push_error("LevelSaveSystem: Failed to pack scene")
		return false

	# Save scene
	var err := ResourceSaver.save(packed, path)
	if err != OK:
		push_error("LevelSaveSystem: Failed to save: %s" % error_string(err))
		return false

	# Generate thumbnail
	if include_thumbnail:
		var thumb_path := path.get_basename() + "_thumb.png"
		_generate_thumbnail(thumb_path)

	_log(str("[LevelSaveSystem] Level saved: %s" % path), "Log")
	save_completed.emit(path)
	return true


## Load level from path


func load_level(path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_error("LevelSaveSystem: File not found: %s" % path)
		return false
	if not Engine.is_editor_hint():
		push_warning("LevelSaveSystem: Loading a level requires the Godot editor")
		return false

	EditorInterface.open_scene_from_path(path)

	_log(str("[LevelSaveSystem] Level loaded: %s" % path), "Log")
	load_completed.emit(path)
	return true


## Perform autosave


func autosave() -> bool:
	_ensure_autosave_dir()

	# Generate timestamped filename
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := AUTOSAVE_DIR.path_join("autosave_%s.tscn" % timestamp)

	if save_level(path, false):
		_cleanup_old_autosaves()
		autosave_completed.emit()
		return true


## Start autosave timer
func start_autosave(interval: float = 300.0) -> void:
	if interval <= 0.0:
		push_error("LevelSaveSystem: Autosave interval must be greater than zero")
		return
	if not scene_root or not is_instance_valid(scene_root):
		push_error("LevelSaveSystem: Cannot start autosave without a valid scene root")
		return
	if not scene_root.is_inside_tree():
		push_error("LevelSaveSystem: Cannot start autosave before the scene root enters the tree")
		return

	autosave_interval = interval
	if not autosave_timer or not is_instance_valid(autosave_timer):
		autosave_timer = Timer.new()
		autosave_timer.name = "LevelSaveAutosaveTimer"
		autosave_timer.timeout.connect(autosave)

	if autosave_timer.get_parent() != scene_root:
		var old_parent: Node = autosave_timer.get_parent()
		if old_parent:
			old_parent.remove_child(autosave_timer)
		scene_root.add_child(autosave_timer)

	autosave_timer.wait_time = autosave_interval
	if not autosave_timer.is_stopped():
		autosave_timer.stop()
	autosave_timer.start()


## Stop autosave timer
func stop_autosave() -> void:
	if autosave_timer and is_instance_valid(autosave_timer) and not autosave_timer.is_stopped():
		autosave_timer.stop()


## Generate thumbnail from current viewport


func _generate_thumbnail(path: String) -> bool:
	if not Engine.is_editor_hint():
		push_warning("LevelSaveSystem: Thumbnail capture requires the Godot editor")
		return false

	# Get editor viewport
	var viewport := EditorInterface.get_editor_viewport_3d(0)

	# Wait for frame to render
	await viewport.get_tree().process_frame
	await viewport.get_tree().process_frame

	# Capture viewport
	var image := viewport.get_texture().get_image()
	if not image:
		return false

	# Resize to thumbnail size
	image.resize(THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y, Image.INTERPOLATE_LANCZOS)

	# Save as PNG
	var err := image.save_png(path)
	if err != OK:
		push_warning("LevelSaveSystem: Failed to save thumbnail")
		return false

	return true


func _find_level_root() -> Node:
	if not scene_root:
		return null
	if scene_root.get_script() and scene_root.get_script().resource_path.contains("level_root.gd"):
		return scene_root

	for child in scene_root.get_children():
		if child.get_script() and child.get_script().resource_path.contains("level_root.gd"):
			return child

	return null


func _ensure_autosave_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists(AUTOSAVE_DIR):
		dir.make_dir_recursive(AUTOSAVE_DIR)


func _cleanup_old_autosaves() -> void:
	var dir := DirAccess.open(AUTOSAVE_DIR)
	if not dir:
		return

	# Get all autosave files
	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("autosave_") and file_name.ends_with(".tscn"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort by name (which includes timestamp)
	files.sort()

	# Remove oldest files if over limit
	while files.size() > MAX_AUTOSAVES:
		var oldest: String = files.pop_front()
		dir.remove(oldest)
		_log(str("[LevelSaveSystem] Removed old autosave: %s" % oldest), "Log")


## Export level as mod folder


func export_as_mod(folder_path: String) -> bool:
	var level_root := _find_level_root()
	if not level_root:
		push_error("LevelSaveSystem: No LevelRoot found")
		return false

	# Create folder structure
	if DirAccess.make_dir_recursive_absolute(folder_path) != OK:
		push_error("LevelSaveSystem: Cannot create export directory")
		return false

	# Save level scene
	var level_path := folder_path.path_join("level.tscn")
	if not save_level(level_path, false):
		push_error("LevelSaveSystem: Failed to save exported level")
		return false

	# Save metadata JSON
	var meta_path := folder_path.path_join("level_info.json")
	var metadata: Dictionary = level_root.serialize() if level_root.has_method("serialize") else {}

	var json := JSONHelperClass.safe_stringify(metadata, "\t")
	var file := FileAccess.open(meta_path, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()

	_log(str("[LevelSaveSystem] Exported mod to: %s" % folder_path), "Log")
	return true


## Get list of recent autosaves


func get_autosaves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []

	var dir := DirAccess.open(AUTOSAVE_DIR)
	if not dir:
		return saves

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("autosave_") and file_name.ends_with(".tscn"):
			saves.append(
				{
					"name": file_name,
					"path": AUTOSAVE_DIR.path_join(file_name),
					"modified": FileAccess.get_modified_time(AUTOSAVE_DIR.path_join(file_name))
				}
			)
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort by modified time (newest first)
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.modified > b.modified)

	return saves
