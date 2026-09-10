class_name EditorGlobals
extends RefCounted


# Helper function to safely log messages (static version)
static func _log(message: String, category: String = "Game") -> void:
	if GameManager.has_method("get_core_system"):
		var logger = GameManager.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info(message, category)
			return
	print("[%s] %s" % [category, message])


const AFTER_GUI_INPUT_PASS = 0
const AFTER_GUI_INPUT_STOP = 1

static var _runtime_undo_redo: UndoRedo = null
static var _runtime_root: Node = null
static var _runtime_camera: Camera3D = null


static func is_in_editor() -> bool:
	return Engine.is_editor_hint()


## Get EditorInterface singleton safely


static func _get_editor_interface() -> Object:
	if Engine.has_singleton("EditorInterface"):
		return Engine.get_singleton("EditorInterface")
	return null


## Get UndoRedo manager


static func get_undo_redo() -> Object:
	if is_in_editor():
		var ei = _get_editor_interface()
		if ei:
			return ei.get_editor_undo_redo()

	# Runtime fallback
	if not _runtime_undo_redo:
		_runtime_undo_redo = UndoRedo.new()
	return _runtime_undo_redo


## Get edited scene root


static func get_edited_scene_root() -> Node:
	if is_in_editor():
		var ei = _get_editor_interface()
		if ei:
			var root = ei.get_edited_scene_root()
			if root:
				return root

	# Runtime: return the current scene
	if _runtime_root:
		return _runtime_root

	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		return tree.current_scene
	return null


## Set runtime root (for setup)


static func set_runtime_root(node: Node) -> void:
	_log("[EditorGlobals] Setting runtime root: " + " " + str(node), "Log")
	_runtime_root = node


## Get 3D viewport camera


static func get_editor_camera_3d() -> Camera3D:
	if is_in_editor():
		var ei = _get_editor_interface()
		if ei:
			var viewport = ei.get_editor_viewport_3d()
			if viewport:
				return viewport.get_camera_3d()
		return null

	return _runtime_camera


## Set runtime camera


static func set_runtime_camera(camera: Camera3D) -> void:
	_runtime_camera = camera


## Play current scene


static func play_current_scene() -> void:
	if is_in_editor():
		var ei = _get_editor_interface()
		if ei:
			ei.play_current_scene()
	else:
		_log("[EditorGlobals] Cannot play scene in runtime mode", "Log")


## Get resource previewer


static func get_resource_previewer() -> Object:
	if is_in_editor():
		var ei = _get_editor_interface()
		if ei:
			return ei.get_resource_previewer()
	return null  # No runtime preview generation yet
