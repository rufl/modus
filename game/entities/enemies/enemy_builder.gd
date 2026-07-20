class_name EnemyBuilder
extends RefCounted

const EnemyBloodTrailScript = preload("res://game/entities/enemies/components/enemy_blood_trail.gd")


## Create an enemy from data
static func create_enemy(_data: Dictionary) -> Node:
	# Stub implementation - returns null for now
	# Full implementation would instantiate enemy scene and configure it
	push_warning("[EnemyBuilder] create_enemy is a stub - full implementation pending")
	return null


static func build_components(enemy: Node, data: Dictionary) -> void:
	_setup_health(enemy, data)
	_setup_movement(enemy, data)
	_setup_perception(enemy, data)
	_setup_combat(enemy, data)
	_setup_pain_system(enemy, data)
	_setup_gore_systems(enemy, data)
	_setup_status_effects(enemy)
	_setup_damage_handling(enemy)
	_setup_behavior(enemy)
	_setup_loot(enemy, data)


static func _setup_health(enemy: Node, data: Dictionary) -> void:
	var health_comp := HealthComponent.new()
	health_comp.name = "HealthComponent"
	enemy.add_child(health_comp)

	# Self-configure with difficulty scaling
	if "stats" in data:
		var base_health: float = data.stats.get("health", 30)
		health_comp.configure_from_data(base_health, true)

	# Connect health change signal for health bar
	health_comp.health_changed.connect(Callable(enemy, "_on_health_changed"))

	enemy.health_component = health_comp


static func _setup_movement(enemy: Node, data: Dictionary) -> void:
	var movement_comp := MovementComponent.new()
	movement_comp.name = "MovementComponent"
	enemy.add_child(movement_comp)

	# Self-configure
	if "stats" in data:
		movement_comp.configure_from_data(data.stats.get("move_speed", 4.0))

	if "movement" in data:
		movement_comp.configure_advanced(data.movement)

	enemy.movement_component = movement_comp


static func _setup_perception(enemy: Node, data: Dictionary) -> void:
	var perception_comp := PerceptionComponent.new()
	perception_comp.name = "PerceptionComponent"
	enemy.add_child(perception_comp)

	# Self-configure with tier scaling (replaces 30+ lines of manual config)
	# Self-configure with tier scaling
	var perception_config: Dictionary = {}
	if "perception" in data:
		perception_config = data.perception
	else:
		perception_config = data.get("ai_config", {}).get("perception", {})

	perception_comp.configure_from_data(perception_config, enemy.tier)

	# Connect signals for alert icons (use Callable for proper signal connection)
	if (
		not enemy.multiplayer.has_multiplayer_peer()
		or enemy.multiplayer.is_server()
	):
		if not perception_comp.target_spotted.is_connected(Callable(enemy, "_on_target_spotted")):
			perception_comp.target_spotted.connect(Callable(enemy, "_on_target_spotted"))
		if not perception_comp.target_lost.is_connected(Callable(enemy, "_on_target_lost")):
			perception_comp.target_lost.connect(Callable(enemy, "_on_target_lost"))

	enemy.perception_component = perception_comp


static func _setup_combat(enemy: Node, data: Dictionary) -> void:
	var combat_comp := CombatComponent.new()
	combat_comp.name = "CombatComponent"
	enemy.add_child(combat_comp)

	# Self-configure
	if "stats" in data:
		combat_comp.configure_from_data(
			data.stats.get("damage", 5),
			data.stats.get("attack_range", 2.0),
			data.stats.get("attack_cooldown", 1.5)
		)

	# Load projectile scene for ranged enemies
	if "combat" in data:
		var combat_data: Dictionary = data.combat
		if combat_data.has("projectile_scene"):
			var proj_path: String = combat_data.projectile_scene
			if ResourceLoader.exists(proj_path):
				combat_comp.projectile_scene = load(proj_path)
			else:
				push_warning("Projectile scene not found: " + proj_path)

	enemy.combat_component = combat_comp


static func _setup_pain_system(enemy: Node, data: Dictionary) -> void:
	var pain_sys := PainSystem.new()
	pain_sys.name = "PainSystem"
	enemy.add_child(pain_sys)

	# Configure pain from data
	if "pain_config" in data:
		pain_sys.configure_from_data(data.pain_config)

	# Apply tier-based pain resistance (tier 1-2: normal, tier 3: elite, tier 4: boss)
	if enemy.tier >= 4:
		pain_sys.set_boss_mode(true)
	elif enemy.tier >= 3:
		pain_sys.set_elite_mode(true)

	# Also check explicit flags (override tier if set)
	if "ai_config" in data:
		if data.ai_config.get("is_boss", false):
			pain_sys.set_boss_mode(true)
		elif data.ai_config.get("is_elite", false):
			pain_sys.set_elite_mode(true)

	# Connect pain signals (use Callable for proper signal connection)
	pain_sys.pain_triggered.connect(Callable(enemy, "_on_pain_triggered"))

	enemy.pain_system = pain_sys


static func _setup_gore_systems(enemy: Node, data: Dictionary) -> void:
	# Dismemberment System
	var dismemberment_sys := DismembermentSystem.new()
	dismemberment_sys.name = "DismembermentSystem"
	enemy.add_child(dismemberment_sys)

	if "advanced_gore" in data:
		dismemberment_sys.set_enabled(data.advanced_gore.get("dismemberment_enabled", true))

	enemy.dismemberment_system = dismemberment_sys

	# Organ Gib System
	var organ_gib_sys := OrganGibSystem.new()
	organ_gib_sys.name = "OrganGibSystem"
	enemy.add_child(organ_gib_sys)

	if "advanced_gore" in data:
		organ_gib_sys.set_enabled(data.advanced_gore.get("organ_gibs_enabled", true))

	enemy.organ_gib_system = organ_gib_sys

	# Blood Hit Spawner
	var blood_spawner := BloodHitSpawner.new()
	blood_spawner.name = "BloodHitSpawner"
	enemy.add_child(blood_spawner)

	if "advanced_gore" in data:
		blood_spawner.set_enabled(data.advanced_gore.get("directional_spray_enabled", true))

	enemy.blood_hit_spawner = blood_spawner

	# Blood Trail (drips when low health)
	var blood_trail: Node = EnemyBloodTrailScript.new()
	blood_trail.name = "BloodTrail"
	enemy.add_child(blood_trail)
	blood_trail.setup(enemy)


static func _setup_status_effects(enemy: Node) -> void:
	# Status Effect Manager (for receiving DoT from player weapons)
	var status_mgr := StatusEffectManager.new()
	status_mgr.name = "StatusEffectManager"
	enemy.add_child(status_mgr)

	enemy.status_effect_manager = status_mgr


static func _setup_damage_handling(enemy: Node) -> void:
	# Damage Handler (Core combat logic)
	var damage_handler := EnemyDamageHandler.new()
	damage_handler.name = "DamageHandler"
	enemy.add_child(damage_handler)

	damage_handler.setup(enemy, enemy.health_component, enemy.pain_system, enemy.blood_hit_spawner)

	enemy.damage_handler = damage_handler


static func _setup_behavior(enemy: Node) -> void:
	# Behavior Coordinator (Feedback & Events)
	var behavior_coord := EnemyBehaviorCoordinator.new()
	behavior_coord.name = "BehaviorCoordinator"
	enemy.add_child(behavior_coord)

	behavior_coord.setup(enemy, enemy.health_component, enemy.pain_system, enemy.visuals)

	enemy.behavior_coordinator = behavior_coord


static func _setup_loot(enemy: Node, data: Dictionary) -> void:
	if "loot" in data:
		var loot_data: Dictionary = data.loot
		if "loot_table_id" in loot_data:
			if "loot_table_id" in enemy:
				enemy.loot_table_id = loot_data.loot_table_id
				if OS.is_debug_build():
					var tree: SceneTree = Engine.get_main_loop() as SceneTree
					var gm: Node = tree.root.get_node_or_null("/root/GameManager") if tree else null
					var logger: Node = gm.get_core_system("logger") if gm else null
					if logger:
						logger.debug(
							"Assigned loot table: " + str(loot_data.loot_table_id), "EnemyBuilder"
						)
