class_name WeaponPersistence
extends GameComponent

var _manager: Node3D


func setup(manager: Node3D) -> void:
	_manager = manager


func get_data() -> Dictionary:
	if not _manager:
		return {}

	var data: Dictionary = {}
	var weapons: Array = _manager.weapons
	var weapon_ammo: Array = _manager.weapon_ammo

	for i in weapons.size():
		var weapon: Resource = weapons[i]  # WeaponData is a resource
		if i < weapon_ammo.size():
			var ammo: Array = weapon_ammo[i].duplicate()
			# Key by weapon name for stability across loadouts
			if weapon and "weapon_name" in weapon:
				data[weapon.weapon_name] = ammo

	return data


func apply_data(data: Dictionary) -> void:
	if not _manager:
		return

	var weapons: Array = _manager.weapons
	var weapon_ammo: Array = _manager.weapon_ammo
	var changed: bool = false

	for i in weapons.size():
		var weapon: Resource = weapons[i]
		if weapon and "weapon_name" in weapon:
			var w_name: String = weapon.weapon_name
			if data.has(w_name):
				var saved_ammo: Array = data[w_name]

				# Validation
				if saved_ammo.size() >= 2:
					# Current, Reserve
					weapon_ammo[i] = [int(saved_ammo[0]), int(saved_ammo[1])]

					# Server syncs to client
					if (
						_manager.multiplayer.is_server()
						and _manager.player
						and _manager.player.name.to_int() != 1
					):
						if _manager.has_method("sync_ammo"):
							_manager.sync_ammo.rpc_id(
								_manager.player.name.to_int(),
								i,
								int(saved_ammo[0]),
								int(saved_ammo[1])
							)

					# Notify logic if currently equipped
					if i == _manager.current_weapon_index:
						changed = true

	if changed:
		# Refresh UI/State
		var current_ammo: Array = _manager.get_current_ammo()
		_manager.ammo_changed.emit(
			current_ammo[0], current_ammo[1], _manager.get_current_weapon().weapon_name
		)
