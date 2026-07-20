class_name DebugCommands
extends RefCounted

# MODUS Framework Debug Commands
# Provides debugging functionality for development

static var _fps_display_visible: bool = false
static var _wireframe_enabled: bool = false


static func register_commands(registry: ConsoleCommandRegistry) -> void:
	registry.register_command("debug_info", _debug_info, "Show debug information")
	registry.register_command("fps", _show_fps, "Toggle FPS display")
	registry.register_command("wireframe", _toggle_wireframe, "Toggle wireframe mode")
	registry.register_command("reload_scene", _reload_scene, "Reload current scene")


static func _debug_info(_args: PackedStringArray) -> String:
	var info: String = "[color=yellow]Debug Information:[/color]\n"
	info += "  FPS: %d\n" % Engine.get_frames_per_second()
	info += "  Memory: %d MB\n" % int(OS.get_static_memory_usage() / 1048576.0)

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		info += "  Nodes: %d\n" % tree.get_node_count()

	# Player position
	if tree:
		var players: Array[Node] = tree.get_nodes_in_group("player")
		for p: Node in players:
			if p is CharacterBody3D and p.is_multiplayer_authority():
				info += "  Player Pos: %s\n" % str(p.global_position)
				info += "  Player Vel: %s\n" % str(p.velocity)
				break

	# Match state
	var match_svc: MatchSvc = MatchSvc.get_instance()
	if match_svc:
		info += "  Match State: %s\n" % MatchSvc.MatchState.keys()[match_svc.current_match_state]
		info += "  Time Left: %.0f\n" % match_svc.time_left
		info += "  God Mode: %s\n" % str(match_svc.godmode)
		info += "  Noclip: %s\n" % str(match_svc.noclip)

	# Render info
	info += (
		"  Render Driver: %s"
		% str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))
	)

	return info


static func _show_fps(_args: PackedStringArray) -> String:
	_fps_display_visible = not _fps_display_visible

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		# Use Godot's built-in performance monitors
		tree.root.get_viewport().debug_draw = (
			Viewport.DEBUG_DRAW_DISABLED
			if not _fps_display_visible
			else Viewport.DEBUG_DRAW_OVERDRAW
		)

	if _fps_display_visible:
		return "FPS display [color=green]enabled[/color] (overdraw view)"
	return "FPS display [color=red]disabled[/color]"


static func _toggle_wireframe(_args: PackedStringArray) -> String:
	_wireframe_enabled = not _wireframe_enabled

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree:
		tree.root.get_viewport().debug_draw = (
			Viewport.DEBUG_DRAW_WIREFRAME if _wireframe_enabled else Viewport.DEBUG_DRAW_DISABLED
		)

	if _wireframe_enabled:
		return "Wireframe mode [color=green]enabled[/color]"
	return "Wireframe mode [color=red]disabled[/color]"


static func _reload_scene(_args: PackedStringArray) -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		tree.reload_current_scene()
		return "Scene reloaded"
	return "No scene to reload"
