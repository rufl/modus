extends Node3D

## Example scene demonstrating blood pool integration with framework
## Shows how blood pools work with the effects service and gore system

@export var spawn_test_enemy: bool = true
@export var auto_damage_enemy: bool = true

var effects_service: Node
var test_enemy: Node3D


func _ready() -> void:
	# Wait for services to initialize
	await get_tree().create_timer(0.5).timeout

	# Get effects service
	effects_service = GameManager.get_core_system("effects")
	if not effects_service:
		push_error("[BloodPoolExample] EffectsService not found!")
		return

	# Setup blood pools
	_setup_blood_pools()

	# Spawn test enemy if enabled
	if spawn_test_enemy:
		_spawn_test_enemy()

	GameManager.get_core_system("logger").info(
		"[BloodPoolExample] Ready! Press keys to test:", "Game"
	)
	GameManager.get_core_system("logger").info("  1 - Spawn blood drop", "Game")
	GameManager.get_core_system("logger").info("  2 - Spawn blood splatter", "Game")
	GameManager.get_core_system("logger").info("  3 - Spawn blood trail", "Game")
	GameManager.get_core_system("logger").info("  4 - Spawn gore effect", "Game")
	GameManager.get_core_system("logger").info("  5 - Damage test enemy", "Game")
	GameManager.get_core_system("logger").info("  6 - Kill test enemy", "Game")


func _setup_blood_pools() -> void:
	# Setup all blood pools in scene
	var setup = BloodPoolSetup.new()
	setup.blood_color = Color(0.35, 0.05, 0.05)
	setup.blood_merge_factor = 0.25
	setup.setup_blood_pools()

	var pools = get_tree().get_nodes_in_group("blood_pool")
	GameManager.get_core_system("logger").info(
		"[BloodPoolExample] Configured %d blood pool(s)" % pools.size(), "Game"
	)

	# Check if gore system has blood pools
	if effects_service and effects_service.gore_system:
		print(
			"[BloodPoolExample] Blood pools enabled: ",
			effects_service.gore_system.has_blood_pools()
		)


func _spawn_test_enemy() -> void:
	# Create simple test enemy
	test_enemy = Node3D.new()
	test_enemy.name = "TestEnemy"
	test_enemy.position = Vector3(0, 1, 0)
	add_child(test_enemy)

	# Add blood trail component
	var blood_trail = BloodTrailComponent.new()
	blood_trail.spawn_distance = 0.3
	blood_trail.only_when_damaged = false  # Always bleed for demo
	test_enemy.add_child(blood_trail)

	# Add simple health system
	test_enemy.set_meta("health", 100)
	test_enemy.set_meta("max_health", 100)

	# Add movement for blood trail demo
	if auto_damage_enemy:
		_start_enemy_movement()

	GameManager.get_core_system("logger").info(
		"[BloodPoolExample] Test enemy spawned with blood trail", "Game"
	)


func _start_enemy_movement() -> void:
	# Move enemy in circle to create blood trail
	var tween = create_tween().set_loops()
	tween.tween_property(test_enemy, "position:x", 3.0, 2.0)
	tween.tween_property(test_enemy, "position:z", 3.0, 2.0)
	tween.tween_property(test_enemy, "position:x", -3.0, 2.0)
	tween.tween_property(test_enemy, "position:z", -3.0, 2.0)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		KEY_1:
			_test_blood_drop()
		KEY_2:
			_test_blood_splatter()
		KEY_3:
			_test_blood_trail()
		KEY_4:
			_test_gore_effect()
		KEY_5:
			_test_damage_enemy()
		KEY_6:
			_test_kill_enemy()


func _test_blood_drop() -> void:
	var pos = _get_random_floor_position()
	if effects_service.has_method("spawn_blood_pool"):
		effects_service.spawn_blood_pool(pos)
		GameManager.get_core_system("logger").info(
			"[BloodPoolExample] Spawned blood drop at " + " " + str(pos), "Game"
		)


func _test_blood_splatter() -> void:
	var pos = _get_random_floor_position()
	if effects_service.has_method("spawn_blood_pool_splatter"):
		effects_service.spawn_blood_pool_splatter(pos, 1.5)
		GameManager.get_core_system("logger").info(
			"[BloodPoolExample] Spawned blood splatter at " + " " + str(pos), "Game"
		)


func _test_blood_trail() -> void:
	var start = _get_random_floor_position()
	var end = _get_random_floor_position()
	if effects_service.has_method("spawn_blood_pool_trail"):
		effects_service.spawn_blood_pool_trail(start, end, 1.0)
		GameManager.get_core_system("logger").info(
			(
				"[BloodPoolExample] Spawned blood trail from "
				+ " "
				+ str(start)
				+ " "
				+ " to "
				+ " "
				+ str(end)
			),
			"Game"
		)


func _test_gore_effect() -> void:
	var pos = _get_random_floor_position()
	if effects_service.has_method("spawn_gore_effect"):
		effects_service.spawn_gore_effect(pos, Vector3.UP, 2.0)
		GameManager.get_core_system("logger").info(
			"[BloodPoolExample] Spawned gore effect at " + " " + str(pos), "Game"
		)


func _test_damage_enemy() -> void:
	if not test_enemy:
		GameManager.get_core_system("logger").info(
			"[BloodPoolExample] No test enemy to damage", "Game"
		)
		return

	var health = test_enemy.get_meta("health", 0)
	health -= 25
	test_enemy.set_meta("health", health)

	# Spawn blood at enemy position
	var blood_handler = BloodImpactHandler.new()
	blood_handler.handle_hit(test_enemy.global_position, 25.0, Vector3.DOWN)

	GameManager.get_core_system("logger").info(
		"[BloodPoolExample] Damaged enemy, health: " + " " + str(health), "Game"
	)


func _test_kill_enemy() -> void:
	if not test_enemy:
		GameManager.get_core_system("logger").info(
			"[BloodPoolExample] No test enemy to kill", "Game"
		)
		return

	var pos = test_enemy.global_position

	# Spawn death gore effect
	if effects_service.has_method("spawn_gore_effect"):
		effects_service.spawn_gore_effect(pos, Vector3.UP, 2.0)

	# Remove enemy
	test_enemy.queue_free()
	test_enemy = null

	GameManager.get_core_system("logger").info(
		"[BloodPoolExample] Killed enemy at " + " " + str(pos), "Game"
	)


func _get_random_floor_position() -> Vector3:
	return Vector3(randf_range(-5, 5), 0.1, randf_range(-5, 5))
