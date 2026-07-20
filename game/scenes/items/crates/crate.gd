extends StaticBody3D
class_name Crate

const WeaponGeneratorScript: GDScript = preload(
	"res://game/scripts/features/loot/weapon_generator.gd"
)
const WEAPON_PICKUP_SCENES: Array[String] = [
	"res://game/scenes/items/pickups/pistol_pickup.tscn",
	"res://game/scenes/items/pickups/shotgun_pickup.tscn",
	"res://game/scenes/items/pickups/machinegun_pickup.tscn",
	"res://game/scenes/items/pickups/rocket_launcher_pickup.tscn",
	"res://game/scenes/items/pickups/railgun_pickup.tscn",
]

@export var health: int = 3
@export var respawn_time: float = 30.0
@export_group("Loot Configuration")
@export var weapon_drop_chance: float = 0.25
@export var always_drop_ammo: bool = true
@export var consumable_drop_chance: float = 0.3
@export var powerup_drop_chance: float = 0.1

var destroyed: bool = false

var _max_health: int = 3

# FIXED C-05: Store timer references for proper cleanup
var _respawn_timer: SceneTreeTimer = null
var _destroy_timer: SceneTreeTimer = null


func _ready() -> void:
	add_to_group("crates")
	_max_health = health


## Take damage and break if health depleted (server only processes damage)


func take_damage(damage: int, shooter_id: int) -> void:
	# Only server processes damage
	if not multiplayer.is_server():
		return

	if destroyed:
		return

	health -= damage

	if health <= 0:
		_break.rpc(shooter_id)


## Break the crate (synced via RPC)

@rpc("authority", "call_local", "reliable")
func _break(breaker_id: int) -> void:
	if destroyed:
		return
	destroyed = true

	# Spawn loot (server only) - assigned to whoever broke it
	if multiplayer.is_server():
		_spawn_loot(breaker_id)

	# Visual effects (all clients)
	$MeshInstance3D.hide()
	$CollisionShape3D.set_deferred("disabled", true)
	_spawn_break_particles()

	# Respawn or remove based on respawn_time
	if respawn_time > 0:
		# FIXED C-05: Store timer reference and use named method
		if multiplayer.is_server():
			_respawn_timer = get_tree().create_timer(respawn_time)
			_respawn_timer.timeout.connect(_on_respawn_timeout)
	else:
		# Permanent destruction
		_destroy_timer = get_tree().create_timer(2.0)
		_destroy_timer.timeout.connect(_on_destroy_timeout)


func _on_respawn_timeout() -> void:
	## Called when respawn timer completes
	_respawn.rpc()


func _on_destroy_timeout() -> void:
	## Called when destroy timer completes
	queue_free()


func _exit_tree() -> void:
	## FIXED C-05: Cleanup signal connections to prevent memory leaks
	if _respawn_timer and _respawn_timer.timeout.is_connected(_on_respawn_timeout):
		_respawn_timer.timeout.disconnect(_on_respawn_timeout)
		_respawn_timer = null

	if _destroy_timer and _destroy_timer.timeout.is_connected(_on_destroy_timeout):
		_destroy_timer.timeout.disconnect(_on_destroy_timeout)
		_destroy_timer = null


## Respawn the crate (synced via RPC)

@rpc("authority", "call_local", "reliable")
func _respawn() -> void:
	destroyed = false
	health = _max_health
	$MeshInstance3D.show()
	$CollisionShape3D.set_deferred("disabled", false)


func _spawn_loot(owner_id: int) -> void:
	call_deferred("_finish_spawn_loot", owner_id)


func _finish_spawn_loot(owner_id: int) -> void:
	var spawn_offset: int = 0  # Offset spawns to prevent overlap

	# Roll for weapon drop
	if randf() < weapon_drop_chance:
		var weapon_data: Dictionary = WeaponGeneratorScript.generate_crate_weapon()
		_spawn_weapon_pickup(weapon_data, owner_id, spawn_offset)
		spawn_offset += 1

	# Always or conditionally spawn ammo
	if always_drop_ammo:
		_spawn_ammo(owner_id, spawn_offset)
		spawn_offset += 1

	# Roll for consumable (health/armor)
	if randf() < consumable_drop_chance:
		_spawn_consumable(owner_id, spawn_offset)
		spawn_offset += 1

	# Roll for powerup (speed/damage boost)
	if randf() < powerup_drop_chance:
		_spawn_powerup(owner_id, spawn_offset)


func _spawn_weapon_pickup(weapon_data: Dictionary, owner_id: int, offset: int) -> void:
	var weapon_type: int = weapon_data["weapon_type"]
	if weapon_type >= WEAPON_PICKUP_SCENES.size():
		return

	var scene_path: String = WEAPON_PICKUP_SCENES[weapon_type]
	if not ResourceLoader.exists(scene_path):
		push_warning("Weapon pickup scene not found: " + scene_path)
		return

	var scene: PackedScene = load(scene_path)
	var pickup: Node3D = scene.instantiate()

	# Apply affix indices for network sync
	if "prefix_index" in pickup:
		pickup.prefix_index = weapon_data["prefix_index"]
	if "suffix_index" in pickup:
		pickup.suffix_index = weapon_data["suffix_index"]

	# Assign to owner
	if "owner_peer_id" in pickup:
		pickup.owner_peer_id = owner_id

	get_tree().current_scene.add_child(pickup)
	pickup.global_position = global_position + Vector3(offset * 0.5, 0.5, 0)


func _spawn_ammo(owner_id: int, offset: int) -> void:
	var ammo_path: String = "res://game/scenes/items/pickups/ammo_pickup.tscn"
	if not ResourceLoader.exists(ammo_path):
		return

	var scene: PackedScene = load(ammo_path)
	var loot: Node3D = scene.instantiate()

	if "owner_peer_id" in loot:
		loot.owner_peer_id = owner_id

	get_tree().current_scene.add_child(loot)
	loot.global_position = global_position + Vector3(offset * 0.5, 0.5, 0.3)


func _spawn_consumable(owner_id: int, offset: int) -> void:
	var consumable_scenes: Array[String] = [
		"res://game/scenes/items/pickups/health_pickup.tscn",
		"res://game/scenes/items/pickups/armor_pickup.tscn"
	]

	var scene_path: String = consumable_scenes[randi() % consumable_scenes.size()]
	if not ResourceLoader.exists(scene_path):
		return

	var scene: PackedScene = load(scene_path)
	var loot: Node3D = scene.instantiate()

	if "owner_peer_id" in loot:
		loot.owner_peer_id = owner_id

	get_tree().current_scene.add_child(loot)
	loot.global_position = global_position + Vector3(offset * 0.5, 0.5, -0.3)


func _spawn_powerup(owner_id: int, offset: int) -> void:
	var powerup_scenes: Array[String] = [
		"res://game/scenes/items/pickups/speed_powerup.tscn",
		"res://game/scenes/items/pickups/damage_powerup.tscn"
	]

	var scene_path: String = powerup_scenes[randi() % powerup_scenes.size()]
	if not ResourceLoader.exists(scene_path):
		return

	var scene: PackedScene = load(scene_path)
	var loot: Node3D = scene.instantiate()

	if "owner_peer_id" in loot:
		loot.owner_peer_id = owner_id

	get_tree().current_scene.add_child(loot)
	loot.global_position = global_position + Vector3(offset * 0.5, 0.7, 0.3)


func _spawn_break_particles() -> void:
	call_deferred("_finish_spawn_break_particles")


func _finish_spawn_break_particles() -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 24
	particles.lifetime = 0.8
	particles.explosiveness = 0.9

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.3, 0.3, 0.3)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -10, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.25

	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.6, 0.4, 0.2, 1.0))
	gradient.set_color(1, Color(0.4, 0.3, 0.1, 0.0))
	var gradient_tex: GradientTexture1D = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex

	particles.process_material = mat

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.15, 0.15)
	var quad_mat: StandardMaterial3D = StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.vertex_color_use_as_albedo = true
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = quad_mat
	particles.draw_pass_1 = quad

	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position + Vector3(0, 0.5, 0)

	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(2.0)
	cleanup_timer.timeout.connect(
		func() -> void:
			if is_instance_valid(particles):
				particles.queue_free()
	)
