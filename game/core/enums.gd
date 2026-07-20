class_name Enums
extends Object

enum PlayerState { ALIVE, DEAD, DOWNED, SPECTATING, EDITING, AFK, MENU }


static func get_player_state_name(state: PlayerState) -> String:
	match state:
		PlayerState.ALIVE:
			return "ALIVE"
		PlayerState.DEAD:
			return "DEAD"
		PlayerState.DOWNED:
			return "DOWNED"
		PlayerState.SPECTATING:
			return "SPEC"
		PlayerState.EDITING:
			return "EDIT"
		PlayerState.AFK:
			return "AFK"
		PlayerState.MENU:
			return "MENU"
		_:
			return "UNKNOWN"
