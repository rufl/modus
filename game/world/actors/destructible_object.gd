@tool
class_name DestructibleObject
extends StaticBody3D

signal destroyed

@export var max_health: float = 50.0
@export var surface_type: String = "wood"  # wood, glass, stone, metal
@export var debris_scene: PackedScene
@export var break_sound: AudioStream

var health: float
var is_broken: bool = false

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	health = max_health
	add_to_group("destructible")


func take_damage(damage_info: Variant) -> void:
	if is_broken:
		return

	var amount: float = 0.0
	if damage_info is float:  # legacy/simple support
		amount = damage_info
	elif damage_info.has("amount"):  # Assuming Dictionary or Object with amount
		amount = damage_info.amount
	elif damage_info is DamageInfo:
		amount = damage_info.base_amount

	health -= amount
	if health <= 0:
		break_object()


func restore_state(broken: bool) -> bool:
	if broken:
		break_object()
		return is_broken

	is_broken = false
	health = max_health
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if mesh_instance:
		mesh_instance.visible = true
	return not is_broken


func break_object() -> void:
	if is_broken:
		return
	is_broken = true

	destroyed.emit()

	# Disable collision
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# Hide mesh
	if mesh_instance:
		mesh_instance.visible = false

	# Spawn debris
	if debris_scene:
		var debris: Node3D = debris_scene.instantiate()
		get_parent().add_child(debris)
		debris.global_transform = global_transform

	# Play Sound
	if break_sound:
		# Use AudioManager or generic sound spawner
		# For now, simplistic:
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		get_parent().add_child(player)
		player.global_position = global_position
		player.stream = break_sound
		player.finished.connect(player.queue_free)
		player.play()

	# Cleanup
	# Wait a bit before freeing self to ensure sounds/signals process?
	# Or just keep it disabled if it needs to persist (e.g. for sync)
	# For server authority, we might want to keep it or handle free via RPC.
	# Assuming simple local logic for now or server auth controlling this.

	if multiplayer.is_server():
		_sync_break.rpc()
		await get_tree().create_timer(5.0).timeout
		queue_free()


@rpc("authority", "call_local", "reliable")
func _sync_break() -> void:
	if not is_broken:  # Client side execution
		break_object()
