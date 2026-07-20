extends Node


func _ready() -> void:
	print("[Example Mod] Hello World! The mod is running.")
	print("[Example Mod] Pistol damage should now be 50.")

	# Demonstrate event listening using GameManager
	GameManager.subscribe(
		"match_started", func(_data: Dictionary) -> void: print("[Example Mod] Match Started!")
	)
