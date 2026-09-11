@tool
class_name TextureLibrary
extends Node


# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])


const TEXTURE_DIR = "res://shared/editor_core/textures/retro/"

static var _instance: TextureLibrary = null

var materials: Dictionary = {}
var textures: Dictionary = {}


static func get_instance() -> TextureLibrary:
	return _instance


func _enter_tree() -> void:
	_instance = self
	_load_library()


func _load_library() -> void:
	var dir: DirAccess = DirAccess.open(TEXTURE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png"):
				_register_texture(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("[TextureLibrary] Failed to open textures directory: %s" % TEXTURE_DIR)


func _register_texture(file_name: String) -> void:
	var texture_path: String = TEXTURE_DIR + file_name
	var texture_name: String = file_name.get_basename()

	var texture: Texture2D = load(texture_path)
	if texture:
		textures[texture_name] = texture

		# Create material
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_texture = texture
		mat.uv1_triplanar = true
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # Keep it retro

		materials[texture_name] = mat
		_log(str("[TextureLibrary] Registered texture: %s" % texture_name), "Log")


func get_material(texture_name: String) -> Material:
	return materials.get(texture_name, null)


func get_all_texture_names() -> Array:
	return textures.keys()


func get_texture(texture_name: String) -> Texture2D:
	return textures.get(texture_name, null)
