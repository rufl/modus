@tool
extends PanelContainer

@export var time_slider: HSlider
@export var cloud_slider: HSlider
@export var weather_option: OptionButton
@export var wind_slider: HSlider

var editor_state: Node = null


func setup(state: Node) -> void:
	editor_state = state
	_refresh_ui()


func _ready() -> void:
	if time_slider:
		time_slider.value_changed.connect(_on_time_changed)
	if cloud_slider:
		cloud_slider.value_changed.connect(_on_cloud_changed)
	if weather_option:
		weather_option.item_selected.connect(_on_weather_selected)
		# Populate
		weather_option.clear()
		weather_option.add_item("Clear", 0)
		weather_option.add_item("Rain", 1)
		weather_option.add_item("Snow", 2)
		weather_option.add_item("Storm", 3)
		weather_option.add_item("Windy", 4)
	if wind_slider:
		wind_slider.value_changed.connect(_on_wind_changed)


func _on_time_changed(value: float) -> void:
	if editor_state:
		editor_state.request_environment_change("time", value)


func _on_cloud_changed(value: float) -> void:
	if editor_state:
		editor_state.request_environment_change("clouds", value)


func _on_weather_selected(index: int) -> void:
	if editor_state:
		editor_state.request_environment_change("weather", index)


func _on_wind_changed(value: float) -> void:
	if editor_state:
		editor_state.request_environment_change("wind", value)


func _refresh_ui() -> void:
	# Read current state if possible?
	# For now, we push updates.
	pass
