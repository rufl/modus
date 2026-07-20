class_name WeaponGenerator
extends Object

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const RARITY_POWER_BUDGET: Dictionary = {
	Rarity.COMMON: 1.0,
	Rarity.UNCOMMON: 2.0,
	Rarity.RARE: 3.5,
	Rarity.EPIC: 5.0,
	Rarity.LEGENDARY: 8.0,
}
const RARITY_STAT_VARIATION: Dictionary = {
	Rarity.COMMON: 0.1,
	Rarity.UNCOMMON: 0.15,
	Rarity.RARE: 0.2,
	Rarity.EPIC: 0.25,
	Rarity.LEGENDARY: 0.3,
}
const RARITY_AFFIX_CHANCES: Dictionary = {
	Rarity.COMMON: {"prefix": 0.0, "suffix": 0.0},
	Rarity.UNCOMMON: {"prefix": 0.3, "suffix": 0.0},
	Rarity.RARE: {"prefix": 0.6, "suffix": 0.3},
	Rarity.EPIC: {"prefix": 0.9, "suffix": 0.6},
	Rarity.LEGENDARY: {"prefix": 1.0, "suffix": 1.0},
}
const RARITY_COLORS: Dictionary = {
	Rarity.COMMON: Color(0.7, 0.7, 0.7),
	Rarity.UNCOMMON: Color(0.2, 0.8, 0.2),
	Rarity.RARE: Color(0.2, 0.4, 1.0),
	Rarity.EPIC: Color(0.6, 0.2, 0.8),
	Rarity.LEGENDARY: Color(1.0, 0.6, 0.0),
}
const RARITY_BEAM_HEIGHTS: Dictionary = {
	Rarity.COMMON: 1.5,
	Rarity.UNCOMMON: 2.0,
	Rarity.RARE: 2.5,
	Rarity.EPIC: 3.0,
	Rarity.LEGENDARY: 4.0,
}
const BASE_WEAPONS: Array[String] = ["Pistol", "Shotgun", "Machinegun", "Rocket Launcher"]


static func generate_weapon(
	min_rarity: Rarity = Rarity.COMMON, max_rarity: Rarity = Rarity.LEGENDARY
) -> Dictionary:
	var rarity: Rarity = _roll_rarity(min_rarity, max_rarity)
	var power_budget: float = RARITY_POWER_BUDGET[rarity]
	var base_weapon_index: int = randi() % BASE_WEAPONS.size()
	var base_weapon_name: String = BASE_WEAPONS[base_weapon_index]
	var prefix: WeaponAffix = null
	var suffix: WeaponAffix = null
	var prefix_index: int = -1
	var suffix_index: int = -1

	# Roll for affixes based on rarity
	var affix_chances: Dictionary = RARITY_AFFIX_CHANCES[rarity]

	# Try to get prefix
	if randf() < affix_chances["prefix"]:
		var result: Dictionary = _select_affix_within_budget(
			WeaponAffix.get_all_prefixes(), power_budget
		)
		if result["affix"]:
			prefix = result["affix"]
			prefix_index = result["index"]
			power_budget -= prefix.power_cost

	# Try to get suffix with remaining budget
	if randf() < affix_chances["suffix"]:
		var result: Dictionary = _select_affix_within_budget(
			WeaponAffix.get_all_suffixes(), power_budget
		)
		if result["affix"]:
			suffix = result["affix"]
			suffix_index = result["index"]
			power_budget -= suffix.power_cost

	# Build weapon name
	var name_parts: Array[String] = []
	if prefix:
		name_parts.append(prefix.display_text)
	name_parts.append(base_weapon_name)
	if suffix:
		name_parts.append(suffix.display_text)

	var full_name: String = " ".join(name_parts)

	# Determine color (use rarest affix color, or rarity color)
	var weapon_color: Color = RARITY_COLORS[rarity]
	if suffix:
		weapon_color = suffix.color
	elif prefix:
		weapon_color = prefix.color

	return {
		"weapon_type": base_weapon_index,
		"base_name": base_weapon_name,
		"full_name": full_name,
		"rarity": rarity,
		"rarity_name": _get_rarity_name(rarity),
		"prefix_index": prefix_index,
		"suffix_index": suffix_index,
		"prefix": prefix,
		"suffix": suffix,
		"color": weapon_color,
		"beam_height": RARITY_BEAM_HEIGHTS[rarity],
		"power_budget_used": RARITY_POWER_BUDGET[rarity] - power_budget
	}


## Generate weapon specifically for crate drops (common-rare)


static func generate_crate_weapon() -> Dictionary:
	return generate_weapon(Rarity.COMMON, Rarity.RARE)


## Generate weapon for military chest (rare-legendary)


static func generate_chest_weapon() -> Dictionary:
	return generate_weapon(Rarity.RARE, Rarity.LEGENDARY)


## Roll rarity within range using weighted distribution


static func _roll_rarity(min_rarity: Rarity, max_rarity: Rarity) -> Rarity:
	# Weighted toward lower rarities
	var weights: Array[float] = [50.0, 30.0, 15.0, 4.0, 1.0]  # Common to Legendary

	var valid_rarities: Array[Rarity] = []
	var valid_weights: Array[float] = []

	for i in range(min_rarity, max_rarity + 1):
		valid_rarities.append(i as Rarity)
		valid_weights.append(weights[i])

	var total: float = 0.0
	for w in valid_weights:
		total += w

	var roll: float = randf() * total
	var current: float = 0.0
	for i in range(valid_rarities.size()):
		current += valid_weights[i]
		if roll <= current:
			return valid_rarities[i]

	return valid_rarities[0]


## Select an affix that fits within the power budget


static func _select_affix_within_budget(affixes: Array, budget: float) -> Dictionary:
	var valid_affixes: Array[Dictionary] = []

	for i in range(affixes.size()):
		var affix: WeaponAffix = affixes[i]
		# Allow affixes within budget, or ones that refund budget (negative cost)
		if affix.power_cost <= budget or affix.power_cost < 0:
			valid_affixes.append({"affix": affix, "index": i, "weight": affix.rarity_weight})

	if valid_affixes.is_empty():
		return {"affix": null, "index": -1}

	# Weighted selection
	var total_weight: float = 0.0
	for entry in valid_affixes:
		total_weight += entry["weight"]

	var roll: float = randf() * total_weight
	var current: float = 0.0
	for entry in valid_affixes:
		current += entry["weight"]
		if roll <= current:
			return {"affix": entry["affix"], "index": entry["index"]}

	return valid_affixes[0]


## Get rarity name as string


static func _get_rarity_name(rarity: Rarity) -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
	return "Unknown"


## Calculate combined stats description for tooltip


static func get_stats_description(prefix: WeaponAffix, suffix: WeaponAffix) -> String:
	var stats: Array[String] = []

	if prefix:
		_add_affix_stats(prefix, stats)
	if suffix:
		_add_affix_stats(suffix, stats)

	if stats.is_empty():
		return "Standard issue"
	return "\n".join(stats)


static func _add_affix_stats(affix: WeaponAffix, stats: Array[String]) -> void:
	if affix.damage_mult != 1.0:
		var pct: int = int((affix.damage_mult - 1.0) * 100)
		stats.append("%+d%% Damage" % pct)
	if affix.fire_rate_mult != 1.0:
		var pct: int = int((affix.fire_rate_mult - 1.0) * 100)
		stats.append("%+d%% Fire Rate" % pct)
	if affix.magazine_mult != 1.0:
		var pct: int = int((affix.magazine_mult - 1.0) * 100)
		stats.append("%+d%% Magazine" % pct)
	if affix.reload_speed_mult != 1.0:
		var pct: int = int((affix.reload_speed_mult - 1.0) * 100)
		stats.append("%+d%% Reload Speed" % pct)
	if affix.accuracy_mult != 1.0:
		var pct: int = int((affix.accuracy_mult - 1.0) * 100)
		stats.append("%+d%% Accuracy" % pct)
	if affix.crit_chance > 0:
		stats.append("+%d%% Crit Chance" % int(affix.crit_chance * 100))
	if affix.crit_mult > 2.0:
		stats.append("%.1fx Crit Damage" % affix.crit_mult)
	if affix.chain_count > 0:
		stats.append("Chain %d enemies" % affix.chain_count)
	if affix.splash_radius > 0:
		stats.append("%.1fm Splash Radius" % affix.splash_radius)
	if affix.extra_pellets > 0:
		stats.append("+%d Pellets" % affix.extra_pellets)
	if affix.lifesteal_percent > 0:
		stats.append("+%d%% Lifesteal" % int(affix.lifesteal_percent * 100))
	if affix.piercing_count > 0:
		stats.append("Pierce %d enemies" % affix.piercing_count)
	if affix.has_on_hit_effect():
		var chance_pct: int = int(affix.effect_apply_chance * 100)
		stats.append("%d%% chance: %s" % [chance_pct, affix.affix_name.capitalize()])
