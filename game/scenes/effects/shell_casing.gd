extends RigidBody3D

@export var lifetime: float = 5.0
@export var bounce_sound_threshold: float = 2.0

var _time_alive: float = 0.0
var _has_bounced: bool = false
var _mesh_instance: MeshInstance3D = null


func _ready() -> void:
	# Physics settings
	mass = 0.01
	gravity_scale = 1.0
	contact_monitor = true
	max_contacts_reported = 1

	# Collision layer/mask
	collision_layer = 0  # Don't collide with anything important
	collision_mask = 1  # Collide with world

	# Connect to body_entered for bounce sound
	body_entered.connect(_on_body_entered)

	# Find the MeshInstance3D child for fading
	for child in get_children():
		if child is MeshInstance3D:
			_mesh_instance = child
			break


func _physics_process(delta: float) -> void:
	_time_alive += delta

	# Fade out near end of lifetime
	if _time_alive > lifetime * 0.8 and _mesh_instance:
		var fade_progress: float = (_time_alive - lifetime * 0.8) / (lifetime * 0.2)
		_mesh_instance.transparency = 1.0 - fade_progress

	# Cleanup after lifetime
	if _time_alive >= lifetime:
		queue_free()


func _on_body_entered(_body: Node) -> void:
	if _has_bounced:
		return

	# Play bounce sound on first impact if velocity is high enough
	if linear_velocity.length() > bounce_sound_threshold:
		_has_bounced = true
		_play_bounce_sound()


func _play_bounce_sound() -> void:
	# Optional: play a small metallic clink sound
	var audio: Node = GameManager.get_core_system("audio") if GameManager else null
	if audio and audio.has_method("play_event"):
		audio.play_event("shell_bounce", global_position)
