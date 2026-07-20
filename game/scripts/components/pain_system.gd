class_name PainSystem
extends Node

signal pain_triggered(damage_amount: float, source: Node3D)
signal pain_ended

@export_group("Pain Settings")
@export var pain_chance: float = 0.8
@export var pain_threshold: float = 5.0
@export var pain_duration: float = 0.2
@export var pain_cooldown: float = 0.4
@export_group("Boss Modifiers")
@export var is_boss: bool = false
@export var boss_pain_chance_multiplier: float = 0.3
@export var boss_cooldown_multiplier: float = 3.0
@export_group("Knockback Settings")
@export var knockback_multiplier: float = 0.15
@export var min_knockback: float = 2.0
@export var max_knockback: float = 15.0
@export var knockback_upward_force: float = 0.3

var pain_cooldown_timer: float = 0.0
var pain_duration_timer: float = 0.0
var is_in_pain: bool = false
var effective_pain_chance: float
var effective_cooldown: float
var effective_knockback_multiplier: float


func _ready() -> void:
	set_process(false)  # Only process when timers are active
	_calculate_effective_values()


func _process(delta: float) -> void:
	var timers_active: bool = false

	# Count down cooldown
	if pain_cooldown_timer > 0.0:
		pain_cooldown_timer -= delta
		timers_active = true

	# Count down pain duration
	if is_in_pain:
		pain_duration_timer -= delta
		timers_active = true
		if pain_duration_timer <= 0.0:
			_exit_pain_state()

	# Disable processing when no timers are active
	if not timers_active:
		set_process(false)


func _calculate_effective_values() -> void:
	if is_boss:
		effective_pain_chance = pain_chance * boss_pain_chance_multiplier
		effective_cooldown = pain_cooldown * boss_cooldown_multiplier
		effective_knockback_multiplier = 0.3  # 30% knockback for bosses
	else:
		effective_pain_chance = pain_chance
		effective_cooldown = pain_cooldown
		effective_knockback_multiplier = 1.0


func can_enter_pain() -> bool:
	return pain_cooldown_timer <= 0.0 and not is_in_pain


func should_trigger_pain(damage: float) -> bool:
	# Check damage threshold
	if damage < pain_threshold:
		return false

	# Check if on cooldown or already in pain
	if not can_enter_pain():
		return false

	# Random chance roll
	return randf() <= effective_pain_chance


func trigger_pain(damage: float, source: Node3D = null) -> void:
	if not should_trigger_pain(damage):
		return

	_enter_pain_state(damage, source)


func force_trigger_pain(damage: float, source: Node3D = null) -> void:
	## Force pain state regardless of threshold/chance (for special attacks)
	if can_enter_pain():
		_enter_pain_state(damage, source)


func _enter_pain_state(damage: float, source: Node3D) -> void:
	is_in_pain = true
	pain_duration_timer = pain_duration
	pain_cooldown_timer = effective_cooldown
	set_process(true)  # Enable processing for timer updates

	pain_triggered.emit(damage, source)

	# Sync to clients if in multiplayer
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var parent_path: NodePath = get_parent().get_path() if get_parent() else NodePath()
		_sync_pain_state.rpc(true, parent_path)


@rpc("authority", "call_remote", "unreliable")
func _sync_pain_state(in_pain: bool, _entity_path: NodePath) -> void:
	## RPC: Sync pain state to clients for visual feedback
	is_in_pain = in_pain
	if in_pain:
		pain_duration_timer = pain_duration


func _exit_pain_state() -> void:
	is_in_pain = false
	pain_ended.emit()

	# Sync to clients if in multiplayer
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var parent_path: NodePath = get_parent().get_path() if get_parent() else NodePath()
		_sync_pain_state.rpc(false, parent_path)


func is_pain_active() -> bool:
	return is_in_pain


func is_on_cooldown() -> bool:
	return pain_cooldown_timer > 0.0


func get_pain_progress() -> float:
	## Returns 0.0 to 1.0 progress through pain state
	if not is_in_pain:
		return 0.0
	return 1.0 - (pain_duration_timer / pain_duration)


func get_cooldown_remaining() -> float:
	return pain_cooldown_timer


func set_boss_mode(enabled: bool) -> void:
	is_boss = enabled
	_calculate_effective_values()


func set_elite_mode(enabled: bool) -> void:
	## Elite enemies have reduced pain/knockback
	if enabled:
		effective_pain_chance = pain_chance * 0.6
		effective_cooldown = pain_cooldown * 1.5
		effective_knockback_multiplier = 0.6  # 60% knockback
	else:
		_calculate_effective_values()


func calculate_knockback_force(damage: float) -> float:
	## Calculate knockback force based on damage dealt
	var force := damage * knockback_multiplier
	force = clamp(force, min_knockback, max_knockback)
	force *= effective_knockback_multiplier
	return force


func calculate_knockback_velocity(
	damage: float, target_pos: Vector3, source_pos: Vector3
) -> Vector3:
	## Calculate full knockback velocity vector
	var direction := (target_pos - source_pos).normalized()
	var force := calculate_knockback_force(damage)
	direction.y = 0.0  # Keep horizontal only
	if direction.length() < 0.1:
		direction = Vector3.BACK  # Default direction
	direction = direction.normalized()

	return Vector3(direction.x * force, force * knockback_upward_force, direction.z * force)


func get_knockback_multiplier() -> float:
	return effective_knockback_multiplier


func get_pain_info() -> Dictionary:
	## Debug information
	return {
		"is_in_pain": is_in_pain,
		"pain_cooldown_timer": pain_cooldown_timer,
		"pain_duration_timer": pain_duration_timer,
		"pain_chance": effective_pain_chance,
		"pain_threshold": pain_threshold,
		"pain_duration": pain_duration,
		"pain_cooldown": effective_cooldown,
		"knockback_mult": effective_knockback_multiplier
	}


func configure_from_data(data: Dictionary) -> void:
	## Configure from enemy JSON data
	if "pain_chance" in data:
		pain_chance = data.pain_chance
	if "pain_threshold" in data:
		pain_threshold = data.pain_threshold
	if "pain_duration" in data:
		pain_duration = data.pain_duration
	if "pain_cooldown" in data:
		pain_cooldown = data.pain_cooldown
	if "knockback_multiplier" in data:
		knockback_multiplier = data.knockback_multiplier
	if "is_boss" in data:
		is_boss = data.is_boss

	_calculate_effective_values()
