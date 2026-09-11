extends ModusGutTestBase

## Property Test: Weapon State Synchronization Under Rapid Switching
## Property 3: Weapon State Synchronization Under Rapid Switching
## Validates: Requirements 1.3, 11.2
## Exercises WeaponInventory, WeaponNetworkSync, and NetworkManager APIs directly.

const MAX_WEAPONS := 9

var _network_manager: Node = null


func before_each() -> void:
	await modus_setup()
	var network_service := NetworkSvc.get_service()
	if network_service:
		_network_manager = network_service.network_manager


func after_each() -> void:
	_network_manager = null
	modus_teardown()


func test_property_final_state_consistency() -> void:
	var fixture := _create_weapon_fixture("1")
	var inventory: WeaponInventory = fixture.inventory
	var observed_indices: Array[int] = []
	inventory.weapon_switched.connect(
		func(_weapon_name: String, index: int) -> void: observed_indices.append(index)
	)

	var switch_sequence: Array[int] = [0, 4, 2, 8, 1, 7]
	for index: int in switch_sequence:
		inventory.switch_to_weapon(index)
		assert_eq(inventory.current_weapon_index, index)

	assert_eq(observed_indices, switch_sequence)
	assert_eq(inventory.get_current_weapon(), inventory.weapons[switch_sequence[-1]])


func test_property_state_sync_with_rate_limiting() -> void:
	assert_not_null(_network_manager, "NetworkManager is required for rate-limit coverage")
	if not _network_manager:
		return

	var peer_id := get_instance_id()
	var method := "request_weapon_switch"
	if _network_manager._rpc_rate_limits.has(method):
		_network_manager._rpc_rate_limits[method].last_call_time.erase(peer_id)

	assert_true(_network_manager._check_rate_limit(peer_id, method))
	for attempt: int in range(4):
		assert_false(
			_network_manager._check_rate_limit(peer_id, method),
			"Rapid request %d must be rate limited" % (attempt + 2)
		)


func test_property_multi_client_consistency() -> void:
	var server_fixture := _create_weapon_fixture("1")
	var client_one := _create_weapon_fixture("2")
	var client_two := _create_weapon_fixture("3")
	var authoritative_indices: Array[int] = [3, 6, 1, 8]

	for index: int in authoritative_indices:
		server_fixture.inventory.switch_to_weapon(index)
		client_one.sync.confirm_weapon_switch(index)
		client_two.sync.confirm_weapon_switch(index)

		assert_eq(server_fixture.inventory.current_weapon_index, index)
		assert_eq(client_one.inventory.current_weapon_index, index)
		assert_eq(client_two.inventory.current_weapon_index, index)

	assert_eq(
		client_one.inventory.get_current_weapon().weapon_name,
		server_fixture.inventory.get_current_weapon().weapon_name
	)
	assert_eq(
		client_two.inventory.get_current_weapon().weapon_name,
		server_fixture.inventory.get_current_weapon().weapon_name
	)


func test_property_rejected_switches_no_change() -> void:
	var fixture := _create_weapon_fixture("1")
	var inventory: WeaponInventory = fixture.inventory
	var sync: WeaponNetworkSync = fixture.sync
	inventory.switch_to_weapon(5)

	for rejection: Dictionary in [
		{"valid_index": 5, "reason": "Rate limit exceeded"},
		{"valid_index": 5, "reason": "Unauthorized"},
		{"valid_index": 5, "reason": "Invalid weapon index"}
	]:
		sync.reject_weapon_switch(rejection.valid_index, rejection.reason)
		assert_eq(inventory.current_weapon_index, 5)
		assert_eq(inventory.get_current_weapon(), inventory.weapons[5])


func test_property_switch_confirmation_flow() -> void:
	var fixture := _create_weapon_fixture("1")
	var inventory: WeaponInventory = fixture.inventory
	var sync: WeaponNetworkSync = fixture.sync

	inventory.switch_to_weapon(0)
	sync.confirm_weapon_switch(4)
	assert_eq(inventory.current_weapon_index, 4)

	sync.reject_weapon_switch(4, "Out of ammo")
	assert_eq(inventory.current_weapon_index, 4)

	sync.confirm_weapon_switch(2)
	assert_eq(inventory.current_weapon_index, 2)


func test_property_authoritative_confirmations_converge_after_missing_updates() -> void:
	var fixture := _create_weapon_fixture("1")
	var inventory: WeaponInventory = fixture.inventory
	var sync: WeaponNetworkSync = fixture.sync
	inventory.switch_to_weapon(0)

	# A reliable authoritative confirmation repairs a client that missed prior updates.
	sync.confirm_weapon_switch(6)
	assert_eq(inventory.current_weapon_index, 6)
	sync.confirm_weapon_switch(8)
	assert_eq(inventory.current_weapon_index, 8)


func _create_weapon_fixture(player_name: String) -> Dictionary:
	var player := CharacterBody3D.new()
	player.name = player_name
	add_child_autofree(player)

	var inventory := WeaponInventory.new()
	inventory.name = "WeaponInventory_" + player_name
	add_child_autofree(inventory)
	for index: int in range(MAX_WEAPONS):
		var weapon := WeaponData.new()
		weapon.weapon_name = "TestWeapon%d" % index
		weapon.id = "test_weapon_%d" % index
		inventory.weapons.append(weapon)

	var ammo_system := WeaponAmmoSystem.new()
	ammo_system.name = "WeaponAmmoSystem_" + player_name
	add_child_autofree(ammo_system)
	ammo_system.setup(inventory)
	ammo_system.initialize_ammo(inventory.weapons)

	var sync := WeaponNetworkSync.new()
	sync.name = "WeaponNetworkSync_" + player_name
	add_child_autofree(sync)
	sync.setup(player, null, inventory, ammo_system)

	return {"inventory": inventory, "sync": sync, "ammo": ammo_system, "player": player}
