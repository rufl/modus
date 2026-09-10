extends Control
class_name EmbeddedLevelEditor

signal editor_closed
signal level_saved(path: String)
signal level_loaded(path: String)

const EditorState = preload("res://shared/editor_core/core/editor_state.gd")
const AssetRegistry = preload("res://shared/editor_core/core/asset_registry.gd")
const GridSystemScript = preload("res://shared/editor_core/core/grid_system.gd")
const SelectionManagerScript = preload("res://shared/editor_core/core/selection_manager.gd")
const EditorFeaturesScript = preload("res://shared/editor_core/core/editor_features.gd")
const AssetPaletteDock = preload("res://shared/editor_core/ui/asset_palette_dock.tscn")
const ToolbarDock = preload("res://shared/editor_core/ui/toolbar_dock.tscn")
const HotbarUI = preload("res://shared/editor_core/ui/hotbar.tscn")

var editor_state: Node
var asset_registry: Node
var grid_system: Node
var selection_manager: Node
var editor_features: Node  ## Unified features controller
var palette_panel: Control
var toolbar_panel: Control
var hotbar: Control
var viewport_container: SubViewportContainer
var sub_viewport: SubViewport
var editor_camera: Camera3D
var level_root: Node3D
var _environment_panel: PanelContainer
var _env_interface: Control

var _is_active: bool = false


func _ready() -> void:
	name = "EmbeddedLevelEditor"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_layout()
	_init_systems()
	_init_ui()
	_init_viewport()

	# Start hidden until activated
	visible = false


func _setup_layout() -> void:
	# Main horizontal container
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hbox)

	# Left: Palette panel
	palette_panel = PanelContainer.new()
	palette_panel.custom_minimum_size.x = 280
	hbox.add_child(palette_panel)

	# Center: Viewport + Toolbar stack
	var center_vbox: VBoxContainer = VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(center_vbox)

	# Right: Environment panel
	_environment_panel = PanelContainer.new()
	_environment_panel.name = "EnvironmentPanel"
	_environment_panel.custom_minimum_size.x = 320
	_environment_panel.visible = false
	hbox.add_child(_environment_panel)

	# Environment Interface
	var env_interface_script: GDScript = preload(
		"res://game/editor/environment_effect_config_interface.gd"
	)
	if env_interface_script:
		_env_interface = Control.new()
		_env_interface.set_script(env_interface_script)
		_env_interface.name = "EnvironmentInterface"
		_environment_panel.add_child(_env_interface)

	# Toolbar at top
	toolbar_panel = HBoxContainer.new()
	toolbar_panel.custom_minimum_size.y = 48
	center_vbox.add_child(toolbar_panel)

	# 3D Viewport
	viewport_container = SubViewportContainer.new()
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	center_vbox.add_child(viewport_container)

	# Hotbar at bottom
	var hotbar_container: HBoxContainer = HBoxContainer.new()
	hotbar_container.custom_minimum_size.y = 64
	hotbar_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_vbox.add_child(hotbar_container)


func _init_systems() -> void:
	# Editor State (tools, selection, brush size)
	editor_state = EditorState.new()
	editor_state.name = "EditorState"
	add_child(editor_state)

	# Asset Registry (scans available assets)
	asset_registry = AssetRegistry.new()
	asset_registry.name = "AssetRegistry"
	add_child(asset_registry)

	# Grid System (snapping)
	grid_system = GridSystemScript.new()
	grid_system.name = "GridSystem"
	add_child(grid_system)

	# Selection Manager (multi-select, clipboard)
	selection_manager = SelectionManagerScript.new()
	selection_manager.name = "SelectionManager"
	add_child(selection_manager)

	# Editor Features (hotbar, console, preview, actors)
	editor_features = EditorFeaturesScript.new()
	editor_features.name = "EditorFeatures"
	add_child(editor_features)


func _init_ui() -> void:
	# Asset Palette
	if ResourceLoader.exists(AssetPaletteDock.resource_path):
		var palette: Control = AssetPaletteDock.instantiate()
		palette_panel.add_child(palette)
		if palette.has_method("setup"):
			palette.setup(asset_registry, editor_state)

	# Toolbar
	if ResourceLoader.exists(ToolbarDock.resource_path):
		var toolbar: Control = ToolbarDock.instantiate()
		toolbar_panel.add_child(toolbar)
		if toolbar.has_method("setup"):
			toolbar.setup(editor_state)

		# Connect Toolbar Actions to Features
		if editor_features:
			if toolbar.has_signal("package_requested"):
				toolbar.package_requested.connect(editor_features.package_current_level)
			if toolbar.has_signal("workshop_requested"):
				toolbar.workshop_requested.connect(editor_features.toggle_workshop)
			if toolbar.has_signal("environment_toggled"):
				toolbar.environment_toggled.connect(_on_environment_toggled)

	# Hotbar - now managed by EditorFeatures but we still instantiate UI here
	if ResourceLoader.exists(HotbarUI.resource_path):
		hotbar = HotbarUI.instantiate()
		toolbar_panel.get_parent().get_child(2).add_child(hotbar)
		if hotbar.has_method("setup"):
			hotbar.setup(editor_state, asset_registry)


func _init_viewport() -> void:
	# SubViewport for 3D editing
	sub_viewport = SubViewport.new()
	sub_viewport.handle_input_locally = true
	sub_viewport.physics_object_picking = true
	sub_viewport.size = Vector2i(1280, 720)
	viewport_container.add_child(sub_viewport)

	# Editor Camera
	editor_camera = Camera3D.new()
	editor_camera.position = Vector3(0, 5, 10)
	editor_camera.look_at(Vector3.ZERO)
	editor_camera.current = true
	sub_viewport.add_child(editor_camera)

	# Lighting
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 45, 0)
	sun.shadow_enabled = true
	sub_viewport.add_child(sun)

	# Level Root (where placed objects go)
	level_root = Node3D.new()
	level_root.name = "LevelRoot"
	sub_viewport.add_child(level_root)

	# Setup EditorFeatures with all references
	if editor_features:
		editor_features.setup(editor_state, asset_registry, grid_system, level_root, editor_camera)


func _process(_delta: float) -> void:
	if not _is_active:
		return

	_handle_camera_movement(_delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return

	# Forward to editor features first (for custom tools like Visual Connection)
	if editor_features and editor_features.has_method("handle_3d_input"):
		if editor_features.handle_3d_input(editor_camera, event):
			return

	# Forward to editor state for standard tools
	if editor_state:
		editor_state.handle_3d_input(editor_camera, event, grid_system)

	# Camera rotation (RMB drag)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		editor_camera.rotation.y -= event.relative.x * 0.005
		editor_camera.rotation.x -= event.relative.y * 0.005
		editor_camera.rotation.x = clamp(editor_camera.rotation.x, -PI / 2, PI / 2)


func _handle_camera_movement(delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return

	var speed: float = 20.0
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= 2.5

	var velocity: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		velocity -= editor_camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		velocity += editor_camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		velocity -= editor_camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		velocity += editor_camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_E):
		velocity += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		velocity -= Vector3.UP

	editor_camera.global_position += velocity.normalized() * speed * delta


## Open the embedded editor


func open() -> void:
	_is_active = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Notify network if in multiplayer
	var ns := GameManager.get_core_system("network") as NetworkSvc
	if ns and ns.network_editor:
		ns.network_editor.is_edit_mode = true


## Close the embedded editor


func close() -> void:
	_is_active = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var ns := GameManager.get_core_system("network") as NetworkSvc
	if ns and ns.network_editor:
		ns.network_editor.is_edit_mode = false

	editor_closed.emit()


## Toggle editor visibility


func toggle() -> void:
	if _is_active:
		close()
	else:
		open()


## Save current level


func save_level(path: String) -> void:
	if not level_root:
		push_error("EmbeddedLevelEditor: Cannot save without a level root")
		return

	var packed := PackedScene.new()
	var pack_error := packed.pack(level_root)
	if pack_error != OK:
		push_error("EmbeddedLevelEditor: Failed to pack level: %s" % pack_error)
		return

	var save_error := ResourceSaver.save(packed, path)
	if save_error != OK:
		push_error("EmbeddedLevelEditor: Failed to save level '%s': %s" % [path, save_error])
		return

	level_saved.emit(path)


## Load a level


func load_level(path: String) -> void:
	if not level_root:
		push_error("EmbeddedLevelEditor: Cannot load without a level root")
		return
	if not ResourceLoader.exists(path):
		push_warning("EmbeddedLevelEditor: Level does not exist: %s" % path)
		return

	var scene: PackedScene = load(path)
	if not scene:
		push_error("EmbeddedLevelEditor: Failed to load level: %s" % path)
		return

	for child: Node in level_root.get_children():
		child.free()

	var instance := scene.instantiate()
	for child: Node in instance.get_children():
		child.reparent(level_root)
	instance.free()

	level_loaded.emit(path)


func _on_environment_toggled(active: bool) -> void:
	if _environment_panel:
		_environment_panel.visible = active
		if active and _env_interface and _env_interface.has_method("refresh_zone_list"):
			_env_interface.refresh_zone_list()
