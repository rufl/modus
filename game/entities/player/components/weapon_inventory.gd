class_name WeaponInventory
extends GameComponent

## Manages weapon collection, switching, and view models
## Extracted from WeaponManager for better separation of concerns

signal weapon_switched(weapon_name: String, weapon_index: int)

var weapons: Array[WeaponData] = []
var weapon_scenes: Array[Node3D] = []
var current_weapon_index: int = 0
var weapon_holder_node: Node3D
var camera: Camera3D

var _weapon_view_model_paths: Array[String] = []
var _cached_muzzle_points: Array[Node3D] = []
var _knife_weapon_index: int = -1


func _log(message: String, category: String = "WeaponInventory") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info(message, category)
	else:
		print(message)


func _log_warning(message: String, category: String = "WeaponInventory") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.warning(message, category)
	else:
		push_warning(message)


func setup(holder: Node3D, cam: Camera3D) -> void:
	weapon_holder_node = holder
	camera = cam


func load_weapons_from_database() -> void:
	weapons.clear()
	_weapon_view_model_paths.clear()

	# Access DataService directly from GameManager
	var data_service: Node = GameManager.get_core_system("data")
	var weapons_map: Dictionary = {}

	if data_service and "weapons" in data_service:
		weapons_map = data_service.weapons
	else:
		_log_warning("[WeaponInventory] DataService not available or has no weapons")

	if weapons_map.is_empty():
		_log_warning("[WeaponInventory] No weapons in database, loading fallbacks")
		_add_fallback_weapons()
		return

	# Sort by slot
	var keys: Array = weapons_map.keys()
	keys.sort_custom(
		func(a: String, b: String) -> bool:
			var slot_a: int = weapons_map[a].get("slot", 99)
			var slot_b: int = weapons_map[b].get("slot", 99)
			return slot_a < slot_b
	)

	for id: String in keys:
		var data: Dictionary = weapons_map[id]
		if not _validate_weapon_data(id, data):
			continue

		var weapon_obj: WeaponData = WeaponData.from_dictionary(data)
		weapon_obj.id = id
		if weapon_obj.weapon_name.is_empty():
			weapon_obj.weapon_name = id.capitalize()

		weapons.append(weapon_obj)

		var vm_path: String = data.get("view_model_path", data.get("visuals", {}).get("model", ""))
		_weapon_view_model_paths.append(vm_path)

		# Register projectile pool if available
		if weapon_obj.projectile_scene:
			var pool_service: Node = GameManager.get_core_system("pools")
			if pool_service and pool_service.has_method("register_pool"):
				pool_service.register_pool(
					weapon_obj.projectile_scene.resource_path, weapon_obj.projectile_scene, 10, 50
				)

	_log("[WeaponInventory] Loaded %d weapons" % weapons.size())


func setup_weapon_models() -> void:
	_log("[WeaponInventory] setup_weapon_models called", "Player")
	_log("[WeaponInventory] weapon_holder_node: %s" % weapon_holder_node, "Player")
	_log(
		(
			"[WeaponInventory] weapon_holder_node visible: %s"
			% (str(weapon_holder_node.visible) if weapon_holder_node else "null")
		),
		"Player"
	)
	_log(
		(
			"[WeaponInventory] weapon_holder_node position: %s"
			% (str(weapon_holder_node.global_position) if weapon_holder_node else "null")
		),
		"Player"
	)
	_log("[WeaponInventory] Number of weapon paths: %d" % _weapon_view_model_paths.size(), "Player")

	for child in weapon_holder_node.get_children():
		child.queue_free()

	weapon_scenes.clear()
	_cached_muzzle_points.clear()

	for i in range(_weapon_view_model_paths.size()):
		var path: String = _weapon_view_model_paths[i]
		_log("[WeaponInventory] Loading weapon %d from path: %s" % [i, path], "Player")

		if path.is_empty() or not ResourceLoader.exists(path):
			_log("[WeaponInventory] Path empty or doesn't exist, skipping", "Player")
			continue

		var scene: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if not scene:
			_log("[WeaponInventory] Failed to load scene", "Player")
			continue

		var instance: Node3D = scene.instantiate()
		instance.name = weapons[i].weapon_name if i < weapons.size() else "weapon_" + str(i)
		instance.position = Vector3.ZERO
		weapon_holder_node.add_child(instance)
		# Don't hide on first weapon (index 0), hide all others
		if i != 0:
			instance.hide()

		_log(
			(
				"[WeaponInventory] Weapon %d instantiated: %s visible: %s global_pos: %s"
				% [i, instance.name, instance.visible, instance.global_position]
			),
			"Player"
		)
		weapon_scenes.append(instance)

		# Cache muzzle point
		var muzzle: Node3D = instance.get_node_or_null("Muzzle")
		if not muzzle:
			muzzle = instance.get_node_or_null("MuzzlePoint")
		if not muzzle:
			muzzle = instance.get_node_or_null("BarrelEnd")
		_cached_muzzle_points.append(muzzle)


func switch_to_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		_log(
			(
				"[WeaponInventory] Cannot switch to weapon %d - out of range (have %d weapons)"
				% [index, weapons.size()]
			),
			"Player"
		)
		return

	_log(
		"[WeaponInventory] Switching from weapon %d to %d" % [current_weapon_index, index], "Player"
	)

	# Hide current
	if current_weapon_index < weapon_scenes.size():
		weapon_scenes[current_weapon_index].hide()

	current_weapon_index = index

	# Show new
	if current_weapon_index < weapon_scenes.size():
		var new_weapon_node: Node3D = weapon_scenes[current_weapon_index]
		if new_weapon_node.get_parent() != weapon_holder_node:
			new_weapon_node.reparent(weapon_holder_node)
			new_weapon_node.position = Vector3.ZERO
			new_weapon_node.rotation = Vector3.ZERO
		new_weapon_node.show()
		_log(
			(
				"[WeaponInventory] Switched to weapon %d (%s) visible: %s"
				% [index, new_weapon_node.name, new_weapon_node.visible]
			),
			"Player"
		)
		_log(
			(
				"[WeaponInventory] Weapon holder visible: %s"
				% (str(weapon_holder_node.visible) if weapon_holder_node else "null")
			),
			"Player"
		)
		_log("[WeaponInventory] Weapon position: %s" % new_weapon_node.global_position, "Player")

	var weapon: WeaponData = get_current_weapon()
	if weapon:
		weapon_switched.emit(weapon.weapon_name, index)


func get_current_weapon() -> WeaponData:
	if weapons.is_empty() or current_weapon_index >= weapons.size() or current_weapon_index < 0:
		return null
	return weapons[current_weapon_index]


func get_current_weapon_scene() -> Node3D:
	if current_weapon_index < weapon_scenes.size():
		return weapon_scenes[current_weapon_index]
	return null


func get_muzzle_position(default_offset: Vector3) -> Vector3:
	var weapon: WeaponData = get_current_weapon()
	if not weapon:
		return Vector3.ZERO

	var offset: Vector3 = weapon.muzzle_flash_offset

	# Try weapon-specific muzzle point first
	if current_weapon_index < _cached_muzzle_points.size():
		var muzzle: Node3D = _cached_muzzle_points[current_weapon_index]
		if muzzle and is_instance_valid(muzzle):
			return muzzle.to_global(offset)

	# CRITICAL FIX: Start raycast from camera position + forward offset
	# This ensures shots start OUTSIDE the player's collision shape
	if camera:
		var forward: Vector3 = -camera.global_transform.basis.z
		var final_offset: Vector3 = offset if offset != Vector3.ZERO else default_offset
		# Start 0.5m in front of camera to clear player collision
		return camera.global_position + forward * 0.5 + camera.global_transform.basis * final_offset

	# Fallback: weapon holder (if camera not available)
	if weapon_holder_node and is_instance_valid(weapon_holder_node):
		var final_offset: Vector3 = offset if offset != Vector3.ZERO else default_offset
		return weapon_holder_node.to_global(final_offset)

	return Vector3.ZERO


func find_knife_index() -> int:
	if _knife_weapon_index != -1:
		return _knife_weapon_index

	for i in weapons.size():
		if weapons[i].weapon_name.to_lower().contains("knife"):
			_knife_weapon_index = i
			return i
	return -1


func apply_weapon_adjustments(adjustments: Dictionary) -> void:
	for i in range(weapon_scenes.size()):
		var node: Node3D = weapon_scenes[i]
		if not is_instance_valid(node):
			continue

		var w_name: String = weapons[i].weapon_name if i < weapons.size() else str(node.name)
		if not adjustments.has(w_name):
			continue

		var adj: Dictionary = adjustments[w_name]

		if adj.has("position"):
			node.position = _parse_v3(adj.position, node.position)
		if adj.has("rotation"):
			node.rotation_degrees = _parse_v3(adj.rotation, node.rotation_degrees)
		if adj.has("scale"):
			var s: float = float(adj.scale)
			node.scale = Vector3(s, s, s)

		if i < weapons.size():
			var w_data: WeaponData = weapons[i]
			if adj.has("muzzle_flash_offset"):
				w_data.muzzle_flash_offset = _parse_v3(
					adj.muzzle_flash_offset, w_data.muzzle_flash_offset
				)
			elif adj.has("muzzleFlashOffset"):
				w_data.muzzle_flash_offset = _parse_v3(
					adj.muzzleFlashOffset, w_data.muzzle_flash_offset
				)
			if adj.has("tracer"):
				var t: Dictionary = adj.tracer
				if t.has("color"):
					w_data.tracer_color = _parse_color(t.color, w_data.tracer_color)
				if t.has("width"):
					w_data.tracer_width = float(t.width)


func _validate_weapon_data(_weapon_id: String, data: Dictionary) -> bool:
	if not data.has("name"):
		return false

	var stats: Dictionary = data.get("stats", data)
	var required: Array[String] = ["damage", "fire_rate", "magazine_size", "max_reserve_ammo"]

	for field in required:
		if not stats.has(field):
			return false

	var damage: int = stats.get("damage", 0)
	if damage <= 0 or damage > 10000:
		return false

	var fire_rate: float = stats.get("fire_rate", 0.0)
	if fire_rate <= 0.0 or fire_rate > 100.0:
		return false

	var mag_size: int = stats.get("magazine_size", 0)
	if mag_size <= 0 or mag_size > 1000:
		return false

	return true


func _add_fallback_weapons() -> void:
	var pistol_data: Dictionary = {
		"name": "Pistol",
		"slot": 0,
		"stats":
		{
			"damage": 35,
			"fire_rate": 0.3,
			"magazine_size": 12,
			"max_reserve_ammo": 96,
			"spread_angle": 1.0,
			"pellet_count": 1,
			"reload_time": 2.0,
		}
	}

	var pistol: WeaponData = WeaponData.from_dictionary(pistol_data)
	pistol.id = "pistol"
	weapons.append(pistol)
	_weapon_view_model_paths.append("")

	var knife_data: Dictionary = {
		"name": "Knife",
		"slot": 1,
		"stats":
		{
			"damage": 25,
			"fire_rate": 0.5,
			"magazine_size": 1,
			"max_reserve_ammo": 1,
			"is_melee": true
		}
	}

	var knife: WeaponData = WeaponData.from_dictionary(knife_data)
	knife.id = "knife"
	weapons.append(knife)
	_weapon_view_model_paths.append("")


func _parse_v3(val: Variant, default: Vector3) -> Vector3:
	if val is Dictionary:
		return Vector3(val.get("x", default.x), val.get("y", default.y), val.get("z", default.z))
	if val is Array and val.size() >= 3:
		return Vector3(val[0], val[1], val[2])
	return default


func _parse_color(val: Variant, default: Color) -> Color:
	if val is Dictionary:
		return Color(
			val.get("r", default.r),
			val.get("g", default.g),
			val.get("b", default.b),
			val.get("a", default.a)
		)
	if val is String:
		return Color(val)
	return default
