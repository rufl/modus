extends Node3D

signal grenade_fired(position: Vector3, velocity: Vector3)
signal ammo_changed(current: int, reserve: int)
signal reload_started
signal reload_finished

@export_group("Stats")
@export var damage: float = 120.0
@export var splash_radius: float = 5.5
@export var fire_rate: float = 1.0
@export var clip_size: int = 6
@export var max_reserve_ammo: int = 30
@export var reload_time: float = 2.0
@export_group("Projectile")
@export var grenade_scene: PackedScene = preload("res://game/entities/projectiles/grenade.tscn")
@export var launch_speed: float = 48.0  # Tuned for Quake feel

var current_ammo: int = 6
var reserve_ammo: int = 30
var can_fire: bool = true
var is_reloading: bool = false

var _player: Node3D = null


func _ready() -> void:
	current_ammo = clip_size
	reserve_ammo = max_reserve_ammo

	# Find player parent
	var parent := get_parent()
	while parent:
		if parent.is_in_group("player") or parent.is_in_group("players"):
			_player = parent
			break
		parent = parent.get_parent()


func fire() -> bool:
	if not can_fire or is_reloading or current_ammo <= 0:
		return false

	can_fire = false
	current_ammo -= 1
	ammo_changed.emit(current_ammo, reserve_ammo)

	# Get camera for aim direction
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		var spawn_pos := camera.global_position + (-camera.global_transform.basis.z * 0.5)
		var direction := -camera.global_transform.basis.z

		# Spawn grenade on server, sync to clients
		# Actually for Quake projectiles we usually spawn local for responsiveness
		# or use lag compensation. But respecting existing multiplayer structure:
		if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
			_spawn_grenade(spawn_pos, direction)
		else:
			_request_grenade_spawn.rpc_id(1, spawn_pos, direction)

	# Fire rate cooldown
	# Fire rate cooldown safe timer
	var tween := create_tween()
	tween.tween_interval(1.0 / fire_rate)
	tween.tween_callback(func() -> void: can_fire = true)

	grenade_fired.emit(global_position, -global_transform.basis.z * launch_speed)
	return true


func reload() -> void:
	if is_reloading or current_ammo >= clip_size or reserve_ammo <= 0:
		return

	is_reloading = true
	reload_started.emit()

	await get_tree().create_timer(reload_time).timeout

	var needed := clip_size - current_ammo
	var available := mini(needed, reserve_ammo)
	current_ammo += available
	reserve_ammo -= available

	is_reloading = false
	reload_finished.emit()
	ammo_changed.emit(current_ammo, reserve_ammo)


func add_ammo(amount: int) -> int:
	var can_add := max_reserve_ammo - reserve_ammo
	var actually_added := mini(amount, can_add)
	reserve_ammo += actually_added
	ammo_changed.emit(current_ammo, reserve_ammo)
	return actually_added


func _spawn_grenade(from: Vector3, direction: Vector3) -> void:
	if not grenade_scene:
		return
	call_deferred("_finish_spawn_grenade", from, direction)


func _finish_spawn_grenade(from: Vector3, direction: Vector3) -> void:
	var grenade: Node = grenade_scene.instantiate()
	var tree := get_tree()
	if not tree:
		return

	# Add to current scene so MultiplayerSpawner can detect and replicate it
	# (Spawner watches World/CurrentScene, not Root)
	var scene_root: Node = tree.current_scene
	if scene_root:
		scene_root.add_child(grenade)
	else:
		# Fallback if no current scene (e.g. testing)
		tree.root.add_child(grenade)

	# If grenade has launch method, use it
	if grenade.has_method("launch"):
		grenade.launch(from, direction, _player)
		# Override stats if needed
		if "damage" in grenade:
			grenade.damage = damage
		if "splash_radius" in grenade:
			grenade.splash_radius = splash_radius


@rpc("any_peer", "reliable")
func _request_grenade_spawn(from: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_spawn_grenade(from, direction)
	# No manual sync needed - MultiplayerSpawner handles it
