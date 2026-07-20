extends ModusGutTestBase

# Test MODUS Framework CombatService functionality
# Converted from legacy Dictionary format to GUT assertions

func before_each() -> void:
	await modus_setup()

func after_each() -> void:
	modus_teardown()

func test_service_exists() -> void:
	assert_service_registered_with_gamecore("combat", "CombatService should be registered")

func test_validate_hit() -> void:
	# Test hit validation method exists and returns bool
	assert_service_registered_with_gamecore("combat")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var combat: Node = gm.get_core_system("combat")
		if combat:
			var attacker_pos := Vector3(0, 1, 0)
			var target_pos := Vector3(5, 1, 0)
			var weapon_id := "pistol"

			var result: bool = combat.validate_hit(attacker_pos, target_pos, weapon_id)

			# Currently returns true (stub), just verify it works
			assert_eq(typeof(result), TYPE_BOOL, "validate_hit should return bool")

func test_max_damage_constant() -> void:
	# Verify MAX_DAMAGE constant is defined
	assert_service_registered_with_gamecore("combat")

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var combat: Node = gm.get_core_system("combat")
		if combat:
			var max_dmg: float = combat.MAX_DAMAGE

			assert_gt(max_dmg, 0, "MAX_DAMAGE should be positive")
			assert_le(max_dmg, 10000, "MAX_DAMAGE should be reasonable (not > 10000)")
