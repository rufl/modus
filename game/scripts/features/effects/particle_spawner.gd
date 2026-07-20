class_name ParticleSpawner
extends Node

## Manages particle system spawning and pooling
## Extracted from EffectsService for better separation

signal particle_spawned(particle: GPUParticles3D)

var current_quality: int = 1  # EffectQuality.MEDIUM
var _active_particles: Array[GPUParticles3D] = []

const PARTICLE_POOL_SIZE: Dictionary = {
	0: 20,  # LOW
	1: 40,  # MEDIUM
	2: 80,  # HIGH
	3: 150,  # ULTRA
}


func set_quality(quality: int) -> void:
	current_quality = quality


func spawn_particles(
	scene_path: String,
	pos: Vector3,
	rot: Vector3 = Vector3.ZERO,
	parent: Node3D = null,
	lifetime: float = 5.0
) -> GPUParticles3D:
	var pool_service: Node = GameManager.get_core_system("pools")
	var particles: GPUParticles3D = null
	var limit: int = PARTICLE_POOL_SIZE.get(current_quality, 40)

	# Lazy register pool
	if pool_service and pool_service.has_method("register_pool"):
		var pools_dict: Dictionary = pool_service.get("pools") if "pools" in pool_service else {}
		if not pools_dict.has(scene_path) and ResourceLoader.exists(scene_path):
			var scene: PackedScene = load(scene_path)
			pool_service.register_pool(scene_path, scene, 5, limit)

	# Get from pool
	if pool_service and pool_service.has_method("get_instance"):
		particles = pool_service.get_instance(scene_path) as GPUParticles3D

	# Fallback: create new
	if not particles:
		if not ResourceLoader.exists(scene_path):
			return null
		var scene: PackedScene = load(scene_path)
		particles = scene.instantiate() as GPUParticles3D
		if not particles:
			return null

	_active_particles.append(particles)
	call_deferred("_finish_spawn_particles", particles, scene_path, pos, rot, parent, lifetime)

	return particles


func _finish_spawn_particles(
	particles: GPUParticles3D,
	scene_path: String,
	pos: Vector3,
	rot: Vector3,
	parent: Node3D,
	lifetime: float
) -> void:
	if not is_instance_valid(particles):
		return

	if not particles.get_parent():
		if parent and is_instance_valid(parent):
			parent.add_child(particles)
		else:
			get_tree().root.add_child(particles)

	particles.global_position = pos
	particles.rotation = rot
	particles.emitting = true

	# Scale by quality
	var quality_scale: float = _get_quality_scale()
	if not particles.has_meta("base_amount"):
		particles.set_meta("base_amount", particles.amount)

	var base_amount: int = particles.get_meta("base_amount")
	particles.amount = maxi(int(base_amount * quality_scale), 1)

	particle_spawned.emit(particles)

	# Auto-cleanup
	get_tree().create_timer(lifetime).timeout.connect(
		func() -> void: _return_to_pool(particles, scene_path), CONNECT_ONE_SHOT
	)


func _return_to_pool(particles: GPUParticles3D, _scene_path: String) -> void:
	if not is_instance_valid(particles):
		return

	particles.emitting = false
	_active_particles.erase(particles)

	var pool_service: Node = GameManager.get_core_system("pools")
	if pool_service and pool_service.has_method("return_instance"):
		pool_service.return_instance(particles)
	else:
		particles.queue_free()


func cleanup_finished_effects() -> void:
	var to_remove: Array[GPUParticles3D] = []

	for particle in _active_particles:
		if not is_instance_valid(particle) or not particle.emitting:
			to_remove.append(particle)

	for particle in to_remove:
		_active_particles.erase(particle)


func _get_quality_scale() -> float:
	match current_quality:
		0:
			return 0.5  # LOW
		1:
			return 0.75  # MEDIUM
		2:
			return 1.0  # HIGH
		3:
			return 1.5  # ULTRA
		_:
			return 1.0
