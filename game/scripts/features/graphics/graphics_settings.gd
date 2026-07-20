extends Node

signal quality_changed(preset: int)

enum Preset { LOW, MEDIUM, HIGH, ULTRA }

const PRESET_NAMES: Array[String] = ["Low", "Medium", "High", "Ultra"]
const SETTINGS_PATH: String = "user://graphics_settings.cfg"

var current_preset: Preset = Preset.MEDIUM


## Helper to set screen-space AA only if renderer supports it
func _set_screen_space_aa(mode: Viewport.ScreenSpaceAA) -> void:
	var rendering_method: String = ProjectSettings.get_setting(
		"rendering/renderer/rendering_method", "forward_plus"
	)
	if rendering_method in ["forward_plus", "mobile"]:
		get_viewport().screen_space_aa = mode


func _ready() -> void:
	# Load saved settings or auto-detect
	if not _load_settings():
		_auto_detect_preset()

	apply_preset(current_preset)


func apply_preset(preset: Preset) -> void:
	current_preset = preset

	match preset:
		Preset.LOW:
			_apply_low()
		Preset.MEDIUM:
			_apply_medium()
		Preset.HIGH:
			_apply_high()
		Preset.ULTRA:
			_apply_ultra()

	_save_settings()
	quality_changed.emit(preset)
	GameManager.get_core_system("logger").info(
		"[GraphicsSettings] Applied preset: " + " " + str(PRESET_NAMES[preset]), "Core"
	)


func _apply_low() -> void:
	# Resolution scaling (70%)
	get_viewport().scaling_3d_scale = 0.7
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR

	# Shadows - minimal
	RenderingServer.directional_shadow_atlas_set_size(1024, true)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)

	# Anti-aliasing - none
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	_set_screen_space_aa(Viewport.SCREEN_SPACE_AA_DISABLED)

	# Effects
	_set_environment_quality(0)


func _apply_medium() -> void:
	# Resolution scaling (85%)
	get_viewport().scaling_3d_scale = 0.85
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR

	# Shadows - soft
	RenderingServer.directional_shadow_atlas_set_size(2048, true)
	RenderingServer.positional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW
	)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW
	)

	# Anti-aliasing - FXAA
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	_set_screen_space_aa(Viewport.SCREEN_SPACE_AA_FXAA)

	# Effects
	_set_environment_quality(1)


func _apply_high() -> void:
	# Resolution scaling (100%)
	get_viewport().scaling_3d_scale = 1.0
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR

	# Shadows - high quality
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	RenderingServer.positional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
	)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
	)

	# Anti-aliasing - MSAA 2x
	get_viewport().msaa_3d = Viewport.MSAA_2X
	_set_screen_space_aa(Viewport.SCREEN_SPACE_AA_DISABLED)

	# Effects
	_set_environment_quality(2)


func _apply_ultra() -> void:
	# Resolution scaling (100%)
	get_viewport().scaling_3d_scale = 1.0
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR

	# Shadows - maximum quality
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	RenderingServer.positional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_ULTRA
	)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_ULTRA
	)

	# Anti-aliasing - MSAA 4x
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_set_screen_space_aa(Viewport.SCREEN_SPACE_AA_DISABLED)

	# Effects
	_set_environment_quality(3)


func _set_environment_quality(level: int) -> void:
	# Find world environment and adjust
	var env: WorldEnvironment = _find_world_environment()
	if not env or not env.environment:
		return

	match level:
		0:  # Low
			env.environment.ssao_enabled = false
			env.environment.ssil_enabled = false
			env.environment.sdfgi_enabled = false
			env.environment.glow_enabled = false
			env.environment.ssr_enabled = false
		1:  # Medium
			env.environment.ssao_enabled = false
			env.environment.ssil_enabled = false
			env.environment.sdfgi_enabled = false
			env.environment.glow_enabled = true
			env.environment.ssr_enabled = false
		2:  # High
			env.environment.ssao_enabled = true
			env.environment.ssil_enabled = false
			env.environment.sdfgi_enabled = false
			env.environment.glow_enabled = true
			env.environment.ssr_enabled = false
		3:  # Ultra
			env.environment.ssao_enabled = true
			env.environment.ssil_enabled = true
			env.environment.sdfgi_enabled = false  # Manual enable per-level
			env.environment.glow_enabled = true
			env.environment.ssr_enabled = true


func _find_world_environment() -> WorldEnvironment:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("world_environment")
	if nodes.size() > 0:
		return nodes[0] as WorldEnvironment

	# Fallback: search scene tree
	return _recursive_find(get_tree().current_scene)


func _recursive_find(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	for child in node.get_children():
		var result: WorldEnvironment = _recursive_find(child)
		if result:
			return result
	return null


func _auto_detect_preset() -> void:
	# Detect GPU capabilities
	var video_adapter: String = RenderingServer.get_video_adapter_name().to_lower()

	# Check for integrated GPUs
	if "intel" in video_adapter or "uhd" in video_adapter:
		current_preset = Preset.LOW
		GameManager.get_core_system("logger").info(
			"[GraphicsSettings] Detected Intel iGPU, using LOW preset", "Core"
		)
	elif "amd" in video_adapter and "vega" in video_adapter:
		current_preset = Preset.LOW
		GameManager.get_core_system("logger").info(
			"[GraphicsSettings] Detected AMD APU, using LOW preset", "Core"
		)
	elif "nvidia" in video_adapter:
		# Check for low-end NVIDIA
		if "mx" in video_adapter or "1050" in video_adapter or "1650" in video_adapter:
			current_preset = Preset.MEDIUM
		else:
			current_preset = Preset.HIGH
	elif "amd" in video_adapter or "radeon" in video_adapter:
		current_preset = Preset.MEDIUM
	else:
		current_preset = Preset.MEDIUM

	GameManager.get_core_system("logger").info(
		"[GraphicsSettings] Auto-detected: " + " " + str(PRESET_NAMES[current_preset]), "Core"
	)


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("graphics", "preset", current_preset)
	config.save(SETTINGS_PATH)


func _load_settings() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		current_preset = config.get_value("graphics", "preset", Preset.MEDIUM)
		return true
	return false


func get_preset_name() -> String:
	return PRESET_NAMES[current_preset]


func cycle_preset() -> void:
	var next: int = (current_preset + 1) % Preset.size()
	apply_preset(next as Preset)
