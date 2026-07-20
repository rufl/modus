## CombatFeature - Feature module for combat system
##
## Manages combat-related functionality including damage calculation,
## hit validation, and knockback. Replaces the old CombatService with
## a modular, configuration-driven approach.
##
## Requirements: 2.3
class_name CombatFeature
extends FeatureModule

# Preload combat subsystems
const DamageCalculatorClass = preload("res://game/scripts/features/combat/damage_calculator.gd")
const HitValidatorClass = preload("res://game/scripts/features/combat/hit_validator.gd")
const KnockbackSystemClass = preload("res://game/scripts/features/combat/knockback_system.gd")

## Maximum damage that can be dealt in a single hit
var max_damage: float = 1000.0

## Whether lag compensation is enabled
var lag_compensation_enabled: bool = true

## Whether hit validation is enabled
var hit_validation_enabled: bool = true

## Combat subsystems
var damage_calculator: DamageCalculator
var hit_validator: HitValidator
var knockback_system: KnockbackSystem


## Constructor
func _init() -> void:
	super._init("combat")
	feature_name = "Combat System"


## Initialize the combat feature
func initialize() -> void:
	super.initialize()

	# Load configuration values
	max_damage = get_config_value("max_damage", 1000.0)
	lag_compensation_enabled = get_config_value("lag_compensation.enabled", true)
	hit_validation_enabled = get_config_value("hit_validation.enabled", true)

	# Initialize subsystems
	damage_calculator = DamageCalculatorClass.new(config.get("damage_types", {}), config)
	add_child(damage_calculator)

	hit_validator = HitValidatorClass.new(config.get("hit_validation", {}))
	add_child(hit_validator)

	# Initialize lag compensation for hit validator
	if lag_compensation_enabled:
		var lag_comp_system: Node = _get_lag_compensation_system()
		if lag_comp_system:
			hit_validator.initialize(lag_comp_system)

	knockback_system = KnockbackSystemClass.new(config.get("knockback", {}))
	add_child(knockback_system)

	# Subscribe to combat events
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("subscribe"):
		game_manager.subscribe("damage_requested", _on_damage_requested)
		game_manager.subscribe("hit_detected", _on_hit_detected)


## Shutdown the combat feature
func shutdown() -> void:
	# Unsubscribe from events
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("unsubscribe"):
		game_manager.unsubscribe("damage_requested", _on_damage_requested)
		game_manager.unsubscribe("hit_detected", _on_hit_detected)

	# Clean up subsystems
	if damage_calculator:
		damage_calculator.queue_free()
	if hit_validator:
		hit_validator.queue_free()
	if knockback_system:
		knockback_system.queue_free()

	super.shutdown()


## Apply damage to a target entity
## This is the main public API for dealing damage
func apply_damage(target: Node, damage_info: DamageInfo) -> void:
	if not target or not is_instance_valid(target):
		push_warning("CombatFeature: Invalid target for damage")
		return

	# Validate hit if enabled
	if hit_validation_enabled and not hit_validator.validate(damage_info):
		return

	# Calculate final damage
	var final_damage: float = damage_calculator.calculate(damage_info)

	# Cap damage at maximum
	if final_damage > max_damage:
		final_damage = max_damage

	# Apply damage to target
	if target.has_method("take_damage"):
		damage_info.final_damage = final_damage
		target.take_damage(damage_info)

		# Emit damage dealt event
		var game_manager: Node = get_node_or_null("/root/GameManager")
		if game_manager and game_manager.has_method("emit_event"):
			game_manager.emit_event(
				"damage_dealt",
				{
					"target": target,
					"amount": final_damage,
					"source": damage_info.source,
					"is_critical": damage_info.is_critical
				}
			)

		# Apply knockback if enabled
		if config.get("knockback", {}).get("enabled", true):
			knockback_system.apply_knockback(target, damage_info, final_damage)


## Event handler for damage requests
func _on_damage_requested(data: Dictionary) -> void:
	var target: Node = data.get("target")
	var damage_info: DamageInfo = data.get("damage_info")

	if target and damage_info:
		apply_damage(target, damage_info)


## Event handler for hit detection
func _on_hit_detected(_data: Dictionary) -> void:
	# Handle hit detection events
	# This can be used for additional processing when hits are detected
	pass


## Get lag compensation system from NetworkService
func _get_lag_compensation_system() -> Node:
	# TODO(v1.1, @network-team): Implement lag compensation system
	#
	# IMPACT: Without lag compensation, hit registration in high-latency scenarios
	# (>100ms) will feel inaccurate. Players will see hits that the server rejects.
	#
	# Implementation plan:
	# 1. Implement server-side rewind system (store player positions per tick)
	# 2. Add client timestamp to hit RPCs
	# 3. Rewind server state to client's timestamp
	# 4. Validate hit at rewound position
	# 5. Apply damage if valid
	# 6. Add client-side prediction validation
	# 7. Implement anti-cheat checks (max rewind time, position validation)
	# 8. Add configuration for rewind buffer size and max latency
	#
	# Estimated effort: 40-60 hours
	# Priority: HIGH for competitive multiplayer, MEDIUM for co-op
	#
	# WORKAROUND: Current hit detection uses immediate server position.
	# Works acceptably for LAN (<50ms) and low-latency (<100ms) connections.
	# For high-latency games, recommend host-side hit detection or accept
	# the limitation.

	return null  # Not implemented - returns null
