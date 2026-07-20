extends SceneTree


func _init():
	GameManager.get_core_system("logger").info(
		"[Exporter] Starting export of procedural model...", "Core"
	)

	# Create the visuals instance
	# We use load() to get the script by path to be safe
	var VisualsScript = load("res://game/entities/common/skeletal_character_visuals.gd")
	if not VisualsScript:
		GameManager.get_core_system("logger").info(
			"[Exporter] Error: Could not load skeletal_character_visuals.gd", "Core"
		)
		quit(1)
		return

	var visuals: Node = VisualsScript.new()
	visuals.name = "SkeletalVisuals"

	# Container root
	var root: Node3D = Node3D.new()
	root.name = "ProceduralCharacter"
	root.add_child(visuals)

	# Manually trigger build methods because _ready() isn't automatically called
	# when just adding child in a SceneTree script without main loop processing
	GameManager.get_core_system("logger").info("[Exporter] Building skeleton...", "Core")
	visuals.build_skeleton()
	GameManager.get_core_system("logger").info("[Exporter] Building visuals...", "Core")
	visuals.build_visuals()

	# Note: We skip animation player setup as we just want the model/rig for Blender

	# Prepare GLTF
	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()

	GameManager.get_core_system("logger").info("[Exporter] Converting to GLTF...", "Core")
	var err: Error = gltf.append_from_scene(root, state)
	if err != OK:
		GameManager.get_core_system("logger").info(
			"[Exporter] Error appending scene to GLTF: " + " " + str(err), "Core"
		)
		quit(1)
		return

	var output_path = "res://game/art/models/skel/procedural_reference.glb"
	GameManager.get_core_system("logger").info(
		"[Exporter] Writing to " + " " + str(output_path), "Core"
	)

	err = gltf.write_to_filesystem(state, output_path)
	if err != OK:
		GameManager.get_core_system("logger").info(
			"[Exporter] Error writing filesystem: " + " " + str(err), "Core"
		)
		quit(1)
	else:
		GameManager.get_core_system("logger").info("[Exporter] Success!", "Core")

	quit(0)
