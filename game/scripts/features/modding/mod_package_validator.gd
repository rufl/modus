class_name ModPackageValidator
extends RefCounted

## Validates mod package manifests before they reach ModLoader.
## Errors are structural or dependency/override failures; disabled mods are warnings.

const REQUIRED_FIELDS: Array[String] = ["id", "name", "version"]
const OVERRIDE_SECTIONS: Array[String] = ["systems", "weapons", "enemies", "loot", "loot_tables"]


func validate_manifest(manifest: Dictionary, source: String = "<memory>") -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	for field in REQUIRED_FIELDS:
		if not manifest.has(field) or str(manifest.get(field, "")).strip_edges().is_empty():
			errors.append("%s: missing required field '%s'" % [source, field])

	if manifest.has("dependencies") and not manifest.dependencies is Array:
		errors.append("%s: dependencies must be an array" % source)
	if manifest.has("config_overrides") and not manifest.config_overrides is Dictionary:
		errors.append("%s: config_overrides must be an object" % source)
	if manifest.has("enabled") and not manifest.enabled is bool:
		errors.append("%s: enabled must be a boolean" % source)
	elif not manifest.get("enabled", false):
		warnings.append("%s: mod is disabled" % source)

	return {
		"source": source,
		"id": str(manifest.get("id", "")),
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings
	}


func validate_packages(manifests: Array[Dictionary]) -> Dictionary:
	var results: Array[Dictionary] = []
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var package_ids: Dictionary = {}
	var overrides: Dictionary = {}

	for manifest in manifests:
		var source := str(manifest.get("id", "<unknown>"))
		var result := validate_manifest(manifest, source)
		results.append(result)
		errors.append_array(result.errors)
		warnings.append_array(result.warnings)
		if result.id != "":
			package_ids[result.id] = true

	for manifest in manifests:
		var mod_id := str(manifest.get("id", "<unknown>"))
		for dependency in manifest.get("dependencies", []):
			if not package_ids.has(str(dependency)):
				errors.append("%s: missing dependency '%s'" % [mod_id, str(dependency)])
		if not manifest.get("enabled", false):
			continue
		var config_overrides: Dictionary = manifest.get("config_overrides", {})
		if not config_overrides is Dictionary:
			continue
		for section in OVERRIDE_SECTIONS:
			var section_data: Variant = config_overrides.get(section, {})
			if not section_data is Dictionary:
				continue
			for target in section_data.keys():
				var key := "%s.%s" % [section, str(target)]
				if overrides.has(key):
					errors.append(
						"override conflict on %s between %s and %s" % [key, overrides[key], mod_id]
					)
				else:
					overrides[key] = mod_id

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"packages": results,
		"override_owners": overrides
	}
