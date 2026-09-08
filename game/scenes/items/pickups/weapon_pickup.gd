extends "res://game/scenes/items/pickups/pickup_base.gd"
class_name WeaponPickup

enum WeaponType { PISTOL = 0, SHOTGUN = 1, MACHINEGUN = 2, ROCKET_LAUNCHER = 3 }

@export var weapon_type: WeaponType = WeaponType.PISTOL
@export var base_weapon_name: String = "Pistol"
@export var prefix_index: int = -1
@export var suffix_index: int = -1

var prefix_affix: WeaponAffix = null
var suffix_affix: WeaponAffix = null
var rarity_color: Color = Color.WHITE


func _extend_synchronizer_config(config: SceneReplicationConfig) -> void:
	super._extend_synchronizer_config(config)
	config.add_property(".:prefix_index")
	config.add_property(".:suffix_index")


func _ready() -> void:
	_update_from_indices()
	super._ready()


func _update_from_indices() -> void:
	# Load affixes based on indices
	if prefix_index >= 0:
		var all_prefixes: Array[WeaponAffix] = WeaponAffix.get_all_prefixes()
		if prefix_index < all_prefixes.size():
			prefix_affix = all_prefixes[prefix_index]
	else:
		prefix_affix = null

	if suffix_index >= 0:
		var all_suffixes: Array[WeaponAffix] = WeaponAffix.get_all_suffixes()
		if suffix_index < all_suffixes.size():
			suffix_affix = all_suffixes[suffix_index]
	else:
		suffix_affix = null

	_update_display_name()
	_apply_rarity_visuals()


func _update_display_name() -> void:
	var name_parts: Array[String] = []

	# Prefix
	if prefix_affix:
		name_parts.append(prefix_affix.display_text)

	# Base name
	name_parts.append(base_weapon_name)

	# Suffix
	if suffix_affix:
		name_parts.append(suffix_affix.display_text)

	pickup_name = " ".join(name_parts)

	# Build description from modifiers
	var stats: Array[String] = []
	if prefix_affix:
		_add_affix_stats(prefix_affix, stats)
	if suffix_affix:
		_add_affix_stats(suffix_affix, stats)

	if stats.is_empty():
		description = "Standard issue"
	else:
		description = "\n".join(stats)

	# Selected drop rarity takes precedence; affix-only map pickups retain their colors.
	if rarity:
		rarity_color = rarity.color
	elif suffix_affix:
		rarity_color = suffix_affix.color
	elif prefix_affix:
		rarity_color = prefix_affix.color
	else:
		rarity_color = Color.WHITE


func _add_affix_stats(affix: WeaponAffix, stats: Array[String]) -> void:
	if affix.damage_mult != 1.0:
		var pct: int = int((affix.damage_mult - 1.0) * 100)
		stats.append("%+d%% Damage" % pct)
	if affix.fire_rate_mult != 1.0:
		var pct: int = int((affix.fire_rate_mult - 1.0) * 100)
		stats.append("%+d%% Fire Rate" % pct)
	if affix.magazine_mult != 1.0:
		var pct: int = int((affix.magazine_mult - 1.0) * 100)
		stats.append("%+d%% Magazine" % pct)
	if affix.reload_speed_mult != 1.0:
		var pct: int = int((affix.reload_speed_mult - 1.0) * 100)
		stats.append("%+d%% Reload" % pct)


func _on_pickup(player: CharacterBody3D) -> void:
	var ammo_amount: int = _get_ammo_amount()
	var has_affixes: bool = (prefix_affix != null) or (suffix_affix != null)

	# If the weapon has affixes, we want to equip it (apply stats)
	# If it's a standard weapon, we just give ammo (assuming player starts with base weapons)
	if has_affixes and player.has_method("pickup_weapon"):
		player.pickup_weapon(weapon_type, prefix_affix, suffix_affix, ammo_amount)
	elif player.has_method("add_ammo_for_weapon"):
		player.add_ammo_for_weapon(weapon_type, ammo_amount)

	# Service-based screen flash
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.effects and gs.effects.has_method("screen_flash"):
		gs.effects.screen_flash(rarity_color.lightened(0.2), 0.25)
	else:
		# Fallback for compatibility
		if "weapon_ammo" in player and weapon_type < player.weapon_ammo.size():
			player.weapon_ammo[weapon_type][1] += ammo_amount


func _get_ammo_amount() -> int:
	match weapon_type:
		WeaponType.PISTOL:
			return 24
		WeaponType.SHOTGUN:
			return 12
		WeaponType.MACHINEGUN:
			return 60
		WeaponType.ROCKET_LAUNCHER:
			return 4
	return 20


## Generate random affixes for this weapon


func generate_random_affixes(allow_prefix: bool = true, allow_suffix: bool = true) -> void:
	# Prefix chance: 40%
	if allow_prefix and randf() < 0.4:
		prefix_index = WeaponAffix.get_random_prefix_index()

	# Suffix chance: 25% (rarer)
	if allow_suffix and randf() < 0.25:
		suffix_index = WeaponAffix.get_random_suffix_index()

	_update_from_indices()


func _apply_rarity_visuals() -> void:
	super._apply_rarity_visuals()
	# Color the mesh based on rarity
	if rarity_color != Color.WHITE:
		var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
		if mesh and mesh.get_active_material(0):
			var mat: StandardMaterial3D = mesh.get_active_material(0).duplicate()
			mat.emission_enabled = true
			mat.emission = rarity_color
			mat.emission_energy_multiplier = 0.5
			mesh.set_surface_override_material(0, mat)

	# Screen flash for pickup
	var gs_api := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs_api and gs_api.effects and gs_api.effects.has_method("screen_flash"):
		gs_api.effects.screen_flash(rarity_color.lightened(0.2), 0.25)


## Set rarity (called by LootGenerator)


func set_rarity(new_rarity: ItemRarity) -> void:
	rarity_color = new_rarity.color if new_rarity else Color.WHITE
	super.set_rarity(new_rarity)
