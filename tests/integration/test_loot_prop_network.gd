extends ModusGutTestBase

const SpawnerScript := preload("res://game/world/actors/props/loot_prop_spawner.gd")

var _roots: Array[Node3D] = []
var _apis: Array[SceneMultiplayer] = []
var _peers: Array[ENetMultiplayerPeer] = []
var _server: Node3D
var _previous_scene: Node
var _registry: Node
var _registered_peer: int = 0
var _loot: LootSvc
var _previous_beacons: bool


func before_each() -> void:
	await modus_setup()
	_previous_scene = get_tree().current_scene
	var gameplay := GameManager.get_core_system("gameplay") as GameplaySvc
	_registry = gameplay.entity_registry
	_loot = gameplay.loot
	_previous_beacons = _loot.spawn_beacons
	_loot.spawn_beacons = false
	_server = _network_root()
	var peer := ENetMultiplayerPeer.new()
	_peers.append(peer)
	assert_eq(peer.create_server(0), OK)
	_server.multiplayer.multiplayer_peer = peer
	get_tree().current_scene = _server


func after_each() -> void:
	if _registered_peer:
		_registry.unregister_player(_registered_peer)
	_registered_peer = 0
	_loot.spawn_beacons = _previous_beacons
	get_tree().current_scene = _previous_scene
	for root: Node3D in _roots:
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


func _network_root() -> Node3D:
	var root := Node3D.new()
	get_tree().root.add_child(root)
	_roots.append(root)
	var api := SceneMultiplayer.new()
	_apis.append(api)
	get_tree().set_multiplayer(api, root.get_path())
	var replicator := MultiplayerSpawner.new()
	replicator.name = "MultiplayerSpawner"
	replicator.spawn_path = NodePath("..")
	for path: String in SpawnerScript.PROP_SCENES.values():
		replicator.add_spawnable_scene(path)
	for path: String in LootSvc.ITEM_SCENE_MAP.values():
		if (
			replicator.get_spawnable_scene_count() == 0
			or path not in _registered_scenes(replicator)
		):
			replicator.add_spawnable_scene(path)
	root.add_child(replicator)
	return root


func _registered_scenes(spawner: MultiplayerSpawner) -> Array[String]:
	var paths: Array[String] = []
	for index: int in range(spawner.get_spawnable_scene_count()):
		paths.append(spawner.get_spawnable_scene(index))
	return paths


func _connect_client() -> Node3D:
	var root := _network_root()
	var peer := ENetMultiplayerPeer.new()
	_peers.append(peer)
	assert_eq(peer.create_client("127.0.0.1", _peers[0].get_host().get_local_port()), OK)
	root.multiplayer.multiplayer_peer = peer
	for attempt: int in range(120):
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break
		await get_tree().create_timer(0.01).timeout
	assert_eq(peer.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED)
	return root


func _marker(kind: LootPropSpawner.PropType, position: Vector3) -> LootPropSpawner:
	# Production maps nest markers under transformed level nodes.
	var level := Node3D.new()
	level.position = Vector3(8, 0, -5)
	level.rotation.y = 0.4
	_server.add_child(level)
	var marker := SpawnerScript.new()
	marker.spawn_on_ready = false
	marker.random_rotation = false
	marker.prop_type = kind
	level.add_child(marker)
	marker.global_position = position
	return marker


func _await_copy(client: Node3D, prop: Node3D) -> Node3D:
	for attempt: int in range(120):
		var copy := client.get_node_or_null(NodePath(prop.name)) as Node3D
		if copy:
			return copy
		await get_tree().create_timer(0.01).timeout
	fail_test("Authoritative prop did not replicate: %s" % prop.name)
	return null


func _pickups() -> Array[PickupBase]:
	var result: Array[PickupBase] = []
	for child: Node in _server.get_children():
		if child is PickupBase:
			result.append(child)
	return result


func test_enet_nested_spawn_preserves_configuration_and_remote_interaction_is_once_only() -> void:
	var client := await _connect_client()
	_registered_peer = client.multiplayer.get_unique_id()
	var player := CharacterBody3D.new()
	player.name = "RegisteredPlayer"
	player.set_multiplayer_authority(_registered_peer)
	player.add_to_group("player")
	_server.add_child(player)
	_registry.register_player(_registered_peer, player)
	var client_player := CharacterBody3D.new()
	client_player.name = "RegisteredPlayer"
	client_player.set_multiplayer_authority(_registered_peer)
	client_player.add_to_group("player")
	client.add_child(client_player)
	var marker := _marker(LootPropSpawner.PropType.WEAPON_RACK, Vector3(3, 0, 4))
	marker.weapon_type = "shotgun"
	var rack := marker.spawn_prop()
	assert_same(rack.get_parent(), _server, "Nested markers must use the existing replication root")
	var copy := await _await_copy(client, rack)
	if not copy:
		return
	assert_true(copy.global_transform.is_equal_approx(marker.global_transform))
	assert_eq(copy.weapon_type, "shotgun")
	# A real registry lookup must reject the request until its authoritative player is near.
	player.global_position = Vector3(100, 0, 0)
	client_player.global_position = copy.global_position
	copy.interact(client_player)
	await get_tree().create_timer(0.05).timeout
	assert_true(rack.has_weapon)
	assert_eq(_pickups().size(), 0)
	player.global_position = rack.global_position
	copy.interact(client_player)
	copy.interact(client_player)
	for attempt: int in range(120):
		if not copy.has_weapon:
			break
		await get_tree().create_timer(0.01).timeout
	assert_false(rack.has_weapon)
	assert_false(copy.has_weapon)
	assert_false(copy.weapon_display.visible)
	assert_eq(_pickups().size(), 1)
	if _pickups().size() == 1:
		var pickup := _pickups()[0] as WeaponPickup
		assert_not_null(pickup)
		if pickup:
			assert_eq(pickup.weapon_type, WeaponPickup.WeaponType.SHOTGUN)
			assert_eq(pickup.owner_peer_id, _registered_peer)


func test_enet_late_join_sees_searched_pile_revealed_stash_and_configured_vase_health() -> void:
	var pile_marker := _marker(LootPropSpawner.PropType.CORPSE_PILE, Vector3(0, 0, 0))
	pile_marker.loot_table_override = "hidden_stash"
	var pile := pile_marker.spawn_prop() as CorpsePile
	pile._loot_pile(1)
	var stash_marker := _marker(LootPropSpawner.PropType.HIDDEN_STASH, Vector3(4, 0, 0))
	var stash := stash_marker.spawn_prop() as HiddenStash
	stash.reveal_trigger = HiddenStash.RevealTrigger.CUSTOM
	stash.reveal_delay = 0.0
	stash.trigger_reveal()
	var vase_marker := _marker(LootPropSpawner.PropType.VASE, Vector3(8, 0, 0))
	vase_marker.health_multiplier = 3.0
	var vase := vase_marker.spawn_prop() as BreakableProp
	vase.wobble_on_damage = false
	vase.take_damage(10.0)
	var client := await _connect_client()
	var pile_copy := await _await_copy(client, pile) as CorpsePile
	var stash_copy := await _await_copy(client, stash) as HiddenStash
	var vase_copy := await _await_copy(client, vase) as BreakableProp
	if pile_copy:
		assert_false(pile_copy.can_be_looted())
		assert_eq(pile_copy.loot_table_id, "hidden_stash")
		assert_false(pile_copy.interaction_label.visible)
	if stash_copy:
		assert_true(stash_copy.is_revealed)
		assert_true(stash_copy.is_looted)
		var material := stash_copy.mesh_instance.get_active_material(0) as StandardMaterial3D
		assert_eq(material.albedo_color.a, stash_copy.revealed_alpha)
	if vase_copy:
		assert_eq(vase_copy.max_health, 75.0)
		assert_eq(vase_copy.sync_health, 65.0, "Client readiness cannot reset replicated damage")
