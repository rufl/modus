extends GameService

## Integrated Effects Service using modular architecture
## Orchestrates particles, decals, gore, and tracers

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

# Module references
var particle_spawner: ParticleSpawner
var decal_spawner: DecalSpawner
var gore_system: GoreSystem
var tracer_renderer: TracerRenderer
var blood_pool_manager: BloodPoolManager
var effect_pool_manager: EffectPoolManager

# Settings
var current_quality: EffectQuality = EffectQuality.MEDIUM
var max_active_explosions: int = 10
var active_explosions: int = 0
var enable_screen_flash: bool = true
var enable_dynamic_light: bool = true
var enable_scorch_marks: bool = true
var explosion_scene: PackedScene = preload("res://game/entities/projectiles/explosion_quake.tscn")

const CLEANUP_INTERVAL: float = 5.0
var _cleanup_timer: float = 0.0


func _ready() -> void:
	name = "EffectsService"


func get_init_priority() -> int:
	return 40  # After network, before gameplay


func get_dependencies() -> Array[String]:
	return ["config"]


func initialize() -> void:
	if _initialized:
		push_warning("[EffectsService] Already initialized")
		return

	await _wait_for_dependencies()

	# Load quality settings
	var quality_name: String = get_config("graphics.effect_quality", "MEDIUM")
	current_quality = EffectQuality.get(quality_name.to_upper())

	_setup_modules()
	_register_projectile_pools()

	# Subscribe to events
	subscribe_event("player_died", _on_player_died_event)

	_mark_initialized()
	GameManager.get_core_system("logger").info(
		"[EffectsService] Initialized - Quality: %s" % EffectQuality.keys()[current_quality],
		"EffectsService"
	)


## EffectsService is the sole owner of the effect module tree.
func shutdown() -> void:
	unsubscribe_event("player_died", _on_player_died_event)

	for module: Node in [
		effect_pool_manager,
		particle_spawner,
		decal_spawner,
		blood_pool_manager,
		gore_system,
		tracer_renderer,
	]:
		if module and is_instance_valid(module):
			module.queue_free()

	effect_pool_manager = null
	particle_spawner = null
	decal_spawner = null
	blood_pool_manager = null
	gore_system = null
	tracer_renderer = null
	_initialized = false
	super.shutdown()


func _setup_modules() -> void:
	if effect_pool_manager and is_instance_valid(effect_pool_manager):
		return
	# 0. Effect Pool Manager (no dependencies) - MUST BE FIRST
	effect_pool_manager = EffectPoolManager.new()
	effect_pool_manager.name = "EffectPoolManager"
	add_child(effect_pool_manager)
	effect_pool_manager.enable_stats = true

	# 1. Particle Spawner (no dependencies)
	particle_spawner = ParticleSpawner.new()
	particle_spawner.name = "ParticleSpawner"
	add_child(particle_spawner)
	particle_spawner.set_quality(current_quality)
	particle_spawner.particle_spawned.connect(_on_particle_spawned)

	# 2. Decal Spawner (no dependencies)
	decal_spawner = DecalSpawner.new()
	decal_spawner.name = "DecalSpawner"
	add_child(decal_spawner)
	decal_spawner.set_quality(current_quality)
	decal_spawner.decal_spawned.connect(_on_decal_spawned)

	# 3. Blood Pool Manager (no dependencies)
	blood_pool_manager = BloodPoolManager.new()
	blood_pool_manager.name = "BloodPoolManager"
	add_child(blood_pool_manager)
	blood_pool_manager.auto_discover_pools = true

	# 4. Gore System (depends on particle, decal spawners, and blood pool manager)
	gore_system = GoreSystem.new()
	gore_system.name = "GoreSystem"
	add_child(gore_system)
	gore_system.setup(decal_spawner, particle_spawner, blood_pool_manager)
	gore_system.load_config(get_config)

	# 5. Tracer Renderer (no dependencies)
	tracer_renderer = TracerRenderer.new()
	tracer_renderer.name = "TracerRenderer"
	add_child(tracer_renderer)


func _on_particle_spawned(particle: GPUParticles3D) -> void:
	effect_spawned.emit(particle)


func _on_decal_spawned(decal: Sprite3D) -> void:
	decal_spawned.emit(decal)


func _register_projectile_pools() -> void:
	var pool_service: Node = GameManager.get_core_system("pools")
	if not pool_service:
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
		"nuker3000_ball": "res://game/entities/projectiles/nuker3000_ball.tscn",
		"gib": "res://game/entities/effects/gib.tscn",
		"decal": "res://game/entities/effects/generic_decal.tscn",
		"explosion": "res://game/entities/projectiles/explosion_quake.tscn",
		"bullet_hole": "res://game/scenes/effects/bullet_hole.tscn",
	}

	for pool_id: String in projectile_scenes:
		var scene_path: String = projectile_scenes[pool_id]
		if ResourceLoader.exists(scene_path):
			var scene: PackedScene = load(scene_path)
			pool_service.register_pool(pool_id, scene, sizes["initial"], sizes["max"])

	# Register damage numbers
	var dn_path: String = "res://game/scenes/ui/damage_number.tscn"
	if ResourceLoader.exists(dn_path):
		var dn_scene: PackedScene = load(dn_path)
		pool_service.register_pool("damage_number", dn_scene, sizes["initial"], sizes["max"])


func _process(delta: float) -> void:
	_cleanup_timer += delta
	if _cleanup_timer >= CLEANUP_INTERVAL:
		_cleanup_timer = 0.0
		if particle_spawner:
			particle_spawner.cleanup_finished_effects()


# ============================================================================
# PUBLIC API - Particles
# ============================================================================


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


# ============================================================================
# PUBLIC API - Decals
# ============================================================================


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


func spawn_blood_decal(pos: Vector3, normal: Vector3, is_high_velocity: bool = false) -> Sprite3D:
	if decal_spawner:
		return decal_spawner.spawn_blood_decal(pos, normal, is_high_velocity)
	return null


func spawn_bullet_hole(pos: Vector3, normal: Vector3) -> void:
	if decal_spawner:
		decal_spawner.spawn_bullet_hole(pos, normal)


# ============================================================================
# PUBLIC API - Gore
# ============================================================================

@rpc("authority", "call_local", "reliable")
func spawn_gore_effect(
	position: Vector3, death_direction: Vector3 = Vector3.ZERO, intensity: float = 1.0
) -> void:
	if not is_feature_enabled("gore"):
		return

	if gore_system:
		gore_system.spawn_gore_effect(position, death_direction, intensity)


@rpc("authority", "call_local", "reliable")
func spawn_blood_synced(position: Vector3, normal: Vector3, intensity: float = 1.0) -> void:
	if not is_feature_enabled("gore"):
		return

	if gore_system:
		gore_system.spawn_blood_synced(position, normal, intensity)


## Spawn a limb gib for dismemberment
func spawn_limb_gib(
	position: Vector3, bone_name: String, limb_color: Color, launch_direction: Vector3
) -> void:
	if not is_feature_enabled("gore"):
		return

	if gore_system:
		gore_system.spawn_limb_gib(position, bone_name, limb_color, launch_direction)


# ============================================================================
# PUBLIC API - Blood Pools (Shader-based)
# ============================================================================


## Spawn blood pool drop at world position
func spawn_blood_pool(position: Vector3) -> bool:
	if not is_feature_enabled("gore") or not gore_system:
		return false

	if gore_system.has_blood_pools():
		gore_system.spawn_blood_drop(position)
		return true
	return false


## Spawn blood trail between two positions
func spawn_blood_pool_trail(start_pos: Vector3, end_pos: Vector3, intensity: float = 1.0) -> void:
	if not is_feature_enabled("gore") or not gore_system:
		return

	gore_system.spawn_blood_trail(start_pos, end_pos, intensity)


## Spawn blood splatter (multiple drops in radius)
func spawn_blood_pool_splatter(position: Vector3, intensity: float = 1.0) -> void:
	if not is_feature_enabled("gore") or not gore_system:
		return

	if blood_pool_manager:
		var radius: float = 0.3 + (intensity * 0.5)
		var drops: int = int(5 + (intensity * 10))
		blood_pool_manager.spawn_blood_splatter(position, radius, drops)


# ============================================================================
# PUBLIC API - Tracers
# ============================================================================


func spawn_tracer(
	from: Vector3, to: Vector3, color: Color = Color(1, 0.9, 0.4), lifetime: float = 0.15
) -> void:
	if tracer_renderer:
		tracer_renderer.spawn_tracer(from, to, color, lifetime)


func spawn_simple_tracer(from: Vector3, to: Vector3, color: Color = Color(1, 0.9, 0.4)) -> void:
	if tracer_renderer:
		tracer_renderer.spawn_simple_tracer(from, to, color)


# ============================================================================
# PUBLIC API - Screen Effects
# ============================================================================


func screen_flash(color: Color = Color(1, 1, 1, 0.5), duration: float = 0.2) -> void:
	if not enable_screen_flash:
		return

	var us := UISystem.get_service()
	if not us or not us.ui_manager:
		return

	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	us.ui_manager.add_child(rect)

	var tween := rect.create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN).set_trans(
		Tween.TRANS_QUAD
	)
	tween.tween_callback(rect.queue_free)


# ============================================================================
# PUBLIC API - Explosions
# ============================================================================

@rpc("authority", "call_local", "reliable")
func spawn_explosion(
	position: Vector3,
	explosion_type: ExplosionType = ExplosionType.MEDIUM,
	damage: float = 100.0,
	radius: float = 5.0
) -> void:
	if active_explosions >= max_active_explosions:
		return

	active_explosions += 1

	# Spawn explosion scene
	if explosion_scene:
		var explosion: Node3D = explosion_scene.instantiate()
		get_tree().root.add_child(explosion)
		explosion.global_position = position

		# Configure explosion
		if "damage" in explosion:
			explosion.damage = damage
		if "radius" in explosion:
			explosion.radius = radius

		# Cleanup
		get_tree().create_timer(5.0).timeout.connect(_on_explosion_cleanup.bind(explosion))

	# Screen shake
	var camera_shake_service: Node = GameManager.get_core_system("camera_shake")
	if camera_shake_service and camera_shake_service.has_method("shake"):
		var intensity: float = 1.0
		match explosion_type:
			ExplosionType.SMALL:
				intensity = 0.3
			ExplosionType.MEDIUM:
				intensity = 0.6
			ExplosionType.LARGE:
				intensity = 1.0
			ExplosionType.MASSIVE:
				intensity = 1.5
		camera_shake_service.shake(intensity, 0.5)

	# Screen flash
	if enable_screen_flash:
		var flash_color: Color = Color(1.0, 0.8, 0.4, 0.3)
		screen_flash(flash_color, 0.3)

	explosion_created.emit(position, radius)


func _on_explosion_cleanup(explosion: Node3D) -> void:
	active_explosions -= 1
	if is_instance_valid(explosion):
		explosion.queue_free()


# ============================================================================
# POOLING HELPERS
# ============================================================================


func get_pooled_projectile(projectile_type: String) -> Node:
	var pool_service: Node = GameManager.get_core_system("pools")
	if pool_service and pool_service.has_method("get_instance"):
		return pool_service.get_instance(projectile_type)
	return null


func return_pooled_projectile(projectile: Node) -> void:
	var pool_service: Node = GameManager.get_core_system("pools")
	if pool_service and pool_service.has_method("return_instance"):
		pool_service.return_instance(projectile)


func return_pooled_gib(gib: Node) -> void:
	var pool_service: Node = GameManager.get_core_system("pools")
	if pool_service and pool_service.has_method("return_instance"):
		pool_service.return_instance(gib)


# ============================================================================
# UTILITY
# ============================================================================


func is_feature_enabled(feature: String) -> bool:
	match feature:
		"gore":
			return gore_system != null and gore_system.spawn_gibs
		"decals":
			return decal_spawner != null
		"particles":
			return particle_spawner != null
		_:
			return true


func set_quality(quality: EffectQuality) -> void:
	current_quality = quality

	if particle_spawner:
		particle_spawner.set_quality(quality)
	if decal_spawner:
		decal_spawner.set_quality(quality)


func _on_player_died_event(data: Dictionary) -> void:
	var position: Vector3 = data.get("position", Vector3.ZERO)
	var direction: Vector3 = data.get("direction", Vector3.ZERO)

	spawn_gore_effect.rpc(position, direction, 2.0)


# ============================================================================
# PUBLIC API - Effect Pooling (NEW)
# ============================================================================


## Spawn pooled muzzle flash (reuses objects, no GC pressure)
func spawn_pooled_muzzle_flash(
	pos: Vector3, color: Color = Color.ORANGE, scale: float = 1.0, lifetime: float = 0.05
) -> Node3D:
	if effect_pool_manager:
		return effect_pool_manager.spawn_muzzle_flash(pos, color, scale, lifetime)
	return null


## Spawn pooled particles (reuses objects, no GC pressure)
func spawn_pooled_particles(
	pos: Vector3,
	amount: int = 20,
	lifetime: float = 0.15,
	color: Color = Color.ORANGE,
	spread: float = 15.0,
	velocity_min: float = 2.0,
	velocity_max: float = 5.0
) -> GPUParticles3D:
	if effect_pool_manager:
		return effect_pool_manager.spawn_particles(
			pos, amount, lifetime, color, spread, velocity_min, velocity_max
		)
	return null


## Spawn pooled light (reuses objects, no GC pressure)
func spawn_pooled_light(
	pos: Vector3,
	color: Color = Color.ORANGE,
	energy: float = 3.0,
	light_range: float = 4.0,
	lifetime: float = 0.05
) -> OmniLight3D:
	if effect_pool_manager:
		return effect_pool_manager.spawn_light(pos, color, energy, light_range, lifetime)
	return null


## Spawn pooled shell casing (reuses objects, no GC pressure)
func spawn_pooled_shell_casing(
	pos: Vector3,
	velocity: Vector3,
	angular_velocity: Vector3,
	shell_type: String = "bullet",
	lifetime: float = 5.0
) -> RigidBody3D:
	if effect_pool_manager:
		return effect_pool_manager.spawn_shell_casing(
			pos, velocity, angular_velocity, shell_type, lifetime
		)
	return null


## Get pooling statistics
func get_pool_stats() -> Dictionary:
	if effect_pool_manager:
		return effect_pool_manager.get_stats()
	return {}


## Reset pooling statistics
func reset_pool_stats() -> void:
	if effect_pool_manager:
		effect_pool_manager.reset_stats()
