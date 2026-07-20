@tool
class_name EnemySpawnerActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum EnemyBehavior { IDLE, PATROL, GUARD, HUNT }

@export var enemy_id: String = "grunt_basic"
@export_range(1, 4) var tier: int = 1
@export var behavior: EnemyBehavior = EnemyBehavior.IDLE
@export var patrol_radius: float = 5.0
@export var auto_spawn: bool = true

var _mesh_instance: MeshInstance3D
var _direction_mesh: MeshInstance3D
var _label: Label3D
var _is_spawned: bool = false


func _init() -> void:
	actor_category = "activator"
	actor_name = "Enemy Spawner"
	actor_description = "Spawns an enemy (Block version)"


func _on_actor_ready() -> void:
	if Engine.is_editor_hint():
		_setup_editor_visuals()
	else:
		# Runtime logic: authority/server spawns
		if auto_spawn:
			_spawn_enemy_deferred()

		# Hide visual aid at runtime
		visible = false


func _on_activated(_data: Dictionary) -> void:
	if not _is_spawned:
		_spawn_enemy()


func _spawn_enemy_deferred() -> void:
	# Small delay to ensure world is ready
	await get_tree().process_frame
	_spawn_enemy()


func _spawn_enemy() -> void:
	if _is_spawned and one_shot:
		return

	# Only server/authority spawns enemies in multiplayer
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var enemy_scene_path: String = "res://game/entities/enemies/enemy.tscn"
	if not ResourceLoader.exists(enemy_scene_path):
		push_error("[EnemySpawnerActor] Enemy scene not found: " + enemy_scene_path)
		return

	var enemy_scene: PackedScene = load(enemy_scene_path)
	var enemy: Node = enemy_scene.instantiate()

	# Configure Enemy
	if "enemy_id" in enemy:
		enemy.enemy_id = enemy_id
	if "tier" in enemy:
		enemy.tier = tier

	# Apply transform
	enemy.global_transform = global_transform

	# Add to scene
	get_parent().add_child(enemy)

	if "patrol_radius" in enemy:
		enemy.patrol_radius = patrol_radius

	_is_spawned = true
	var logger = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info("[Spawner] %s spawned at %s" % [enemy_id, global_position], "Match")


func _setup_editor_visuals() -> void:
	# Clear old
	for child in get_children():
		if child is MeshInstance3D or child is Label3D:
			child.queue_free()

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "EditorBox"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.6, 1.8, 0.6)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = _get_tier_color(tier)
	mat.albedo_color.a = 0.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box.material = mat
	_mesh_instance.mesh = box
	_mesh_instance.position.y = 0.9
	add_child(_mesh_instance)

	# Direction indicator (Arrow)
	_direction_mesh = MeshInstance3D.new()
	_direction_mesh.name = "EditorArrow"
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.4, 0.4, 0.1)

	var arrow_mat: StandardMaterial3D = StandardMaterial3D.new()
	arrow_mat.albedo_color = Color.WHITE
	_direction_mesh.mesh = prism
	_direction_mesh.material_override = arrow_mat
	_direction_mesh.rotation_degrees.x = -90
	_direction_mesh.position = Vector3(0, 1.0, -0.5)
	add_child(_direction_mesh)

	_label = Label3D.new()
	_label.name = "EditorLabel"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 2.2, 0)
	_label.text = enemy_id + "\n(Tier " + str(tier) + ")"
	_label.font_size = 32
	add_child(_label)


func _get_tier_color(t: int) -> Color:
	match t:
		1:
			return Color(0.9, 0.9, 0.9)  # Basic
		2:
			return Color(0.2, 0.6, 1.0)  # Improved
		3:
			return Color(1.0, 0.6, 0.0)  # Elite
		4:
			return Color(1.0, 0.1, 0.1)  # Boss
		_:
			return Color.WHITE


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "enemy_id",
				"type": TYPE_STRING,
				"label": "Enemy ID",
				"description": "ID of the enemy to spawn from Database"
			},
			{
				"name": "tier",
				"type": TYPE_INT,
				"label": "Tier",
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "1,4"
			},
			{
				"name": "behavior",
				"type": TYPE_INT,
				"label": "Initial Behavior",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Idle,Patrol,Guard,Hunt"
			},
			{"name": "patrol_radius", "type": TYPE_FLOAT, "label": "Patrol Radius"},
			{"name": "auto_spawn", "type": TYPE_BOOL, "label": "Auto Spawn"}
		]
	)
	return props
