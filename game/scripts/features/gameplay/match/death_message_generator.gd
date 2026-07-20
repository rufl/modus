class_name DeathMessageGenerator
extends RefCounted

const DEFAULT_PHRASES = ["{victim} died."]
const SUICIDE_PHRASES = ["{victim} killed themselves.", "{victim} couldn't take it anymore."]
const VOID_PHRASES = ["{victim} fell into the void.", "{victim} left the map."]
const FALL_PHRASES = ["{victim} fell to their death.", "{victim} forgot about gravity."]
const WEAPON_PHRASES = {
	"pistol": ["{killer} shot {victim}.", "{killer} put a bullet in {victim}."],
	"shotgun": ["{killer} blasted {victim}.", "{killer} turned {victim} into swiss cheese."],
	"machinegun": ["{killer} mowed down {victim}.", "{killer} sprayed {victim}."],
	"rocket": ["{killer} blew up {victim}.", "{killer} rocketed {victim}."],
	"railgun": ["{killer} railed {victim}.", "{killer} sniped {victim}."],
	"melee": ["{killer} beat {victim} to death.", "{killer} punched {victim}'s lights out."],
}
const GENERIC_KILL_PHRASES = ["{killer} killed {victim}.", "{killer} fragged {victim}."]


static func _get_phrases(category: String, subcategory: String = "") -> Array:
	var cm: Node = GameManager.get_core_system("config")
	if cm:
		# Try to get from config
		var path: String = "death_messages." + category
		if not subcategory.is_empty():
			path += "." + subcategory

		var phrases: Variant = cm.get_value(path)
		if phrases is Array:
			return phrases

	# Fallback if config failed/missing
	match category:
		"suicide":
			return SUICIDE_PHRASES
		"void":
			return VOID_PHRASES
		"fall":
			return FALL_PHRASES
		"generic_kill":
			return GENERIC_KILL_PHRASES
		"weapons":
			if not subcategory.is_empty() and WEAPON_PHRASES.has(subcategory):
				return WEAPON_PHRASES[subcategory]
			return DEFAULT_PHRASES
		_:
			return DEFAULT_PHRASES


static func generate_message(
	victim_name: String, killer_name: String, damage_source: String = ""
) -> String:
	# 1. Suicide / Self-Kill
	if victim_name == killer_name:
		if damage_source == "void" or damage_source == "fall":
			return _pick_random(_get_phrases("void")).format({"victim": victim_name})
		return _pick_random(_get_phrases("suicide")).format({"victim": victim_name})

	# 2. Environment
	if killer_name == "Environment":
		if damage_source == "fall":
			return _pick_random(_get_phrases("fall")).format({"victim": victim_name})
		if damage_source == "void":
			return _pick_random(_get_phrases("void")).format({"victim": victim_name})

		# For hazards, we might not have a specific category in JSON yet.
		# use generic env logic or define 'hazards'.
		# Current JSON has 'void', 'suicide', 'default', 'weapons', 'generic_kill'.
		# We'll use a hardcoded fallback or add 'hazards' to JSON later if needed.
		# For now, let's stick to the behavior we had or try to fetch 'hazards'
		var hazard_phrases: Array = _get_phrases("hazards")
		if hazard_phrases != DEFAULT_PHRASES:
			return _pick_random(hazard_phrases).format({"victim": victim_name})

		if damage_source == "hazards" or damage_source == "lava" or damage_source == "acid":
			return "{victim} took a bath/swim in something bad.".format({"victim": victim_name})

		return "{victim} was killed by the environment.".format({"victim": victim_name})

	# 3. PvP Kill
	if not damage_source.is_empty():
		# Try exact match
		var w_phrases: Array = _get_phrases("weapons", damage_source)
		if w_phrases != DEFAULT_PHRASES:
			return _pick_random(w_phrases).format({"victim": victim_name, "killer": killer_name})

		# Try partial match (e.g. "shotgun_super" -> "shotgun")
		var cm: Node = GameManager.get_core_system("config")
		if cm:
			var all_weapons: Variant = cm.get_value("visuals.death_messages.weapons")
			if all_weapons is Dictionary:
				for key: String in all_weapons.keys():
					if damage_source.begins_with(key) or key in damage_source:
						var list: Variant = all_weapons[key]
						if list is Array and not list.is_empty():
							return _pick_random(list).format(
								{"victim": victim_name, "killer": killer_name}
							)

		# Fallback partial match
		for key: String in WEAPON_PHRASES.keys():
			if damage_source.begins_with(key) or key in damage_source:
				return _pick_random(WEAPON_PHRASES[key]).format(
					{"victim": victim_name, "killer": killer_name}
				)

	# 4. Fallback Generic PvP
	if killer_name != "Unknown" and not killer_name.is_empty():
		return _pick_random(_get_phrases("generic_kill")).format(
			{"victim": victim_name, "killer": killer_name}
		)

	# 5. Last Resort
	return _pick_random(_get_phrases("default")).format({"victim": victim_name})


static func _pick_random(arr: Array) -> String:
	if arr.is_empty():
		return "{victim} died."
	return arr[randi() % arr.size()]
