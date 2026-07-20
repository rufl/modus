extends Node

signal performance_warning(metric: String, value: float, threshold: float)
signal performance_critical(metric: String, value: float, threshold: float)
signal quality_preset_changed(preset: int)

const QualitySettingsClass = preload("res://game/scripts/features/performance/quality_settings.gd")
const LODManagerClass = preload("res://game/scripts/features/performance/lod_manager.gd")
const HardwareDetectorClass = preload(
	"res://game/scripts/features/performance/hardware_detector.gd"
)

var enable_ai_throttling: bool = true
var ai_update_interval: float = 0.1
var target_fps: float = 60.0
var warning_fps: float = 45.0
var critical_fps: float = 30.0
var current_quality_preset: int = 1  # MEDIUM
var current_fps: float = 0.0
var average_fps: float = 0.0
var memory_usage_mb: float = 0.0

var _lod_manager: Node = null
var _hardware_detector: Node = null
var _update_timer: float = 0.0
var _ai_timer: float = 0.0


static func get_service() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("GameManager"):
		var manager: Node = tree.root.get_node("GameManager")
		if manager.has_method("get_core_system"):
			return manager.get_core_system("performance")
	return null


func initialize() -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info("[PerformanceService] Initializing...", "PerformanceService")

	# Initialize hardware detector first
	_hardware_detector = HardwareDetectorClass.new()
	add_child(_hardware_detector)
	_hardware_detector.hardware_detected.connect(_on_hardware_detected)

	_lod_manager = LODManagerClass.new()
	add_child(_lod_manager)

	# Load or auto-detect preset
	var saved: int = _load_quality_preset()
	if saved < 0:
		# Use hardware-detected preset
		var recommended: String = _hardware_detector.get_recommended_preset()
		current_quality_preset = _preset_name_to_int(recommended)
	else:
		current_quality_preset = saved

	apply_quality_preset(current_quality_preset)
	await get_tree().process_frame


func _process(delta: float) -> void:
	_update_metrics(delta)

	if enable_ai_throttling:
		_ai_timer += delta
		if _ai_timer >= ai_update_interval:
			_ai_timer = 0.0
			_optimize_ai()

	_update_timer += delta
	if _update_timer >= 1.0:
		_update_timer = 0.0
		_check_thresholds()


func _update_metrics(_delta: float) -> void:
	current_fps = Engine.get_frames_per_second()
	memory_usage_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0

	# Debug: Check for NaN values
	if is_nan(current_fps):
		push_warning("[PerformanceService] NaN detected in current_fps")
		current_fps = 0.0
	if is_nan(memory_usage_mb):
		push_warning("[PerformanceService] NaN detected in memory_usage_mb")
		memory_usage_mb = 0.0


func _check_thresholds() -> void:
	if current_fps < critical_fps:
		performance_critical.emit("FPS", current_fps, critical_fps)
	elif current_fps < warning_fps:
		performance_warning.emit("FPS", current_fps, warning_fps)


func _optimize_ai() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy: Node in enemies:
		if enemy.has_method("set_ai_update_rate"):
			var dist: float = enemy.global_position.distance_to(player.global_position)
			if dist < 20.0:
				enemy.set_ai_update_rate(1.0)
			elif dist < 40.0:
				enemy.set_ai_update_rate(0.5)
			else:
				enemy.set_ai_update_rate(0.25)


func apply_quality_preset(preset: int) -> void:
	current_quality_preset = preset
	var config: Dictionary = QualitySettingsClass.get_preset_config(preset)

	# Apply environment settings
	var env: Node = get_tree().get_first_node_in_group("world_environment")
	if env and env.environment:
		env.environment.ssao_enabled = config.get("ssao_enabled", false)
		env.environment.glow_enabled = config.get("glow_enabled", true)

	if _lod_manager:
		_lod_manager.set_lod_bias(config.get("lod_bias", 1.0))

	ai_update_interval = config.get("ai_update_interval", 0.1)
	_save_quality_preset(preset)
	quality_preset_changed.emit(preset)


func _save_quality_preset(preset: int) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("graphics", "quality_preset", preset)
	cfg.save("user://graphics_settings.cfg")


func _load_quality_preset() -> int:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load("user://graphics_settings.cfg") == OK:
		return cfg.get_value("graphics", "quality_preset", -1)
	return -1


func get_performance_report() -> Dictionary:
	var report: Dictionary = {
		"fps": current_fps if not is_nan(current_fps) else 0.0,
		"memory_mb": memory_usage_mb if not is_nan(memory_usage_mb) else 0.0,
		"quality_preset": current_quality_preset,
		"ai_throttling": enable_ai_throttling,
		"objects": get_tree().get_node_count(),
		"version": "1.0"
	}
	return report


func print_performance_stats() -> void:
	GameManager.get_core_system("logger").info("--- Performance Stats ---", "Core")
	GameManager.get_core_system("logger").info(
		"FPS: %.2f" % (current_fps if not is_nan(current_fps) else 0.0), "Core"
	)
	GameManager.get_core_system("logger").info(
		"Memory: %.2f MB" % (memory_usage_mb if not is_nan(memory_usage_mb) else 0.0), "Core"
	)
	GameManager.get_core_system("logger").info("Nodes: %d" % get_tree().get_node_count(), "Core")
	GameManager.get_core_system("logger").info(
		"Quality Preset: %d" % current_quality_preset, "Core"
	)
	GameManager.get_core_system("logger").info("-----------------------", "Core")


func optimize_ai_pathfinding() -> void:
	# Implementation specific optimization call
	_optimize_ai()
	GameManager.get_core_system("logger").info(
		"[PerformanceService] Triggered manual AI pathfinding optimization", "Core"
	)


func _on_hardware_detected(info: Dictionary) -> void:
	## Called when hardware is detected
	GameManager.get_core_system("logger").info(
		"[PerformanceService] Hardware detected: %s %s" % [info.gpu_vendor, info.gpu_tier],
		"PerformanceService"
	)

	# Apply hardware-specific optimizations
	if info.is_low_end_hardware:
		_apply_low_end_optimizations()


func _apply_low_end_optimizations() -> void:
	## Apply optimizations for low-end hardware (UHD620, etc.)
	GameManager.get_core_system("logger").info(
		"[PerformanceService] Applying low-end hardware optimizations", "PerformanceService"
	)

	# Force low quality preset
	if current_quality_preset > 0:  # If not already on LOW
		apply_quality_preset(0)  # LOW preset

	# Additional optimizations beyond preset
	if _lod_manager:
		_lod_manager.set_draw_distance(40.0)  # Shorter draw distance
		_lod_manager.set_lod_bias(6.0)  # Very aggressive LOD
		_lod_manager.lod_update_interval = 0.5  # Less frequent updates
		_lod_manager.cull_update_interval = 0.2  # Less frequent culling

	# Reduce AI update frequency
	ai_update_interval = 0.25  # 4 FPS AI updates
	target_fps = 45.0  # Lower target FPS
	warning_fps = 30.0
	critical_fps = 20.0


func _preset_name_to_int(preset_name: String) -> int:
	## Convert preset name to integer
	match preset_name.to_lower():
		"low":
			return 0
		"medium":
			return 1
		"high":
			return 2
		"ultra":
			return 3
		_:
			return 1  # Default to medium


func get_hardware_info() -> Dictionary:
	## Get hardware information
	if _hardware_detector:
		return _hardware_detector.get_hardware_info()
	return {}


func is_low_end_hardware() -> bool:
	## Check if running on low-end hardware
	if _hardware_detector:
		return _hardware_detector.is_low_end_hardware
	return false


func is_uhd620() -> bool:
	## Check if running on Intel UHD 620
	if _hardware_detector:
		return _hardware_detector.is_uhd620()
	return false
