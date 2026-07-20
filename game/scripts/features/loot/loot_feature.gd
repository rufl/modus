## LootFeature - Feature module for loot generation system
##
## Manages loot table loading, loot generation, and item drops.
## Depends on InventoryFeature for item management.
##
## Requirements: 2.3
class_name LootFeature
extends FeatureModule

# Preload LootTable
const LootTable = preload("res://game/scripts/features/loot/loot_table.gd")

## Dictionary of loaded loot tables by ID
var loot_tables: Dictionary = {}

## Whether loot generation is enabled
var loot_enabled: bool = true

## Global loot multiplier
var loot_multiplier: float = 1.0

## Reference to InventoryFeature
var inventory_feature: InventoryFeature = null


## Constructor
func _init() -> void:
	super._init("loot")
	feature_name = "Loot System"
	declare_dependencies(["inventory"])


## Initialize the loot feature
func initialize() -> void:
	super.initialize()

	# Load configuration values
	loot_enabled = get_config_value("enabled", true)
	loot_multiplier = get_config_value("loot_multiplier", 1.0)

	# Get reference to InventoryFeature
	var game_manager: Node = null
	game_manager = get_node_or_null("/root/GameManager")
	if not game_manager and get_parent():
		if get_parent().has_method("get_feature"):
			game_manager = get_parent()

	if game_manager and game_manager.has_method("get_feature"):
		inventory_feature = game_manager.get_feature("inventory")
		if not inventory_feature:
			push_warning("LootFeature: InventoryFeature not available yet")

	# Load loot tables from configuration
	_load_loot_tables()

	# Subscribe to loot events
	if game_manager and game_manager.has_method("subscribe"):
		game_manager.subscribe("entity_died", _on_entity_died)
		game_manager.subscribe("loot_requested", _on_loot_requested)


## Shutdown the loot feature
func shutdown() -> void:
	# Unsubscribe from events
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("unsubscribe"):
		game_manager.unsubscribe("entity_died", _on_entity_died)
		game_manager.unsubscribe("loot_requested", _on_loot_requested)

	# Clear loot tables
	loot_tables.clear()
	inventory_feature = null

	super.shutdown()


## Generate loot from a loot table
## Returns an array of item dictionaries
func generate_loot(table_id: String, luck_modifier: float = 0.0) -> Array:
	if not loot_enabled:
		return []

	if not loot_tables.has(table_id):
		push_warning("LootFeature: Loot table '%s' not found" % table_id)
		return []

	var loot_table: LootTable = loot_tables[table_id]
	return loot_table.generate_loot(luck_modifier)


## Get a loot table by ID
func get_loot_table(table_id: String) -> LootTable:
	return loot_tables.get(table_id)


## Register a loot table
func register_loot_table(table_id: String, loot_table: LootTable) -> void:
	loot_tables[table_id] = loot_table


## Drop loot at a position in the world
## Creates item entities at the specified position
func drop_loot(items: Array, position: Vector3, spread: float = 1.0) -> void:
	if items.is_empty():
		return

	var game_manager: Node = get_node_or_null("/root/GameManager")
	if not game_manager or not game_manager.has_method("emit_event"):
		return

	# Emit event for each item to be dropped
	for item in items:
		var drop_position: Vector3 = (
			position + Vector3(randf_range(-spread, spread), 0.0, randf_range(-spread, spread))
		)

		game_manager.emit_event("item_dropped", {"item": item, "position": drop_position})


## Load loot tables from configuration
func _load_loot_tables() -> void:
	var tables_config: Dictionary = get_config_value("tables", {})

	for table_id in tables_config.keys():
		var table_data: Dictionary = tables_config[table_id]
		var loot_table := LootTable.new()

		# Load table properties
		loot_table.table_id = table_id
		loot_table.min_drops = table_data.get("min_drops", 0)
		loot_table.max_drops = table_data.get("max_drops", 1)

		# Load loot entries
		var entries: Array = table_data.get("entries", [])
		for entry_data in entries:
			if entry_data is Dictionary:
				loot_table.add_entry(
					entry_data.get("item_id", ""),
					entry_data.get("weight", 1.0),
					entry_data.get("min_quantity", 1),
					entry_data.get("max_quantity", 1),
					entry_data.get("tier", "common")
				)

		loot_tables[table_id] = loot_table


## Event handler for entity death
func _on_entity_died(data: Dictionary) -> void:
	var entity: Node = data.get("entity")
	var position: Vector3 = data.get("position", Vector3.ZERO)
	var loot_table_id: String = data.get("loot_table", "")

	if loot_table_id.is_empty():
		return

	# Generate and drop loot
	var items: Array = generate_loot(loot_table_id)
	if not items.is_empty():
		drop_loot(items, position)


## Event handler for loot requests
func _on_loot_requested(data: Dictionary) -> void:
	var table_id: String = data.get("table_id", "")
	var position: Vector3 = data.get("position", Vector3.ZERO)
	var luck: float = data.get("luck", 0.0)

	if table_id.is_empty():
		return

	# Generate and drop loot
	var items: Array = generate_loot(table_id, luck)
	if not items.is_empty():
		drop_loot(items, position)
