## EffectsFeature - Feature module for visual effects system
##
## Manages particles, decals, gore, tracers, and explosions.
## Provides API for spawning various visual effects in the game world.
##
## Requirements: 2.3
class_name EffectsFeature
extends FeatureModule

signal effect_spawned(effect: Node3D)
signal decal_spawned(decal: Sprite3D)
signal explosion_created(position: Vector3, radius: float)

enum EffectQuality {
	LOW,
	MEDIUM,
	HIGH,
	ULTRA,
}

enum ExplosionType {
	SMALL,
	MEDIUM,
	LARGE,
	MASSIVE,
}

## Module references
var particle_spawner: ParticleSpawner
var decal_spawner: DecalSpawner
var gore_system: GoreSystem
var tracer_renderer: TracerRenderer
var blood_pool_manager: BloodPoolManager
var effect_pool_manager: EffectPoolManager

## Settings
var current_quality: EffectQuality = EffectQuality.MEDIUM
var max_active_explosions: int = 10
var active_explosions: int = 0
var enable_screen_flash: bool = true
var enable_dynamic_light: bool = true
var enable_scorch_marks: bool = true
var explosion_scene: PackedScene

const CLEANUP_INTERVAL: float = 5.0
var _cleanup_timer: float = 0.0


## Constructor
func _init() -> void:
	super._init("effects")
	feature_name = "Effects System"


## Initialize the effects feature
func initialize() -> void:
	super.initialize()

	# Load quality settings
	var quality_name: String = get_config_value("quality", "MEDIUM")
	current_quality = EffectQuality.get(quality_name.to_upper())

	# Load other settings
	max_active_explosions = get_config_value("max_active_explosions", 10)
	enable_screen_flash = get_config_value("enable_screen_flash", true)
	enable_dynamic_light = get_config_value("enable_dynamic_light", true)
	enable_scorch_marks = get_config_value("enable_scorch_marks", true)

	# Load explosion scene
	var explosion_path: String = get_config_value(
		"explosion_scene", "res://game/entities/projectiles/explosion_quake.tscn"
	)
	if ResourceLoader.exists(explosion_path):
		explosion_scene = load(explosion_path)

	# Setup modules
	_setup_modules()
	_register_projectile_pools()


## Shutdown the effects feature
func shutdown() -> void:
	# Clean up modules
	if effect_pool_manager and is_instance_valid(effect_pool_manager):
		effect_pool_manager.queue_free()
	if particle_spawner and is_instance_valid(particle_spawner):
		particle_spawner.queue_free()
	if decal_spawner and is_instance_valid(decal_spawner):
		decal_spawner.queue_free()
	if blood_pool_manager and is_instance_valid(blood_pool_manager):
		blood_pool_manager.queue_free()
	if gore_system and is_instance_valid(gore_system):
		gore_system.queue_free()
	if tracer_renderer and is_instance_valid(tracer_renderer):
		tracer_renderer.queue_free()

	super.shutdown()


## Process cleanup timer
func _process(delta: float) -> void:
	_cleanup_timer += delta
	if _cleanup_timer >= CLEANUP_INTERVAL:
		_cleanup_timer = 0.0
		if particle_spawner:
			particle_spawner.cleanup_finished_effects()


## Setup effect modules
func _setup_modules() -> void:
	# Effect Pool Manager (no dependencies) - MUST BE FIRST
	effect_pool_manager = EffectPoolManager.new()
	effect_pool_manager.name = "EffectPoolManager"
	add_child(effect_pool_manager)
	effect_pool_manager.enable_stats = true

	# Particle Spawner
	particle_spawner = ParticleSpawner.new()
	particle_spawner.name = "ParticleSpawner"
	add_child(particle_spawner)
	particle_spawner.set_quality(current_quality)
	particle_spawner.particle_spawned.connect(_on_particle_spawned)

	# Decal Spawner
	decal_spawner = DecalSpawner.new()
	decal_spawner.name = "DecalSpawner"
	add_child(decal_spawner)
	decal_spawner.set_quality(current_quality)
	decal_spawner.decal_spawned.connect(_on_decal_spawned)

	# Blood Pool Manager
	blood_pool_manager = BloodPoolManager.new()
	blood_pool_manager.name = "BloodPoolManager"
	add_child(blood_pool_manager)
	blood_pool_manager.auto_discover_pools = true

	# Gore System (depends on other modules)
	gore_system = GoreSystem.new()
	gore_system.name = "GoreSystem"
	add_child(gore_system)
	gore_system.setup(decal_spawner, particle_spawner, blood_pool_manager)
	gore_system.load_config(get_config_value)

	# Tracer Renderer
	tracer_renderer = TracerRenderer.new()
	tracer_renderer.name = "TracerRenderer"
	add_child(tracer_renderer)


## Register projectile pools
func _register_projectile_pools() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if not game_manager:
		return

	var object_pool: Node = null
	if game_manager.has_method("get_core_system"):
		var system_service: Node = game_manager.get_core_system("system")
		if system_service and "object_pool" in system_service:
			object_pool = system_service.object_pool

	if not object_pool:
		return

	var pool_sizes: Dictionary = {
		EffectQuality.LOW: {"initial": 5, "max": 20},
		EffectQuality.MEDIUM: {"initial": 10, "max": 40},
		EffectQuality.HIGH: {"initial": 15, "max": 60},
		EffectQuality.ULTRA: {"initial": 20, "max": 100},
	}

	var sizes: Dictionary = pool_sizes.get(current_quality, pool_sizes[EffectQuality.MEDIUM])

	var projectile_scenes: Dictionary = {
		"rocket": "res://game/entities/projectiles/rocket.tscn",
		"plasma": "res://game/entities/projectiles/plasma.tscn",
		"grenade": "res://game/entities/projectiles/grenade.tscn",
		"bfg_ball": "res://game/entities/projectiles/bfg_ball.tscn",
		"gib": "res://game/entities/effects/gib.tscn",
		"decal": "res://game/entities/effects/generic_decal.tscn",
		"explosion": "res://game/entities/projectiles/explosion_quake.tscn",
		"bullet_hole": "res://game/scenes/effects/bullet_hole.tscn",
	}

	for pool_id: String in projectile_scenes:
		var scene_path: String = projectile_scenes[pool_id]
		if ResourceLoader.exists(scene_path):
			var scene: PackedScene = load(scene_path)
			if object_pool.has_method("register_pool"):
				object_pool.register_pool(pool_id, scene, sizes.initial, sizes.max)


## Spawn particles
func spawn_particles(
	scene_path: String,
	pos: Vector3,
	rot: Vector3 = Vector3.ZERO,
	parent: Node3D = null,
	lifetime: float = 5.0
) -> GPUParticles3D:
	if particle_spawner:
		return particle_spawner.spawn_particles(scene_path, pos, rot, parent, lifetime)
	return null


## Spawn decal
func spawn_decal(
	texture: Texture2D,
	pos: Vector3,
	normal: Vector3,
	decal_size: Vector3 = Vector3(1, 1, 1),
	lifetime: float = 30.0
) -> Sprite3D:
	if decal_spawner:
		return decal_spawner.spawn_decal(texture, pos, normal, decal_size, lifetime)
	return null


## Spawn blood decal
func spawn_blood_decal(pos: Vector3, normal: Vector3, is_high_velocity: bool = false) -> Sprite3D:
	if decal_spawner:
		return decal_spawner.spawn_blood_decal(pos, normal, is_high_velocity)
	return null


## Spawn bullet hole
func spawn_bullet_hole(pos: Vector3, normal: Vector3) -> void:
	if decal_spawner:
		decal_spawner.spawn_bullet_hole(pos, normal)


## Spawn gore effect
func spawn_gore_effect(
	position: Vector3, death_direction: Vector3 = Vector3.ZERO, intensity: float = 1.0
) -> void:
	if gore_system:
		gore_system.spawn_gore_effect(position, death_direction, intensity)


## Spawn blood
func spawn_blood_synced(position: Vector3, normal: Vector3, intensity: float = 1.0) -> void:
	if gore_system:
		gore_system.spawn_blood_synced(position, normal, intensity)


## Spawn tracer
func spawn_tracer(
	from: Vector3, to: Vector3, color: Color = Color(1, 0.9, 0.4), lifetime: float = 0.15
) -> void:
	if tracer_renderer:
		tracer_renderer.spawn_tracer(from, to, color, lifetime)


## Spawn explosion
func spawn_explosion(
	position: Vector3,
	explosion_type: ExplosionType = ExplosionType.MEDIUM,
	damage: float = 100.0,
	radius: float = 5.0
) -> void:
	if active_explosions >= max_active_explosions:
		return

	active_explosions += 1

	if explosion_scene:
		var explosion: Node3D = explosion_scene.instantiate()
		get_tree().root.add_child(explosion)
		explosion.global_position = position

		if "damage" in explosion:
			explosion.damage = damage
		if "radius" in explosion:
			explosion.radius = radius

		get_tree().create_timer(5.0).timeout.connect(_on_explosion_cleanup.bind(explosion))

	explosion_created.emit(position, radius)


## Set quality level
func set_quality(quality: EffectQuality) -> void:
	current_quality = quality

	if particle_spawner:
		particle_spawner.set_quality(quality)
	if decal_spawner:
		decal_spawner.set_quality(quality)


## Event handlers
func _on_particle_spawned(particle: GPUParticles3D) -> void:
	effect_spawned.emit(particle)


func _on_decal_spawned(decal: Sprite3D) -> void:
	decal_spawned.emit(decal)


func _on_explosion_cleanup(explosion: Node3D) -> void:
	active_explosions -= 1
	if is_instance_valid(explosion):
		explosion.queue_free()
