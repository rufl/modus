@tool
extends Node

signal tool_changed(tool_type: ToolType)  # Emitted when tool selection changes
signal selection_changed(selected_nodes: Array[Node])  # Emitted when node selection changes
signal editing_mode_changed(is_editing: bool)  # Emitted when editing mode toggles
signal brush_size_changed(size: Vector3i)  # Emitted when brush size changes
signal network_action_requested(action: String, data: Dictionary)

enum ToolType {
	NONE, BLOCK_BRUSH, PAINT_BRUSH, ERASER, ENTITY_PLACER, SPAWN_POINT, CONNECT, SELECT, VEGETATION  # Added Vegetation Tool
}

const LocalEditorGlobals = preload("res://shared/editor_core/core/editor_globals.gd")
const SpawnPointScript = preload("res://shared/editor_core/nodes/spawn_point.gd")
const VegetationToolScript = preload("res://shared/editor_core/tools/vegetation_tool.gd")  # Preload new tool

var current_tool: ToolType = ToolType.NONE
var selected_nodes: Array[Node] = []
var is_editing_active: bool = false
var brush_size: Vector3i = Vector3i.ONE
var selected_asset: Dictionary = {}
var is_networked: bool = false
var hover_position: Vector3 = Vector3.ZERO
var hover_normal: Vector3 = Vector3.UP
var brushes: Dictionary = {}

var _vegetation_tool: VegetationTool
var _preview_rotation: float = 0.0


func _ready() -> void:
	_init_brushes()


func _init_brushes() -> void:
	# Lazy load brush scripts when needed
	pass


## Check if the editor is in an active editing mode


func is_editing() -> bool:
	return is_editing_active and current_tool != ToolType.NONE


## Set the editing mode


func set_editing_mode(enabled: bool) -> void:
	is_editing_active = enabled
	editing_mode_changed.emit(enabled)


## Select a tool by type


func select_tool(tool_type: ToolType) -> void:
	current_tool = tool_type
	tool_changed.emit(tool_type)


## Cycle to the next tool


func next_tool() -> void:
	var next_idx := (current_tool + 1) % ToolType.size()
	current_tool = next_idx as ToolType
	tool_changed.emit(current_tool)


## Previous tool


func previous_tool() -> void:
	var prev_idx := current_tool - 1
	if prev_idx < 0:
		prev_idx = ToolType.size() - 1
	current_tool = prev_idx as ToolType
	tool_changed.emit(current_tool)


## Request environment change (Networked)


func request_environment_change(type: String, value: Variant) -> void:
	var data: Dictionary = {"type": type, "value": value}

	if is_networked:
		network_action_requested.emit("change_environment", data)
		return

	# Apply locally
	remote_change_environment(data)


## Set selected asset from palette


func set_selected_asset(asset_data: Dictionary) -> void:
	selected_asset = asset_data

	# Lazy load scene if missing
	if not selected_asset.has("scene") and selected_asset.has("scene_path"):
		var path: String = selected_asset["scene_path"]
		if ResourceLoader.exists(path):
			selected_asset["scene"] = load(path)


## Clear selection


func clear_selection() -> void:
	selected_nodes = []
	selected_asset = {}
	selection_changed.emit(selected_nodes)


## Handle 3D input from editor plugin


func handle_3d_input(camera: Camera3D, event: InputEvent, grid_system: Node) -> int:
	if not is_editing():
		return LocalEditorGlobals.AFTER_GUI_INPUT_PASS

	# Mouse motion - update hover position
	if event is InputEventMouseMotion:
		_update_hover_position(camera, event.position, grid_system)
		return LocalEditorGlobals.AFTER_GUI_INPUT_PASS

	# Mouse button - apply tool
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			return _apply_current_tool()
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			return _cancel_current_operation()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_rotate_preview(1)
			return LocalEditorGlobals.AFTER_GUI_INPUT_STOP
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_rotate_preview(-1)
			return LocalEditorGlobals.AFTER_GUI_INPUT_STOP

	# Keyboard shortcuts
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				_rotate_preview(1)
				return LocalEditorGlobals.AFTER_GUI_INPUT_STOP
			KEY_BRACKETLEFT:
				brush_size = Vector3i(
					max(1, brush_size.x - 1),
					max(1, brush_size.y - 1),
					max(1, brush_size.z - 1)
				)
				brush_size_changed.emit(brush_size)
				return LocalEditorGlobals.AFTER_GUI_INPUT_STOP
			KEY_BRACKETRIGHT:
				brush_size = Vector3i(
					brush_size.x + 1,
					brush_size.y + 1,
					brush_size.z + 1
				)
				brush_size_changed.emit(brush_size)
				return LocalEditorGlobals.AFTER_GUI_INPUT_STOP
			KEY_ESCAPE:
				current_tool = ToolType.NONE
				return LocalEditorGlobals.AFTER_GUI_INPUT_STOP

	return LocalEditorGlobals.AFTER_GUI_INPUT_PASS


func _update_hover_position(camera: Camera3D, screen_pos: Vector2, grid_system: Node) -> void:
	# Raycast from camera to find hover position
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var to := from + dir * 1000.0

	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false

	var result := space_state.intersect_ray(query)
	if result:
		hover_position = grid_system.snap_to_grid(result.position)
		hover_normal = result.normal
	else:
		# Default to XZ plane at y=0
		var t := -from.y / dir.y if dir.y != 0 else 0.0
		if t > 0:
			var plane_hit := from + dir * t
			hover_position = grid_system.snap_to_grid(plane_hit)
			hover_normal = Vector3.UP


func get_tool_name(tool_type: ToolType) -> String:
	match tool_type:
		ToolType.SELECT:
			return "Select"
		ToolType.BLOCK_BRUSH:
			return "Block"
		ToolType.PAINT_BRUSH:
			return "Paint"
		ToolType.ENTITY_PLACER:
			return "Entity"
		ToolType.CONNECT:
			return "Connect"
		ToolType.ERASER:
			return "Eraser"
		ToolType.SPAWN_POINT:
			return "Spawn Point"
		ToolType.VEGETATION:
			return "Vegetation"
		ToolType.NONE:
			return "None"
	return "Unknown"


## Public accessor for level root


func get_level_root() -> Node3D:
	return _get_level_root()


func _apply_current_tool() -> int:
	match current_tool:
		ToolType.BLOCK_BRUSH:
			return _apply_block_brush()
		ToolType.PAINT_BRUSH:
			return _apply_paint_brush()
		ToolType.ERASER:
			return _apply_eraser()
		ToolType.ENTITY_PLACER:
			return _apply_entity_placer()
		ToolType.SPAWN_POINT:
			return _apply_spawn_point()
		ToolType.CONNECT:
			return _apply_connection()
		ToolType.VEGETATION:
			return _apply_vegetation()
		_:
			return LocalEditorGlobals.AFTER_GUI_INPUT_PASS


func _apply_block_brush() -> int:
	if selected_asset.is_empty():
		return LocalEditorGlobals.AFTER_GUI_INPUT_PASS

	# Get undo/redo from editor
	var undo := LocalEditorGlobals.get_undo_redo()
	undo.create_action("Place Block")

	# Create CSG block at hover position

	var block := CSGBox3D.new()
	block.size = Vector3(brush_size) * get_grid_size()
	block.position = hover_position

	# Apply material if available
	if selected_asset.has("material"):
		block.material = selected_asset.material

	# Networked Mode Interception
	if is_networked:
		var data: Dictionary = {
			"type": "block_brush",
			"position": hover_position,
			"size": block.size,
			"material_path":
			selected_asset.material.resource_path if selected_asset.get("material") else ""
		}
		network_action_requested.emit("place_block", data)
		block.free()
		return LocalEditorGlobals.AFTER_GUI_INPUT_STOP

	# Get level root or current scene
	var parent := _get_level_root()
	if parent:
		undo.add_do_method(Callable(parent, "add_child").bind(block))
		var edited_root: Node = LocalEditorGlobals.get_edited_scene_root()
		if edited_root:
			undo.add_do_property(block, "owner", edited_root)
		undo.add_undo_method(Callable(parent, "remove_child").bind(block))
		undo.add_undo_method(Callable(block, "queue_free"))
		undo.commit_action()
		return LocalEditorGlobals.AFTER_GUI_INPUT_STOP

	block.queue_free()
	return LocalEditorGlobals.AFTER_GUI_INPUT_PASS


func _apply_paint_brush() -> int:
	if selected_asset.is_empty() or not selected_asset.has("material"):
		return LocalEditorGlobals.AFTER_GUI_INPUT_PASS

	# Raycast to find CSG node under cursor
	var target: Node = _get_node_under_cursor()
	if not target or not target is CSGShape3D:
		return LocalEditorGlobals.AFTER_GUI_INPUT_PASS

	# Networked Mode Interception
	if is_networked:
		var relative_path: String = target.name
		if target.get_parent().name != "LevelRoot":
			relative_path = target.get_parent().name + "/" + target.name

		var data: Dictionary = {
			"path": relative_path, "material_path": selected_asset.material.resource_path
		}
		network_action_requested.emit("paint_node", data)
		return LocalEditorGlobals.AFTER_GUI_INPUT_STOP

	var undo := LocalEditorGlobals.get_undo_redo()
	var old_material: Material = target.material
	var new_material: Material = selected_asset.material

	undo.create_action("Paint Block")
	undo.add_do_property(target, "material", new_material)
	undo.add_undo_property(target, "material", old_material)
	undo.commit_action()

	return LocalEditorGlobals.AFTER_GUI_INPUT_STOP


func _apply_eraser() -> int:
	var target: Node = _get_node_under_cursor()
	if not target:
		return LocalEditorGlobals.AFTER_GUI_INPUT_PASS

	# Don't erase the level root or scene root
	var scene_root := LocalEditorGlobals.get_edited_scene_root()
	if target == scene_root:
		return LocalEditorGlobals.AFTER_GUI_INPUT_PASS
	if target.get_script() and target.get_script().resource_path.contains("level_root.gd"):
		return LocalEditorGlobals.AFTER_GUI_INPUT_PASS

	# Networked Mode Interception
	if is_networked:
		var relative_path: String = target.name  # Simplification, ideally we need full relative path
		if target.get_parent().name != "LevelRoot":
			relative_path = target.get_parent().name + "/" + target.name

		network_action_requested.emit("delete_node", {"path": relative_path})
		return LocalEditorGlobals.AFTER_GUI_INPUT_STOP

	var parent: Node = target.get_parent()
	var undo := LocalEditorGlobals.get_undo_redo()

	undo.create_action("Erase Node")
	undo.add_do_method(Callable(parent, "remove_child").bind(target))
	undo.add_do_method(Callable(target, "queue_free"))
	undo.add_undo_method(Callable(parent, "add_child").bind(target))
	undo.add_undo_reference(target)
	undo.commit_action()

	return LocalEditorGlobals.AFTER_GUI_INPUT_STOP


func _apply_entity_placer() -> int:
	if selected_asset.is_empty():
		return LocalEditorGlobals.AFTER_GUI_INPUT_PASS

	# Determine if we should place a SpawnPoint (dynamic) or Scene (static)
	var asset_type: String = selected_asset.get("type", "")
	var scene: PackedScene = selected_asset.get("scene")
	var asset_id: String = selected_asset.get("id", "")

	# Entities (enemies) and Interactables (items) should be SpawnPoints for multiplayer
	# Props can be static MeshInstances/Scenes

	# Special case for "Prop" category which we want to keep static
	var category: String = _get_asset_category(asset_id)

	if category == "Props" or category == "Hazards" or category == "Blocks":
		# Place as static scene
		if not scene:
			return LocalEditorGlobals.AFTER_GUI_INPUT_PASS

		var instance := scene.instantiate()
		instance.position = hover_position
		# Apply rotation
		instance.rotation.y = _preview_rotation
		instance.set_meta("level_editor_placed", true)

		var undo := LocalEditorGlobals.get_undo_redo()
		undo.create_action("Place Asset")

		var parent := _get_level_root()
		if parent:
			undo.add_do_method(Callable(parent, "add_child").bind(instance))
			var edited_root: Node = LocalEditorGlobals.get_edited_scene_root()
			if edited_root:
				undo.add_do_property(instance, "owner", edited_root)
			undo.add_undo_method(Callable(parent, "remove_child").bind(instance))
			undo.add_undo_method(Callable(instance, "queue_free"))
			undo.commit_action()
			return LocalEditorGlobals.AFTER_GUI_INPUT_STOP

	else:
		# Place as SpawnPoint (Enemy, Item, etc)
		var spawn := Node3D.new()
		spawn.set_script(SpawnPointScript)
		spawn.position = hover_position
		spawn.rotation.y = _preview_rotation
		spawn.set_meta("level_editor_placed", true)

		# Configure SpawnPoint
		if category == "Entities":
			spawn.spawn_type = 1  # ENEMY
			spawn.enemy_id = asset_id
			spawn.name = "Spawn_" + asset_id.capitalize().replace(" ", "")
		elif category == "Interactables" or category == "Items" or asset_type == "item":
			spawn.spawn_type = 2  # ITEM
			spawn.item_id = asset_id
			spawn.name = "Spawn_" + asset_id.capitalize().replace(" ", "")
		else:
			# Fallback
			if scene:
				spawn.queue_free()
				# Try placing as static scene as fallback
				return _apply_static_scene(scene)
			spawn.queue_free()
			return LocalEditorGlobals.AFTER_GUI_INPUT_PASS

		# Networked Mode Interception (Spawn Point)
		if is_networked:
			var data: Dictionary = {
				"type": "entity_placer",
				"subtype": "spawn_point",
				"spawn_type": spawn.spawn_type,
				"enemy_id": spawn.enemy_id,
				"item_id": spawn.item_id,
				"position": hover_position,
				"rotation_y": _preview_rotation
			}
			network_action_requested.emit("place_entity", data)
			spawn.free()
			return LocalEditorGlobals.AFTER_GUI_INPUT_STOP

		var undo := LocalEditorGlobals.get_undo_redo()

		undo.create_action("Place Spawn Point")

		var parent := _get_level_root()
		if parent:
			undo.add_do_method(Callable(parent, "add_child").bind(spawn))
			var edited_root: Node = LocalEditorGlobals.get_edited_scene_root()
			if edited_root:
				undo.add_do_property(spawn, "owner", edited_root)
			undo.add_undo_method(Callable(parent, "remove_child").bind(spawn))
			undo.add_undo_method(Callable(spawn, "queue_free"))
			undo.commit_action()
			return LocalEditorGlobals.AFTER_GUI_INPUT_STOP

	return LocalEditorGlobals.AFTER_GUI_INPUT_PASS


func _apply_static_scene(scene: PackedScene) -> int:
	var instance := scene.instantiate()
	instance.position = hover_position
	instance.rotation.y = _preview_rotation
	instance.set_meta("level_editor_placed", true)

	var undo := LocalEditorGlobals.get_undo_redo()
	undo.create_action("Place Static Asset")

	var parent := _get_level_root()
	if parent:
		undo.add_do_method(Callable(parent, "add_child").bind(instance))
		var edited_root: Node = LocalEditorGlobals.get_edited_scene_root()
		if edited_root:
			undo.add_do_property(instance, "owner", edited_root)
		undo.add_undo_method(Callable(parent, "remove_child").bind(instance))
		undo.add_undo_method(Callable(instance, "queue_free"))
		undo.commit_action()
		return LocalEditorGlobals.AFTER_GUI_INPUT_STOP
	return LocalEditorGlobals.AFTER_GUI_INPUT_PASS


func _apply_spawn_point() -> int:
	if selected_asset.is_empty() or not selected_asset.has("spawn_type"):
		return LocalEditorGlobals.AFTER_GUI_INPUT_PASS

	# Create SpawnPoint node
	var spawn := Node3D.new()
	spawn.set_script(SpawnPointScript)
	spawn.position = hover_position
	spawn.rotation.y = _preview_rotation

	# Set spawn type based on selected asset
	match selected_asset.spawn_type:
		"player":
			spawn.spawn_type = 0  # SpawnType.PLAYER
			spawn.name = "PlayerSpawn"
		"enemy":
			spawn.spawn_type = 1  # SpawnType.ENEMY
			spawn.name = "EnemySpawn"
		"item":
			spawn.spawn_type = 2  # SpawnType.ITEM
			spawn.name = "ItemSpawn"
		_:
			spawn.queue_free()
			return LocalEditorGlobals.AFTER_GUI_INPUT_PASS

	var undo := LocalEditorGlobals.get_undo_redo()
	undo.create_action("Place Spawn Point")

	var parent := _get_level_root()
	if parent:
		undo.add_do_method(Callable(parent, "add_child").bind(spawn))
		var edited_root: Node = LocalEditorGlobals.get_edited_scene_root()
		if edited_root:
			undo.add_do_property(spawn, "owner", edited_root)
		undo.add_undo_method(Callable(parent, "remove_child").bind(spawn))
		undo.add_undo_method(Callable(spawn, "queue_free"))
		undo.commit_action()
		return LocalEditorGlobals.AFTER_GUI_INPUT_STOP

	spawn.queue_free()
	return LocalEditorGlobals.AFTER_GUI_INPUT_PASS


func _apply_connection() -> int:
	# VISUAL CONNECTION UPDATE:
	# This logic is now handled by VisualConnectionTool via EditorFeatures.
	# We return PASS here so if the tool didn't handle it, we don't do anything fallback-wise
	# that conflicts with the new system.

	return LocalEditorGlobals.AFTER_GUI_INPUT_PASS


func _cancel_current_operation() -> int:
	clear_selection()
	return LocalEditorGlobals.AFTER_GUI_INPUT_STOP


func _rotate_preview(direction: int) -> void:
	_preview_rotation += direction * (PI / 4.0)  # 45 degree increments


func get_preview_rotation() -> float:
	return _preview_rotation


func get_grid_size() -> float:
	# Get from grid system
	var grid := get_node_or_null("../GridSystem")
	if grid and grid.has_method("get_cell_size"):
		return grid.get_cell_size()
	return 1.0


func _get_level_root() -> Node:
	# Find LevelRoot node in current scene, or use scene root
	var scene_root := LocalEditorGlobals.get_edited_scene_root()
	if not scene_root:
		return null

	# Look for LevelRoot type
	for child in scene_root.get_children():
		if child.get_script() and child.get_script().resource_path.contains("level_root.gd"):
			return child

	# Fallback to scene root
	return scene_root


## Get node under cursor using physics raycast
## Returns null if no node found


func _get_node_under_cursor() -> Node:
	# Use the viewport to get input info
	var camera := LocalEditorGlobals.get_editor_camera_3d()
	if not camera:
		return null

	# Use stored hover position to find nearby objects
	var space_state := camera.get_world_3d().direct_space_state

	# Raycast from camera through hover position
	var from := camera.global_position
	var to := hover_position + (hover_position - from).normalized() * 10.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true

	var result := space_state.intersect_ray(query)
	if result and result.collider:
		# Get the parent node (collider might be a shape)
		var collider: Node = result.collider
		if collider.get_parent():
			return collider.get_parent()
		return collider

	# Fallback: find closest node to hover_position in level root
	var level_root := _get_level_root()
	if not level_root:
		return null

	var closest_node: Node = null
	var closest_dist: float = 2.0  # Max distance to consider

	for child in level_root.get_children():
		if child is Node3D:
			var dist := (child as Node3D).global_position.distance_to(hover_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_node = child

	return closest_node


func _get_asset_category(id: String) -> String:
	# Helper to find category name for an asset ID
	# In a real scenario, this should be passed from AssetRegistry or stored in selected_asset
	var registry: Node = get_node_or_null("../AssetRegistry")
	if not registry:
		return "Blocks"

	# Check all categories
	for cat_name: String in registry.get_category_names():
		var cat_enum: int = registry.get_category_by_name(cat_name)
		var assets: Array = registry.assets.get(cat_enum, [])
		for asset: Dictionary in assets:
			if asset.id == id:
				return cat_name

	return "Blocks"


# ============================================================================
# REMOTE EXECUTION (Called by NetworkEditor)
# ============================================================================


func remote_place_block(data: Dictionary) -> void:
	var block := CSGBox3D.new()
	block.size = data.get("size", Vector3.ONE)
	block.position = data.get("position", Vector3.ZERO)

	var mat_path: String = data.get("material_path", "")
	if not mat_path.is_empty():
		block.material = load(mat_path)

	var parent := _get_level_root()
	if parent:
		parent.add_child(block)
		block.owner = parent.get_tree().edited_scene_root


func remote_delete_node(relative_path: String) -> void:
	var parent := _get_level_root()
	if not parent:
		return

	var node: Node = parent.get_node_or_null(relative_path)
	if node:
		node.queue_free()


func remote_paint_node(data: Dictionary) -> void:
	var parent := _get_level_root()
	if not parent:
		return

	var node: Node = parent.get_node_or_null(data.get("path", ""))
	if node and node is CSGShape3D:
		var mat_path: String = data.get("material_path", "")
		if not mat_path.is_empty():
			node.material = load(mat_path)


func remote_place_entity(data: Dictionary) -> void:
	var subtype: String = data.get("subtype", "static")
	var pos: Vector3 = data.get("position", Vector3.ZERO)
	var rot_y: float = data.get("rotation_y", 0.0)

	if subtype == "static":
		var scene_path: String = data.get("scene_path", "")
		if scene_path.is_empty():
			return
		var scene: PackedScene = load(scene_path)
		if not scene:
			return

		var instance: Node = scene.instantiate()
		instance.position = pos
		instance.rotation.y = rot_y
		instance.set_meta("level_editor_placed", true)

		var parent := _get_level_root()
		if parent:
			parent.add_child(instance)
			instance.owner = parent.get_tree().edited_scene_root

	elif subtype == "spawn_point":
		var spawn: Node3D = Node3D.new()
		spawn.set_script(SpawnPointScript)
		spawn.position = pos
		spawn.rotation.y = rot_y
		spawn.spawn_type = data.get("spawn_type", 0)
		spawn.enemy_id = data.get("enemy_id", "")
		spawn.item_id = data.get("item_id", "")

		var parent := _get_level_root()
		if parent:
			parent.add_child(spawn)
			spawn.owner = parent.get_tree().edited_scene_root


func remote_connect_nodes(data: Dictionary) -> void:
	var from_path: String = data.get("from_path", "")
	var to_path: String = data.get("to_path", "")
	var channel: String = data.get("channel", "")

	if from_path.is_empty() or to_path.is_empty() or channel.is_empty():
		return

	var parent := _get_level_root()
	if not parent:
		return

	var from_node: Node = parent.get_node_or_null(from_path)
	var to_node: Node = parent.get_node_or_null(to_path)

	if from_node and to_node and parent.has_method("register_to_channel"):
		parent.register_to_channel(from_node, channel, true)
		parent.register_to_channel(to_node, channel, false)


func remote_change_environment(data: Dictionary) -> void:
	var type: String = data.get("type", "")
	var value: Variant = data.get("value")

	match type:
		"time":
			var sky: Node = _get_skybox_controller()
			if sky and sky.has_method("set_time"):
				sky.set_time(float(value))
		"clouds":
			var sky: Node = _get_skybox_controller()
			if sky and sky.has_method("set_cloud_coverage"):
				sky.set_cloud_coverage(float(value))
		"weather":
			var ws: Node = get_node_or_null("/root/WeatherSystem")
			if ws and ws.has_method("set_weather"):
				ws.set_weather(int(value))
		"wind":
			var ws: Node = get_node_or_null("/root/WeatherSystem")
			if ws and ws.has_method("set_wind"):
				# Expect value to be { "strength": x, "direction": v3 }
				if value is Dictionary:
					ws.set_wind(value.strength, value.get("direction", Vector3.ZERO))
				else:
					ws.set_wind(float(value))


func _get_skybox_controller() -> Node:
	var root := _get_level_root()
	if not root:
		return null
	# Expect it at root or under Environment
	var sky := root.get_node_or_null("SkyboxController")
	if not sky:
		sky = root.get_node_or_null("Environment/SkyboxController")
	return sky


func _apply_vegetation() -> int:
	if not _vegetation_tool:
		_vegetation_tool = VegetationToolScript.new()
		_vegetation_tool.setup(self)

	# Check for camera
	var camera := LocalEditorGlobals.get_editor_camera_3d()
	if not camera:
		return LocalEditorGlobals.AFTER_GUI_INPUT_PASS

	var res: Dictionary = {
		"position": hover_position, "normal": hover_normal, "collider": _get_node_under_cursor()
	}

	if _vegetation_tool.apply_tool(res):
		return LocalEditorGlobals.AFTER_GUI_INPUT_STOP

	return LocalEditorGlobals.AFTER_GUI_INPUT_PASS
