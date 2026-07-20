@tool
class_name EditorAssetRegistry
extends Node

signal assets_loaded
signal category_changed(category: String)

enum Category { BLOCKS, ENTITIES, PROPS, INTERACTABLES, HAZARDS, PICKUPS, SPAWN_POINTS }

const CATEGORY_NAMES := {
	Category.BLOCKS: "Blocks",
	Category.ENTITIES: "Entities",
	Category.PROPS: "Props",
	Category.INTERACTABLES: "Interactables",
	Category.HAZARDS: "Hazards",
	Category.PICKUPS: "Pickups",
	Category.SPAWN_POINTS: "Spawn Points",
}

var assets: Dictionary = {}
var current_category: Category = Category.BLOCKS
var search_filter: String = ""


func _ready() -> void:
	_init_asset_categories()
	# Defer scanning to avoid blocking editor startup
	_scan_assets.call_deferred()


func _init_asset_categories() -> void:
	for cat: int in Category.values():
		assets[cat] = []


## Scan for available assets in the project


func _scan_assets() -> void:
	# Blocks - CSG primitives with materials
	_register_builtin_blocks()

	# Entities - enemies from game/entities/enemies
	_scan_directory("res://game/entities/enemies/", Category.ENTITIES, ["*.tscn"])

	# Props - canonical world actor scenes
	_scan_directory("res://game/world/actors/props/", Category.PROPS, ["*.tscn"])
	_scan_directory("res://game/world/actors/props/scenes/", Category.PROPS, ["*.tscn"])

	# Hazards - crushers, spikes, turrets
	_scan_directory("res://game/world/actors/hazards/", Category.HAZARDS, ["*.tscn"])
	_scan_directory("res://game/scenes/environment/hazards/", Category.HAZARDS, ["*.tscn"])

	# Interactables - doors, triggers, platforms
	_register_interactables()
	_scan_directory("res://game/scenes/environment/traversal/", Category.INTERACTABLES, ["*.tscn"])
	_scan_directory(
		"res://game/scenes/environment/interactables/", Category.INTERACTABLES, ["*.tscn"]
	)

	# Pickups - health, armor, ammo, weapons
	_scan_directory("res://game/scenes/items/pickups/", Category.PICKUPS, ["*.tscn"])

	# Spawn points - built-in
	_register_spawn_points()

	assets_loaded.emit()


func _register_builtin_blocks() -> void:
	## Register basic block types for CSG-based level building
	var block_types := [
		{"id": "block_stone", "name": "Stone Block", "color": Color(0.5, 0.5, 0.5)},
		{"id": "block_brick", "name": "Brick Block", "color": Color(0.6, 0.3, 0.2)},
		{"id": "block_wood", "name": "Wood Block", "color": Color(0.5, 0.35, 0.2)},
		{"id": "block_metal", "name": "Metal Block", "color": Color(0.4, 0.45, 0.5)},
		{"id": "block_dirt", "name": "Dirt Block", "color": Color(0.4, 0.3, 0.2)},
		{"id": "block_grass", "name": "Grass Block", "color": Color(0.3, 0.5, 0.2)},
		{"id": "block_sand", "name": "Sand Block", "color": Color(0.8, 0.7, 0.5)},
		{"id": "block_ice", "name": "Ice Block", "color": Color(0.7, 0.85, 0.95)},
		{"id": "block_lava", "name": "Lava Block", "color": Color(0.9, 0.3, 0.1)},
		{"id": "block_water", "name": "Water Block", "color": Color(0.2, 0.4, 0.8)},
	]

	for block: Dictionary in block_types:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = block.color
		mat.roughness = 0.8

		assets[Category.BLOCKS].append(
			{
				"id": block.id,
				"name": block.name,
				"type": "block",
				"material": mat,
				"icon": null,  # Will generate thumbnail
				"description": "Basic " + block.name.to_lower()
			}
		)


func _register_interactables() -> void:
	## Register existing interactable components
	var interactables := [
		{"id": "door", "name": "Door", "path": "res://game/world/actors/door.gd"},
		{
			"id": "trigger_zone",
			"name": "Trigger Zone",
			"path": "res://game/world/actors/trigger_zone.gd"
		},
		{
			"id": "moving_platform",
			"name": "Moving Platform",
			"path": "res://game/world/actors/moving_platform.gd"
		},
	]

	for item: Dictionary in interactables:
		if ResourceLoader.exists(item.path):
			assets[Category.INTERACTABLES].append(
				{
					"id": item.id,
					"name": item.name,
					"type": "interactable",
					"script_path": item.path,
					"icon": null,
					"description": "Interactive " + item.name.to_lower()
				}
			)


func _register_spawn_points() -> void:
	assets[Category.SPAWN_POINTS].append(
		{
			"id": "spawn_player",
			"name": "Player Spawn",
			"type": "spawn_point",
			"spawn_type": "player",
			"icon": null,
			"description": "Player spawn location"
		}
	)

	assets[Category.SPAWN_POINTS].append(
		{
			"id": "spawn_enemy",
			"name": "Enemy Spawn",
			"type": "spawn_point",
			"spawn_type": "enemy",
			"icon": null,
			"description": "Enemy spawn location"
		}
	)

	assets[Category.SPAWN_POINTS].append(
		{
			"id": "spawn_item",
			"name": "Item Spawn",
			"type": "spawn_point",
			"spawn_type": "item",
			"icon": null,
			"description": "Item/pickup spawn location"
		}
	)


func _scan_directory(path: String, category: Category, patterns: Array) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			for pattern: Variant in patterns:
				if file_name.match(pattern):
					var full_path := path.path_join(file_name)
					_register_scene_asset(full_path, category)
					break
		file_name = dir.get_next()

	dir.list_dir_end()


func _register_scene_asset(scene_path: String, category: Category) -> void:
	if not ResourceLoader.exists(scene_path):
		return

	# OPTIMIZATION: Don't load the scene here.
	# Only store the path and metadata to avoid synchronous load during scan.
	var id := scene_path.get_file().get_basename()
	var display_name := id.capitalize().replace("_", " ")

	assets[category].append(
		{
			"id": id,
			"name": display_name,
			"type": "scene",
			"scene_path": scene_path,  # Store path for lazy loading
			"icon": null,
			"description": display_name + " from " + scene_path.get_base_dir().get_file()
		}
	)


## Get assets for current category with optional filter


func get_filtered_assets() -> Array:
	var category_assets: Array = assets.get(current_category, [])

	if search_filter.is_empty():
		return category_assets

	var filtered := []
	var search_lower := search_filter.to_lower()

	for asset: Dictionary in category_assets:
		var name_match: bool = asset.name.to_lower().contains(search_lower)
		var id_match: bool = asset.id.to_lower().contains(search_lower)
		if name_match or id_match:
			filtered.append(asset)

	return filtered


## Set category filter


func set_category(category: Category) -> void:
	if current_category != category:
		current_category = category
		category_changed.emit(CATEGORY_NAMES[category])


## Set search filter


func set_search_filter(filter: String) -> void:
	search_filter = filter


## Get asset by ID (searches all categories)


func get_asset_by_id(id: String) -> Dictionary:
	for cat_assets: Variant in assets.values():
		for asset: Dictionary in cat_assets:
			if asset.id == id:
				return asset
	return {}


## Get all category names


func get_category_names() -> Array[String]:
	var names: Array[String] = []
	for cat: int in Category.values():
		names.append(CATEGORY_NAMES[cat])
	return names


## Get category by name


func get_category_by_name(category_name: String) -> Category:
	for cat: int in Category.values():
		if CATEGORY_NAMES[cat] == category_name:
			return cat as Category
	return Category.BLOCKS


## Register custom asset


func register_custom_asset(category: Category, asset_data: Dictionary) -> void:
	if not asset_data.has("id") or not asset_data.has("name"):
		push_error("Asset must have 'id' and 'name' fields")
		return

	assets[category].append(asset_data)


## Get asset scene by ID (helper for gizmos/spawners)


func get_asset_scene(id: String) -> PackedScene:
	var asset: Dictionary = get_asset_by_id(id)
	if asset.has("scene"):
		return asset.scene

	if asset.has("scene_path"):
		# Lazy load for gizmo preview
		asset["scene"] = load(asset["scene_path"])
		return asset["scene"]
	return null


## Get asset count for category


func get_asset_count(category: Category) -> int:
	return assets.get(category, []).size()
