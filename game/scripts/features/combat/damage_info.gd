class_name DamageInfo
extends Resource

enum DamageType {
	GENERIC,  ## Standard damage
	BULLET,  ## Hitscan/projectile firearm damage
	EXPLOSIVE,  ## AOE explosive damage
	EXPLOSION,  ## Alias for EXPLOSIVE
	MELEE,  ## Physical melee attacks
	FIRE,  ## Damage over time - Burn
	POISON,  ## Damage over time - Poison
	BLEED,  ## Damage over time - Bleeding
	FREEZE,  ## Freeze/ice damage
	FALL,  ## Environmental fall damage
	VOID,  ## Kill volumes / out of bounds
	CRITICAL,  ## Critical hit damage (visual feedback)
	SHOTGUN,  ## Shotgun pellets (special gib rules)
	ENERGY  ## High-damage energy weapons (Nuker 3000, Railgun, etc.)
}

@export_group("Damage Properties")
@export var base_amount: float = 0.0
@export var damage_type: DamageType = DamageType.GENERIC
@export var target_armor: float = 0.0
@export var armor_penetration: float = 0.0  ## 0.0 to 1.0 (percent of armor ignored)
@export_group("Critical Hit")
@export var is_critical: bool = false
@export var critical_multiplier: float = 2.0
@export_group("Physics")
@export var knockback_force: float = 0.0
@export var knockback_multiplier: float = 1.0  ## Damage type knockback multiplier
@export var knockback_direction: Vector3 = Vector3.ZERO
@export var hit_position: Vector3 = Vector3.ZERO
@export var hit_normal: Vector3 = Vector3.UP
@export_group("Source Info")
@export var weapon_source: Resource = null
@export var weapon_id: String = ""  ## String ID for network reliability
@export var source_id: int = -1  ## Network ID of source

var source: Node3D = null
var final_damage: float = 0.0
var overkill_damage: float = 0.0  ## Damage dealt beyond target's remaining health


static func create(
	amount: float, type: DamageType = DamageType.GENERIC, src: Node3D = null
) -> DamageInfo:
	var info: DamageInfo = DamageInfo.new()
	info.base_amount = amount
	info.damage_type = type
	info.source = src
	if src and src.has_method("get_multiplayer_authority"):
		info.source_id = src.get_multiplayer_authority()
	return info


func get_damage_color() -> Color:
	match damage_type:
		DamageType.GENERIC:
			return Color.WHITE
		DamageType.BULLET:
			return Color.LIGHT_GRAY
		DamageType.EXPLOSIVE:
			return Color.ORANGE_RED
		DamageType.EXPLOSION:
			return Color.ORANGE_RED
		DamageType.MELEE:
			return Color.RED
		DamageType.FIRE:
			return Color.ORANGE
		DamageType.POISON:
			return Color.LIME_GREEN
		DamageType.BLEED:
			return Color.DARK_RED
		DamageType.FREEZE:
			return Color.LIGHT_BLUE
		DamageType.FALL:
			return Color.DIM_GRAY
		DamageType.VOID:
			return Color.BLACK
		DamageType.ENERGY:
			return Color.CYAN
	return Color.WHITE
