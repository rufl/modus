@tool
extends Node3D
class_name EnemySpawner

const ENEMY_SCENE: PackedScene = preload("res://game/entities/enemies/enemy.tscn")

@export_group("Enemy Configuration")
@export var enemy_id: String = "grunt_basic"
@export_range(1, 4) var tier: int = 1
@export_enum("Idle", "Patrol", "Guard", "Hunt") var initial_state: String = "Idle"
@export var patrol_path: NodePath

var _mesh_instance: MeshInstance3D
var _direction_mesh: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_setup_editor_visuals()
	else:
		# Runtime logic: Only authority/server spawns enemies
		if multiplayer.has_multiplayer_peer():
			if multiplayer.is_server():
				call_deferred("_spawn_enemy")
		else:
			# Singleplayer
			call_deferred("_spawn_enemy")

		# Hide spawner at runtime (visuals only)
		visible = false


func _spawn_enemy() -> void:
	if not ENEMY_SCENE:
		push_error("[EnemySpawner] Enemy scene not loaded")
		return

	var enemy: Node = ENEMY_SCENE.instantiate()

	# Configure Enemy
	if "enemy_id" in enemy:
		enemy.enemy_id = enemy_id
	if "tier" in enemy:
		enemy.tier = tier

	# Initial State / AI Config (if supported by Enemy script)
	# Assuming Enemy has a way to set initial state or we configure AI controller
	# For now, we rely on Enemy.gd's internal config loading based on ID

	# Transform
	enemy.global_transform = global_transform

	# Add to level
	get_parent().add_child(enemy)
	GameManager.get_core_system("logger").info(
		"[EnemySpawner] Spawning %s (Tier %d)" % [enemy_id, tier], "World"
	)

	# Verify patrol path
	if not patrol_path.is_empty():
		var path_node: Node = get_node_or_null(patrol_path)
		if path_node and "patrol_path" in enemy:
			# If enemy supports assigning a path directly
			enemy.patrol_path = path_node
		elif path_node and enemy.has_method("set_patrol_path"):
			enemy.set_patrol_path(path_node)


func _setup_editor_visuals() -> void:
	# Clear old
	for child in get_children():
		child.queue_free()

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "EditorBox"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.6, 1.8, 0.6)  # Roughly human size

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = _get_tier_color(tier)
	mat.albedo_color.a = 0.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box.material = mat
	_mesh_instance.mesh = box
	_mesh_instance.position.y = 0.9  # Sit on floor
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
	_direction_mesh.rotation_degrees.x = -90  # Point forward
	_direction_mesh.position = Vector3(0, 0.1, -0.5)  # In front
	add_child(_direction_mesh)

	_label = Label3D.new()
	_label.name = "EditorLabel"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 2.0, 0)
	_label.text = enemy_id + "\n(Tier " + str(tier) + ")"
	_label.font_size = 24
	add_child(_label)


func _update_visuals() -> void:
	if _mesh_instance and _mesh_instance.mesh:
		var mat: StandardMaterial3D = _mesh_instance.mesh.surface_get_material(0)
		if not mat:
			mat = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_mesh_instance.mesh.surface_set_material(0, mat)

		var color: Color = _get_tier_color(tier)
		color.a = 0.4
		mat.albedo_color = color

	if _label:
		_label.text = enemy_id + "\n(Tier " + str(tier) + ")"


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
