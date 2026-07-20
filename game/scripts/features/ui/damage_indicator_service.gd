extends Node
class_name DamageIndicatorSvc

const INDICATOR_SCENE: PackedScene = preload("res://game/ui/hud/damage_indicator.tscn")

var _indicators: Array[Control] = []


func initialize() -> void:
	GameManager.subscribe("player_damaged", _on_player_damaged)
	var logger_service: Node = GameManager.get_core_system("logger")
	if logger_service:
		logger_service.info("DamageIndicatorService initialized", "DamageIndicatorService")


func cleanup() -> void:
	# Unsubscribe from events to prevent null callable errors
	GameManager.unsubscribe("player_damaged", _on_player_damaged)

	# Clean up any remaining indicators
	for indicator in _indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()
	_indicators.clear()


func _on_player_damaged(data: Dictionary) -> void:
	var source_pos: Vector3 = data.get("source_position", Vector3.ZERO)
	if source_pos == Vector3.ZERO:
		return

	_show_indicator(source_pos)


func _show_indicator(source_pos: Vector3) -> void:
	var us := UISystem.get_service()
	if not us or not us.ui_manager:
		return

	var indicator: Control = INDICATOR_SCENE.instantiate() as Control
	us.ui_manager.add_child(indicator)
	if indicator.has_method("setup"):
		(indicator as Object).call("setup", source_pos)
	_indicators.append(indicator)
