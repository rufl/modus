class_name BloodSpray
extends GPUParticles3D

@export var base_amount: float = 150.0
@export var velocity_scale: float = 25.0

const BLOOD_SPRAY_SCENE: String = "res://game/entities/effects/blood_spray.tscn"


## Spawn a blood spray effect at the given position
## This should be called from a Node context, not as a static function
## Usage: var spawner = get_tree().current_scene; spawner.spawn_blood_spray(pos, dir)
func spawn_at(pos: Vector3, dir: Vector3, intensity: float = 1.0) -> void:
	global_position = pos

	# Align spray direction
	if dir.length_squared() > 0.001:
		var target: Vector3 = pos + dir

		# Use look_at safely
		if not pos.is_equal_approx(target):
			if abs(dir.normalized().dot(Vector3.UP)) > 0.99:
				# Handle nearly vertical case
				look_at(target, Vector3.RIGHT)
			else:
				look_at(target, Vector3.UP)

	# Start emitting
	emitting = true
	amount_ratio = clamp(intensity, 0.1, 3.0)

	# Auto-cleanup after particles finish
	start_cleanup()


func _ready() -> void:
	# Particles configured in scene
	# one_shot = true
	# emitting = false (initially, triggered by spawn_at)
	pass


func start_cleanup() -> void:
	# Ensure emitting is true
	emitting = true

	if is_inside_tree():
		await get_tree().create_timer(1.0).timeout
	queue_free()
