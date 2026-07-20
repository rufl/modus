@tool
class_name HotbarCategory
extends RefCounted

enum Category { BLOCKS, PROPS, ENTITIES, TRIGGERS, EFFECTS, HAZARDS, MOVERS, CUSTOM }  ## Solid geometry blocks  ## Decorative props and furniture  ## Enemies, NPCs, interactive objects  ## Trigger zones, activators  ## Particles, lights, sounds  ## Damaging elements  ## Moving platforms, doors  ## User-defined category

const CATEGORY_NAMES: Dictionary = {
	Category.BLOCKS: "Blocks",
	Category.PROPS: "Props",
	Category.ENTITIES: "Entities",
	Category.TRIGGERS: "Triggers",
	Category.EFFECTS: "Effects",
	Category.HAZARDS: "Hazards",
	Category.MOVERS: "Movers",
	Category.CUSTOM: "Custom",
}

const CATEGORY_COLORS: Dictionary = {
	Category.BLOCKS: Color(0.6, 0.6, 0.8),
	Category.PROPS: Color(0.6, 0.8, 0.6),
	Category.ENTITIES: Color(0.8, 0.6, 0.6),
	Category.TRIGGERS: Color(0.8, 0.8, 0.4),
	Category.EFFECTS: Color(0.8, 0.4, 0.8),
	Category.HAZARDS: Color(1.0, 0.4, 0.4),
	Category.MOVERS: Color(0.4, 0.8, 0.8),
	Category.CUSTOM: Color(0.7, 0.7, 0.7),
}

const CATEGORY_ICONS: Dictionary = {
	Category.BLOCKS: "🧱",
	Category.PROPS: "🪑",
	Category.ENTITIES: "👾",
	Category.TRIGGERS: "⚡",
	Category.EFFECTS: "✨",
	Category.HAZARDS: "☠️",
	Category.MOVERS: "🚪",
	Category.CUSTOM: "📦",
}


static func next_category(current: Category) -> Category:
	var next_val: int = (current + 1) % Category.size()
	return next_val as Category


## Get the previous category (for ALT+scroll down)


static func prev_category(current: Category) -> Category:
	var prev_val: int = current - 1
	if prev_val < 0:
		prev_val = Category.size() - 1
	return prev_val as Category


## Get display name for a category


static func get_name(cat: Category) -> String:
	return CATEGORY_NAMES.get(cat, "Unknown")


## Get color for a category


static func get_color(cat: Category) -> Color:
	return CATEGORY_COLORS.get(cat, Color.WHITE)


## Get icon for a category


static func get_icon(cat: Category) -> String:
	return CATEGORY_ICONS.get(cat, "?")


## Determine category from asset data


static func categorize_asset(asset: Dictionary) -> Category:
	var asset_type: String = asset.get("type", "").to_lower()
	var tags: Array = asset.get("tags", [])

	# Check tags first
	for tag: Variant in tags:
		var tag_str: String = str(tag).to_lower()
		match tag_str:
			"block", "geometry", "wall", "floor":
				return Category.BLOCKS
			"prop", "decoration", "furniture":
				return Category.PROPS
			"entity", "enemy", "npc", "spawner":
				return Category.ENTITIES
			"trigger", "activator", "switch":
				return Category.TRIGGERS
			"effect", "particle", "light", "sound":
				return Category.EFFECTS
			"hazard", "trap", "damage":
				return Category.HAZARDS
			"mover", "door", "platform", "lift":
				return Category.MOVERS

	# Fallback to type detection
	match asset_type:
		"block", "csg", "geometry":
			return Category.BLOCKS
		"prop", "mesh", "static":
			return Category.PROPS
		"spawn_point", "entity", "enemy":
			return Category.ENTITIES
		"trigger", "zone":
			return Category.TRIGGERS
		"particle", "light", "audio":
			return Category.EFFECTS
		"hazard":
			return Category.HAZARDS
		"mover", "door":
			return Category.MOVERS
		_:
			return Category.CUSTOM


## Get all categories as an array


static func get_all_categories() -> Array[Category]:
	var result: Array[Category] = []
	for i: int in range(Category.size()):
		result.append(i as Category)
	return result
