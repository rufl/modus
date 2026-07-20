class_name PlayerProgression
extends Node

signal xp_gained(amount: int, new_xp: int, xp_to_next: int)
signal leveled_up(new_level: int, skill_points_gained: int)
signal skill_points_changed(new_amount: int)

const SAVE_DIR: String = "user://saves/"
const DEFAULT_SLOT: String = "default"

var current_xp: int = 0
var current_level: int = 1
var skill_points: int = 0
var base_xp_requirement: int = 100
var xp_exponent: float = 1.5
var max_level: int = 50

var _skill_manager: SkillTreeManager = null


func get_save_path(slot_name: String = DEFAULT_SLOT) -> String:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	return SAVE_DIR + slot_name + "_progression.json"


## Get list of available save slots


static func get_save_slots() -> Array[String]:
	if not DirAccess.dir_exists_absolute("user://saves/"):
		return []

	var dir: DirAccess = DirAccess.open("user://saves/")
	var slots: Array[String] = []
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with("_progression.json"):
				slots.append(file_name.replace("_progression.json", ""))
			file_name = dir.get_next()
	return slots


func _ready() -> void:
	name = "PlayerProgression"


## Set reference to SkillTreeManager


func set_skill_manager(manager: SkillTreeManager) -> void:
	_skill_manager = manager


## Calculate XP required for a specific level


func get_xp_required_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return int(base_xp_requirement * pow(level - 1, xp_exponent))


## Get XP required to reach next level


func get_xp_to_next_level() -> int:
	return get_xp_required_for_level(current_level + 1) - current_xp


func get_level() -> int:
	return current_level


func get_current_xp() -> int:
	return current_xp


func get_xp_for_next_level() -> int:
	return get_xp_to_next_level()


func get_xp_progress() -> float:
	return get_level_progress()


## Get progress to next level (0.0 - 1.0)


func get_level_progress() -> float:
	if current_level >= max_level:
		return 1.0

	var current_level_xp: int = get_xp_required_for_level(current_level)
	var next_level_xp: int = get_xp_required_for_level(current_level + 1)
	var xp_in_level: int = current_xp - current_level_xp
	var xp_needed: int = next_level_xp - current_level_xp

	if xp_needed <= 0:
		return 1.0

	return float(xp_in_level) / float(xp_needed)


## Add XP and check for level-up


func add_xp(amount: int) -> void:
	if current_level >= max_level:
		return

	current_xp += amount

	# Emit local signal
	xp_gained.emit(amount, current_xp, get_xp_to_next_level())

	# Emit global event
	var peer_id: int = 1
	if get_parent() and get_parent().has_method("get_multiplayer_authority"):
		peer_id = get_parent().get_multiplayer_authority()

	GameManager.emit_event("xp_gained", {"peer_id": peer_id, "amount": amount})

	# Check for level-up
	while current_xp >= get_xp_required_for_level(current_level + 1):
		if current_level >= max_level:
			break
		_level_up()


## Internal level-up logic


func _level_up() -> void:
	current_level += 1

	# Award skill point
	var points_gained: int = 1
	skill_points += points_gained

	# Add points to skill tree manager
	if _skill_manager:
		_skill_manager.add_skill_points(points_gained)

	leveled_up.emit(current_level, points_gained)
	skill_points_changed.emit(skill_points)

	GameManager.get_core_system("logger").info(
		"Level up! Now level %d with %d skill points" % [current_level, skill_points], "Player"
	)


## Deduct a percentage of current XP (returns amount deducted)
## Used for death penalties


func deduct_xp(percentage: float) -> int:
	var deduction: int = int(current_xp * percentage)
	current_xp = maxi(0, current_xp - deduction)

	# Emit signal to update UI
	xp_gained.emit(-deduction, current_xp, get_xp_to_next_level())

	return deduction


## Spend a skill point (returns true if successful)


func spend_skill_point() -> bool:
	if skill_points <= 0:
		return false

	skill_points -= 1
	skill_points_changed.emit(skill_points)
	return true


## Refund a skill point (for respec)


func refund_skill_point() -> void:
	skill_points += 1
	skill_points_changed.emit(skill_points)


## Save progression to file via SaveService


func save_progression(slot_name: String = DEFAULT_SLOT) -> bool:
	var save_svc: Node = GameManager.get_core_system("save")
	if not save_svc:
		push_error("[PlayerProgression] SaveService not found")
		return false

	var save_data: Dictionary = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"current_xp": current_xp,
		"current_level": current_level,
		"skill_points": skill_points,
		"unlocked_skills": []
	}

	# Get unlocked skills from manager
	if _skill_manager:
		save_data["unlocked_skills"] = _skill_manager.get_unlocked_skills()

	var metadata: Dictionary = {"type": "progression", "level": current_level}

	# Note: We prefix slot with "prog_" to differentiate from world saves
	# or better, just reuse the slot name if we want one file (requires merging logic)
	# For now, separate file: slot "myrun" -> save "myrun_prog"
	var final_slot: String = slot_name + "_progression"

	if save_svc.save_data(final_slot, save_data, metadata):
		GameManager.get_core_system("logger").info(
			"[PlayerProgression] Saved to %s" % final_slot, "Player"
		)
		return true
	return false


## Load progression from file via SaveService


func load_progression(slot_name: String = DEFAULT_SLOT) -> bool:
	var save_svc: Node = GameManager.get_core_system("save")
	if not save_svc:
		push_error("[PlayerProgression] SaveService not found")
		return false

	var final_slot: String = slot_name + "_progression"
	var save_data: Dictionary = save_svc.load_data(final_slot)

	if save_data.is_empty():
		GameManager.get_core_system("logger").info(
			"[PlayerProgression] No data found for slot '%s'" % final_slot, "Player"
		)
		return false

	# Validate version
	if save_data.get("version", 0) != 1:
		push_warning("Save file version mismatch, may have issues")

	# Load data
	current_xp = save_data.get("current_xp", 0)
	current_level = save_data.get("current_level", 1)
	skill_points = save_data.get("skill_points", 0)

	# Load unlocked skills
	if _skill_manager and "unlocked_skills" in save_data:
		var unlocked: Array = save_data["unlocked_skills"]
		var skill_ids: Array[String] = []
		for skill_id: Variant in unlocked:
			skill_ids.append(str(skill_id))
		_skill_manager.load_unlocked_skills(skill_ids)

	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info(
			(
				"Progression loaded: Level %d, %d XP, %d skill points"
				% [current_level, current_xp, skill_points]
			),
			"Player"
		)

	# Emit signals to update UI
	xp_gained.emit(0, current_xp, get_xp_to_next_level())
	skill_points_changed.emit(skill_points)

	return true


## Reset progression (for testing or respec)


func reset_progression() -> void:
	current_xp = 0
	current_level = 1
	skill_points = 0

	if _skill_manager:
		_skill_manager.reset_all_skills()

	xp_gained.emit(0, current_xp, get_xp_to_next_level())
	skill_points_changed.emit(skill_points)
