## UIFeature - Feature module for UI system
##
## Manages UI components including theme, focus, loading screens, and HUD.
## Provides API for screen management and UI configuration.
##
## Requirements: 2.3
class_name UIFeature
extends FeatureModule

signal theme_changed
signal hud_settings_changed

## UI subsystems
var ui_manager: Node
var theme_manager: Node
var focus_manager: Node
var loading_screen: Node
var dev_console: Node

## MapTheme configuration
var theme: Dictionary = {
	"primary_color": Color(0.2, 0.6, 1.0),
	"secondary_color": Color(0.15, 0.15, 0.2),
	"accent_color": Color(1.0, 0.8, 0.2),
	"danger_color": Color(1.0, 0.3, 0.3),
	"text_color": Color(0.9, 0.9, 0.9)
}

## HUD settings
var hud_settings: Dictionary = {"global_scale": 1.0, "opacity": 1.0, "show_crosshair": true}

## HUD weapon settings
var hud_weapon_settings: Dictionary = {}

var _music_notifier_layer: CanvasLayer


## Constructor
func _init() -> void:
	super._init("ui")
	feature_name = "UI System"


## Initialize the UI feature
func initialize() -> void:
	super.initialize()

	# Load configurations
	_load_theme_config()
	_load_hud_config()
	_load_hud_weapon_settings()

	# Load subsystems
	ui_manager = _load_and_add("res://shared/ui_core/managers/ui_manager.gd", "UIManager")
	theme_manager = _load_and_add("res://shared/ui_core/managers/theme_manager.gd", "ThemeManager")
	focus_manager = _load_and_add("res://shared/ui_core/managers/focus_manager.gd", "FocusManager")

	# Load visual components
	loading_screen = _load_and_add_scene("res://game/ui/loading_screen.tscn", "LoadingScreen")

	# Setup global UI
	_setup_global_ui()


## Shutdown the UI feature
func shutdown() -> void:
	# Clean up subsystems
	if ui_manager and is_instance_valid(ui_manager):
		ui_manager.queue_free()
	if theme_manager and is_instance_valid(theme_manager):
		theme_manager.queue_free()
	if focus_manager and is_instance_valid(focus_manager):
		focus_manager.queue_free()
	if loading_screen and is_instance_valid(loading_screen):
		loading_screen.queue_free()
	if dev_console and is_instance_valid(dev_console):
		dev_console.queue_free()
	if _music_notifier_layer and is_instance_valid(_music_notifier_layer):
		_music_notifier_layer.queue_free()

	super.shutdown()


## Get theme color
func get_theme_color(color_name: String, default: Color = Color.WHITE) -> Color:
	return theme.get(color_name, default)


## Get HUD scale
func get_hud_scale() -> float:
	return hud_settings.get("global_scale", 1.0)


## Check if HUD element is visible
func is_hud_element_visible(element_name: String) -> bool:
	if not hud_settings.get("opacity", 1.0) > 0:
		return false

	var global_key: String = "show_" + element_name
	if hud_settings.has(global_key) and not hud_settings[global_key]:
		return false

	var elements: Dictionary = hud_settings.get("elements", {})
	if elements.has(element_name):
		var el_data: Dictionary = elements[element_name]
		if el_data.has("visible") and not el_data.visible:
			return false

	return true


## Get element configuration
func get_element_config(element_name: String) -> Dictionary:
	var elements: Dictionary = hud_settings.get("elements", {})
	return elements.get(element_name, {})


## Get HUD element position
func get_hud_element_pos(element_name: String) -> Vector2:
	var defaults: Dictionary = hud_weapon_settings.get("defaults", {}).get("hud", {})
	var pos_array: Array = defaults.get(element_name + "Position", [0.0, 0.0])
	if pos_array.size() >= 2:
		return Vector2(pos_array[0], pos_array[1])
	return Vector2.ZERO


## Get weapon offset
func get_weapon_offset(weapon_id: String, offset_type: String) -> Vector3:
	var w_settings: Dictionary = hud_weapon_settings.get("weapons", {}).get(weapon_id, {})
	if w_settings.has(offset_type):
		var arr: Array = w_settings[offset_type]
		if arr.size() >= 3:
			return Vector3(arr[0], arr[1], arr[2])

	var defaults: Dictionary = hud_weapon_settings.get("defaults", {}).get("weapon", {})
	if defaults.has(offset_type):
		var arr: Array = defaults[offset_type]
		if arr.size() >= 3:
			return Vector3(arr[0], arr[1], arr[2])

	return Vector3.ZERO


## Get weapon configuration
func get_weapon_config(weapon_id: String, key: String, default: Variant = null) -> Variant:
	var w_settings: Dictionary = hud_weapon_settings.get("weapons", {}).get(weapon_id, {})
	if w_settings.has(key):
		return w_settings[key]

	var defaults: Dictionary = hud_weapon_settings.get("defaults", {}).get("weapon", {})
	if defaults.has(key):
		return defaults[key]

	return default


## Open screen
func open_screen(screen_path: String, params: Dictionary = {}) -> void:
	if ui_manager and ui_manager.has_method("open_screen"):
		ui_manager.open_screen(screen_path, params)
	else:
		push_warning("[UIFeature] ui_manager.open_screen not available")


## Close screen
func close_screen() -> void:
	if ui_manager and ui_manager.has_method("close_screen"):
		ui_manager.close_screen()
	elif ui_manager and ui_manager.has_method("back"):
		ui_manager.back()
	else:
		push_warning("[UIFeature] ui_manager.close_screen not available")


## Get current screen
func get_current_screen() -> Node:
	if ui_manager and ui_manager.has_method("get_current_screen"):
		return ui_manager.get_current_screen()
	if ui_manager and ui_manager.has_method("get_active_screen"):
		return ui_manager.get_active_screen()
	return null


## Load theme configuration
func _load_theme_config() -> void:
	var theme_config: Dictionary = config.get("theme", {})
	if not theme_config.is_empty():
		_update_theme_color("primary_color", theme_config)
		_update_theme_color("secondary_color", theme_config)
		_update_theme_color("accent_color", theme_config)
		_update_theme_color("danger_color", theme_config)
		_update_theme_color("text_color", theme_config)
		theme_changed.emit()


## Load HUD configuration
func _load_hud_config() -> void:
	var hud_config: Dictionary = config.get("hud", {})
	if not hud_config.is_empty():
		hud_settings = hud_config
		hud_settings_changed.emit()


## Load HUD weapon settings
func _load_hud_weapon_settings() -> void:
	hud_weapon_settings = config.get("hud_weapon_settings", {})


## Update theme color
func _update_theme_color(key: String, data: Dictionary) -> void:
	if key in data:
		theme[key] = Color(data[key])


## Load and add a script as a child node
func _load_and_add(path: String, node_name: String) -> Node:
	if not FileAccess.file_exists(path):
		push_error("[UIFeature] Script not found: %s" % path)
		return null

	var script: GDScript = load(path)
	if not script:
		push_error("[UIFeature] Failed to load script: %s" % path)
		return null

	var node: Node = Node.new()
	node.name = node_name
	node.set_script(script)
	add_child(node)
	return node


## Load and add a scene as a child node
func _load_and_add_scene(path: String, node_name: String) -> Node:
	if not FileAccess.file_exists(path):
		push_error("[UIFeature] Scene not found: %s" % path)
		return null

	var scene: PackedScene = load(path)
	if not scene:
		push_error("[UIFeature] Failed to load scene: %s" % path)
		return null

	var node: Node = scene.instantiate()
	node.name = node_name
	add_child(node)
	return node


## Setup global UI components
func _setup_global_ui() -> void:
	var script_path: String = "res://game/ui/hud/music_notifier.gd"
	if not FileAccess.file_exists(script_path):
		return

	var script: GDScript = load(script_path)
	if script:
		_music_notifier_layer = CanvasLayer.new()
		_music_notifier_layer.name = "MusicNotifierLayer"
		_music_notifier_layer.layer = 35
		add_child(_music_notifier_layer)

		var notifier: PanelContainer = PanelContainer.new()
		notifier.set_script(script)
		notifier.set_anchors_preset(Control.PRESET_FULL_RECT)
		notifier.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_music_notifier_layer.add_child(notifier)
