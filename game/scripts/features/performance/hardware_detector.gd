class_name HardwareDetector
extends Node
## Detects hardware capabilities and recommends optimal settings

signal hardware_detected(info: Dictionary)

enum GPUVendor { UNKNOWN, INTEL, AMD, NVIDIA, ARM }
enum GPUTier { UNKNOWN, LOW, MEDIUM, HIGH, ULTRA }

var gpu_vendor: GPUVendor = GPUVendor.UNKNOWN
var gpu_tier: GPUTier = GPUTier.UNKNOWN
var gpu_name: String = ""
var cpu_count: int = 0
var memory_mb: int = 0
var is_integrated_gpu: bool = false
var is_low_end_hardware: bool = false

# Known low-end GPUs
const LOW_END_GPUS: Array[String] = [
	"UHD 620",
	"UHD 630",
	"HD 620",
	"HD 630",
	"Iris",
	"Vega 3",
	"Vega 5",
	"Vega 6",
	"Vega 7",
	"Vega 8",
	"Radeon Graphics",  # AMD APU integrated
	"Mali",  # ARM integrated
	"Adreno",  # Qualcomm integrated
]

# Known medium-end GPUs
const MEDIUM_END_GPUS: Array[String] = [
	"GTX 1050",
	"GTX 1060",
	"GTX 1650",
	"GTX 1660",
	"RX 560",
	"RX 570",
	"RX 580",
	"RX 5500",
	"Arc A380",
]

# Known high-end GPUs
const HIGH_END_GPUS: Array[String] = [
	"RTX 2060",
	"RTX 2070",
	"RTX 2080",
	"RTX 3060",
	"RTX 3070",
	"RTX 3080",
	"RX 5700",
	"RX 6600",
	"RX 6700",
	"RX 6800",
	"Arc A750",
	"Arc A770",
]

# Known ultra-end GPUs
const ULTRA_END_GPUS: Array[String] = [
	"RTX 3090",
	"RTX 4070",
	"RTX 4080",
	"RTX 4090",
	"RX 6900",
	"RX 7800",
	"RX 7900",
]


func _ready() -> void:
	detect_hardware()


func detect_hardware() -> void:
	## Detect hardware capabilities
	_detect_gpu()
	_detect_cpu()
	_detect_memory()
	_determine_tier()

	var info := get_hardware_info()
	hardware_detected.emit(info)

	GameManager.get_core_system("logger").info(
		"[HardwareDetector] GPU: %s (%s, %s)" % [gpu_name, _vendor_to_string(), _tier_to_string()],
		"Performance"
	)
	GameManager.get_core_system("logger").info(
		"[HardwareDetector] CPU: %d cores, RAM: %d MB" % [cpu_count, memory_mb], "Performance"
	)


func _detect_gpu() -> void:
	## Detect GPU vendor and model
	var adapter_name := RenderingServer.get_video_adapter_name()
	gpu_name = adapter_name

	# Detect vendor
	if "Intel" in adapter_name:
		gpu_vendor = GPUVendor.INTEL
		is_integrated_gpu = true
	elif "AMD" in adapter_name or "Radeon" in adapter_name:
		gpu_vendor = GPUVendor.AMD
		# Check if integrated
		if "Vega" in adapter_name or "Radeon Graphics" in adapter_name:
			is_integrated_gpu = true
	elif (
		"NVIDIA" in adapter_name
		or "GeForce" in adapter_name
		or "GTX" in adapter_name
		or "RTX" in adapter_name
	):
		gpu_vendor = GPUVendor.NVIDIA
	elif "Mali" in adapter_name or "Adreno" in adapter_name:
		gpu_vendor = GPUVendor.ARM
		is_integrated_gpu = true
	else:
		gpu_vendor = GPUVendor.UNKNOWN


func _detect_cpu() -> void:
	## Detect CPU core count
	cpu_count = OS.get_processor_count()


func _detect_memory() -> void:
	## Detect system memory (approximate)
	# Godot doesn't expose this directly, estimate from OS
	var os_name := OS.get_name()
	if os_name == "Windows" or os_name == "Linux" or os_name == "macOS":
		# Assume at least 4GB for desktop
		memory_mb = 4096
		# Try to get more accurate info from environment
		if OS.has_feature("low_memory"):
			memory_mb = 2048
	else:
		# Mobile or unknown
		memory_mb = 2048


func _determine_tier() -> void:
	## Determine GPU tier based on name matching
	for gpu: String in ULTRA_END_GPUS:
		if gpu in gpu_name:
			gpu_tier = GPUTier.ULTRA
			return

	for gpu: String in HIGH_END_GPUS:
		if gpu in gpu_name:
			gpu_tier = GPUTier.HIGH
			return

	for gpu: String in MEDIUM_END_GPUS:
		if gpu in gpu_name:
			gpu_tier = GPUTier.MEDIUM
			return

	for gpu: String in LOW_END_GPUS:
		if gpu in gpu_name:
			gpu_tier = GPUTier.LOW
			is_low_end_hardware = true
			return

	# Fallback: use heuristics
	if is_integrated_gpu:
		gpu_tier = GPUTier.LOW
		is_low_end_hardware = true
	elif cpu_count <= 2:
		gpu_tier = GPUTier.LOW
		is_low_end_hardware = true
	elif cpu_count <= 4:
		gpu_tier = GPUTier.MEDIUM
	else:
		gpu_tier = GPUTier.HIGH


func get_hardware_info() -> Dictionary:
	## Get hardware information as dictionary
	return {
		"gpu_vendor": _vendor_to_string(),
		"gpu_tier": _tier_to_string(),
		"gpu_name": gpu_name,
		"cpu_count": cpu_count,
		"memory_mb": memory_mb,
		"is_integrated_gpu": is_integrated_gpu,
		"is_low_end_hardware": is_low_end_hardware,
	}


func get_recommended_preset() -> String:
	## Get recommended quality preset based on hardware
	match gpu_tier:
		GPUTier.LOW:
			return "low"
		GPUTier.MEDIUM:
			return "medium"
		GPUTier.HIGH:
			return "high"
		GPUTier.ULTRA:
			return "ultra"
		_:
			return "medium"  # Safe default


func get_recommended_settings() -> Dictionary:
	## Get recommended settings based on hardware
	var settings := {}

	match gpu_tier:
		GPUTier.LOW:
			settings = {
				"shadow_enabled": false,
				"shadow_size": 1024,
				"ssao_enabled": false,
				"ssr_enabled": false,
				"sdfgi_enabled": false,
				"volumetric_fog": false,
				"glow_enabled": false,
				"max_particles": 50,
				"lod_bias": 4.0,
				"entity_draw_distance": 50.0,
				"effect_quality": 0.25,
				"ai_update_interval": 0.2,
				"target_fps": 60,
			}
		GPUTier.MEDIUM:
			settings = {
				"shadow_enabled": true,
				"shadow_size": 2048,
				"ssao_enabled": false,
				"ssr_enabled": false,
				"sdfgi_enabled": false,
				"volumetric_fog": false,
				"glow_enabled": true,
				"max_particles": 100,
				"lod_bias": 2.0,
				"entity_draw_distance": 100.0,
				"effect_quality": 0.5,
				"ai_update_interval": 0.15,
				"target_fps": 60,
			}
		GPUTier.HIGH:
			settings = {
				"shadow_enabled": true,
				"shadow_size": 4096,
				"ssao_enabled": true,
				"ssr_enabled": false,
				"sdfgi_enabled": false,
				"volumetric_fog": true,
				"glow_enabled": true,
				"max_particles": 200,
				"lod_bias": 1.0,
				"entity_draw_distance": 150.0,
				"effect_quality": 0.75,
				"ai_update_interval": 0.1,
				"target_fps": 60,
			}
		GPUTier.ULTRA:
			settings = {
				"shadow_enabled": true,
				"shadow_size": 8192,
				"ssao_enabled": true,
				"ssr_enabled": true,
				"sdfgi_enabled": true,
				"volumetric_fog": true,
				"glow_enabled": true,
				"max_particles": 500,
				"lod_bias": 0.5,
				"entity_draw_distance": 200.0,
				"effect_quality": 1.0,
				"ai_update_interval": 0.05,
				"target_fps": 120,
			}
		_:
			settings = get_recommended_settings_for_tier(GPUTier.MEDIUM)

	# Apply Intel-specific optimizations
	if gpu_vendor == GPUVendor.INTEL and is_integrated_gpu:
		settings["shadow_enabled"] = false  # Intel integrated GPUs struggle with shadows
		settings["ssao_enabled"] = false
		settings["ssr_enabled"] = false
		settings["volumetric_fog"] = false
		settings["max_particles"] = 30
		settings["lod_bias"] = 6.0  # Very aggressive LOD
		settings["entity_draw_distance"] = 40.0  # Shorter draw distance
		settings["effect_quality"] = 0.15  # Minimal effects

	return settings


func get_recommended_settings_for_tier(tier: GPUTier) -> Dictionary:
	## Get recommended settings for a specific tier
	var temp_tier := gpu_tier
	gpu_tier = tier
	var settings := get_recommended_settings()
	gpu_tier = temp_tier
	return settings


func _vendor_to_string() -> String:
	match gpu_vendor:
		GPUVendor.INTEL:
			return "Intel"
		GPUVendor.AMD:
			return "AMD"
		GPUVendor.NVIDIA:
			return "NVIDIA"
		GPUVendor.ARM:
			return "ARM"
		_:
			return "Unknown"


func _tier_to_string() -> String:
	match gpu_tier:
		GPUTier.LOW:
			return "Low"
		GPUTier.MEDIUM:
			return "Medium"
		GPUTier.HIGH:
			return "High"
		GPUTier.ULTRA:
			return "Ultra"
		_:
			return "Unknown"


func is_uhd620() -> bool:
	## Check if GPU is Intel UHD 620 specifically
	return "UHD 620" in gpu_name or "UHD620" in gpu_name


func is_intel_integrated() -> bool:
	## Check if GPU is Intel integrated
	return gpu_vendor == GPUVendor.INTEL and is_integrated_gpu
