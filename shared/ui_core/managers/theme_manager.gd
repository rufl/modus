extends Node


# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])


signal theme_changed(theme_id: String)
signal preset_loaded(preset_id: String)
signal accessibility_changed(setting: String, value: bool)

const PRESET_DEFAULT: String = "default"
const PRESET_DARK: String = "dark"
const PRESET_PIXEL: String = "pixel"
const PRESET_HIGH_CONTRAST: String = "high_contrast"
const THEME_PATH: String = "res://shared/ui_core/themes/"

var _current_theme: Theme = null
var _current_theme_id: String = PRESET_DEFAULT
var _theme_cache: Dictionary = {}
var _themeable_controls: Array[WeakRef] = []
var _runtime_overrides: Dictionary = {}
var _accessibility: Dictionary = {
	"reduced_motion": false,
	"high_contrast": false,
	"large_text": false,
	"screen_reader": false,
}
var _follow_system: bool = false


func _ready() -> void:
	name = "ThemeManager"
	_load_config()
	_load_initial_theme()

	_log("[ThemeManager] Initialized with theme: %s" % _current_theme_id, "ThemeManager")


func _load_config() -> void:
	var cm: Node = GameManager.get_core_system("config")
	if not cm:
		return

	_current_theme_id = cm.get_value("ui.theme.current", PRESET_DEFAULT)
	_follow_system = cm.get_value("ui.theme.follow_system", false)

	# Load accessibility settings
	_accessibility.reduced_motion = cm.get_value("ui.accessibility.reduced_motion", false)
	_accessibility.high_contrast = cm.get_value("ui.accessibility.high_contrast", false)
	_accessibility.large_text = cm.get_value("ui.accessibility.large_text", false)
	_accessibility.screen_reader = cm.get_value("ui.accessibility.screen_reader", false)


func _load_initial_theme() -> void:
	# Handle high contrast override
	if _accessibility.high_contrast:
		_current_theme_id = PRESET_HIGH_CONTRAST

	# Handle system theme following
	if _follow_system:
		_current_theme_id = _detect_system_theme()

	# Load the theme
	_current_theme = _load_theme_preset(_current_theme_id)
	if not _current_theme:
		push_warning("[ThemeManager] Failed to load theme '%s', using fallback" % _current_theme_id)
		_current_theme = _create_fallback_theme()


# ============================================================================
# THEME SWITCHING
# ============================================================================

## Set the active theme by preset ID


func set_theme(theme_id: String) -> bool:
	if theme_id == _current_theme_id:
		return true

	var theme: Theme = _load_theme_preset(theme_id)
	if not theme:
		push_error("[ThemeManager] Theme not found: %s" % theme_id)
		return false

	_current_theme = theme
	_current_theme_id = theme_id

	# Apply runtime overrides
	_apply_runtime_overrides()

	# Update all registered controls
	_update_all_themeables()

	# Save preference
	_save_config()

	theme_changed.emit(theme_id)

	if GameManager:
		if GameManager.has_method("emit_event"):
			GameManager.emit_event("theme_changed", {"theme_id": theme_id})
		var logger: Node = GameManager.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[ThemeManager] MapTheme changed to: %s" % theme_id, "ThemeManager")

	return true


## Get the current theme


func get_current_theme() -> Theme:
	return _current_theme


## Get the current theme ID


func get_current_theme_id() -> String:
	return _current_theme_id


## Get list of available theme presets


func get_available_presets() -> Array[String]:
	return [PRESET_DEFAULT, PRESET_DARK, PRESET_PIXEL, PRESET_HIGH_CONTRAST]


## Check if a theme exists


func has_theme(theme_id: String) -> bool:
	var path: String = THEME_PATH + theme_id + ".tres"
	return ResourceLoader.exists(path)


# ============================================================================
# THEMEABLE REGISTRATION
# ============================================================================

## Register a control to receive theme updates


func register_themeable(control: Control) -> void:
	# Check if already registered
	for ref: WeakRef in _themeable_controls:
		if ref.get_ref() == control:
			return

	_themeable_controls.append(weakref(control))

	# Apply current theme immediately
	var ui_theme: Theme = _current_theme
	control.theme = ui_theme


## Unregister a control from theme updates


func unregister_themeable(control: Control) -> void:
	for i: int in range(_themeable_controls.size() - 1, -1, -1):
		var ref: WeakRef = _themeable_controls[i]
		if ref.get_ref() == control or ref.get_ref() == null:
			_themeable_controls.remove_at(i)


func _update_all_themeables() -> void:
	# Clean up dead refs and update valid ones
	var valid_refs: Array[WeakRef] = []

	for ref: WeakRef in _themeable_controls:
		var control: Control = ref.get_ref()
		if control:
			var ui_theme: Theme = _current_theme
			control.theme = ui_theme
			valid_refs.append(ref)

	_themeable_controls = valid_refs


# ============================================================================
# RUNTIME OVERRIDES
# ============================================================================

## Set a runtime override for a theme property


func set_override(type: String, control_name: String, property: String, value: Variant) -> void:
	var key: String = "%s/%s/%s" % [type, control_name, property]
	_runtime_overrides[key] = value

	# Apply to current theme
	_apply_single_override(type, control_name, property, value)


## Remove a runtime override


func remove_override(type: String, control_name: String, property: String) -> void:
	var key: String = "%s/%s/%s" % [type, control_name, property]
	_runtime_overrides.erase(key)

	# Reload theme to reset
	_current_theme = _load_theme_preset(_current_theme_id)
	_apply_runtime_overrides()
	_update_all_themeables()


## Clear all runtime overrides


func clear_overrides() -> void:
	_runtime_overrides.clear()
	_current_theme = _load_theme_preset(_current_theme_id)
	_update_all_themeables()


func _apply_runtime_overrides() -> void:
	for key: String in _runtime_overrides.keys():
		var parts: PackedStringArray = key.split("/")
		if parts.size() == 3:
			_apply_single_override(parts[0], parts[1], parts[2], _runtime_overrides[key])


func _apply_single_override(
	type: String, control_name: String, property: String, value: Variant
) -> void:
	if not _current_theme:
		return

	match type:
		"color":
			if value is Color:
				_current_theme.set_color(property, control_name, value)
		"constant":
			if value is int:
				_current_theme.set_constant(property, control_name, value)
		"font_size":
			if value is int:
				_current_theme.set_font_size(property, control_name, value)


# ============================================================================
# ACCESSIBILITY
# ============================================================================

## Set an accessibility setting


func set_accessibility(setting: String, enabled: bool) -> void:
	if not _accessibility.has(setting):
		push_warning("[ThemeManager] Unknown accessibility setting: %s" % setting)
		return

	_accessibility[setting] = enabled

	# Handle special cases
	match setting:
		"high_contrast":
			if enabled:
				set_theme(PRESET_HIGH_CONTRAST)
				var cfg: Node = GameManager.get_core_system("config")
				var next_theme: String = PRESET_DEFAULT
				if cfg:
					next_theme = cfg.get_value("ui.theme.current", PRESET_DEFAULT)
				set_theme(next_theme)

		"large_text":
			_apply_large_text(enabled)

	# Save setting
	var cfg_save: Node = GameManager.get_core_system("config")
	if cfg_save:
		cfg_save.set_value("ui.accessibility." + setting, enabled, true)

	accessibility_changed.emit(setting, enabled)


## Get an accessibility setting


func get_accessibility(setting: String) -> bool:
	return _accessibility.get(setting, false)


## Check if reduced motion is enabled


func is_reduced_motion() -> bool:
	return _accessibility.reduced_motion


func _apply_large_text(enabled: bool) -> void:
	if not _current_theme:
		return

	var scale_factor: float = 1.4 if enabled else 1.0
	var base_sizes: Dictionary = {"font_size": 14, "title_font_size": 24, "bold_font_size": 14}

	for size_name: String in base_sizes:
		var new_size: int = int(base_sizes[size_name] * scale_factor)
		# Apply to common control types
		for control_type: String in ["Button", "Label", "LineEdit", "RichTextLabel"]:
			if _current_theme.has_font_size(size_name, control_type):
				_current_theme.set_font_size(size_name, control_type, new_size)

	_update_all_themeables()


# ============================================================================
# THEME LOADING
# ============================================================================


func _load_theme_preset(theme_id: String) -> Theme:
	# Check cache
	if _theme_cache.has(theme_id):
		# Return a duplicate to allow per-instance modifications
		return _theme_cache[theme_id].duplicate()

	# Try to load from file
	var path: String = THEME_PATH + theme_id + ".tres"
	if ResourceLoader.exists(path):
		var loaded_theme: Theme = load(path)
		if loaded_theme:
			_theme_cache[theme_id] = loaded_theme
			preset_loaded.emit(theme_id)
			return loaded_theme.duplicate()

	# Create built-in presets if file doesn't exist
	var builtin_theme: Theme = _create_builtin_preset(theme_id)
	if builtin_theme:
		_theme_cache[theme_id] = builtin_theme
		preset_loaded.emit(theme_id)
		return builtin_theme.duplicate()

	push_error("[ThemeManager] Failed to create theme preset: %s" % theme_id)
	return null  # Theme creation failed


## Create a built-in theme preset
## Returns Theme if preset exists, null if unknown preset ID
func _create_builtin_preset(theme_id: String) -> Theme:
	match theme_id:
		PRESET_DEFAULT:
			return _create_default_theme()
		PRESET_DARK:
			return _create_dark_theme()
		PRESET_PIXEL:
			return _create_pixel_theme()
		PRESET_HIGH_CONTRAST:
			return _create_high_contrast_theme()

	push_warning("[ThemeManager] Unknown theme preset: %s" % theme_id)
	return null  # Unknown preset


func _create_fallback_theme() -> Theme:
	return _create_default_theme()


func _create_default_theme() -> Theme:
	var theme: Theme = Theme.new()

	# Base colors
	var bg_color: Color = Color(0.15, 0.15, 0.17, 1.0)
	var fg_color: Color = Color(0.9, 0.9, 0.92, 1.0)
	var accent_color: Color = Color(0.3, 0.5, 0.8, 1.0)
	var hover_color: Color = Color(0.25, 0.25, 0.28, 1.0)
	var pressed_color: Color = Color(0.2, 0.4, 0.7, 1.0)

	# Button
	var button_normal: StyleBoxFlat = StyleBoxFlat.new()
	button_normal.bg_color = bg_color
	button_normal.border_width_bottom = 2
	button_normal.border_width_left = 2
	button_normal.border_width_right = 2
	button_normal.border_width_top = 2
	button_normal.border_color = accent_color
	button_normal.corner_radius_top_left = 4
	button_normal.corner_radius_top_right = 4
	button_normal.corner_radius_bottom_left = 4
	button_normal.corner_radius_bottom_right = 4
	button_normal.content_margin_left = 16
	button_normal.content_margin_right = 16
	button_normal.content_margin_top = 8
	button_normal.content_margin_bottom = 8

	var button_hover: StyleBoxFlat = button_normal.duplicate()
	button_hover.bg_color = hover_color

	var button_pressed: StyleBoxFlat = button_normal.duplicate()
	button_pressed.bg_color = pressed_color

	var button_focus: StyleBoxFlat = button_normal.duplicate()
	button_focus.border_color = Color(0.5, 0.7, 1.0, 1.0)
	button_focus.border_width_bottom = 3
	button_focus.border_width_left = 3
	button_focus.border_width_right = 3
	button_focus.border_width_top = 3

	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("focus", "Button", button_focus)
	theme.set_color("font_color", "Button", fg_color)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)

	# Panel
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	theme.set_stylebox("panel", "Panel", panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# Label
	theme.set_color("font_color", "Label", fg_color)
	theme.set_font_size("font_size", "Label", 14)

	# LineEdit
	var line_edit_style: StyleBoxFlat = StyleBoxFlat.new()
	line_edit_style.bg_color = Color(0.1, 0.1, 0.12, 1.0)
	line_edit_style.border_width_bottom = 2
	line_edit_style.border_color = Color(0.3, 0.3, 0.35, 1.0)
	line_edit_style.corner_radius_top_left = 4
	line_edit_style.corner_radius_top_right = 4
	line_edit_style.corner_radius_bottom_left = 4
	line_edit_style.corner_radius_bottom_right = 4
	line_edit_style.content_margin_left = 8
	line_edit_style.content_margin_right = 8
	line_edit_style.content_margin_top = 6
	line_edit_style.content_margin_bottom = 6
	theme.set_stylebox("normal", "LineEdit", line_edit_style)
	theme.set_color("font_color", "LineEdit", fg_color)
	theme.set_color("caret_color", "LineEdit", accent_color)

	return theme


func _create_dark_theme() -> Theme:
	var theme: Theme = _create_default_theme()

	# Darker variant
	var bg_color: Color = Color(0.08, 0.08, 0.1, 1.0)
	var panel_style: StyleBoxFlat = theme.get_stylebox("panel", "Panel").duplicate()
	panel_style.bg_color = bg_color
	theme.set_stylebox("panel", "Panel", panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	return theme


func _create_pixel_theme() -> Theme:
	var theme: Theme = Theme.new()

	# Retro pixel colors
	var bg_color: Color = Color(0.1, 0.1, 0.15, 1.0)
	var fg_color: Color = Color(0.9, 0.9, 0.8, 1.0)
	var accent_color: Color = Color(0.8, 0.6, 0.2, 1.0)  # Gold

	# Button (sharp corners, no gradients)
	var button_normal: StyleBoxFlat = StyleBoxFlat.new()
	button_normal.bg_color = Color(0.2, 0.2, 0.25, 1.0)
	button_normal.border_width_bottom = 4
	button_normal.border_width_left = 2
	button_normal.border_width_right = 2
	button_normal.border_width_top = 2
	button_normal.border_color = accent_color
	button_normal.corner_radius_top_left = 0
	button_normal.corner_radius_top_right = 0
	button_normal.corner_radius_bottom_left = 0
	button_normal.corner_radius_bottom_right = 0
	button_normal.content_margin_left = 12
	button_normal.content_margin_right = 12
	button_normal.content_margin_top = 8
	button_normal.content_margin_bottom = 8

	var button_hover: StyleBoxFlat = button_normal.duplicate()
	button_hover.bg_color = accent_color
	button_hover.border_color = Color.WHITE

	var button_pressed: StyleBoxFlat = button_normal.duplicate()
	button_pressed.bg_color = Color(0.6, 0.4, 0.1, 1.0)

	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_color("font_color", "Button", fg_color)
	theme.set_color("font_hover_color", "Button", Color.BLACK)

	# Panel
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = bg_color
	panel_style.border_width_bottom = 4
	panel_style.border_width_left = 4
	panel_style.border_width_right = 4
	panel_style.border_width_top = 4
	panel_style.border_color = accent_color
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	theme.set_stylebox("panel", "Panel", panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# Label
	theme.set_color("font_color", "Label", fg_color)

	return theme


func _create_high_contrast_theme() -> Theme:
	var theme: Theme = Theme.new()

	# High contrast colors
	var bg_color: Color = Color.BLACK
	var fg_color: Color = Color.WHITE
	var accent_color: Color = Color.YELLOW

	# Button
	var button_normal: StyleBoxFlat = StyleBoxFlat.new()
	button_normal.bg_color = bg_color
	button_normal.border_width_bottom = 3
	button_normal.border_width_left = 3
	button_normal.border_width_right = 3
	button_normal.border_width_top = 3
	button_normal.border_color = fg_color
	button_normal.content_margin_left = 16
	button_normal.content_margin_right = 16
	button_normal.content_margin_top = 10
	button_normal.content_margin_bottom = 10

	var button_hover: StyleBoxFlat = button_normal.duplicate()
	button_hover.bg_color = accent_color
	button_hover.border_color = bg_color

	var button_pressed: StyleBoxFlat = button_normal.duplicate()
	button_pressed.bg_color = fg_color

	var button_focus: StyleBoxFlat = button_normal.duplicate()
	button_focus.border_color = accent_color
	button_focus.border_width_bottom = 5
	button_focus.border_width_left = 5
	button_focus.border_width_right = 5
	button_focus.border_width_top = 5

	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("focus", "Button", button_focus)
	theme.set_color("font_color", "Button", fg_color)
	theme.set_color("font_hover_color", "Button", bg_color)
	theme.set_color("font_pressed_color", "Button", bg_color)

	# Panel
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = bg_color
	panel_style.border_width_bottom = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_color = fg_color
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	theme.set_stylebox("panel", "Panel", panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# Label - larger for accessibility
	theme.set_color("font_color", "Label", fg_color)
	theme.set_font_size("font_size", "Label", 18)

	return theme


# ============================================================================
# SYSTEM THEME DETECTION
# ============================================================================


func _detect_system_theme() -> String:
	# Check for system dark mode preference
	# Note: Godot 4.5+ may have better OS theme detection
	var is_dark: bool = DisplayServer.is_dark_mode_supported() and DisplayServer.is_dark_mode()

	return PRESET_DARK if is_dark else PRESET_DEFAULT


## Enable/disable system theme following


func set_follow_system(enabled: bool) -> void:
	_follow_system = enabled

	if enabled:
		set_theme(_detect_system_theme())

	var cfg: Node = GameManager.get_core_system("config")
	if cfg:
		cfg.set_value("ui.theme.follow_system", enabled, true)


# ============================================================================
# PERSISTENCE
# ============================================================================


func _save_config() -> void:
	var cfg: Node = GameManager.get_core_system("config")
	if not cfg:
		return

	# Don't save if following system or using accessibility override
	if _follow_system or _accessibility.high_contrast:
		return

	cfg.set_value("ui.theme.current", _current_theme_id, true)
