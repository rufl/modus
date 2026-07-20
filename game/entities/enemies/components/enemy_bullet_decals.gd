class_name EnemyBulletDecals
extends Node

## Manages bullet hit decals on enemy bodies
## Uses pooling for performance optimization
## Uses Sprite3D for GLES3 compatibility

const BULLET_HIT_TEXTURE = preload("res://game/art/textures/decals/bullet_hit.png")
const MAX_DECALS_PER_ENEMY: int = 10

var _enemy: Node3D
var _visuals: SkeletalCharacterVisuals
var _active_decals: Array[Sprite3D] = []
var _decal_pool: Array[Sprite3D] = []


func setup(enemy: Node3D, visuals: SkeletalCharacterVisuals) -> void:
	_enemy = enemy
	_visuals = visuals

	# Pre-warm decal pool
	_prewarm_pool(5)


func _prewarm_pool(count: int) -> void:
	for i in range(count):
		var decal := _create_decal()
		decal.visible = false
		_decal_pool.append(decal)


func _create_decal() -> Sprite3D:
	var decal := Sprite3D.new()
	decal.name = "BulletHitDecal"

	# Configure as decal-like sprite for GLES3 compatibility
	decal.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	decal.shaded = false
	decal.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	decal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	decal.no_depth_test = false
	decal.layers = 0xFFFFF

	decal.texture = BULLET_HIT_TEXTURE

	# Decal settings
	decal.pixel_size = 0.15 / 64.0  # Small bullet hole
	decal.modulate = Color(1, 1, 1, 1)

	# Add to enemy so it moves with the body
	if _visuals and _visuals.mannequin_root:
		_visuals.mannequin_root.add_child(decal)
	elif _enemy:
		_enemy.add_child(decal)

	return decal


func spawn_bullet_decal(hit_position: Vector3, hit_normal: Vector3) -> void:
	GameManager.get_core_system("logger").info(
		(
			"[EnemyBulletDecals] Spawning decal at "
			+ str(hit_position)
			+ " with normal "
			+ str(hit_normal)
		),
		"Enemy"
	)
	GameManager.get_core_system("logger").info(
		"[EnemyBulletDecals] _enemy: " + str(_enemy) + " _visuals: " + str(_visuals), "Enemy"
	)

	# Get decal from pool or create new
	var decal: Sprite3D
	if _decal_pool.size() > 0:
		decal = _decal_pool.pop_back()
		GameManager.get_core_system("logger").info(
			"[EnemyBulletDecals] Got decal from pool, parent: " + str(decal.get_parent()), "Enemy"
		)
	else:
		decal = _create_decal()
		GameManager.get_core_system("logger").info(
			"[EnemyBulletDecals] Created new decal, parent: " + str(decal.get_parent()), "Enemy"
		)

	# Position decal at hit point (convert to local space)
	var local_pos: Vector3
	if _visuals and _visuals.mannequin_root:
		local_pos = _visuals.mannequin_root.to_local(hit_position)
		GameManager.get_core_system("logger").info(
			"[EnemyBulletDecals] Using mannequin_root, local_pos: " + str(local_pos), "Enemy"
		)
	else:
		local_pos = _enemy.to_local(hit_position)
		GameManager.get_core_system("logger").info(
			"[EnemyBulletDecals] Using enemy, local_pos: " + str(local_pos), "Enemy"
		)

	decal.position = local_pos + hit_normal * 0.01  # Slight offset to prevent z-fighting
	GameManager.get_core_system("logger").info(
		"[EnemyBulletDecals] Decal position set to: " + str(decal.position), "Enemy"
	)

	# Orient to surface normal
	if hit_normal != Vector3.ZERO:
		# Check if normal is parallel to up vector to avoid colinear warning
		var up := Vector3.UP
		if abs(hit_normal.dot(up)) > 0.99:
			up = Vector3.RIGHT
		decal.look_at(decal.global_position + hit_normal, up)
		GameManager.get_core_system("logger").info(
			"[EnemyBulletDecals] Decal oriented to normal", "Enemy"
		)

	# Random rotation for variety
	decal.rotate_object_local(Vector3.FORWARD, randf() * TAU)

	# Make visible
	decal.visible = true
	decal.modulate.a = 1.0

	if OS.is_debug_build():
		var logger: Node = GameManager.get_core_system("logger")
		if logger:
			logger.debug(
				(
					"Decal made visible, pixel_size: %s texture: %s"
					% [decal.pixel_size, decal.texture]
				),
				"EnemyBulletDecals"
			)

	# Add to active list
	_active_decals.append(decal)

	# Enforce max decals limit (remove oldest)
	if _active_decals.size() > MAX_DECALS_PER_ENEMY:
		var oldest: Sprite3D = _active_decals.pop_front()
		_return_decal(oldest)

	# Fade out after delay
	_schedule_fade_out(decal, 30.0)


func _schedule_fade_out(decal: Sprite3D, delay: float) -> void:
	await get_tree().create_timer(delay).timeout

	if not is_instance_valid(decal) or not is_instance_valid(self):
		return

	# Fade out over 2 seconds
	var tween := create_tween()
	tween.tween_property(decal, "modulate:a", 0.0, 2.0)
	tween.tween_callback(func() -> void: _return_decal(decal))


func _return_decal(decal: Sprite3D) -> void:
	if not is_instance_valid(decal):
		return

	# Remove from active list
	var idx := _active_decals.find(decal)
	if idx != -1:
		_active_decals.remove_at(idx)

	# Return to pool
	decal.visible = false
	decal.modulate.a = 1.0
	_decal_pool.append(decal)


func clear_all_decals() -> void:
	## Remove all decals (called on death/despawn)
	for decal in _active_decals:
		if is_instance_valid(decal):
			decal.queue_free()

	for decal in _decal_pool:
		if is_instance_valid(decal):
			decal.queue_free()

	_active_decals.clear()
	_decal_pool.clear()


func _exit_tree() -> void:
	clear_all_decals()
