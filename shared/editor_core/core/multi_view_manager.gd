@tool
class_name MultiViewManager
extends Node

signal view_changed(view_mode: ViewMode)
signal camera_changed(camera: Camera3D)

enum ViewMode { PERSPECTIVE, ISOMETRIC, TOP, FRONT, SIDE, SPLIT_2D_3D }  ## Default 3D perspective  ## Isometric 2D-style view  ## Orthographic top-down  ## Orthographic front  ## Orthographic side  ## Split screen with 2D + 3D

var current_mode: ViewMode = ViewMode.PERSPECTIVE
var main_camera: Camera3D = null
var ortho_camera: Camera3D = null
var viewport_container: SubViewportContainer = null
var split_viewport: SubViewport = null
var ortho_size: float = 20.0
var isometric_angle: float = 30.0  ## Degrees from horizontal
var camera_distance: float = 50.0
var focus_point: Vector3 = Vector3.ZERO

var _original_projection: Camera3D.ProjectionType
var _original_fov: float
var _original_size: float


func _ready() -> void:
	name = "MultiViewManager"


## Setup with camera reference


func setup(camera: Camera3D, container: SubViewportContainer = null) -> void:
	main_camera = camera
	viewport_container = container

	# Store original camera settings
	if main_camera:
		_original_projection = main_camera.projection
		_original_fov = main_camera.fov
		_original_size = main_camera.size


## Set view mode


func set_view_mode(mode: ViewMode) -> void:
	if mode == current_mode:
		return

	current_mode = mode

	match mode:
		ViewMode.PERSPECTIVE:
			_setup_perspective_view()
		ViewMode.ISOMETRIC:
			_setup_isometric_view()
		ViewMode.TOP:
			_setup_orthographic_view(Vector3.UP, Vector3.FORWARD)
		ViewMode.FRONT:
			_setup_orthographic_view(Vector3.FORWARD, Vector3.UP)
		ViewMode.SIDE:
			_setup_orthographic_view(Vector3.RIGHT, Vector3.UP)
		ViewMode.SPLIT_2D_3D:
			_setup_split_view()

	view_changed.emit(mode)


## Cycle through view modes


func cycle_view_mode() -> void:
	var next_mode: int = (current_mode + 1) % ViewMode.size()
	set_view_mode(next_mode as ViewMode)


## Setup standard perspective view


func _setup_perspective_view() -> void:
	if not main_camera:
		return

	main_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	main_camera.fov = _original_fov if _original_fov > 0 else 70.0

	# Disable split view
	_disable_split_view()

	camera_changed.emit(main_camera)


## Setup isometric view


func _setup_isometric_view() -> void:
	if not main_camera:
		return

	main_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	main_camera.size = ortho_size

	# Position camera for isometric view
	var angle_rad: float = deg_to_rad(isometric_angle)
	var offset := Vector3(1, sin(angle_rad), 1).normalized() * camera_distance

	main_camera.global_position = focus_point + offset
	main_camera.look_at(focus_point)

	# Lock Y rotation to 45 degrees for isometric
	main_camera.rotation.y = deg_to_rad(45)

	_disable_split_view()
	camera_changed.emit(main_camera)


## Setup orthographic view from direction


func _setup_orthographic_view(direction: Vector3, up: Vector3) -> void:
	if not main_camera:
		return

	main_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	main_camera.size = ortho_size

	# Position camera
	main_camera.global_position = focus_point + direction * camera_distance

	# Use look_at with explicit up vector
	var target: Vector3 = focus_point
	main_camera.look_at(target, up)

	_disable_split_view()
	camera_changed.emit(main_camera)


## Setup split 2D/3D view


func _setup_split_view() -> void:
	if not viewport_container:
		push_warning("[MultiViewManager] No viewport container for split view")
		_setup_perspective_view()
		return

	# Restore perspective on main camera
	main_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	main_camera.fov = _original_fov if _original_fov > 0 else 70.0

	# Create or show split viewport
	if not split_viewport:
		_create_split_viewport()

	split_viewport.get_parent().visible = true

	# Position ortho camera for top-down
	if ortho_camera:
		ortho_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		ortho_camera.size = ortho_size
		ortho_camera.global_position = focus_point + Vector3.UP * camera_distance
		ortho_camera.look_at(focus_point)

	camera_changed.emit(main_camera)


func _create_split_viewport() -> void:
	if not viewport_container:
		return

	# Create container for split view
	var split_container := SubViewportContainer.new()
	split_container.name = "SplitViewContainer"
	split_container.stretch = true
	split_container.custom_minimum_size = Vector2(200, 200)
	split_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Add to the right of main viewport
	viewport_container.get_parent().add_child(split_container)

	# Create viewport
	split_viewport = SubViewport.new()
	split_viewport.handle_input_locally = true
	split_container.add_child(split_viewport)

	# Create ortho camera
	ortho_camera = Camera3D.new()
	ortho_camera.name = "OrthoCamera"
	ortho_camera.current = true
	split_viewport.add_child(ortho_camera)


func _disable_split_view() -> void:
	if split_viewport and split_viewport.get_parent():
		split_viewport.get_parent().visible = false


## Set focus point for orthographic views


func set_focus_point(point: Vector3) -> void:
	focus_point = point

	# Update camera position if in ortho mode
	if current_mode != ViewMode.PERSPECTIVE and main_camera:
		var direction: Vector3
		match current_mode:
			ViewMode.ISOMETRIC:
				var angle_rad: float = deg_to_rad(isometric_angle)
				direction = Vector3(1, sin(angle_rad), 1).normalized()
			ViewMode.TOP:
				direction = Vector3.UP
			ViewMode.FRONT:
				direction = Vector3.FORWARD
			ViewMode.SIDE:
				direction = Vector3.RIGHT
			_:
				direction = Vector3(1, 1, 1).normalized()

		main_camera.global_position = focus_point + direction * camera_distance


## Set orthographic size (zoom level)


func set_ortho_size(size: float) -> void:
	ortho_size = maxf(1.0, size)
	if main_camera and main_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		main_camera.size = ortho_size
	if ortho_camera:
		ortho_camera.size = ortho_size


## Zoom in orthographic view


func zoom_in(factor: float = 1.2) -> void:
	set_ortho_size(ortho_size / factor)


## Zoom out orthographic view


func zoom_out(factor: float = 1.2) -> void:
	set_ortho_size(ortho_size * factor)


## Handle NumPad input for view switching


func handle_numpad_input(keycode: int) -> bool:
	match keycode:
		KEY_KP_ENTER:
			# Toggle isometric
			if current_mode == ViewMode.ISOMETRIC:
				set_view_mode(ViewMode.PERSPECTIVE)
			else:
				set_view_mode(ViewMode.ISOMETRIC)
			return true
		KEY_KP_7:
			# Top view
			set_view_mode(ViewMode.TOP)
			return true
		KEY_KP_1:
			# Front view
			set_view_mode(ViewMode.FRONT)
			return true
		KEY_KP_3:
			# Side view
			set_view_mode(ViewMode.SIDE)
			return true
		KEY_KP_5:
			# Toggle ortho/perspective
			if main_camera:
				if main_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
					set_view_mode(ViewMode.PERSPECTIVE)
				else:
					set_view_mode(ViewMode.ISOMETRIC)
			return true
		KEY_KP_ADD:
			zoom_in()
			return true
		KEY_KP_SUBTRACT:
			zoom_out()
			return true

	return false


## Get current view mode name


func get_mode_name() -> String:
	return ViewMode.keys()[current_mode]


## Check if in orthographic mode


func is_orthographic() -> bool:
	return current_mode != ViewMode.PERSPECTIVE
