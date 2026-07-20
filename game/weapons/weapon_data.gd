class_name WeaponData
extends Resource

@export var weapon_name: String = "Pistol"
@export var weapon_id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var damage: int = 1
@export var damage_type: DamageInfo.DamageType = DamageInfo.DamageType.BULLET
@export var magazine_size: int = 12
@export var max_reserve_ammo: int = 48
@export var reload_time: float = 1.5
@export var fire_rate: float = 0.4
@export var is_automatic: bool = false
@export var pellet_count: int = 1
@export var spread_angle: float = 0.0
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 0.0
@export var blast_radius: float = 5.0
@export var attack_range: float = 2.0
@export var audio_pitch: float = 1.0
@export var audio_pitch_variation: float = 0.05
@export var audio_volume_db: float = 0.0
@export var screen_shake_trauma: float = 0.2
@export var fire_audio: AudioStream
@export_group("Spin-Up")
@export var has_spin_up: bool = false
@export var spin_up_time: float = 0.8
@export var spin_down_time: float = 1.5
@export var min_fire_rate: float = 5.0
@export var max_fire_rate: float = 20.0
@export var spin_spread_max: float = 3.0
@export var spin_audio: AudioStream
@export var spin_audio_pitch_max: float = 1.5
@export_group("Visuals")
@export var visual_recoil_amount: float = 0.1
@export var visual_recoil_recovery: float = 10.0
@export var weapon_bob_amount: float = 0.04
@export var weapon_bob_freq: float = 2.0
@export var view_model_offset: Vector3 = Vector3(0.25, -0.25, -0.5)
@export var view_model_rotation: Vector3 = Vector3.ZERO
@export var view_model_scale: Vector3 = Vector3.ONE
@export var muzzle_flash_offset: Vector3 = Vector3(0, 0, -0.5)
@export var tracer_color: Color = Color(1.0, 0.8, 0.2)
@export var tracer_width: float = 0.05
@export var cartridge_eject_enabled: bool = false
@export var cartridge_eject_offset: Vector3 = Vector3(0.2, 0.0, 0.5)
@export var cartridge_scale: float = 1.0
@export var cartridge_scene_path: String = "res://game/scenes/effects/shell_casing.tscn"
@export_group("Affixes")
@export var prefix_index: int = -1
@export var suffix_index: int = -1

var id: String = ""

var _prefix_affix: WeaponAffix = null
var _suffix_affix: WeaponAffix = null


func get_prefix_affix() -> WeaponAffix:
	if prefix_index < 0:
		return null
	if not _prefix_affix:
		var all_prefixes: Array[WeaponAffix] = WeaponAffix.get_all_prefixes()
		if prefix_index < all_prefixes.size():
			_prefix_affix = all_prefixes[prefix_index]
	return _prefix_affix


## Get the suffix affix (cached)


func get_suffix_affix() -> WeaponAffix:
	if suffix_index < 0:
		return null
	if not _suffix_affix:
		var all_suffixes: Array[WeaponAffix] = WeaponAffix.get_all_suffixes()
		if suffix_index < all_suffixes.size():
			_suffix_affix = all_suffixes[suffix_index]
	return _suffix_affix


## Check if weapon has any status effect affixes


func has_status_effect_affix() -> bool:
	var prefix: WeaponAffix = get_prefix_affix()
	var suffix: WeaponAffix = get_suffix_affix()
	return (prefix and prefix.has_on_hit_effect()) or (suffix and suffix.has_on_hit_effect())


## Try to create a status effect from this weapon's affixes (handles roll)


func try_create_status_effect(source_id: int = -1) -> StatusEffect:
	# Check suffix first (elemental effects are usually suffixes)
	var suffix: WeaponAffix = get_suffix_affix()
	if suffix and suffix.has_on_hit_effect() and suffix.roll_for_effect():
		return suffix.create_on_hit_effect(source_id)

	# Check prefix
	var prefix: WeaponAffix = get_prefix_affix()
	if prefix and prefix.has_on_hit_effect() and prefix.roll_for_effect():
		return prefix.create_on_hit_effect(source_id)

	return null


static func from_dictionary(data: Dictionary) -> WeaponData:
	var wd: WeaponData = WeaponData.new()

	if data.has("name"):
		wd.weapon_name = data.name

	if data.has("icon") and ResourceLoader.exists(data.icon):
		wd.icon = load(data.icon)

	if data.has("stats"):
		var s: Dictionary = data.stats
		if s.has("damage"):
			wd.damage = s.damage
		if s.has("magazine_size"):
			wd.magazine_size = s.magazine_size
		if s.has("max_reserve_ammo"):
			wd.max_reserve_ammo = s.max_reserve_ammo
		if s.has("reload_time"):
			wd.reload_time = s.reload_time
		if s.has("fire_rate"):
			wd.fire_rate = s.fire_rate
		if s.has("is_automatic"):
			wd.is_automatic = s.is_automatic
		if s.has("pellet_count"):
			wd.pellet_count = s.pellet_count
		if s.has("spread_angle"):
			wd.spread_angle = s.spread_angle
		if s.has("range"):
			wd.attack_range = s.range  # Melee weapon range

		# Parse Damage Type
		if s.has("damage_type"):
			var dt_str: String = s.damage_type
			match dt_str.to_lower():
				"explosive", "explosion":
					wd.damage_type = DamageInfo.DamageType.EXPLOSIVE
				"shotgun":
					wd.damage_type = DamageInfo.DamageType.SHOTGUN
				"melee":
					wd.damage_type = DamageInfo.DamageType.MELEE
				"fire":
					wd.damage_type = DamageInfo.DamageType.FIRE
				"energy":
					wd.damage_type = DamageInfo.DamageType.ENERGY
				# Plasma treated as bullet for now unless we add PLASMA type
				"plasma":
					wd.damage_type = DamageInfo.DamageType.BULLET
				_:
					wd.damage_type = DamageInfo.DamageType.BULLET

	if data.has("projectile"):
		var p: Dictionary = data.projectile
		if p.has("speed"):
			wd.projectile_speed = p.speed
		if p.has("blast_radius"):
			wd.blast_radius = p.blast_radius
		if p.has("scene") and not p.scene.is_empty():
			wd.projectile_scene = load(p.scene)

	if data.has("visuals"):
		var v: Dictionary = data.visuals
		if v.has("recoil_amount"):
			wd.visual_recoil_amount = v.recoil_amount
		if v.has("recoil_recovery"):
			wd.visual_recoil_recovery = v.recoil_recovery
		if v.has("bob_amount"):
			wd.weapon_bob_amount = v.bob_amount
		if v.has("bob_freq"):
			wd.weapon_bob_freq = v.bob_freq

		if v.has("view_model_offset"):
			wd.view_model_offset = _parse_vector3(v.view_model_offset, wd.view_model_offset)
		if v.has("view_model_rotation"):
			wd.view_model_rotation = _parse_vector3(v.view_model_rotation, wd.view_model_rotation)
		if v.has("view_model_scale"):
			wd.view_model_scale = _parse_vector3(v.view_model_scale, wd.view_model_scale)
		if v.has("muzzle_flash_offset"):
			wd.muzzle_flash_offset = _parse_vector3(v.muzzle_flash_offset, wd.muzzle_flash_offset)

		if v.has("tracer"):
			var t: Dictionary = v.tracer
			if t.has("color"):
				wd.tracer_color = _parse_color(t.color, wd.tracer_color)
			if t.has("width"):
				wd.tracer_width = t.width

		if v.has("cartridge_eject"):
			var ce_data: Variant = v.cartridge_eject
			if ce_data is bool:
				wd.cartridge_eject_enabled = ce_data
			elif ce_data is Dictionary:
				wd.cartridge_eject_enabled = true
				if ce_data.has("offset"):
					wd.cartridge_eject_offset = _parse_vector3(
						ce_data.offset, wd.cartridge_eject_offset
					)
				if ce_data.has("scale"):
					wd.cartridge_scale = float(ce_data.scale)
				if ce_data.has("scene_path"):
					wd.cartridge_scene_path = str(ce_data.scene_path)

	if data.has("spin"):
		var sp: Dictionary = data.spin
		if sp.has("has_spin_up"):
			wd.has_spin_up = sp.has_spin_up
		if sp.has("spin_up_time"):
			wd.spin_up_time = sp.spin_up_time
		if sp.has("spin_down_time"):
			wd.spin_down_time = sp.spin_down_time
		if sp.has("min_fire_rate"):
			wd.min_fire_rate = sp.min_fire_rate
		if sp.has("max_fire_rate"):
			wd.max_fire_rate = sp.max_fire_rate
		if sp.has("spin_spread_max"):
			wd.spin_spread_max = sp.spin_spread_max
		if sp.has("audio") and ResourceLoader.exists(sp.audio):
			wd.spin_audio = load(sp.audio)

	if data.has("audio"):
		var a: Dictionary = data.audio
		if a.has("pitch"):
			wd.audio_pitch = a.pitch
		if a.has("pitch_variation"):
			wd.audio_pitch_variation = a.pitch_variation
		if a.has("volume_db"):
			wd.audio_volume_db = a.volume_db
		if a.has("shake_trauma"):
			wd.screen_shake_trauma = a.shake_trauma
		if a.has("fire_sound") and ResourceLoader.exists(a.fire_sound):
			wd.fire_audio = load(a.fire_sound)

	return wd


static func _parse_vector3(val: Variant, default: Vector3) -> Vector3:
	if val is Array and val.size() >= 3:
		return Vector3(val[0], val[1], val[2])
	if val is Dictionary:
		return Vector3(val.get("x", default.x), val.get("y", default.y), val.get("z", default.z))
	return default


static func _parse_color(val: Variant, default: Color) -> Color:
	if val is Dictionary:
		return Color(
			val.get("r", default.r),
			val.get("g", default.g),
			val.get("b", default.b),
			val.get("a", default.a)
		)
	if val is Array and val.size() >= 3:
		return Color(val[0], val[1], val[2], val[3] if val.size() > 3 else 1.0)
	if val is String:
		return Color(val)
	return default
