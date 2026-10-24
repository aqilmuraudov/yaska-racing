class_name ResultsScreen
extends Control
## Post-race table: placement, times, best laps, DNF markers, reward and
## record feedback. Rewards are applied once per event (SaveManager ledger),
## so re-showing results never duplicates them.

var race: RaceManager
var panel: PanelContainer
var table: GridContainer
var summary: Label
var reward_label: Label
var retry_btn: Button


func setup(p_race: RaceManager) -> void:
	race = p_race
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.2)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	# Docked right so the winner's celebration stays visible on the left.
	var center := MarginContainer.new()
	center.anchor_left = 1.0
	center.anchor_right = 1.0
	center.anchor_top = 0.0
	center.anchor_bottom = 1.0
	center.offset_left = -740
	center.offset_right = 0
	center.offset_top = 0
	center.offset_bottom = 0
	center.add_theme_constant_override("margin_right", 24)
	center.add_theme_constant_override("margin_top", 24)
	center.add_theme_constant_override("margin_bottom", 24)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = tr("RESULTS_TITLE")
	title.theme_type_variation = &"Heading"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	summary = Label.new()
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_override("font", UITheme.heading_font())
	summary.add_theme_font_size_override("font_size", 40)
	summary.add_theme_constant_override("outline_size", 12)
	summary.add_theme_color_override("font_outline_color", UITheme.INK)
	v.add_child(summary)
	table = GridContainer.new()
	table.columns = 4
	table.add_theme_constant_override("h_separation", 26)
	table.add_theme_constant_override("v_separation", 4)
	v.add_child(table)
	reward_label = Label.new()
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_color_override("font_color", UITheme.GOLD)
	v.add_child(reward_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	retry_btn = Button.new()
	retry_btn.text = tr("RESULTS_RETRY")
	retry_btn.custom_minimum_size = Vector2(280, 74)
	UITheme.style_button(retry_btn, "yellow", 30)
	retry_btn.icon = UITheme.icon("restore")
	retry_btn.expand_icon = false
	retry_btn.add_theme_constant_override("icon_max_width", 34)
	retry_btn.pressed.connect(func():
		AudioManager.play_ui("ui_confirm")
		race.restart())
	row.add_child(retry_btn)
	var menu_btn := Button.new()
	menu_btn.text = tr("RESULTS_MENU")
	menu_btn.custom_minimum_size = Vector2(260, 74)
	UITheme.style_button(menu_btn, "blue", 26)
	menu_btn.pressed.connect(func():
		AudioManager.play_ui("ui_back")
		race.quit_to_menu())
	row.add_child(menu_btn)


static func place_text(place: int) -> String:
	return TranslationServer.translate("RESULTS_PLACE_%d" % clampi(place, 1, 8))


func show_results(res: Dictionary) -> void:
	for c in table.get_children():
		c.queue_free()
	for key in ["RESULTS_POSITION", "RESULTS_RACER", "RESULTS_TIME", "RESULTS_BEST_LAP"]:
		var h := Label.new()
		h.text = tr(key)
		h.theme_type_variation = &"Dim"
		table.add_child(h)
	for row in res.rows:
		var col := UITheme.GOLD if row.is_player else UITheme.TEXT
		_cell(place_text(row.place), col)
		var name_box := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = row.paint
		swatch.custom_minimum_size = Vector2(18, 18)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_box.add_child(swatch)
		var nl := Label.new()
		nl.text = row.name
		nl.add_theme_color_override("font_color", col)
		name_box.add_child(nl)
		table.add_child(name_box)
		_cell(RaceHUD.format_time(row.time) if row.finished else tr("RESULTS_DNF"), col)
		_cell(RaceHUD.format_time(row.best_lap) if row.best_lap > 0.0 else "--", col)
	var p: Dictionary = res.player
	summary.text = "%s: %s" % [tr("RESULTS_POSITION"), place_text(p.place)] if not p.is_empty() else ""
	var parts: Array[String] = []
	if res.get("improved", {}).get("lap", false) or res.get("improved", {}).get("race", false):
		parts.append(tr("HUD_NEW_RECORD"))
	if int(res.get("stars", 0)) > 0:
		parts.append("%s +%d" % [tr("RESULTS_STARS"), int(res.stars)])
	if int(res.get("reward", 0)) > 0:
		parts.append("%s: +%d %s" % [tr("RESULTS_REWARD"), int(res.reward), tr("RESULTS_COINS")])
	elif res.get("already_rewarded", false):
		parts.append(tr("RESULTS_ALREADY_REWARDED"))
	reward_label.text = "   ".join(parts)
	# A new paint unlocked by this race's stars: say so (cosmetic reward).
	var before := int(res.get("stars_total", 0))
	var after := before + int(res.get("stars_added", 0))
	for i in range(1, KartPaints.count()):
		if not KartPaints.is_unlocked(i, before) and KartPaints.is_unlocked(i, after):
			reward_label.text += "\n" + tr("RESULTS_PAINT_UNLOCKED") % tr(KartPaints.NAME_KEYS[i - 1])
	if not p.is_empty() and int(p.place) <= 3:
		summary.add_theme_color_override("font_color", [UITheme.YELLOW, Color("e3ecf7"), Color("ffad6b")][int(p.place) - 1])
	else:
		summary.add_theme_color_override("font_color", UITheme.TEXT)
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.4)
	# Finishing celebration: a short confetti of sparkles (not continuous).
	if not p.is_empty() and p.get("finished", true) and not bool(Settings.get_value("accessibility", "reduced_flashing", false)):
		tw.tween_callback(func():
			for k in 3:
				var at := summary.get_global_rect().get_center() + Vector2(randf_range(-200, 200), randf_range(-10, 30))
				UITheme.sparkle_burst(self, at, 7, [UITheme.YELLOW, UITheme.CORAL, UITheme.LIME][k]))
	retry_btn.grab_focus()


func _cell(text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	table.add_child(l)
