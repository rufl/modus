extends RefCounted


## Record only changed dictionary entries, so unloading does not reset unrelated runtime state.
static func capture(before: Dictionary, after: Dictionary) -> Dictionary:
	var changes: Dictionary = {}
	for key: Variant in after:
		var existed: bool = before.has(key)
		var previous: Variant = before.get(key)
		var applied: Variant = after[key]
		if existed and previous == applied:
			continue
		if applied is Dictionary and (not existed or previous is Dictionary):
			changes[key] = {
				"children": capture(previous if existed else {}, applied), "existed": existed
			}
		else:
			changes[key] = {"existed": existed, "before": _copy(previous), "after": _copy(applied)}
	for key: Variant in before:
		if not after.has(key):
			changes[key] = {"existed": true, "before": _copy(before[key]), "removed": true}
	return changes


static func restore(target: Dictionary, changes: Dictionary) -> void:
	for key: Variant in changes:
		var change: Dictionary = changes[key]
		if change.has("children"):
			if target.get(key) is Dictionary:
				restore(target[key], change.children)
				if not change.existed and target[key].is_empty():
					target.erase(key)
		elif change.get("removed", false):
			if not target.has(key):
				target[key] = _copy(change.before)
		elif target.has(key) and target[key] == change.after:
			if change.existed:
				target[key] = _copy(change.before)
			else:
				target.erase(key)


static func _copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
