@tool
extends Node3D
class_name ItemSpawner

const PICKUP_SCENE: PackedScene = preload("res://game/scenes/items/pickups/consumable_pickup.tscn")

@export var item_id: String = "health_potion"

var _mesh_instance: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_setup_editor_visuals()
	else:
		# Runtime logic
		# Only server spawns networked items
		# Use is_server check safely
		if multiplayer.has_multiplayer_peer():
			if multiplayer.is_server():
				call_deferred("_spawn_item")
		else:
			# Singleplayer / No networking init yet
			call_deferred("_spawn_item")

		# Hide spawner at runtime
		visible = false


func _spawn_item() -> void:
	if not PICKUP_SCENE:
		push_error("[ItemSpawner] Pickup scene not loaded")
		return

	var pickup = PICKUP_SCENE.instantiate()

	# Set ID before ready
	if "item_id" in pickup:
		pickup.item_id = item_id

	# Position
	pickup.global_transform = global_transform

	# Add to level (parent of this spawner)
	get_parent().add_child(pickup)
	GameManager.get_core_system("logger").info("[ItemSpawner] Spawning %s" % item_id, "World")


func _setup_editor_visuals() -> void:
	# Clean up old visuals if re-running
	if has_node("EditorMesh"):
		get_node("EditorMesh").queue_free()
	if has_node("EditorLabel"):
		get_node("EditorLabel").queue_free()

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "EditorMesh"
	var box = BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 1.0, 0.5, 0.5)  # Translucent green
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box.material = mat
	_mesh_instance.mesh = box
	add_child(_mesh_instance)

	_label = Label3D.new()
	_label.name = "EditorLabel"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 0.6, 0)
	_label.text = item_id
	_label.font_size = 32
	add_child(_label)
