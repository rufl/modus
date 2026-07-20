extends VBoxContainer


func _ready() -> void:
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		gs.match_service.kill_feed_updated.connect(_update_kill_feed)


func _exit_tree() -> void:
	# === SIGNAL HYGIENE ===
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		if gs.match_service.kill_feed_updated.is_connected(_update_kill_feed):
			gs.match_service.kill_feed_updated.disconnect(_update_kill_feed)


func _update_kill_feed() -> void:
	# Clear existing entries
	for child in get_children():
		child.queue_free()

	# Add current kill feed entries
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if not gs or not gs.match_service:
		return

	for entry: Dictionary in gs.match_service.kill_feed:
		var container: HBoxContainer = HBoxContainer.new()
		container.alignment = BoxContainer.ALIGNMENT_END
		add_child(container)

		# Valid Check
		if not entry.has("killer_id") or not entry.has("victim_id"):
			continue

		var killer_name: String = gs.match_service.get_player_name(entry["killer_id"])
		var victim_name: String = gs.match_service.get_player_name(entry["victim_id"])
		var weapon_id: String = entry.get("weapon_id", "")

		var my_id: int = multiplayer.get_unique_id()
		var p1_color: Color = Color.WHITE
		var p2_color: Color = Color.WHITE

		# Color logic
		if entry["killer_id"] == my_id:
			p1_color = Color.GREEN
		if entry["victim_id"] == my_id:
			p2_color = Color.RED

		# Suicide case
		if entry["killer_id"] == entry["victim_id"] or entry["killer_id"] == 0:
			var label: Label = Label.new()
			label.text = "%s died" % victim_name
			label.add_theme_color_override("font_color", p2_color)
			container.add_child(label)
		else:
			# Killer
			var l_killer: Label = Label.new()
			l_killer.text = killer_name
			l_killer.add_theme_color_override("font_color", p1_color)
			container.add_child(l_killer)

			# Weapon (Icon or Text)
			if weapon_id != "":
				var data_service: Node = GameManager.get_core_system("data")
				var w_data: Dictionary = (
					data_service.get_weapon_data(weapon_id) if data_service else {}
				)
				var icon_texture: Texture2D = null

				if w_data.has("icon") and ResourceLoader.exists(w_data.icon):
					icon_texture = load(w_data.icon)

				if icon_texture:
					var tex_rect: TextureRect = TextureRect.new()
					tex_rect.texture = icon_texture
					tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					tex_rect.custom_minimum_size = Vector2(24, 24)
					container.add_child(tex_rect)
				else:
					# Text Fallback
					var w_name: String = w_data.get("name", weapon_id)
					var l_weapon: Label = Label.new()
					l_weapon.text = "[%s]" % w_name
					l_weapon.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
					l_weapon.add_theme_font_size_override("font_size", 12)
					container.add_child(l_weapon)
			else:
				# Generic separator
				var l_sep: Label = Label.new()
				l_sep.text = "killed"
				l_sep.add_theme_color_override("font_color", Color.GRAY)
				container.add_child(l_sep)

			# Victim
			var l_victim: Label = Label.new()
			l_victim.text = victim_name
			l_victim.add_theme_color_override("font_color", p2_color)
			container.add_child(l_victim)
