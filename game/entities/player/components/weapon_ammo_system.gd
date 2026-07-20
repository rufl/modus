class_name WeaponAmmoSystem
extends GameComponent

## Manages ammunition tracking, reloading, and persistence
## Extracted from WeaponManager for better separation of concerns

signal ammo_changed(current: int, reserve: int, weapon: String)
signal reload_started(duration: float)
signal reload_finished

var weapon_ammo: Array[Array] = []  # [current, reserve] per weapon
var is_reloading: bool = false

var _weapon_inventory: WeaponInventory


func setup(inventory: WeaponInventory) -> void:
	_weapon_inventory = inventory


func initialize_ammo(weapons: Array[WeaponData]) -> void:
	weapon_ammo.clear()
	for weapon: WeaponData in weapons:
		weapon_ammo.append([weapon.magazine_size, weapon.max_reserve_ammo])


func get_current_ammo() -> Array:
	var idx: int = _weapon_inventory.current_weapon_index
	if weapon_ammo.is_empty() or idx >= weapon_ammo.size():
		return [0, 0]
	return weapon_ammo[idx]


func get_ammo_for_weapon(weapon_idx: int) -> Dictionary:
	## Get ammo data for a specific weapon index
	## Returns: {"current": int, "reserve": int}
	if weapon_idx < 0 or weapon_idx >= weapon_ammo.size():
		return {"current": 0, "reserve": 0}

	var ammo: Array = weapon_ammo[weapon_idx]
	return {"current": ammo[0], "reserve": ammo[1]}


func consume_ammo(weapon_idx: int, amount: int = 1) -> bool:
	if weapon_idx < 0 or weapon_idx >= weapon_ammo.size():
		return false

	var ammo: Array = weapon_ammo[weapon_idx]
	if ammo[0] < amount:
		return false

	ammo[0] -= amount
	emit_ammo_update()
	return true


func sync_ammo(weapon_idx: int, current: int, reserve: int) -> void:
	if weapon_idx >= 0 and weapon_idx < weapon_ammo.size():
		weapon_ammo[weapon_idx] = [current, reserve]
		if weapon_idx == _weapon_inventory.current_weapon_index:
			emit_ammo_update()


func start_reload() -> void:
	var weapon: WeaponData = _weapon_inventory.get_current_weapon()
	var ammo: Array = get_current_ammo()

	if not weapon or ammo[0] >= weapon.magazine_size or ammo[1] <= 0:
		return

	is_reloading = true
	reload_started.emit(weapon.reload_time)

	# Play reload sound
	if GameManager.get_core_system("audio"):
		GameManager.get_core_system("audio").play_event("reload", Vector3.ZERO)

	await get_tree().create_timer(weapon.reload_time).timeout

	if not is_reloading:  # Cancelled
		return

	_finish_reload()


func _finish_reload() -> void:
	var weapon: WeaponData = _weapon_inventory.get_current_weapon()
	var ammo: Array = get_current_ammo()

	if not weapon:
		is_reloading = false
		return

	var needed: int = weapon.magazine_size - ammo[0]
	var available: int = ammo[1]
	var to_reload: int = mini(needed, available)

	ammo[0] += to_reload
	ammo[1] -= to_reload

	is_reloading = false
	reload_finished.emit()
	emit_ammo_update()


func cancel_reload() -> void:
	is_reloading = false


func emit_ammo_update() -> void:
	var weapon: WeaponData = _weapon_inventory.get_current_weapon()
	var ammo: Array = get_current_ammo()
	if weapon:
		ammo_changed.emit(ammo[0], ammo[1], weapon.weapon_name)


func get_ammo_data() -> Dictionary:
	var data: Dictionary = {}
	var weapons: Array[WeaponData] = _weapon_inventory.weapons

	for i in weapons.size():
		var weapon: WeaponData = weapons[i]
		if i < weapon_ammo.size():
			var ammo: Array = weapon_ammo[i].duplicate()
			data[weapon.weapon_name] = ammo

	return data


func apply_ammo_data(data: Dictionary) -> void:
	var weapons: Array[WeaponData] = _weapon_inventory.weapons

	for i in weapons.size():
		var weapon: WeaponData = weapons[i]
		if data.has(weapon.weapon_name):
			var saved_ammo: Array = data[weapon.weapon_name]
			if saved_ammo.size() >= 2:
				weapon_ammo[i] = [int(saved_ammo[0]), int(saved_ammo[1])]

	# Update UI if needed
	if _weapon_inventory.current_weapon_index >= 0:
		emit_ammo_update()


func can_fire() -> bool:
	var ammo: Array = get_current_ammo()
	return not is_reloading and ammo[0] > 0


func refill_all_ammo() -> void:
	## Refills all weapons to maximum ammo (used on respawn)
	var weapons: Array[WeaponData] = _weapon_inventory.weapons

	for i in weapons.size():
		if i < weapon_ammo.size():
			var weapon: WeaponData = weapons[i]
			weapon_ammo[i] = [weapon.magazine_size, weapon.max_reserve_ammo]

	# Update UI for current weapon
	emit_ammo_update()
