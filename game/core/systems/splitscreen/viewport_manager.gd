class_name ViewportManager
extends Node

## ViewportManager creates and manages individual player viewports for splitscreen
## multiplayer. This component handles SubViewport creation, grid layout calculation,
## aspect ratio maintenance, and rendering quality management. It supports 2x2 (4 players),
## 2x3 (5-6 players), and 3x2 (5-6 players) grid layouts with automatic arrangement
## based on player count.

## Signals

## Emitted when a viewport is created for a player
signal viewport_created(player_id: int, viewport: SubViewport)

## Emitted when a viewport is destroyed
signal viewport_destroyed(player_id: int)

## Emitted when the viewport layout changes
signal layout_changed(layout_type: LayoutType)

## Layout types for viewport arrangement
# 4 players in 2x2 grid, 5-6 players in 2x3 or 3x2 grid
enum LayoutType { GRID_2X2, GRID_2X3, GRID_3X2 }

## Internal state
var _viewports: Dictionary = {}  # player_id -> SubViewport
var _viewport_containers: Dictionary = {}  # player_id -> SubViewportContainer
var _player_instances: Dictionary = {}  # player_id -> Node (player instance)
var _cameras: Dictionary = {}  # player_id -> Camera3D
var _current_layout: LayoutType = LayoutType.GRID_2X2
var _viewport_container_root: Control = null
var _rendering_quality: float = 1.0
var _layout_cache: Dictionary = {}  # PERFORMANCE FIX: Cache pre-calculated layouts

## Configuration
var msaa_mode: Viewport.MSAA = Viewport.MSAA_2X
var fxaa_enabled: bool = true
var shadow_quality: String = "medium"
var clear_color: Color = Color.BLACK
var aspect_ratio_variance_threshold: float = 0.05


func _ready() -> void:
	# Create root container for all viewport containers
	_viewport_container_root = Control.new()
	_viewport_container_root.name = "SplitscreenViewportRoot"
	_viewport_container_root.anchor_right = 1.0
	_viewport_container_root.anchor_bottom = 1.0
	add_child(_viewport_container_root)

	# PERFORMANCE FIX: Pre-calculate all possible layouts
	_precalculate_layouts()


## Create a viewport for a player
## Returns the created SubViewport
func create_viewport(player_id: int, player_scene: PackedScene) -> SubViewport:
	if _viewports.has(player_id):
		push_error("Viewport for player %d already exists" % player_id)
		return _viewports[player_id]

	# Create SubViewportContainer
	var container: SubViewportContainer = SubViewportContainer.new()
	container.name = "Player%dContainer" % player_id
	container.stretch = true
	_viewport_container_root.add_child(container)
	_viewport_containers[player_id] = container

	# Create SubViewport
	var viewport: SubViewport = SubViewport.new()
	viewport.name = "Player%dViewport" % player_id
	viewport.size = Vector2i(1920, 1080)  # Will be adjusted by layout
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_to_group("splitscreen_viewport")
	container.add_child(viewport)
	_viewports[player_id] = viewport

	# Apply rendering settings
	_apply_rendering_settings(viewport)

	# Instantiate player scene
	if player_scene != null:
		var player_instance: Node = player_scene.instantiate()
		player_instance.name = "Player%d" % player_id
		viewport.add_child(player_instance)
		_player_instances[player_id] = player_instance

		# Create and configure camera
		var camera: Camera3D = Camera3D.new()
		camera.name = "Player%dCamera" % player_id
		camera.current = true
		viewport.add_child(camera)
		_cameras[player_id] = camera

	viewport_created.emit(player_id, viewport)

	return viewport


## Destroy a viewport for a player
func destroy_viewport(player_id: int) -> void:
	if not _viewports.has(player_id):
		push_warning("Viewport for player %d does not exist" % player_id)
		return

	# Clean up player instance
	if _player_instances.has(player_id):
		var player_instance: Node = _player_instances[player_id]
		if is_instance_valid(player_instance):
			player_instance.queue_free()
		_player_instances.erase(player_id)

	# Clean up camera
	if _cameras.has(player_id):
		var camera: Camera3D = _cameras[player_id]
		if is_instance_valid(camera):
			camera.queue_free()
		_cameras.erase(player_id)

	# Clean up viewport
	var viewport: SubViewport = _viewports[player_id]
	if is_instance_valid(viewport):
		viewport.queue_free()
	_viewports.erase(player_id)

	# Clean up container
	if _viewport_containers.has(player_id):
		var container: SubViewportContainer = _viewport_containers[player_id]
		if is_instance_valid(container):
			container.queue_free()
		_viewport_containers.erase(player_id)

	viewport_destroyed.emit(player_id)


## Arrange viewports in a grid layout based on player count
func arrange_viewports(player_count: int) -> void:
	var layout: LayoutType = _calculate_layout_type(player_count)
	_current_layout = layout

	var rects: Array[Rect2] = _calculate_viewport_rects(player_count, layout)
	var player_ids: Array = _viewports.keys()
	player_ids.sort()

	for i in range(min(player_ids.size(), rects.size())):
		var player_id: int = player_ids[i]
		var rect: Rect2 = rects[i]

		if _viewport_containers.has(player_id):
			var container: SubViewportContainer = _viewport_containers[player_id]
			_apply_rect_to_container(container, rect)

	layout_changed.emit(layout)


## Calculate the appropriate layout type for a player count
func _calculate_layout_type(player_count: int) -> LayoutType:
	match player_count:
		4:
			return LayoutType.GRID_2X2
		5, 6:
			return LayoutType.GRID_2X3  # Default to 2x3 for 5-6 players
		_:
			return LayoutType.GRID_2X2


## Calculate viewport rectangles for a given player count and layout
## Returns an array of Rect2 with normalized coordinates (0-1)
func _calculate_viewport_rects(player_count: int, layout: LayoutType) -> Array[Rect2]:
	# PERFORMANCE FIX: Use cached layouts
	var cache_key: String = "%d_%d" % [player_count, layout]
	if _layout_cache.has(cache_key):
		return _layout_cache[cache_key]

	var rects: Array[Rect2] = []

	match layout:
		LayoutType.GRID_2X2:
			# 2x2 grid: 4 players, each 50% width × 50% height
			rects.append(Rect2(0.0, 0.0, 0.5, 0.5))  # Top-left
			rects.append(Rect2(0.5, 0.0, 0.5, 0.5))  # Top-right
			rects.append(Rect2(0.0, 0.5, 0.5, 0.5))  # Bottom-left
			rects.append(Rect2(0.5, 0.5, 0.5, 0.5))  # Bottom-right

		LayoutType.GRID_2X3:
			if player_count == 5:
				# Preserve equal player area while filling the screen: three
				# viewports use the 60% top row and two use the 40% bottom row.
				# Every viewport therefore owns exactly one fifth of the display.
				for col in range(3):
					rects.append(Rect2(col * (1.0 / 3.0), 0.0, 1.0 / 3.0, 0.6))
				for col in range(2):
					rects.append(Rect2(col * 0.5, 0.6, 0.5, 0.4))
			else:
				# 2x3 grid: 6 players, each 33.3% width × 50% height
				for row in range(2):
					for col in range(3):
						var x: float = col * (1.0 / 3.0)
						var y: float = row * 0.5
						var w: float = 1.0 / 3.0
						var h: float = 0.5
						rects.append(Rect2(x, y, w, h))

		LayoutType.GRID_3X2:
			# 3x2 grid: 5-6 players, each 50% width × 33.3% height
			for row in range(3):
				for col in range(2):
					var x: float = col * 0.5
					var y: float = row * (1.0 / 3.0)
					var w: float = 0.5
					var h: float = 1.0 / 3.0
					rects.append(Rect2(x, y, w, h))

	# Return only the number of rects needed
	var result: Array[Rect2] = rects.slice(0, player_count)
	_layout_cache[cache_key] = result
	return result


func _precalculate_layouts() -> void:
	# PERFORMANCE FIX: Pre-calculate all common layouts at startup
	# This eliminates the nested loop overhead during gameplay
	for layout: LayoutType in [LayoutType.GRID_2X2, LayoutType.GRID_2X3, LayoutType.GRID_3X2]:
		for player_count in range(1, 7):  # Support 1-6 players
			_calculate_viewport_rects(player_count, layout)


## Apply a normalized rect to a viewport container
func _apply_rect_to_container(container: SubViewportContainer, rect: Rect2) -> void:
	container.anchor_left = rect.position.x
	container.anchor_top = rect.position.y
	container.anchor_right = rect.position.x + rect.size.x
	container.anchor_bottom = rect.position.y + rect.size.y
	container.offset_left = 0
	container.offset_top = 0
	container.offset_right = 0
	container.offset_bottom = 0


## Apply rendering settings to a viewport
func _apply_rendering_settings(viewport: SubViewport) -> void:
	viewport.msaa_3d = msaa_mode

	# Screen-space AA only works with Forward+ or Mobile renderer
	# Check renderer to avoid warning
	var rendering_method: String = ProjectSettings.get_setting(
		"rendering/renderer/rendering_method", "forward_plus"
	)
	if rendering_method in ["forward_plus", "mobile"]:
		viewport.screen_space_aa = (
			Viewport.SCREEN_SPACE_AA_FXAA if fxaa_enabled else Viewport.SCREEN_SPACE_AA_DISABLED
		)

	# Set clear color
	var world_env: World3D = viewport.world_3d
	if world_env == null:
		world_env = World3D.new()
		viewport.world_3d = world_env


## Set rendering quality level (0.0 - 1.0)
## Adjusts MSAA, shadows, and render scale based on quality
func set_rendering_quality(quality_level: float) -> void:
	_rendering_quality = clamp(quality_level, 0.0, 1.0)

	# Determine quality settings based on level
	if _rendering_quality >= 0.8:
		# High quality
		msaa_mode = Viewport.MSAA_4X
		shadow_quality = "high"
	elif _rendering_quality >= 0.5:
		# Medium quality
		msaa_mode = Viewport.MSAA_2X
		shadow_quality = "medium"
	else:
		# Low quality
		msaa_mode = Viewport.MSAA_DISABLED
		shadow_quality = "low"

	# Apply to all existing viewports
	for viewport: SubViewport in _viewports.values():
		_apply_rendering_settings(viewport)


## Get the viewport for a specific player
## Returns the SubViewport if found, null otherwise
func get_player_viewport(player_id: int) -> SubViewport:
	return _viewports.get(player_id, null)


## Get all viewports
## Returns an array of all SubViewports
func get_all_viewports() -> Array[SubViewport]:
	var viewports: Array[SubViewport] = []
	for viewport: SubViewport in _viewports.values():
		viewports.append(viewport)
	return viewports


## Get the current layout type
func get_layout_type() -> LayoutType:
	return _current_layout


## Get viewport rectangles for the current layout
func get_viewport_rects() -> Array[Rect2]:
	var player_count: int = _viewports.size()
	return _calculate_viewport_rects(player_count, _current_layout)


## Get the player instance for a specific player
func get_player_instance(player_id: int) -> Node:
	return _player_instances.get(player_id, null)


## Get the camera for a specific player
func get_camera(player_id: int) -> Camera3D:
	return _cameras.get(player_id, null)


## Get the number of active viewports
func get_viewport_count() -> int:
	return _viewports.size()


## Check if a viewport exists for a player
func has_viewport(player_id: int) -> bool:
	return _viewports.has(player_id)


## Load configuration from settings
func load_configuration(config: Dictionary) -> void:
	# Viewport settings
	var viewport_config: Dictionary = config.get("viewport", {})

	var msaa_str: String = viewport_config.get("msaa", "2x")
	msaa_mode = _parse_msaa_mode(msaa_str)

	fxaa_enabled = viewport_config.get("fxaa", true)
	shadow_quality = viewport_config.get("shadow_quality", "medium")

	var clear_color_str: String = viewport_config.get("clear_color", "#000000")
	clear_color = Color(clear_color_str)

	aspect_ratio_variance_threshold = viewport_config.get("aspect_ratio_variance_threshold", 0.05)


## Parse MSAA mode string to enum
func _parse_msaa_mode(msaa_str: String) -> Viewport.MSAA:
	match msaa_str.to_lower():
		"disabled":
			return Viewport.MSAA_DISABLED
		"2x":
			return Viewport.MSAA_2X
		"4x":
			return Viewport.MSAA_4X
		"8x":
			return Viewport.MSAA_8X
		_:
			return Viewport.MSAA_2X


## Cleanup all viewports
func cleanup_all_viewports() -> void:
	var player_ids: Array = _viewports.keys()
	for player_id: int in player_ids:
		destroy_viewport(player_id)
