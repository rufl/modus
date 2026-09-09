extends ModusGutTestBase

const MovementScript = preload("res://game/entities/player/components/player_movement_component.gd")


class Effects:
	extends StatusEffectManager

	func _spawn_effect_visual(_effect: StatusEffect) -> void:
		pass


class DamageTarget:
	extends Node3D
	var received: float = 0.0

	func take_damage(info: DamageInfo) -> void:
		received = info.base_amount


var _roots: Array[Node] = []
var _apis: Array[SceneMultiplayer] = []
var _peers: Array[ENetMultiplayerPeer] = []


func before_each() -> void:
	await modus_setup()


func after_each() -> void:
	for root: Node in _roots:
		var path := root.get_path()
		root.free()
		get_tree().set_multiplayer(null, path)
	for api: SceneMultiplayer in _apis:
		api.multiplayer_peer = null
	for peer: ENetMultiplayerPeer in _peers:
		peer.close()
	_roots.clear()
	_apis.clear()
	_peers.clear()
	modus_teardown()


func _effects(peer: ENetMultiplayerPeer = null, owner_id: int = 1) -> Effects:
	var root := Node.new()
	add_child(root)
	_roots.append(root)
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, root.get_path())
	_apis.append(api)
	if peer:
		api.multiplayer_peer = peer
	var actor := CharacterBody3D.new()
	actor.name = "Player"
	actor.add_to_group("player")
	actor.set_multiplayer_authority(owner_id)
	root.add_child(actor)
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	actor.add_child(health)
	var effects := Effects.new()
	effects.name = "StatusEffectManager"
	effects.set_multiplayer_authority(owner_id)
	actor.add_child(effects)
	return effects


func test_duration_refresh_coexistence_and_base_stats() -> void:
	var effects := _effects()
	var player := Player.new()
	autofree(player)
	player.status_effect_manager = effects
	player.speed_multiplier = 2.0
	player.damage_multiplier = 3.0
	var movement := MovementScript.new()
	autofree(movement)
	movement.player = player
	movement.move_speed = 8.0
	assert_true(effects.apply_consumable_buff("buff_speed", 2.0))
	assert_true(effects.apply_consumable_buff("buff_damage", 4.0))
	movement._ground_move(Vector3.FORWARD, 1.0)
	assert_eq(player.velocity.z, -24.0)
	assert_eq(player.get_outgoing_damage_modifier(), 3.75)
	effects._process(1.5)
	assert_true(effects.apply_consumable_buff("buff_speed", 3.0))
	effects._process(1.0)
	assert_eq(movement.get_effective_move_speed(), 24.0, "Refresh must not multiply stacks")
	effects._process(1.5)
	assert_eq(player.get_outgoing_damage_modifier(), 3.0, "Damage expires independently")
	assert_eq(movement.get_effective_move_speed(), 24.0)
	effects._process(0.5)
	player.velocity = Vector3.ZERO
	movement._ground_move(Vector3.FORWARD, 1.0)
	assert_eq(player.velocity.z, -16.0)
	assert_eq(movement.move_speed, 8.0, "Buffs must not overwrite configured movement")
	assert_eq(player.speed_multiplier, 2.0)
	assert_eq(player.damage_multiplier, 3.0)


func test_invalid_duration_dead_player_and_clear() -> void:
	var effects := _effects()
	for duration: float in [0.0, -1.0, INF, NAN]:
		assert_false(effects.apply_consumable_buff("buff_speed", duration))
	assert_false(effects.apply_consumable_buff("unknown", 1.0))
	assert_true(effects.apply_consumable_buff("buff_speed", 10.0))
	assert_true(effects.apply_consumable_buff("buff_damage", 10.0))
	var health := effects.get_parent().get_node("HealthComponent") as HealthComponent
	health.current_health = 0.0
	health.died.emit(0)
	assert_eq(effects.get_movement_modifier(), 1.0)
	assert_eq(effects.get_damage_modifier(), 1.0)
	assert_false(effects.apply_consumable_buff("buff_damage", 1.0))
	health.current_health = 100.0
	assert_true(effects.apply_consumable_buff("buff_damage", 10.0))
	effects.remove_all_effects()
	assert_eq(effects.get_damage_modifier(), 1.0)


func test_combat_dispatch_uses_buff_once_then_restores_baseline() -> void:
	var effects := _effects()
	var player := Player.new()
	autofree(player)
	player.status_effect_manager = effects
	var combat := CombatSvc.new()
	effects.get_parent().get_parent().add_child(combat)
	var target := DamageTarget.new()
	effects.get_parent().get_parent().add_child(target)
	assert_true(effects.apply_consumable_buff("buff_damage", 2.0))
	combat.apply_damage(target, 40.0, player, DamageInfo.DamageType.BULLET)
	assert_eq(target.received, 50.0)
	combat.apply_damage(target, 80.0, player, DamageInfo.DamageType.EXPLOSIVE)
	assert_eq(target.received, 100.0)
	effects._process(2.0)
	combat.apply_damage(target, 40.0, player, DamageInfo.DamageType.BULLET)
	assert_eq(target.received, 40.0)


func _wait_for_network(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await get_tree().process_frame
	return false


func test_enet_client_owned_player_refresh_expiry_and_forgery() -> void:
	var server := ENetMultiplayerPeer.new()
	_peers.append(server)
	assert_eq(server.create_server(0), OK)
	var authoritative := _effects(server)
	var client := ENetMultiplayerPeer.new()
	_peers.append(client)
	assert_eq(client.create_client("127.0.0.1", server.get_host().get_local_port()), OK)
	var replica := _effects(client)
	var connected := func() -> bool:
		return (
			client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
			and authoritative.multiplayer.get_peers().has(client.get_unique_id())
		)
	assert_true(await _wait_for_network(connected))
	var owner_id := client.get_unique_id()
	authoritative.get_parent().set_multiplayer_authority(owner_id)
	replica.get_parent().set_multiplayer_authority(owner_id)
	assert_true(authoritative.apply_consumable_buff("buff_speed", 5.0))
	authoritative.set_process(false)
	assert_true(
		await _wait_for_network(func() -> bool: return replica.get_movement_modifier() == 1.5)
	)
	assert_false(replica.apply_consumable_buff("buff_damage", 100.0))
	var forged := StatusEffect.new()
	forged.effect_type = StatusEffect.EffectType.SPEED_BUFF
	forged.movement_speed_modifier = 100.0
	replica.apply_effect(forged)
	replica.rpc_id(1, "_sync_effect_applied", forged.to_dict())
	replica.active_effects.clear()
	replica.rpc_id(1, "_request_effects")
	assert_true(
		await _wait_for_network(func() -> bool: return replica.get_movement_modifier() == 1.5)
	)
	assert_eq(authoritative.get_movement_modifier(), 1.5, "Owning client cannot publish buffs")
	assert_true(authoritative.apply_consumable_buff("buff_speed", 8.0))
	assert_true(
		await _wait_for_network(func() -> bool: return replica.active_effects[0].duration == 8.0)
	)
	authoritative.set_process(false)
	authoritative._process(8.0)
	assert_true(
		await _wait_for_network(func() -> bool: return replica.get_movement_modifier() == 1.0)
	)
