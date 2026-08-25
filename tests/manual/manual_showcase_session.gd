extends SceneTree

const OVERLAY_SCENE := "res://tests/manual/manual_evidence_overlay.tscn"


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene.is_empty():
		push_error("[ManualShowcaseSession] Project main scene is not configured")
		quit(1)
		return

	var error := change_scene_to_file(main_scene)
	if error != OK:
		push_error("[ManualShowcaseSession] Main scene failed to load: %s" % error_string(error))
		quit(1)
		return
	await scene_changed

	var overlay_scene := load(OVERLAY_SCENE) as PackedScene
	if not overlay_scene:
		push_error("[ManualShowcaseSession] Recorder overlay failed to load")
		quit(1)
		return
	root.add_child(overlay_scene.instantiate())
