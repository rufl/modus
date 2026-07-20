@tool
extends Node3D
class_name EnemySpawnerBlock

signal enemy_spawned(enemy: Node)
signal all_enemies_spawned
signal wave_complete

enum SpawnTrigger { ON_ENTER, ON_TIMER, ON_SIGNAL, MANUAL }

@export var enemy_scene_path: String = "res://game/entities/enemies/enemy.tscn"
@export var enemy_id: String = "grunt"  ## ID for data service lookup
@export_category("Spawn Settings")
@export var spawn_trigger: SpawnTrigger = SpawnTrigger.ON_ENTER
@export var spawn_count: int = 3
@export var spawn_delay: float = 0.5  ## Delay between each spawn
@export var respawn_enabled: bool = false
@export var respawn_delay: float = 30.0
@export_category("Trigger Zone")
@export var trigger_radius: float = 10.0
@export var trigger_once: bool = true
@export_category("Timer Spawn")
@export var timer_interval: float = 15.0
@export var auto_start_timer: bool = false
@export_category("Visuals (Editor Only)")
@export var editor_color: Color = Color(1.0, 0.0, 0.0, 0.3)

var _spawned_count: int = 0
var _active_enemies: Array[Node] = []
var _has_triggered: bool = false
var _trigger_area: Area3D = null
var _spawn_timer: Timer = null


func _ready() -> void:
	if Engine.is_editor_hint():
		_setup_editor_visual()
		return

	# Runtime setup
	_setup_trigger_area()

	if spawn_trigger == SpawnTrigger.ON_TIMER and auto_start_timer:
		_setup_spawn_timer()
		_spawn_timer.start()


func _setup_trigger_area() -> void:
	if spawn_trigger != SpawnTrigger.ON_ENTER:
		return

	_trigger_area = Area3D.new()
	_trigger_area.name = "TriggerArea"

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = trigger_radius
	collision.shape = sphere
	_trigger_area.add_child(collision)

	_trigger_area.body_entered.connect(_on_body_entered)
	add_child(_trigger_area)


func _setup_spawn_timer() -> void:
	if spawn_trigger != SpawnTrigger.ON_TIMER:
		return

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = timer_interval
	_spawn_timer.timeout.connect(_on_timer_timeout)
	add_child(_spawn_timer)


func _setup_editor_visual() -> void:
	# Visual indicator in editor only
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "EditorVisual"

	var box := BoxMesh.new()
	box.size = Vector3(1.0, 2.0, 1.0)
	mesh_instance.mesh = box

	var material := StandardMaterial3D.new()
	material.albedo_color = editor_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.set_surface_override_material(0, material)

	add_child(mesh_instance)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	if trigger_once and _has_triggered:
		return

	_has_triggered = true
	spawn_enemies()


func _on_timer_timeout() -> void:
	if _spawned_count >= spawn_count and not respawn_enabled:
		_spawn_timer.stop()
		return

	_spawn_single_enemy()


## Spawn all enemies (for immediate spawn or trigger)


func spawn_enemies() -> void:
	for i in range(spawn_count):
		if i > 0:
			await get_tree().create_timer(spawn_delay).timeout

		_spawn_single_enemy()

	all_enemies_spawned.emit()


## Spawn a single enemy


func _spawn_single_enemy() -> void:
	var enemy: Node3D = null

	# Try loading from scene path
	if ResourceLoader.exists(enemy_scene_path):
		var scene: PackedScene = load(enemy_scene_path)
		enemy = scene.instantiate()
	else:
		push_warning("[EnemySpawner] Enemy scene not found: %s" % enemy_scene_path)
		return

	# Configure enemy if it has enemy_id property
	if "enemy_id" in enemy and not enemy_id.is_empty():
		enemy.enemy_id = enemy_id

	# Add to scene
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = global_position

	# Track enemy
	_active_enemies.append(enemy)
	_spawned_count += 1

	# Connect death signal for respawn/wave tracking
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))
	elif enemy.has_node("HealthComponent"):
		enemy.get_node("HealthComponent").died.connect(_on_enemy_died.bind(enemy))

	enemy_spawned.emit(enemy)
	GameManager.get_core_system("logger").info(
		"[EnemySpawner] Spawned enemy: %s (#%d)" % [enemy_id, _spawned_count], "World"
	)


func _on_enemy_died(_killer_id: int, enemy: Node) -> void:
	_active_enemies.erase(enemy)

	# Check if wave complete
	if _active_enemies.is_empty():
		wave_complete.emit()

		# Handle respawn
		if respawn_enabled:
			await get_tree().create_timer(respawn_delay).timeout
			_spawned_count = 0
			spawn_enemies()


## Manual spawn trigger


func trigger_spawn() -> void:
	spawn_enemies()


## Get current active enemy count


func get_active_enemy_count() -> int:
	# Clean up invalid references
	_active_enemies = _active_enemies.filter(func(e: Node) -> bool: return is_instance_valid(e))
	return _active_enemies.size()


## Editor warning for missing scene


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if enemy_scene_path.is_empty():
		warnings.append("Enemy scene path is not set")
	elif not ResourceLoader.exists(enemy_scene_path):
		warnings.append("Enemy scene not found: %s" % enemy_scene_path)
	return warnings
