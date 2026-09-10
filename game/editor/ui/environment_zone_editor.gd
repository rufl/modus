@tool
class_name EnvironmentZoneEditor
extends Control

## Environmental Effect Configuration Interface
## Zone Editor with Parameter Tuning, Preview System and Save/Load Presets

# Signals
signal zone_created(zone: EnvironmentVolume)
signal zone_modified(zone: EnvironmentVolume)
signal zone_deleted(zone_id: String)
signal preset_saved(preset_name: String)
signal preset_loaded(preset_name: String)

# Exported properties
@export_group("UI Settings")
@export var show_zone_editor: bool = true
@export var show_parameter_tuning: bool = true
@export var show_preview_system: bool = true
@export var show_preset_manager: bool = true

@export_group("Zone Defaults")
@export var default_zone_size: Vector3 = Vector3(10, 5, 10)
@export var default_zone_color: Color = Color(0, 0.5, 1, 0.3)
@export var default_zone_shape: int = 0  # 0=Box, 1=Sphere, 2=Capsule

# UI Elements
var _main_container: VBoxContainer = null
var _zone_toolbar: HBoxContainer = null
var _parameter_panel: PanelContainer = null
var _preview_viewport: SubViewport = null
var _preset_manager: PanelContainer = null
var _zone_list: Tree = null
var _zones: Dictionary = {}
var _presets: Dictionary = {}
var _selected_zone: EnvironmentVolume = null
const JSONHelperClass = preload("res://game/core/json_helper.gd")


func _ready() -> void:
	# Create the UI elements
	_create_ui()

	# Load existing presets
	_load_presets()

	# Connect signals
	_connect_signals()


func _create_ui() -> void:
	# Main container
	_main_container = VBoxContainer.new()
	_main_container.name = "EnvironmentZoneEditor"
	add_child(_main_container)

	# Toolbar for zone operations
	_zone_toolbar = HBoxContainer.new()
	_zone_toolbar.name = "ZoneToolbar"
	_main_container.add_child(_zone_toolbar)

	# Create zone button
	var create_btn := Button.new()
	create_btn.text = "Create Zone"
	create_btn.pressed.connect(_on_create_zone_pressed)
	_zone_toolbar.add_child(create_btn)

	# Delete zone button
	var delete_btn := Button.new()
	delete_btn.text = "Delete Zone"
	delete_btn.pressed.connect(_on_delete_zone_pressed)
	_zone_toolbar.add_child(delete_btn)

	# Apply preset button
	var apply_preset_btn := Button.new()
	apply_preset_btn.text = "Apply Preset"
	apply_preset_btn.pressed.connect(_on_apply_preset_pressed)
	_zone_toolbar.add_child(apply_preset_btn)

	# Zone list/tree view
	_zone_list = Tree.new()
	_zone_list.name = "ZoneList"
	_zone_list.hide_root = true
	_main_container.add_child(_zone_list)
	_zone_list.item_selected.connect(_on_zone_selected)

	# Parameter tuning panel
	_parameter_panel = PanelContainer.new()
	_parameter_panel.name = "ParameterPanel"
	var param_label := Label.new()
	param_label.text = "Zone Parameters"
	_parameter_panel.add_child(param_label)

	var param_container := VBoxContainer.new()
	_parameter_panel.add_child(param_container)

	# Weather override selector
	var weather_label := Label.new()
	weather_label.text = "Weather Override:"
	param_container.add_child(weather_label)

	var weather_select := OptionButton.new()
	weather_select.name = "WeatherSelect"
	weather_select.add_item("None", -1)
	weather_select.add_item("Clear", 0)
	weather_select.add_item("Rain", 1)
	weather_select.add_item("Snow", 2)
	weather_select.add_item("Storm", 3)
	weather_select.add_item("Windy", 4)
	weather_select.item_selected.connect(_on_weather_override_changed)
	param_container.add_child(weather_select)

	# Gravity multiplier
	var gravity_label := Label.new()
	gravity_label.text = "Gravity Multiplier:"
	param_container.add_child(gravity_label)

	var gravity_slider := HSlider.new()
	gravity_slider.name = "GravitySlider"
	gravity_slider.min_value = 0.0
	gravity_slider.max_value = 3.0
	gravity_slider.value = 1.0
	gravity_slider.value_changed.connect(_on_gravity_multiplier_changed)
	param_container.add_child(gravity_slider)

	# Fog density
	var fog_label := Label.new()
	fog_label.text = "Fog Density Override:"
	param_container.add_child(fog_label)

	var fog_slider := HSlider.new()
	fog_slider.name = "FogSlider"
	fog_slider.min_value = -1.0  # -1 means no override
	fog_slider.max_value = 1.0
	fog_slider.value = -1.0
	fog_slider.value_changed.connect(_on_fog_density_changed)
	param_container.add_child(fog_slider)

	_main_container.add_child(_parameter_panel)

	# Preview viewport
	if show_preview_system:
		_preview_viewport = SubViewport.new()
		_preview_viewport.name = "PreviewViewport"
		_preview_viewport.size = Vector2(300, 200)
		_main_container.add_child(_preview_viewport)

	# Preset manager
	if show_preset_manager:
		_preset_manager = PanelContainer.new()
		_preset_manager.name = "PresetManager"
		var preset_label := Label.new()
		preset_label.text = "Environment Presets"
		_preset_manager.add_child(preset_label)

		var preset_container := VBoxContainer.new()
		_preset_manager.add_child(preset_container)

		# Preset list
		var preset_list := ItemList.new()
		preset_list.name = "PresetList"
		preset_container.add_child(preset_list)

		# Preset buttons
		var preset_buttons := HBoxContainer.new()
		preset_container.add_child(preset_buttons)

		var save_preset_btn := Button.new()
		save_preset_btn.text = "Save Preset"
		save_preset_btn.pressed.connect(_on_save_preset_pressed)
		preset_buttons.add_child(save_preset_btn)

		var load_preset_btn := Button.new()
		load_preset_btn.text = "Load Preset"
		load_preset_btn.pressed.connect(_on_load_preset_pressed)
		preset_buttons.add_child(load_preset_btn)

		var delete_preset_btn := Button.new()
		delete_preset_btn.text = "Delete Preset"
		delete_preset_btn.pressed.connect(_on_delete_preset_pressed)
		preset_buttons.add_child(delete_preset_btn)

		_main_container.add_child(_preset_manager)


func _connect_signals() -> void:
	# Connect UI element signals
	pass


## Create a new environment zone
func create_zone(pos: Vector3 = Vector3.ZERO, sz: Vector3 = Vector3.ZERO) -> EnvironmentVolume:
	if sz == Vector3.ZERO:
		sz = default_zone_size

	# Create environment volume
	var zone_scene: PackedScene = preload("res://game/world/actors/volumes/environment_volume.tscn")
	var zone: EnvironmentVolume = (
		zone_scene.instantiate() if zone_scene else EnvironmentVolume.new()
	)

	# Set properties
	zone.name = "EnvironmentZone_%d" % _zones.size()
	zone.position = pos
	zone.scale = sz

	# Apply default visual properties if it's a mesh instance
	if zone is Node3D:
		# Add visual indicator for the zone
		var visual_indicator := MeshInstance3D.new()
		visual_indicator.name = "ZoneVisual"

		# Create wireframe or translucent box to indicate zone boundaries
		var box_mesh := BoxMesh.new()
		box_mesh.size = sz
		visual_indicator.mesh = box_mesh

		var zone_material := StandardMaterial3D.new()
		zone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		zone_material.albedo_color = default_zone_color
		zone_material.render_priority = 20  # Render on top
		visual_indicator.material_override = zone_material
		zone.add_child(visual_indicator)

	# Add to current scene
	var parent_scene: Node = get_tree().current_scene
	if parent_scene:
		parent_scene.add_child(zone)

	# Track the zone
	_zones[zone.name] = zone

	# Add to UI list
	var item: TreeItem = _zone_list.create_item()
	item.set_text(0, zone.name)
	item.set_metadata(0, zone)

	# Emit signal
	zone_created.emit(zone)

	return zone


## Delete selected zone
func delete_zone(zone: EnvironmentVolume) -> bool:
	if not zone or not is_instance_valid(zone):
		return false

	# Remove from tracking
	_zones.erase(zone.name)

	# Remove from UI
	var items: Array[TreeItem] = _zone_list.get_root().get_children()
	for item: TreeItem in items:
		if item.get_metadata(0) == zone:
			item.free()
			break

	# Remove from scene
	zone.queue_free()

	# Emit signal
	zone_deleted.emit(zone.name)
	return true


## Update zone parameters
func update_zone_parameters(zone: EnvironmentVolume, params: Dictionary) -> void:
	if not zone:
		return

	# Update weather override
	if params.has("weather_override"):
		if "weather_override" in zone:
			zone.weather_override = params.weather_override

	# Update gravity multiplier
	if params.has("gravity_multiplier"):
		if "gravity_multiplier" in zone:
			zone.gravity_multiplier = params.gravity_multiplier

	# Update fog density
	if params.has("fog_density_override"):
		if "fog_density_override" in zone:
			zone.fog_density_override = params.fog_density_override

	# Update other parameters as needed
	if params.has("color"):
		_update_zone_visual(zone, params.color)

	# Emit signal
	zone_modified.emit(zone)


## Update zone visual representation
func _update_zone_visual(zone: EnvironmentVolume, color: Color) -> void:
	# Find the visual indicator child and update its color
	for child in zone.get_children():
		if child.name == "ZoneVisual" and child is MeshInstance3D:
			var mat: StandardMaterial3D = child.material_override
			if mat:
				mat.albedo_color = color


## Save preset to file
func save_preset(preset_name: String, zone_params: Dictionary) -> Error:
	if preset_name.is_empty():
		return ERR_INVALID_PARAMETER

	var preset_data: Dictionary = {
		"name": preset_name,
		"parameters": zone_params,
		"timestamp": Time.get_datetime_string_from_system(),
		"version": "1.0"
	}

	# Save to user directory
	var file_path: String = "user://environment_presets/" + preset_name + ".json5"

	# Ensure directory exists
	var dir := DirAccess.open("user://environment_presets/")
	if not dir:
		DirAccess.make_dir_recursive_absolute("user://environment_presets/")

	# Write file
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return ERR_FILE_CANT_WRITE

	file.store_string(JSONHelperClass.safe_stringify(preset_data))
	file.close()

	# Track preset
	_presets[preset_name] = preset_data
	preset_saved.emit(preset_name)

	return OK


## Load preset from file
func load_preset(preset_name: String) -> Error:
	var file_path: String = "user://environment_presets/" + preset_name + ".json5"
	if not FileAccess.file_exists(file_path):
		return ERR_FILE_NOT_FOUND

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return ERR_FILE_CANT_READ

	var content := file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(content)
	if err != OK:
		return ERR_PARSE_ERROR

	var preset_data: Variant = json.data
	if preset_data is Dictionary:
		_presets[preset_name] = preset_data
		if _selected_zone:
			update_zone_parameters(_selected_zone, preset_data.get("parameters", {}))
		preset_loaded.emit(preset_name)
		return OK

	return ERR_INVALID_DATA


func _load_presets() -> void:
	var path := "user://environment_presets/"
	if not DirAccess.dir_exists_absolute(path):
		return

	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json5"):
				var preset_name: String = file_name.get_basename()
				load_preset(preset_name)
			file_name = dir.get_next()

	_update_preset_list()


func _update_preset_list() -> void:
	if not _preset_manager:
		return

	var list: ItemList = _preset_manager.get_node("VBoxContainer/PresetList")
	if list:
		list.clear()
		for preset_name: String in _presets.keys():
			list.add_item(preset_name)


# UI Handlers
func _on_create_zone_pressed() -> void:
	create_zone(Vector3.ZERO, default_zone_size)


func _on_delete_zone_pressed() -> void:
	if _selected_zone:
		delete_zone(_selected_zone)
		_selected_zone = null


func _on_apply_preset_pressed() -> void:
	if not _selected_zone:
		return

	if not _preset_manager:
		return
	var list := _preset_manager.get_node_or_null("VBoxContainer/PresetList") as ItemList
	if list and list.is_anything_selected():
		var idx: int = list.get_selected_items()[0]
		var preset_name: String = list.get_item_text(idx)
		load_preset(preset_name)


func _on_zone_selected() -> void:
	var item: TreeItem = _zone_list.get_selected()
	if item:
		_selected_zone = item.get_metadata(0)
		_update_parameter_ui()


func _update_parameter_ui() -> void:
	if not _selected_zone or not _parameter_panel:
		return

	var container: VBoxContainer = _parameter_panel.get_node("VBoxContainer")
	var weather_select: OptionButton = container.get_node("WeatherSelect")
	var gravity_slider: HSlider = container.get_node("GravitySlider")
	var fog_slider: HSlider = container.get_node("FogSlider")

	if "weather_override" in _selected_zone:
		weather_select.selected = int(_selected_zone.weather_override) + 1
	if "gravity_multiplier" in _selected_zone:
		gravity_slider.value = _selected_zone.gravity_multiplier
	if "fog_density_override" in _selected_zone:
		fog_slider.value = _selected_zone.fog_density_override


func _on_weather_override_changed(index: int) -> void:
	if _selected_zone:
		update_zone_parameters(_selected_zone, {"weather_override": index - 1})


func _on_gravity_multiplier_changed(value: float) -> void:
	if _selected_zone:
		# Safety check for NaN
		if not is_nan(value):
			update_zone_parameters(_selected_zone, {"gravity_multiplier": value})


func _on_fog_density_changed(value: float) -> void:
	if _selected_zone:
		if not is_nan(value):
			update_zone_parameters(_selected_zone, {"fog_density_override": value})


func _on_save_preset_pressed() -> void:
	if not _selected_zone:
		return

	# Show a simple dialog or just use a default name for now
	var preset_name: String = "Preset_%d" % _presets.size()
	var params: Dictionary = {
		"weather_override":
		_selected_zone.weather_override if "weather_override" in _selected_zone else -1,
		"gravity_multiplier":
		_selected_zone.gravity_multiplier if "gravity_multiplier" in _selected_zone else 1.0,
		"fog_density_override":
		_selected_zone.fog_density_override if "fog_density_override" in _selected_zone else -1.0
	}
	save_preset(preset_name, params)
	_update_preset_list()


func _on_load_preset_pressed() -> void:
	_on_apply_preset_pressed()


func _on_delete_preset_pressed() -> void:
	if not _preset_manager:
		return
	var list := _preset_manager.get_node_or_null("VBoxContainer/PresetList") as ItemList
	if list and list.is_anything_selected():
		var idx: int = list.get_selected_items()[0]
		var preset_name: String = list.get_item_text(idx)
		var path: String = "user://environment_presets/" + preset_name + ".json5"
		DirAccess.remove_absolute(path)
		_presets.erase(preset_name)
		_update_preset_list()
