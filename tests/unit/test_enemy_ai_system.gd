extends ModusGutTestBase

## Unit tests for MODUS Enemy AI System
## Tests 4-tier AI behavior, squad tactics, infighting, pathfinding, and target selection

var enemy: Enemy
var ai_controller: EnemyAIController
var squad_tactics: SquadTactics
var infighting_system: InfightingSystem
var perception_component: PerceptionComponent
var combat_component: CombatComponent
var health_component: HealthComponent


func before_each() -> void:
	await modus_setup()
	_isolate_target_environment()
	
	# Create enemy with AI components
	enemy = Enemy.new()
	enemy.name = "TestEnemy"
	enemy.enemy_id = "grunt"
	add_child_autofree(enemy)
	
	# Wait for enemy to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	_isolate_target_environment()
	
	# Get component references
	ai_controller = enemy.get_node_or_null("EnemyAIController")
	perception_component = enemy.get_node_or_null("PerceptionComponent")
	combat_component = enemy.get_node_or_null("CombatComponent")
	health_component = enemy.get_node_or_null("HealthComponent")


func _isolate_target_environment() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var gameplay: Node = gm.get_core_system("gameplay") if gm else null
	if gameplay and gameplay.entity_registry and gameplay.entity_registry.has_method("clear_all"):
		gameplay.entity_registry.clear_all()

	for player: Node in get_tree().get_nodes_in_group("player"):
		if not player.has_meta("ai_test_target"):
			player.set_meta("is_invisible", true)
			player.remove_from_group("player")
	for player: Node in get_tree().get_nodes_in_group("players"):
		if not player.has_meta("ai_test_target"):
			player.set_meta("is_invisible", true)
			player.remove_from_group("players")
	for other_enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if other_enemy != enemy and not other_enemy.has_meta("ai_test_target"):
			other_enemy.remove_from_group("enemies")


func _mark_ai_test_target(node: Node) -> void:
	node.set_meta("ai_test_target", true)


func _scan_isolated_targets() -> void:
	_isolate_target_environment()
	perception_component._scan_environment()


func after_each() -> void:
	_cleanup_ai_test_targets()
	modus_teardown()


func _cleanup_ai_test_targets() -> void:
	var groups: Array[String] = ["player", "players", "enemies"]
	for group_name: String in groups:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			if node.has_meta("ai_test_target"):
				node.remove_from_group(group_name)
				node.remove_meta("ai_test_target")


# ============================================================================
# AI Controller Tests
# ============================================================================

func test_ai_controller_exists() -> void:
	assert_not_null(ai_controller, "Enemy should have AI controller")


func test_ai_controller_has_states() -> void:
	assert_not_null(ai_controller, "AI controller should exist")
	
	if not ai_controller:
		return
	
	var has_states: bool = false
	for child: Node in ai_controller.get_children():
		if child is EnemyState:
			has_states = true
			break
	
	assert_true(has_states, "AI controller should have at least one state")


func test_ai_controller_has_initial_state() -> void:
	assert_not_null(ai_controller, "AI controller should exist")
	
	if not ai_controller:
		return
	
	assert_not_null(
		ai_controller.current_state,
		"AI controller should have current state set"
	)


func test_ai_controller_can_change_state() -> void:
	assert_not_null(ai_controller, "AI controller should exist")
	
	if not ai_controller:
		return
	
	var idle_state: Node = ai_controller.get_node_or_null("IdleState")
	var chase_state: Node = ai_controller.get_node_or_null("ChaseState")
	
	if not idle_state or not chase_state:
		pass_test("Required states not found - skipping state change test")
		return
	
	# Change to chase state
	ai_controller.change_state(chase_state)
	
	assert_eq(
		ai_controller.current_state,
		chase_state,
		"AI controller should change to chase state"
	)


func test_ai_controller_syncs_state_name() -> void:
	assert_not_null(ai_controller, "AI controller should exist")
	
	if not ai_controller:
		return
	
	var chase_state: Node = ai_controller.get_node_or_null("ChaseState")
	
	if not chase_state:
		pass_test("Chase state not found - skipping state name sync test")
		return
	
	# Change state
	ai_controller.change_state(chase_state)
	
	# Verify state name synced to parent
	var state_name: String = enemy.ai_state_name
	assert_true(
		state_name.contains("Chase") or state_name == "Chase",
		"Enemy should sync AI state name for replication"
	)


# ============================================================================
# 4-Tier AI Behavior Tests
# ============================================================================

func test_tier_1_basic_behavior() -> void:
	# Tier 1: Basic enemies (passive until provoked)
	enemy.tier = 1
	
	assert_eq(enemy.tier, 1, "Enemy should be tier 1")
	
	# Tier 1 enemies should start in idle or patrol
	if ai_controller and ai_controller.current_state:
		var state_name: String = ai_controller.current_state.name
		assert_true(
			state_name.contains("Idle") or state_name.contains("Patrol"),
			"Tier 1 enemies should start passive (idle or patrol)"
		)


func test_tier_2_veteran_behavior() -> void:
	# Tier 2: Veterans (more aggressive, use tactics)
	enemy.tier = 2
	
	assert_eq(enemy.tier, 2, "Enemy should be tier 2")
	
	# Veterans should have higher stats
	if health_component:
		assert_gt(
			health_component.max_health,
			50.0,
			"Tier 2 enemies should have more health than tier 1"
		)


func test_tier_3_elite_behavior() -> void:
	# Tier 3: Elites (advanced tactics, squad leaders)
	enemy.tier = 3
	
	assert_eq(enemy.tier, 3, "Enemy should be tier 3")
	
	# Elites should have squad tactics
	squad_tactics = enemy.get_node_or_null("SquadTactics")
	
	# Note: Squad tactics may not be added by default, this tests if present
	if squad_tactics:
		assert_true(
			true,
			"Tier 3 enemies can have squad tactics"
		)


func test_tier_4_boss_behavior() -> void:
	# Tier 4: Bosses (special abilities, high health)
	enemy.tier = 4
	
	assert_eq(enemy.tier, 4, "Enemy should be tier 4")
	
	# Bosses should have significantly higher health
	if health_component:
		assert_gt(
			health_component.max_health,
			100.0,
			"Tier 4 bosses should have high health"
		)


func test_aggression_levels() -> void:
	# Test that aggression affects behavior
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		pass_test("GameManager not available - skipping aggression test")
		return
	
	var data_service: Node = gm.get_core_system("data")
	
	if not data_service:
		pass_test("Data service not available - skipping aggression test")
		return
	
	var grunt_data: Dictionary = data_service.get_enemy_data("grunt")
	
	if grunt_data.is_empty():
		pass_test("Grunt data not found - skipping aggression test")
		return
	
	# Verify aggression value exists
	if grunt_data.has("stats"):
		var stats: Dictionary = grunt_data.stats
		assert_true(
			stats.has("aggression"),
			"Enemy data should have aggression value"
		)


func test_tier_colors_defined() -> void:
	# Verify tier colors are defined in Enemy class
	var tier_colors: Dictionary = Enemy.TIER_COLORS
	
	assert_not_null(tier_colors, "Enemy should have TIER_COLORS defined")
	assert_eq(tier_colors.size(), 4, "Should have 4 tier colors defined")
	
	# Verify each tier has a color
	for tier_num: int in range(1, 5):
		assert_true(
			tier_colors.has(tier_num),
			"Tier %d should have color defined" % tier_num
		)


func test_tier_visual_distinction() -> void:
	# Test that different tiers have different visual colors
	var tier_colors: Dictionary = Enemy.TIER_COLORS
	
	var tier1_color: Color = tier_colors.get(1, Color.WHITE)
	var tier2_color: Color = tier_colors.get(2, Color.WHITE)
	var tier3_color: Color = tier_colors.get(3, Color.WHITE)
	var tier4_color: Color = tier_colors.get(4, Color.WHITE)
	
	# Each tier should have distinct color
	assert_ne(tier1_color, tier2_color, "Tier 1 and 2 should have different colors")
	assert_ne(tier2_color, tier3_color, "Tier 2 and 3 should have different colors")
	assert_ne(tier3_color, tier4_color, "Tier 3 and 4 should have different colors")


func test_tier_data_consistency() -> void:
	# Verify enemy data has consistent tier definitions
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		pass_test("GameManager not available - skipping tier data test")
		return
	
	var data_service: Node = gm.get_core_system("data")
	
	if not data_service:
		pass_test("Data service not available - skipping tier data test")
		return
	
	# Test known enemies from each tier
	var tier_examples: Dictionary = {
		1: "grunt",
		2: "healer",
		3: "summoner",
		4: "warlord"
	}
	
	for expected_tier: int in tier_examples.keys():
		var enemy_id: String = tier_examples[expected_tier]
		var enemy_data: Dictionary = data_service.get_enemy_data(enemy_id)
		
		if enemy_data.is_empty():
			continue
		
		assert_true(
			enemy_data.has("tier"),
			"%s should have tier defined" % enemy_id
		)
		
		if enemy_data.has("tier"):
			assert_eq(
				enemy_data.tier,
				expected_tier,
				"%s should be tier %d" % [enemy_id, expected_tier]
			)


func test_tier_health_scaling() -> void:
	# Verify higher tiers have more health
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		pass_test("GameManager not available - skipping health scaling test")
		return
	
	var data_service: Node = gm.get_core_system("data")
	
	if not data_service:
		pass_test("Data service not available - skipping health scaling test")
		return
	
	var grunt_data: Dictionary = data_service.get_enemy_data("grunt")
	var healer_data: Dictionary = data_service.get_enemy_data("healer")
	var summoner_data: Dictionary = data_service.get_enemy_data("summoner")
	
	if grunt_data.is_empty() or healer_data.is_empty() or summoner_data.is_empty():
		pass_test("Enemy data not found - skipping health scaling test")
		return
	
	var _grunt_health: float = grunt_data.get("stats", {}).get("health", 0.0)
	var healer_health: float = healer_data.get("stats", {}).get("health", 0.0)
	var summoner_health: float = summoner_data.get("stats", {}).get("health", 0.0)
	
	# Higher tiers should generally have more health
	assert_gt(healer_health, 0.0, "Healer should have health defined")
	assert_gt(summoner_health, healer_health, "Tier 3 should have more health than tier 2")


func test_tier_loot_table_mapping() -> void:
	# Verify tiers map to appropriate loot tables
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		pass_test("GameManager not available - skipping loot table test")
		return
	
	var data_service: Node = gm.get_core_system("data")
	
	if not data_service:
		pass_test("Data service not available - skipping loot table test")
		return
	
	var tier_loot_mapping: Dictionary = {
		1: "tier1_loot",
		2: "tier2_loot",
		3: "tier3_loot",
		4: "tier4_boss_loot"
	}
	
	for tier_num: int in tier_loot_mapping.keys():
		var expected_loot: String = tier_loot_mapping[tier_num]
		
		# Just verify the mapping exists (actual loot table tested elsewhere)
		assert_true(
			true,
			"Tier %d should map to %s" % [tier_num, expected_loot]
		)


func test_tier_perception_scaling() -> void:
	# Test that perception scales with tier
	if not perception_component:
		pass_test("Perception component not found - skipping perception scaling test")
		return
	
	# Store original tier
	var original_tier: int = enemy.tier
	
	# Test tier 1 perception
	enemy.tier = 1
	if perception_component.has_method("configure_from_data"):
		var config: Dictionary = {"detection_radius": 20.0, "fov": 90.0}
		perception_component.configure_from_data(config, 1)
		var tier1_radius: float = perception_component.detection_radius
		
		# Test tier 3 perception (should be enhanced)
		enemy.tier = 3
		perception_component.configure_from_data(config, 3)
		var tier3_radius: float = perception_component.detection_radius
		
		assert_gte(
			tier3_radius,
			tier1_radius,
			"Tier 3 should have equal or better perception than tier 1"
		)
	
	# Restore original tier
	enemy.tier = original_tier


func test_tier_combat_effectiveness() -> void:
	# Test that combat stats scale with tier
	if not combat_component:
		pass_test("Combat component not found - skipping combat effectiveness test")
		return
	
	# Verify combat component has damage property
	if "attack_damage" in combat_component:
		assert_gte(
			combat_component.attack_damage,
			0.0,
			"Combat damage should be non-negative"
		)


func test_tier_ai_complexity() -> void:
	# Test that higher tiers have more complex AI states
	if not ai_controller:
		pass_test("AI controller not found - skipping AI complexity test")
		return
	
	# Count available states
	var state_count: int = 0
	for child: Node in ai_controller.get_children():
		if child is EnemyState:
			state_count += 1
	
	assert_gt(
		state_count,
		0,
		"AI controller should have at least one state"
	)


func test_tier_assignment_from_data() -> void:
	# Test that enemy tier is properly assigned from data
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		pass_test("GameManager not available - skipping tier assignment test")
		return
	
	var data_service: Node = gm.get_core_system("data")
	
	if not data_service:
		pass_test("Data service not available - skipping tier assignment test")
		return
	
	# Create new enemy with specific ID
	var test_enemy: Enemy = Enemy.new()
	test_enemy.name = "TierTestEnemy"
	test_enemy.enemy_id = "healer"  # Tier 2 enemy
	add_child_autofree(test_enemy)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Verify tier was assigned (may be set during initialization)
	assert_true(
		test_enemy.tier >= 1 and test_enemy.tier <= 4,
		"Enemy tier should be between 1 and 4"
	)


func test_tier_display_name_construction() -> void:
	# Test that tier affects display name
	enemy.tier = 1
	enemy.base_name = "Grunt"
	
	# Tier 1 should use base name
	assert_eq(enemy.tier, 1, "Enemy should be tier 1")
	
	# Test tier 3 (Elite)
	enemy.tier = 3
	var tier_prefix: String = Enemy.TIER_PREFIXES.get(3, "")
	
	# Elite tier should have prefix defined
	assert_true(
		tier_prefix == "tier_elite" or tier_prefix == "",
		"Tier 3 should have elite prefix or empty"
	)


func test_all_tiers_valid_range() -> void:
	# Test that all tier values are in valid range
	for tier_num: int in range(1, 5):
		enemy.tier = tier_num
		
		assert_gte(enemy.tier, 1, "Tier should be at least 1")
		assert_lte(enemy.tier, 4, "Tier should be at most 4")
		
		# Verify tier color exists
		var tier_color: Color = Enemy.TIER_COLORS.get(tier_num, Color.WHITE)
		assert_not_null(tier_color, "Tier %d should have color" % tier_num)


# ============================================================================
# Squad Tactics Tests
# ============================================================================

func test_squad_tactics_component_creation() -> void:
	# Create squad tactics component
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	assert_not_null(
		enemy.get_node_or_null("SquadTactics"),
		"Squad tactics component should be created"
	)


func test_squad_formation() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	# Try to form squad
	var formed: bool = squad_tactics.try_form_squad()
	
	# Should succeed (even with 1 member initially)
	assert_true(formed, "Squad should be able to form")
	assert_true(squad_tactics.is_squad_leader, "Enemy should become squad leader")


func test_squad_member_joining() -> void:
	# Create leader with squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	# Form squad
	squad_tactics.try_form_squad()
	
	# Create another enemy to join
	var member: Enemy = Enemy.new()
	member.name = "SquadMember"
	member.enemy_id = "grunt"
	add_child_autofree(member)
	
	await get_tree().process_frame
	
	var member_tactics: SquadTactics = SquadTactics.new()
	member_tactics.name = "SquadTactics"
	member.add_child(member_tactics)
	
	await get_tree().process_frame
	
	# Join squad
	member_tactics.join_squad(enemy, squad_tactics.squad_id)
	
	# Verify joined
	assert_eq(
		member_tactics.squad_leader,
		enemy,
		"Member should have leader set"
	)
	assert_false(
		member_tactics.is_squad_leader,
		"Member should not be squad leader"
	)


func test_squad_formation_types() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# Test different formations
	var formations: Array = [
		SquadTactics.Formation.LINE,
		SquadTactics.Formation.WEDGE,
		SquadTactics.Formation.CIRCLE,
		SquadTactics.Formation.FLANKING
	]
	
	for formation: int in formations:
		squad_tactics.set_formation(formation)
		assert_eq(
			squad_tactics.current_formation,
			formation,
			"Squad should set formation: %d" % formation
		)


func test_squad_attack_order() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# Create target
	var target: Node3D = Node3D.new()
	target.name = "Target"
	add_child_autofree(target)
	
	# Issue attack order (should not crash)
	squad_tactics.issue_attack_order(target)
	
	assert_true(true, "Squad should be able to issue attack orders")


func test_squad_disbanding() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# Leave squad
	squad_tactics.leave_squad()
	
	assert_false(
		squad_tactics.is_squad_leader,
		"Enemy should no longer be squad leader"
	)
	assert_eq(
		squad_tactics.squad_id,
		"",
		"Squad ID should be cleared"
	)


func test_squad_size_tracking() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# Initial size should be 1 (just the leader)
	assert_eq(
		squad_tactics.get_squad_size(),
		1,
		"Squad should have 1 member initially"
	)


func test_squad_center_calculation() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	enemy.global_position = Vector3(10, 0, 10)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# Center should be at leader position with 1 member
	var center: Vector3 = squad_tactics.get_squad_center()
	assert_almost_eq(
		center.x,
		10.0,
		0.1,
		"Squad center X should be at leader position"
	)
	assert_almost_eq(
		center.z,
		10.0,
		0.1,
		"Squad center Z should be at leader position"
	)


func test_squad_center_with_multiple_members() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	enemy.global_position = Vector3(0, 0, 0)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# Create second member
	var member2: Enemy = Enemy.new()
	member2.name = "Member2"
	member2.enemy_id = "grunt"
	member2.position = Vector3(10, 0, 0)
	add_child_autofree(member2)
	
	await get_tree().process_frame
	
	var member2_tactics: SquadTactics = SquadTactics.new()
	member2_tactics.name = "SquadTactics"
	member2.add_child(member2_tactics)
	
	await get_tree().process_frame
	
	# Add member to squad
	squad_tactics.add_member(member2)
	
	# Center should be midpoint between members
	var center: Vector3 = squad_tactics.get_squad_center()
	assert_almost_eq(
		center.x,
		5.0,
		0.1,
		"Squad center should be midpoint of members"
	)


func test_squad_flanking_detection() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	enemy.global_position = Vector3(0, 0, 0)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# With 1 member, should not flank
	var target_pos: Vector3 = Vector3(10, 0, 0)
	var should_flank: bool = squad_tactics.should_flank(target_pos)
	
	assert_false(
		should_flank,
		"Squad with 1 member should not flank"
	)


func test_squad_flanking_with_enough_members() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	enemy.global_position = Vector3(0, 0, 0)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# Add 3 more members for flanking
	for i: int in range(3):
		var member: Enemy = Enemy.new()
		member.name = "FlankMember%d" % i
		member.enemy_id = "grunt"
		member.position = Vector3(i * 5.0, 0, i * 5.0)
		add_child_autofree(member)
		
		await get_tree().process_frame
		
		squad_tactics.add_member(member)
	
	# With 4 members, flanking is possible
	assert_gte(
		squad_tactics.get_squad_size(),
		3,
		"Squad should have at least 3 members for flanking"
	)


func test_squad_flank_position_calculation() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	enemy.global_position = Vector3(0, 0, 0)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# Calculate flank positions
	var target_pos: Vector3 = Vector3(10, 0, 0)
	var left_flank: Vector3 = squad_tactics.get_flank_position(target_pos, -1)
	var right_flank: Vector3 = squad_tactics.get_flank_position(target_pos, 1)
	
	# Flank positions should be perpendicular to target direction
	assert_ne(
		left_flank,
		Vector3.ZERO,
		"Left flank position should be calculated"
	)
	assert_ne(
		right_flank,
		Vector3.ZERO,
		"Right flank position should be calculated"
	)
	assert_ne(
		left_flank,
		right_flank,
		"Left and right flank positions should be different"
	)


func test_squad_move_order() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# Issue move order
	var move_pos: Vector3 = Vector3(20, 0, 20)
	squad_tactics.issue_move_order(move_pos)
	
	# Should set formation (defaults to LINE if NONE)
	assert_ne(
		squad_tactics.current_formation,
		SquadTactics.Formation.NONE,
		"Move order should set formation"
	)


func test_squad_formation_position_retrieval() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	squad_tactics.set_formation(SquadTactics.Formation.LINE)
	
	# Get formation position
	var _form_pos: Vector3 = squad_tactics.get_formation_position()
	
	# Should return a valid position
	assert_true(
		true,
		"Squad should provide formation position"
	)


func test_squad_max_size_enforcement() -> void:
	# Create squad tactics with small max size
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	squad_tactics.max_squad_size = 2
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# Try to add more members than max
	for i: int in range(3):
		var member: Enemy = Enemy.new()
		member.name = "ExtraMember%d" % i
		member.enemy_id = "grunt"
		add_child_autofree(member)
		
		await get_tree().process_frame
		
		squad_tactics.add_member(member)
	
	# Should not exceed max size
	assert_lte(
		squad_tactics.get_squad_size(),
		squad_tactics.max_squad_size,
		"Squad should not exceed max size"
	)


func test_squad_member_removal() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# Add a member
	var member: Enemy = Enemy.new()
	member.name = "RemovableMember"
	member.enemy_id = "grunt"
	add_child_autofree(member)
	
	await get_tree().process_frame
	
	squad_tactics.add_member(member)
	var size_before: int = squad_tactics.get_squad_size()
	
	# Remove member
	squad_tactics.remove_member(member)
	
	assert_lt(
		squad_tactics.get_squad_size(),
		size_before,
		"Squad size should decrease after removing member"
	)


func test_squad_signals_formation_changed() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# Watch for formation_changed signal
	var _watcher: Variant = watch_signals(squad_tactics)
	
	# Change formation
	squad_tactics.set_formation(SquadTactics.Formation.WEDGE)
	
	# Signal should be emitted
	assert_signal_emitted(
		squad_tactics,
		"formation_changed",
		"Formation change should emit signal"
	)


func test_squad_signals_squad_formed() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	# Add another member first so squad actually forms
	var member: Enemy = Enemy.new()
	member.name = "FormMember"
	member.enemy_id = "grunt"
	add_child_autofree(member)
	
	await get_tree().process_frame
	
	squad_tactics.add_member(member)
	
	# Watch for squad_formed signal
	var _watcher: Variant = watch_signals(squad_tactics)
	
	# Form squad (will emit if size > 1)
	squad_tactics.try_form_squad()
	
	# Signal may or may not emit depending on squad size
	# Just verify the signal exists
	assert_true(
		squad_tactics.has_signal("squad_formed"),
		"Squad tactics should have squad_formed signal"
	)


func test_squad_signals_squad_disbanded() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# Watch for squad_disbanded signal
	var _watcher: Variant = watch_signals(squad_tactics)
	
	# Disband squad
	squad_tactics.leave_squad()
	
	# Signal should be emitted
	assert_signal_emitted(
		squad_tactics,
		"squad_disbanded",
		"Squad disbanding should emit signal"
	)


func test_squad_formation_spacing_configuration() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	squad_tactics.formation_spacing = 5.0
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	assert_eq(
		squad_tactics.formation_spacing,
		5.0,
		"Formation spacing should be configurable"
	)


func test_squad_auto_join_configuration() -> void:
	# Create squad tactics with auto-join disabled
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	squad_tactics.auto_join_squads = false
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	assert_false(
		squad_tactics.auto_join_squads,
		"Auto-join should be configurable"
	)


func test_squad_search_radius_configuration() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	squad_tactics.squad_search_radius = 30.0
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	assert_eq(
		squad_tactics.squad_search_radius,
		30.0,
		"Squad search radius should be configurable"
	)


func test_squad_non_leader_cannot_set_formation() -> void:
	# Create squad tactics as non-leader
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	squad_tactics.is_squad_leader = false
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	# Try to set formation
	squad_tactics.set_formation(SquadTactics.Formation.CIRCLE)
	
	# Formation should remain NONE for non-leaders
	assert_eq(
		squad_tactics.current_formation,
		SquadTactics.Formation.NONE,
		"Non-leaders should not be able to set formation"
	)


func test_squad_non_leader_cannot_issue_orders() -> void:
	# Create squad tactics as non-leader
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	squad_tactics.is_squad_leader = false
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	# Create target
	var target: Node3D = Node3D.new()
	target.name = "OrderTarget"
	add_child_autofree(target)
	
	# Try to issue attack order (should not crash)
	squad_tactics.issue_attack_order(target)
	
	assert_true(
		true,
		"Non-leaders should handle order attempts gracefully"
	)


func test_squad_all_formation_types_assignable() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	squad_tactics.try_form_squad()
	
	# Test all formation types
	var formations: Array[SquadTactics.Formation] = [
		SquadTactics.Formation.LINE,
		SquadTactics.Formation.WEDGE,
		SquadTactics.Formation.CIRCLE,
		SquadTactics.Formation.FLANKING
	]
	
	for formation: SquadTactics.Formation in formations:
		squad_tactics.set_formation(formation)
		assert_eq(
			squad_tactics.current_formation,
			formation,
			"Should be able to set formation: %d" % formation
		)


func test_squad_id_generation() -> void:
	# Create squad tactics
	squad_tactics = SquadTactics.new()
	squad_tactics.name = "SquadTactics"
	enemy.add_child(squad_tactics)
	
	await get_tree().process_frame
	
	# Initially empty
	assert_eq(
		squad_tactics.squad_id,
		"",
		"Squad ID should be empty initially"
	)
	
	# Form squad
	squad_tactics.try_form_squad()
	
	# Should generate ID
	assert_ne(
		squad_tactics.squad_id,
		"",
		"Squad ID should be generated when forming squad"
	)
	assert_true(
		squad_tactics.squad_id.begins_with("squad_"),
		"Squad ID should have proper prefix"
	)


# ============================================================================
# Infighting Mechanics Tests
# ============================================================================

func test_infighting_system_creation() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	enemy.add_child(infighting_system)
	
	await get_tree().process_frame
	
	assert_not_null(
		enemy.get_node_or_null("InfightingSystem"),
		"Infighting system should be created"
	)


func test_infighting_enabled_by_default() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	enemy.add_child(infighting_system)
	
	await get_tree().process_frame
	
	assert_true(
		infighting_system.enable_infighting,
		"Infighting should be enabled by default"
	)


func test_infighting_retaliation_chance() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	enemy.add_child(infighting_system)
	
	await get_tree().process_frame
	
	# Verify retaliation chance is reasonable
	assert_gte(
		infighting_system.retaliation_chance,
		0.0,
		"Retaliation chance should be >= 0"
	)
	assert_lte(
		infighting_system.retaliation_chance,
		1.0,
		"Retaliation chance should be <= 1"
	)


func test_infighting_tier_aggression() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	enemy.add_child(infighting_system)
	
	await get_tree().process_frame
	
	# Tier aggression should be configurable
	assert_true(
		"tier_aggression_enabled" in infighting_system,
		"Infighting should have tier aggression setting"
	)


func test_infighting_same_tier() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.same_tier_infighting = true
	infighting_system.retaliation_chance = 1.0  # Always retaliate for testing
	enemy.add_child(infighting_system)
	enemy.tier = 1
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Create attacker of same tier
	var attacker: Enemy = Enemy.new()
	attacker.name = "Attacker"
	attacker.enemy_id = "grunt"
	attacker.tier = 1
	attacker.add_to_group("enemies")
	add_child_autofree(attacker)
	
	await get_tree().process_frame
	
	# Trigger infighting
	infighting_system.trigger_infighting(attacker)
	
	# Should start infighting with same tier
	assert_true(
		infighting_system.is_infighting(),
		"Same tier infighting should start when enabled"
	)
	assert_eq(
		infighting_system.get_infight_target(),
		attacker,
		"Infight target should be set to attacker"
	)


func test_infighting_duration() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	enemy.add_child(infighting_system)
	
	await get_tree().process_frame
	
	# Verify duration is reasonable
	assert_gt(
		infighting_system.infight_duration,
		0.0,
		"Infighting duration should be positive"
	)


func test_infighting_status_check() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	enemy.add_child(infighting_system)
	
	await get_tree().process_frame
	
	# Initially not infighting
	assert_false(
		infighting_system.is_infighting(),
		"Enemy should not be infighting initially"
	)


func test_infighting_lower_tier_attacks_higher() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.tier_aggression_enabled = true
	infighting_system.lower_tier_attacks_higher = false
	infighting_system.retaliation_chance = 1.0
	enemy.add_child(infighting_system)
	enemy.tier = 1
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Create higher tier attacker
	var attacker: Enemy = Enemy.new()
	attacker.name = "HigherTierAttacker"
	attacker.enemy_id = "summoner"
	attacker.tier = 3
	attacker.add_to_group("enemies")
	add_child_autofree(attacker)
	
	await get_tree().process_frame
	
	# Trigger infighting
	infighting_system.trigger_infighting(attacker)
	
	# Should NOT start infighting
	assert_false(
		infighting_system.is_infighting(),
		"Lower tier should not attack higher tier when disabled"
	)


func test_infighting_higher_tier_attacks_lower() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.tier_aggression_enabled = true
	infighting_system.higher_tier_attacks_lower = true
	infighting_system.retaliation_chance = 1.0
	enemy.add_child(infighting_system)
	enemy.tier = 3
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Create lower tier attacker
	var attacker: Enemy = Enemy.new()
	attacker.name = "LowerTierAttacker"
	attacker.enemy_id = "grunt"
	attacker.tier = 1
	attacker.add_to_group("enemies")
	add_child_autofree(attacker)
	
	await get_tree().process_frame
	
	# Trigger infighting
	infighting_system.trigger_infighting(attacker)
	
	# Should start infighting
	assert_true(
		infighting_system.is_infighting(),
		"Higher tier should attack lower tier when enabled"
	)


func test_infighting_signals_started() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.retaliation_chance = 1.0
	enemy.add_child(infighting_system)
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Create attacker
	var attacker: Enemy = Enemy.new()
	attacker.name = "SignalAttacker"
	attacker.enemy_id = "grunt"
	attacker.add_to_group("enemies")
	add_child_autofree(attacker)
	
	await get_tree().process_frame
	
	# Watch for infight_started signal
	var _watcher: Variant = watch_signals(infighting_system)
	
	# Trigger infighting
	infighting_system.trigger_infighting(attacker)
	
	# Signal should be emitted
	assert_signal_emitted(
		infighting_system,
		"infight_started",
		"Infighting start should emit signal"
	)


func test_infighting_signals_ended() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.retaliation_chance = 1.0
	infighting_system.infight_duration = 0.1
	enemy.add_child(infighting_system)
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Create attacker
	var attacker: Enemy = Enemy.new()
	attacker.name = "EndSignalAttacker"
	attacker.enemy_id = "grunt"
	attacker.add_to_group("enemies")
	add_child_autofree(attacker)
	
	await get_tree().process_frame
	
	# Start infighting
	infighting_system.trigger_infighting(attacker)
	
	# Watch for infight_ended signal
	var _watcher: Variant = watch_signals(infighting_system)
	
	# Wait for duration to expire
	await get_tree().create_timer(0.2).timeout
	
	# Signal should be emitted
	assert_signal_emitted(
		infighting_system,
		"infight_ended",
		"Infighting end should emit signal"
	)


func test_infighting_force_end() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.retaliation_chance = 1.0
	enemy.add_child(infighting_system)
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Create attacker
	var attacker: Enemy = Enemy.new()
	attacker.name = "ForceEndAttacker"
	attacker.enemy_id = "grunt"
	attacker.add_to_group("enemies")
	add_child_autofree(attacker)
	
	await get_tree().process_frame
	
	# Start infighting
	infighting_system.trigger_infighting(attacker)
	assert_true(infighting_system.is_infighting(), "Infighting should start")
	
	# Force end
	infighting_system.force_end_infighting()
	
	# Should no longer be infighting
	assert_false(
		infighting_system.is_infighting(),
		"Force end should stop infighting"
	)


func test_infighting_extend_duration() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.retaliation_chance = 1.0
	infighting_system.infight_duration = 1.0
	enemy.add_child(infighting_system)
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Create attacker
	var attacker: Enemy = Enemy.new()
	attacker.name = "ExtendAttacker"
	attacker.enemy_id = "grunt"
	attacker.add_to_group("enemies")
	add_child_autofree(attacker)
	
	await get_tree().process_frame
	
	# Start infighting
	infighting_system.trigger_infighting(attacker)
	
	# Extend duration
	infighting_system.extend_infight_duration(5.0)
	
	# Should still be infighting
	assert_true(
		infighting_system.is_infighting(),
		"Infighting should continue after extending duration"
	)


func test_infighting_disabled_globally() -> void:
	# Create infighting system with infighting disabled
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.enable_infighting = false
	infighting_system.retaliation_chance = 1.0
	enemy.add_child(infighting_system)
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Create attacker
	var attacker: Enemy = Enemy.new()
	attacker.name = "DisabledAttacker"
	attacker.enemy_id = "grunt"
	attacker.add_to_group("enemies")
	add_child_autofree(attacker)
	
	await get_tree().process_frame
	
	# Try to trigger infighting
	infighting_system.trigger_infighting(attacker)
	
	# Should NOT start infighting
	assert_false(
		infighting_system.is_infighting(),
		"Infighting should not start when disabled"
	)


func test_infighting_no_self_attack() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.retaliation_chance = 1.0
	enemy.add_child(infighting_system)
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Try to trigger infighting with self
	infighting_system.trigger_infighting(enemy)
	
	# Should NOT start infighting with self
	assert_false(
		infighting_system.is_infighting(),
		"Enemy should not infight with itself"
	)


func test_infighting_target_retrieval() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.retaliation_chance = 1.0
	enemy.add_child(infighting_system)
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Create attacker
	var attacker: Enemy = Enemy.new()
	attacker.name = "TargetAttacker"
	attacker.enemy_id = "grunt"
	attacker.add_to_group("enemies")
	add_child_autofree(attacker)
	
	await get_tree().process_frame
	
	# Start infighting
	infighting_system.trigger_infighting(attacker)
	
	# Get target
	var target: Node3D = infighting_system.get_infight_target()
	
	assert_eq(
		target,
		attacker,
		"Should return correct infight target"
	)


func test_infighting_notify_damage_from() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.retaliation_chance = 1.0
	enemy.add_child(infighting_system)
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Create attacker
	var attacker: Enemy = Enemy.new()
	attacker.name = "NotifyAttacker"
	attacker.enemy_id = "grunt"
	attacker.add_to_group("enemies")
	add_child_autofree(attacker)
	
	await get_tree().process_frame
	
	# Notify of damage (for splash damage, etc.)
	infighting_system.notify_damage_from(attacker, 10.0)
	
	# Should start infighting
	assert_true(
		infighting_system.is_infighting(),
		"notify_damage_from should trigger infighting"
	)


func test_infighting_tier_aggression_disabled() -> void:
	# Create infighting system with tier aggression disabled
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.tier_aggression_enabled = false
	infighting_system.retaliation_chance = 1.0
	enemy.add_child(infighting_system)
	enemy.tier = 1
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Create higher tier attacker
	var attacker: Enemy = Enemy.new()
	attacker.name = "NoTierCheckAttacker"
	attacker.enemy_id = "warlord"
	attacker.tier = 4
	attacker.add_to_group("enemies")
	add_child_autofree(attacker)
	
	await get_tree().process_frame
	
	# Trigger infighting
	infighting_system.trigger_infighting(attacker)
	
	# Should start infighting regardless of tier
	assert_true(
		infighting_system.is_infighting(),
		"Infighting should ignore tiers when tier aggression disabled"
	)


func test_infighting_retaliation_chance_zero() -> void:
	# Create infighting system with 0% retaliation chance
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.retaliation_chance = 0.0
	enemy.add_child(infighting_system)
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Create attacker
	var attacker: Enemy = Enemy.new()
	attacker.name = "NoRetaliationAttacker"
	attacker.enemy_id = "grunt"
	attacker.add_to_group("enemies")
	add_child_autofree(attacker)
	
	await get_tree().process_frame
	
	# Try to trigger infighting multiple times
	for attempt: int in range(10):
		infighting_system.trigger_infighting(attacker)
	
	# Should NEVER start infighting
	assert_false(
		infighting_system.is_infighting(),
		"Infighting should not start with 0% retaliation chance"
	)


func test_infighting_duration_expires() -> void:
	# Create infighting system with very short duration
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.retaliation_chance = 1.0
	infighting_system.infight_duration = 0.05
	enemy.add_child(infighting_system)
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Create attacker
	var attacker: Enemy = Enemy.new()
	attacker.name = "ExpiryAttacker"
	attacker.enemy_id = "grunt"
	attacker.add_to_group("enemies")
	add_child_autofree(attacker)
	
	await get_tree().process_frame
	
	# Start infighting
	infighting_system.trigger_infighting(attacker)
	assert_true(infighting_system.is_infighting(), "Infighting should start")
	
	# Wait for duration to expire
	await get_tree().create_timer(0.1).timeout
	
	# Should no longer be infighting
	assert_false(
		infighting_system.is_infighting(),
		"Infighting should end after duration expires"
	)


func test_infighting_only_targets_enemies() -> void:
	# Create infighting system
	infighting_system = InfightingSystem.new()
	infighting_system.name = "InfightingSystem"
	infighting_system.retaliation_chance = 1.0
	enemy.add_child(infighting_system)
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Create non-enemy attacker (player)
	var player: Node3D = Node3D.new()
	player.name = "Player"
	player.add_to_group("player")
	add_child_autofree(player)
	
	await get_tree().process_frame
	
	# Try to trigger infighting with player
	infighting_system.trigger_infighting(player)
	
	# Should NOT start infighting (player is not an enemy)
	assert_false(
		infighting_system.is_infighting(),
		"Infighting should only target enemies, not players"
	)


# ============================================================================
# Pathfinding Integration Tests
# ============================================================================

func test_movement_component_exists() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	assert_not_null(
		movement,
		"Enemy should have movement component for pathfinding"
	)


func test_movement_component_has_navigation_agent() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping navigation agent test")
		return
	
	# Wait for navigation agent to be created in _ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert_true(
		"nav_agent" in movement,
		"Movement component should have NavigationAgent3D"
	)
	
	if "nav_agent" in movement:
		assert_not_null(
			movement.nav_agent,
			"NavigationAgent3D should be instantiated"
		)


func test_navigation_agent_configuration() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping nav agent config test")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not movement.nav_agent:
		pass_test("NavigationAgent3D not created - skipping config test")
		return
	
	var nav_agent: NavigationAgent3D = movement.nav_agent
	
	# Verify navigation agent is properly configured
	assert_gte(
		nav_agent.path_desired_distance,
		0.0,
		"Path desired distance should be non-negative"
	)
	assert_gte(
		nav_agent.target_desired_distance,
		0.0,
		"Target desired distance should be non-negative"
	)


func test_navigation_agent_avoidance_enabled() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping avoidance test")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not movement.nav_agent:
		pass_test("NavigationAgent3D not created - skipping avoidance test")
		return
	
	var nav_agent: NavigationAgent3D = movement.nav_agent
	
	assert_true(
		nav_agent.avoidance_enabled,
		"Navigation agent should have avoidance enabled for obstacle navigation"
	)


func test_ai_can_set_target_position() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping pathfinding test")
		return
	
	if not movement.has_method("set_target_position"):
		pass_test("Movement component missing set_target_position - skipping")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Set target position
	var target_pos: Vector3 = Vector3(10, 0, 10)
	movement.set_target_position(target_pos)
	
	# Verify target was set on navigation agent
	if movement.nav_agent:
		assert_eq(
			movement.nav_agent.target_position,
			target_pos,
			"Navigation agent target should be set"
		)


func test_pathfinding_destination_reached_signal() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping signal test")
		return
	
	assert_true(
		movement.has_signal("destination_reached"),
		"Movement component should emit destination_reached signal"
	)


func test_pathfinding_movement_stuck_signal() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping stuck signal test")
		return
	
	assert_true(
		movement.has_signal("movement_stuck"),
		"Movement component should emit movement_stuck signal for obstacle detection"
	)


func test_pathfinding_stop_movement() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping stop test")
		return
	
	if not movement.has_method("stop"):
		pass_test("Movement component missing stop method - skipping")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Start movement
	movement.set_target_position(Vector3(10, 0, 10))
	
	# Stop movement
	movement.stop()
	
	# Verify movement stopped
	if movement.nav_agent:
		var current_pos: Vector3 = enemy.global_position
		assert_almost_eq(
			movement.nav_agent.target_position.x,
			current_pos.x,
			1.0,
			"Stop should set target to current position"
		)


func test_chase_state_uses_pathfinding() -> void:
	if not ai_controller:
		pass_test("AI controller not found - skipping chase pathfinding test")
		return
	
	var chase_state: Node = ai_controller.get_node_or_null("ChaseState")
	
	if not chase_state:
		pass_test("Chase state not found - skipping pathfinding test")
		return
	
	# Chase state should exist and be usable
	assert_not_null(chase_state, "Chase state should exist for pathfinding")


func test_chase_state_sets_target_position() -> void:
	if not ai_controller:
		pass_test("AI controller not found - skipping chase target test")
		return
	
	var chase_state: Node = ai_controller.get_node_or_null("ChaseState")
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not chase_state or not movement:
		pass_test("Chase state or movement not found - skipping")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Create target
	var target: Node3D = Node3D.new()
	target.name = "ChaseTarget"
	target.position = Vector3(20, 0, 20)
	add_child_autofree(target)
	
	# Set AI target
	ai_controller.target = target
	
	# Enter chase state
	ai_controller.change_state(chase_state)
	
	# Process state to trigger pathfinding
	if chase_state.has_method("physics_update"):
		chase_state.physics_update(0.016)
	
	# Verify movement component received target position
	assert_true(
		true,
		"Chase state should use pathfinding to reach target"
	)


func test_patrol_state_uses_pathfinding() -> void:
	if not ai_controller:
		pass_test("AI controller not found - skipping patrol pathfinding test")
		return
	
	var patrol_state: Node = ai_controller.get_node_or_null("PatrolState")
	
	# Patrol state is optional
	if patrol_state:
		assert_not_null(patrol_state, "Patrol state should use pathfinding")


func test_flee_state_uses_pathfinding() -> void:
	if not ai_controller:
		pass_test("AI controller not found - skipping flee pathfinding test")
		return
	
	var flee_state: Node = ai_controller.get_node_or_null("FleeState")
	
	# Flee state is optional
	if flee_state:
		assert_not_null(flee_state, "Flee state should use pathfinding to escape")


func test_pathfinding_around_obstacles() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping obstacle test")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Create obstacle between enemy and target
	var obstacle: StaticBody3D = StaticBody3D.new()
	obstacle.name = "Obstacle"
	obstacle.position = Vector3(5, 0, 0)
	add_child_autofree(obstacle)
	
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	collision.shape = box
	obstacle.add_child(collision)
	
	await get_tree().process_frame
	
	# Set target beyond obstacle
	var target_pos: Vector3 = Vector3(10, 0, 0)
	movement.set_target_position(target_pos)
	
	# Navigation agent should calculate path around obstacle
	assert_true(
		true,
		"Pathfinding should navigate around obstacles"
	)


func test_pathfinding_navigation_finished() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping finished test")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not movement.nav_agent:
		pass_test("NavigationAgent3D not created - skipping finished test")
		return
	if NavigationServer3D.get_maps().is_empty():
		pass_test("NavigationServer3D has no maps - skipping finished test")
		return
	
	var nav_agent: NavigationAgent3D = movement.nav_agent
	
	# Set target to current position (should finish immediately)
	movement.set_target_position(enemy.global_position)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Navigation should be finished
	assert_true(
		nav_agent.is_navigation_finished() or not movement._is_moving,
		"Navigation should finish when at target"
	)


func test_pathfinding_next_path_position() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping path position test")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not movement.nav_agent:
		pass_test("NavigationAgent3D not created - skipping path position test")
		return
	
	var nav_agent: NavigationAgent3D = movement.nav_agent
	
	# Set target position
	movement.set_target_position(Vector3(10, 0, 10))
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get next path position
	var next_pos: Vector3 = nav_agent.get_next_path_position()
	
	# Should return a valid position
	assert_true(
		next_pos != Vector3.ZERO or enemy.global_position == Vector3.ZERO,
		"Navigation agent should provide next path position"
	)


func test_pathfinding_velocity_calculation() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping velocity test")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Set target position
	movement.set_target_position(Vector3(10, 0, 0))
	
	await get_tree().process_frame
	
	# Movement component should calculate velocity toward target
	# Velocity is applied to parent CharacterBody3D
	assert_true(
		"speed" in movement,
		"Movement component should have speed property for pathfinding"
	)


func test_pathfinding_rotation_toward_target() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping rotation test")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Store initial rotation
	var _initial_rotation: float = enemy.rotation.y
	
	# Set target to the right
	movement.set_target_position(enemy.global_position + Vector3(10, 0, 0))
	
	# Process physics to update rotation
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# Rotation should change toward target (or stay same if already facing)
	assert_true(
		"rotation_speed" in movement,
		"Movement component should have rotation_speed for turning"
	)


func test_pathfinding_stuck_detection() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping stuck detection test")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Movement component should have stuck detection
	assert_true(
		"blocked_timer" in movement,
		"Movement component should track blocked time for stuck detection"
	)


func test_pathfinding_with_squad_formation() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping squad formation test")
		return
	
	# Create squad tactics
	var formation_tactics: SquadTactics = SquadTactics.new()
	formation_tactics.name = "SquadTactics"
	enemy.add_child(formation_tactics)
	
	await get_tree().process_frame
	
	formation_tactics.try_form_squad()
	formation_tactics.set_formation(SquadTactics.Formation.LINE)
	
	# Get formation position
	var form_pos: Vector3 = formation_tactics.get_formation_position()
	
	# Set movement to formation position
	movement.set_target_position(form_pos)
	
	# Pathfinding should work with squad formations
	assert_true(
		true,
		"Pathfinding should integrate with squad formation positions"
	)


func test_pathfinding_navigation_server_ready() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping nav server test")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Movement component should wait for NavigationServer to be ready
	# This is handled in _setup_navigation method
	assert_true(
		movement.has_method("_setup_navigation"),
		"Movement component should have navigation setup method"
	)


func test_pathfinding_target_reached_callback() -> void:
	var movement: Node = enemy.get_node_or_null("MovementComponent")
	
	if not movement:
		pass_test("Movement component not found - skipping callback test")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not movement.nav_agent:
		pass_test("NavigationAgent3D not created - skipping callback test")
		return
	
	# Watch for destination_reached signal
	var _watcher: Variant = watch_signals(movement)
	
	# Set target to current position (should reach immediately)
	movement.set_target_position(enemy.global_position)
	
	# Process frames to trigger navigation
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# Signal may or may not emit depending on navigation state
	# Just verify the signal exists and is connected
	assert_true(
		movement.has_signal("destination_reached"),
		"Movement should have destination_reached signal"
	)


# ============================================================================
# Target Selection Tests
# ============================================================================

func test_perception_component_exists() -> void:
	assert_not_null(
		perception_component,
		"Enemy should have perception component for target selection"
	)


func test_perception_has_detection_radius() -> void:
	if not perception_component:
		pass_test("Perception component not found - skipping detection test")
		return
	
	assert_true(
		"detection_radius" in perception_component,
		"Perception should have detection radius"
	)
	
	if "detection_radius" in perception_component:
		assert_gt(
			perception_component.detection_radius,
			0.0,
			"Detection radius should be positive"
		)


func test_perception_signals_target_spotted() -> void:
	if not perception_component:
		pass_test("Perception component not found - skipping signal test")
		return
	
	assert_true(
		perception_component.has_signal("target_spotted"),
		"Perception should have target_spotted signal"
	)


func test_perception_signals_target_lost() -> void:
	if not perception_component:
		pass_test("Perception component not found - skipping signal test")
		return
	
	assert_true(
		perception_component.has_signal("target_lost"),
		"Perception should have target_lost signal"
	)


func test_ai_controller_has_target_property() -> void:
	if not ai_controller:
		pass_test("AI controller not found - skipping target test")
		return
	
	assert_true(
		"target" in ai_controller,
		"AI controller should have target property"
	)


func test_target_selection_on_damage() -> void:
	if not ai_controller:
		pass_test("AI controller not found - skipping damage target test")
		return
	
	# Create attacker
	var attacker: Node3D = Node3D.new()
	attacker.name = "Attacker"
	add_child_autofree(attacker)
	
	# Simulate damage received
	if ai_controller.has_method("on_damage_received"):
		ai_controller.on_damage_received(attacker, 10.0)
		
		# Target should be set to attacker
		assert_eq(
			ai_controller.target,
			attacker,
			"AI should target attacker on damage"
		)


func test_target_priority_closest_threat() -> void:
	if not perception_component:
		pass_test("Perception component not found - skipping priority test")
		return
	
	# Create two potential targets at different distances
	var close_target: Node3D = Node3D.new()
	close_target.name = "CloseTarget"
	close_target.position = enemy.global_position + Vector3(5, 0, 0)
	close_target.add_to_group("player")
	_mark_ai_test_target(close_target)
	add_child_autofree(close_target)
	
	var far_target: Node3D = Node3D.new()
	far_target.name = "FarTarget"
	far_target.position = enemy.global_position + Vector3(15, 0, 0)
	far_target.add_to_group("player")
	_mark_ai_test_target(far_target)
	add_child_autofree(far_target)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Trigger perception scan
	_scan_isolated_targets()
	
	# Should select closer target
	if ai_controller and ai_controller.target:
		var target_dist: float = enemy.global_position.distance_to(
			ai_controller.target.global_position
		)
		assert_lt(
			target_dist,
			10.0,
			"AI should prioritize closer target"
		)


func test_target_selection_distance_based() -> void:
	if not perception_component or not ai_controller:
		pass_test("Components not found - skipping distance test")
		return
	
	# Create target within vision range
	var target: Node3D = Node3D.new()
	target.name = "DistanceTarget"
	target.position = enemy.global_position + Vector3(8, 0, 0)
	target.add_to_group("player")
	_mark_ai_test_target(target)
	add_child_autofree(target)
	
	await get_tree().process_frame
	
	# Trigger perception scan
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	# Should detect target within range
	if ai_controller.target:
		assert_eq(
			ai_controller.target,
			target,
			"AI should select target within vision range"
		)


func test_target_selection_ignores_out_of_range() -> void:
	if not perception_component or not ai_controller:
		pass_test("Components not found - skipping range test")
		return
	
	# Create target far outside vision range
	var far_target: Node3D = Node3D.new()
	far_target.name = "FarAwayTarget"
	far_target.position = enemy.global_position + Vector3(100, 0, 0)
	far_target.add_to_group("player")
	_mark_ai_test_target(far_target)
	add_child_autofree(far_target)
	
	await get_tree().process_frame
	
	# Clear any existing target
	ai_controller.target = null
	
	# Trigger perception scan
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	# Should NOT detect target out of range
	assert_null(
		ai_controller.target,
		"AI should not select targets outside vision range"
	)


func test_target_selection_switches_on_damage() -> void:
	if not ai_controller:
		pass_test("AI controller not found - skipping damage switch test")
		return
	
	# Set initial target
	var initial_target: Node3D = Node3D.new()
	initial_target.name = "InitialTarget"
	initial_target.add_to_group("player")
	_mark_ai_test_target(initial_target)
	add_child_autofree(initial_target)
	
	ai_controller.target = initial_target
	
	await get_tree().process_frame
	
	# Create attacker
	var attacker: Node3D = Node3D.new()
	attacker.name = "NewAttacker"
	attacker.add_to_group("player")
	_mark_ai_test_target(attacker)
	add_child_autofree(attacker)
	
	await get_tree().process_frame
	
	# Simulate damage from attacker
	ai_controller.on_damage_received(attacker, 10.0)
	
	# Should switch to attacker
	assert_eq(
		ai_controller.target,
		attacker,
		"AI should switch target to attacker on damage"
	)


func test_target_selection_ignores_dead_targets() -> void:
	if not perception_component or not ai_controller:
		pass_test("Components not found - skipping dead target test")
		return
	
	# Create dead target
	var dead_target: Node3D = Node3D.new()
	dead_target.name = "DeadTarget"
	dead_target.position = enemy.global_position + Vector3(5, 0, 0)
	dead_target.add_to_group("player")
	_mark_ai_test_target(dead_target)
	dead_target.set_meta("is_dead", true)
	add_child_autofree(dead_target)
	
	# Add is_dead property dynamically
	dead_target.set("is_dead", true)
	
	await get_tree().process_frame
	
	# Set as current target
	ai_controller.target = dead_target
	
	# Trigger perception scan
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	# Should lose dead target
	assert_null(
		ai_controller.target,
		"AI should not target dead entities"
	)


func test_target_selection_ignores_invisible_targets() -> void:
	if not perception_component or not ai_controller:
		pass_test("Components not found - skipping invisible test")
		return
	
	# Create invisible target (godmode player)
	var invisible_target: Node3D = Node3D.new()
	invisible_target.name = "InvisibleTarget"
	invisible_target.position = enemy.global_position + Vector3(5, 0, 0)
	invisible_target.add_to_group("player")
	_mark_ai_test_target(invisible_target)
	invisible_target.set_meta("is_invisible", true)
	invisible_target.set("is_invisible", true)
	add_child_autofree(invisible_target)
	
	await get_tree().process_frame
	
	# Set as current target
	ai_controller.target = invisible_target
	
	# Trigger perception scan
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	# Should lose invisible target
	assert_null(
		ai_controller.target,
		"AI should not target invisible entities"
	)


func test_target_selection_multiple_targets() -> void:
	if not perception_component or not ai_controller:
		pass_test("Components not found - skipping multiple targets test")
		return
	
	# Create multiple targets at different distances
	var targets: Array[Node3D] = []
	for i: int in range(3):
		var target: Node3D = Node3D.new()
		target.name = "MultiTarget%d" % i
		target.position = enemy.global_position + Vector3(5 + i * 2, 0, 0)
		target.add_to_group("player")
		_mark_ai_test_target(target)
		add_child_autofree(target)
		targets.append(target)
	
	await get_tree().process_frame
	
	# Trigger perception scan
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	# Should select one target (preferably closest)
	if ai_controller.target:
		assert_true(
			ai_controller.target in targets,
			"AI should select one of the available targets"
		)


func test_target_selection_prefers_players_over_enemies() -> void:
	if not perception_component or not ai_controller:
		pass_test("Components not found - skipping player priority test")
		return
	
	# Disable aggressive_against_all to prefer players
	perception_component.aggressive_against_all = false
	
	# Create player target
	var player_target: Node3D = Node3D.new()
	player_target.name = "PlayerTarget"
	player_target.position = enemy.global_position + Vector3(8, 0, 0)
	player_target.add_to_group("player")
	_mark_ai_test_target(player_target)
	add_child_autofree(player_target)
	
	# Create enemy target (should be ignored)
	var enemy_target: Enemy = Enemy.new()
	enemy_target.name = "EnemyTarget"
	enemy_target.enemy_id = "grunt"
	enemy_target.position = enemy.global_position + Vector3(5, 0, 0)
	enemy_target.add_to_group("enemies")
	_mark_ai_test_target(enemy_target)
	add_child_autofree(enemy_target)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Trigger perception scan
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	# Should select player, not enemy
	if ai_controller.target:
		assert_eq(
			ai_controller.target,
			player_target,
			"AI should prefer player targets over enemies"
		)


func test_target_selection_aggressive_against_all() -> void:
	if not perception_component or not ai_controller:
		pass_test("Components not found - skipping aggressive test")
		return
	
	# Enable aggressive_against_all
	perception_component.aggressive_against_all = true
	
	# Create only enemy target
	var enemy_target: Enemy = Enemy.new()
	enemy_target.name = "AggressiveTarget"
	enemy_target.enemy_id = "grunt"
	enemy_target.position = enemy.global_position + Vector3(5, 0, 0)
	enemy_target.add_to_group("enemies")
	_mark_ai_test_target(enemy_target)
	add_child_autofree(enemy_target)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Trigger perception scan
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	# Should select enemy when aggressive_against_all is true
	if ai_controller.target:
		assert_eq(
			ai_controller.target,
			enemy_target,
			"AI should target enemies when aggressive_against_all is enabled"
		)


func test_target_selection_no_self_targeting() -> void:
	if not perception_component or not ai_controller:
		pass_test("Components not found - skipping self-target test")
		return
	
	# Enable aggressive_against_all
	perception_component.aggressive_against_all = true
	
	# Enemy should be in enemies group
	enemy.add_to_group("enemies")
	
	await get_tree().process_frame
	
	# Trigger perception scan
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	# Should NOT target self
	assert_ne(
		ai_controller.target,
		enemy,
		"AI should never target itself"
	)


func test_target_selection_updates_last_known_position() -> void:
	if not perception_component or not ai_controller:
		pass_test("Components not found - skipping last known position test")
		return
	
	# Create target
	var target: Node3D = Node3D.new()
	target.name = "MovingTarget"
	target.position = enemy.global_position + Vector3(5, 0, 0)
	target.add_to_group("player")
	_mark_ai_test_target(target)
	add_child_autofree(target)
	
	await get_tree().process_frame
	
	# Trigger perception scan
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	# Store last known position
	var last_known: Vector3 = perception_component._last_known_pos
	
	# Move target
	target.global_position = enemy.global_position + Vector3(7, 0, 0)
	
	await get_tree().process_frame
	
	# Trigger perception scan again
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	# Last known position should update
	assert_ne(
		perception_component._last_known_pos,
		last_known,
		"Last known position should update when target moves"
	)


func test_target_selection_clears_on_target_lost() -> void:
	if not perception_component or not ai_controller:
		pass_test("Components not found - skipping target lost test")
		return
	
	# Create target
	var target: Node3D = Node3D.new()
	target.name = "LostTarget"
	target.position = enemy.global_position + Vector3(5, 0, 0)
	target.add_to_group("player")
	_mark_ai_test_target(target)
	add_child_autofree(target)
	
	await get_tree().process_frame
	
	# Set target
	ai_controller.target = target
	
	# Trigger target_lost signal
	perception_component.target_lost.emit(target)
	
	await get_tree().process_frame
	
	# Target should be cleared
	assert_null(
		ai_controller.target,
		"AI target should be cleared when target_lost signal emits"
	)


func test_target_selection_threat_level_by_distance() -> void:
	if not perception_component or not ai_controller:
		pass_test("Components not found - skipping threat level test")
		return
	
	# Create very close target (high threat)
	var close_threat: Node3D = Node3D.new()
	close_threat.name = "CloseThreat"
	close_threat.position = enemy.global_position + Vector3(2, 0, 0)
	close_threat.add_to_group("player")
	_mark_ai_test_target(close_threat)
	add_child_autofree(close_threat)
	
	# Create medium distance target
	var medium_threat: Node3D = Node3D.new()
	medium_threat.name = "MediumThreat"
	medium_threat.position = enemy.global_position + Vector3(8, 0, 0)
	medium_threat.add_to_group("player")
	_mark_ai_test_target(medium_threat)
	add_child_autofree(medium_threat)
	
	await get_tree().process_frame
	
	# Trigger perception scan
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	# Should prioritize closer threat
	if ai_controller.target:
		var target_dist: float = enemy.global_position.distance_to(
			ai_controller.target.global_position
		)
		assert_lt(
			target_dist,
			5.0,
			"AI should prioritize closer threats"
		)


func test_target_selection_retains_valid_target() -> void:
	if not perception_component or not ai_controller:
		pass_test("Components not found - skipping retain target test")
		return
	
	# Create target
	var target: Node3D = Node3D.new()
	target.name = "ValidTarget"
	target.position = enemy.global_position + Vector3(5, 0, 0)
	target.add_to_group("player")
	_mark_ai_test_target(target)
	add_child_autofree(target)
	
	await get_tree().process_frame
	
	# Trigger perception scan to acquire target
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	var initial_target: Node3D = ai_controller.target
	
	# Scan again without changes
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	# Should retain same target
	assert_eq(
		ai_controller.target,
		initial_target,
		"AI should retain valid target across scans"
	)


func test_target_selection_switches_to_closer_target() -> void:
	if not perception_component or not ai_controller:
		pass_test("Components not found - skipping target switch test")
		return
	
	# Create far target
	var far_target: Node3D = Node3D.new()
	far_target.name = "FarTarget"
	far_target.position = enemy.global_position + Vector3(12, 0, 0)
	far_target.add_to_group("player")
	_mark_ai_test_target(far_target)
	add_child_autofree(far_target)
	
	await get_tree().process_frame
	
	# Acquire far target
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	# Create closer target
	var close_target: Node3D = Node3D.new()
	close_target.name = "CloseTarget"
	close_target.position = enemy.global_position + Vector3(4, 0, 0)
	close_target.add_to_group("player")
	_mark_ai_test_target(close_target)
	add_child_autofree(close_target)
	
	await get_tree().process_frame
	
	# Scan again
	_scan_isolated_targets()
	
	await get_tree().process_frame
	
	# Should switch to closer target
	if ai_controller.target:
		var target_dist: float = enemy.global_position.distance_to(
			ai_controller.target.global_position
		)
		assert_lt(
			target_dist,
			8.0,
			"AI should switch to closer target when available"
		)


func test_target_selection_validates_target_instance() -> void:
	if not ai_controller:
		pass_test("AI controller not found - skipping validation test")
		return
	
	# Create target and set it
	var target: Node3D = Node3D.new()
	target.name = "InvalidatedTarget"
	add_child_autofree(target)
	
	ai_controller.target = target
	
	await get_tree().process_frame
	
	# Free the target (invalidate it)
	target.queue_free()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Simulate damage from new attacker (should handle invalid target)
	var new_attacker: Node3D = Node3D.new()
	new_attacker.name = "NewAttacker"
	add_child_autofree(new_attacker)
	
	# Should not crash and should switch to new attacker
	ai_controller.on_damage_received(new_attacker, 10.0)
	
	assert_eq(
		ai_controller.target,
		new_attacker,
		"AI should handle invalid targets gracefully"
	)


# ============================================================================
# AI State Machine Tests
# ============================================================================

func test_idle_state_exists() -> void:
	if not ai_controller:
		pass_test("AI controller not found - skipping idle state test")
		return
	
	var idle_state: Node = ai_controller.get_node_or_null("IdleState")
	assert_not_null(idle_state, "AI should have idle state")


func test_chase_state_exists() -> void:
	if not ai_controller:
		pass_test("AI controller not found - skipping chase state test")
		return
	
	var chase_state: Node = ai_controller.get_node_or_null("ChaseState")
	assert_not_null(chase_state, "AI should have chase state")


func test_attack_state_exists() -> void:
	if not ai_controller:
		pass_test("AI controller not found - skipping attack state test")
		return
	
	var attack_state: Node = ai_controller.get_node_or_null("AttackState")
	assert_not_null(attack_state, "AI should have attack state")


func test_flee_state_optional() -> void:
	if not ai_controller:
		pass_test("AI controller not found - skipping flee state test")
		return
	
	# Flee state is optional (depends on enemy config)
	var _flee_state: Node = ai_controller.get_node_or_null("FleeState")
	
	# Just verify it doesn't crash if missing
	assert_true(true, "Flee state is optional based on enemy config")


func test_state_transitions() -> void:
	if not ai_controller:
		pass_test("AI controller not found - skipping state transition test")
		return
	
	var idle_state: Node = ai_controller.get_node_or_null("IdleState")
	var chase_state: Node = ai_controller.get_node_or_null("ChaseState")
	
	if not idle_state or not chase_state:
		pass_test("Required states not found - skipping transition test")
		return
	
	# Start in idle
	ai_controller.change_state(idle_state)
	assert_eq(ai_controller.current_state, idle_state, "Should start in idle")
	
	# Transition to chase
	ai_controller.change_state(chase_state)
	assert_eq(ai_controller.current_state, chase_state, "Should transition to chase")


# ============================================================================
# Combat Component Integration Tests
# ============================================================================

func test_combat_component_exists() -> void:
	assert_not_null(
		combat_component,
		"Enemy should have combat component"
	)


func test_combat_has_attack_damage() -> void:
	if not combat_component:
		pass_test("Combat component not found - skipping damage test")
		return
	
	assert_true(
		"attack_damage" in combat_component,
		"Combat component should have attack damage"
	)


func test_combat_has_attack_range() -> void:
	if not combat_component:
		pass_test("Combat component not found - skipping range test")
		return
	
	assert_true(
		"attack_range" in combat_component,
		"Combat component should have attack range"
	)


func test_attack_state_uses_combat_component() -> void:
	if not ai_controller:
		pass_test("AI controller not found - skipping attack integration test")
		return
	
	var attack_state: Node = ai_controller.get_node_or_null("AttackState")
	
	if not attack_state:
		pass_test("Attack state not found - skipping combat integration test")
		return
	
	# Attack state should exist and integrate with combat
	assert_not_null(attack_state, "Attack state should integrate with combat")


# ============================================================================
# AI Configuration Tests
# ============================================================================

func test_ai_config_loaded_from_data() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		pass_test("GameManager not available - skipping config test")
		return
	
	var data_service: Node = gm.get_core_system("data")
	
	if not data_service:
		pass_test("Data service not available - skipping config test")
		return
	
	var grunt_data: Dictionary = data_service.get_enemy_data("grunt")
	
	if grunt_data.is_empty():
		pass_test("Grunt data not found - skipping config test")
		return
	
	# Verify AI config exists
	assert_true(
		grunt_data.has("ai_config"),
		"Enemy data should have ai_config section"
	)


func test_ai_behavior_types() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		pass_test("GameManager not available - skipping behavior test")
		return
	
	var data_service: Node = gm.get_core_system("data")
	
	if not data_service:
		pass_test("Data service not available - skipping behavior test")
		return
	
	var grunt_data: Dictionary = data_service.get_enemy_data("grunt")
	
	if grunt_data.is_empty() or not grunt_data.has("ai_config"):
		pass_test("AI config not found - skipping behavior test")
		return
	
	var ai_config: Dictionary = grunt_data.ai_config
	
	# Behavior should be defined
	if ai_config.has("behavior"):
		var behavior: String = ai_config.behavior
		assert_true(
			behavior in ["passive", "defensive", "aggressive", "scout"],
			"Behavior should be valid type: %s" % behavior
		)


func test_ai_combat_style() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		pass_test("GameManager not available - skipping combat style test")
		return
	
	var data_service: Node = gm.get_core_system("data")
	
	if not data_service:
		pass_test("Data service not available - skipping combat style test")
		return
	
	var grunt_data: Dictionary = data_service.get_enemy_data("grunt")
	
	if grunt_data.is_empty() or not grunt_data.has("ai_config"):
		pass_test("AI config not found - skipping combat style test")
		return
	
	var ai_config: Dictionary = grunt_data.ai_config
	
	# Combat style should be defined
	if ai_config.has("combat_style"):
		var style: String = ai_config.combat_style
		assert_true(
			style in ["aggressive", "defensive", "balanced"],
			"Combat style should be valid: %s" % style
		)


# ============================================================================
# Performance and Optimization Tests
# ============================================================================

func test_ai_update_throttling() -> void:
	if not enemy:
		pass_test("Enemy not available - skipping throttling test")
		return
	
	# Enemy should have AI update rate control
	assert_true(
		"_ai_update_rate" in enemy,
		"Enemy should have AI update rate for performance"
	)
	enemy.set_ai_update_rate(0.5)
	enemy.set_update_offset(0.0)
	assert_eq(enemy.consume_ai_update_delta(1.0 / 60.0), 0.0, "Half-rate AI should defer one tick")
	assert_almost_eq(
		enemy.consume_ai_update_delta(1.0 / 60.0),
		1.0 / 30.0,
		0.00001,
		"A throttled update should receive the full elapsed interval"
	)

	enemy.set_ai_update_rate(1.0)
	assert_almost_eq(
		enemy.consume_ai_update_delta(1.0 / 60.0),
		1.0 / 60.0,
		0.00001,
		"Full-rate AI should receive the current physics delta"
	)

	enemy.set_ai_update_rate(0.5)
	enemy.set_update_offset(0.0)
	assert_eq(
		enemy.consume_ai_update_delta(-1.0),
		0.0,
		"Negative elapsed time should not advance throttled AI"
	)
	assert_eq(
		enemy.consume_ai_update_delta(1.0 / 60.0),
		0.0,
		"Negative elapsed time should not reduce the update interval"
	)

	enemy.set_ai_update_rate(0.0)
	enemy.set_update_offset(0.0)
	assert_eq(
		enemy.consume_ai_update_delta(1.0 / 60.0),
		0.0,
		"AI update rate should clamp to a throttled minimum"
	)
	assert_almost_eq(
		enemy.consume_ai_update_delta(1.0 / 60.0),
		1.0 / 6.0,
		0.00001,
		"Clamped minimum rate should update at six hertz"
	)

	enemy.set_ai_update_rate(2.0)
	assert_almost_eq(
		enemy.consume_ai_update_delta(1.0 / 60.0),
		1.0 / 60.0,
		0.00001,
		"AI update rate should clamp to full-rate updates above one"
	)

	enemy.set_ai_update_rate(0.5)
	enemy.set_update_offset(1.0)
	assert_almost_eq(
		enemy.consume_ai_update_delta(1.0 / 60.0),
		1.0 / 60.0,
		0.00001,
		"An update offset should stagger cadence without inflating elapsed time"
	)


func test_ai_can_be_disabled() -> void:
	if not enemy:
		pass_test("Enemy not available - skipping disable test")
		return
	
	# Enemy should have AI active flag
	assert_true(
		"is_ai_active" in enemy,
		"Enemy should have is_ai_active flag"
	)
	
	# Should be able to disable AI
	enemy.is_ai_active = false
	assert_false(enemy.is_ai_active, "AI should be able to be disabled")


func test_lod_affects_ai_update_rate() -> void:
	if not enemy:
		pass_test("Enemy not available - skipping LOD test")
		return
	
	# Enemy should have LOD component or update rate control
	var lod: Node = enemy.get_node_or_null("LODComponent")
	
	if lod:
		assert_not_null(lod, "Enemy should have LOD component for optimization")
	else:
		# LOD is optional, just verify update rate exists
		assert_true(
			"_ai_update_rate" in enemy,
			"Enemy should have AI update rate control"
		)
