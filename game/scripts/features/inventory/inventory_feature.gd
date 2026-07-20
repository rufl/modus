## InventoryFeature - Feature module for inventory system
##
## Manages inventory creation, item storage, and inventory operations.
## Provides API for adding, removing, and querying items in player inventories.
##
## Requirements: 2.3
class_name InventoryFeature
extends FeatureModule

# Preload InventoryData
const InventoryData = preload("res://game/scripts/features/inventory/inventory_data.gd")

## Maximum number of inventory slots
var max_slots: int = 20

## Whether auto-stacking is enabled
var auto_stack: bool = true

## Whether overflow is allowed
var allow_overflow: bool = false

## Pickup range in meters
var pickup_range: float = 2.0

## Drop distance in meters
var drop_distance: float = 1.5


## Constructor
func _init() -> void:
	super._init("inventory")
	feature_name = "Inventory System"


## Initialize the inventory feature
func initialize() -> void:
	super.initialize()

	# Load configuration values
	max_slots = get_config_value("default_max_slots", 20)
	auto_stack = get_config_value("stacking.enabled", true)
	allow_overflow = get_config_value("allow_overflow", false)
	pickup_range = get_config_value("pickup.pickup_range", 2.0)
	drop_distance = get_config_value("drop.drop_distance", 1.5)


## Shutdown the inventory feature
func shutdown() -> void:
	super.shutdown()


## Create a new inventory with specified max slots
## Returns an InventoryData instance
func create_inventory(slots: int = -1) -> InventoryData:
	var inventory := InventoryData.new()

	if slots > 0:
		inventory.max_slots = slots
	else:
		inventory.max_slots = max_slots

	inventory.auto_stack = auto_stack
	inventory.allow_overflow = allow_overflow

	return inventory


## Get inventory configuration for a specific key
func get_inventory_config(key: String, default: Variant = null) -> Variant:
	return get_config_value(key, default)
