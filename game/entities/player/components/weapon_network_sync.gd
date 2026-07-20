class_name WeaponNetworkSync
extends GameComponent

## Handles all weapon-related network synchronization
## Extracted from WeaponManager for better separation of concerns

var player: CharacterBody3D
var camera: Camera3D

var _weapon_inventory: WeaponInventory
var _ammo_system: WeaponAmmoSystem
var _switch_in_progress: bool = false  # Atomic flag to prevent race condition


func setup(
	p_player: CharacterBody3D, cam: Camera3D, inventory: WeaponInventory, ammo: WeaponAmmoSystem
) -> void:
	player = p_player
	camera = cam
	_weapon_inventory = inventory
	_ammo_system = ammo


@rpc("any_peer", "call_remote", "reliable")
func request_weapon_switch(index: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()

	# Atomic check - prevent race condition from multiple RPC calls
	if _switch_in_progress:
		push_warning("[WeaponNetworkSync] Weapon switch already in progress - rejecting duplicate")
		reject_weapon_switch.rpc_id(
			sender_id, _weapon_inventory.current_weapon_index, "Switch in progress"
		)
		return

	_switch_in_progress = true

	var ns := GameManager.get_core_system("network") as NetworkSvc

	# CRITICAL: Validate RPC with correct method name
	if (
		ns
		and ns.network_manager
		and not ns.network_manager.validate_rpc(sender_id, "request_weapon_switch", [index])
	):
		# Rate limit exceeded - reject
		reject_weapon_switch.rpc_id(
			sender_id, _weapon_inventory.current_weapon_index, "Rate limit exceeded"
		)
		_switch_in_progress = false
		return

	# Verify sender is the player
	if sender_id != player.name.to_int():
		push_warning("[WeaponNetworkSync] Unauthorized weapon switch from peer %d" % sender_id)
		reject_weapon_switch.rpc_id(
			sender_id, _weapon_inventory.current_weapon_index, "Unauthorized"
		)
		_switch_in_progress = false
		return

	# Validate weapon index
	if index < 0 or index >= _weapon_inventory.weapons.size():
		var log_msg: String = (
			"[WeaponNetworkSync] Invalid weapon index from peer %d: %d (rejected)"
			% [sender_id, index]
		)
		push_warning(log_msg)
		if GameManager and GameManager.get_core_system("logger"):
			GameManager.get_core_system("logger").warning(log_msg, "WeaponNetworkSync")
		reject_weapon_switch.rpc_id(
			sender_id, _weapon_inventory.current_weapon_index, "Invalid weapon index"
		)
		_switch_in_progress = false
		return

	# Check if weapon has ammo (prevent switching to empty weapon)
	if _ammo_system:
		var weapon: WeaponData = _weapon_inventory.weapons[index]
		if weapon:
			var ammo_data: Dictionary = _ammo_system.get_ammo_for_weapon(index)
			var current_ammo: int = ammo_data.get("current", 0)
			var reserve_ammo: int = ammo_data.get("reserve", 0)

			# Allow switch if weapon has any ammo OR is a melee weapon
			if current_ammo == 0 and reserve_ammo == 0 and not weapon.is_melee:
				reject_weapon_switch.rpc_id(
					sender_id, _weapon_inventory.current_weapon_index, "Out of ammo"
				)
				_switch_in_progress = false
				return

	# SUCCESS: Switch weapon
	_weapon_inventory.current_weapon_index = index

	# Confirm to client (optional, but good for feedback)
	confirm_weapon_switch.rpc_id(sender_id, index)

	# Reset atomic flag
	_switch_in_progress = false


@rpc("authority", "call_remote", "reliable")
func reject_weapon_switch(valid_index: int, reason: String = "") -> void:
	## Server rejected weapon switch - rollback to valid index
	var log_msg: String = "[WeaponNetworkSync] Weapon switch rejected"
	if reason:
		log_msg += ": " + reason
	log_msg += ". Rolling back to index %d" % valid_index

	if GameManager and GameManager.get_core_system("logger"):
		GameManager.get_core_system("logger").warning(log_msg, "WeaponNetworkSync")

	# Rollback to valid weapon
	_weapon_inventory.switch_to_weapon(valid_index)

	# Show UI feedback to player
	var ui_svc: Node = GameManager.get_core_system("ui")
	if ui_svc and ui_svc.has_method("show_notification"):
		ui_svc.show_notification("Cannot switch weapon: " + reason, 2.0)


@rpc("authority", "call_remote", "reliable")
func confirm_weapon_switch(index: int) -> void:
	## Server confirmed weapon switch - ensure client is in sync
	if _weapon_inventory.current_weapon_index != index:
		if GameManager and GameManager.get_core_system("logger"):
			GameManager.get_core_system("logger").info(
				"[WeaponNetworkSync] Server confirmed switch to %d, syncing" % index,
				"WeaponNetworkSync"
			)
		_weapon_inventory.switch_to_weapon(index)


@rpc("authority", "call_local", "unreliable")
func sync_fire_fx(w_name: String, cam_pos: Vector3, cam_dir: Vector3, _w_idx: int) -> void:
	# Play sound
	if GameManager and GameManager.get_core_system("audio"):
		GameManager.get_core_system("audio").play_event("shoot", cam_pos)

	GameManager.emit_event(
		"weapon_fired", {"weapon_name": w_name, "position": cam_pos, "direction": cam_dir}
	)


@rpc("call_remote", "reliable")
func sync_ammo(w_idx: int, current: int, reserve: int) -> void:
	_ammo_system.sync_ammo(w_idx, current, reserve)


func request_fire_to_server(muzzle_pos: Vector3, direction: Vector3, weapon_idx: int) -> void:
	if multiplayer.is_server():
		return

	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.combat:
		gs.combat.request_fire.rpc_id(1, muzzle_pos, direction, weapon_idx)


func broadcast_fire_effects(
	weapon_name: String, origin: Vector3, direction: Vector3, weapon_idx: int
) -> void:
	sync_fire_fx.rpc(weapon_name, origin, direction, weapon_idx)


func sync_ammo_to_client(weapon_idx: int, current: int, reserve: int, sender_id: int) -> void:
	if sender_id != multiplayer.get_unique_id():
		sync_ammo.rpc_id(sender_id, weapon_idx, current, reserve)
	else:
		# Listen server - update locally
		_ammo_system.sync_ammo(weapon_idx, current, reserve)
