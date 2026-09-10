@tool
class_name EditorFeatures
extends Node

# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])



signal console_toggled(is_open: bool)
signal feature_ready(feature_name: String)

const HotbarScene = preload("res://shared/editor_core/ui/hotbar.tscn")
const PlacementPreviewScript = preload("res://shared/editor_core/tools/placement_preview.gd")
const EditorConsoleScript = preload("res://shared/editor_core/ui/editor_console.gd")
const ActorRegistryScript = preload("res://shared/editor_core/actors/actor_registry.gd")
const ChannelSystemScript = preload("res://shared/editor_core/scripting/channel_system.gd")
const VisConnToolScript = preload("res://shared/editor_core/tools/visual_connection_tool.gd")
const ConnRendererScript = preload("res://shared/editor_core/gizmos/connection_renderer.gd")
const ConnPropsScript = preload("res://shared/editor_core/ui/connection_properties_panel.gd")
const EditorNetworkAdapterScript = preload(
	"res://shared/editor_core/core/editor_network_adapter.gd"
)
const LevelPackagerScript = preload("res://shared/editor_core/data/level_packager.gd")
const WorkshopManagerScript = preload("res://shared/editor_core/data/workshop_manager.gd")
const WorkshopBrowserScript = preload("res://shared/editor_core/ui/workshop_browser_panel.gd")

var hotbar: Control = null
var placement_preview: Node3D = null
var command_console: Control = null
var actor_registry: Node = null
var channel_system: Node = null
var visual_connection_tool: Node = null
var connection_renderer: Node3D = null
var connection_properties: Control = null
var network_adapter: Node = null
var editor_state: Node = null
var asset_registry: Node = null
var grid_system: Node = null
var level_root: Node3D = null
var editor_camera: Camera3D = null
var console_key: int = KEY_QUOTELEFT
var workshop_manager: Node = null
var workshop_browser: Control = null

var _pkg_dialog: FileDialog = null


func _ready() -> void:
	name = "EditorFeatures"


## Setup with core editor references


func setup(
	state: Node,
	registry: Node = null,
	grid: Node = null,
	root: Node3D = null,
	camera: Camera3D = null
) -> void:
	editor_state = state
	asset_registry = registry
	grid_system = grid
	level_root = root
	editor_camera = camera

	# Initialize all features
	_init_hotbar()
	_init_placement_preview()
	_init_command_console()
	_init_actor_registry()
	_init_channel_system()
	_init_visual_connection_system()
	_init_network_adapter()
	_init_workshop_system()  # Includes packaging


## Initialize dual hotbar


func _init_hotbar() -> void:
	if not HotbarScene:
		push_warning("[EditorFeatures] Hotbar scene not found")
		return

	hotbar = HotbarScene.instantiate()
	add_child(hotbar)

	if hotbar.has_method("setup"):
		hotbar.setup(editor_state, asset_registry)

	feature_ready.emit("hotbar")


## Initialize placement preview


func _init_placement_preview() -> void:
	if not PlacementPreviewScript:
		push_warning("[EditorFeatures] PlacementPreview script not found")
		return

	placement_preview = Node3D.new()
	placement_preview.set_script(PlacementPreviewScript)
	placement_preview.name = "PlacementPreview"

	if level_root:
		level_root.add_child(placement_preview)
	else:
		add_child(placement_preview)

	if placement_preview.has_method("setup"):
		placement_preview.setup(grid_system)

	feature_ready.emit("placement_preview")


## Initialize command console


func _init_command_console() -> void:
	if not EditorConsoleScript:
		push_warning("[EditorFeatures] EditorConsole script not found")
		return

	command_console = PanelContainer.new()
	command_console.set_script(EditorConsoleScript)
	command_console.name = "EditorConsole"
	add_child(command_console)

	if command_console.has_method("setup"):
		command_console.setup(editor_state, level_root, grid_system)

	# Position console at bottom-center
	command_console.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	command_console.position.y -= 320

	# Connect close signal
	if command_console.has_signal("console_closed"):
		command_console.console_closed.connect(_on_console_closed)

	feature_ready.emit("command_console")


## Initialize actor registry


func _init_actor_registry() -> void:
	if not ActorRegistryScript:
		push_warning("[EditorFeatures] ActorRegistry script not found")
		return

	actor_registry = Node.new()
	actor_registry.set_script(ActorRegistryScript)
	actor_registry.name = "ActorRegistry"
	add_child(actor_registry)

	feature_ready.emit("actor_registry")


## Initialize channel system


func _init_channel_system() -> void:
	# Check if parent already has ChannelSystem
	var parent: Node = get_parent()
	if parent and parent.has_node("ChannelSystem"):
		channel_system = parent.get_node("ChannelSystem")
		feature_ready.emit("channel_system")
		return

	if not ChannelSystemScript:
		push_warning("[EditorFeatures] ChannelSystem script not found")
		return

	channel_system = Node.new()
	channel_system.set_script(ChannelSystemScript)
	channel_system.name = "ChannelSystem"
	add_child(channel_system)

	feature_ready.emit("channel_system")


## Initialize visual connection system


func _init_visual_connection_system() -> void:
	# Visual Connection Tool
	if VisConnToolScript:
		visual_connection_tool = Node.new()
		visual_connection_tool.set_script(VisConnToolScript)
		visual_connection_tool.name = "VisualConnectionTool"
		add_child(visual_connection_tool)

		# Setup references
		if visual_connection_tool.has_method("setup"):
			visual_connection_tool.setup(channel_system, editor_camera, level_root)

		feature_ready.emit("visual_connection_tool")

	# Connection Renderer
	if ConnRendererScript:
		connection_renderer = Node3D.new()
		connection_renderer.set_script(ConnRendererScript)
		connection_renderer.name = "ConnectionRenderer"

		if level_root:
			level_root.add_child(connection_renderer)
		else:
			add_child(connection_renderer)

		if connection_renderer.has_method("setup"):
			connection_renderer.setup(channel_system, level_root)

		# Link renderer to tool
		if visual_connection_tool and visual_connection_tool.has_method("set_renderer"):
			visual_connection_tool.set_renderer(connection_renderer)

		feature_ready.emit("connection_renderer")

	# Connection Properties Panel
	if ConnPropsScript:
		connection_properties = Control.new()
		connection_properties.set_script(ConnPropsScript)
		connection_properties.name = "ConnectionPropertiesPanel"
		add_child(connection_properties)

		if connection_properties.has_method("setup"):
			connection_properties.setup(channel_system)

		feature_ready.emit("connection_properties")

	# Connect Tool -> Properties
	if visual_connection_tool and connection_properties:
		if visual_connection_tool.has_signal("connection_selected"):
			visual_connection_tool.connection_selected.connect(
				func(channel: String):
					if connection_properties.has_method("edit_channel"):
						connection_properties.edit_channel(channel)
						_show_properties_panel()
			)

		# Also update properties when new connection made
		if visual_connection_tool.has_signal("connection_completed"):
			visual_connection_tool.connection_completed.connect(
				func(_s, _t, channel):
					if connection_properties.has_method("edit_channel"):
						connection_properties.edit_channel(channel)
						_show_properties_panel()
			)


func _show_properties_panel() -> void:
	# Assuming this panel should be floating or docked.
	# For now, ensure it's visible. Logic for docking might be elsewhere.
	if connection_properties:
		connection_properties.visible = true
		# Maybe center it? Or it's docked in toolbar?
		# Original code just added it as child.


## Initialize network adapter


func _init_network_adapter() -> void:
	if not EditorNetworkAdapterScript:
		return

	network_adapter = Node.new()
	network_adapter.set_script(EditorNetworkAdapterScript)
	network_adapter.name = "EditorNetworkAdapter"
	add_child(network_adapter)

	if network_adapter.has_method("setup"):
		network_adapter.setup(editor_state)

	feature_ready.emit("network_adapter")


# Workshop components

## Initialize workshop system


func _init_workshop_system() -> void:
	if not WorkshopManagerScript or not WorkshopBrowserScript:
		return

	# 1. Workshop Manager
	workshop_manager = Node.new()
	workshop_manager.set_script(WorkshopManagerScript)
	workshop_manager.name = "WorkshopManager"
	add_child(workshop_manager)

	# 2. Workshop Browser
	workshop_browser = PanelContainer.new()
	workshop_browser.set_script(WorkshopBrowserScript)
	workshop_browser.name = "WorkshopBrowserPanel"
	workshop_browser.visible = false

	# Position it center
	workshop_browser.set_anchors_preset(Control.PRESET_CENTER)

	add_child(workshop_browser)

	if workshop_browser.has_method("setup"):
		workshop_browser.setup(workshop_manager)

	# 3. Packaging Dialog
	_pkg_dialog = FileDialog.new()
	_pkg_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_pkg_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_pkg_dialog.filters = ["*.mdsl ; Level Packages"]
	_pkg_dialog.title = "Package Level As..."
	_pkg_dialog.file_selected.connect(_on_package_file_selected)
	add_child(_pkg_dialog)

	feature_ready.emit("workshop_system")


func package_current_level() -> void:
	if _pkg_dialog:
		_pkg_dialog.popup_centered(Vector2(600, 400))


func _on_package_file_selected(path: String) -> void:
	if not level_root:
		push_error("No level root to package")
		return

	_log("[EditorFeatures] Packaging level to: " + " " + str(path), "Log")

	# Create manifest
	var manifest = LevelPackagerScript.LevelManifest.new()
	manifest.name = level_root.name
	manifest.author = _get_package_author()

	# Package it
	var result = LevelPackagerScript.package_level(level_root, path.get_base_dir(), manifest)

	if result.success:
		_log("[EditorFeatures] Package success: " + " " + str(result.output_path), "Log")
		if command_console and command_console.has_method("log_message"):
			var msg: String = "[System] Level packaged successfully at " + result.output_path
			command_console.log_message(msg)
	else:
		push_error("Package failed: " + result.error_msg)
		if command_console and command_console.has_method("log_message"):
			command_console.log_message("[System] Packaging failed: " + result.error_msg)


func _get_package_author() -> String:
	var config_service: Node = GameManager.get_core_system("config") if GameManager else null
	if config_service and config_service.has_method("get_value"):
		var configured: String = str(config_service.get_value("editor.author", "")).strip_edges()
		if not configured.is_empty():
			return configured
	var system_user := OS.get_environment("USER").strip_edges()
	if system_user.is_empty():
		system_user = OS.get_environment("USERNAME").strip_edges()
	return system_user if not system_user.is_empty() else "Local User"


func toggle_workshop() -> void:
	if workshop_browser:
		workshop_browser.visible = not workshop_browser.visible
		if workshop_browser.visible:
			workshop_browser.move_to_front()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return

	# Console toggle (backtick/tilde key)
	if event.keycode == console_key:
		toggle_console()
		get_viewport().set_input_as_handled()

	# Rotation keys for placement preview
	if placement_preview and placement_preview.is_active:
		if event.keycode == KEY_R:
			if event.shift_pressed:
				placement_preview.fine_rotate_preview(15.0)
			else:
				placement_preview.rotate_preview(90.0)
			get_viewport().set_input_as_handled()


## Toggle command console visibility


func toggle_console() -> void:
	if command_console:
		if command_console.visible:
			command_console.close()
		else:
			command_console.open()
		console_toggled.emit(command_console.visible)


func _on_console_closed() -> void:
	console_toggled.emit(false)


## Get the hotbar


func get_hotbar() -> Control:
	return hotbar


## Get the placement preview


func get_placement_preview() -> Node3D:
	return placement_preview


## Get the command console


func get_console() -> Control:
	return command_console


## Get the actor registry


func get_actor_registry() -> Node:
	return actor_registry


## Get the channel system


func get_channel_system() -> Node:
	return channel_system


## Start placement preview for an asset


func start_placement(asset: Dictionary) -> void:
	if placement_preview and placement_preview.has_method("start_preview"):
		placement_preview.start_preview(asset)


## Clear placement preview


func clear_placement() -> void:
	if placement_preview and placement_preview.has_method("clear_preview"):
		placement_preview.clear_preview()


## Update placement preview from camera raycast


func update_placement_from_camera() -> void:
	if not placement_preview or not editor_camera:
		return
	if not placement_preview.is_active:
		return

	var from: Vector3 = editor_camera.global_position
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var direction: Vector3 = editor_camera.project_ray_normal(mouse_pos)

	if placement_preview.has_method("update_from_raycast"):
		placement_preview.update_from_raycast(from, direction, editor_camera)


## Open command console


func open_console() -> void:
	if command_console and command_console.has_method("open"):
		command_console.open()
		console_toggled.emit(true)


## Close command console


func close_console() -> void:
	if command_console and command_console.has_method("close"):
		command_console.close()


## Execute a console command directly


func execute_command(cmd: String) -> void:
	if command_console and command_console.has_method("submit_command"):
		command_console.submit_command(cmd)


## Create an actor by ID


func create_actor(actor_id: String) -> Node:
	if actor_registry and actor_registry.has_method("create_actor"):
		return actor_registry.create_actor(actor_id)
	return null


## Get all available actors


func get_available_actors() -> Array[Dictionary]:
	if actor_registry:
		var result: Array[Dictionary] = []
		for actor_id: String in actor_registry.get_all_actor_ids():
			result.append(actor_registry.get_actor_info(actor_id))
		return result
	return []


## Set the level root (call if changed after setup)


func set_level_root(root: Node3D) -> void:
	level_root = root

	# Reparent placement preview
	if placement_preview and placement_preview.get_parent() != root:
		placement_preview.reparent(root)

	# Update console
	if command_console and command_console.has_method("setup"):
		command_console.level_root = root


## Set the editor camera (call if changed after setup)


func set_camera(camera: Camera3D) -> void:
	editor_camera = camera


## Handle 3D input


func handle_3d_input(camera: Camera3D, event: InputEvent) -> bool:
	if not editor_state:
		return false

	# Check if Connect tool is active
	# Check if Connect tool is active
	# Use get function/property if ToolType enum is not available here easily
	# (it's in EditorState class)
	# But EditorState is a const check? No, class defined in script.

	# Check property directly using dynamic access or enum value (6 = CONNECT)
	if editor_state.current_tool == 6:  # ToolType.CONNECT
		if visual_connection_tool and visual_connection_tool.has_method("handle_input"):
			if visual_connection_tool.handle_input(camera, event):
				return true

	return false
