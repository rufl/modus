class_name UISystem
extends Node

signal theme_changed
signal hud_settings_changed

const CFG_UI_PATH: String = "res://game/config/gameplay/ui.json5"
const CFG_WEAPON_HUD_PATH: String = "res://game/config/gameplay/hud_weapon_settings.json5"
const JSON5_LOADER_PATH: String = "res://game/core/json5_loader.gd"

var ui_manager: Node
var theme_manager: Node
var focus_manager: Node
var loading_screen: Node
var dev_console: Node
var theme: Dictionary = {
	"primary_color": Color(0.2, 0.6, 1.0),
	"secondary_color": Color(0.15, 0.15, 0.2),
	"accent_color": Color(1.0, 0.8, 0.2),
	"danger_color": Color(1.0, 0.3, 0.3),
	"text_color": Color(0.9, 0.9, 0.9)
}
var hud_settings: Dictionary = {"global_scale": 1.0, "opacity": 1.0, "show_crosshair": true}
var hud_weapon_settings: Dictionary = {}
var _music_notifier_layer: CanvasLayer
var logger: Node


func get_init_priority() -> int:
	return 40  # After CombatService (30)


func initialize() -> void:
	# Initialize logger first using scene tree access
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		logger = gm.get_core_system("logger")

	# 1. Load Configurations
	load_config()
	_load_hud_weapon_settings()

	# 2. Load Subsystems
	ui_manager = _load_and_add("res://shared/ui_core/managers/ui_manager.gd", "UIManager")
	theme_manager = _load_and_add("res://shared/ui_core/managers/theme_manager.gd", "ThemeManager")
	focus_manager = _load_and_add("res://shared/ui_core/managers/focus_manager.gd", "FocusManager")

	# 3. Load Visual Components
	loading_screen = _load_and_add_scene("res://game/ui/loading_screen.tscn", "LoadingScreen")

	# Load console (only in debug builds for security)
	if OS.is_debug_build():
		dev_console = _load_and_add_scene(
			"res://game/ui/console/dropdown_console.tscn", "DevConsole"
		)
		if dev_console:
			dev_console.process_mode = Node.PROCESS_MODE_ALWAYS

	# 4. Global UI
	_setup_global_ui()

	# Safe logging - logger might not be available yet
	if logger and logger.has_method("info"):
		logger.info("[UIService] Initialized.", "Core")
	else:
		print("[UIService] Initialized.")


# --- Configuration Loading ---


func load_config() -> void:
	var config_data: Dictionary = {}

	# Use simple JSON5 loader logic
	var file := FileAccess.open(CFG_UI_PATH, FileAccess.READ)
	if file:
		# Just close file, we load via loader script
		file.close()

		var json5_loader: GDScript = load(JSON5_LOADER_PATH)
		if json5_loader:
			var loaded: Variant = json5_loader.load_file(CFG_UI_PATH)
			if loaded is Dictionary:
				config_data = loaded
		else:
			push_error("[UIService] JSON5Loader not found!")

	if not config_data.is_empty():
		_parse_config(config_data)


func _load_hud_weapon_settings() -> void:
	var json5_loader: GDScript = load(JSON5_LOADER_PATH)
	if json5_loader and json5_loader.file_exists(CFG_WEAPON_HUD_PATH):
		var data: Variant = json5_loader.load_file(CFG_WEAPON_HUD_PATH)
		if data is Dictionary:
			hud_weapon_settings = data

		# Safe logging - use class-level logger
		if logger and logger.has_method("info"):
			logger.info("[UIService] Loaded HUD weapon settings.", "Core")
		else:
			print("[UIService] Loaded HUD weapon settings.")


func _parse_config(data: Dictionary) -> void:
	if "theme" in data:
		var t_data: Dictionary = data.theme
		_update_theme_color("primary_color", t_data)
		_update_theme_color("secondary_color", t_data)
		_update_theme_color("accent_color", t_data)
		_update_theme_color("danger_color", t_data)
		_update_theme_color("text_color", t_data)

		theme_changed.emit()

	if "hud" in data:
		hud_settings = data.hud
		hud_settings_changed.emit()


func _update_theme_color(key: String, data: Dictionary) -> void:
	if key in data:
		theme[key] = Color(data[key])


# --- Public API (General) ---


func get_theme_color(color_name: String, default: Color = Color.WHITE) -> Color:
	return theme.get(color_name, default)


func get_hud_scale() -> float:
	return hud_settings.get("global_scale", 1.0)


func is_hud_element_visible(element_name: String) -> bool:
	if not hud_settings.get("opacity", 1.0) > 0:
		return false

	# Check global toggles
	var global_key: String = "show_" + element_name
	if hud_settings.has(global_key) and not hud_settings[global_key]:
		return false

	# Check specific element override
	var elements: Dictionary = hud_settings.get("elements", {})
	if elements.has(element_name):
		var el_data: Dictionary = elements[element_name]
		if el_data.has("visible") and not el_data.visible:
			return false

	return true


func get_element_config(element_name: String) -> Dictionary:
	var elements: Dictionary = hud_settings.get("elements", {})
	return elements.get(element_name, {})


# --- Public API (Legacy / Weapon Hud Support) ---


func get_hud_element_pos(element_name: String) -> Vector2:
	var defaults: Dictionary = hud_weapon_settings.get("defaults", {}).get("hud", {})
	var pos_array: Array = defaults.get(element_name + "Position", [0.0, 0.0])
	if pos_array.size() >= 2:
		return Vector2(pos_array[0], pos_array[1])
	return Vector2.ZERO


func get_weapon_offset(weapon_id: String, offset_type: String) -> Vector3:
	# Check specific weapon first
	var w_settings: Dictionary = hud_weapon_settings.get("weapons", {}).get(weapon_id, {})
	if w_settings.has(offset_type):
		var arr: Array = w_settings[offset_type]
		if arr.size() >= 3:
			return Vector3(arr[0], arr[1], arr[2])

	# Fallback to default
	var defaults: Dictionary = hud_weapon_settings.get("defaults", {}).get("weapon", {})
	if defaults.has(offset_type):
		var arr: Array = defaults[offset_type]
		if arr.size() >= 3:
			return Vector3(arr[0], arr[1], arr[2])

	return Vector3.ZERO


func get_weapon_config(weapon_id: String, key: String, default: Variant = null) -> Variant:
	# Check specific weapon first
	var w_settings: Dictionary = hud_weapon_settings.get("weapons", {}).get(weapon_id, {})
	if w_settings.has(key):
		return w_settings[key]

	# Fallback to default
	var defaults: Dictionary = hud_weapon_settings.get("defaults", {}).get("weapon", {})
	if defaults.has(key):
		return defaults[key]

	return default


# --- Static Compatibility (Optional) ---
# Allows UISvc.get_service() to work if we update usage to UIService.get_service()


static func get_service() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("GameManager"):
		var manager: Node = tree.root.get_node("GameManager")
		if manager.has_method("get_core_system"):
			return manager.get_core_system("ui")
	return null


# --- Screen Management API ---


func open_screen(screen_path: String, params: Dictionary = {}) -> void:
	if ui_manager and ui_manager.has_method("open_screen"):
		ui_manager.open_screen(screen_path, params)
	else:
		push_warning("[UIService] ui_manager.open_screen not available")


func close_screen() -> void:
	if ui_manager and ui_manager.has_method("close_screen"):
		ui_manager.close_screen()
	elif ui_manager and ui_manager.has_method("back"):
		ui_manager.back()
	else:
		push_warning("[UIService] ui_manager.close_screen not available")


func get_current_screen() -> Node:
	if ui_manager and ui_manager.has_method("get_current_screen"):
		return ui_manager.get_current_screen()
	if ui_manager and ui_manager.has_method("get_active_screen"):
		return ui_manager.get_active_screen()
	return null


# --- Internal Helpers ---


func _load_and_add(path: String, node_name: String) -> Node:
	if not ResourceLoader.exists(path):
		push_error("UIService: Script not found: %s" % path)
		return null

	var script: GDScript = load(path)
	if not script:
		push_error("UIService: Failed to load script: %s" % path)
		return null

	var node: Node = Node.new()
	node.name = node_name
	node.set_script(script)
	add_child(node)
	return node


func _load_and_add_scene(path: String, node_name: String) -> Node:
	# Safe logging - use class-level logger
	if logger and logger.has_method("info"):
		logger.info("[UIService] Attempting to load scene: %s" % path, "Core")
	else:
		print("[UIService] Attempting to load scene: %s" % path)

	if not ResourceLoader.exists(path):
		push_error("UIService: Scene not found: %s" % path)
		return null

	var scene: PackedScene = load(path)
	if not scene:
		push_error("UIService: Failed to load scene: %s" % path)
		return null

	if logger and logger.has_method("info"):
		logger.info("[UIService] Scene loaded successfully, attempting to instantiate...", "Core")
	else:
		print("[UIService] Scene loaded successfully, attempting to instantiate...")

	var node: Node = scene.instantiate()

	if logger and logger.has_method("info"):
		logger.info("[UIService] Scene instantiated successfully: %s" % node.get_class(), "Core")
	else:
		print("[UIService] Scene instantiated successfully: %s" % node.get_class())

	node.name = node_name
	add_child(node)
	return node


func _setup_global_ui() -> void:
	var script: GDScript = load("res://game/ui/hud/music_notifier.gd")
	if script:
		_music_notifier_layer = CanvasLayer.new()
		_music_notifier_layer.name = "MusicNotifierLayer"
		_music_notifier_layer.layer = 35
		add_child(_music_notifier_layer)

		var notifier: PanelContainer = PanelContainer.new()
		notifier.set_script(script)
		# Ensure it spans the screen so anchors work
		notifier.set_anchors_preset(Control.PRESET_FULL_RECT)
		notifier.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_music_notifier_layer.add_child(notifier)
