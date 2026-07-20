extends HSlider


func _on_value_changed(sensitivity_value: float) -> void:
	GameManager.get_core_system("globals").sensitivity = sensitivity_value
