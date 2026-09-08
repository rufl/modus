extends Node

signal quality_changed(settings: Dictionary)

var current_settings: Dictionary = {}


func _ready() -> void:
	# Wait for GameManager.get_core_system("config")
	var gm: Node = get_node_or_null("/root/GameManager")
	var cfg: Node = gm.get_core_system("config") if gm else null
	if cfg and not cfg.is_node_ready():
		await cfg.ready

	# Listen for reload
	if cfg:
		cfg.config_reloaded.connect(_on_config_reloaded)

	# Apply initial
	_apply_graphics_settings()


func _on_config_reloaded(_file_path: String = "") -> void:
	_apply_graphics_settings()


func _apply_graphics_settings() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var cfg: Node = gm.get_core_system("config") if gm else null
	if not cfg:
		return

	var graphics_cfg: Dictionary = cfg.get_value("graphics", {})
	var preset_name: String = graphics_cfg.get("quality_preset", graphics_cfg.get("preset", "high"))

	var presets: Dictionary = cfg.get_value("visuals.quality_presets", {})

	# Fallback if preset missing
	if not presets.has(preset_name):
		push_warning("[GraphicsSystem] Preset '%s' not found. Defaulting to 'high'." % preset_name)
		preset_name = "high"

	if not presets.has(preset_name):
		push_warning("[GraphicsSystem] 'high' preset missing. Cannot apply settings.")
		return

	var settings: Dictionary = presets[preset_name].duplicate(true)

	# Apply custom overrides if any
	var custom: Dictionary = graphics_cfg.get("custom", {})
	for key: String in custom:
		settings[key] = custom[key]

	current_settings = settings
	_apply_to_engine(settings)

	quality_changed.emit(settings)
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger:
		logger.info("[GraphicsSystem] Applied quality preset: %s" % preset_name, "GraphicsSystem")


func _apply_to_engine(settings: Dictionary) -> void:
	# Shadows
	RenderingServer.directional_shadow_atlas_set_size(settings.get("shadow_size", 4096), true)

	# Global SSAO/SSR/SDFGI/Glow controlled via WorldEnvironment usually.
	# But we can try to set project settings or let the WorldEnvironment controller handle it.
	# For simpler MVP, we'll let components disable themselves based on 'quality_changed' signal
	# OR we find the active WorldEnvironment and update it.

	# Note: This might not be reliable if no camera yet.
	# Better approach: Components (WeatherController) listen to signal
	# and update the environment they control.


## Helper to check feature enablement


func is_feature_enabled(feature: String) -> bool:
	return current_settings.get(feature, false)


## Helper to get quality value


func get_quality_value(key: String, default: Variant = null) -> Variant:
	return current_settings.get(key, default)
