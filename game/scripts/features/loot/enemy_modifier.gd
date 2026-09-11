class_name EnemyModifier
extends Resource

## Just stats (Extra Strong, Tank)
## Adds damage type / effect (Fire Enchanted)
## Behavior change (Extra Fast)
enum ModifierType { STAT_BOOST, ELEMENTAL, UTILITY }

@export var modifier_name: String = "Elite"
@export var prefix: String = "Elite"  ## Name prefix e.g. "Burning" Zombie
@export var color: Color = Color.RED
@export var type: ModifierType = ModifierType.STAT_BOOST
@export_group("Stat Multipliers")
@export var health_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var speed_mult: float = 1.0
@export var scale_mult: float = 1.0
@export var xp_mult: float = 1.0
@export_group("Effects")
@export var on_hit_effect: StatusEffect = null
@export var visual_effect: PackedScene = null


func apply_to(enemy: Node3D) -> void:
	# Apply stats
	if enemy.has_method("apply_stat_multiplier"):
		enemy.apply_stat_multiplier("health", health_mult)
		enemy.apply_stat_multiplier("damage", damage_mult)
		enemy.apply_stat_multiplier("speed", speed_mult)
		enemy.apply_stat_multiplier("scale", scale_mult)

	# There is no enemy on-hit dispatch hook yet. Do not silently advertise
	# an effect that can never reach a victim.
	if on_hit_effect:
		push_error(
			"[EnemyModifier] On-hit effect '%s' is unsupported for enemy modifiers; effect disabled"
			% on_hit_effect.effect_name
		)

	# Apply visuals
	if visual_effect:
		var vfx: Node3D = visual_effect.instantiate()
		enemy.add_child(vfx)
	# Apply name prefix (if label exists)
	# (Logic to be handled by enemy wrapper)


# Factory methods for common affixes


static func create_frenzied() -> EnemyModifier:
	var m: EnemyModifier = EnemyModifier.new()
	m.modifier_name = "Frenzied"
	m.prefix = "Frenzied"
	m.color = Color.ORANGE_RED
	m.type = ModifierType.STAT_BOOST
	m.damage_mult = 1.5
	m.speed_mult = 1.5
	m.health_mult = 0.8  # Glass cannon
	return m


static func create_tank() -> EnemyModifier:
	var m: EnemyModifier = EnemyModifier.new()
	m.modifier_name = "Tank"
	m.prefix = "Armored"
	m.color = Color.SLATE_GRAY
	m.type = ModifierType.STAT_BOOST
	m.health_mult = 2.5
	m.scale_mult = 1.2
	m.speed_mult = 0.7
	return m


static func create_ghostly() -> EnemyModifier:
	push_error(
		"[EnemyModifier] Ghostly is disabled: no safe enemy transparency/phase hook exists"
	)
	return null


## Elemental Affixes - Apply status effects on hit


static func create_burning() -> EnemyModifier:
	var m: EnemyModifier = EnemyModifier.new()
	m.modifier_name = "Burning"
	m.prefix = "Burning"
	m.color = Color.ORANGE
	m.type = ModifierType.ELEMENTAL
	m.damage_mult = 1.2
	# Create burn effect for on_hit
	var burn: StatusEffect = StatusEffect.new()
	burn.effect_name = "Burn"
	burn.effect_type = StatusEffect.EffectType.BURN
	burn.duration = 3.0
	burn.damage_per_tick = 5.0
	burn.tick_interval = 0.5
	m.on_hit_effect = burn
	return m


static func create_freezing() -> EnemyModifier:
	var m: EnemyModifier = EnemyModifier.new()
	m.modifier_name = "Freezing"
	m.prefix = "Freezing"
	m.color = Color.LIGHT_BLUE
	m.type = ModifierType.ELEMENTAL
	# Create freeze/slow effect for on_hit
	var freeze: StatusEffect = StatusEffect.new()
	freeze.effect_name = "Freeze"
	freeze.effect_type = StatusEffect.EffectType.FREEZE
	freeze.duration = 2.0
	freeze.slow_percent = 0.5
	m.on_hit_effect = freeze
	return m


static func create_poisonous() -> EnemyModifier:
	var m: EnemyModifier = EnemyModifier.new()
	m.modifier_name = "Poisonous"
	m.prefix = "Poisonous"
	m.color = Color.LIME_GREEN
	m.type = ModifierType.ELEMENTAL
	# Create poison DoT effect for on_hit
	var poison: StatusEffect = StatusEffect.new()
	poison.effect_name = "Poison"
	poison.effect_type = StatusEffect.EffectType.POISON
	poison.duration = 5.0
	poison.damage_per_tick = 3.0
	poison.tick_interval = 1.0
	poison.stacks = true
	poison.max_stacks = 5
	m.on_hit_effect = poison
	return m


static func create_electrified() -> EnemyModifier:
	push_error(
		"[EnemyModifier] Electrified is disabled: no safe chain-damage hook exists"
	)
	return null


static func create_vampiric() -> EnemyModifier:
	push_error(
		"[EnemyModifier] Vampiric is disabled: no safe damage-dealt/lifesteal hook exists"
	)
	return null


## Get a random supported modifier for elite enemies.
static func get_random_modifier() -> EnemyModifier:
	var options: Array[Callable] = [
		create_frenzied,
		create_tank,
		create_burning,
		create_freezing,
		create_poisonous
	]
	return options[randi() % options.size()].call()
