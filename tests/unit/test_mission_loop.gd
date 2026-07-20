extends Node

var test_enemy: Node
var step: int = 0


func _ready() -> void:
	print("Starting Mission Loop Test (Scene Mode)...")

	# Autoloads should be ready now
	var gs := GameplaySvc.get_service()
	if not gs or not gs.mission:
		print("FAILURE: GameplayService.mission not found")
		get_tree().quit(1)
		return

	# 2. Spawn Enemy
	test_enemy = Node.new()
	test_enemy.name = "TestEnemy"
	test_enemy.add_to_group("enemies")

	# Mock properties using script
	var script: GDScript = GDScript.new()
	script.source_code = "extends Node\nvar is_dead = false"
	script.reload()
	test_enemy.set_script(script)

	add_child(test_enemy)
	print("Spawned TestEnemy in group 'enemies'")

	# 3. Start Match (simulated)
	# We call handle_match_started directly
	# Pass empty settings to verify default fallback
	gs.mission.handle_match_started({})

	if gs.mission.active_mission_id != "mission_kill_all":
		print("FAILURE: Mission did not start. Active ID: ", gs.mission.active_mission_id)
		# Print available missions to debug
		print("Available: ", gs.mission.available_missions.keys())
		get_tree().quit(1)
		return

	print("Mission Started: ", gs.mission.active_mission_id)


func _process(_delta: float) -> void:
	step += 1

	if step == 30:  # Wait a bit
		print("Simulating Enemy Death...")
		test_enemy.is_dead = true
		test_enemy.queue_free()

	if step > 30 and step < 60:
		# Check if mission completes
		var gs := GameplaySvc.get_service()
		if gs and gs.mission.active_mission_id == "":
			print("SUCCESS: Mission completed (id is empty)")
			get_tree().quit(0)
			return

	if step > 100:
		print("FAILURE: Timed out waiting for mission completion")
		print("Living enemies: ", get_tree().get_nodes_in_group("enemies").size())
		get_tree().quit(1)
		return
