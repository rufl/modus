class_name WeaponAffix
extends Resource

enum AffixType { PREFIX, SUFFIX }  # Goes before weapon name  # Goes after weapon name ("of X")
enum StatBoost {
	DAMAGE, FIRE_RATE, MAGAZINE_SIZE, RELOAD_SPEED, ACCURACY, CHAIN, SPLASH, CRIT, LIFESTEAL
}

@export var affix_name: String = ""
@export var display_text: String = ""  # e.g., "Rapid" or "of Destruction"
@export var affix_type: AffixType = AffixType.PREFIX
@export var rarity_weight: float = 100.0  # Lower = rarer
@export var power_cost: float = 0.0  # Power budget cost (positive = consumes, negative = refunds)
@export_group("Stat Modifiers")
@export var damage_mult: float = 1.0
@export var fire_rate_mult: float = 1.0  # Higher = faster
@export var magazine_mult: float = 1.0  # Bigger mag
@export var reload_speed_mult: float = 1.0  # Higher = faster reload
@export var accuracy_mult: float = 1.0  # Higher = less spread
@export_group("Advanced Stats")
@export var chain_count: int = 0  # Number of enemies the hit can chain to
@export var chain_damage_falloff: float = 0.7  # Damage multiplier per chain
@export var splash_radius: float = 0.0  # AoE damage radius on hit
@export var splash_damage_mult: float = 0.5  # Splash damage as % of main damage
@export var extra_pellets: int = 0  # Additional projectiles/pellets
@export var crit_chance: float = 0.0  # 0.0 to 1.0 critical hit chance
@export var crit_mult: float = 2.0  # Critical damage multiplier
@export var lifesteal_percent: float = 0.0  # Health restored as % of damage dealt
@export var piercing_count: int = 0  # Number of enemies to pierce through
@export_group("Status Effect on Hit")
@export var on_hit_effect_type: int = -1
@export var effect_duration: float = 5.0
@export var effect_damage_per_tick: float = 5.0
@export var effect_tick_interval: float = 1.0
@export var effect_apply_chance: float = 1.0  # 0.0 to 1.0
@export_group("Visual")
@export var color: Color = Color.WHITE


func apply_to_weapon(weapon_data: WeaponData) -> void:
	weapon_data.damage = int(weapon_data.damage * damage_mult)
	weapon_data.fire_rate *= fire_rate_mult
	weapon_data.magazine_size = int(weapon_data.magazine_size * magazine_mult)
	# Note: reload_speed in WeaponData might need inverse application
	# accuracy would need to be added to WeaponData


## Check if this affix has an on-hit status effect


func has_on_hit_effect() -> bool:
	return on_hit_effect_type >= 0


## Create the status effect for this affix (call after roll check)


func create_on_hit_effect(source_id: int = -1) -> StatusEffect:
	if not has_on_hit_effect():
		return null

	var effect := StatusEffect.new()
	effect.effect_type = on_hit_effect_type as StatusEffect.EffectType
	effect.duration = effect_duration
	effect.remaining_duration = effect_duration
	effect.tick_interval = effect_tick_interval
	effect.damage_per_tick = effect_damage_per_tick
	effect.effect_color = color
	effect.source_id = source_id

	# Set effect name based on type
	match effect.effect_type:
		StatusEffect.EffectType.POISON:
			effect.effect_name = "Poison"
		StatusEffect.EffectType.BURN:
			effect.effect_name = "Burning"
		StatusEffect.EffectType.BLEED:
			effect.effect_name = "Bleeding"
		StatusEffect.EffectType.FREEZE:
			effect.effect_name = "Frozen"
			effect.movement_speed_modifier = 0.5  # Slowed
		_:
			effect.effect_name = affix_name

	return effect


## Roll for effect application (returns true if effect should apply)


func roll_for_effect() -> bool:
	return randf() <= effect_apply_chance


# ============================================================================
# Factory Methods - Common Affixes
# ============================================================================

## Prefixes


static func create_rapid() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "rapid"
	a.display_text = "Rapid"
	a.affix_type = AffixType.PREFIX
	a.fire_rate_mult = 1.5
	a.damage_mult = 0.85
	a.color = Color.YELLOW
	a.rarity_weight = 80.0
	a.power_cost = 15.0
	return a


static func create_heavy() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "heavy"
	a.display_text = "Heavy"
	a.affix_type = AffixType.PREFIX
	a.damage_mult = 1.4
	a.fire_rate_mult = 0.75
	a.color = Color.ORANGE_RED
	a.rarity_weight = 70.0
	a.power_cost = 20.0
	return a


static func create_tactical() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "tactical"
	a.display_text = "Tactical"
	a.affix_type = AffixType.PREFIX
	a.reload_speed_mult = 1.5
	a.accuracy_mult = 1.3
	a.color = Color.SLATE_GRAY
	a.rarity_weight = 90.0
	a.power_cost = 10.0
	return a


static func create_extended() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "extended"
	a.display_text = "Extended"
	a.affix_type = AffixType.PREFIX
	a.magazine_mult = 1.5
	a.reload_speed_mult = 0.8
	a.color = Color.FOREST_GREEN
	a.rarity_weight = 100.0
	a.power_cost = 5.0
	return a


static func create_deadly() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "deadly"
	a.display_text = "Deadly"
	a.affix_type = AffixType.PREFIX
	a.crit_chance = 0.25
	a.crit_mult = 2.5
	a.color = Color.CRIMSON
	a.rarity_weight = 45.0
	a.power_cost = 30.0
	return a


static func create_vampiric() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "vampiric"
	a.display_text = "Vampiric"
	a.affix_type = AffixType.PREFIX
	a.lifesteal_percent = 0.15
	a.damage_mult = 0.9
	a.color = Color.DARK_MAGENTA
	a.rarity_weight = 30.0
	a.power_cost = 35.0
	return a


static func create_piercing() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "piercing"
	a.display_text = "Piercing"
	a.affix_type = AffixType.PREFIX
	a.piercing_count = 2
	a.damage_mult = 0.85
	a.color = Color.STEEL_BLUE
	a.rarity_weight = 40.0
	a.power_cost = 25.0
	return a


static func create_multishot() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "multishot"
	a.display_text = "Multi-Shot"
	a.affix_type = AffixType.PREFIX
	a.extra_pellets = 2
	a.damage_mult = 0.7
	a.accuracy_mult = 0.8
	a.color = Color.GOLD
	a.rarity_weight = 35.0
	a.power_cost = 40.0
	return a


static func create_incendiary() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "incendiary"
	a.display_text = "Incendiary"
	a.affix_type = AffixType.PREFIX
	a.splash_radius = 1.5
	a.splash_damage_mult = 0.3
	a.damage_mult = 0.9
	a.color = Color.ORANGE
	a.rarity_weight = 40.0
	a.power_cost = 30.0
	return a


static func create_shocking() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "shocking"
	a.display_text = "Shocking"
	a.affix_type = AffixType.PREFIX
	a.chain_count = 2
	a.chain_damage_falloff = 0.6
	a.color = Color.DEEP_SKY_BLUE
	a.rarity_weight = 30.0
	a.power_cost = 40.0
	return a


static func create_cursed() -> WeaponAffix:
	## Cursed weapons deal more damage but have downsides - returns power budget
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "cursed"
	a.display_text = "Cursed"
	a.affix_type = AffixType.PREFIX
	a.damage_mult = 1.6
	a.reload_speed_mult = 0.6
	a.magazine_mult = 0.6
	a.color = Color.PURPLE
	a.rarity_weight = 25.0
	a.power_cost = -10.0  # Refunds budget due to downsides
	return a


static func create_lightweight() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "lightweight"
	a.display_text = "Lightweight"
	a.affix_type = AffixType.PREFIX
	a.reload_speed_mult = 1.8
	a.fire_rate_mult = 1.2
	a.damage_mult = 0.75
	a.color = Color.AQUA
	a.rarity_weight = 60.0
	a.power_cost = 15.0
	return a


static func create_unstable() -> WeaponAffix:
	## High risk/reward - explosive splash but inaccurate
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "unstable"
	a.display_text = "Unstable"
	a.affix_type = AffixType.PREFIX
	a.splash_radius = 2.5
	a.splash_damage_mult = 0.5
	a.accuracy_mult = 0.5
	a.color = Color.HOT_PINK
	a.rarity_weight = 25.0
	a.power_cost = 25.0
	return a


## Suffixes


static func create_of_destruction() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "destruction"
	a.display_text = "of Destruction"
	a.affix_type = AffixType.SUFFIX
	a.damage_mult = 1.5
	a.magazine_mult = 0.7
	a.color = Color.RED
	a.rarity_weight = 40.0
	a.power_cost = 25.0
	return a


static func create_of_precision() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "precision"
	a.display_text = "of Precision"
	a.affix_type = AffixType.SUFFIX
	a.accuracy_mult = 2.0
	a.damage_mult = 1.1
	a.color = Color.CYAN
	a.rarity_weight = 50.0
	return a


static func create_of_haste() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "haste"
	a.display_text = "of Haste"
	a.affix_type = AffixType.SUFFIX
	a.fire_rate_mult = 1.3
	a.reload_speed_mult = 1.3
	a.color = Color.LIME_GREEN
	a.rarity_weight = 60.0
	return a


## Elemental Suffixes (apply status effects on hit)


static func create_of_burning() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "burning"
	a.display_text = "of Burning"
	a.affix_type = AffixType.SUFFIX
	a.on_hit_effect_type = StatusEffect.EffectType.BURN
	a.effect_duration = 3.0
	a.effect_damage_per_tick = 8.0
	a.effect_tick_interval = 0.5
	a.effect_apply_chance = 0.4  # 40% chance
	a.color = Color.ORANGE
	a.rarity_weight = 35.0  # Rare
	return a


static func create_of_venom() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "venom"
	a.display_text = "of Venom"
	a.affix_type = AffixType.SUFFIX
	a.on_hit_effect_type = StatusEffect.EffectType.POISON
	a.effect_duration = 5.0
	a.effect_damage_per_tick = 5.0
	a.effect_tick_interval = 1.0
	a.effect_apply_chance = 0.5  # 50% chance
	a.color = Color.LIME_GREEN
	a.rarity_weight = 45.0
	return a


static func create_of_bleeding() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "bleeding"
	a.display_text = "of Bleeding"
	a.affix_type = AffixType.SUFFIX
	a.on_hit_effect_type = StatusEffect.EffectType.BLEED
	a.effect_duration = 6.0
	a.effect_damage_per_tick = 3.0
	a.effect_tick_interval = 0.5
	a.effect_apply_chance = 0.35  # 35% chance
	a.color = Color.DARK_RED
	a.rarity_weight = 40.0
	return a


static func create_of_frost() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "frost"
	a.display_text = "of Frost"
	a.affix_type = AffixType.SUFFIX
	a.on_hit_effect_type = StatusEffect.EffectType.FREEZE
	a.effect_duration = 4.0
	a.effect_damage_per_tick = 2.0
	a.effect_tick_interval = 1.0
	a.effect_apply_chance = 0.3
	a.color = Color.LIGHT_BLUE
	a.rarity_weight = 30.0
	a.power_cost = 35.0
	return a


static func create_of_annihilation() -> WeaponAffix:
	## Top-tier damage suffix
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "annihilation"
	a.display_text = "of Annihilation"
	a.affix_type = AffixType.SUFFIX
	a.damage_mult = 1.8
	a.crit_chance = 0.15
	a.crit_mult = 3.0
	a.fire_rate_mult = 0.8
	a.color = Color.DARK_VIOLET
	a.rarity_weight = 15.0  # Very rare
	a.power_cost = 50.0
	return a


static func create_of_storms() -> WeaponAffix:
	## Chain lightning effect
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "storms"
	a.display_text = "of Storms"
	a.affix_type = AffixType.SUFFIX
	a.chain_count = 3
	a.chain_damage_falloff = 0.5
	a.color = Color.DODGER_BLUE
	a.rarity_weight = 20.0
	a.power_cost = 45.0
	return a


static func create_of_the_vampire() -> WeaponAffix:
	## Strong lifesteal suffix
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "vampire"
	a.display_text = "of the Vampire"
	a.affix_type = AffixType.SUFFIX
	a.lifesteal_percent = 0.25
	a.color = Color.DARK_RED
	a.rarity_weight = 20.0
	a.power_cost = 40.0
	return a


static func create_of_explosions() -> WeaponAffix:
	## AoE splash damage on hit
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "explosions"
	a.display_text = "of Explosions"
	a.affix_type = AffixType.SUFFIX
	a.splash_radius = 3.0
	a.splash_damage_mult = 0.4
	a.color = Color.ORANGE_RED
	a.rarity_weight = 25.0
	a.power_cost = 35.0
	return a


static func create_of_swiftness() -> WeaponAffix:
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "swiftness"
	a.display_text = "of Swiftness"
	a.affix_type = AffixType.SUFFIX
	a.fire_rate_mult = 1.6
	a.reload_speed_mult = 1.4
	a.damage_mult = 0.75
	a.color = Color.SPRING_GREEN
	a.rarity_weight = 50.0
	a.power_cost = 20.0
	return a


static func create_of_the_marksman() -> WeaponAffix:
	## Accuracy + crit focused
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "marksman"
	a.display_text = "of the Marksman"
	a.affix_type = AffixType.SUFFIX
	a.accuracy_mult = 2.5
	a.crit_chance = 0.2
	a.crit_mult = 2.5
	a.color = Color.MEDIUM_AQUAMARINE
	a.rarity_weight = 30.0
	a.power_cost = 35.0
	return a


static func create_of_chaos() -> WeaponAffix:
	## Multi-shot + chain hybrid
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "chaos"
	a.display_text = "of Chaos"
	a.affix_type = AffixType.SUFFIX
	a.extra_pellets = 1
	a.chain_count = 1
	a.chain_damage_falloff = 0.7
	a.damage_mult = 0.8
	a.color = Color.MAGENTA
	a.rarity_weight = 20.0
	a.power_cost = 45.0
	return a


static func create_of_endurance() -> WeaponAffix:
	## Big magazine, sustain focus
	var a: WeaponAffix = WeaponAffix.new()
	a.affix_name = "endurance"
	a.display_text = "of Endurance"
	a.affix_type = AffixType.SUFFIX
	a.magazine_mult = 2.0
	a.lifesteal_percent = 0.05
	a.reload_speed_mult = 0.7
	a.color = Color.OLIVE_DRAB
	a.rarity_weight = 45.0
	a.power_cost = 20.0
	return a


static func get_all_prefixes() -> Array[WeaponAffix]:
	return [
		create_rapid(),
		create_heavy(),
		create_tactical(),
		create_extended(),
		create_deadly(),
		create_vampiric(),
		create_piercing(),
		create_multishot(),
		create_incendiary(),
		create_shocking(),
		create_cursed(),
		create_lightweight(),
		create_unstable()
	]


static func get_all_suffixes() -> Array[WeaponAffix]:
	return [
		create_of_destruction(),
		create_of_precision(),
		create_of_haste(),
		create_of_burning(),
		create_of_venom(),
		create_of_bleeding(),
		create_of_frost(),
		create_of_annihilation(),
		create_of_storms(),
		create_of_the_vampire(),
		create_of_explosions(),
		create_of_swiftness(),
		create_of_the_marksman(),
		create_of_chaos(),
		create_of_endurance()
	]


## Random affix selection


static func get_random_prefix() -> WeaponAffix:
	var prefixes: Array[WeaponAffix] = get_all_prefixes()
	return _weighted_select(prefixes)


static func get_random_suffix() -> WeaponAffix:
	var suffixes: Array[WeaponAffix] = get_all_suffixes()
	return _weighted_select(suffixes)


static func get_random_prefix_index() -> int:
	var prefixes: Array[WeaponAffix] = get_all_prefixes()
	var selected: WeaponAffix = _weighted_select(prefixes)
	# Find index of selected/matching affix
	for i in range(prefixes.size()):
		if prefixes[i].affix_name == selected.affix_name:
			return i
	return -1


static func get_random_suffix_index() -> int:
	var suffixes: Array[WeaponAffix] = get_all_suffixes()
	var selected: WeaponAffix = _weighted_select(suffixes)
	for i in range(suffixes.size()):
		if suffixes[i].affix_name == selected.affix_name:
			return i
	return -1


static func _weighted_select(affixes: Array) -> WeaponAffix:
	var total_weight: float = 0.0
	for a: WeaponAffix in affixes:
		total_weight += a.rarity_weight

	var roll: float = randf() * total_weight
	var current: float = 0.0
	for a: WeaponAffix in affixes:
		current += a.rarity_weight
		if roll <= current:
			return a

	return affixes[0]
