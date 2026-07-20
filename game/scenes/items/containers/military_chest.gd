extends StaticBody3D
class_name MilitaryChest

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

@export var health: int = 0
@export var respawn_time: float = 120.0
@export_group("Loot Configuration")
@export var min_rarity: int = 2  # RARE
@export var max_rarity: int = 4  # LEGENDARY
@export var weapon_count: int = 1
@export var ammo_count: int = 2

var opened: bool = false

@onready var interactable: Interactable = $Interactable

# FIXED C-05: Store timer reference for proper cleanup
var _respawn_timer: SceneTreeTimer = null


func _ready() -> void:
	add_to_group("military_chests")
	add_to_group("interactables")

	# Connect to Interactable component signal
	if interactable:
		interactable.interacted.connect(_on_interacted)


## Handler for Interactable signal


func _on_interacted(interactor: Node) -> void:
	interact(interactor)


## Called when player interacts with the chest


func interact(player: Node) -> void:
	if opened:
		return

	var player_id: int = 1
	if player.has_method("get_multiplayer_authority"):
		player_id = player.get_multiplayer_authority()

	# Request open on server
	if multiplayer.is_server():
		_open_chest(player_id)
	else:
		_request_open.rpc_id(1, player_id)


@rpc("any_peer", "reliable")
func _request_open(opener_id: int) -> void:
	if not multiplayer.is_server():
		return
	if opened:
		return
	_open_chest(opener_id)


func _open_chest(opener_id: int) -> void:
	if opened:
		return
	opened = true

	# Sync to all clients
	_sync_open.rpc()

	# Spawn loot
	call_deferred("_spawn_loot", opener_id)

	# Schedule respawn
	if respawn_time > 0:
		# FIXED C-05: Store timer reference and use named method
		_respawn_timer = get_tree().create_timer(respawn_time)
		_respawn_timer.timeout.connect(_on_respawn_timeout)


func _on_respawn_timeout() -> void:
	## Called when respawn timer completes
	_respawn.rpc()


func _exit_tree() -> void:
	## FIXED C-05: Cleanup signal connections to prevent memory leaks
	if _respawn_timer and _respawn_timer.timeout.is_connected(_on_respawn_timeout):
		_respawn_timer.timeout.disconnect(_on_respawn_timeout)
		_respawn_timer = null


@rpc("authority", "call_local", "reliable")
func _sync_open() -> void:
	opened = true
	_play_open_animation()


@rpc("authority", "call_local", "reliable")
func _respawn() -> void:
	opened = false
	_play_close_animation()


func _play_open_animation() -> void:
	# Animate lid opening (if MeshInstance3D exists)
	var lid: Node3D = get_node_or_null("Lid")
	if lid:
		var tween: Tween = create_tween()
		tween.tween_property(lid, "rotation_degrees:x", -110.0, 0.5)

	# Play chest open sound (low pitch for creaking effect)
	if GameManager.get_core_system("audio"):
		GameManager.get_core_system("audio").play_sound_3d(
			GameManager.get_core_system("audio").BASE_FIRE_SOUND, global_position, 0.3, -3.0
		)


func _play_close_animation() -> void:
	var lid: Node3D = get_node_or_null("Lid")
	if lid:
		var tween: Tween = create_tween()
		tween.tween_property(lid, "rotation_degrees:x", 0.0, 0.3)

	# Play chest close sound (slightly higher pitch than open)
	if GameManager.get_core_system("audio"):
		GameManager.get_core_system("audio").play_sound_3d(
			GameManager.get_core_system("audio").BASE_FIRE_SOUND, global_position, 0.4, -5.0
		)


func _spawn_loot(owner_id: int) -> void:
	var spawn_offset: int = 0

	# Spawn weapons
	for i in range(weapon_count):
		var weapon_data: Dictionary = WeaponGeneratorScript.generate_weapon(
			min_rarity as WeaponGeneratorScript.Rarity, max_rarity as WeaponGeneratorScript.Rarity
		)
		_spawn_weapon_pickup(weapon_data, owner_id, spawn_offset)
		spawn_offset += 1

	# Spawn ammo
	for i in range(ammo_count):
		_spawn_ammo(owner_id, spawn_offset)
		spawn_offset += 1


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

	# Spawn in arc above chest
	var angle: float = (float(offset) / 3.0) * TAU * 0.5
	var spawn_pos: Vector3 = global_position + Vector3(cos(angle) * 0.8, 1.5, sin(angle) * 0.8)
	pickup.global_position = spawn_pos


func _spawn_ammo(owner_id: int, offset: int) -> void:
	var ammo_path: String = "res://game/scenes/items/pickups/ammo_pickup.tscn"
	if not ResourceLoader.exists(ammo_path):
		return

	var scene: PackedScene = load(ammo_path)
	var loot: Node3D = scene.instantiate()

	if "owner_peer_id" in loot:
		loot.owner_peer_id = owner_id

	get_tree().current_scene.add_child(loot)

	var angle: float = (float(offset) / 3.0) * TAU * 0.5 + TAU * 0.25
	var spawn_pos: Vector3 = global_position + Vector3(cos(angle) * 0.6, 1.2, sin(angle) * 0.6)
	loot.global_position = spawn_pos


## Optional: Allow shooting to open (treats damage as interaction trigger)


func take_damage(damage: int, shooter_id: int) -> void:
	if health > 0:
		health -= damage
		if health <= 0 and not opened:
			if multiplayer.is_server():
				_open_chest(shooter_id)
	elif not opened:
		# Health 0 = indestructible, but interact by damage
		if multiplayer.is_server():
			_open_chest(shooter_id)
