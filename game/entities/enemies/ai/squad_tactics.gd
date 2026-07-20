class_name SquadTactics
extends Node

signal squad_formed(squad_id: String)
signal squad_disbanded
signal formation_changed(formation: Formation)

enum Formation { NONE, LINE, WEDGE, CIRCLE, FLANKING }

const CONFIG_PATH := "res://game/config/gameplay/combat.json5"
const DEFAULT_MAX_SQUAD_SIZE := 5
const DEFAULT_FORMATION_SPACING := 3.0
const DEFAULT_AUTO_JOIN_SQUADS := true
const DEFAULT_SQUAD_SEARCH_RADIUS := 20.0
const DEFAULT_FLANK_DISTANCE := 8.0

@export_group("Squad Settings")
@export var squad_id: String = ""
@export var max_squad_size: int = DEFAULT_MAX_SQUAD_SIZE
@export var formation_spacing: float = DEFAULT_FORMATION_SPACING
@export var auto_join_squads: bool = DEFAULT_AUTO_JOIN_SQUADS
@export var squad_search_radius: float = DEFAULT_SQUAD_SEARCH_RADIUS

var squad_members: Array[Node3D] = []
var squad_leader: Node3D = null
var current_formation: Formation = Formation.NONE
var formation_position: Vector3 = Vector3.ZERO
var is_squad_leader: bool = false

var _flank_distance: float = DEFAULT_FLANK_DISTANCE
var _parent: Node3D = null


func _ready() -> void:
	_parent = get_parent() as Node3D
	_load_config()
	if auto_join_squads:
		call_deferred("_try_join_nearby_squad")


func _load_config() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var cm: Node = gm.get_core_system("config") if gm else null
	if not cm:
		return

	var cfg: Variant = cm.get_value("ai_combat.squad_tactics")
	if not cfg is Dictionary:
		return

	if max_squad_size == DEFAULT_MAX_SQUAD_SIZE:
		max_squad_size = cfg.get("max_squad_size", max_squad_size)
	if is_equal_approx(formation_spacing, DEFAULT_FORMATION_SPACING):
		formation_spacing = cfg.get("formation_spacing", formation_spacing)
	if auto_join_squads == DEFAULT_AUTO_JOIN_SQUADS:
		auto_join_squads = cfg.get("auto_join_squads", auto_join_squads)
	if is_equal_approx(squad_search_radius, DEFAULT_SQUAD_SEARCH_RADIUS):
		squad_search_radius = cfg.get("squad_search_radius", squad_search_radius)
	if is_equal_approx(_flank_distance, DEFAULT_FLANK_DISTANCE):
		_flank_distance = cfg.get("flank_distance", _flank_distance)


func try_form_squad() -> bool:
	# Only form squads on server
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return false

	if squad_id.is_empty():
		squad_id = "squad_%d_%d" % [randi(), Time.get_ticks_msec()]

	is_squad_leader = true
	squad_leader = _parent
	squad_members.append(_parent)

	_recruit_nearby_enemies()

	squad_formed.emit(squad_id)
	return true


func join_squad(leader: Node3D, new_squad_id: String) -> void:
	if is_squad_leader:
		return

	squad_leader = leader
	squad_id = new_squad_id
	is_squad_leader = false

	var leader_tactics := leader.get_node_or_null("SquadTactics")
	if leader_tactics:
		leader_tactics.add_member(_parent)


func leave_squad() -> void:
	if is_squad_leader:
		_disband_squad()
	else:
		if squad_leader and is_instance_valid(squad_leader):
			var leader_tactics := squad_leader.get_node_or_null("SquadTactics") as SquadTactics
			if leader_tactics:
				leader_tactics.remove_member(_parent)

	squad_leader = null
	squad_id = ""
	squad_disbanded.emit()


func set_formation(formation: Formation) -> void:
	if not is_squad_leader:
		return

	current_formation = formation
	_update_formation_positions()
	formation_changed.emit(formation)


func get_formation_position() -> Vector3:
	return formation_position


func get_squad_size() -> int:
	return squad_members.size()


func get_squad_center() -> Vector3:
	if squad_members.is_empty():
		return Vector3.ZERO

	var center := Vector3.ZERO
	var valid_count := 0

	for member: Node3D in squad_members:
		if is_instance_valid(member):
			center += member.global_position
			valid_count += 1

	return center / valid_count if valid_count > 0 else Vector3.ZERO


func should_flank(target_position: Vector3) -> bool:
	if not is_squad_leader or squad_members.size() < 3:
		return false

	var squad_center := get_squad_center()
	var to_target := (target_position - squad_center).normalized()

	var flanking_count := 0
	for member: Node3D in squad_members:
		if not is_instance_valid(member):
			continue

		var to_member := (member.global_position - squad_center).normalized()
		var angle := to_target.dot(to_member)

		# Members not directly facing target can flank
		if angle < 0.5:
			flanking_count += 1

	return flanking_count >= 2


func get_flank_position(target_position: Vector3, side: int) -> Vector3:
	if not squad_leader or not is_instance_valid(squad_leader):
		return Vector3.ZERO

	var to_target := (target_position - squad_leader.global_position).normalized()
	var perpendicular := Vector3(-to_target.z, 0.0, to_target.x)

	var flank_direction := perpendicular * side
	var flank_distance := 8.0

	return target_position + flank_direction * flank_distance


func issue_attack_order(target: Node3D) -> void:
	if not is_squad_leader:
		return

	for member: Node3D in squad_members:
		if not is_instance_valid(member):
			continue

		# Set target via enemy AI interface
		if member.has_method("set_target"):
			member.set_target(target)
		elif "current_target" in member:
			member.current_target = target


func issue_move_order(position: Vector3) -> void:
	if not is_squad_leader:
		return

	set_formation(current_formation if current_formation != Formation.NONE else Formation.LINE)

	# Calculate formation positions around destination
	_update_formation_positions_around(position)


func _try_join_nearby_squad() -> void:
	if not _parent:
		return

	# Use GameManager.get_core_system("entity") for fast O(1) lookup
	var gm: Node = get_node_or_null("/root/GameManager")
	var gs: Node = gm.get_core_system("gameplay") if gm else null
	var enemies: Array[Node] = []
	if gs and gs.entity_registry:
		enemies = gs.entity_registry.get_all_enemies()

	for enemy: Node in enemies:
		if enemy == _parent:
			continue

		var distance: float = _parent.global_position.distance_to(enemy.global_position)
		if distance > squad_search_radius:
			continue

		var enemy_tactics := enemy.get_node_or_null("SquadTactics") as SquadTactics
		if not enemy_tactics:
			continue

		if enemy_tactics.is_squad_leader and enemy_tactics.squad_members.size() < max_squad_size:
			join_squad(enemy, enemy_tactics.squad_id)
			return


func _recruit_nearby_enemies() -> void:
	if not is_squad_leader or not _parent:
		return

	# Use GameManager.get_core_system("entity") for fast O(1) lookup
	var gm: Node = get_node_or_null("/root/GameManager")
	var gs: Node = gm.get_core_system("gameplay") if gm else null
	var enemies: Array[Node] = []
	if gs and gs.entity_registry:
		enemies = gs.entity_registry.get_all_enemies()

	for enemy: Node in enemies:
		if enemy == squad_leader:
			continue

		if squad_members.size() >= max_squad_size:
			break

		var distance: float = squad_leader.global_position.distance_to(enemy.global_position)
		if distance > squad_search_radius:
			continue

		var enemy_tactics := enemy.get_node_or_null("SquadTactics") as SquadTactics
		if enemy_tactics and enemy_tactics.squad_id.is_empty():
			enemy_tactics.join_squad(squad_leader, squad_id)


func add_member(member: Node3D) -> void:
	if not is_squad_leader:
		return

	if squad_members.size() >= max_squad_size:
		return

	if not squad_members.has(member):
		squad_members.append(member)
		_update_formation_positions()


func remove_member(member: Node3D) -> void:
	if not is_squad_leader:
		return

	squad_members.erase(member)

	if squad_members.size() <= 1:
		_disband_squad()
	else:
		_update_formation_positions()


func _disband_squad() -> void:
	for member: Node3D in squad_members:
		if not is_instance_valid(member) or member == squad_leader:
			continue

		var member_tactics := member.get_node_or_null("SquadTactics") as SquadTactics
		if member_tactics:
			member_tactics.squad_leader = null
			member_tactics.squad_id = ""

	squad_members.clear()
	is_squad_leader = false
	squad_disbanded.emit()


func _update_formation_positions() -> void:
	if not is_squad_leader or squad_members.is_empty():
		return

	_update_formation_positions_around(get_squad_center())


func _update_formation_positions_around(center: Vector3) -> void:
	match current_formation:
		Formation.LINE:
			_assign_line_formation(center)
		Formation.WEDGE:
			_assign_wedge_formation(center)
		Formation.CIRCLE:
			_assign_circle_formation(center)
		Formation.FLANKING:
			_assign_flanking_formation(center)
		Formation.NONE:
			# Everyone stays at center
			for member: Node3D in squad_members:
				var tactics := member.get_node_or_null("SquadTactics") as SquadTactics
				if tactics:
					tactics.formation_position = center


func _assign_line_formation(center: Vector3) -> void:
	var count := squad_members.size()
	var half_width := (count - 1) * formation_spacing * 0.5

	for i: int in range(count):
		if not is_instance_valid(squad_members[i]):
			continue

		var offset := Vector3(i * formation_spacing - half_width, 0.0, 0.0)
		var tactics := squad_members[i].get_node_or_null("SquadTactics")
		if tactics:
			tactics.formation_position = center + offset


func _assign_wedge_formation(center: Vector3) -> void:
	var count := squad_members.size()

	for i: int in range(count):
		if not is_instance_valid(squad_members[i]):
			continue

		var row := int(sqrt(float(i)))
		var col := i - (row * row)
		var offset := Vector3((col - row * 0.5) * formation_spacing, 0.0, row * formation_spacing)

		var tactics := squad_members[i].get_node_or_null("SquadTactics")
		if tactics:
			tactics.formation_position = center + offset


func _assign_circle_formation(center: Vector3) -> void:
	var count := squad_members.size()

	for i: int in range(count):
		if not is_instance_valid(squad_members[i]):
			continue

		var angle := (TAU / count) * i
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * formation_spacing * 2.0

		var tactics := squad_members[i].get_node_or_null("SquadTactics")
		if tactics:
			tactics.formation_position = center + offset


func _assign_flanking_formation(center: Vector3) -> void:
	var count := squad_members.size()
	@warning_ignore("integer_division")
	var half := count / 2

	for i: int in range(count):
		if not is_instance_valid(squad_members[i]):
			continue

		var side := 1.0 if i < half else -1.0
		var offset := Vector3(
			side * formation_spacing * 3.0, 0.0, float(i % maxi(half, 1)) * formation_spacing
		)

		var tactics := squad_members[i].get_node_or_null("SquadTactics")
		if tactics:
			tactics.formation_position = center + offset
