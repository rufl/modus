class_name LegacyLootTable
extends Resource

@export_group("Configuration")
@export var min_items: int = 1
@export var max_items: int = 1
@export var no_drop_chance: float = 0.0  ## 0.0 to 1.0
@export_group("Loot Pool")
@export var possible_items: Array[ItemData] = []
@export var item_weights: Array[float] = []


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

	for index in possible_items.size():
		var item: ItemData = possible_items[index]
		var w: float = item.rarity.drop_chance_weight if item and item.rarity else 100.0
		if index < item_weights.size():
			w = item_weights[index]
		w = maxf(w, 0.0) if is_finite(w) else 0.0
		weights.append(w)
		total_weight += w
	if total_weight <= 0:
		return result

	# Pick items
	for _unused: int in range(item_count):
		var pick: float = randf() * total_weight
		var current_w: float = 0.0
		for j in range(possible_items.size()):
			current_w += weights[j]
			if pick < current_w:
				if possible_items[j]:
					result.append(possible_items[j])
				break

	return result
