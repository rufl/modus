extends GutTest
## Unit coverage for the per-player PlayerProgression component.

const SAVE_SLOTS: Array[String] = [
	"gut_progression_save", "gut_progression_load", "gut_progression_roundtrip"
]

var progression: PlayerProgression
var save_service: SaveService


func before_each() -> void:
	progression = autofree(PlayerProgression.new())
	add_child(progression)
	save_service = GameManager.get_core_system("save") as SaveService


func after_each() -> void:
	for slot: String in SAVE_SLOTS:
		save_service.delete_save(slot + "_progression")
	progression = null
	save_service = null


func test_progression_system_exists() -> void:
	assert_not_null(progression)
	assert_eq(progression.get_level(), 1)


func test_xp_accumulation_increases_level() -> void:
	progression.add_xp(progression.get_xp_for_next_level())
	assert_eq(progression.get_level(), 2)
	assert_eq(progression.get_current_xp(), 100)


func test_leveling_triggers_at_correct_threshold() -> void:
	var threshold := progression.get_xp_required_for_level(2)
	progression.add_xp(threshold - 1)
	assert_eq(progression.get_level(), 1)
	progression.add_xp(1)
	assert_eq(progression.get_level(), 2)


func test_leveling_emits_signal() -> void:
	watch_signals(progression)
	progression.add_xp(progression.get_xp_for_next_level())
	assert_signal_emitted_with_parameters(progression, "leveled_up", [2, 1])


func test_leveling_grants_skill_point() -> void:
	progression.add_xp(progression.get_xp_for_next_level())
	assert_eq(progression.skill_points, 1)


func test_each_level_grants_skill_point() -> void:
	progression.add_xp(progression.get_xp_required_for_level(4))
	assert_eq(progression.get_level(), 4)
	assert_eq(progression.skill_points, 3)


func test_progression_persistence_saves() -> void:
	progression.add_xp(progression.get_xp_required_for_level(3))
	assert_true(progression.save_progression(SAVE_SLOTS[0]))
	var saved := save_service.load_data(SAVE_SLOTS[0] + "_progression")
	assert_eq(int(saved.get("current_level")), 3)
	assert_eq(int(saved.get("skill_points")), 2)


func test_progression_persistence_loads() -> void:
	progression.add_xp(progression.get_xp_required_for_level(3))
	assert_true(progression.save_progression(SAVE_SLOTS[1]))
	progression.reset_progression()
	assert_true(progression.load_progression(SAVE_SLOTS[1]))
	assert_eq(progression.get_level(), 3)
	assert_eq(progression.skill_points, 2)


func test_progression_persistence_roundtrip() -> void:
	progression.add_xp(progression.get_xp_required_for_level(4) + 25)
	assert_true(progression.save_progression(SAVE_SLOTS[2]))
	var expected := [
		progression.get_level(), progression.get_current_xp(), progression.skill_points
	]
	progression.reset_progression()
	assert_true(progression.load_progression(SAVE_SLOTS[2]))
	assert_eq(
		[progression.get_level(), progression.get_current_xp(), progression.skill_points], expected
	)
