## EffectsFeature - Feature facade for the visual effects system
##
## The production effect modules are owned by EffectsService. This feature is
## kept as the configurable feature-facing API and delegates to that service.
## It must never construct a second pool, spawner, gore, or tracer tree.
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

## References to the modules owned by EffectsService. They are exposed for
## compatibility with feature-only callers, but are never instantiated here.
var particle_spawner: ParticleSpawner
var decal_spawner: DecalSpawner
var gore_system: GoreSystem
var tracer_renderer: TracerRenderer
var blood_pool_manager: BloodPoolManager
var effect_pool_manager: EffectPoolManager

var current_quality: EffectQuality = EffectQuality.MEDIUM
var max_active_explosions: int = 10
var active_explosions: int = 0
var enable_screen_flash: bool = true
var enable_dynamic_light: bool = true
var enable_scorch_marks: bool = true
var explosion_scene: PackedScene

var _owner: Node
var _owner_error_reported: bool = false


func _init() -> void:
	super._init("effects")
	feature_name = "Effects System"


## Bind this facade to the canonical EffectsService. A missing owner is an
## integration error; do not silently fall back to constructing duplicate
## effect modules.
func initialize() -> void:
	_owner = _find_owner()
	if not _owner:
		_report_missing_owner()
		return

	super.initialize()
	_sync_owner_bindings()
	_connect_owner_signals()


## EffectsService owns all module lifetime. The feature only disconnects its
## signal forwarding and releases references.
func shutdown() -> void:
	_disconnect_owner_signals()
	_owner = null
	particle_spawner = null
	decal_spawner = null
	gore_system = null
	tracer_renderer = null
	blood_pool_manager = null
	effect_pool_manager = null
	super.shutdown()


func _find_owner() -> Node:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("get_core_system"):
		var service: Node = game_manager.get_core_system("effects")
		if service and service != self:
			return service

	# Test fixtures may attach the feature to a local service locator instead of
	# the autoloaded GameManager.
	var parent_node: Node = get_parent()
	while parent_node:
		if parent_node.has_method("get_core_system"):
			var local_service: Node = parent_node.get_core_system("effects")
			if local_service and local_service != self:
				return local_service
		parent_node = parent_node.get_parent()

	return null


func _report_missing_owner() -> void:
	if _owner_error_reported:
		return
	_owner_error_reported = true
	push_error(
		(
			"[EffectsFeature] EffectsService owner not found; "
			+ "the feature facade will remain unavailable"
		)
	)


func _owner_or_null() -> Node:
	if _owner and is_instance_valid(_owner):
		_sync_owner_bindings()
		_connect_owner_signals()
		return _owner

	_owner = _find_owner()
	if not _owner:
		_report_missing_owner()
		return null

	_sync_owner_bindings()
	_connect_owner_signals()
	return _owner


func _sync_owner_bindings() -> void:
	if not _owner or not is_instance_valid(_owner):
		return

	particle_spawner = _owner.get("particle_spawner") as ParticleSpawner
	decal_spawner = _owner.get("decal_spawner") as DecalSpawner
	gore_system = _owner.get("gore_system") as GoreSystem
	tracer_renderer = _owner.get("tracer_renderer") as TracerRenderer
	blood_pool_manager = _owner.get("blood_pool_manager") as BloodPoolManager
	effect_pool_manager = _owner.get("effect_pool_manager") as EffectPoolManager

	if _owner.get("current_quality") != null:
		current_quality = _owner.get("current_quality")
	if _owner.get("max_active_explosions") != null:
		max_active_explosions = _owner.get("max_active_explosions")
	if _owner.get("active_explosions") != null:
		active_explosions = _owner.get("active_explosions")
	if _owner.get("enable_screen_flash") != null:
		enable_screen_flash = _owner.get("enable_screen_flash")
	if _owner.get("enable_dynamic_light") != null:
		enable_dynamic_light = _owner.get("enable_dynamic_light")
	if _owner.get("enable_scorch_marks") != null:
		enable_scorch_marks = _owner.get("enable_scorch_marks")
	if _owner.get("explosion_scene") != null:
		explosion_scene = _owner.get("explosion_scene")


func _connect_owner_signals() -> void:
	if not _owner or not is_instance_valid(_owner):
		return
	if _owner.has_signal("effect_spawned"):
		var effect_callable := Callable(self, "_on_owner_effect_spawned")
		if not _owner.is_connected("effect_spawned", effect_callable):
			_owner.connect("effect_spawned", effect_callable)
	if _owner.has_signal("decal_spawned"):
		var decal_callable := Callable(self, "_on_owner_decal_spawned")
		if not _owner.is_connected("decal_spawned", decal_callable):
			_owner.connect("decal_spawned", decal_callable)
	if _owner.has_signal("explosion_created"):
		var explosion_callable := Callable(self, "_on_owner_explosion_created")
		if not _owner.is_connected("explosion_created", explosion_callable):
			_owner.connect("explosion_created", explosion_callable)
	if _owner.has_signal("service_ready"):
		var ready_callable := Callable(self, "_on_owner_ready")
		if not _owner.is_connected("service_ready", ready_callable):
			_owner.connect("service_ready", ready_callable)


func _disconnect_owner_signals() -> void:
	if not _owner or not is_instance_valid(_owner):
		return
	if _owner.has_signal("effect_spawned"):
		var effect_callable := Callable(self, "_on_owner_effect_spawned")
		if _owner.is_connected("effect_spawned", effect_callable):
			_owner.disconnect("effect_spawned", effect_callable)
	if _owner.has_signal("decal_spawned"):
		var decal_callable := Callable(self, "_on_owner_decal_spawned")
		if _owner.is_connected("decal_spawned", decal_callable):
			_owner.disconnect("decal_spawned", decal_callable)
	if _owner.has_signal("explosion_created"):
		var explosion_callable := Callable(self, "_on_owner_explosion_created")
		if _owner.is_connected("explosion_created", explosion_callable):
			_owner.disconnect("explosion_created", explosion_callable)
	if _owner.has_signal("service_ready"):
		var ready_callable := Callable(self, "_on_owner_ready")
		if _owner.is_connected("service_ready", ready_callable):
			_owner.disconnect("service_ready", ready_callable)


func _on_owner_ready() -> void:
	_sync_owner_bindings()


func spawn_particles(
	scene_path: String,
	pos: Vector3,
	rot: Vector3 = Vector3.ZERO,
	parent: Node3D = null,
	lifetime: float = 5.0
) -> GPUParticles3D:
	var owner := _owner_or_null()
	if owner and owner.has_method("spawn_particles"):
		return (
			owner.call("spawn_particles", scene_path, pos, rot, parent, lifetime) as GPUParticles3D
		)
	return null


func spawn_decal(
	texture: Texture2D,
	pos: Vector3,
	normal: Vector3,
	decal_size: Vector3 = Vector3(1, 1, 1),
	lifetime: float = 30.0
) -> Sprite3D:
	var owner := _owner_or_null()
	if owner and owner.has_method("spawn_decal"):
		return owner.call("spawn_decal", texture, pos, normal, decal_size, lifetime) as Sprite3D
	return null


func spawn_blood_decal(pos: Vector3, normal: Vector3, is_high_velocity: bool = false) -> Sprite3D:
	var owner := _owner_or_null()
	if owner and owner.has_method("spawn_blood_decal"):
		return owner.call("spawn_blood_decal", pos, normal, is_high_velocity) as Sprite3D
	return null


func spawn_bullet_hole(pos: Vector3, normal: Vector3) -> void:
	var owner := _owner_or_null()
	if owner and owner.has_method("spawn_bullet_hole"):
		owner.call("spawn_bullet_hole", pos, normal)


func spawn_gore_effect(
	position: Vector3, death_direction: Vector3 = Vector3.ZERO, intensity: float = 1.0
) -> void:
	var owner := _owner_or_null()
	if owner and owner.has_method("spawn_gore_effect"):
		owner.call("spawn_gore_effect", position, death_direction, intensity)


func spawn_blood_synced(position: Vector3, normal: Vector3, intensity: float = 1.0) -> void:
	var owner := _owner_or_null()
	if owner and owner.has_method("spawn_blood_synced"):
		owner.call("spawn_blood_synced", position, normal, intensity)


func spawn_tracer(
	from: Vector3, to: Vector3, color: Color = Color(1, 0.9, 0.4), lifetime: float = 0.15
) -> void:
	var owner := _owner_or_null()
	if owner and owner.has_method("spawn_tracer"):
		owner.call("spawn_tracer", from, to, color, lifetime)


func spawn_explosion(
	position: Vector3,
	explosion_type: ExplosionType = ExplosionType.MEDIUM,
	damage: float = 100.0,
	radius: float = 5.0
) -> void:
	var owner := _owner_or_null()
	if owner and owner.has_method("spawn_explosion"):
		owner.call("spawn_explosion", position, explosion_type, damage, radius)


func set_quality(quality: EffectQuality) -> void:
	current_quality = quality
	var owner := _owner_or_null()
	if owner and owner.has_method("set_quality"):
		owner.call("set_quality", quality)
		_sync_owner_bindings()


func _on_owner_effect_spawned(effect: Node3D) -> void:
	effect_spawned.emit(effect)


func _on_owner_decal_spawned(decal: Sprite3D) -> void:
	decal_spawned.emit(decal)


func _on_owner_explosion_created(position: Vector3, radius: float) -> void:
	explosion_created.emit(position, radius)
