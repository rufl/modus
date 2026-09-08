extends "res://game/scenes/items/pickups/pickup_base.gd"

@export var item_id: String = "health_potion"
@export var stack_count: int = 1


func _extend_synchronizer_config(config: SceneReplicationConfig) -> void:
	super._extend_synchronizer_config(config)
	config.add_property(".:item_id")
	config.add_property(".:stack_count")


func _ready() -> void:
	# Resource-backed drops are configured before tree entry; map pickups use the database.
	var data: Dictionary = item_data
	if data.is_empty():
		var data_service = GameManager.get_core_system("data")
		data = data_service.get_item_data(item_id) if data_service else {}

	if data.is_empty():
		push_warning("[ConsumablePickup] Item not found: %s" % item_id)
		# Use fallback data
		data = {
			"id": item_id,
			"display_name": "Unknown Item",
			"description": "An unknown item",
			"item_type": 2,  # CONSUMABLE
			"rarity": 0,
			"max_stack": 1,
			"value": 0
		}

	# Configure pickup from item data
	pickup_name = data.get("display_name", item_id)
	description = data.get("description", "")

	# Set item_data for inventory transfer
	item_data = data.duplicate()
	item_data["current_stack"] = stack_count

	# Set rarity visuals
	if not rarity:
		set_rarity(ItemRarity.from_tier(data.get("rarity", 0)))

	# Set icon display
	var icon_path: String = data.get("icon_path", "")
	if not icon_path.is_empty():
		use_icon = true
		# Use emoji fallback based on effect type
		match data.get("effect_type", ""):
			"heal":
				icon_text = "💊"
				icon_color = Color(0.3, 1.0, 0.4)
			"armor":
				icon_text = "🛡️"
				icon_color = Color(0.3, 0.5, 1.0)
			"buff_speed":
				icon_text = "⚡"
				icon_color = Color(1.0, 0.9, 0.2)
			"buff_damage":
				icon_text = "💥"
				icon_color = Color(1.0, 0.4, 0.2)
			_:
				icon_text = "📦"
				icon_color = Color.WHITE

	super._ready()


func _apply_pickup(player: CharacterBody3D) -> bool:
	if "inventory" in player and player.inventory is Inventory:
		return _add_to_inventory(player)
	return super._apply_pickup(player)


func _on_pickup(player: CharacterBody3D) -> void:
	# Apply consumable effect immediately OR add to inventory
	var effect_type: String = item_data.get("effect_type", "")
	var effect_value: float = item_data.get("effect_value", 0.0)

	# Fallback: Apply effect immediately if no inventory
	match effect_type:
		"heal":
			if "health_component" in player and player.health_component:
				player.health_component.heal(effect_value)
			elif "health" in player:
				var max_hp: int = player.max_health if "max_health" in player else 100
				player.health = mini(int(player.health + effect_value), max_hp)
		"armor":
			if "health_component" in player and player.health_component:
				player.health_component.add_armor(effect_value)
			elif "armor" in player:
				var max_armor: int = player.max_armor if "max_armor" in player else 100
				player.armor = mini(int(player.armor + effect_value), max_armor)
		"buff_speed":
			if "speed_multiplier" in player:
				player.speed_multiplier = 1.5
				# Reset after duration
				get_tree().create_timer(effect_value).timeout.connect(
					func() -> void:
						if is_instance_valid(player):
							player.speed_multiplier = 1.0
				)
		"buff_damage":
			if "damage_multiplier" in player:
				player.damage_multiplier = 1.25
				get_tree().create_timer(effect_value).timeout.connect(
					func() -> void:
						if is_instance_valid(player):
							player.damage_multiplier = 1.0
				)

	print(
		"[ConsumablePickup] Applied %s effect: %s (%.1f)" % [pickup_name, effect_type, effect_value]
	)
