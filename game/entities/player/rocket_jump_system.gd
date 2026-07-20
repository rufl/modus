class_name RocketJumpSystem
extends Node

signal rocket_jump_performed(velocity: Vector3, speed: float)
signal rocket_jump_ended

const CONFIG_PATH := "res://game/config/gameplay/gameplay.json5"
const JSON5LoaderClass := preload("res://game/core/json5_loader.gd")

@export var velocity_multiplier: float = 1.5
@export var min_boost_velocity: float = 8.0
@export var max_boost_velocity: float = 25.0
@export var air_control_multiplier: float = 1.2

var is_rocket_jumping: bool = false
var rocket_jump_timer: float = 0.0
var rocket_jump_duration: float = 0.5
var player: CharacterBody3D = null


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if not player:
		push_error("[RocketJumpSystem] Must be child of CharacterBody3D")
	_load_config()


func _load_config(_file_path: String = "") -> void:
	var cfg: Dictionary = {}
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var config_manager: Node = gm.get_core_system("config")
		if config_manager:
			var config_result: Variant = config_manager.get_value("movement.rocket_jump", {})
			if config_result is Dictionary:
				cfg = config_result
			if not config_manager.config_reloaded.is_connected(_load_config):
				config_manager.config_reloaded.connect(_load_config)

	if cfg.is_empty():
		var data: Variant = JSON5LoaderClass.load_file(CONFIG_PATH)
		if data is Dictionary:
			var movement: Variant = data.get("movement", {})
			if movement is Dictionary:
				var rocket_jump: Variant = movement.get("rocket_jump", {})
				if rocket_jump is Dictionary:
					cfg = rocket_jump

	if cfg.is_empty():
		return

	_apply_config(cfg)

	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger:
			logger.info("[RocketJumpSystem] Config loaded from: %s" % CONFIG_PATH, "Player")


func _exit_tree() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return
	var config_manager: Node = gm.get_core_system("config")
	if config_manager and config_manager.config_reloaded.is_connected(_load_config):
		config_manager.config_reloaded.disconnect(_load_config)


func _apply_config(cfg: Dictionary) -> void:
	velocity_multiplier = cfg.get("velocity_multiplier", velocity_multiplier)
	min_boost_velocity = cfg.get("min_boost_velocity", min_boost_velocity)
	max_boost_velocity = cfg.get("max_boost_velocity", max_boost_velocity)
	air_control_multiplier = cfg.get("air_control_multiplier", air_control_multiplier)
	rocket_jump_duration = cfg.get("duration", rocket_jump_duration)


func _process(delta: float) -> void:
	if is_rocket_jumping:
		rocket_jump_timer -= delta
		if rocket_jump_timer <= 0.0:
			end_rocket_jump()


func apply_explosion_force(
	explosion_position: Vector3, player_position: Vector3, base_force: float
) -> Vector3:
	# Calculate and apply rocket jump velocity boost
	if not player:
		return Vector3.ZERO

	# Calculate direction away from explosion
	var direction := (player_position - explosion_position).normalized()

	# Calculate distance-based force
	var distance := explosion_position.distance_to(player_position)
	var force_multiplier := 1.0

	# Closer explosions = more force (inverse square falloff)
	if distance > 0.1:
		force_multiplier = 1.0 / (distance * 0.5)
		force_multiplier = clamp(force_multiplier, 0.3, 2.0)

	# Calculate boost velocity
	var boost_velocity := direction * base_force * force_multiplier * velocity_multiplier
	var boost_speed := boost_velocity.length()

	# Clamp to reasonable values
	if boost_speed > max_boost_velocity:
		boost_velocity = boost_velocity.normalized() * max_boost_velocity
	elif boost_speed < min_boost_velocity:
		boost_velocity = boost_velocity.normalized() * min_boost_velocity

	# Start rocket jump state
	start_rocket_jump(boost_velocity)

	return boost_velocity


func start_rocket_jump(boost_velocity: Vector3) -> void:
	# Start rocket jump state
	is_rocket_jumping = true
	rocket_jump_timer = rocket_jump_duration

	var speed := boost_velocity.length()
	rocket_jump_performed.emit(boost_velocity, speed)


func end_rocket_jump() -> void:
	# End rocket jump state
	if is_rocket_jumping:
		is_rocket_jumping = false
		rocket_jump_ended.emit()


func get_air_control_modifier() -> float:
	# Get air control multiplier during rocket jump
	if is_rocket_jumping:
		return air_control_multiplier
	return 1.0


## Configure from external Dictionary (called by Player via GameManager.get_core_system("config"))


func configure(cfg: Dictionary) -> void:
	_apply_config(cfg)
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger:
			logger.info(
				"[RocketJumpSystem] Configured from GameManager.get_core_system('config')", "Player"
			)
