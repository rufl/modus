extends GutTest

const SpawnerScript := preload("res://game/world/actors/props/loot_prop_spawner.gd")

var _roots: Array[Node3D] = []
var _apis: Array[SceneMultiplayer] = []
var _peers: Array[ENetMultiplayerPeer] = []
var _world: Node3D


func before_each() -> void:
	_world = _network_root()
	_world.position = Vector3(31, 7, -19)
	_world.rotation = Vector3(0.2, 0.7, -0.1)


func after_each() -> void:
	for root: Node3D in _roots:
		var root_path: NodePath = root.get_path()
		root.free()
		get_tree().set_multiplayer(null, root_path)
	for api: SceneMultiplayer in _apis:
		api.multiplayer_peer = null
	for peer: ENetMultiplayerPeer in _peers:
		peer.close()
	_roots.clear()
	_apis.clear()
	_peers.clear()
	await get_tree().process_frame


func _network_root() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, root.get_path())
	_roots.append(root)
	_apis.append(api)
	return root


func _marker(parent: Node, automatic: bool = false) -> LootPropSpawner:
	var marker := SpawnerScript.new()
	marker.spawn_on_ready = automatic
	marker.random_rotation = false
	marker.position = Vector3(2, 3, 5)
	marker.rotation = Vector3(-0.15, 0.4, 0.25)
	parent.add_child(marker)
	return marker


func _props(parent: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child: Node in parent.get_children():
		if child is CollisionObject3D:
			result.append(child)
	return result


func test_canonical_props_have_configured_world_transform_at_readiness() -> void:
	var parent := Node3D.new()
	parent.position = Vector3(-4, 2, 8)
	parent.rotation = Vector3(0.3, -0.6, 0.1)
	_world.add_child(parent)
	var observed: Array[Transform3D] = []
	parent.child_entered_tree.connect(
		func(child: Node) -> void:
			if child is CollisionObject3D:
				child.ready.connect(func() -> void: observed.append(child.global_transform))
	)
	var marker := _marker(parent)
	for kind in [
		LootPropSpawner.PropType.CRATE,
		LootPropSpawner.PropType.BARREL,
		LootPropSpawner.PropType.VASE,
		LootPropSpawner.PropType.CHEST,
		LootPropSpawner.PropType.CORPSE_PILE,
		LootPropSpawner.PropType.HIDDEN_STASH,
		LootPropSpawner.PropType.WEAPON_RACK
	]:
		marker.prop_type = kind
		marker.health_multiplier = 2.0
		var prop := marker.spawn_prop()
		assert_not_null(prop)
		if not prop:
			continue
		assert_eq(observed.size(), 1, "A canonical scene must enter readiness exactly once")
		if observed.size() == 1:
			assert_true(observed[0].is_equal_approx(marker.global_transform))
		assert_true(prop.global_transform.is_equal_approx(marker.global_transform))
		if prop is BreakableProp:
			prop.wobble_on_damage = false
			prop.show_damage_cracks = false
			var initial_health: float = prop.sync_health
			var damage: float = 75.0 if kind == LootPropSpawner.PropType.CRATE else 45.0
			prop.take_damage(damage)
			assert_false(
				prop.is_destroyed, "The health override must affect actual damage survival"
			)
			assert_eq(prop.sync_health, initial_health - damage)
		marker.despawn_prop()
		observed.clear()


func test_repeated_spawn_and_pending_startup_keep_exactly_one_prop() -> void:
	var marker := _marker(_world, true)
	var original := marker.spawn_prop()
	assert_not_null(original)
	assert_same(marker.spawn_prop(), original)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_props(_world), [original])
	assert_same(marker.spawned_prop, original)


func test_respawn_detaches_original_before_replacement_enters_tree() -> void:
	var marker := _marker(_world)
	var original := marker.spawn_prop()
	var counts_at_ready: Array[int] = []
	_world.child_entered_tree.connect(
		func(child: Node) -> void:
			if child is BreakableProp:
				child.ready.connect(func() -> void: counts_at_ready.append(_props(_world).size()))
	)
	marker.respawn_prop()
	var replacement := marker.spawned_prop
	assert_not_null(replacement)
	assert_ne(replacement, original)
	assert_false(original.is_inside_tree())
	assert_true(original.is_queued_for_deletion())
	assert_eq(counts_at_ready, [1])
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_props(_world), [replacement])
	assert_same(marker.spawned_prop, replacement, "Old deletion must not clear the replacement")


func test_external_removal_and_queued_deletion_allow_clean_replacement() -> void:
	var marker := _marker(_world)
	var original := marker.spawn_prop()
	_world.remove_child(original)
	assert_null(marker.spawned_prop)
	assert_true(marker.visible)
	original.free()
	var next := marker.spawn_prop()
	next.queue_free()
	var replacement := marker.spawn_prop()
	assert_ne(replacement, next)
	assert_false(next.is_inside_tree())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_same(marker.spawned_prop, replacement)
	assert_eq(_props(_world), [replacement])


func test_despawn_cancels_pending_automatic_spawn() -> void:
	var marker := _marker(_world, true)
	marker.despawn_prop()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_props(_world).size(), 0)
	assert_null(marker.spawned_prop)


func test_removing_and_readding_marker_cancels_its_old_deferred_startup() -> void:
	var marker := _marker(_world, true)
	_world.remove_child(marker)
	assert_null(marker.spawn_prop(), "Detached markers cannot materialize props")
	_world.add_child(marker)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_props(_world).size(), 0)
	assert_null(marker.spawned_prop)


func test_queued_marker_never_materializes_a_prop_and_live_teardown_releases_ownership() -> void:
	var observed: Array[Node] = []
	_world.child_entered_tree.connect(
		func(child: Node) -> void:
			if child is BreakableProp:
				observed.append(child)
	)
	var pending_marker := _marker(_world, true)
	pending_marker.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(observed.size(), 0, "Queued startup must not briefly instantiate before deletion")
	var marker := _marker(_world)
	var prop := marker.spawn_prop()
	_world.remove_child(marker)
	marker.free()
	assert_true(prop.is_queued_for_deletion())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_props(_world).size(), 0, "Removing a marker must not strand its sibling prop")


func test_enet_client_cannot_spawn_despawn_or_respawn_authoritative_props() -> void:
	var client_root := _network_root()
	# Start offline, then transfer the subtree to a real connected client. This
	# exercises authority loss while an existing live prop remains tracked.
	var client_marker := _marker(client_root)
	var retained := client_marker.spawn_prop()
	var server := ENetMultiplayerPeer.new()
	var client := ENetMultiplayerPeer.new()
	_peers.append(server)
	_peers.append(client)
	assert_eq(server.create_server(0), OK)
	_world.multiplayer.multiplayer_peer = server
	assert_eq(client.create_client("127.0.0.1", server.get_host().get_local_port()), OK)
	client_root.multiplayer.multiplayer_peer = client
	for attempt in range(120):
		if client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break
		await get_tree().create_timer(0.01).timeout
	assert_eq(client.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED)
	assert_false(client_root.multiplayer.is_server())
	assert_null(client_marker.spawn_prop())
	client_marker.despawn_prop()
	client_marker.respawn_prop()
	assert_same(client_marker.spawned_prop, retained)
	assert_true(retained.is_inside_tree())
	assert_false(retained.is_queued_for_deletion())
	var fresh_client_marker := _marker(client_root, true)
	assert_null(fresh_client_marker.spawn_prop())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(fresh_client_marker.spawned_prop)
	assert_eq(_props(client_root), [retained])
	client_root.remove_child(client_marker)
	client_marker.free()
	assert_false(
		retained.is_queued_for_deletion(), "Client teardown cannot delete authoritative props"
	)
	var server_marker := _marker(_world)
	var server_prop := server_marker.spawn_prop()
	assert_not_null(server_prop)
	server_marker.respawn_prop()
	assert_eq(_props(_world), [server_marker.spawned_prop])
	server_marker.despawn_prop()
	assert_eq(_props(_world).size(), 0)
