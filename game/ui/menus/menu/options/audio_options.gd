extends Node

@onready var master_slider: HSlider = %MasterVolumeSlider
@onready var sfx_slider: HSlider = %SFXVolumeSlider
@onready var music_slider: HSlider = %MusicVolumeSlider
@onready var master_label: Label = %MasterVolumeLabel
@onready var sfx_label: Label = %SFXVolumeLabel
@onready var music_label: Label = %MusicVolumeLabel


func _ready() -> void:
	# Setup sliders with current values
	if master_slider:
		# Convert dB to percentage (0-100)
		master_slider.value = _db_to_percent(GameManager.get_core_system("audio").master_volume)
		master_slider.value_changed.connect(_on_master_changed)
		_update_master_label()

	if sfx_slider:
		sfx_slider.value = _db_to_percent(GameManager.get_core_system("audio").sfx_volume)
		sfx_slider.value_changed.connect(_on_sfx_changed)
		_update_sfx_label()

	if music_slider:
		music_slider.value = _db_to_percent(GameManager.get_core_system("audio").music_volume)
		music_slider.value_changed.connect(_on_music_changed)
		_update_music_label()


func _on_master_changed(value: float) -> void:
	GameManager.get_core_system("audio").set_master_volume(_percent_to_db(value))
	_update_master_label()


func _on_sfx_changed(value: float) -> void:
	GameManager.get_core_system("audio").set_sfx_volume(_percent_to_db(value))
	_update_sfx_label()


func _on_music_changed(value: float) -> void:
	GameManager.get_core_system("audio").set_music_volume(_percent_to_db(value))
	_update_music_label()


func _update_master_label() -> void:
	if master_label and master_slider:
		master_label.text = "%d%%" % int(master_slider.value)


func _update_sfx_label() -> void:
	if sfx_label and sfx_slider:
		sfx_label.text = "%d%%" % int(sfx_slider.value)


func _update_music_label() -> void:
	if music_label and music_slider:
		music_label.text = "%d%%" % int(music_slider.value)


## Convert dB to percentage (0-100)


func _db_to_percent(db: float) -> float:
	# -40dB = 0%, 0dB = 100%
	return clampf((db + 40.0) / 40.0 * 100.0, 0.0, 100.0)


## Convert percentage to dB


func _percent_to_db(percent: float) -> float:
	# 0% = -40dB (mute), 100% = 0dB (full)
	if percent <= 0:
		return -80.0  # Effectively mute
	return (percent / 100.0) * 40.0 - 40.0
