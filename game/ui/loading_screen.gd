extends CanvasLayer

@onready var background: ColorRect = $Background
@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var spinner: Control = $CenterContainer/VBoxContainer/Spinner

var _is_loading: bool = false
var _spinner_rotation: float = 0.0


func _ready() -> void:
	visible = false
	layer = 50  # Lower than UI screens (which are at 10)


func _process(delta: float) -> void:
	if _is_loading and spinner:
		# Rotate spinner
		_spinner_rotation += delta * 180.0  # 180 degrees per second
		spinner.rotation = deg_to_rad(_spinner_rotation)


## Show loading screen with optional message


func show_loading(message: String = "Loading...") -> void:
	status_label.text = message
	title_label.text = "LOADING"
	progress_bar.value = 0
	_is_loading = true
	visible = true

	if OS.is_debug_build():
		GameManager.get_core_system("logger").info("[LoadingScreen] Shown: %s" % message, "UI")


## Update progress (0.0 to 1.0) with optional status message


func update_progress(progress: float, message: String = "") -> void:
	progress_bar.value = progress * 100.0

	if message:
		status_label.text = message

	# Force update
	await get_tree().process_frame


## Hide loading screen


func hide_loading() -> void:
	_is_loading = false
	visible = false

	if OS.is_debug_build():
		GameManager.get_core_system("logger").info("[LoadingScreen] Hidden", "UI")


## Load scene with progress tracking


func load_scene_async(scene_path: String) -> void:
	show_loading("Loading scene...")

	# Start threaded loading
	var err: Error = ResourceLoader.load_threaded_request(scene_path)
	if err != OK:
		push_error("[LoadingScreen] Failed to start loading: %s" % scene_path)
		hide_loading()
		return

	# Poll loading progress
	while true:
		var progress: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(
			scene_path, progress
		)

		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				var prog_value: float = progress[0] if progress.size() > 0 else 0.0
				update_progress(prog_value, "Loading assets... %.0f%%" % (prog_value * 100.0))
				await get_tree().process_frame

			ResourceLoader.THREAD_LOAD_LOADED:
				update_progress(1.0, "Complete!")
				var scene: PackedScene = ResourceLoader.load_threaded_get(scene_path)

				if scene:
					get_tree().change_scene_to_packed(scene)
					await get_tree().process_frame
					hide_loading()
				else:
					push_error("[LoadingScreen] Failed to get loaded scene: %s" % scene_path)
					hide_loading()
				return

			ResourceLoader.THREAD_LOAD_FAILED:
				push_error("[LoadingScreen] Failed to load scene: %s" % scene_path)
				hide_loading()
				return

			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("[LoadingScreen] Invalid resource: %s" % scene_path)
				hide_loading()
				return
