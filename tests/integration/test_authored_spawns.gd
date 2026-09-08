extends ModusGutTestBase

const SpawnPointScript := preload("res://shared/editor_core/nodes/spawn_point.gd")
const LevelRootScript := preload("res://shared/editor_core/nodes/level_root.gd")
const SpawnManagerScript := preload("res://game/world/enemy_spawn_manager.gd")


class SpawnWorld:
	extends "res://game/world/world.gd"

	# Exercise production spawning without starting a listening server or menus.
	func _ready() -> void:
		pass

	func _exit_tree() -> void:
		pass


class PickupRecipient:
	extends CharacterBody3D

	var health: int = 25
	var max_health: int = 100
	var armor: int = 0
	var max_armor: int = 100
	var blood_overlay: Control = null
	var inventory: Inventory = null
	var ammo_by_weapon: Dictionary = {}

	func add_ammo_for_weapon(weapon_type: int, amount: int) -> void:
		ammo_by_weapon[weapon_type] = ammo_by_weapon.get(weapon_type, 0) + amount


var _world: Node
var _level: Node3D
var _markers: Node3D
var _manager: EnemySpawnManager
var _stats: Dictionary


func before_each() -> void:
	await modus_setup()
	_world = Node.new()
	add_child_autofree(_world)
	_level = LevelRootScript.new()
	_level.position = Vector3(30, 0, 40)
	_level.rotation.y = 0.6
	_world.add_child(_level)
	_markers = Node3D.new()
	_markers.position = Vector3(2, 0, 3)
	_level.add_child(_markers)
	_stats = {}
	_manager = SpawnManagerScript.new()
	_world.add_child(_manager)
	_manager.setup(_world, _stats)


func after_each() -> void:
	modus_teardown()


func _item_marker(item_id: String, pos: Vector3, delay: float = 0.0) -> LevelSpawnPoint:
	var marker: LevelSpawnPoint = SpawnPointScript.new()
	marker.spawn_type = LevelSpawnPoint.SpawnType.ITEM
	marker.item_id = item_id
	marker.respawn_time = delay
	marker.position = pos
	marker.rotation = Vector3(0.1, 0.3, 0.2)
	_markers.add_child(marker)
	return marker


func _pickups() -> Array[Node3D]:
	var pickups: Array[Node3D] = []
	for child: Node in _world.get_children():
		if child is PickupBase and not child.is_queued_for_deletion():
			pickups.append(child)
	return pickups


func test_nested_authored_enemy_spawns_without_legacy_arena_enemies() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.position.y = -0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 1, 30)
	shape.shape = box
	floor_body.add_child(shape)
	_level.add_child(floor_body)
	var marker: LevelSpawnPoint = SpawnPointScript.new()
	marker.spawn_type = LevelSpawnPoint.SpawnType.ENEMY
	marker.enemy_id = "grunt_basic"
	marker.position = Vector3(0, 0.5, 0)
	marker.rotation.y = 0.4
	_markers.add_child(marker)
	await get_tree().physics_frame

	_manager.spawn_enemies()

	var enemies: Array[Node] = []
	for child: Node in _world.get_children():
		if child is Enemy:
			enemies.append(child)
	assert_eq(enemies.size(), 1, "Only the authored enemy should exist, not legacy arena spawns")
	assert_eq(_stats.enemies_spawned, 1)
	if enemies.size() == 1:
		var enemy: Node3D = enemies[0]
		assert_eq(enemy.enemy_id, "grunt_basic")
		assert_true(enemy.global_position.is_equal_approx(marker.global_position))
		assert_true(enemy.global_basis.is_equal_approx(Basis.from_euler(marker.global_rotation)))


func test_authored_catalog_item_keeps_world_transform_and_heals_on_pickup() -> void:
	var marker := _item_marker("health_potion", Vector3(1, 2, 0))
	_manager.spawn_enemies()
	var pickups := _pickups()
	assert_eq(pickups.size(), 1)
	assert_eq(
		_stats.enemies_spawned, 0, "An item-only authored level must not spawn legacy enemies"
	)
	if pickups.size() != 1:
		return
	var pickup: Node3D = pickups[0]
	assert_true(pickup.global_position.is_equal_approx(marker.global_position))
	assert_true(pickup.global_basis.is_equal_approx(Basis.from_euler(marker.global_rotation)))
	var recipient := PickupRecipient.new()
	_world.add_child(recipient)
	recipient.global_position = pickup.global_position
	pickup._request_pickup(recipient.get_path())
	assert_eq(recipient.health, 75, "The catalog potion must apply its real 50 HP effect")
	assert_true(pickup.collected)


func test_authored_material_enters_inventory_with_its_catalog_type() -> void:
	_item_marker("scrap_metal", Vector3(0, 2, 0))
	_manager.spawn_enemies()
	var pickups := _pickups()
	assert_eq(pickups.size(), 1)
	if pickups.size() != 1:
		return
	var recipient := PickupRecipient.new()
	recipient.inventory = Inventory.new()
	_world.add_child(recipient)
	recipient.global_position = pickups[0].global_position
	pickups[0]._request_pickup(recipient.get_path())
	var item: InventoryItem = recipient.inventory.get_item_at(0)
	assert_not_null(item)
	if item:
		assert_eq(item.id, "scrap_metal")
		assert_eq(item.item_type, InventoryItem.ItemType.MATERIAL)
		assert_eq(item.current_stack, 1)


func test_authored_health_tier_and_weapon_scene_keep_their_pickup_effects() -> void:
	_item_marker("health_mega", Vector3(0, 2, 0))
	_item_marker("shotgun_pickup", Vector3(4, 2, 0))
	_manager.spawn_enemies()
	var pickups := _pickups()
	assert_eq(pickups.size(), 2)
	var recipient := PickupRecipient.new()
	_world.add_child(recipient)
	for pickup: Node3D in pickups:
		recipient.global_position = pickup.global_position
		pickup._request_pickup(recipient.get_path())
	assert_eq(recipient.health, 125, "Megahealth must retain its overhealing tier")
	assert_eq(recipient.ammo_by_weapon.get(WeaponPickup.WeaponType.SHOTGUN, 0), 12)
	assert_false(recipient.ammo_by_weapon.has(WeaponPickup.WeaponType.PISTOL))


func test_authored_item_respawns_at_its_marker_after_collection() -> void:
	var marker := _item_marker("shield_booster", Vector3(0, 2, 0), 0.01)
	_manager.spawn_enemies()
	var pickups := _pickups()
	assert_eq(pickups.size(), 1)
	if pickups.size() != 1:
		return
	var original_id: int = pickups[0].get_instance_id()
	var recipient := PickupRecipient.new()
	_world.add_child(recipient)
	recipient.global_position = pickups[0].global_position
	pickups[0]._request_pickup(recipient.get_path())
	assert_eq(recipient.armor, 25)
	await get_tree().create_timer(0.1).timeout
	pickups = _pickups()
	assert_eq(pickups.size(), 1, "Exactly one replacement pickup should be spawned")
	if pickups.size() == 1:
		assert_ne(pickups[0].get_instance_id(), original_id)
		# Rigid-body pickups can fall between respawn and this observation.
		assert_almost_eq(pickups[0].global_position.x, marker.global_position.x, 0.001)
		assert_almost_eq(pickups[0].global_position.z, marker.global_position.z, 0.001)
		recipient.global_position = pickups[0].global_position
		pickups[0]._request_pickup(recipient.get_path())
		assert_eq(recipient.armor, 50, "The replacement retains the authored item's effect")


func test_player_spawns_at_authored_marker_instead_of_origin() -> void:
	var world := SpawnWorld.new()
	add_child(world)
	var level: Node3D = LevelRootScript.new()
	level.position = Vector3(50, 0, 60)
	level.rotation.y = 0.7
	world.add_child(level)
	var marker: LevelSpawnPoint = SpawnPointScript.new()
	marker.position = Vector3(3, 2, 4)
	marker.rotation.y = 0.2
	level.add_child(marker)
	var player_service: PlayerSvc = PlayerSvc.get_instance()
	var player_data: Dictionary = (
		player_service._player_data.duplicate(true) if player_service else {}
	)
	var tokens: Dictionary = player_service._active_tokens.duplicate() if player_service else {}
	var mouse_mode: Input.MouseMode = Input.mouse_mode
	var gameplay := GameManager.get_core_system("gameplay") as GameplaySvc
	var scores: Dictionary = (
		gameplay.match_service.player_scores.duplicate(true)
		if gameplay and gameplay.match_service
		else {}
	)

	world.spawn_player_node(1, "editor")

	var player: Node3D = world.get_node("1")
	assert_true(player.global_position.is_equal_approx(marker.global_position))
	assert_true(player.global_basis.is_equal_approx(Basis.from_euler(marker.global_rotation)))
	world.free()
	Input.mouse_mode = mouse_mode
	if player_service:
		player_service._player_data = player_data
		player_service._active_tokens = tokens
	if gameplay and gameplay.match_service:
		gameplay.match_service.player_scores = scores
