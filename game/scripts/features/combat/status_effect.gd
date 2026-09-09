class_name StatusEffect
extends Resource

enum EffectType {POISON, BURN, SLOW, STUN, FREEZE, BLEED, DROWNING, CUSTOM, SPEED_BUFF, DAMAGE_BUFF}

@export var effect_type: EffectType = EffectType.POISON
@export var effect_name: String = "Poison"
@export var duration: float = 5.0
@export var tick_interval: float = 1.0
@export var damage_per_tick: float = 5.0
@export var movement_speed_modifier: float = 1.0
@export var outgoing_damage_modifier: float = 1.0
@export var can_act: bool = true
@export var stacks: bool = false
@export var max_stacks: int = 1
@export var effect_color: Color = Color.GREEN
@export var particle_effect: PackedScene = null

var remaining_duration: float = 0.0
var time_since_last_tick: float = 0.0
var current_stacks: int = 1
var source_id: int = -1  # Multiplayer: Track source by peer ID


func _init() -> void:
	remaining_duration = duration


func apply_to_target(target: Node3D, from_source_id: int = -1) -> void:
	# SECURITY FIX: Validate target before accessing
	if not is_instance_valid(target):
		push_error("[StatusEffect] Invalid target")
		return

	remaining_duration = duration
	time_since_last_tick = 0.0
	source_id = from_source_id


func update(delta: float, target: Node3D) -> bool:
	# SECURITY FIX: Validate target is still valid
	if not is_instance_valid(target):
		return false

	remaining_duration -= delta
	time_since_last_tick += delta

	# Process tick damage
	if time_since_last_tick >= tick_interval and tick_interval > 0:
		time_since_last_tick = 0.0
		_process_tick(target)

	return remaining_duration > 0.0


func _process_tick(target: Node3D) -> void:
	# SECURITY FIX: Validate target is still valid
	if not is_instance_valid(target) or damage_per_tick <= 0.0:
		return

	# Player node ownership does not confer damage authority.
	if target.multiplayer.has_multiplayer_peer() and not target.multiplayer.is_server():
		return

	var damage_info := DamageInfo.new()
	damage_info.base_amount = damage_per_tick * current_stacks
	damage_info.damage_type = _get_damage_type()
	damage_info.source_id = source_id

	if target.has_method("take_damage"):
		target.take_damage(damage_info)
	else:
		var health_component: Node = target.get_node_or_null("HealthComponent")
		if health_component and health_component.has_method("take_damage"):
			health_component.take_damage(damage_info)


func _get_damage_type() -> DamageInfo.DamageType:
	match effect_type:
		EffectType.POISON:
			return DamageInfo.DamageType.POISON
		EffectType.BURN:
			return DamageInfo.DamageType.FIRE
		EffectType.BLEED:
			return DamageInfo.DamageType.BLEED
		_:
			return DamageInfo.DamageType.GENERIC


func add_stack() -> void:
	if stacks and current_stacks < max_stacks:
		current_stacks += 1
		remaining_duration = duration


func get_remaining_time() -> float:
	return remaining_duration


func get_stack_count() -> int:
	return current_stacks


func create_copy() -> StatusEffect:
	var copy := StatusEffect.new()
	copy.effect_type = effect_type
	copy.effect_name = effect_name
	copy.duration = duration
	copy.tick_interval = tick_interval
	copy.damage_per_tick = damage_per_tick
	copy.movement_speed_modifier = movement_speed_modifier
	copy.outgoing_damage_modifier = outgoing_damage_modifier
	copy.can_act = can_act
	copy.stacks = stacks
	copy.max_stacks = max_stacks
	copy.effect_color = effect_color
	copy.particle_effect = particle_effect
	copy.source_id = source_id
	return copy


func to_dict() -> Dictionary:
	return {
		"type": effect_type,
		"name": effect_name,
		"duration": duration,
		"remaining": remaining_duration,
		"tick_interval": tick_interval,
		"damage": damage_per_tick,
		"speed_mod": movement_speed_modifier,
		"damage_mod": outgoing_damage_modifier,
		"can_act": can_act,
		"stacks": current_stacks,
		"source_id": source_id
	}


static func from_dict(data: Dictionary) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type = data.get("type", EffectType.POISON)
	effect.effect_name = data.get("name", "Effect")
	effect.duration = data.get("duration", 5.0)
	effect.remaining_duration = data.get("remaining", effect.duration)
	effect.tick_interval = data.get("tick_interval", 1.0)
	effect.damage_per_tick = data.get("damage", 0.0)
	effect.movement_speed_modifier = data.get("speed_mod", 1.0)
	effect.outgoing_damage_modifier = data.get("damage_mod", 1.0)
	effect.can_act = data.get("can_act", true)
	effect.current_stacks = data.get("stacks", 1)
	effect.source_id = data.get("source_id", -1)
	return effect


# ============================================================================
# Factory Methods
# ============================================================================


static func create_poison(
	duration_sec: float = 5.0, damage: float = 5.0, from_source_id: int = -1
) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type = EffectType.POISON
	effect.effect_name = "Poison"
	effect.duration = duration_sec
	effect.tick_interval = 1.0
	effect.damage_per_tick = damage
	effect.effect_color = Color.GREEN
	effect.source_id = from_source_id
	return effect


static func create_burn(
	duration_sec: float = 3.0, damage: float = 8.0, from_source_id: int = -1
) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type = EffectType.BURN
	effect.effect_name = "Burning"
	effect.duration = duration_sec
	effect.tick_interval = 0.5
	effect.damage_per_tick = damage
	effect.effect_color = Color.ORANGE_RED
	effect.source_id = from_source_id
	effect.stacks = true
	effect.max_stacks = 3
	return effect


static func create_slow(
	duration_sec: float = 4.0, slow_amount: float = 0.5, from_source_id: int = -1
) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type = EffectType.SLOW
	effect.effect_name = "Slowed"
	effect.duration = duration_sec
	effect.tick_interval = 0.0
	effect.damage_per_tick = 0.0
	effect.movement_speed_modifier = slow_amount
	effect.effect_color = Color.CYAN
	effect.source_id = from_source_id
	return effect


static func create_stun(duration_sec: float = 2.0, from_source_id: int = -1) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type = EffectType.STUN
	effect.effect_name = "Stunned"
	effect.duration = duration_sec
	effect.tick_interval = 0.0
	effect.damage_per_tick = 0.0
	effect.can_act = false
	effect.movement_speed_modifier = 0.0
	effect.effect_color = Color.YELLOW
	effect.source_id = from_source_id
	return effect


static func create_bleed(
	duration_sec: float = 6.0, damage: float = 3.0, from_source_id: int = -1
) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type = EffectType.BLEED
	effect.effect_name = "Bleeding"
	effect.duration = duration_sec
	effect.tick_interval = 0.5
	effect.damage_per_tick = damage
	effect.effect_color = Color.DARK_RED
	effect.source_id = from_source_id
	effect.stacks = true
	effect.max_stacks = 5
	return effect


static func create_freeze(duration_sec: float = 3.0, from_source_id: int = -1) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type = EffectType.FREEZE
	effect.effect_name = "Frozen"
	effect.duration = duration_sec
	effect.tick_interval = 0.0
	effect.damage_per_tick = 0.0
	effect.can_act = false
	effect.movement_speed_modifier = 0.0
	effect.effect_color = Color.LIGHT_BLUE
	effect.source_id = from_source_id
	return effect


static func create_drowning(
	duration_sec: float = 3.0, damage: float = 10.0, from_source_id: int = -1
) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.effect_type = EffectType.DROWNING
	effect.effect_name = "Drowning"
	effect.duration = duration_sec
	effect.tick_interval = 1.0
	effect.damage_per_tick = damage
	effect.effect_color = Color(0.0, 0.2, 0.8)
	effect.source_id = from_source_id
	return effect
