extends Node

const MAIN_MENU_SCREEN: String = "res://shared/ui_core/screens/main_menu_screen.tscn"


func _ready() -> void:
	var logger: Node = GameManager.get_core_system("logger")
	logger.info("[MainEntry] _ready() called", "MainEntry")
	var current_scene_name: String = (
		str(get_tree().current_scene.name) if get_tree().current_scene else "null"
	)
	logger.info("[MainEntry] Initial current scene: %s" % current_scene_name, "MainEntry")

	# Wait for core services to be fully initialized
	if GameManager and not GameManager.is_initialized():
		await GameManager.ready
	else:
		# Fallback delay if GameManager is missing or already ready
		await get_tree().process_frame

	var after_frame_scene: String = (
		str(get_tree().current_scene.name) if get_tree().current_scene else "null"
	)
	logger.info(
		"[MainEntry] After process_frame, current scene: %s" % after_frame_scene, "MainEntry"
	)

	# Scene change monitoring removed - world scene now self-destructs during menu startup

	if _is_standalone_editor():
		_launch_editor()
	else:
		_launch_game()


func _on_tree_changed() -> void:
	# If scene changed during menu startup, force it back
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene and tree.current_scene.name != "MainEntry":
		var logger: Node = GameManager.get_core_system("logger")
		if logger:
			logger.warning(
				(
					"Scene changed to %s during startup, forcing back to MainEntry"
					% tree.current_scene.name
				),
				"MainEntry"
			)
		tree.current_scene = self
		# Re-launch menu
		_launch_game()


func _is_standalone_editor() -> bool:
	return (
		OS.has_feature("standalone_editor")
		or "--editor" in OS.get_cmdline_args()
		or OS.has_feature("editor_mode")
	)


func _launch_editor() -> void:
	var logger: Node = GameManager.get_core_system("logger")
	logger.info("[MainEntry] Launching Standalone Editor...", "MainEntry")
	var editor_scene: String = "res://plugins/editor/editor_runtime.tscn"
	if ResourceLoader.exists(editor_scene):
		get_tree().change_scene_to_file(editor_scene)
	else:
		push_error("[MainEntry] Editor runtime scene not found: %s" % editor_scene)
		# Fallback to game?
		_launch_game()


func _launch_game() -> void:
	var logger: Node = GameManager.get_core_system("logger")
	logger.info("[MainEntry] Launching Game...", "MainEntry")
	var launch_scene_name: String = (
		str(get_tree().current_scene.name) if get_tree().current_scene else "null"
	)
	logger.info("[MainEntry] Current scene: %s" % launch_scene_name, "MainEntry")

	# Use UIService.ui_manager to show the main menu
	var us := UISystem.get_service()
	var ui_mgr: Node = us.ui_manager if us else null

	if ui_mgr:
		logger.info("[MainEntry] Opening main menu screen via UIService.ui_manager...", "MainEntry")
		# Assuming "MainMenuScreen" is the key or path
		ui_mgr.open_screen(MAIN_MENU_SCREEN)
		# The original code had these lines, but the new snippet removes them.
		# var final_scene_name: String = str(get_tree().current_scene.name) \
		# 	if get_tree().current_scene else "null"
		# print("[MainEntry] Current scene after opening menu: %s" % final_scene_name)
	elif ResourceLoader.exists(MAIN_MENU_SCREEN):
		# This elif was implied by the original structure and the new 'else'
		# for direct scene change
		# Direct scene change if UIManager not available
		logger.info(
			"[MainEntry] UIService.ui_manager not available, changing scene directly...",
			"MainEntry"
		)
		get_tree().change_scene_to_file(MAIN_MENU_SCREEN)
	else:
		# Last resort: try showcase scene
		var world_scene: String = "res://game/world/maps/showcase.tscn"
		if ResourceLoader.exists(world_scene):
			logger.info("[MainEntry] No menu found, loading showcase scene...", "MainEntry")
			get_tree().change_scene_to_file(world_scene)
		else:
			push_error("[MainEntry] No valid scene found to launch!")
