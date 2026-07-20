extends PanelContainer

const DEFAULT_STATUS_COLORS: Dictionary = {
	"Alive": Color(0.3, 1.0, 0.3),
	"Dead": Color(1.0, 0.3, 0.3),
	"Spectating": Color(0.7, 0.7, 0.7),
	"Connecting": Color(1.0, 1.0, 0.3),
}

var container: VBoxContainer = null

var _status_colors: Dictionary = {}
var _local_player_color: Color = Color(0.4, 0.8, 1.0)
var _kills_color: Color = Color(0.3, 1.0, 0.3)
var _deaths_color: Color = Color(1.0, 0.3, 0.3)
var _highlight_local: bool = true


func _ready() -> void:
	# Try to find required nodes
	container = get_node_or_null("%ScoreContainer")

	if not container:
		push_warning("[Scoreboard] %ScoreContainer not found - scoreboard will not work")

	hide()
	_load_config()

	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		gs.match_service.scores_updated.connect(_update_scoreboard)

	# Listen for config reloads
	var cfg: Node = GameManager.get_core_system("config")
	if cfg:
		cfg.config_reloaded.connect(_load_config)


func _exit_tree() -> void:
	# === SIGNAL HYGIENE ===
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service and gs.match_service.scores_updated.is_connected(_update_scoreboard):
		gs.match_service.scores_updated.disconnect(_update_scoreboard)
	var cfg: Node = GameManager.get_core_system("config")
	if cfg and cfg.config_reloaded.is_connected(_load_config):
		cfg.config_reloaded.disconnect(_load_config)


func _load_config(_file_path: String = "") -> void:
	var cfg: Node = GameManager.get_core_system("config")
	if not cfg:
		_status_colors = DEFAULT_STATUS_COLORS.duplicate()
		return

	# Load status colors
	var colors_cfg: Dictionary = cfg.get_value("visuals.scoreboard.status_colors", {})
	_status_colors.clear()

	for status: String in colors_cfg:
		var c: Dictionary = colors_cfg[status]
		_status_colors[status] = Color(c.get("r", 1.0), c.get("g", 1.0), c.get("b", 1.0))

	# Fill in any missing defaults
	for status: String in DEFAULT_STATUS_COLORS:
		if not _status_colors.has(status):
			_status_colors[status] = DEFAULT_STATUS_COLORS[status]

	# Load local player highlight color
	var lpc: Dictionary = cfg.get_value("visuals.scoreboard.local_player_color", {})
	if not lpc.is_empty():
		_local_player_color = Color(lpc.get("r", 0.4), lpc.get("g", 0.8), lpc.get("b", 1.0))

	_highlight_local = cfg.get_value("visuals.scoreboard.highlight_local_player", true)

	# Load kills/deaths colors
	var kc: Dictionary = cfg.get_value("visuals.scoreboard.kills_color", {})
	if not kc.is_empty():
		_kills_color = Color(kc.get("r", 0.3), kc.get("g", 1.0), kc.get("b", 0.3))

	var dc: Dictionary = cfg.get_value("visuals.scoreboard.deaths_color", {})
	if not dc.is_empty():
		_deaths_color = Color(dc.get("r", 1.0), dc.get("g", 0.3), dc.get("b", 0.3))


func _process(_delta: float) -> void:
	# Show/hide scoreboard based on Tab key
	if Input.is_action_pressed("scoreboard"):
		if not visible:
			_update_scoreboard()
			show()
	else:
		hide()


func _update_scoreboard() -> void:
	# Null safety check
	if not container:
		# Already warned in _ready, just return cleanly
		return

	# Clear existing entries
	for child in container.get_children():
		child.queue_free()

	# Get sorted scores from MatchSvc
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if not gs or not gs.match_service:
		return

	var scores: Array = (gs.match_service as MatchSvc).get_sorted_scores()

	# Add local player if not in list yet (e.g. just joined)
	var my_id: int = multiplayer.get_unique_id()
	var found_self: bool = false
	for entry: Dictionary in scores:
		if entry["peer_id"] == my_id:
			found_self = true
			break

	if not found_self and my_id != 0:
		var player_name: String = "Unknown"
		if gs and gs.match_service:
			player_name = gs.match_service.get_player_name(my_id)

		scores.append(
			{
				"peer_id": my_id,
				"name": player_name,
				"kills": 0,
				"deaths": 0,
				"health": 100,
				"state": Enums.PlayerState.ALIVE
			}
		)

	# Create score entries
	for entry: Dictionary in scores:
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Player name
		var name_label: Label = Label.new()
		name_label.text = entry["name"]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Highlight local player
		if _highlight_local and entry["peer_id"] == my_id:
			name_label.add_theme_color_override("font_color", _local_player_color)

		# Kills
		var kills_label: Label = Label.new()
		kills_label.text = str(entry["kills"])
		kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kills_label.custom_minimum_size.x = 50
		kills_label.add_theme_color_override("font_color", _kills_color)

		# Deaths
		var deaths_label: Label = Label.new()
		deaths_label.text = str(entry["deaths"])
		deaths_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		deaths_label.custom_minimum_size.x = 50
		deaths_label.add_theme_color_override("font_color", _deaths_color)

		# Status/Health
		var _health_str: String = str(entry.get("health", 100)) + "%"
		var state_enum: int = entry.get("state", Enums.PlayerState.ALIVE)
		var status: String = Enums.get_player_state_name(state_enum)

		# Check if dead, spectating, editing, or afk
		if (
			state_enum == Enums.PlayerState.DEAD
			or state_enum == Enums.PlayerState.SPECTATING
			or state_enum == Enums.PlayerState.EDITING
			or state_enum == Enums.PlayerState.AFK
		):
			_health_str = "-"

		var status_label: Label = Label.new()
		status_label.text = status
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Apply status color from config
		if _status_colors.has(status):
			status_label.add_theme_color_override("font_color", _status_colors[status])

		row.add_child(name_label)
		row.add_child(kills_label)
		row.add_child(deaths_label)
		row.add_child(status_label)
		container.add_child(row)
