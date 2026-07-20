@tool
class_name MapBoundary
extends Area3D

@export var active: bool = true
@export_category("Damage")
@export var kill_instantly: bool = true
@export var damage_per_second: float = 50.0  ## Used if kill_instantly is false
@export var damage_type: String = "void"  ## death_message category
@export_category("Warning")
@export var warning_time: float = 0.0  ## Time before damage starts (0 = immediate)
@export var warning_message: String = "RETURN TO COMBAT AREA"

var _entities_in_zone: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Default configuration for typical kill plane
	if collision_layer == 1:
		collision_layer = 0  # Don't interact with physics usually
	if collision_mask == 1:
		collision_mask = 2 | 4 | 16  # Players (2) + Enemies (4) + PhysicsObjects (16)


func _process(delta: float) -> void:
	if not active or _entities_in_zone.is_empty():
		return

	# Only authority handles damage
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var current_time: float = Time.get_ticks_msec() / 1000.0

	# Process entities (iterate over keys duplicate to allow removal)
	var entities: Array[Node3D] = _entities_in_zone.keys()
	for entity: Node3D in entities:
		if not is_instance_valid(entity):
			_entities_in_zone.erase(entity)
			continue

		var enter_time: float = _entities_in_zone[entity]
		var elapsed: float = current_time - enter_time

		# Check warning time
		if elapsed < warning_time:
			# Could show client-side warning here via RPC if Player
			continue

		# Apply penalty
		if kill_instantly:
			_apply_instant_death(entity)
		else:
			_apply_damage(entity, delta)


func _on_body_entered(body: Node3D) -> void:
	if not active:
		return

	# Start tracking
	_entities_in_zone[body] = Time.get_ticks_msec() / 1000.0

	# Show warning immediately if applicable (client-side)
	if warning_time > 0 and body is CharacterBody3D:
		if body.is_multiplayer_authority() and body.has_method("show_warning"):
			body.show_warning(warning_message, warning_time)

	GameManager.get_core_system("logger").info(
		"[MapBoundary] Entity entered: %s" % body.name, "World"
	)


func _on_body_exited(body: Node3D) -> void:
	if _entities_in_zone.has(body):
		_entities_in_zone.erase(body)

		# Clear warning
		if body.has_method("hide_warning") and body.is_multiplayer_authority():
			body.hide_warning()


func _get_damage_type_int() -> int:
	match damage_type.to_lower():
		"void":
			return 10  # DamageInfo.DamageType.VOID
		"fire":
			return 6  # DamageInfo.DamageType.FIRE
		"poison":
			return 7  # DamageInfo.DamageType.POISON
		_:
			return 0  # DamageInfo.DamageType.GENERIC


func _apply_instant_death(entity: Node3D) -> void:
	# Check for FallDeathChecker (Player integration)
	var fall_checker: Node = entity.get_node_or_null("FallDeathChecker")
	if fall_checker and fall_checker.has_method("trigger_death"):
		fall_checker.trigger_death()
		return

	var combat_service: Node = GameManager.get_core_system("combat")
	if combat_service:
		combat_service.apply_damage(entity, 10000.0, null, _get_damage_type_int())
	elif "health" in entity:
		entity.health = 0.0
	else:
		entity.queue_free()  # Destroy non-living objects

	_entities_in_zone.erase(entity)  # Stop processing


func _apply_damage(entity: Node3D, delta: float) -> void:
	var damage: float = damage_per_second * delta
	var combat_service: Node = GameManager.get_core_system("combat")
	if combat_service:
		combat_service.apply_damage(entity, damage, null, _get_damage_type_int())
	elif "health" in entity:
		# Manual fallback
		var current_hp: float = entity.get("health")
		entity.set("health", current_hp - damage)
		if entity.get("health") <= 0:
			_entities_in_zone.erase(entity)
