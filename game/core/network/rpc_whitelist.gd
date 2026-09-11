extends RefCounted
class_name RPCWhitelist

## RPC Whitelist - Security-First RPC Validation
##
## This class maintains a comprehensive whitelist of all allowed RPC methods
## with their rate limits and validation requirements.
##
## CRITICAL SECURITY RULE: Any RPC not in this whitelist is DENIED by default.

## RPC Configuration Structure
## {
##   "method_name": {
##     "calls_per_second": float,
##     "requires_validation": bool,
##     "validator_method": String (optional),
##     "description": String
##   }
## }

const ALLOWED_RPCS: Dictionary = {
	# ========================================================================
	# COMBAT RPCS (High Frequency)
	# ========================================================================
	"request_shoot":
	{
		"calls_per_second": 10.0,
		"requires_validation": true,
		"validator_method": "_validate_shoot_request",
		"description": "Client requests to fire weapon"
	},
	"request_damage":
	{
		"calls_per_second": 20.0,
		"requires_validation": true,
		"validator_method": "_validate_damage_request",
		"description": "Request damage application to entity"
	},
	"_sync_muzzle_flash":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Server syncs muzzle flash effect"
	},
	"_sync_tracer":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Server syncs bullet tracer"
	},
	"_sync_spawn_projectile":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Server syncs projectile spawn"
	},
	# ========================================================================
	# MOVEMENT RPCS (Very High Frequency)
	# ========================================================================
	"sync_position":
	{"calls_per_second": 60.0, "requires_validation": false, "description": "Sync player position"},
	"_sync_movement_state":
	{
		"calls_per_second": 60.0,
		"requires_validation": false,
		"description": "Sync movement state (crouch, sprint)"
	},
	"request_dodge":
	# ========================================================================
	# WEAPON RPCS
	{"calls_per_second": 2.0, "requires_validation": false, "description": "Request dodge action"},
	# ========================================================================
	"request_weapon_switch":
	{
		"calls_per_second": 5.0,
		"requires_validation": true,
		"validator_method": "_validate_weapon_switch",
		"description": "Request weapon switch"
	},
	"reject_weapon_switch":
	{
		"calls_per_second": 5.0,
		"requires_validation": false,
		"description": "Server rejects weapon switch (rollback)"
	},
	"confirm_weapon_switch":
	{
		"calls_per_second": 5.0,
		"requires_validation": false,
		"description": "Server confirms weapon switch"
	},
	"request_reload":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Request weapon reload"
	},
	"_request_grenade_spawn":
	# ========================================================================
	# ITEM/INVENTORY RPCS
	{"calls_per_second": 2.0, "requires_validation": false, "description": "Request grenade spawn"},
	# ========================================================================
	"request_pickup":
	{
		"calls_per_second": 5.0,
		"requires_validation": true,
		"validator_method": "_validate_pickup_request",
		"description": "Request item pickup"
	},
	"request_drop":
	{"calls_per_second": 2.0, "requires_validation": false, "description": "Request item drop"},
	"request_use_item":
	{"calls_per_second": 10.0, "requires_validation": false, "description": "Request item use"},
	"give_item":
	{"calls_per_second": 5.0, "requires_validation": false, "description": "Give item to player"},
	"move_item":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Move item in inventory"
	},
	"split_stack":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Split inventory stack"
	},
	"equip_item":
	{"calls_per_second": 10.0, "requires_validation": false, "description": "Equip inventory item"},
	"unequip_item":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Unequip inventory item"
	},
	# ========================================================================
	# MATCH SERVICE RPCS (Critical #12)
	# ========================================================================
	"update_player_status":
	{
		"calls_per_second": 10.0,
		"requires_validation": true,
		"validator_method": "_validate_player_status_update",
		"description": "Update player status (health, state)"
	},
	"register_kill":
	{
		"calls_per_second": 5.0,
		"requires_validation": true,
		"validator_method": "_validate_kill_registration",
		"description": "Register kill event"
	},
	"request_respawn":
	{
		"calls_per_second": 1.0,
		"requires_validation": false,
		"description": "Request player respawn"
	},
	"send_message":
	{
		"calls_per_second": 3.0,
		"requires_validation": true,
		"validator_method": "_validate_chat_message",
		"description": "Send chat message (anti-spam)"
	},
	"send_chat_message":
	{
		"calls_per_second": 3.0,
		"requires_validation": true,
		"validator_method": "_validate_chat_message",
		"description": "Send chat message via ChatService"
	},
	# ========================================================================
	# PLAYER STATE MANAGER RPCS (Critical #12)
	# ========================================================================
	"set_player_state":
	{
		"calls_per_second": 5.0,
		"requires_validation": false,
		"description": "Set player state (alive, dead, downed)"
	},
	"set_player_mode":
	{
		"calls_per_second": 2.0,
		"requires_validation": false,
		"description": "Set player mode (spectator, editor)"
	},
	# ========================================================================
	# NETWORK EDITOR RPCS (Critical #12)
	# ========================================================================
	"place_block":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Place block in editor"
	},
	"delete_node":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Delete node in editor"
	},
	"paint_block":
	{
		"calls_per_second": 15.0,
		"requires_validation": false,
		"description": "Paint block in editor"
	},
	"place_entity":
	{"calls_per_second": 5.0, "requires_validation": false, "description": "Place editor entity"},
	"transform_node":
	{
		"calls_per_second": 15.0,
		"requires_validation": false,
		"description": "Transform editor node"
	},
	"request_action":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Editor action request"
	},
	"sync_action":
	{"calls_per_second": 10.0, "requires_validation": false, "description": "Editor action sync"},
	"update_cursor":
	{
		"calls_per_second": 60.0,
		"requires_validation": false,
		"description": "Editor cursor position"
	},
	"sync_cursor":
	# ========================================================================
	# WORLD/ENVIRONMENT RPCS
	{"calls_per_second": 60.0, "requires_validation": false, "description": "Editor cursor sync"},
	# ========================================================================
	"request_spawn":
	{"calls_per_second": 1.0, "requires_validation": false, "description": "Request player spawn"},
	"toggle_freeze":
	{
		"calls_per_second": 1.0,
		"requires_validation": false,
		"description": "Toggle time freeze (projectile lab)"
	},
	"_sync_time_scale":
	{"calls_per_second": 1.0, "requires_validation": false, "description": "Sync time scale"},
	"request_state_change":
	{
		"calls_per_second": 2.0,
		"requires_validation": false,
		"description": "Request enemy lab state change"
	},
	# ========================================================================
	# INTERACTIVE OBJECT RPCS
	# ========================================================================
	"_request_open":
	{"calls_per_second": 2.0, "requires_validation": false, "description": "Request door open"},
	"_request_close":
	{"calls_per_second": 2.0, "requires_validation": false, "description": "Request door close"},
	"_perform_open":
	{
		"calls_per_second": 2.0,
		"requires_validation": false,
		"description": "Perform door open (server)"
	},
	"_perform_close":
	{
		"calls_per_second": 2.0,
		"requires_validation": false,
		"description": "Perform door close (server)"
	},
	"_request_damage":
	{"calls_per_second": 10.0, "requires_validation": false, "description": "Request prop damage"},
	"_request_reveal":
	{
		"calls_per_second": 1.0,
		"requires_validation": false,
		"description": "Request hidden stash reveal"
	},
	"_request_take_rpc":
	{
		"calls_per_second": 2.0,
		"requires_validation": false,
		"description": "Request weapon rack take"
	},
	"_request_open_rpc":
	{"calls_per_second": 2.0, "requires_validation": false, "description": "Request chest open"},
	"_request_loot_rpc":
	# ========================================================================
	# SYNC RPCS (Server -> Client)
	{"calls_per_second": 2.0, "requires_validation": false, "description": "Request corpse loot"},
	# ========================================================================
	"_sync_break":
	{"calls_per_second": 5.0, "requires_validation": false, "description": "Sync object break"},
	"sync_time":
	{"calls_per_second": 1.0, "requires_validation": false, "description": "Sync day/night time"},
	"_sync_state":
	{"calls_per_second": 5.0, "requires_validation": false, "description": "Sync hazard state"},
	"_spawn_projectile":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Spawn turret projectile"
	},
	"_sync_health":
	{"calls_per_second": 10.0, "requires_validation": false, "description": "Sync entity health"},
	"_sync_destroyed":
	{"calls_per_second": 5.0, "requires_validation": false, "description": "Sync destroyed state"},
	"_play_break_effects":
	{"calls_per_second": 5.0, "requires_validation": false, "description": "Play break effects"},
	"_play_impact_effects":
	{"calls_per_second": 10.0, "requires_validation": false, "description": "Play impact effects"},
	"_play_reveal":
	{"calls_per_second": 2.0, "requires_validation": false, "description": "Play reveal animation"},
	"_give_weapon":
	{"calls_per_second": 2.0, "requires_validation": false, "description": "Give weapon to player"},
	"_play_take_effect":
	{"calls_per_second": 2.0, "requires_validation": false, "description": "Play take effect"},
	"_play_opening":
	{"calls_per_second": 2.0, "requires_validation": false, "description": "Play chest opening"},
	"_play_loot_effect":
	{"calls_per_second": 2.0, "requires_validation": false, "description": "Play loot effect"},
	"_play_damage_feedback":
	{"calls_per_second": 10.0, "requires_validation": false, "description": "Play damage feedback"},
	"_play_destruction":
	{
		"calls_per_second": 5.0,
		"requires_validation": false,
		"description": "Play destruction effects"
	},
	# ========================================================================
	# ENEMY/AI RPCS
	# ========================================================================
	"sync_blood_hit":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Sync blood hit effect"
	},
	"sync_spawn_ragdoll":
	{"calls_per_second": 5.0, "requires_validation": false, "description": "Sync ragdoll spawn"},
	"play_pain_feedback":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Play enemy pain feedback (visual/audio)"
	},
	# ========================================================================
	# EFFECTS/GORE RPCS
	# ========================================================================
	"spawn_blood_synced":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Spawn blood effect (server authority)"
	},
	"spawn_gore_effect":
	{
		"calls_per_second": 5.0,
		"requires_validation": false,
		"description": "Spawn gore effect on death (server authority)"
	},
	"spawn_explosion":
	{
		"calls_per_second": 5.0,
		"requires_validation": false,
		"description": "Spawn explosion effect (server authority)"
	},
	"spawn_explosion_mark":
	{
		"calls_per_second": 5.0,
		"requires_validation": false,
		"description": "Spawn explosion mark decal (server authority)"
	},
	"_client_show_alert":
	# ========================================================================
	# COMPONENT RPCS
	{"calls_per_second": 5.0, "requires_validation": false, "description": "Show AI alert icon"},
	# ========================================================================
	"_sync_effect_applied":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Sync status effect applied"
	},
	"_sync_effect_removed":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Sync status effect removed"
	},
	"_sync_effect_stack":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Sync effect stack count"
	},
	"_sync_effects_cleared":
	{
		"calls_per_second": 5.0,
		"requires_validation": false,
		"description": "Sync all effects cleared"
	},
	"_sync_health_state":
	{
		"calls_per_second": 10.0,
		"requires_validation": false,
		"description": "Sync health/armor state"
	},
	"_sync_heal_visual":
	{
		"calls_per_second": 5.0,
		"requires_validation": false,
		"description": "Sync heal visual effect"
	},
	"_sync_pain_state":
	# ========================================================================
	# ADMIN/UTILITY RPCS
	{"calls_per_second": 10.0, "requires_validation": false, "description": "Sync pain state"},
	# ========================================================================
	"kick_player":
	{
		"calls_per_second": 0.1,
		"requires_validation": false,
		"description": "Kick player (admin only)"
	},
	"verify_steam_ticket":
	{
		"calls_per_second": 0.5,
		"requires_validation": true,
		"validator_method": "_validate_steam_ticket",
		"description": "Verify Steam authentication ticket"
	},
	"sync_state_to_client":
	{
		"calls_per_second": 1.0,
		"requires_validation": false,
		"description": "Sync full state to reconnecting client"
	},
	# ========================================================================
	# DOWNED STATE RPCS (Critical #7 - Revive Exploit)
	# ========================================================================
	"request_revive":
	{
		"calls_per_second": 1.0,
		"requires_validation": true,
		"validator_method": "_validate_revive_request",
		"description": "Request revive downed player"
	},
	"request_revive_start":
	{
		"calls_per_second": 1.0,
		"requires_validation": true,
		"validator_method": "_validate_revive_request",
		"description": "Start revive process"
	},
	"_request_pickup_object":
	{
		"calls_per_second": 5.0,
		"requires_validation": true,
		"validator_method": "_validate_interaction_pickup",
		"description": "Request physics-object pickup"
	},
	"_request_throw_object":
	{
		"calls_per_second": 5.0,
		"requires_validation": true,
		"validator_method": "_validate_interaction_throw",
		"description": "Request held-object throw"
	},
	"request_revive_stop":
	{
		"calls_per_second": 5.0,
		"requires_validation": true,
		"validator_method": "_validate_target_player_rpc",
		"description": "Stop revive process"
	},
	"request_bleedout_immediate":
	{
		"calls_per_second": 1.0,
		"requires_validation": true,
		"validator_method": "_validate_target_player_rpc",
		"description": "Request immediate bleedout"
	},
}


## Check if RPC method is allowed
static func is_allowed(method: String) -> bool:
	return ALLOWED_RPCS.has(method)


## Get RPC configuration
static func get_config(method: String) -> Dictionary:
	return ALLOWED_RPCS.get(method, {})


## Get all allowed RPC methods
static func get_all_methods() -> Array[String]:
	var methods: Array[String] = []
	for method: String in ALLOWED_RPCS.keys():
		methods.append(method)
	return methods


## Get rate limit for method
static func get_rate_limit(method: String) -> float:
	var config: Dictionary = get_config(method)
	return config.get("calls_per_second", 1.0)


## Check if method requires validation
static func requires_validation(method: String) -> bool:
	var config: Dictionary = get_config(method)
	return config.get("requires_validation", false)


## Get validator method name
static func get_validator(method: String) -> String:
	var config: Dictionary = get_config(method)
	return config.get("validator_method", "")


## Print whitelist summary
static func print_summary() -> void:
	print("[RPCWhitelist] Allowed RPC Methods: %d" % ALLOWED_RPCS.size())
	print("[RPCWhitelist] Methods requiring validation:")
	for method: String in ALLOWED_RPCS.keys():
		var config: Dictionary = ALLOWED_RPCS[method]
		if config.get("requires_validation", false):
			print("  - %s (%.1f calls/sec)" % [method, config.get("calls_per_second", 1.0)])
