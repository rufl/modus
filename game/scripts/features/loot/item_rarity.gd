class_name ItemRarity
extends Resource

enum Tier { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, UNIQUE }

@export var tier: Tier = Tier.COMMON
@export var display_name: String = "Common"
@export var color: Color = Color.WHITE
@export var value_multiplier: float = 1.0
@export var stat_multiplier: float = 1.0  ## Modifier for enemy stats/weapon damage
@export var drop_chance_weight: float = 100.0  ## Weight for loot tables
@export var beam_height: float = 2.0  ## Vertical ray height


static func create_common() -> ItemRarity:
	var r: ItemRarity = ItemRarity.new()
	r.tier = Tier.COMMON
	r.display_name = "Common"
	r.color = Color.WHITE
	r.value_multiplier = 1.0
	r.stat_multiplier = 1.0
	r.drop_chance_weight = 100.0
	r.beam_height = 2.0
	return r


static func create_uncommon() -> ItemRarity:
	var r: ItemRarity = ItemRarity.new()
	r.tier = Tier.UNCOMMON
	r.display_name = "Uncommon"
	r.color = Color.GREEN
	r.value_multiplier = 2.0
	r.stat_multiplier = 1.5
	r.drop_chance_weight = 40.0
	r.beam_height = 3.0
	return r


static func create_rare() -> ItemRarity:
	var r: ItemRarity = ItemRarity.new()
	r.tier = Tier.RARE
	r.display_name = "Rare"
	r.color = Color(1.0, 0.84, 0.0)  # Gold - matches Elite enemies
	r.value_multiplier = 5.0
	r.stat_multiplier = 2.5
	r.drop_chance_weight = 15.0
	r.beam_height = 4.0
	return r


static func create_epic() -> ItemRarity:
	var r: ItemRarity = ItemRarity.new()
	r.tier = Tier.EPIC
	r.display_name = "Epic"
	r.color = Color(0.6, 0.2, 0.9)  # Purple
	r.value_multiplier = 10.0
	r.stat_multiplier = 3.5
	r.drop_chance_weight = 5.0
	r.beam_height = 5.0
	return r


static func create_legendary() -> ItemRarity:
	var r: ItemRarity = ItemRarity.new()
	r.tier = Tier.LEGENDARY
	r.display_name = "Legendary"
	r.color = Color.YELLOW
	r.value_multiplier = 20.0
	r.stat_multiplier = 5.0
	r.drop_chance_weight = 2.0
	r.beam_height = 6.0
	return r


static func create_unique() -> ItemRarity:
	var r: ItemRarity = ItemRarity.new()
	r.tier = Tier.UNIQUE
	r.display_name = "Unique"
	r.color = Color.ORANGE
	r.value_multiplier = 50.0
	r.stat_multiplier = 7.0
	r.drop_chance_weight = 0.5
	r.beam_height = 8.0
	return r


## Get rarity by tier


static func from_tier(rarity_tier: Tier) -> ItemRarity:
	match rarity_tier:
		Tier.COMMON:
			return create_common()
		Tier.UNCOMMON:
			return create_uncommon()
		Tier.RARE:
			return create_rare()
		Tier.EPIC:
			return create_epic()
		Tier.LEGENDARY:
			return create_legendary()
		Tier.UNIQUE:
			return create_unique()
	return create_common()
