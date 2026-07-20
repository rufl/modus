extends VBoxContainer

const MAX_ENTRIES: int = 3
const BASE_LIFETIME: float = 6.0
const MIN_LIFETIME: float = 2.0
const LIFETIME_DECAY: float = 0.5

var entries: Array[Dictionary] = []


func _ready() -> void:
	# Subscribe to Core Events
	if GameManager.get_core_system("events"):
		# Lifts
		GameManager.get_core_system("events").subscribe("item_picked_up", _on_item_picked_up)
		GameManager.get_core_system("events").subscribe("enemy_died", _on_enemy_died)
		GameManager.get_core_system("events").subscribe("player_died", _on_player_died)

	# Legacy signals (if any remain)
	# GameManager.get_core_system("events").loot_picked_up.connect(_on_item_picked_up_legacy)


func _exit_tree() -> void:
	# === SIGNAL HYGIENE ===
	if GameManager.get_core_system("events"):
		GameManager.get_core_system("events").unsubscribe("item_picked_up", _on_item_picked_up)
		GameManager.get_core_system("events").unsubscribe("enemy_died", _on_enemy_died)
		GameManager.get_core_system("events").unsubscribe("player_died", _on_player_died)


func _on_item_picked_up(data: Dictionary) -> void:
	var item_id: String = data.get("item_id", "Unknown")
	var player_id: int = data.get("peer_id", -1)

	var is_local: bool = player_id == multiplayer.get_unique_id()

	# Get item rarity
	var rarity_tier: int = _get_item_rarity(item_id)
	var is_legendary: bool = rarity_tier >= ItemRarity.Tier.LEGENDARY

	# Filter others' pickups unless legendary/unique
	if not is_local and not is_legendary:
		return

	var msg: String = "Picked up %s" % _format_item_name(item_id)
	var color: Color = _get_rarity_color(rarity_tier)

	if _is_weapon(item_id):
		if rarity_tier == ItemRarity.Tier.COMMON:
			color = Color.GOLD
	elif _is_powerup(item_id):
		if rarity_tier == ItemRarity.Tier.COMMON:
			color = Color.MAGENTA

	if not is_local:
		var pname: String = str(player_id)
		var gs := GameManager.get_core_system("gameplay") as GameplaySvc
		if gs and gs.match_service:
			pname = gs.match_service.get_player_name(player_id)
		msg = "%s found %s!" % [pname, _format_item_name(item_id)]

		# Add special indicator for legendary/unique
		if is_legendary:
			msg = "★ " + msg + " ★"

	_add_log_entry(msg, color)


func _on_enemy_died(data: Dictionary) -> void:
	var killer_id: int = data.get("killer_id", -1)
	var enemy_id: String = data.get("enemy_id", "Enemy")
	var is_crit: bool = data.get("is_crit", false)
	var overkill: float = data.get("overkill_damage", 0.0)

	var my_id: int = multiplayer.get_unique_id()

	if killer_id == my_id:
		var msg: String = "You killed %s" % enemy_id.capitalize()
		var color: Color = Color.RED

		if is_crit:
			msg += " (CRIT!)"
			color = Color.ORANGE_RED

		# Add overkill display if significant (>10 damage)
		if overkill > 10.0:
			msg += " [+%d OVERKILL]" % int(overkill)
			color = Color(1.0, 0.5, 0.0)  # Bright orange for overkill

		_add_log_entry(msg, color)

	# Optional: Show when teammates kill elite enemies
	# else: ...


func _on_player_died(data: Dictionary) -> void:
	var victim_id: int = data.get("peer_id", -1)
	var killer_id: int = data.get("killer_id", -1)

	var victim_name: String = "Player"
	var killer_name: String = "Environment"

	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		victim_name = gs.match_service.get_player_name(victim_id)
		if killer_id != -1:
			killer_name = gs.match_service.get_player_name(killer_id)

	var msg: String = "%s died" % victim_name
	if killer_id != -1 and killer_id != victim_id:
		msg = "%s killed by %s" % [victim_name, killer_name]

	_add_log_entry(msg, Color.CRIMSON)


func _add_log_entry(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)

	add_child(label)
	move_child(label, 0)

	entries.append({"label": label, "time": Time.get_unix_time_from_system()})

	# Limit
	if entries.size() > MAX_ENTRIES:
		var oldest: Dictionary = entries.pop_back()
		if is_instance_valid(oldest.label):
			oldest.label.queue_free()

	_schedule_fade(label)

	_schedule_fade(label)


func _schedule_fade(label: Label) -> void:
	await get_tree().create_timer(BASE_LIFETIME).timeout
	if is_instance_valid(label):
		var tween: Tween = create_tween()
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(label.queue_free)


func _format_item_name(id: String) -> String:
	return id.replace("_", " ").capitalize()


func _get_item_rarity(item_id: String) -> int:
	var data_service: Node = GameManager.get_core_system("data")
	if not data_service:
		return _infer_rarity_from_id(item_id)

	var item_data: Dictionary = data_service.get_item_data(item_id)
	if item_data.is_empty():
		return _infer_rarity_from_id(item_id)

	# Check if rarity is specified in data
	if item_data.has("rarity"):
		var rarity_val: Variant = item_data.rarity
		if rarity_val is int:
			return rarity_val
		if rarity_val is Dictionary and rarity_val.has("tier"):
			return rarity_val.tier

	# Fallback to pattern matching
	return _infer_rarity_from_id(item_id)


func _infer_rarity_from_id(item_id: String) -> int:
	## Infer rarity from item_id patterns (fallback when no data exists)
	var lower_id: String = item_id.to_lower()

	# Check for rarity keywords in item_id
	if "unique" in lower_id or "artifact" in lower_id:
		return ItemRarity.Tier.UNIQUE
	if "legendary" in lower_id or "mythic" in lower_id:
		return ItemRarity.Tier.LEGENDARY
	if "epic" in lower_id or "purple" in lower_id:
		return ItemRarity.Tier.EPIC
	if "rare" in lower_id or "gold" in lower_id:
		return ItemRarity.Tier.RARE
	if "uncommon" in lower_id or "green" in lower_id:
		return ItemRarity.Tier.UNCOMMON

	# Special cases for high-tier items
	if "mega" in lower_id or "quad" in lower_id or "invuln" in lower_id:
		return ItemRarity.Tier.EPIC  # Powerups are epic

	return ItemRarity.Tier.COMMON


func _get_rarity_color(rarity_tier: int) -> Color:
	match rarity_tier:
		ItemRarity.Tier.COMMON:
			return Color.WHITE
		ItemRarity.Tier.UNCOMMON:
			return Color.GREEN
		ItemRarity.Tier.RARE:
			return Color(1.0, 0.84, 0.0)  # Gold
		ItemRarity.Tier.EPIC:
			return Color(0.6, 0.2, 0.9)  # Purple
		ItemRarity.Tier.LEGENDARY:
			return Color.YELLOW
		ItemRarity.Tier.UNIQUE:
			return Color.ORANGE
		_:
			return Color.WHITE


func _is_weapon(id: String) -> bool:
	return "weapon" in id or "gun" in id or "launcher" in id


func _is_powerup(id: String) -> bool:
	var lower: String = id.to_lower()
	return (
		"powerup" in lower
		or "mega" in lower
		or "quad" in lower
		or "invuln" in lower
		or "haste" in lower
		or "artifact" in lower
	)
