class_name ItemData
extends Resource

enum ItemType { WEAPON, ARMOR, CONSUMABLE, AMMO, MISC }

@export var item_id: String = ""
@export var display_name: String = "Item"
@export var description: String = ""
@export var icon: Texture2D = null
@export var item_type: ItemType = ItemType.MISC
@export var rarity: ItemRarity = null
@export var base_value: int = 10
@export var max_stack: int = 1
@export var world_scene: PackedScene = null


func _init(p_id: String = "", p_name: String = "", p_type: int = ItemType.MISC) -> void:
	item_id = p_id
	display_name = p_name
	item_type = p_type as ItemType
	if not rarity:
		rarity = ItemRarity.create_common()


func get_display_name_colored() -> String:
	return "[color=#%s]%s[/color]" % [rarity.color.to_html(), display_name]


func get_modified_value() -> int:
	if rarity:
		return int(base_value * rarity.value_multiplier)
	return base_value
