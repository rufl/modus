extends ModusGutTestBase

const EnemyBuilderScript := preload("res://game/entities/enemies/enemy_builder.gd")


func test_builder_rejects_empty_data() -> void:
	assert_null(EnemyBuilderScript.create_enemy({}))
	assert_push_error("Enemy data must not be empty")


func test_builder_stages_validated_enemy_data_before_tree_entry() -> void:
	var source := {
		"id": "elite/grunt",
		"tier": 9,
		"aggressive": true,
		"stats": {"health": 75.0, "move_speed": 5.0},
	}
	var enemy: Node = EnemyBuilderScript.create_enemy(source)
	autofree(enemy)

	assert_not_null(enemy)
	assert_eq(enemy.enemy_id, "elite/grunt")
	assert_eq(enemy.tier, 4)
	assert_eq(enemy.name, "elite_grunt")
	assert_true(enemy.get_meta("spawn_aggressive", false))
	var staged: Dictionary = enemy.get_meta("enemy_builder_data")
	source.stats.health = 1.0
	assert_eq(staged.stats.health, 75.0)


func test_builder_rejects_missing_scene() -> void:
	assert_null(
		EnemyBuilderScript.create_enemy(
			{"id": "missing", "scene_path": "res://missing/enemy.tscn"}
		)
	)
	assert_push_error("Enemy scene does not exist")
