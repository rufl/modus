class_name EnemyBloodTrail
extends Node

## Spawns blood trail when enemy is hurt or fleeing
## Uses blood pool shader system for retro pixelated style

const LOW_HEALTH_THRESHOLD: float = 0.5  # Below 50% health starts bleeding
const FLEE_HEALTH_THRESHOLD: float = 0.3  # Below 30% health flees and bleeds more
const DRIP_INTERVAL_NORMAL: float = 0.5  # Normal bleeding interval
const DRIP_INTERVAL_FLEEING: float = 0.2  # Faster bleeding when fleeing
const MIN_MOVEMENT_SPEED: float = 0.5  # Minimum speed to leave trail

var _enemy: Enemy
var _drip_timer: float = 0.0
var _next_drip_time: float = 0.5
var _is_bleeding: bool = false
var _is_fleeing: bool = false
var _last_blood_position: Vector3 = Vector3.ZERO


func setup(enemy: Enemy) -> void:
	_enemy = enemy
	_last_blood_position = _enemy.global_position
	_next_drip_time = DRIP_INTERVAL_NORMAL


func _physics_process(delta: float) -> void:
	if not _enemy or _enemy.is_dead:
		return

	# Check health status
	var health_ratio: float = _enemy.health / _enemy.max_health
	_is_bleeding = health_ratio < LOW_HEALTH_THRESHOLD and health_ratio > 0
	_is_fleeing = health_ratio < FLEE_HEALTH_THRESHOLD

	if not _is_bleeding:
		return

	# Check if enemy is moving
	var speed: float = _enemy.velocity.length()
	if speed < MIN_MOVEMENT_SPEED:
		return

	# Adjust drip rate based on state
	var target_interval: float = DRIP_INTERVAL_FLEEING if _is_fleeing else DRIP_INTERVAL_NORMAL

	# More bleeding at lower health
	var urgency: float = 1.0 - (health_ratio / LOW_HEALTH_THRESHOLD)
	target_interval *= (1.0 - urgency * 0.5)

	_drip_timer += delta
	if _drip_timer >= _next_drip_time:
		_drip_timer = 0.0
		_next_drip_time = target_interval
		_spawn_blood_drop()


func _spawn_blood_drop() -> void:
	# Use blood pool system
	var gm: Node = get_node_or_null("/root/GameManager")
	var blood_effects: Node = gm.get_core_system("blood_effects") if gm else null
	if not blood_effects or not blood_effects.is_available():
		return

	var drop_position: Vector3 = _enemy.global_position

	# Add slight randomness
	drop_position.x += randf_range(-0.2, 0.2)
	drop_position.z += randf_range(-0.2, 0.2)

	# Check distance from last drop
	if drop_position.distance_to(_last_blood_position) < 0.3:
		return

	# Spawn blood drop
	blood_effects.spawn_blood(drop_position)
	_last_blood_position = drop_position


## Check if enemy is currently fleeing
func is_fleeing() -> bool:
	if not _enemy or not _enemy.ai_controller:
		return false

	# Check if in flee state
	if _enemy.ai_controller.has_method("get_current_state_name"):
		var state_name: String = _enemy.ai_controller.get_current_state_name()
		return state_name == "Flee" or state_name == "flee"

	return _is_fleeing
