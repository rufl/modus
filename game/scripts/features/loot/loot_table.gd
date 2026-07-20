class_name LegacyLootTable
extends Resource

@export_group("Configuration")
@export var min_items: int = 1
@export var max_items: int = 1
@export var no_drop_chance: float = 0.0  ## 0.0 to 1.0
@export_group("Loot Pool")
@export var possible_items: Array[ItemData] = []


func roll_loot() -> Array[ItemData]:
	var result: Array[ItemData] = []

	if randf() < no_drop_chance:
		return result

	var item_count: int = randi_range(min_items, max_items)
	if possible_items.is_empty():
		return result

	# Calculate total weight
	var total_weight: float = 0.0
	var weights: Array[float] = []

	for item: ItemData in possible_items:
		var w: float = 100.0  # Default
		if item.rarity:
			w = item.rarity.drop_chance_weight
		weights.append(w)
		total_weight += w

	# Pick items
	for _unused: int in range(item_count):
		var pick: float = randf() * total_weight
		var current_w: float = 0.0
		for j in range(possible_items.size()):
			current_w += weights[j]
			if pick <= current_w:
				result.append(possible_items[j])
				break

	return result
