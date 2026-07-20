class_name EnemyBehaviorCoordinator
extends Node

var _enemy: Node
var _health_component: HealthComponent
var _pain_system: PainSystem
var _visuals: Node3D


func setup(
	enemy: Node, health_comp: HealthComponent, pain_sys: PainSystem, visuals: Node3D
) -> void:
	_enemy = enemy
	_health_component = health_comp
	_pain_system = pain_sys
	_visuals = visuals

	# Connect to health component death signal
	if _health_component:
		_health_component.died.connect(_on_died)


func _on_died(_killer_id: int) -> void:
	## Handle enemy death - emit game events for loot and stats
	_enemy.is_dead = true

	# Only server handles death logic
	if _enemy.multiplayer.has_multiplayer_peer() and not _enemy.multiplayer.is_server():
		return

	# NOTE: enemy_died event is emitted by EnemyDamageHandler._handle_death()
	# which includes more detailed information (damage_type, is_crit, etc.)
	# We don't emit it here to avoid duplicate kill counting


@rpc("authority", "call_local", "reliable")
func play_pain_feedback() -> void:
	## Visual/audio feedback for taking damage
	if _visuals:
		# Flash RED for damage (more visible than white)
		_visuals.flash(Color.RED, 0.2)
		# Trigger hurt/flinch animation
		if _visuals.has_method("play_hurt"):
			_visuals.play_hurt()
	else:
		push_warning("[Enemy] No visuals for pain feedback!")


@rpc("authority", "call_local", "unreliable")
func play_telegraph() -> void:
	## Show attack telegraph animation
	if _visuals and _visuals.has_method("play_telegraph"):
		_visuals.play_telegraph()
