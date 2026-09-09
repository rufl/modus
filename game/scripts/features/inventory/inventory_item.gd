class_name InventoryItem
extends Resource

enum ItemType { WEAPON, ARMOR, CONSUMABLE, MATERIAL, KEY_ITEM, AMMO }

@export var id: String = ""
@export var display_name: String = "Item"
@export var description: String = ""
@export var icon_path: String = ""
@export var item_type: ItemType = ItemType.MATERIAL
@export var rarity: ItemRarity.Tier = ItemRarity.Tier.COMMON
@export var max_stack: int = 1
@export var current_stack: int = 1
@export var value: int = 0
@export var equip_slot: String = ""  # Empty or a name from Inventory.EQUIPMENT_SLOTS.
@export var weapon_scene: String = ""  # Path to weapon scene for weapons
@export var effect_type: String = ""  # "heal", "buff", "damage"
@export var effect_value: float = 0.0

var icon: Texture2D = null
var item_id: String = ""


static func from_dict(data: Dictionary) -> InventoryItem:
	var item: InventoryItem = InventoryItem.new()
	item.id = data.get("id", "")
	item.display_name = data.get("display_name", "Item")
	item.description = data.get("description", "")
	item.icon_path = data.get("icon_path", "")
	if not item.icon_path.is_empty() and ResourceLoader.exists(item.icon_path, "Texture2D"):
		item.icon = load(item.icon_path) as Texture2D
	item.item_type = data.get("item_type", ItemType.MATERIAL)
	item.rarity = data.get("rarity", ItemRarity.Tier.COMMON)
	item.max_stack = data.get("max_stack", 1)
	item.current_stack = data.get("current_stack", 1)
	item.value = data.get("value", 0)
	item.equip_slot = data.get("equip_slot", "")
	item.weapon_scene = data.get("weapon_scene", "")
	item.effect_type = data.get("effect_type", "")
	item.effect_value = data.get("effect_value", 0.0)
	return item


## Convert to dictionary for network/save


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"icon_path": icon_path,
		"item_type": item_type,
		"rarity": rarity,
		"max_stack": max_stack,
		"current_stack": current_stack,
		"value": value,
		"equip_slot": equip_slot,
		"weapon_scene": weapon_scene,
		"effect_type": effect_type,
		"effect_value": effect_value
	}


## Check if item can stack with another


func can_stack_with(other: InventoryItem) -> bool:
	if not other:
		return false
	if id != other.id:
		return false
	if max_stack <= 1:
		return false
	return current_stack < max_stack


## Add to stack, returns overflow amount


func add_to_stack(amount: int) -> int:
	var space: int = max_stack - current_stack
	var to_add: int = mini(amount, space)
	current_stack += to_add
	return amount - to_add


## Remove from stack, returns actual removed


func remove_from_stack(amount: int) -> int:
	var to_remove: int = mini(amount, current_stack)
	current_stack -= to_remove
	return to_remove


## Check if stack is empty


func is_empty() -> bool:
	return current_stack <= 0


## Duplicate item with new stack count


func duplicate_with_stack(new_stack: int) -> InventoryItem:
	var copy: InventoryItem = duplicate() as InventoryItem
	copy.icon = icon
	copy.item_id = item_id
	copy.current_stack = new_stack
	return copy


## Get rarity color


func get_rarity_color() -> Color:
	return ItemRarity.from_tier(rarity).color
