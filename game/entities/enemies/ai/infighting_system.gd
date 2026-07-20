class_name InfightingSystem
extends Node

signal infight_started(attacker: Node3D, victim: Node3D)
signal infight_ended(enemy: Node3D)

const DEFAULT_ENABLE_INFIGHTING := true
const DEFAULT_TIER_AGGRESSION_ENABLED := true
const DEFAULT_RETALIATION_CHANCE := 0.8
const DEFAULT_INFIGHT_DURATION := 10.0
const DEFAULT_LOWER_TIER_ATTACKS_HIGHER := false
const DEFAULT_SAME_TIER_INFIGHTING := true
const DEFAULT_HIGHER_TIER_ATTACKS_LOWER := true

@export_group("Infighting Settings")
@export var enable_infighting: bool = DEFAULT_ENABLE_INFIGHTING
@export var tier_aggression_enabled: bool = DEFAULT_TIER_AGGRESSION_ENABLED
@export var retaliation_chance: float = DEFAULT_RETALIATION_CHANCE
@export var infight_duration: float = DEFAULT_INFIGHT_DURATION
@export_group("Tier Aggression")
@export var lower_tier_attacks_higher: bool = DEFAULT_LOWER_TIER_ATTACKS_HIGHER
@export var same_tier_infighting: bool = DEFAULT_SAME_TIER_INFIGHTING
@export var higher_tier_attacks_lower: bool = DEFAULT_HIGHER_TIER_ATTACKS_LOWER

var infight_target: Node3D = null
var infight_timer: float = 0.0
var original_target: Node3D = null

var _last_damage_source: Node3D = null
var _parent: Node3D = null
var _health_component: Node = null


func _ready() -> void:
	_parent = get_parent() as Node3D
	if not _parent:
		push_error("[InfightingSystem] Must be child of Node3D")
		return

	_load_config()

	# Respect GameManager.get_core_system("config") toggle (can be disabled by mods or user)
	var gm: Node = get_node_or_null("/root/GameManager")
	var config: Node = gm.get_core_system("config") if gm else null
	if config and config.has_method("is_feature_enabled"):
		enable_infighting = enable_infighting and config.is_feature_enabled("infighting")

	# Connect to health component to detect friendly fire
	_health_component = _parent.get_node_or_null("HealthComponent")
	if _health_component and _health_component.has_signal("damage_received"):
		_health_component.damage_received.connect(_on_damage_received)

	# Also connect to global damage events for source node resolution
	if gm:
		gm.subscribe("damage_dealt", _on_global_damage_dealt_event)


func _exit_tree() -> void:
	# Unsubscribe from global events to prevent null callable errors
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.unsubscribe("damage_dealt", _on_global_damage_dealt_event)


func _on_global_damage_dealt_event(data: Dictionary) -> void:
	var target: Node = data.get("target")
	var source: Node = data.get("source")

	if target and source:
		_on_global_damage_dealt(target, 0.0, source)


func _load_config() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var config: Node = gm.get_core_system("config") if gm else null
	if not config or not config.has_method("get_value"):
		return

	var data: Variant = config.get_value("ai_combat")
	if not data or not data is Dictionary:
		return

	if not data.has("infighting"):
		return
	var cfg: Dictionary = data["infighting"]

	if enable_infighting == DEFAULT_ENABLE_INFIGHTING:
		enable_infighting = cfg.get("enabled", enable_infighting)
	if is_equal_approx(retaliation_chance, DEFAULT_RETALIATION_CHANCE):
		retaliation_chance = cfg.get("retaliation_chance", retaliation_chance)
	if is_equal_approx(infight_duration, DEFAULT_INFIGHT_DURATION):
		infight_duration = cfg.get("duration", infight_duration)

	if cfg.has("tier_aggression"):
		var ta: Dictionary = cfg["tier_aggression"]
		if tier_aggression_enabled == DEFAULT_TIER_AGGRESSION_ENABLED:
			tier_aggression_enabled = ta.get("enabled", tier_aggression_enabled)
		if lower_tier_attacks_higher == DEFAULT_LOWER_TIER_ATTACKS_HIGHER:
			lower_tier_attacks_higher = ta.get("lower_tier_attacks_higher", lower_tier_attacks_higher)
		if same_tier_infighting == DEFAULT_SAME_TIER_INFIGHTING:
			same_tier_infighting = ta.get("same_tier_infighting", same_tier_infighting)
		if higher_tier_attacks_lower == DEFAULT_HIGHER_TIER_ATTACKS_LOWER:
			higher_tier_attacks_lower = ta.get("higher_tier_attacks_lower", higher_tier_attacks_lower)


func _process(delta: float) -> void:
	if infight_timer > 0.0:
		infight_timer -= delta
		if infight_timer <= 0.0:
			_end_infighting()

	# Check if infight target died
	if infight_target and not is_instance_valid(infight_target):
		_end_infighting()


func _on_global_damage_dealt(target: Node, _amount: float, source: Node) -> void:
	# Track damage source when this entity is the target
	if target == _parent and source is Node3D:
		_last_damage_source = source as Node3D


func _on_damage_received(_amount: float, source_id: int, _damage_type: int) -> void:
	if not enable_infighting:
		return

	# Try multiple methods to find the source
	var source: Node3D = _find_damage_source(source_id)
	if not source:
		return

	# Check if damage came from another enemy
	if not source.is_in_group("enemies"):
		return

	# Don't infight with self
	if source == _parent:
		return

	# Check tier-based aggression rules
	if not _should_retaliate(source):
		return

	# Roll for retaliation
	if randf() > retaliation_chance:
		return

	# Start infighting
	_start_infighting(source)


func _find_damage_source(source_id: int) -> Node3D:
	# Method 1: Check cached last damage source
	if is_instance_valid(_last_damage_source):
		var cached := _last_damage_source
		_last_damage_source = null  # Clear after use
		return cached

	# Method 2: Try to find by instance ID (for enemies)
	# instance_id is more reliable for local entities
	if source_id > 0:
		var node := instance_from_id(source_id)
		if node is Node3D:
			return node as Node3D

	# Method 3: Search enemies for matching instance ID
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy.get_instance_id() == source_id:
			return enemy as Node3D

	# Method 4: Try peer ID for players (unlikely for enemy-to-enemy)
	for player: Node in get_tree().get_nodes_in_group("player"):
		if player.has_method("get_multiplayer_authority"):
			if player.get_multiplayer_authority() == source_id:
				return player as Node3D

	return null


func trigger_infighting(attacker: Node3D) -> void:
	if not enable_infighting:
		return

	if not attacker or not attacker.is_in_group("enemies"):
		return

	if attacker == _parent:
		return

	if not _should_retaliate(attacker):
		return

	if randf() > retaliation_chance:
		return

	_start_infighting(attacker)


func notify_damage_from(attacker: Node3D, _damage: float) -> void:
	## External method for direct damage notification
	## Call this when applying splash damage or other indirect damage
	if not enable_infighting:
		return

	if not attacker or not attacker.is_in_group("enemies"):
		return

	if attacker == _parent:
		return

	if not _should_retaliate(attacker):
		return

	if randf() > retaliation_chance:
		return

	_start_infighting(attacker)


func _should_retaliate(attacker: Node3D) -> bool:
	if not tier_aggression_enabled:
		return true

	var my_tier := _get_enemy_tier(_parent)
	var attacker_tier := _get_enemy_tier(attacker)

	# Same tier
	if my_tier == attacker_tier:
		return same_tier_infighting

	# Higher tier deciding whether to attack lower tier
	if my_tier > attacker_tier:
		return higher_tier_attacks_lower

	# Lower tier deciding whether to attack higher tier
	if my_tier < attacker_tier:
		return lower_tier_attacks_higher

	return true


func _get_enemy_tier(target: Node3D) -> int:
	if not target:
		return 0

	# Check for tier in enemy data
	if "tier" in target:
		return target.tier

	if "enemy_tier" in target:
		return target.enemy_tier

	# Check for health-based tier estimation
	var hp: float = 100.0
	if "health" in target:
		hp = target.health
	elif target.has_node("HealthComponent"):
		var hc: Node = target.get_node("HealthComponent")
		if "max_health" in hc:
			hp = hc.max_health

	# Tier based on health pool
	if hp <= 50:
		return 0  # Weak
	if hp <= 150:
		return 1  # Medium
	if hp <= 300:
		return 2  # Strong
	return 3  # Boss


func _start_infighting(target: Node3D) -> void:
	# Store original target if we have one
	if not original_target:
		if "current_target" in _parent:
			original_target = _parent.current_target
		elif _parent.has_method("get_target"):
			original_target = _parent.get_target()

	# Set new infight target
	infight_target = target
	infight_timer = infight_duration

	# Update enemy target
	if _parent.has_method("set_target"):
		_parent.set_target(target)
	elif "current_target" in _parent:
		_parent.current_target = target

	infight_started.emit(_parent, target)

	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger:
		logger.info(
			"[InfightingSystem] %s started infighting with %s" % [_parent.name, target.name],
			"Enemy"
		)


func _end_infighting() -> void:
	if not infight_target:
		return

	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger:
		logger.info(
			"[InfightingSystem] %s ended infighting" % _parent.name, "Enemy"
		)

	# Restore original target
	if original_target and is_instance_valid(original_target):
		if _parent.has_method("set_target"):
			_parent.set_target(original_target)
		elif "current_target" in _parent:
			_parent.current_target = original_target
	else:
		# Find player to target
		var player := get_tree().get_first_node_in_group("player")
		if player:
			if _parent.has_method("set_target"):
				_parent.set_target(player)
			elif "current_target" in _parent:
				_parent.current_target = player

	var _old_target := infight_target
	infight_target = null
	original_target = null

	infight_ended.emit(_parent)


func is_infighting() -> bool:
	return infight_target != null and is_instance_valid(infight_target)


func get_infight_target() -> Node3D:
	return infight_target


func force_end_infighting() -> void:
	infight_timer = 0.0
	_end_infighting()


func extend_infight_duration(additional_time: float) -> void:
	if is_infighting():
		infight_timer += additional_time
