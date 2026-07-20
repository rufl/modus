extends SceneTree

const JSON5Loader = preload("res://game/core/json5_loader.gd")
const Validator = preload("res://game/scripts/features/modding/mod_package_validator.gd")


func _initialize() -> void:
	var manifests: Array[Dictionary] = []
	var mods_dir := DirAccess.open("res://mods")
	if not mods_dir:
		push_error("Unable to open res://mods")
		quit(1)
		return

	mods_dir.list_dir_begin()
	var folder := mods_dir.get_next()
	while folder != "":
		if mods_dir.current_is_dir() and not folder.begins_with("."):
			var manifest_path := "res://mods/%s/mod.json" % folder
			if FileAccess.file_exists(manifest_path):
				var manifest: Variant = JSON5Loader.load_file(manifest_path)
				if manifest is Dictionary:
					manifests.append(manifest)
				else:
					push_error("%s: manifest is not an object" % manifest_path)
		folder = mods_dir.get_next()
	mods_dir.list_dir_end()

	var result: Dictionary = Validator.new().validate_packages(manifests)
	for warning in result.warnings:
		print("WARN: %s" % warning)
	for error in result.errors:
		push_error(error)
	print("MOD_PACKAGE_VALIDATION packages=%d errors=%d warnings=%d" % [
		manifests.size(), result.errors.size(), result.warnings.size()
	])
	quit(0 if result.valid else 1)
