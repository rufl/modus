extends Node
class_name BloodPoolSetup

## Helper script to setup blood pools in game levels
## Attach to level root or use as autoload

@export var auto_setup_on_ready: bool = true
@export var blood_texture_size: int = 256
@export var blood_color: Color = Color(0.35, 0.05, 0.05)
@export var blood_merge_factor: float = 0.25


func _ready() -> void:
	if auto_setup_on_ready:
		await get_tree().process_frame
		setup_blood_pools()


## Setup all blood pools in the scene
func setup_blood_pools() -> void:
	var pools = get_tree().get_nodes_in_group("blood_pool")

	if pools.is_empty():
		push_warning(
			"[BloodPoolSetup] No blood pools found in scene. Add MeshInstance3D nodes to 'blood_pool' group."
		)
		return

	for pool in pools:
		if pool is BloodPool:
			_configure_blood_pool(pool)

	GameManager.get_core_system("logger").info(
		"[BloodPoolSetup] Configured %d blood pool(s)" % pools.size(), "Core"
	)


## Configure a single blood pool
func _configure_blood_pool(pool: BloodPool) -> void:
	var mat: ShaderMaterial = pool.get_active_material(0)
	if not mat:
		push_warning("[BloodPoolSetup] Blood pool missing ShaderMaterial: %s" % pool.name)
		return

	# Generate blood texture if not assigned
	if not mat.get_shader_parameter("blood_texture"):
		var blood_tex = BloodTextureGenerator.create_blood_gradient_texture(blood_texture_size)
		mat.set_shader_parameter("blood_texture", blood_tex)

	# Set blood color
	mat.set_shader_parameter("blood_color", blood_color)
	mat.set_shader_parameter("blood_merge_factor", blood_merge_factor)


## Create a blood pool programmatically
static func create_blood_pool(
	parent: Node3D, position: Vector3, size: Vector2 = Vector2(10, 10), subdivisions: int = 32
) -> BloodPool:
	# Create mesh instance
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "BloodPool"
	mesh_instance.position = position

	# Create plane mesh
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = size
	plane_mesh.subdivide_width = subdivisions
	plane_mesh.subdivide_depth = subdivisions
	mesh_instance.mesh = plane_mesh

	# Load shader
	var shader: Shader = load("res://shared/shaders/blood_pool.gdshader")
	if not shader:
		push_error("[BloodPoolSetup] Failed to load blood pool shader")
		return null

	# Create shader material
	var mat := ShaderMaterial.new()
	mat.shader = shader

	# Generate blood texture
	var blood_tex = BloodTextureGenerator.create_blood_gradient_texture(256)
	mat.set_shader_parameter("blood_texture", blood_tex)
	mat.set_shader_parameter("blood_color", Color(0.35, 0.05, 0.05))
	mat.set_shader_parameter("blood_merge_factor", 0.25)

	mesh_instance.set_surface_override_material(0, mat)

	# Attach script
	var script: Script = load("res://shared/shaders/blood_pool.gd")
	if script:
		mesh_instance.set_script(script)

	# Add to group
	mesh_instance.add_to_group("blood_pool")

	# Add to parent
	parent.add_child(mesh_instance)

	return mesh_instance as BloodPool


## Get blood pool manager from effects service
static func get_blood_pool_manager() -> BloodPoolManager:
	var effects_service = GameManager.get_core_system("effects")
	if effects_service and "blood_pool_manager" in effects_service:
		return effects_service.blood_pool_manager
	return null
