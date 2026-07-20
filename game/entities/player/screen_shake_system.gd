class_name ScreenShakeSystem
extends Node

signal trauma_added(amount: float, source: String)
signal trauma_threshold_reached(level: String)

const CONFIG_PATH := "res://game/config/gameplay/ui.json5"

@export_group("Weapon Trauma")
@export var trauma_weapon_light: float = 0.08
@export var trauma_weapon_medium: float = 0.15
@export var trauma_weapon_heavy: float = 0.25
@export_group("Explosion Trauma")
@export var trauma_explosion_close: float = 0.7
@export var trauma_explosion_medium: float = 0.4
@export var trauma_explosion_far: float = 0.15
@export_group("Damage Trauma")
@export var trauma_damage_light: float = 0.15
@export var trauma_damage_medium: float = 0.25
@export var trauma_damage_heavy: float = 0.4
@export_group("Landing Trauma")
@export var trauma_landing_light: float = 0.1
@export var trauma_landing_medium: float = 0.25
@export var trauma_landing_heavy: float = 0.5
@export_group("Trauma Decay")
@export var max_trauma: float = 1.0
@export var trauma_decay_rate: float = 1.2
@export var trauma_power: float = 2.0
@export_group("Shake Intensity")
@export var max_rotation_shake: float = 3.0
@export var max_position_shake: float = 0.08
@export var max_fov_shake: float = 2.0
@export_group("Shake Frequency")
@export var rotation_frequency: float = 25.0
@export var position_frequency: float = 18.0
@export var fov_frequency: float = 12.0

var current_trauma: float = 0.0
var noise_seed: int = 0
var time_offset: float = 0.0
var noise: FastNoiseLite
var camera: Camera3D = null
var base_fov: float = 75.0

var _punch_intensity: float = 0.0
var _punch_direction: Vector2 = Vector2.ZERO  # X: Pitch, Y: Yaw
var _punch_decay: float = 10.0
var _fov_stored: bool = false


func _ready() -> void:
	set_process(false)  # Only process when trauma is active
	_init_noise()
	time_offset = randf() * 1000.0

	# Connect to config for hot-reload (if using GameManager.get_core_system("config"))
	var cfg: Node = GameManager.get_core_system("config")
	if cfg:
		cfg.config_reloaded.connect(_on_config_reloaded)
	_load_config()


func _exit_tree() -> void:
	# === SIGNAL HYGIENE ===
	var cfg2: Node = GameManager.get_core_system("config")
	if cfg2:
		if cfg2.config_reloaded.is_connected(_on_config_reloaded):
			cfg2.config_reloaded.disconnect(_on_config_reloaded)


func _on_config_reloaded(_file_path: String = "") -> void:
	_load_config()
	GameManager.get_core_system("logger").info(
		"[ScreenShakeSystem] Configuration reloaded", "Player"
	)


func _init_noise() -> void:
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 1.0
	noise.fractal_octaves = 2


func _load_config() -> void:
	## Try GameManager.get_core_system("config") first, fall back to direct JSON loading
	## This gives buyers flexibility to use either approach

	# Option 1: GameManager.get_core_system("config") (recommended for hot-reload support)
	var cfg3: Node = GameManager.get_core_system("config")
	var config_result: Variant = cfg3.get_value("visuals.screen_shake") if cfg3 else null
	if config_result != null and config_result is Dictionary:
		var config: Dictionary = config_result
		if not config.is_empty():
			_apply_config(config)
			return

	# Option 2: Direct JSON file loading (fallback)
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("[ScreenShakeSystem] Failed to parse config: %s" % CONFIG_PATH)
		return
	file.close()

	var json_config: Dictionary = json.data
	_apply_config(json_config)


func _apply_config(config: Dictionary) -> void:
	## Apply loaded configuration values
	# Trauma decay settings
	if config.has("trauma_decay"):
		var decay: Dictionary = config["trauma_decay"]
		max_trauma = decay.get("max_trauma", max_trauma)
		trauma_decay_rate = decay.get("trauma_decay_rate", trauma_decay_rate)
		trauma_power = decay.get("trauma_power", trauma_power)

	# Weapon trauma
	if config.has("weapon_trauma"):
		var weapon: Dictionary = config["weapon_trauma"]
		if weapon.has("light"):
			trauma_weapon_light = weapon["light"].get("trauma", trauma_weapon_light)
		if weapon.has("medium"):
			trauma_weapon_medium = weapon["medium"].get("trauma", trauma_weapon_medium)
		if weapon.has("heavy"):
			trauma_weapon_heavy = weapon["heavy"].get("trauma", trauma_weapon_heavy)

	# Explosion trauma
	if config.has("explosion_trauma"):
		var explosion: Dictionary = config["explosion_trauma"]
		if explosion.has("close"):
			trauma_explosion_close = explosion["close"].get("trauma", trauma_explosion_close)
		if explosion.has("medium"):
			trauma_explosion_medium = explosion["medium"].get("trauma", trauma_explosion_medium)
		if explosion.has("far"):
			trauma_explosion_far = explosion["far"].get("trauma", trauma_explosion_far)

	# Damage trauma
	if config.has("damage_trauma"):
		var dmg: Dictionary = config["damage_trauma"]
		if dmg.has("light"):
			trauma_damage_light = dmg["light"].get("trauma", trauma_damage_light)
		if dmg.has("medium"):
			trauma_damage_medium = dmg["medium"].get("trauma", trauma_damage_medium)
		if dmg.has("heavy"):
			trauma_damage_heavy = dmg["heavy"].get("trauma", trauma_damage_heavy)

	# Landing trauma
	if config.has("landing_trauma"):
		var landing: Dictionary = config["landing_trauma"]
		if landing.has("light"):
			trauma_landing_light = landing["light"].get("trauma", trauma_landing_light)
		if landing.has("medium"):
			trauma_landing_medium = landing["medium"].get("trauma", trauma_landing_medium)
		if landing.has("heavy"):
			trauma_landing_heavy = landing["heavy"].get("trauma", trauma_landing_heavy)

	# Shake intensity
	if config.has("shake_intensity"):
		var intensity: Dictionary = config["shake_intensity"]
		max_rotation_shake = intensity.get("max_rotation_shake", max_rotation_shake)
		max_position_shake = intensity.get("max_position_shake", max_position_shake)
		max_fov_shake = intensity.get("max_fov_shake", max_fov_shake)

	# Shake frequency
	if config.has("shake_frequency"):
		var freq: Dictionary = config["shake_frequency"]
		rotation_frequency = freq.get("rotation_frequency", rotation_frequency)
		position_frequency = freq.get("position_frequency", position_frequency)
		fov_frequency = freq.get("fov_frequency", fov_frequency)


func _process(delta: float) -> void:
	# Decay trauma over time
	if current_trauma > 0.0:
		current_trauma = max(0.0, current_trauma - trauma_decay_rate * delta)
		if current_trauma <= 0.0:
			set_process(false)  # Disable when trauma fully decayed


func add_trauma(amount: float, source: String = "generic") -> void:
	## Add trauma (usually from 0.0 to 1.0)
	current_trauma = clampf(current_trauma + amount, 0.0, max_trauma)

	if current_trauma > 0.001:
		set_process(true)

	trauma_added.emit(amount, source)

	# Check thresholds for haptic/audio triggers
	if current_trauma > 0.8:
		trauma_threshold_reached.emit("heavy")
	elif current_trauma > 0.5:
		trauma_threshold_reached.emit("medium")


func add_directional_trauma(amount: float, direction: Vector3) -> void:
	## Add trauma with a directional "kick" (punch)
	## Args:
	##   amount: Standard trauma amount
	##   direction: World-space direction hit came from (to kick away from)
	add_trauma(amount, "directional_hit")

	if not camera:
		return

	# Convert world direction to local camera pitch/yaw punch
	# This kicks the camera AWAY from the direction of the hit
	var local_dir := camera.global_transform.basis.inverse() * direction

	# X is Side (Yaw kick), Y is Up (Pitch kick), Z is Forward (FOV kick?)
	_punch_direction.x = -local_dir.y * 5.0  # Pitch kick (neg Y dir = look up)
	_punch_direction.y = local_dir.x * 3.0  # Yaw kick
	_punch_intensity = amount * 2.0


func add_weapon_fire_trauma(weapon_type: String = "medium") -> void:
	## Add trauma from weapon fire
	var trauma_amount := trauma_weapon_medium

	match weapon_type.to_lower():
		"light", "pistol", "smg":
			trauma_amount = trauma_weapon_light
		"medium", "rifle", "shotgun":
			trauma_amount = trauma_weapon_medium
		"heavy", "rocket", "sniper", "machinegun":
			trauma_amount = trauma_weapon_heavy

	add_trauma(trauma_amount, "weapon_%s" % weapon_type)


func add_explosion_trauma(distance: float, max_distance: float = 10.0) -> void:
	## Add trauma from explosion based on distance
	var distance_ratio: float = clamp(distance / max_distance, 0.0, 1.0)

	var trauma_amount: float
	if distance_ratio < 0.3:
		trauma_amount = trauma_explosion_close
	elif distance_ratio < 0.6:
		trauma_amount = trauma_explosion_medium
	else:
		trauma_amount = trauma_explosion_far

	# Scale by distance (closer = more trauma)
	trauma_amount *= (1.0 - distance_ratio * 0.5)

	add_trauma(trauma_amount, "explosion")


func add_damage_trauma(damage_amount: float, max_health: float = 100.0) -> void:
	## Add trauma from taking damage
	var damage_ratio: float = clamp(damage_amount / max_health, 0.0, 1.0)

	var trauma_amount: float
	if damage_ratio < 0.1:
		trauma_amount = trauma_damage_light
	elif damage_ratio < 0.25:
		trauma_amount = trauma_damage_medium
	else:
		trauma_amount = trauma_damage_heavy

	add_trauma(trauma_amount, "damage")


func add_landing_trauma(velocity: float, terminal_velocity: float = 20.0) -> void:
	## Add trauma from landing impact based on fall velocity
	## Args:
	##   velocity: The landing velocity (positive value, typically from abs(velocity.y))
	##   terminal_velocity: Maximum expected fall velocity for scaling
	var velocity_ratio: float = clamp(velocity / terminal_velocity, 0.0, 1.0)

	var trauma_amount: float
	if velocity_ratio < 0.3:
		trauma_amount = trauma_landing_light
	elif velocity_ratio < 0.6:
		trauma_amount = trauma_landing_medium
	else:
		trauma_amount = trauma_landing_heavy

	# Only add trauma if landing was significant
	if velocity_ratio > 0.2:
		add_trauma(trauma_amount, "landing_%.1fm/s" % velocity)


func apply_shake_to_camera(target_camera: Camera3D) -> void:
	## Apply shake effect to camera - call this in _physics_process
	if not target_camera:
		return

	camera = target_camera

	# Store base FOV on first use
	if not _fov_stored:
		base_fov = camera.fov
		_fov_stored = true

	# Calculate shake intensity (trauma^power for smooth falloff)
	var shake_intensity := pow(current_trauma, trauma_power)

	# Apply and decay punch intensity
	if _punch_intensity > 0.001:
		camera.rotation_degrees.x += _punch_direction.x * _punch_intensity
		camera.rotation_degrees.y += _punch_direction.y * _punch_intensity
		_punch_intensity = lerpf(_punch_intensity, 0.0, get_process_delta_time() * _punch_decay)

	if shake_intensity > 0.001:
		# Update time for noise sampling
		var current_time := Time.get_ticks_msec() / 1000.0 + time_offset

		# Generate shake offsets using noise-like functions
		var rotation_shake := _get_shake_rotation(current_time, shake_intensity)
		var position_shake := _get_shake_position(current_time, shake_intensity)
		var fov_shake := _get_shake_fov(current_time, shake_intensity)

		# Apply rotation shake (additive to existing rotation)
		camera.rotation_degrees.x += rotation_shake.x
		camera.rotation_degrees.y += rotation_shake.y
		camera.rotation_degrees.z = rotation_shake.z  # Roll is pure shake

		# Apply position shake (using h_offset and v_offset)
		camera.h_offset = position_shake.x
		camera.v_offset = position_shake.y

		# Apply FOV shake
		camera.fov = base_fov + fov_shake
	else:
		# Reset offsets when not shaking
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		camera.fov = base_fov


func reset_camera() -> void:
	## Reset camera to neutral state
	if camera:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		if _fov_stored:
			camera.fov = base_fov


func _get_shake_rotation(time: float, intensity: float) -> Vector3:
	## Generate rotation shake using sine waves
	var x_shake: float = _noise(time * rotation_frequency, 0.0) * max_rotation_shake * intensity
	var y_shake: float = (
		_noise(time * rotation_frequency, 1.0) * max_rotation_shake * intensity * 0.5
	)
	var z_shake: float = (
		_noise(time * rotation_frequency, 2.0) * max_rotation_shake * intensity * 0.3
	)
	return Vector3(x_shake, y_shake, z_shake)


func _get_shake_position(time: float, intensity: float) -> Vector3:
	## Generate position shake using sine waves
	return Vector3(
		_noise(time * position_frequency, 3.0) * max_position_shake * intensity,
		_noise(time * position_frequency, 4.0) * max_position_shake * intensity,
		0.0
	)


func _get_shake_fov(time: float, intensity: float) -> float:
	## Generate FOV shake using sine wave
	return _noise(time * fov_frequency, 6.0) * max_fov_shake * intensity


func _noise(time: float, offset: float) -> float:
	## Generate gradient noise using FastNoiseLite
	return noise.get_noise_2d(time, offset)


func get_trauma_level() -> float:
	## Get current trauma level (0.0 to 1.0)
	return current_trauma


func get_shake_intensity() -> float:
	## Get current shake intensity (trauma^power)
	return pow(current_trauma, trauma_power)


func clear_trauma() -> void:
	## Instantly clear all trauma
	current_trauma = 0.0
	reset_camera()


func get_trauma_stats() -> Dictionary:
	## Get trauma statistics
	return {
		"trauma": current_trauma,
		"shake_intensity": get_shake_intensity(),
		"is_shaking": current_trauma > 0.001
	}
