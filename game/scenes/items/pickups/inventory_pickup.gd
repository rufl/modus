extends PickupBase


func _ready() -> void:
	pickup_name = item_data.get("display_name", pickup_name)
	description = item_data.get("description", description)
	super._ready()


func _apply_pickup(player: CharacterBody3D) -> bool:
	return _add_to_inventory(player)
