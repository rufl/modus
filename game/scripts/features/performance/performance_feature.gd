## PerformanceFeature - Feature module for performance monitoring and optimization
##
## Manages performance monitoring, quality settings, LOD management, and hardware detection.
## Provides API for performance metrics and optimization controls.
##
## Requirements: 2.3
class_name PerformanceFeature
extends FeatureModule

signal performance_warning(metric: String, value: float, threshold: float)
signal performance_critical(metric: String, value: float, threshold: float)
signal quality_preset_changed(preset: int)

const QualitySettingsClass = preload("res://game/scripts/features/performance/quality_settings.gd")
const LODManagerClass = preload("res://game/scripts/features/performance/lod_manager.gd")
const HardwareDetectorClass = preload(
	"res://game/scripts/features/performance/hardware_detector.gd"
)

## Performance settings
var enable_ai_throttling: bool = true
var ai_update_interval: float = 0.1
var target_fps: float = 60.0
var warning_fps: float = 45.0
var critical_fps: float = 30.0

## Current state
var current_quality_preset: int = 1  # MEDIUM
var current_fps: float = 0.0
var average_fps: float = 0.0
var memory_usage_mb: float = 0.0

## Subsystems
var _lod_manager: Node = null
var _hardware_detector: Node = null

## Internal timers
var _update_timer: float = 0.0
var _ai_timer: float = 0.0


## Constructor
func _init() -> void:
	super._init("performance")
	feature_name = "Performance System"


## Initialize the performance feature
func initialize() -> void:
	super.initialize()

	# Load configuration values
	enable_ai_throttling = get_config_value("ai_throttling.enabled", true)
	ai_update_interval = get_config_value("ai_throttling.update_interval", 0.1)
	target_fps = get_config_value("target_fps", 60.0)
	warning_fps = get_config_value("warning_fps", 45.0)
	critical_fps = get_config_value("critical_fps", 30.0)

	# Initialize hardware detector first
	_hardware_detector = HardwareDetectorClass.new()
	add_child(_hardware_detector)
	_hardware_detector.hardware_detected.connect(_on_hardware_detected)

	# Initialize LOD manager
	_lod_manager = LODManagerClass.new()
	add_child(_lod_manager)

	# Load or auto-detect quality preset
	var saved: int = _load_quality_preset()
	if saved < 0:
		var recommended: String = _hardware_detector.get_recommended_preset()
		current_quality_preset = _preset_name_to_int(recommended)
	else:
		current_quality_preset = saved

	apply_quality_preset(current_quality_preset)


## Shutdown the performance feature
func shutdown() -> void:
	# Clean up subsystems
	if _lod_manager and is_instance_valid(_lod_manager):
		_lod_manager.queue_free()
	if _hardware_detector and is_instance_valid(_hardware_detector):
		_hardware_detector.queue_free()

	super.shutdown()


## Process performance monitoring
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


## Update performance metrics
func _update_metrics(_delta: float) -> void:
	current_fps = Engine.get_frames_per_second()
	memory_usage_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0

	if is_nan(current_fps):
		push_warning("[PerformanceFeature] NaN detected in current_fps")
		current_fps = 0.0
	if is_nan(memory_usage_mb):
		push_warning("[PerformanceFeature] NaN detected in memory_usage_mb")
		memory_usage_mb = 0.0


## Check performance thresholds
func _check_thresholds() -> void:
	if current_fps < critical_fps:
		performance_critical.emit("FPS", current_fps, critical_fps)
	elif current_fps < warning_fps:
		performance_warning.emit("FPS", current_fps, warning_fps)


## Optimize AI update rates based on distance
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


## Apply quality preset
func apply_quality_preset(preset: int) -> void:
	current_quality_preset = preset
	var preset_config: Dictionary = QualitySettingsClass.get_preset_config(preset)

	# Apply environment settings
	var env: Node = get_tree().get_first_node_in_group("world_environment")
	if env and env.environment:
		env.environment.ssao_enabled = preset_config.get("ssao_enabled", false)
		env.environment.glow_enabled = preset_config.get("glow_enabled", true)

	# Apply LOD settings
	if _lod_manager:
		_lod_manager.set_lod_bias(preset_config.get("lod_bias", 1.0))

	# Apply AI settings
	ai_update_interval = preset_config.get("ai_update_interval", 0.1)

	_save_quality_preset(preset)
	quality_preset_changed.emit(preset)


## Get performance report
func get_performance_report() -> Dictionary:
	return {
		"fps": current_fps if not is_nan(current_fps) else 0.0,
		"memory_mb": memory_usage_mb if not is_nan(memory_usage_mb) else 0.0,
		"quality_preset": current_quality_preset,
		"ai_throttling": enable_ai_throttling,
		"objects": get_tree().get_node_count(),
		"version": "1.0"
	}


## Print performance statistics
func print_performance_stats() -> void:
	print("--- Performance Stats ---")
	print("FPS: %.2f" % (current_fps if not is_nan(current_fps) else 0.0))
	print("Memory: %.2f MB" % (memory_usage_mb if not is_nan(memory_usage_mb) else 0.0))
	print("Nodes: %d" % get_tree().get_node_count())
	print("Quality Preset: %d" % current_quality_preset)
	print("-----------------------")


## Optimize AI pathfinding
func optimize_ai_pathfinding() -> void:
	_optimize_ai()


## Get hardware information
func get_hardware_info() -> Dictionary:
	if _hardware_detector:
		return _hardware_detector.get_hardware_info()
	return {}


## Check if running on low-end hardware
func is_low_end_hardware() -> bool:
	if _hardware_detector:
		return _hardware_detector.is_low_end_hardware
	return false


## Check if running on Intel UHD 620
func is_uhd620() -> bool:
	if _hardware_detector:
		return _hardware_detector.is_uhd620()
	return false


## Save quality preset to user config
func _save_quality_preset(preset: int) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("graphics", "quality_preset", preset)
	cfg.save("user://graphics_settings.cfg")


## Load quality preset from user config
func _load_quality_preset() -> int:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load("user://graphics_settings.cfg") == OK:
		return cfg.get_value("graphics", "quality_preset", -1)
	return -1


## Convert preset name to integer
func _preset_name_to_int(preset_name: String) -> int:
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
			return 1


## Hardware detected event handler
func _on_hardware_detected(info: Dictionary) -> void:
	if info.is_low_end_hardware:
		_apply_low_end_optimizations()


## Apply optimizations for low-end hardware
func _apply_low_end_optimizations() -> void:
	if current_quality_preset > 0:
		apply_quality_preset(0)  # Force LOW preset

	if _lod_manager:
		_lod_manager.set_draw_distance(40.0)
		_lod_manager.set_lod_bias(6.0)
		_lod_manager.lod_update_interval = 0.5
		_lod_manager.cull_update_interval = 0.2

	ai_update_interval = 0.25
	target_fps = 45.0
	warning_fps = 30.0
	critical_fps = 20.0
