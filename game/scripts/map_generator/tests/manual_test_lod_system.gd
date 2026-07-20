extends Node3D

## Manual test for MapLODManager
## Creates test geometry and applies LOD to demonstrate the system
##
## Instructions:
## 1. Run this scene
## 2. Use WASD to move the camera
## 3. Observe LOD transitions at different distances
## 4. Press SPACE to toggle LOD visualization

var lod_manager: MapLODManager
var context: GenerationContext
var camera: Camera3D
var camera_speed := 10.0
var show_lod_info := false


func _ready() -> void:
	# Create camera
	camera = Camera3D.new()
	camera.position = Vector3(0, 5, 15)
	camera.look_at(Vector3.ZERO)
	add_child(camera)

	# Create test context
	context = GenerationContext.new()
	context.config = GenerationConfig.new()
	context.config.enable_lod = true
	context.grid_size = Vector2i(32, 32)
	context.prefab_instances = []

	# Initialize LOD manager
	lod_manager = MapLODManager.new()
	lod_manager.initialize(context)

	# Create test geometry
	_create_test_geometry()

	# Apply LOD
	lod_manager.apply_lod_to_scene(self)

	# Print statistics
	var stats := lod_manager.get_lod_statistics()
	print("=== LOD System Test ===")
	print("LOD Enabled: ", stats["lod_enabled"])
	print("LOD0 Distance: ", stats["lod0_distance"], "m")
	print("LOD1 Distance: ", stats["lod1_distance"], "m")
	print("LOD2 Distance: ", stats["lod2_distance"], "m")
	print("LOD1 Complexity: ", stats["lod1_complexity"] * 100, "%")
	print("LOD2 Complexity: ", stats["lod2_complexity"] * 100, "%")
	print("\nControls:")
	print("  WASD - Move camera")
	print("  SPACE - Toggle LOD info")
	print("  ESC - Quit")


func _create_test_geometry() -> void:
	# Create a grid of test cubes at various distances
	var cube_mesh := BoxMesh.new()
	cube_mesh.size = Vector3(2, 2, 2)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.3, 0.3)

	# Create cubes at different distances to test LOD transitions
	var distances := [5.0, 15.0, 25.0, 35.0, 45.0, 60.0, 80.0]

	for i in range(distances.size()):
		var distance: float = distances[i]
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = cube_mesh
		mesh_instance.material_override = material
		mesh_instance.position = Vector3(0, 0, -distance)
		mesh_instance.name = "TestCube_%dm" % int(distance)
		add_child(mesh_instance)

		# Add label
		var label := Label3D.new()
		label.text = "%dm" % int(distance)
		label.position = Vector3(0, 3, -distance)
		label.pixel_size = 0.02
		add_child(label)

	# Add directional light
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(light)

	# Add environment
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	env.environment = environment
	add_child(env)


func _process(delta: float) -> void:
	# Camera movement
	var movement := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		movement.z -= 1
	if Input.is_key_pressed(KEY_S):
		movement.z += 1
	if Input.is_key_pressed(KEY_A):
		movement.x -= 1
	if Input.is_key_pressed(KEY_D):
		movement.x += 1

	if movement.length() > 0:
		movement = movement.normalized()
		camera.position += movement * camera_speed * delta

	# Toggle LOD info
	if Input.is_key_pressed(KEY_SPACE) and not show_lod_info:
		show_lod_info = true
		_print_lod_info()
	elif not Input.is_key_pressed(KEY_SPACE):
		show_lod_info = false

	# Quit
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()


func _print_lod_info() -> void:
	print("\n=== Current LOD Info ===")
	print("Camera Position: ", camera.position)

	# Find all LOD containers
	var lod_containers := _find_lod_containers(self)
	print("LOD Containers: ", lod_containers.size())

	for container in lod_containers:
		var distance := camera.position.distance_to(container.global_position)
		var active_lod := _get_active_lod_level(distance)
		print("  %s: %.1fm (LOD%d)" % [container.name, distance, active_lod])


func _find_lod_containers(node: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []

	if node is Node3D and "_LOD" in node.name:
		result.append(node as Node3D)

	for child in node.get_children():
		result.append_array(_find_lod_containers(child))

	return result


func _get_active_lod_level(distance: float) -> int:
	if distance < MapLODManager.LOD0_DISTANCE:
		return 0
	if distance < MapLODManager.LOD1_DISTANCE:
		return 1
	return 2
