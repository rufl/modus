class_name LootSvc
extends GameService

signal loot_spawned(position: Vector3, items: Array)

const MAX_PICKUP_DISTANCE: float = 3.0
const PICKUP_SCENE_PATH: String = "res://game/scenes/items/pickups/pickup_base.tscn"
const LOOT_BEACON_SCENE_PATH: String = "res://game/systems/loot/loot_beacon.tscn"
const ITEM_SCENE_MAP: Dictionary = {
	"health_small": "res://game/scenes/items/pickups/health_pickup.tscn",
	"health_medium": "res://game/scenes/items/pickups/health_pickup.tscn",
	"health_large": "res://game/scenes/items/pickups/health_pickup.tscn",
	"health_mega": "res://game/scenes/items/pickups/health_pickup.tscn",
	"ammo_clip": "res://game/scenes/items/pickups/ammo_pickup.tscn",
	"ammo_box": "res://game/scenes/items/pickups/ammo_pickup.tscn",
	"armor_pickup": "res://game/scenes/items/pickups/armor_pickup.tscn",
	"weapon_pistol": "res://game/scenes/items/pickups/pistol_pickup.tscn",
	"weapon_shotgun": "res://game/scenes/items/pickups/shotgun_pickup.tscn",
	"weapon_machinegun": "res://game/scenes/items/pickups/machinegun_pickup.tscn",
	"weapon_rocket_launcher": "res://game/scenes/items/pickups/rocket_launcher_pickup.tscn",
}
const HEALTH_TIER_MAP: Dictionary = {
	"health_small": 1, "health_medium": 2, "health_large": 3, "health_mega": 4
}
const AMMO_TIER_MAP: Dictionary = {"ammo_clip": 1, "ammo_box": 2}

var spawn_beacons: bool = true
var beacon_min_rarity: int = 1  # Uncommon+
var instanced_loot: bool = false
var drop_rate_multiplier: float = 1.0
var rare_chance_bonus: float = 0.0
var pickup_magnet_radius: float = 2.0
var auto_pickup: bool = true
var base_luck: float = 0.0
var kill_streak: int = 0
var luck_bonus_per_kill: float = 0.02
var max_luck_from_kills: float = 0.25
var luck_decay_time: float = 5.0
var _active_pickups: Dictionary = {}  # NodePath -> pickup_data
var _pickup_counter: int = 0
var _last_kill_time: float = 0.0
var _loot_table_cache: Dictionary = {}


static func get_instance() -> LootSvc:
	var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	var gs: Node = (
		gm.get_core_system("gameplay") if gm and gm.has_method("get_core_system") else null
	)
	return gs.loot if gs else null


## Helper method for safe logging
func _log_info(message: String) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger and logger.has_method("info"):
		logger.info(message, "LootService")
	else:
		print(message)


## LootService - Centralized loot spawning service with multiplayer support
##
## Handles:
## - Server-authoritative loot spawning from props/containers
## - Pickup registration and validation
## - Loot beacon visual feedback
## - Multiplayer sync for item pickups


func _ready() -> void:
	name = "LootService"


func get_init_priority() -> int:
	return 45  # After GameManager.get_core_system("effects") (40), before gameplay


func get_dependencies() -> Array[String]:
	return ["config", "effects"]


func initialize() -> void:
	await _wait_for_dependencies()

	# Load configuration
	spawn_beacons = bool(get_config("loot.spawn_beacons", spawn_beacons))
	beacon_min_rarity = int(get_config("loot.beacon_min_rarity", beacon_min_rarity))
	instanced_loot = bool(get_config("loot.instanced_loot", instanced_loot))
	drop_rate_multiplier = float(get_config("loot.drop_rate_multiplier", drop_rate_multiplier))
	rare_chance_bonus = float(get_config("loot.rare_chance_bonus", rare_chance_bonus))
	pickup_magnet_radius = float(get_config("loot.pickup_magnet_radius", pickup_magnet_radius))
	auto_pickup = bool(get_config("loot.auto_pickup", auto_pickup))

	# Connect to events
	subscribe_event("enemy_died", _on_enemy_died_event)

	var gm: Node = get_node_or_null("/root/GameManager")
	var data_service: Node = gm.get_core_system("data") if gm else null
	if data_service and data_service.has_signal("data_reloaded"):
		if not data_service.data_reloaded.is_connected(_on_database_reloaded):
			data_service.data_reloaded.connect(_on_database_reloaded)

	_mark_initialized()
	_log_info(
		(
			"[LootService] Initialized - beacons: %s, r: %d, inst: %s"
			% [spawn_beacons, beacon_min_rarity, instanced_loot]
		)
	)


func _exit_tree() -> void:
	# === SIGNAL HYGIENE ===
	var gm: Node = get_node_or_null("/root/GameManager")
	var data_service: Node = gm.get_core_system("data") if gm else null
	if (
		data_service
		and data_service.has_signal("data_reloaded")
		and data_service.data_reloaded.is_connected(_on_database_reloaded)
	):
		data_service.data_reloaded.disconnect(_on_database_reloaded)

	# Unsubscribe events
	if gm:
		gm.unsubscribe("enemy_died", _on_enemy_died_event)


# =============================================================================
# PUBLIC API - LOOT SPAWNING
# =============================================================================

## Spawn loot from a loot table at position (server-authoritative)
## Called by breakable props, treasure chests, etc.

@rpc("authority", "call_local", "reliable")
func spawn_loot_from_table(
	position: Vector3,
	loot_table_id: String,
	source_path: NodePath = NodePath(),
	owner_peer: int = -1
) -> void:
	# Server authority (in singleplayer, we ARE the server)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Get loot table from database
	var loot_table: LegacyLootTable = _get_loot_table(loot_table_id)
	if not loot_table:
		push_warning("[LootService] Loot table not found: %s" % loot_table_id)
		return

	# Roll for items
	var items: Array = loot_table.roll_loot()
	if items.is_empty():
		return

	# Spawn each item
	var spawned_items: Array = []
	for item_data: ItemData in items:
		var pickup: Node3D = _spawn_pickup(item_data, position, owner_peer)
		if pickup:
			spawned_items.append(pickup.get_path())

	# Emit event
	emit_event(
		"loot_spawned",
		{
			"position": position,
			"items": spawned_items,
			"source": source_path,
			"table_id": loot_table_id
		}
	)

	loot_spawned.emit(position, spawned_items)


## Spawn a specific item at position (server-authoritative)

@rpc("authority", "call_local", "reliable")
func spawn_item(position: Vector3, item_data_path: String, owner_peer: int = -1) -> void:
	# Server authority (in singleplayer, we ARE the server)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var item_data: ItemData = load(item_data_path)
	if not item_data:
		push_warning("[LootService] Failed to load item data: %s" % item_data_path)
		return

	_spawn_pickup(item_data, position, owner_peer)


## Request to pick up an item (client -> server)
## Request to pick up an item (client -> server)

@rpc("any_peer", "reliable")
func request_pickup(pickup_path: NodePath) -> void:
	# Server authority (in singleplayer, we ARE the server)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var peer_id: int = multiplayer.get_remote_sender_id()

	# Rate Limited Validation via NetworkService.network_manager
	# Note: Validation is delegated to NetworkManager for centralized rate limiting
	# and consistent RPC security across all services
	var gm: Node = get_node_or_null("/root/GameManager")
	var ns: Node = gm.get_core_system("network") if gm else null
	if ns and ns.network_manager:
		if not ns.network_manager.validate_rpc(peer_id, "request_pickup", [pickup_path]):
			return

	# Validate pickup exists
	if not _active_pickups.has(pickup_path):
		_deny_pickup.rpc_id(peer_id, pickup_path, "Item no longer exists")
		return

	var pickup_data: Dictionary = _active_pickups[pickup_path]
	var pickup: Node3D = get_node_or_null(pickup_path)

	if not is_instance_valid(pickup):
		_active_pickups.erase(pickup_path)
		_deny_pickup.rpc_id(peer_id, pickup_path, "Item no longer valid")
		return

	# Validate owner restriction
	if pickup_data.owner_peer > 0 and pickup_data.owner_peer != peer_id:
		_deny_pickup.rpc_id(peer_id, pickup_path, "This item is not for you")
		return

	# Validate distance (SERVER-SIDE CHECK)
	var player: Node3D = _get_player_by_peer(peer_id)
	if player:
		var distance: float = player.global_position.distance_to(pickup.global_position)
		if distance > MAX_PICKUP_DISTANCE * 1.5:  # 50% tolerance for lag
			_deny_pickup.rpc_id(peer_id, pickup_path, "Too far away (Distance: %.1f)" % distance)
			push_warning(
				"[LootService] Pickup denied (Too far): Player %d at %.1f m" % [peer_id, distance]
			)
			return
	else:
		_deny_pickup.rpc_id(peer_id, pickup_path, "Player not found")
		return

	# Grant the pickup
	_grant_pickup(peer_id, pickup_path, pickup_data.item_data_path)


## Grant pickup to player (server -> client)

@rpc("authority", "call_local", "reliable")
func _grant_pickup(peer_id: int, pickup_path: NodePath, item_data_path: String) -> void:
	# On server: remove from tracking
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_active_pickups.erase(pickup_path)

		# Destroy pickup for all clients
		_destroy_pickup.rpc(pickup_path)

		# Emit event
		# Emit event - REMOVED to prevent duplicates (PickupBase handles this)
		# emit_event("item_picked_up", {
		# 	"pickup_path": pickup_path,
		# 	"item_data_path": item_data_path,
		# 	"peer_id": peer_id
		# })

		# item_picked_up.emit(pickup_path, peer_id)

	# On owning client: add to inventory
	if peer_id == multiplayer.get_unique_id():
		var item_data: ItemData = load(item_data_path)
		if item_data:
			var gm: Node = get_node_or_null("/root/GameManager")
			var gs: Node = gm.get_core_system("gameplay") if gm else null
			if gs and gs.inventory and gs.inventory.has_method("add_item"):
				gs.inventory.add_item(item_data)
			_log_info("[LootService] Picked up: %s" % item_data.display_name)


## Deny pickup request (server -> client)

@rpc("authority", "call_remote", "reliable")
func _deny_pickup(pickup_path: NodePath, reason: String) -> void:
	_log_info("[LootService] Pickup denied: %s - %s" % [pickup_path, reason])
	# Could show UI feedback here


## Destroy a pickup on all clients

@rpc("authority", "call_local", "reliable")
func _destroy_pickup(pickup_path: NodePath) -> void:
	var pickup: Node3D = get_node_or_null(pickup_path)
	if is_instance_valid(pickup):
		pickup.queue_free()


# =============================================================================
# INTERNAL METHODS
# =============================================================================


func _spawn_pickup(item_data: ItemData, position: Vector3, owner_peer: int) -> Node3D:
	## Spawn a pickup node for an item (server only)
	var pickup: Node3D = null

	# Prefer custom world scene if defined
	if item_data.world_scene:
		pickup = item_data.world_scene.instantiate()
	else:
		# Use generic pickup
		if ResourceLoader.exists(PICKUP_SCENE_PATH):
			var scene: PackedScene = load(PICKUP_SCENE_PATH)
			pickup = scene.instantiate()
		else:
			push_warning("[LootService] No pickup scene for item: %s" % item_data.display_name)
			return null

	# Apply random spread
	var spread: Vector3 = Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5))

	# Configure pickup
	if "item_data" in pickup:
		pickup.item_data = item_data

	if pickup.has_method("set_rarity"):
		pickup.set_rarity(item_data.rarity)

	# Add to scene
	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if scene_root:
		scene_root.add_child(pickup, true)
		pickup.global_position = position + spread
	else:
		pickup.queue_free()
		return

	# Setup multiplayer sync
	_setup_pickup_sync(pickup)

	# Track pickup
	_pickup_counter += 1
	var pickup_path: NodePath = pickup.get_path()
	_active_pickups[pickup_path] = {
		"item_data_path": item_data.resource_path,
		"owner_peer": owner_peer,
		"spawn_time": Time.get_ticks_msec(),
		"rarity": item_data.rarity.tier if item_data.rarity else 0
	}

	# Spawn beacon for rare+ items
	if spawn_beacons and item_data.rarity:
		if item_data.rarity.tier >= beacon_min_rarity:
			_spawn_loot_beacon(position + spread, item_data.rarity.tier)

	return pickup


func _setup_pickup_sync(pickup: Node3D) -> void:
	## Add MultiplayerSynchronizer to pickup if needed
	if pickup.has_node("MultiplayerSynchronizer"):
		return

	var synchronizer: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "MultiplayerSynchronizer"
	synchronizer.replication_interval = 0.1

	# Create replication config
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property(":position")
	synchronizer.replication_config = config

	pickup.add_child(synchronizer)


func _spawn_loot_beacon(position: Vector3, rarity_tier: int) -> void:
	## Spawn visual beacon for loot (client-side effect)
	# Use GameManager.get_core_system("effects") for spawning if available
	var gm: Node = get_node_or_null("/root/GameManager")
	var gs: Node = gm.get_core_system("gameplay") if gm else null
	if gs and gs.effects and gs.effects.has_method("spawn_loot_beacon"):
		gs.effects.spawn_loot_beacon(position, rarity_tier)
		return

	# Fallback: Create simple beacon
	if not ResourceLoader.exists(LOOT_BEACON_SCENE_PATH):
		return

	var beacon_scene: PackedScene = load(LOOT_BEACON_SCENE_PATH)
	var beacon: Node3D = beacon_scene.instantiate()
	beacon.global_position = position

	if beacon.has_method("set_rarity_tier"):
		beacon.set_rarity_tier(rarity_tier)

	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if scene_root:
		scene_root.add_child(beacon)
	else:
		beacon.queue_free()
		return


func _get_loot_table(table_id: String) -> LegacyLootTable:
	## Get loot table by ID from data service or create from JSON
	# Try data service first
	var data_service: Node = GameManager.get_core_system("data")
	if data_service and data_service.has_method("get_loot_table"):
		var data: Dictionary = data_service.get_loot_table(table_id)
		if not data.is_empty():
			return _create_loot_table_from_data(data)

	# Fallback: Try loading resource directly
	var resource_path: String = "res://game/data/loot_tables/%s.tres" % table_id
	if ResourceLoader.exists(resource_path):
		return load(resource_path)

	return null


func _create_loot_table_from_data(data: Dictionary) -> LegacyLootTable:
	## Create LootTable from dictionary data
	var table: LegacyLootTable = LegacyLootTable.new()

	if "min_items" in data:
		table.min_items = data.min_items
	if "max_items" in data:
		table.max_items = data.max_items
	if "rolls" in data:
		table.min_items = data.rolls
		table.max_items = data.rolls

	return table


func _get_player_by_peer(peer_id: int) -> Node3D:
	## Get player node by peer ID using GameManager.get_core_system("entity")
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.entity_registry:
		return gs.entity_registry.get_player(peer_id)
	return null


# =============================================================================
# DEBUG / STATS
# =============================================================================


func get_stats() -> Dictionary:
	return {
		"active_pickups": _active_pickups.size(),
		"total_spawned": _pickup_counter,
		"is_server": multiplayer.is_server() if multiplayer.has_multiplayer_peer() else true
	}


# =============================================================================
# EVENT HANDLERS
# =============================================================================


func _on_database_reloaded() -> void:
	_loot_table_cache.clear()


func _on_enemy_died_signal(enemy: Node, pos: Vector3, killer: Node) -> void:
	# Convert signal to event data
	if not is_instance_valid(enemy):
		return

	var data: Dictionary = {
		"enemy": enemy,
		"position": pos,
		"killer": killer,
		"enemy_id": enemy.enemy_id if "enemy_id" in enemy else "",
		"tier": enemy.tier if "tier" in enemy else 1,
		"attack_type": enemy.attack_type if "attack_type" in enemy else "melee"
	}
	_on_enemy_died_event(data)


func _on_enemy_died_event(data: Dictionary) -> void:
	# Only server spawns loot
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var enemy: Node = data.get("enemy")
	var position: Vector3 = data.get("position", Vector3.ZERO)

	_update_kill_streak()

	var enemy_tier: int = data.get("tier", 1)
	var attack_type: String = data.get("attack_type", "melee")
	var enemy_id: String = data.get("enemy_id", "")

	# Try loot table
	var has_loot_table: bool = false
	var data_service: Node = GameManager.get_core_system("data")
	if not enemy_id.is_empty() and data_service:
		var enemy_data: Dictionary = data_service.get_enemy_data(enemy_id)
		var table_id: String = ""

		# Handle nested vs flat
		if "loot" in enemy_data and "loot_table_id" in enemy_data.loot:
			table_id = enemy_data.loot.loot_table_id
		elif "loot_table_id" in enemy_data:
			table_id = enemy_data.loot_table_id

		if not table_id.is_empty():
			var enemy_path: NodePath = NodePath()
			if enemy and enemy.is_inside_tree():
				enemy_path = enemy.get_path()

			# Instanced logic would go here, for now using global
			if instanced_loot:
				spawn_loot_from_table(position, table_id, enemy_path)
				has_loot_table = true
			else:
				spawn_loot_from_table(position, table_id, enemy_path)
				has_loot_table = true

	# Fallback to tier based
	if not has_loot_table:
		_spawn_tier_based_loot(enemy_tier, attack_type, position)


# =============================================================================
# LUCK & TIER LOGIC
# =============================================================================


func get_current_luck() -> float:
	var streak_bonus: float = minf(kill_streak * luck_bonus_per_kill, max_luck_from_kills)
	return clampf(base_luck + streak_bonus + rare_chance_bonus, 0.0, 1.0)


func _update_kill_streak() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_kill_time > luck_decay_time:
		kill_streak = 0
	kill_streak += 1
	_last_kill_time = current_time


func _spawn_tier_based_loot(enemy_tier: int, attack_type: String, pos: Vector3) -> void:
	var drop_pos: Vector3 = pos + Vector3(0, 0.5, 0)
	var current_luck: float = get_current_luck()

	# Simplified tier logic for brevity (ported from LootManager)
	var spawn_weapon: bool = false
	var weapon_rarity: int = 0
	var consumable_tier: int = 1

	match enemy_tier:
		4:  # Boss
			spawn_weapon = true
			weapon_rarity = 3 if randf() < (0.6 - current_luck * 0.3) else 4
			consumable_tier = 4
		3:  # Elite
			spawn_weapon = randf() < (0.8 + current_luck * 0.15)
			weapon_rarity = 2 if randf() < (0.6 - current_luck * 0.3) else 3
			consumable_tier = 3
		2:  # Normal
			spawn_weapon = randf() < (0.15 + current_luck * 0.2)
			if spawn_weapon:
				weapon_rarity = 1 if randf() < current_luck * 0.4 else 0
			consumable_tier = 2
		_:  # Basic
			spawn_weapon = randf() < (0.05 + current_luck * 0.1)  # Lower chance
			weapon_rarity = 0
			consumable_tier = 1

	if spawn_weapon:
		_spawn_random_weapon(drop_pos, weapon_rarity)
	else:
		_spawn_consumable(drop_pos, attack_type, consumable_tier)


func _spawn_random_weapon(pos: Vector3, rarity_tier: int) -> void:
	var weapon_keys: Array = [
		"weapon_pistol", "weapon_shotgun", "weapon_machinegun", "weapon_rocket_launcher"
	]
	var key: String = weapon_keys.pick_random()
	var scene_path: String = ITEM_SCENE_MAP.get(key, "")
	if not scene_path.is_empty():
		var item_data: ItemData = ItemData.new()  # Create dummy data wrapper
		item_data.item_id = key
		item_data.display_name = key.replace("weapon_", "").capitalize()
		item_data.item_type = ItemData.ItemType.WEAPON
		# Map rarity_tier to appropriate ItemRarity
		var rarity: ItemRarity = ItemRarity.from_tier(rarity_tier)
		item_data.rarity = rarity

		# Actually we should use spawn_item logic which handles scenes
		# But internal _spawn_pickup needs real data.
		# For now, let's load dummy data or just spawn the scene directly?
		# Better: Configure a dummy ItemData properly.
		_spawn_pickup_direct_scene(scene_path, pos, rarity_tier)


func _spawn_consumable(pos: Vector3, attack_type: String, tier: int) -> void:
	var key: String = "health_small"
	# Map tier to size
	if tier >= 4:
		key = "health_mega"
	elif tier == 3:
		key = "health_large"
	elif tier == 2:
		key = "health_medium"

	if attack_type != "melee":
		key = "ammo_clip"
		if tier >= 2:
			key = "ammo_box"

	var scene_path: String = ITEM_SCENE_MAP.get(key, "")
	if not scene_path.is_empty():
		_spawn_pickup_direct_scene(scene_path, pos, 0)  # Consumables have fixed tier usually


func _spawn_pickup_direct_scene(scene_path: String, pos: Vector3, rarity_val: int) -> void:
	if not ResourceLoader.exists(scene_path):
		return
	var scene: PackedScene = load(scene_path)
	var pickup: Node3D = scene.instantiate()
	var tree := get_tree()
	var scene_root: Node = tree.current_scene if tree else null
	if not scene_root and tree:
		scene_root = tree.root

	if scene_root:
		scene_root.add_child(pickup, true)
		pickup.global_position = pos
	else:
		pickup.queue_free()
		return

	if pickup.has_method("set_rarity_tier"):  # If it accepts int tier
		pickup.set_rarity_tier(rarity_val)
	elif pickup.has_method("set_rarity"):  # If it needs resource
		# construct rarity resource
		pass

# Re-implement print_stats at end of file if overwritten
