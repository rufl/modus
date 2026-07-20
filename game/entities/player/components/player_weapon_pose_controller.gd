extends Node

## Manages upper body animation poses based on current weapon.
## Subscribes to weapon_switched and sets the appropriate
## pistol/rifle/melee pose on the SkeletalCharacterVisuals.

var _weapon_manager: WeaponManager = null
var _visuals: SkeletalCharacterVisuals = null


func setup(weapon_manager: WeaponManager, visuals: SkeletalCharacterVisuals) -> void:
	_weapon_manager = weapon_manager
	_visuals = visuals

	if _weapon_manager:
		_weapon_manager.weapon_switched.connect(_on_weapon_switched)

	# Set initial pose
	call_deferred("update_pose")


func _exit_tree() -> void:
	if _weapon_manager and _weapon_manager.weapon_switched.is_connected(_on_weapon_switched):
		_weapon_manager.weapon_switched.disconnect(_on_weapon_switched)


func _on_weapon_switched(_w_name: String) -> void:
	update_pose()


func update_pose() -> void:
	## Update upper body animation based on current weapon.
	if not _visuals or not _weapon_manager:
		return

	var weapon: WeaponData = _weapon_manager.get_current_weapon()
	if not weapon:
		if _visuals.has_method("disable_upper_body_override"):
			_visuals.disable_upper_body_override()
		return

	var wn: String = weapon.weapon_name.to_lower()

	if "pistol" in wn or "handgun" in wn:
		_visuals.set_pistol_aim("neutral")
	elif _is_two_handed(wn):
		if _visuals.has_method("set_rifle_aim"):
			_visuals.set_rifle_aim("neutral")
		else:
			_visuals.set_pistol_aim("neutral")
	elif "knife" in wn or "melee" in wn:
		if _visuals.has_method("disable_upper_body_override"):
			_visuals.disable_upper_body_override()
	else:
		_visuals.set_pistol_aim("neutral")


func _is_two_handed(wn: String) -> bool:
	## Check if weapon name maps to a two-handed category.
	var two_handed_keywords: Array[String] = [
		"rifle",
		"shotgun",
		"machinegun",
		"chaingun",
		"smg",
		"launcher",
		"blaster",
		"railgun",
		"bfg",
	]
	for kw: String in two_handed_keywords:
		if kw in wn:
			return true
	return false
