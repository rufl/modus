@tool
class_name ActorRegistry
extends Node

signal actor_registered(actor_id: String)
signal actor_unregistered(actor_id: String)

var actors: Dictionary = {}
var categories: Dictionary = {
	"activator": [],
	"trigger": [],
	"mover": [],
	"hazard": [],
	"effect": [],
	"breakable": [],
}


func _ready() -> void:
	_register_builtin_actors()


## Register all built-in actors


func _register_builtin_actors() -> void:
	# Activators
	register_actor(
		{
			"id": "switch",
			"name": "Switch",
			"category": "activator",
			"description": "Interactive switch (toggle/momentary/hold)",
			"script": "res://shared/editor_core/actors/switch_actor.gd",
			"icon": "⚡"
		}
	)

	register_actor(
		{
			"id": "counter",
			"name": "Counter",
			"category": "activator",
			"description": "Counts triggers, activates at target",
			"script": "res://shared/editor_core/actors/counter_actor.gd",
			"icon": "🔢"
		}
	)

	register_actor(
		{
			"id": "timer",
			"name": "Timer",
			"category": "activator",
			"description": "Delayed or repeating activation",
			"script": "res://shared/editor_core/actors/timer_actor.gd",
			"icon": "⏱️"
		}
	)

	# Triggers
	register_actor(
		{
			"id": "trigger_zone",
			"name": "Trigger Zone",
			"category": "trigger",
			"description": "Invisible zone that triggers on enter/exit",
			"script": "res://shared/editor_core/actors/trigger_zone_actor.gd",
			"icon": "🎯"
		}
	)

	# Movers
	register_actor(
		{
			"id": "door",
			"name": "Door",
			"category": "mover",
			"description": "Animated door (slide/rotate)",
			"script": "res://shared/editor_core/actors/door_actor.gd",
			"icon": "🚪"
		}
	)

	register_actor(
		{
			"id": "platform",
			"name": "Moving Platform",
			"category": "mover",
			"description": "Platform moving along waypoints",
			"script": "res://shared/editor_core/actors/platform_actor.gd",
			"icon": "⬛"
		}
	)

	register_actor(
		{
			"id": "teleporter",
			"name": "Teleporter",
			"category": "mover",
			"description": "Teleports entities to target location",
			"script": "res://shared/editor_core/actors/teleporter_actor.gd",
			"icon": "🌀"
		}
	)

	register_actor(
		{
			"id": "jump_pad",
			"name": "Jump Pad",
			"category": "mover",
			"description": "Launches entities into the air",
			"script": "res://shared/editor_core/actors/jump_pad_actor.gd",
			"icon": "⏫"
		}
	)

	# Hazards
	register_actor(
		{
			"id": "spike",
			"name": "Spike Trap",
			"category": "hazard",
			"description": "Pop-up spikes that deal damage",
			"script": "res://shared/editor_core/actors/spike_actor.gd",
			"icon": "☠️"
		}
	)

	register_actor(
		{
			"id": "hazard_volume",
			"name": "Hazard Volume",
			"category": "hazard",
			"description": "Damage zone (lava, acid, etc.)",
			"script": "res://shared/editor_core/actors/hazard_volume_actor.gd",
			"icon": "🔥"
		}
	)

	# Effects
	register_actor(
		{
			"id": "fog_zone",
			"name": "Fog Zone",
			"category": "effect",
			"description": "Volumetric Fog Volume",
			"script": "res://game/world/actors/effects/fog_zone.gd",
			"icon": "🌫️"
		}
	)

	# Spawners
	register_actor(
		{
			"id": "enemy_spawner",
			"name": "Enemy Spawner",
			"category": "activator",
			"description": "Spawns an enemy at runtime",
			"script": "res://shared/editor_core/actors/enemy_spawner_actor.gd",
			"icon": "💀"
		}
	)

	register_actor(
		{
			"id": "pickup_spawner",
			"name": "Pickup Spawner",
			"category": "activator",
			"description": "Spawns items and weapons",
			"script": "res://shared/editor_core/actors/pickup_spawner_actor.gd",
			"icon": "🎁"
		}
	)

	register_actor(
		{
			"id": "environment_volume",
			"name": "Environment Volume",
			"category": "effect",  # Fits effect or trigger
			"description": "Sector overrides for Weather/Physics",
			"script": "res://game/world/actors/volumes/environment_volume.gd",
			"icon": "🌦️"
		}
	)

	# Secret Walls
	register_actor(
		{
			"id": "secret_wall",
			"name": "Secret Wall",
			"category": "mover",
			"description": "Hidden wall that opens when triggered",
			"script": "res://shared/editor_core/actors/secret_wall_actor.gd",
			"icon": "🔓"
		}
	)

	# Breakable Objects
	register_actor(
		{
			"id": "glass_pane",
			"name": "Glass Pane",
			"category": "breakable",
			"description": "Breakable glass window",
			"script": "res://game/world/actors/breakables/glass_pane.gd",
			"icon": "🪟"
		}
	)

	register_actor(
		{
			"id": "wood_crate",
			"name": "Wood Crate",
			"category": "breakable",
			"description": "Breakable wooden crate with item drops",
			"script": "res://game/world/actors/breakables/wood_crate.gd",
			"icon": "📦"
		}
	)

	register_actor(
		{
			"id": "barrel",
			"name": "Barrel",
			"category": "breakable",
			"description": "Metal or explosive barrel",
			"script": "res://game/world/actors/breakables/barrel.gd",
			"icon": "🛢️"
		}
	)

	register_actor(
		{
			"id": "collapsable_floor",
			"name": "Collapsable Floor",
			"category": "breakable",
			"description": "Floor that collapses when triggered",
			"script": "res://shared/editor_core/actors/collapsable_floor_actor.gd",
			"icon": "⬇️"
		}
	)


## Register an actor type


func register_actor(info: Dictionary) -> void:
	var actor_id: String = info.get("id", "")
	if actor_id.is_empty():
		push_warning("[ActorRegistry] Actor missing ID")
		return

	actors[actor_id] = info

	# Add to category
	var category: String = info.get("category", "")
	if categories.has(category):
		if actor_id not in categories[category]:
			categories[category].append(actor_id)

	actor_registered.emit(actor_id)


## Unregister an actor type


func unregister_actor(actor_id: String) -> void:
	if not actors.has(actor_id):
		return

	var info: Dictionary = actors[actor_id]
	var category: String = info.get("category", "")

	if categories.has(category):
		categories[category].erase(actor_id)

	actors.erase(actor_id)
	actor_unregistered.emit(actor_id)


## Create an instance of an actor


func create_actor(actor_id: String) -> Node:
	if not actors.has(actor_id):
		push_warning("[ActorRegistry] Unknown actor: %s" % actor_id)
		return null

	var info: Dictionary = actors[actor_id]
	var script_path: String = info.get("script", "")

	if script_path.is_empty() or not ResourceLoader.exists(script_path):
		push_warning("[ActorRegistry] Script not found: %s" % script_path)
		return null

	var script: Script = load(script_path)
	if not script:
		push_warning("[ActorRegistry] Failed to load script: %s" % script_path)
		return null

	var instance: Node = script.new()
	if "actor_id" in instance:
		instance.set("actor_id", actor_id)
	else:
		instance.set_meta("actor_id", actor_id)

	return instance


## Get actor info


func get_actor_info(actor_id: String) -> Dictionary:
	return actors.get(actor_id, {})


## Get all actors in a category


func get_actors_in_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if categories.has(category):
		for actor_id: String in categories[category]:
			if actors.has(actor_id):
				result.append(actors[actor_id])
	return result


## Get all categories


func get_categories() -> Array[String]:
	var result: Array[String] = []
	for cat: String in categories:
		result.append(cat)
	return result


## Get all actor IDs


func get_all_actor_ids() -> Array[String]:
	var result: Array[String] = []
	for actor_id: String in actors:
		result.append(actor_id)
	return result


## Search actors by name


func search_actors(query: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	query = query.to_lower()

	for actor_id: String in actors:
		var info: Dictionary = actors[actor_id]
		var actor_name: String = info.get("name", "").to_lower()
		var desc: String = info.get("description", "").to_lower()

		if query in actor_name or query in desc or query in actor_id:
			result.append(info)

	return result
