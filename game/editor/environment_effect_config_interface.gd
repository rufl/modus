@tool
class_name EnvironmentEffectConfigInterface
extends Control

## Environmental Effect Configuration Interface
## Features: Zone editor, parameter tuning, preview system, and save/load presets

# Signals
signal zone_created(zone: EnvironmentVolume)
signal zone_modified(zone: EnvironmentVolume)
signal zone_deleted(zone: EnvironmentVolume)
signal preset_saved(preset_name: String)
signal preset_loaded(preset_name: String)
signal preset_deleted(preset_name: String)

# UI Elements
var _main_container: VBoxContainer
var _zone_list: Tree
var _preset_list: Tree
var _preview_viewport: SubViewport
var _environment_inspector: PanelContainer
var _parameter_tuner: VBoxContainer

# Current state
var _selected_zone: EnvironmentVolume = null
var _selected_preset: String = ""
var _zones: Array[EnvironmentVolume] = []
var _presets: Dictionary = {}
var _preview_camera: Camera3D
var _preview_entities: Array[Node3D] = []

# Exported properties for UI configuration
@export_group("UI Settings")
@export var show_zone_editor: bool = true
@export var show_parameter_tuner: bool = true
@export var show_preset_manager: bool = true
@export var show_preview_viewport: bool = true
@export var default_preset_path: String = "user://environment_presets/"


func _ready() -> void:
	# Initialize the interface
	_setup_ui()
	_load_presets()

	# Connect to scene tree for zone detection
	if not Engine.is_editor_hint():
		get_tree().node_added.connect(_on_node_added)


func _setup_ui() -> void:
	# Main container
	_main_container = VBoxContainer.new()
	_main_container.name = "MainContainer"
	self.add_child(_main_container)

	# Create tab container for organization
	var tab_container := TabContainer.new()
	tab_container.name = "TabContainer"
	_main_container.add_child(tab_container)

	# Zones tab
	if show_zone_editor:
		_create_zone_editor_tab(tab_container)

	# Parameters tab
	if show_parameter_tuner:
		_create_parameter_tuner_tab(tab_container)

	# Presets tab
	if show_preset_manager:
		_create_preset_manager_tab(tab_container)

	# Preview tab
	if show_preview_viewport:
		_create_preview_tab(tab_container)


func _create_zone_editor_tab(tab_container: TabContainer) -> void:
	var zone_tab := VBoxContainer.new()
	zone_tab.name = "Zones"
	tab_container.add_child(zone_tab)
	tab_container.set_tab_title(tab_container.get_tab_count() - 1, "Zones")

	# Toolbar for zone operations
	var toolbar := HBoxContainer.new()
	zone_tab.add_child(toolbar)

	var create_btn := Button.new()
	create_btn.text = "Create Zone"
	create_btn.pressed.connect(_create_new_zone)
	toolbar.add_child(create_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Delete Selected"
	delete_btn.pressed.connect(_delete_selected_zone)
	toolbar.add_child(delete_btn)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(refresh_zone_list)
	toolbar.add_child(refresh_btn)

	# Zone list
	_zone_list = Tree.new()
	_zone_list.name = "ZoneList"
	_zone_list.columns = 2
	_zone_list.set_column_title(0, "Name")
	_zone_list.set_column_title(1, "Type")
	_zone_list.column_titles_visible = true
	zone_tab.add_child(_zone_list)

	_zone_list.item_selected.connect(_on_zone_selected)

	refresh_zone_list()


func _create_parameter_tuner_tab(tab_container: TabContainer) -> void:
	var param_tab := VBoxContainer.new()
	param_tab.name = "Parameters"
	tab_container.add_child(param_tab)
	tab_container.set_tab_title(tab_container.get_tab_count() - 1, "Parameters")

	# Property editor for environment parameters
	_environment_inspector = PanelContainer.new()
	_environment_inspector.name = "EnvironmentInspector"
	param_tab.add_child(_environment_inspector)

	# Create scroll container for properties
	var scroll := ScrollContainer.new()
	_environment_inspector.add_child(scroll)

	_parameter_tuner = VBoxContainer.new()
	scroll.add_child(_parameter_tuner)


func _create_preset_manager_tab(tab_container: TabContainer) -> void:
	var preset_tab := VBoxContainer.new()
	preset_tab.name = "Presets"
	tab_container.add_child(preset_tab)
	tab_container.set_tab_title(tab_container.get_tab_count() - 1, "Presets")

	# Preset toolbar
	var preset_toolbar := HBoxContainer.new()
	preset_tab.add_child(preset_toolbar)

	var save_preset_btn := Button.new()
	save_preset_btn.text = "Save Preset"
	save_preset_btn.pressed.connect(_save_current_preset)
	preset_toolbar.add_child(save_preset_btn)

	var load_preset_btn := Button.new()
	load_preset_btn.text = "Load Preset"
	load_preset_btn.pressed.connect(_load_selected_preset)
	preset_toolbar.add_child(load_preset_btn)

	var delete_preset_btn := Button.new()
	delete_preset_btn.text = "Delete Preset"
	delete_preset_btn.pressed.connect(_delete_selected_preset)
	preset_toolbar.add_child(delete_preset_btn)

	# Preset list
	_preset_list = Tree.new()
	_preset_list.name = "PresetList"
	_preset_list.columns = 2
	_preset_list.set_column_title(0, "Name")
	_preset_list.set_column_title(1, "Type")
	_preset_list.column_titles_visible = true
	preset_tab.add_child(_preset_list)

	_preset_list.item_selected.connect(_on_preset_selected)


func _create_preview_tab(tab_container: TabContainer) -> void:
	var preview_tab := VBoxContainer.new()
	preview_tab.name = "Preview"
	tab_container.add_child(preview_tab)
	tab_container.set_tab_title(tab_container.get_tab_count() - 1, "Preview")

	# Preview viewport
	_preview_viewport = SubViewport.new()
	_preview_viewport.name = "PreviewViewport"
	_preview_viewport.size = Vector2i(400, 300)
	preview_tab.add_child(_preview_viewport)

	# Add a camera to the preview
	_preview_camera = Camera3D.new()
	_preview_camera.name = "PreviewCamera"
	_preview_camera.current = true
	_preview_viewport.add_child(_preview_camera)

	# Add some sample environment entities
	_create_preview_entities()


func _create_preview_entities() -> void:
	# Create sample environment entities for preview
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "PreviewFloor"
	floor_mesh.mesh = BoxMesh.new()
	floor_mesh.mesh.size = Vector3(10, 0.1, 10)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.3, 0.4)
	floor_mesh.material_override = floor_mat
	_preview_viewport.add_child(floor_mesh)

	# Add a test cube to show effects
	var test_cube := MeshInstance3D.new()
	test_cube.name = "TestCube"
	test_cube.mesh = BoxMesh.new()
	test_cube.mesh.size = Vector3(1, 1, 1)
	test_cube.position = Vector3(0, 1, 0)
	var cube_mat := StandardMaterial3D.new()
	cube_mat.albedo_color = Color(0.8, 0.5, 0.2)
	test_cube.material_override = cube_mat
	_preview_viewport.add_child(test_cube)

	_preview_entities.append(test_cube)


## Create a new environment zone
func _create_new_zone() -> void:
	if not get_tree().current_scene:
		push_warning("No current scene - cannot create zone")
		return

	# Create new environment volume
	var new_zone_scene: PackedScene = preload(
		"res://game/world/actors/volumes/environment_volume.tscn"
	)
	var new_zone: EnvironmentVolume

	if new_zone_scene:
		new_zone = new_zone_scene.instantiate() as EnvironmentVolume
	else:
		# Create programmatically if scene not found
		new_zone = EnvironmentVolume.new()

	if new_zone:
		new_zone.name = "EnvironmentZone_" + str(Time.get_ticks_msec())
		get_tree().current_scene.add_child(new_zone)

		# Set as selected
		_selected_zone = new_zone
		_zones.append(new_zone)

		# Update UI
		refresh_zone_list()
		_update_property_editor()

		zone_created.emit(new_zone)


## Delete selected zone
func _delete_selected_zone() -> void:
	if not _selected_zone:
		push_warning("No zone selected for deletion")
		return

	if is_instance_valid(_selected_zone):
		_zones.erase(_selected_zone)
		_selected_zone.queue_free()
		_selected_zone = null

		refresh_zone_list()
		_clear_property_editor()

		zone_deleted.emit(_selected_zone)


## Refresh the zone list display
func refresh_zone_list() -> void:
	if not _zone_list:
		return

	_zone_list.clear()

	# Add all environment volumes in the scene
	var all_zones: Array[Node] = get_tree().get_nodes_in_group("environment_zone")
	for node: Node in all_zones:
		if node is EnvironmentVolume:
			var item := _zone_list.create_item()
			item.set_text(0, node.name)
			item.set_text(1, "Environment")
			item.set_metadata(0, node)

	# Also search in the current scene directly
	if get_tree().current_scene:
		_find_zones_recursive(get_tree().current_scene)


func _find_zones_recursive(node: Node) -> void:
	if node is EnvironmentVolume:
		var item := _zone_list.create_item()
		item.set_text(0, node.name)
		item.set_text(1, "Environment")
		item.set_metadata(0, node)

	for child in node.get_children():
		_find_zones_recursive(child)


## Handle zone selection
func _on_zone_selected() -> void:
	var selected: TreeItem = _zone_list.get_selected()
	if selected:
		_selected_zone = selected.get_metadata(0) as EnvironmentVolume
		_update_property_editor()


## Update property editor with selected zone properties
func _update_property_editor() -> void:
	if not _selected_zone or not _parameter_tuner:
		_clear_property_editor()
		return

	# Clear existing controls
	for child in _parameter_tuner.get_children():
		child.queue_free()

	# Create property editors for the selected zone
	_add_property_editor(
		"Weather Override", "weather_override", _selected_zone.weather_override, TYPE_INT
	)
	_add_property_editor(
		"Gravity Multiplier", "gravity_multiplier", _selected_zone.gravity_multiplier, TYPE_FLOAT
	)
	_add_property_editor(
		"Fog Density Override",
		"fog_density_override",
		_selected_zone.fog_density_override,
		TYPE_FLOAT
	)

	# Wind properties
	_add_header("Wind Properties")
	_add_property_editor(
		"Enable Wind Zone", "enable_wind_zone", _selected_zone.enable_wind_zone, TYPE_BOOL
	)
	if _selected_zone.enable_wind_zone:
		_add_property_editor("Wind Force", "wind_force", _selected_zone.wind_force, TYPE_VECTOR3)
		_add_property_editor(
			"Wind Turbulence", "wind_turbulence", _selected_zone.wind_turbulence, TYPE_FLOAT
		)
		_add_property_editor("Wind Radius", "wind_radius", _selected_zone.wind_radius, TYPE_FLOAT)
		_add_property_editor(
			"Wind Attenuation", "wind_attenuation", _selected_zone.wind_attenuation, TYPE_FLOAT
		)

	# Atmospheric properties
	_add_header("Atmospheric Properties")
	_add_property_editor(
		"Enable Atmospheric Zone",
		"enable_atmospheric_zone",
		_selected_zone.enable_atmospheric_zone,
		TYPE_BOOL
	)
	if _selected_zone.enable_atmospheric_zone:
		_add_property_editor(
			"Atmospheric Density",
			"atmospheric_density",
			_selected_zone.atmospheric_density,
			TYPE_FLOAT
		)
		_add_property_editor(
			"Atmospheric Color", "atmospheric_color", _selected_zone.atmospheric_color, TYPE_COLOR
		)
		_add_property_editor(
			"Light Absorption", "light_absorption", _selected_zone.light_absorption, TYPE_FLOAT
		)
		_add_property_editor(
			"Light Scattering", "light_scattering", _selected_zone.light_scattering, TYPE_FLOAT
		)

	# Physics properties
	_add_header("Physics Properties")
	_add_property_editor(
		"Air Resistance", "air_resistance", _selected_zone.air_resistance, TYPE_FLOAT
	)
	_add_property_editor(
		"Friction Multiplier", "friction_multiplier", _selected_zone.friction_multiplier, TYPE_FLOAT
	)
	_add_property_editor(
		"Bounce Multiplier", "bounce_multiplier", _selected_zone.bounce_multiplier, TYPE_FLOAT
	)


## Add a property editor control
func _add_property_editor(
	label_text: String, property_name: String, current_value: Variant, value_type: int
) -> void:
	var hbox := HBoxContainer.new()

	var label := Label.new()
	label.text = label_text
	hbox.add_child(label)

	var editor_control: Control

	match value_type:
		TYPE_BOOL:
			var checkbox := CheckBox.new()
			checkbox.button_pressed = current_value
			checkbox.toggled.connect(_on_property_changed.bind(property_name, value_type))
			editor_control = checkbox
		TYPE_FLOAT:
			var spinbox := SpinBox.new()
			spinbox.value = current_value
			spinbox.step = 0.01
			spinbox.value_changed.connect(_on_property_changed.bind(property_name, value_type))
			editor_control = spinbox
		TYPE_INT:
			if property_name == "weather_override":
				var option_btn := OptionButton.new()
				option_btn.add_item("None", -1)
				option_btn.add_item("Clear", 0)
				option_btn.add_item("Rain", 1)
				option_btn.add_item("Snow", 2)
				option_btn.add_item("Storm", 3)
				option_btn.add_item("Windy", 4)

				# Select current
				for i in range(option_btn.item_count):
					if option_btn.get_item_id(i) == current_value:
						option_btn.selected = i
						break

				option_btn.item_selected.connect(
					func(idx: int) -> void:
						_on_property_changed(option_btn.get_item_id(idx), property_name, value_type)
				)
				editor_control = option_btn
			else:
				var spinbox := SpinBox.new()
				spinbox.value = current_value
				spinbox.step = 1
				spinbox.value_changed.connect(_on_property_changed.bind(property_name, value_type))
				editor_control = spinbox
		TYPE_STRING:
			var line_edit := LineEdit.new()
			line_edit.text = current_value
			line_edit.text_changed.connect(_on_property_changed_string.bind(property_name))
			editor_control = line_edit
		TYPE_VECTOR3:
			var vector_editor := _create_vector3_editor(current_value, property_name)
			editor_control = vector_editor
		TYPE_COLOR:
			var color_picker := ColorPickerButton.new()
			color_picker.color = current_value
			color_picker.color_changed.connect(_on_property_changed_color.bind(property_name))
			editor_control = color_picker
		_:
			var line_edit := LineEdit.new()
			line_edit.text = str(current_value)
			line_edit.text_changed.connect(_on_property_changed_string.bind(property_name))
			editor_control = line_edit

	hbox.add_child(editor_control)
	_parameter_tuner.add_child(hbox)


## Create Vector3 editor
func _create_vector3_editor(value: Vector3, property_name: String) -> Control:
	var container := HBoxContainer.new()

	var x_spinbox := SpinBox.new()
	x_spinbox.value = value.x
	x_spinbox.prefix = "X:"
	x_spinbox.step = 0.01
	x_spinbox.value_changed.connect(_on_vector3_changed.bind(property_name, "x"))
	container.add_child(x_spinbox)

	var y_spinbox := SpinBox.new()
	y_spinbox.value = value.y
	y_spinbox.prefix = "Y:"
	y_spinbox.step = 0.01
	y_spinbox.value_changed.connect(_on_vector3_changed.bind(property_name, "y"))
	container.add_child(y_spinbox)

	var z_spinbox := SpinBox.new()
	z_spinbox.value = value.z
	z_spinbox.prefix = "Z:"
	z_spinbox.step = 0.01
	z_spinbox.value_changed.connect(_on_vector3_changed.bind(property_name, "z"))
	container.add_child(z_spinbox)

	return container


## Handle vector3 property changes
func _on_vector3_changed(value: float, property_name: String, component: String) -> void:
	if not _selected_zone:
		return

	var current_value: Vector3 = _selected_zone[property_name]
	match component:
		"x":
			current_value.x = value
		"y":
			current_value.y = value
		"z":
			current_value.z = value

	_selected_zone[property_name] = current_value
	zone_modified.emit(_selected_zone)


## Handle property changes
func _on_property_changed(value: Variant, property_name: String, _value_type: int) -> void:
	if not _selected_zone:
		return

	_selected_zone[property_name] = value
	zone_modified.emit(_selected_zone)


## Handle string property changes
func _on_property_changed_string(value: String, property_name: String) -> void:
	if not _selected_zone:
		return

	_selected_zone[property_name] = value
	zone_modified.emit(_selected_zone)


## Handle color property changes
func _on_property_changed_color(value: Color, property_name: String) -> void:
	if not _selected_zone:
		return

	_selected_zone[property_name] = value
	zone_modified.emit(_selected_zone)


## Add header to property editor
func _add_header(title: String) -> void:
	var header := Label.new()
	header.text = title
	header.theme_type_variation = "HeaderSmall"
	_parameter_tuner.add_child(header)


## Clear property editor
func _clear_property_editor() -> void:
	if not _parameter_tuner:
		return

	for child in _parameter_tuner.get_children():
		child.queue_free()


## Save current zone settings as a preset
func _save_current_preset() -> void:
	if not _selected_zone:
		push_warning("No zone selected to save as preset")
		return

	var preset_name: String = _selected_zone.name + "_preset"
	_save_preset(preset_name, _selected_zone)


## Save a preset with a specific name
func _save_preset(p_name: String, zone: EnvironmentVolume) -> void:
	var preset_data: Dictionary = {
		"name": p_name,
		"weather_override": zone.weather_override,
		"gravity_multiplier": zone.gravity_multiplier,
		"fog_density_override": zone.fog_density_override,
		"enable_wind_zone": zone.enable_wind_zone,
		"wind_force": zone.wind_force,
		"wind_turbulence": zone.wind_turbulence,
		"wind_radius": zone.wind_radius,
		"wind_attenuation": zone.wind_attenuation,
		"enable_atmospheric_zone": zone.enable_atmospheric_zone,
		"atmospheric_density": zone.atmospheric_density,
		"atmospheric_color": zone.atmospheric_color,
		"light_absorption": zone.light_absorption,
		"light_scattering": zone.light_scattering,
		"air_resistance": zone.air_resistance,
		"friction_multiplier": zone.friction_multiplier,
		"bounce_multiplier": zone.bounce_multiplier
	}

	_presets[p_name] = preset_data

	# Save to file
	var preset_path: String = default_preset_path + p_name + ".tres"
	var resource := Resource.new()
	resource.set_meta("preset_data", preset_data)
	ResourceSaver.save(resource, preset_path)

	_refresh_preset_list()
	preset_saved.emit(p_name)


## Load selected preset
func _load_selected_preset() -> void:
	var selected: TreeItem = _preset_list.get_selected()
	if selected:
		var preset_name: String = selected.get_text(0)
		_load_preset(preset_name)


## Load a preset by name
func _load_preset(preset_name: String) -> void:
	if not _selected_zone:
		push_warning("No zone selected to apply preset to")
		return

	if _presets.has(preset_name):
		var preset_data: Dictionary = _presets[preset_name]
		_apply_preset_to_zone(preset_data, _selected_zone)
		preset_loaded.emit(preset_name)
	else:
		# Try to load from file
		var preset_path: String = default_preset_path + preset_name + ".tres"
		if FileAccess.file_exists(preset_path):
			var resource: Resource = ResourceLoader.load(preset_path)
			if resource and resource.has_meta("preset_data"):
				var loaded_data: Dictionary = resource.get_meta("preset_data")
				_presets[preset_name] = loaded_data
				_apply_preset_to_zone(loaded_data, _selected_zone)
				preset_loaded.emit(preset_name)


## Apply preset data to a zone
func _apply_preset_to_zone(preset_data: Dictionary, zone: EnvironmentVolume) -> void:
	if preset_data.has("weather_override"):
		zone.weather_override = preset_data["weather_override"]
	if preset_data.has("gravity_multiplier"):
		zone.gravity_multiplier = preset_data["gravity_multiplier"]
	if preset_data.has("fog_density_override"):
		zone.fog_density_override = preset_data.fog_density_override
	if preset_data.has("enable_wind_zone"):
		zone.enable_wind_zone = preset_data.enable_wind_zone
	if preset_data.has("wind_force"):
		zone.wind_force = preset_data.wind_force
	if preset_data.has("wind_turbulence"):
		zone.wind_turbulence = preset_data.wind_turbulence
	if preset_data.has("wind_radius"):
		zone.wind_radius = preset_data.wind_radius
	if preset_data.has("wind_attenuation"):
		zone.wind_attenuation = preset_data.wind_attenuation
	if preset_data.has("enable_atmospheric_zone"):
		zone.enable_atmospheric_zone = preset_data.enable_atmospheric_zone
	if preset_data.has("atmospheric_density"):
		zone.atmospheric_density = preset_data.atmospheric_density
	if preset_data.has("atmospheric_color"):
		zone.atmospheric_color = preset_data.atmospheric_color
	if preset_data.has("light_absorption"):
		zone.light_absorption = preset_data.light_absorption
	if preset_data.has("light_scattering"):
		zone.light_scattering = preset_data.light_scattering
	if preset_data.has("air_resistance"):
		zone.air_resistance = preset_data.air_resistance
	if preset_data.has("friction_multiplier"):
		zone.friction_multiplier = preset_data.friction_multiplier
	if preset_data.has("bounce_multiplier"):
		zone.bounce_multiplier = preset_data["bounce_multiplier"]

	zone_modified.emit(zone)
	_update_property_editor()


## Delete selected preset
func _delete_selected_preset() -> void:
	var selected: TreeItem = _preset_list.get_selected()
	if selected:
		var preset_name: String = selected.get_text(0)
		_delete_preset(preset_name)


## Delete a preset by name
func _delete_preset(preset_name: String) -> void:
	if _presets.has(preset_name):
		_presets.erase(preset_name)

		# Delete file if it exists
		var preset_path: String = default_preset_path + preset_name + ".tres"
		if FileAccess.file_exists(preset_path):
			DirAccess.remove_absolute(preset_path)

		_refresh_preset_list()
		preset_deleted.emit(preset_name)


## Refresh preset list display
func _refresh_preset_list() -> void:
	if not _preset_list:
		return

	_preset_list.clear()

	for preset_name: String in _presets.keys():
		var item := _preset_list.create_item()
		item.set_text(0, preset_name)
		item.set_text(1, "Environment")
		item.set_metadata(0, preset_name)


## Handle preset selection
func _on_preset_selected() -> void:
	var selected: TreeItem = _preset_list.get_selected()
	if selected:
		_selected_preset = selected.get_metadata(0) as String


## Load all presets from directory
func _load_presets() -> void:
	_presets.clear()

	var dir: DirAccess = DirAccess.open(default_preset_path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()

		while file_name != "":
			if file_name.ends_with(".tres"):
				var file_path: String = default_preset_path + file_name
				var resource: Resource = ResourceLoader.load(file_path)
				if resource and resource.has_meta("preset_data"):
					var preset_name: String = file_name.replace(".tres", "")
					_presets[preset_name] = resource.get_meta("preset_data")

			file_name = dir.get_next()

	_refresh_preset_list()


## Handle node added to scene (for detecting new environment volumes)
func _on_node_added(node: Node) -> void:
	if node is EnvironmentVolume:
		_zones.append(node)
		refresh_zone_list()


## Update preview based on current settings
func update_preview() -> void:
	# This would update the preview viewport based on current zone settings
	# For example, adjusting fog, lighting, atmospheric effects in the preview
	if _selected_zone and _preview_viewport:
		# Apply visual effects to preview
		# This is a simplified representation
		for entity in _preview_entities:
			# Apply temporary visual changes to represent the environment effects
			if _selected_zone.enable_wind_zone:
				# Visualize wind effect with gentle movement
				entity.rotation.y = sin(Time.get_ticks_msec() / 1000.0) * 0.1
			else:
				entity.rotation.y = 0


## Apply current settings to selected zone
func apply_settings() -> void:
	if _selected_zone:
		zone_modified.emit(_selected_zone)
