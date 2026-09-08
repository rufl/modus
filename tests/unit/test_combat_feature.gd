extends GutTest

## Unit tests for CombatFeature module
## Tests damage calculation, hit validation, and knockback
## Requirements: 12.1

var combat_feature: CombatFeature
var test_target: Node3D
var test_source: Node3D


func before_each():
	# Wait for autoloads to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Create CombatFeature instance
	combat_feature = CombatFeature.new()
	add_child(combat_feature)

	# Initialize with test configuration
	combat_feature.config = {
		"max_damage": 1000.0,
		"critical_multiplier": 2.0,
		"min_damage": 0.1,
		"damage_types":
		{
			"melee": {"armor_penetration": 0.5, "knockback_multiplier": 1.5, "critical_bonus": 0.1},
			"bullet":
			{"armor_penetration": 0.7, "knockback_multiplier": 0.8, "critical_bonus": 0.05},
			"explosive":
			{"armor_penetration": 0.9, "knockback_multiplier": 2.0, "critical_bonus": 0.0}
		},
		"hit_validation": {"enabled": false},  # Disable for unit tests
		"knockback":
		{
			"enabled": true,
			"base_force": 5.0,
			"damage_multiplier": 0.1,
			"max_force": 20.0,
			"vertical_multiplier": 0.5
		}
	}

	combat_feature.initialize()

	# Create test nodes
	test_target = Node3D.new()
	test_target.name = "TestTarget"
	add_child(test_target)

	test_source = Node3D.new()
	test_source.name = "TestSource"
	add_child(test_source)
	test_source.global_position = Vector3.ZERO
	test_target.global_position = Vector3(5, 0, 0)


func after_each():
	if test_target:
		test_target.free()
	if test_source:
		test_source.free()
	if combat_feature:
		combat_feature.free()


## Test: CombatFeature initializes correctly
func test_combat_feature_initialization():
	assert_not_null(combat_feature, "CombatFeature should be created")
	assert_not_null(combat_feature.damage_calculator, "DamageCalculator should be initialized")
	assert_not_null(combat_feature.hit_validator, "HitValidator should be initialized")
	assert_not_null(combat_feature.knockback_system, "KnockbackSystem should be initialized")
	assert_eq(combat_feature.max_damage, 1000.0, "Max damage should be loaded from config")


## Test: Damage calculation with melee damage type
func test_damage_calculation_melee():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 50.0
	damage_info.damage_type = DamageInfo.DamageType.MELEE
	damage_info.is_critical = false
	damage_info.source = test_source

	var final_damage: float = combat_feature.damage_calculator.calculate(damage_info)

	assert_gt(final_damage, 0.0, "Damage should be positive")
	assert_true(final_damage <= 1000.0, "Damage should not exceed max")


## Test: Damage calculation with critical hit
func test_damage_calculation_critical():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 50.0
	damage_info.damage_type = DamageInfo.DamageType.BULLET
	damage_info.is_critical = true
	damage_info.source = test_source

	var final_damage: float = combat_feature.damage_calculator.calculate(damage_info)

	# Critical should apply 2x multiplier
	assert_gt(final_damage, 50.0, "Critical damage should be higher than base")
	assert_true(abs(final_damage - 100.0) < 1.0, "Critical should apply 2x multiplier")


## Test: Damage calculation with explosive damage type
func test_damage_calculation_explosive():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 75.0
	damage_info.damage_type = DamageInfo.DamageType.EXPLOSIVE
	damage_info.is_critical = false
	damage_info.source = test_source

	var final_damage: float = combat_feature.damage_calculator.calculate(damage_info)

	assert_gt(final_damage, 0.0, "Explosive damage should be positive")
	# Explosive damage type is configured in the combat config


## Test: Knockback force calculation
func test_knockback_force_calculation():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 50.0
	damage_info.damage_type = DamageInfo.DamageType.MELEE
	damage_info.source = test_source

	var force: float = combat_feature.knockback_system.calculate_knockback_force(damage_info, 50.0)

	# Base force (5.0) + damage * multiplier (50 * 0.1) = 5.0 + 5.0 = 10.0
	assert_gt(force, 0.0, "Knockback force should be positive")
	assert_true(force <= 20.0, "Knockback force should not exceed max")


## Test: Knockback force with high damage is capped
func test_knockback_force_capped():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 500.0
	damage_info.damage_type = DamageInfo.DamageType.EXPLOSIVE
	damage_info.source = test_source

	var force: float = combat_feature.knockback_system.calculate_knockback_force(damage_info, 500.0)

	# Should be capped at max_force (20.0)
	assert_eq(force, 20.0, "Knockback force should be capped at max_force")


## Test: Critical hit chance calculation
func test_critical_chance_calculation():
	var damage_info := DamageInfo.new()
	damage_info.damage_type = DamageInfo.DamageType.MELEE

	var crit_chance: float = combat_feature.damage_calculator.calculate_critical_chance(damage_info)

	# Base chance (0.05) + melee bonus (0.1) = 0.15
	assert_true(abs(crit_chance - 0.15) < 0.01, "Melee should have 15% crit chance")


## Test: Minimum damage is enforced
func test_minimum_damage_enforced():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 0.01  # Very low damage
	damage_info.damage_type = DamageInfo.DamageType.BULLET
	damage_info.is_critical = false
	damage_info.source = test_source

	var final_damage: float = combat_feature.damage_calculator.calculate(damage_info)

	assert_true(final_damage >= 0.1, "Damage should be at least min_damage (0.1)")


## Test: Maximum damage is enforced in apply_damage
func test_maximum_damage_enforced():
	# Create a mock target with take_damage method
	var mock_target := Node3D.new()
	mock_target.name = "MockTarget"
	mock_target.set_script(load("res://tests/mocks/mock_damage_target.gd"))
	add_child(mock_target)

	var damage_info := DamageInfo.new()
	damage_info.base_amount = 5000.0  # Exceeds max
	damage_info.damage_type = DamageInfo.DamageType.BULLET
	damage_info.source = test_source

	combat_feature.apply_damage(mock_target, damage_info)

	# Should be capped at 1000.0
	assert_true(damage_info.final_damage <= 1000.0, "Damage should be capped at max_damage")

	mock_target.free()


## Test: Damage calculation with BULLET damage type
func test_damage_calculation_bullet():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 40.0
	damage_info.damage_type = DamageInfo.DamageType.BULLET
	damage_info.is_critical = false
	damage_info.source = test_source

	var final_damage: float = combat_feature.damage_calculator.calculate(damage_info)

	assert_gt(final_damage, 0.0, "Bullet damage should be positive")
	assert_true(final_damage <= 1000.0, "Bullet damage should not exceed max")


## Test: Damage calculation with FIRE damage type
func test_damage_calculation_fire():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 30.0
	damage_info.damage_type = DamageInfo.DamageType.FIRE
	damage_info.is_critical = false
	damage_info.source = test_source

	var final_damage: float = combat_feature.damage_calculator.calculate(damage_info)

	assert_gt(final_damage, 0.0, "Fire damage should be positive")


## Test: Damage calculation with POISON damage type
func test_damage_calculation_poison():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 25.0
	damage_info.damage_type = DamageInfo.DamageType.POISON
	damage_info.is_critical = false
	damage_info.source = test_source

	var final_damage: float = combat_feature.damage_calculator.calculate(damage_info)

	assert_gt(final_damage, 0.0, "Poison damage should be positive")


## Test: Damage calculation with ENERGY damage type
func test_damage_calculation_energy():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 100.0
	damage_info.damage_type = DamageInfo.DamageType.ENERGY
	damage_info.is_critical = false
	damage_info.source = test_source

	var final_damage: float = combat_feature.damage_calculator.calculate(damage_info)

	assert_gt(final_damage, 0.0, "Energy damage should be positive")


## Test: Hit validation with valid hit (disabled validation)
func test_hit_validation_disabled():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 50.0
	damage_info.damage_type = DamageInfo.DamageType.BULLET
	damage_info.source = test_source
	damage_info.hit_position = Vector3.ZERO  # No position = should allow

	# Validation is disabled in config, so should always pass
	var is_valid: bool = combat_feature.hit_validator.validate(damage_info)

	assert_true(is_valid, "Hit should be valid when validation is disabled")


## Test: Hit validation with no hit position
func test_hit_validation_no_position():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 50.0
	damage_info.damage_type = DamageInfo.DamageType.MELEE
	damage_info.source = test_source
	damage_info.hit_position = Vector3.ZERO  # No position specified

	var is_valid: bool = combat_feature.hit_validator.validate(damage_info)

	# Should allow damage without position validation
	assert_true(is_valid, "Hit should be valid when no position is specified")


## Test: Hit validation with null damage info
func test_hit_validation_null_damage_info():
	var is_valid: bool = combat_feature.hit_validator.validate(null)

	assert_false(is_valid, "Hit should be invalid with null damage info")


## Test: Knockback force with melee damage type multiplier
func test_knockback_force_melee_multiplier():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 50.0
	damage_info.damage_type = DamageInfo.DamageType.MELEE
	damage_info.source = test_source

	# Calculate damage first to set knockback_multiplier
	var final_damage: float = combat_feature.damage_calculator.calculate(damage_info)

	var force: float = combat_feature.knockback_system.calculate_knockback_force(
		damage_info, final_damage
	)

	# Melee has knockback_multiplier of 1.5 in config
	# Base force (5.0) + damage * multiplier (50 * 0.1) = 10.0
	# Then apply damage type multiplier: 10.0 * 1.5 = 15.0
	assert_gt(force, 10.0, "Melee knockback should be amplified by multiplier")
	assert_true(force <= 20.0, "Knockback should not exceed max")


## Test: Knockback force with explosive damage type multiplier
func test_knockback_force_explosive_multiplier():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 50.0
	damage_info.damage_type = DamageInfo.DamageType.EXPLOSIVE
	damage_info.source = test_source

	# Calculate damage first to set knockback_multiplier
	var final_damage: float = combat_feature.damage_calculator.calculate(damage_info)

	var force: float = combat_feature.knockback_system.calculate_knockback_force(
		damage_info, final_damage
	)

	# Explosive has knockback_multiplier of 2.0 in config
	# Should produce higher knockback than melee
	assert_gt(force, 10.0, "Explosive knockback should be amplified")
	assert_true(force <= 20.0, "Knockback should not exceed max")


## Test: Knockback force with zero damage
func test_knockback_force_zero_damage():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 0.0
	damage_info.damage_type = DamageInfo.DamageType.BULLET
	damage_info.source = test_source

	var force: float = combat_feature.knockback_system.calculate_knockback_force(damage_info, 0.0)

	# Should still have base force
	assert_true(force >= 5.0, "Knockback should have at least base force")


## Test: Damage calculation with armor penetration
func test_damage_calculation_with_armor_penetration():
	var damage_info := DamageInfo.new()
	damage_info.base_amount = 50.0
	damage_info.damage_type = DamageInfo.DamageType.BULLET
	damage_info.armor_penetration = 0.7  # 70% armor penetration
	damage_info.is_critical = false
	damage_info.source = test_source

	var final_damage: float = combat_feature.damage_calculator.calculate(damage_info)

	assert_gt(final_damage, 0.0, "Damage with armor penetration should be positive")
