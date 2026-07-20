@tool
extends EditorNode3DGizmoPlugin


func _init() -> void:
	create_material("player_spawn", Color(0.2, 0.5, 1.0, 0.8))
	create_material("enemy_spawn", Color(1.0, 0.3, 0.2, 0.8))
	create_material("item_spawn", Color(1.0, 0.8, 0.2, 0.8))
	create_handle_material("handles")


func _get_gizmo_name() -> String:
	return "SpawnPoint"


func _has_gizmo(node: Node3D) -> bool:
	if node.get_script():
		return node.get_script().resource_path.contains("spawn_point.gd")
	return false


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var node := gizmo.get_node_3d()
	if not node:
		return

	# Get spawn type and ID
	var spawn_type := "player"
	var entity_id := ""

	if node.has_method("get_spawn_type"):
		spawn_type = node.get_spawn_type()
	elif "spawn_type" in node:
		match node.spawn_type:
			0:
				spawn_type = "player"
			1:
				spawn_type = "enemy"
			2:
				spawn_type = "item"

	if "enemy_id" in node:
		entity_id = node.enemy_id
	if "item_id" in node and spawn_type == "item":
		entity_id = node.item_id

	# Try to find and visualize the actual mesh
	var mesh_found := false
	if not entity_id.is_empty():
		mesh_found = _draw_entity_mesh(gizmo, entity_id)

	# Fallback to symbolic visualization if no mesh found
	if not mesh_found:
		match spawn_type:
			"player":
				_draw_player_spawn(gizmo)
			"enemy":
				_draw_enemy_spawn(gizmo)
			"item":
				_draw_item_spawn(gizmo)
			_:
				_draw_player_spawn(gizmo)


func _draw_entity_mesh(gizmo: EditorNode3DGizmo, entity_id: String) -> bool:
	# Try to get the scene from AssetRegistry
	var plugin = gizmo.get_plugin()
	var editor_interface = plugin.get_editor_interface()
	var scene_root = editor_interface.get_edited_scene_root()
	var registry = scene_root.get_node_or_null("addons/editor/core/AssetRegistry")
	# Fallback search if not in scene yet (e.g. during initial load)
	if not registry:
		# Can't easily access registry if not in the edited scene tree,
		# but we can try to find it via the plugin singleton if properly architected.
		# For now, we'll try a direct load if we know the path pattern,
		# or rely on the fallback.
		pass

	# Better approach: Use the AssetRegistry attached to the editor plugin
	# But we don't have easy access to it here without a global ref.
	# Let's hope the user is using the editor and AssetRegistry is in the tree.

	# Alternative: We can use the project-wide GameDatabase or similar if it existed.
	# Since we added `get_asset_scene` to AssetRegistry, let's try to find it.

	# Searching for AssetRegistry in the Editor's edited scene root
	var root = gizmo.get_node_3d().get_tree().edited_scene_root
	if root:
		# Use find_child with recursive=true
		registry = root.find_child("AssetRegistry", true, false)

	if not registry or not registry.has_method("get_asset_scene"):
		return false

	var scene: PackedScene = registry.get_asset_scene(entity_id)
	if not scene:
		return false

	# Instantiate to find mesh
	# NOTE: This can be expensive if done every frame, but _redraw is called only on invalidation.
	# Optimization: Cache meshes in a static dictionary
	var instance = scene.instantiate()
	var mesh_instance: MeshInstance3D = _find_mesh_recursive(instance)

	if mesh_instance and mesh_instance.mesh:
		# Draw the mesh with a ghost material
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 1, 1, 0.5)  # Ghosty white
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

		# Draw mesh lines (wireframe-ish) or solid
		# gizmo.add_mesh(mesh_instance.mesh, mat, mesh_instance.global_transform.basis)
		# Note: gizmo.add_mesh takes a mesh and material. Transform is relative to node.
		# We need to apply the mesh instance's local transform relative to the scene root
		gizmo.add_mesh(mesh_instance.mesh, mat, mesh_instance.transform)

		instance.free()
		return true

	instance.free()
	return false


func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node

	for child in node.get_children():
		var result = _find_mesh_recursive(child)
		if result:
			return result

	return null


func _draw_player_spawn(gizmo: EditorNode3DGizmo) -> void:
	var lines := PackedVector3Array()
	var height := 2.0  # Player height
	var radius := 0.4

	# Vertical line
	lines.append(Vector3.ZERO)
	lines.append(Vector3(0, height, 0))

	# Circle at bottom
	_add_circle(lines, Vector3.ZERO, radius, 16)

	# Circle at head height
	_add_circle(lines, Vector3(0, height * 0.8, 0), radius * 0.5, 12)

	# Cross at top
	lines.append(Vector3(-radius, height, 0))
	lines.append(Vector3(radius, height, 0))
	lines.append(Vector3(0, height, -radius))
	lines.append(Vector3(0, height, radius))

	# Direction arrow
	lines.append(Vector3(0, 0.5, 0))
	lines.append(Vector3(0, 0.5, -0.8))
	lines.append(Vector3(0, 0.5, -0.8))
	lines.append(Vector3(-0.2, 0.5, -0.5))
	lines.append(Vector3(0, 0.5, -0.8))
	lines.append(Vector3(0.2, 0.5, -0.5))

	gizmo.add_lines(lines, get_material("player_spawn", gizmo), false)


func _draw_enemy_spawn(gizmo: EditorNode3DGizmo) -> void:
	var lines := PackedVector3Array()
	var height := 1.8
	var radius := 0.5

	# Skull-like icon
	# Vertical line
	lines.append(Vector3.ZERO)
	lines.append(Vector3(0, height, 0))

	# Circle at bottom
	_add_circle(lines, Vector3.ZERO, radius, 16)

	# X mark at top
	lines.append(Vector3(-radius, height, -radius))
	lines.append(Vector3(radius, height, radius))
	lines.append(Vector3(-radius, height, radius))
	lines.append(Vector3(radius, height, -radius))

	# Danger triangle
	var tri_height := 0.8
	lines.append(Vector3(0, height + 0.2, 0))
	lines.append(Vector3(-0.3, height + 0.2 + tri_height, 0))
	lines.append(Vector3(-0.3, height + 0.2 + tri_height, 0))
	lines.append(Vector3(0.3, height + 0.2 + tri_height, 0))
	lines.append(Vector3(0.3, height + 0.2 + tri_height, 0))
	lines.append(Vector3(0, height + 0.2, 0))

	gizmo.add_lines(lines, get_material("enemy_spawn", gizmo), false)


func _draw_item_spawn(gizmo: EditorNode3DGizmo) -> void:
	var lines := PackedVector3Array()
	var height := 0.5
	var radius := 0.3

	# Floating diamond shape
	lines.append(Vector3(0, 0, 0))
	lines.append(Vector3(0, height, 0))

	# Diamond
	var mid := height + 0.3
	var top := height + 0.6
	lines.append(Vector3(-radius, mid, 0))
	lines.append(Vector3(0, top, 0))
	lines.append(Vector3(0, top, 0))
	lines.append(Vector3(radius, mid, 0))
	lines.append(Vector3(radius, mid, 0))
	lines.append(Vector3(0, height, 0))
	lines.append(Vector3(0, height, 0))
	lines.append(Vector3(-radius, mid, 0))

	# Same in Z axis
	lines.append(Vector3(0, mid, -radius))
	lines.append(Vector3(0, top, 0))
	lines.append(Vector3(0, top, 0))
	lines.append(Vector3(0, mid, radius))
	lines.append(Vector3(0, mid, radius))
	lines.append(Vector3(0, height, 0))
	lines.append(Vector3(0, height, 0))
	lines.append(Vector3(0, mid, -radius))

	gizmo.add_lines(lines, get_material("item_spawn", gizmo), false)


func _add_circle(lines: PackedVector3Array, center: Vector3, radius: float, segments: int) -> void:
	for i in range(segments):
		var angle1 := (float(i) / segments) * TAU
		var angle2 := (float(i + 1) / segments) * TAU
		lines.append(center + Vector3(cos(angle1) * radius, 0, sin(angle1) * radius))
		lines.append(center + Vector3(cos(angle2) * radius, 0, sin(angle2) * radius))
