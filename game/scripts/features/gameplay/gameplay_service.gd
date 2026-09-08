extends Node
class_name GameplaySvc

signal services_ready

var match_service: Node
var combat: Node
var loot: Node
var player: Node
var mission: Node
var inventory: Node
var weather: Node
var difficulty: Node
var enemy_tracker: Node
var entity_registry: Node
var effects: Node

var _is_initialized: bool = false


static func get_service() -> GameplaySvc:
	# Get scene tree
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return null

	# Prefer the canonical GameManager service locator.
	var gm: Node = tree.root.get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_core_system"):
		var svc: Node = gm.get_core_system("gameplay")
		if svc:
			return svc as GameplaySvc

	# Fallback
	if tree.root:
		return tree.root.get_node_or_null("GameplayService") as GameplaySvc
	return null


# === SIGNALS ===

# Subsystem instances (Managed as children)

# === STATE ===


func _ready() -> void:
	name = "GameplayService"
	process_priority = 100  # Process after core systems

	# Initialize subsystems
	_init_subsystems()

	# Defer initialization to allow other autoloads to register
	call_deferred("_initialize_services")


func _init_subsystems() -> void:
	# 1. Instantiate Subsystems
	# These are now child nodes instead of global autoloads

	# DifficultyMgr
	difficulty = _load_and_add(
		"res://game/scripts/features/gameplay/gameplay/difficulty_manager.gd",
		"DifficultyMgr",
	)

	# EnemyTrkr
	enemy_tracker = _load_and_add(
		"res://game/scripts/features/gameplay/gameplay/enemy_tracker.gd", "EnemyTrkr"
	)

	# InventoryMgr
	inventory = _load_and_add(
		"res://game/scripts/features/inventory/inventory_manager.gd",
		"InventoryMgr",
	)

	# WeatherSys
	weather = _load_and_add("res://game/world/actors/weather/weather_system.gd", "WeatherSys")

	# Feature services are loaded from their maintained feature paths.

	# PlayerSvc
	player = _load_and_add("res://game/scripts/features/player/player_service.gd", "PlayerSvc")

	# CombatSvc
	combat = _load_and_add("res://game/scripts/features/combat/combat_service.gd", "CombatSvc")

	# LootSvc
	loot = _load_and_add("res://game/scripts/features/loot/loot_service.gd", "LootSvc")

	# MatchSvc (Often depends on others)
	match_service = _load_and_add("res://game/scripts/features/match/match_service.gd", "MatchSvc")

	# MissionMgr
	mission = _load_and_add(
		"res://game/scripts/features/gameplay/gameplay/mission_manager.gd", "MissionMgr"
	)

	# DamageIndicatorSvc
	_load_and_add(
		"res://game/scripts/features/ui/damage_indicator_service.gd", "DamageIndicatorSvc"
	)

	# EffectsSvc
	effects = _load_and_add("res://game/scripts/features/effects/effects_service.gd", "EffectsSvc")

	# PoolService - Object pooling for projectiles, effects, gibs
	_load_and_add("res://game/scripts/features/performance/pool_service.gd", "PoolService")

	# BloodEffects - Blood/gore effects
	_load_and_add("res://shared/shaders/blood_effects_global.gd", "BloodEffects")

	# GameStateManager - Game state management
	_load_and_add("res://game/scripts/features/gameplay/game_state_manager.gd", "GameStateManager")


func _load_and_add(path: String, node_name: String) -> Node:
	var gm: Node = _get_game_manager()
	# GameManager owns these core services before gameplay is constructed.
	var core_id: String = (
		"player" if node_name == "PlayerSvc" else "match" if node_name == "MatchSvc" else ""
	)
	if gm and not core_id.is_empty():
		var existing: Node = gm.get_core_system(core_id)
		if existing:
			return existing

	var script: GDScript = load(path)
	if not script:
		push_error("[GameplayService] Failed to load script: %s" % path)
		return null

	var node: Node = script.new()
	node.name = node_name
	add_child(node)

	# Register important services with GameManager for global access
	if gm:
		if node_name == "CombatSvc":
			gm.register_core_system("combat", node)
		elif node_name == "EffectsSvc":
			gm.register_core_system("effects", node)
		elif node_name == "MatchSvc":
			gm.register_core_system("match", node)
		elif node_name == "PlayerSvc":
			gm.register_core_system("player", node)
		elif node_name == "LootSvc":
			gm.register_core_system("loot", node)
		elif node_name == "WeatherSys":
			gm.register_core_system("weather", node)
		elif node_name == "PoolService":
			gm.register_core_system("pools", node)
		elif node_name == "BloodEffects":
			gm.register_core_system("blood_effects", node)
		elif node_name == "GameStateManager":
			gm.register_core_system("state_manager", node)

	return node


func _get_game_manager() -> Node:
	var parent_node := get_parent()
	while parent_node:
		if (
			parent_node.has_method("get_core_system")
			and parent_node.has_method("register_core_system")
		):
			return parent_node
		parent_node = parent_node.get_parent()

	return get_node_or_null("/root/GameManager")


func _initialize_services() -> void:
	var gm: Node = _get_game_manager()
	var logger: Variant = gm.get_core_system("logger") if gm else null
	if logger and logger.has_method("info"):
		logger.info("[GameplayService] Initializing subsystems...", "Gameplay")
	else:
		print("[GameplayService] Initializing subsystems...")

	# Initialize in dependency order
	# Many of these might have 'initialize()' methods from GameService base or similar

	# Link to global GameManager.get_core_system("effects") (Autoload)
	effects = gm.get_core_system("effects") if gm else null

	var services: Array[Node] = [
		entity_registry,
		difficulty,
		enemy_tracker,
		inventory,
		weather,
		player,
		combat,
		loot,
		match_service,
		mission,
		effects,
	]

	for service: Node in services:
		if service and service.has_method("initialize"):
			# Check if service is already initialized (some are handled by GameCore)
			if service.has_method("is_service_ready") and service.is_service_ready():
				continue
			# Alternative check for some subsystems
			if "is_initialized" in service and service.is_initialized:
				continue

			if logger and logger.has_method("debug"):
				logger.debug("[GameplayService] Initializing %s" % service.name, "Gameplay")
			else:
				print("[GameplayService] Initializing %s" % service.name)
			if service.initialize.get_argument_count() == 0:
				await service.initialize()

	_is_initialized = true
	services_ready.emit()
	if logger and logger.has_method("info"):
		logger.info("[GameplayService] All systems initialized", "Gameplay")
	else:
		print("[GameplayService] All systems initialized")


# === ACCESSORS ===
# These provide backwards compatibility or clean access


func get_match() -> Node:
	return match_service


func get_combat() -> Node:
	return combat


func get_loot() -> Node:
	return loot


func get_player_service() -> Node:
	return player


func get_mission() -> Node:
	return mission


func get_inventory() -> Node:
	return inventory


func get_weather() -> Node:
	return weather


func get_difficulty() -> Node:
	return difficulty


func get_enemy_tracker() -> Node:
	return enemy_tracker


func get_entity_registry() -> Node:
	return entity_registry
