extends HSlider


func _on_value_changed(controller_sensitivity: float) -> void:
	GameManager.get_core_system("globals").controller_sensitivity = controller_sensitivity
