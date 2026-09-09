extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected an MP3 fixture path")
		quit(1)
		return
	var stream := AudioStreamMP3.load_from_file(args[0])
	if not stream:
		push_error("Cannot load MP3 fixture")
		quit(1)
		return
	var player := AudioStreamPlayer.new()
	root.add_child(player)
	player.stream = stream
	player.play()
	if (
		not player.is_playing()
		or player.get_stream_playback().get_class() != "AudioStreamPlaybackMP3"
	):
		push_error("MP3 playback did not start")
		player.free()
		quit(1)
		return
	player.stop()
	player.stream = null
	player.free()
	stream = null
	# Stop retires playback asynchronously. Quit immediately; no artificial drain wait.
	print("MP3_SHUTDOWN_SMOKE_READY")
	quit(0)
