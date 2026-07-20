class_name QualitySettings
extends RefCounted

enum QualityPreset { LOW, MEDIUM, HIGH, ULTRA, CUSTOM }

const DEFAULT_PRESETS: Dictionary = {
	QualityPreset.LOW:
	{
		"name": "Low",
		"shadow_quality": 0,
		"ssao_enabled": false,
		"ssr_enabled": false,
		"volumetric_fog": false,
		"particle_quality": 0.5,
		"texture_quality": 0,
		"antialiasing": 0,
	},
	QualityPreset.MEDIUM:
	{
		"name": "Medium",
		"shadow_quality": 1,
		"ssao_enabled": true,
		"ssr_enabled": false,
		"volumetric_fog": false,
		"particle_quality": 0.75,
		"texture_quality": 1,
		"antialiasing": 1,
	},
	QualityPreset.HIGH:
	{
		"name": "High",
		"shadow_quality": 2,
		"ssao_enabled": true,
		"ssr_enabled": true,
		"volumetric_fog": true,
		"particle_quality": 1.0,
		"texture_quality": 2,
		"antialiasing": 2,
	},
	QualityPreset.ULTRA:
	{
		"name": "Ultra",
		"shadow_quality": 3,
		"ssao_enabled": true,
		"ssr_enabled": true,
		"volumetric_fog": true,
		"particle_quality": 1.5,
		"texture_quality": 3,
		"antialiasing": 3,
	},
}

static var _loaded_presets: Dictionary = {}


static func auto_detect_preset() -> QualityPreset:
	# Get video adapter info
	var video_adapter: String = RenderingServer.get_video_adapter_name().to_lower()

	# Check for high-end GPUs
	var high_end_keywords: Array[String] = [
		"rtx 40", "rtx 30", "rx 7", "rx 6800", "rx 6900", "arc a7", "m1 pro", "m1 max", "m2", "m3"
	]

	var mid_range_keywords: Array[String] = [
		"rtx 20", "gtx 16", "gtx 10", "rx 6600", "rx 6700", "rx 5", "arc a5", "m1", "intel iris"
	]

	for keyword: String in high_end_keywords:
		if keyword in video_adapter:
			GameManager.get_core_system("logger").info(
				"[QualitySettings] Detected high-end GPU, using ULTRA preset", "Core"
			)
			return QualityPreset.ULTRA

	for keyword: String in mid_range_keywords:
		if keyword in video_adapter:
			GameManager.get_core_system("logger").info(
				"[QualitySettings] Detected mid-range GPU, using HIGH preset", "Core"
			)
			return QualityPreset.HIGH

	# Check available VRAM (rough estimate based on texture memory)
	var vram_mb: float = (
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1024.0 / 1024.0
	)

	if vram_mb > 4000:
		GameManager.get_core_system("logger").info(
			"[QualitySettings] High VRAM detected, using HIGH preset", "Core"
		)
		return QualityPreset.HIGH

	if vram_mb > 2000:
		GameManager.get_core_system("logger").info(
			"[QualitySettings] Medium VRAM detected, using MEDIUM preset", "Core"
		)
		return QualityPreset.MEDIUM

	GameManager.get_core_system("logger").info(
		"[QualitySettings] Low VRAM detected, using LOW preset", "Core"
	)
	return QualityPreset.LOW


## Get preset configuration


static func get_preset_config(preset: QualityPreset) -> Dictionary:
	# Initialize loader logic if empty
	if _loaded_presets.is_empty():
		_load_presets_from_config()

	if preset in _loaded_presets:
		return _loaded_presets[preset].duplicate()

	# Fallback
	if preset in DEFAULT_PRESETS:
		return DEFAULT_PRESETS[preset].duplicate()

	return DEFAULT_PRESETS[QualityPreset.MEDIUM].duplicate()


static func _load_presets_from_config() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		_loaded_presets = DEFAULT_PRESETS.duplicate(true)
		return

	var manager: Node = tree.root.get_node_or_null("GameManager")
	var cm: Node = manager.get_core_system("config") if manager else null
	var config_result: Variant = cm.get_value("visuals.quality_presets") if cm else null

	if config_result == null or not config_result is Dictionary:
		_loaded_presets = DEFAULT_PRESETS.duplicate(true)
		return

	var config: Dictionary = config_result
	if config.is_empty():
		_loaded_presets = DEFAULT_PRESETS.duplicate(true)
		return

	# Map string keys back to enum
	for key: String in config.keys():
		var preset_enum: int = -1
		match key.to_lower():
			"low":
				preset_enum = QualityPreset.LOW
			"medium":
				preset_enum = QualityPreset.MEDIUM
			"high":
				preset_enum = QualityPreset.HIGH
			"ultra":
				preset_enum = QualityPreset.ULTRA

		if preset_enum != -1:
			_loaded_presets[preset_enum] = config[key]


## Get preset name


static func get_preset_name(preset: QualityPreset) -> String:
	var config: Dictionary = get_preset_config(preset)
	return config.get("name", "Unknown")


## Get all preset names for UI


static func get_preset_names() -> Array[String]:
	return ["Low", "Medium", "High", "Ultra"]
