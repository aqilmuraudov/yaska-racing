class_name RaceHUD
extends CanvasLayer
## In-race interface. Keeps the centre of the screen clear; everything sits in
## the corners inside the device safe area (notches, rounded corners).

var race: RaceManager
var root: Control
var safe: MarginContainer
var pos_label: Label
var pos_total: Label
var lap_label: Label
var timer_label: Label
var best_label: Label
var item_panel: PanelContainer
var item_icon: ItemIcon
var minimap: MinimapWidget
var drift_meter: DriftMeterWidget
var countdown_label: Label
var message_label: Label
var speed_gauge: SpeedGauge
var star_pill: PanelContainer
var star_label: Label
var money_label: Label ## driving income this race (subtle)
var celebration: FinishCelebration
var replay_layer: Control ## 0.12.0 finish replay overlay
var replay_skip: Button
var tap_hint: TapHint
var rival_strip: RivalStrip ## 0.13.0 portraits of the racers just ahead / behind ## 0.12.0 wordless item hint on touch screens
## First quick race only: three short prompts (steer, drift, item).
var _hints_on := false
var _hint_step := 0
var speed_lines: SpeedLines
var _stuck_time := 0.0
var recover_bar: ProgressBar
var recover_label: Label
var wrong_way_label: Label
var pause_button: Button
var touch: TouchControls
var pause_menu: PauseMenu
var results: ResultsScreen
var _msg_time := 0.0
var _count_time := 0.0
var _last_item: StringName = &""
var _uses_touch := false
var speed_blur: ColorRect
var _blur := 0.0
var captions: VBoxContainer
var pos_badge: PanelContainer
var kids_badge: PanelContainer
var pos_arrow: Label
var lap_pill: PanelContainer
var trap_warning: Label
var _last_place := 0
var _place_flash := 0.0
var delta_pill: PanelContainer
var _tr_box: VBoxContainer
var delta_label: Label
var series_pill: PanelContainer
var _delta_timer := 0.0


func setup(p_race: RaceManager) -> void:
	race = p_race
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	speed_blur = ColorRect.new()
	speed_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speed_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blur_mat := ShaderMaterial.new()
	blur_mat.shader = preload("res://assets/materials/speed_blur.gdshader")
	speed_blur.material = blur_mat
	speed_blur.visible = false
	add_child(speed_blur)
	speed_lines = SpeedLines.new()
	speed_lines.kart = race.player.kart
	speed_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(speed_lines)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	safe = MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(safe)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_uses_touch = DisplayServer.is_touchscreen_available() or Settings.is_mobile() or DebugRunner.parse_args().has("touch")

	var accent: Color = race.player.kart.get_meta("paint", UITheme.TURQUOISE)

	# Upper left: race position badge (strong hierarchy, colour by place)
	pos_badge = PanelContainer.new()
	pos_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pos_badge.add_theme_stylebox_override("panel", UITheme.art_box("panel_hud", 18, 4, 30))
	frame.add_child(pos_badge)
	var pos_row := HBoxContainer.new()
	pos_row.add_theme_constant_override("separation", 2)
	pos_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pos_badge.add_child(pos_row)
	pos_label = _label("1", &"HudBig")
	pos_label.add_theme_font_size_override("font_size", 78)
	pos_row.add_child(pos_label)
	var total_box := MarginContainer.new()
	total_box.add_theme_constant_override("margin_top", 30)
	total_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pos_total = _label("/6", &"HudSmall")
	pos_total.add_theme_font_size_override("font_size", 28)
	total_box.add_child(pos_total)
	pos_row.add_child(total_box)
	pos_arrow = _label("", &"HudSmall")
	pos_arrow.add_theme_font_size_override("font_size", 30)
	pos_row.add_child(pos_arrow)

	# Kids controls badge (0.9.5): tells parents the kart drives itself.
	kids_badge = PanelContainer.new()
	kids_badge.name = "KidsBadge"
	# 0.14.3: hold for 1 s to drive yourself (a short tap does nothing, so a
	# small child does not switch it off by accident).
	kids_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	kids_badge.gui_input.connect(_on_kids_badge_input)
	kids_badge.add_theme_stylebox_override("panel", UITheme.rounded(Color(UITheme.YELLOW, 0.92), 16, 2, Color.WHITE, 8))
	kids_badge.position = Vector2(140, 68)
	kids_badge.visible = race.kids_mode()
	frame.add_child(kids_badge)
	var kb_row := HBoxContainer.new()
	kb_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kb_row.add_theme_constant_override("separation", 4)
	kids_badge.add_child(kb_row)
	var kb_icon := TextureRect.new()
	kb_icon.texture = UITheme.icon("kids_auto")
	kb_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	kb_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	kb_icon.custom_minimum_size = Vector2(34, 34)
	kb_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kb_row.add_child(kb_icon)
	var kb_label := _label(tr("HUD_KIDS_AUTO"), &"HudSmall")
	kb_label.add_theme_font_size_override("font_size", 22)
	kb_label.add_theme_color_override("font_color", UITheme.NAVY_DEEP)
	kb_label.add_theme_constant_override("outline_size", 0)
	kb_row.add_child(kb_label)

	# 0.13.0: who is just ahead / behind, as portraits, under the star pill.
	rival_strip = RivalStrip.new()
	rival_strip.name = "RivalStrip"
	rival_strip.position = Vector2(146, 82)
	frame.add_child(rival_strip)
	rival_strip.setup(race)
	# Stars collected this race, beside the position badge.
	star_pill = PanelContainer.new()
	star_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_pill.add_theme_stylebox_override("panel", UITheme.art_box("panel_hud", 14, 6, 30))
	star_pill.position = Vector2(140, 10)
	frame.add_child(star_pill)
	var star_row := HBoxContainer.new()
	star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_row.add_theme_constant_override("separation", 6)
	star_pill.add_child(star_row)
	var star_icon := TextureRect.new()
	star_icon.texture = UITheme.icon("star")
	star_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star_icon.custom_minimum_size = Vector2(40, 40)
	star_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_row.add_child(star_icon)
	star_label = _label("0", &"HudSmall")
	star_label.add_theme_font_size_override("font_size", 30)
	star_label.custom_minimum_size = Vector2(36, 0)
	star_row.add_child(star_label)
	var money_icon := TextureRect.new()
	money_icon.texture = UITheme.icon("manat")
	money_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	money_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	money_icon.custom_minimum_size = Vector2(34, 34)
	money_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_row.add_child(money_icon)
	money_label = _label(Money.format(0), &"HudSmall")
	money_label.add_theme_font_size_override("font_size", 22)
	money_label.add_theme_color_override("font_color", UITheme.YELLOW)
	star_row.add_child(money_label)

	# Upper right: lap pill, compact timer pill and the pause button
	var tr_box := VBoxContainer.new()
	_tr_box = tr_box
	tr_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr_box.add_theme_constant_override("separation", 4)
	frame.add_child(tr_box)
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_END
	top_row.add_theme_constant_override("separation", 10)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr_box.add_child(top_row)
	lap_pill = PanelContainer.new()
	lap_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lap_pill.add_theme_stylebox_override("panel", UITheme.art_box("panel_hud", 18, 6, 30))
	top_row.add_child(lap_pill)
	lap_label = _label("", &"HudSmall")
	lap_label.add_theme_font_size_override("font_size", 28)
	lap_pill.add_child(lap_label)
	var timer_pill := PanelContainer.new()
	timer_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_pill.add_theme_stylebox_override("panel", UITheme.art_box("panel_hud", 18, 6, 30))
	top_row.add_child(timer_pill)
	timer_label = _label("0:00.000", &"HudSmall")
	timer_label.add_theme_font_size_override("font_size", 26)
	timer_label.custom_minimum_size = Vector2(124, 0)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_pill.add_child(timer_label)
	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.custom_minimum_size = Vector2(72, 66)
	pause_button.focus_mode = Control.FOCUS_NONE
	UITheme.style_button(pause_button, "orange", 30)
	pause_button.pressed.connect(func(): race.set_paused(true))
	top_row.add_child(pause_button)
	best_label = _label("", &"Dim")
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr_box.add_child(best_label)
	# Rekord (0.10.0): live +/- against the best lap at the same point.
	delta_pill = PanelContainer.new()
	delta_pill.name = "DeltaPill"
	delta_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delta_pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	delta_pill.add_theme_stylebox_override("panel", UITheme.rounded(Color(UITheme.INK, 0.7), 22, 3, Color(1, 1, 1, 0.3), 10))
	delta_pill.visible = false
	tr_box.add_child(delta_pill)
	delta_label = _label("", &"HudSmall")
	delta_label.add_theme_font_size_override("font_size", 34)
	delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	delta_label.custom_minimum_size = Vector2(130, 0)
	delta_pill.add_child(delta_label)
	# Cup race number / today's challenge, small, under the timer.
	series_pill = GameUI.chip("trophy", "", 22, Color(UITheme.INK, 0.66), UITheme.YELLOW)
	series_pill.name = "SeriesPill"
	series_pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	series_pill.visible = false
	tr_box.add_child(series_pill)
	trap_warning = _label("! " + tr("HUD_TRAP_AHEAD"), &"HudSmall")
	trap_warning.add_theme_color_override("font_color", Color("ff6b6b"))
	trap_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trap_warning.visible = false
	tr_box.add_child(trap_warning)

	# Item slot for keyboard/controller play. With touch controls the ITEM
	# button itself is the slot (shows the item, roll and availability).
	item_panel = PanelContainer.new()
	item_panel.add_theme_stylebox_override("panel", UITheme.art_box("panel_hud", 12, 8, 30))
	item_panel.custom_minimum_size = Vector2(100, 100)
	item_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	item_panel.position = Vector2(-100, -160)
	frame.add_child(item_panel)
	item_icon = ItemIcon.new()
	item_icon.custom_minimum_size = Vector2(78, 78)
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_panel.add_child(item_icon)

	# Minimap: lower-left corner; with touch controls it sits above them.
	minimap = MinimapWidget.new()
	minimap.custom_minimum_size = Vector2(250, 180)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place_minimap(_uses_touch)
	frame.add_child(minimap)
	minimap.setup(race)

	# Centre texts
	countdown_label = _label("", &"Title")
	countdown_label.add_theme_font_size_override("font_size", 140)
	countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	countdown_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	countdown_label.pivot_offset = Vector2(150, 90)
	countdown_label.custom_minimum_size = Vector2(300, 180)
	countdown_label.position = Vector2(-150, -170)
	frame.add_child(countdown_label)
	# Wraps inside the space between the left (badge/minimap) and right HUD
	# columns, so long hints fit on 4:3 and 16:9 screens too.
	message_label = _label("", &"Heading")
	message_label.add_theme_font_size_override("font_size", 46)
	message_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	message_label.offset_left = 250
	message_label.offset_right = -250
	message_label.offset_top = 140
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(message_label)
	wrong_way_label = _label(tr("HUD_WRONG_WAY"), &"Heading")
	wrong_way_label.add_theme_font_size_override("font_size", 56)
	wrong_way_label.add_theme_color_override("font_color", Color("ff5a5a"))
	wrong_way_label.set_anchors_preset(Control.PRESET_CENTER)
	wrong_way_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrong_way_label.custom_minimum_size = Vector2(700, 80)
	wrong_way_label.position = Vector2(-350, -40)
	wrong_way_label.visible = false
	frame.add_child(wrong_way_label)

	# Bottom-centre: drift meter, recovery hold
	drift_meter = DriftMeterWidget.new()
	drift_meter.kart = race.player.kart
	drift_meter.custom_minimum_size = Vector2(300, 76)
	drift_meter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	drift_meter.position = Vector2(-150, -76 - 112.0) # just above the speedometer
	drift_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(drift_meter)
	recover_label = _label(tr("HUD_RECOVER_HOLD"), &"HudSmall")
	recover_label.set_anchors_preset(Control.PRESET_CENTER)
	recover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recover_label.custom_minimum_size = Vector2(400, 40)
	recover_label.position = Vector2(-200, 60)
	recover_label.visible = false
	frame.add_child(recover_label)
	recover_bar = ProgressBar.new()
	recover_bar.show_percentage = false
	recover_bar.max_value = 1.0
	recover_bar.custom_minimum_size = Vector2(240, 14)
	recover_bar.set_anchors_preset(Control.PRESET_CENTER)
	recover_bar.position = Vector2(-120, 104)
	recover_bar.visible = false
	frame.add_child(recover_bar)

	# Sound captions (accessibility) and item notices: top centre under the
	# message line, never over the minimap or the controls.
	captions = VBoxContainer.new()
	captions.set_anchors_preset(Control.PRESET_CENTER_TOP)
	captions.position = Vector2(-320, 268)
	captions.custom_minimum_size = Vector2(640, 0)
	captions.alignment = BoxContainer.ALIGNMENT_BEGIN
	captions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(captions)

	# Graphical speedometer, bottom centre between the thumb zones.
	speed_gauge = SpeedGauge.new()
	speed_gauge.kart = race.player.kart
	speed_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_gauge.custom_minimum_size = Vector2(180, 110)
	speed_gauge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	speed_gauge.position = Vector2(-90, -110) # dial centred; its readout pill draws to the right
	frame.add_child(speed_gauge)

	# Touch controls, pause menu and results
	touch = TouchControls.new()
	touch.name = "TouchControls"
	root.add_child(touch)
	touch.kids = race.kids_mode()
	touch.camera_low = String(race.config.get("mode", "")) == "time_trial"
	touch.setup(race.player.player_input)
	touch.visible = _uses_touch
	# The camera switch stays under the top-right column whatever it shows.
	tr_box.resized.connect(_sync_camera_slot)
	tr_box.item_rect_changed.connect(_sync_camera_slot)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	root.add_child(pause_menu)
	pause_menu.setup(race)
	celebration = FinishCelebration.new()
	celebration.name = "FinishCelebration"
	root.add_child(celebration)
	race.player_crossed_finish.connect(func(place: int):
		for w in [item_panel, drift_meter, trap_warning]:
			w.visible = false
		touch.release_all()
		touch.visible = false
		celebration.play(place))
	race.money_earned.connect(func(total: int, _gain: int, _kind: String):
		money_label.text = Money.format(total)
		money_label.pivot_offset = money_label.size * 0.5
		money_label.scale = Vector2.ONE * 1.25
		create_tween().tween_property(money_label, "scale", Vector2.ONE, 0.25))
	results = ResultsScreen.new()
	results.name = "Results"
	root.add_child(results)
	results.setup(race)

	race.countdown_tick.connect(_on_countdown)
	race.player_message.connect(func(k, kind): show_message(tr(k), kind, k == "HUD_START_BOOST"))
	race.lap_completed.connect(_on_lap)
	race.results_ready.connect(func(res):
		touch.release_all()
		touch.visible = false
		if _hints_on and not race.auto_drive():
			SaveManager.set_tutorial_flag("basics_done", true)
		for w in [pos_badge, star_pill, item_panel, minimap, drift_meter, speed_gauge, lap_pill, trap_warning, captions]:
			w.visible = false
		celebration.dismiss()
		results.show_results(res))
	race.state_changed.connect(_on_state)
	_build_replay_layer()
	race.replay_started.connect(_on_replay_started)
	race.replay_ended.connect(_on_replay_ended)
	if race.stars:
		race.stars.collected.connect(func(total: int):
			star_label.text = str(total)
			star_pill.pivot_offset = star_pill.size * 0.5
			star_pill.scale = Vector2.ONE * 1.25
			if not bool(Settings.get_value("accessibility", "reduced_flashing", false)):
				UITheme.sparkle_burst(star_pill, star_pill.get_global_rect().get_center(), 5, UITheme.YELLOW))
	var pk := race.player.kart
	pk.drift_boost.connect(func(tier, perfect):
		drift_meter.show_result(tr("HUD_PERFECT") if perfect else tr("HUD_BOOST"), true)
		if not bool(Settings.get_value("accessibility", "reduced_flashing", false)):
			UITheme.sparkle_burst(drift_meter, drift_meter.get_global_rect().get_center(), 9 if perfect else 5, UITheme.YELLOW if perfect else UITheme.TURQUOISE))
	pk.drift_miss.connect(func(): drift_meter.show_result(tr("HUD_MISS"), false))
	pk.drift_denied.connect(func(reason):
		drift_meter.show_result(tr("HUD_DRIFT_SPEED") if reason == &"speed" else tr("HUD_DRIFT_STEER"), false)
		if touch:
			touch.flash_denied())
	pk.respawned.connect(func(): caption(tr("HUD_PROTECTED")))
	pk.shield_blocked.connect(func(): show_message(tr("HUD_SHIELD_BLOCK"), "info"))
	pk.item_changed.connect(_on_item_changed)
	pk.got_hit.connect(func(_k): caption(tr("CAP_HIT")))
	pk.shield_blocked.connect(func(): caption(tr("CAP_SHIELD")))
	pk.boost_started.connect(_on_player_boost)
	race.near_miss.connect(func(_k):
		near_pops += 1
		show_message(tr("HUD_NEAR_MISS"), "good"))
	pk.wall_hit.connect(func(st): if st >= 0.6: caption(tr("CAP_WALL")))
	race.items.item_used.connect(func(k, it): if k == pk and it == &"trap": caption(tr("CAP_TRAP_DROP")))
	Settings.changed.connect(_on_settings_changed)
	Settings.changed.connect(func(section, key):
		if section == "gameplay" and key == "language":
			wrong_way_label.text = tr("HUD_WRONG_WAY")
			trap_warning.text = "! " + tr("HUD_TRAP_AHEAD")
			_update_static())
	_on_settings_changed("", "")
	reset()


func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _apply_safe_area() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var win_size := Vector2(DisplayServer.window_get_size())
	var safe_rect := Rect2(DisplayServer.get_display_safe_area())
	var scale := vp_size / win_size if win_size.x > 0 else Vector2.ONE
	var left := 18.0
	var right := 18.0
	var top := 14.0
	var bottom := 14.0
	if Settings.is_mobile() and safe_rect.size.x > 0:
		left = maxf(left, safe_rect.position.x * scale.x + 8.0)
		top = maxf(top, safe_rect.position.y * scale.y + 6.0)
		right = maxf(right, (win_size.x - safe_rect.end.x) * scale.x + 8.0)
		bottom = maxf(bottom, (win_size.y - safe_rect.end.y) * scale.y + 6.0)
	safe.add_theme_constant_override("margin_left", int(left))
	safe.add_theme_constant_override("margin_right", int(right))
	safe.add_theme_constant_override("margin_top", int(top))
	safe.add_theme_constant_override("margin_bottom", int(bottom))


func _on_settings_changed(_section: String, _key: String) -> void:
	speed_gauge.visible = bool(Settings.get_value("gameplay", "speedometer", true))
	drift_meter.high_contrast = bool(Settings.get_value("accessibility", "high_contrast", false))
	if touch:
		touch.apply_settings()


func reset() -> void:
	countdown_label.text = ""
	message_label.text = ""
	_msg_time = 0.0
	item_icon.item = &""
	item_icon.rolling = false
	results.visible = false
	pause_menu.visible = false
	_last_place = 0
	if touch:
		touch.visible = _uses_touch
	for w in [minimap, drift_meter, speed_gauge, captions]:
		w.visible = true
	item_panel.visible = not _uses_touch
	star_label.text = "0"
	money_label.text = Money.format(0)
	celebration.visible = false
	star_pill.visible = race.config.mode != "tutorial"
	_hints_on = race.config.mode == "quick" and not SaveManager.get_tutorial_flag("basics_done") and not race.kids_mode()
	_hint_step = 0
	_update_static()


func _update_static() -> void:
	var rec := SaveManager.get_record(race.config.track_id)
	if race.ghosts and race.ghosts.best_lap_ms() > 0:
		best_label.text = "%s %s" % [tr("BEST_LAP"), format_time(float(race.ghosts.best_lap_ms()) / 1000.0)]
	elif rec.has("best_lap_ms"):
		best_label.text = "%s %s" % [tr("BEST_LAP"), format_time(float(rec.best_lap_ms) / 1000.0)]
	else:
		best_label.text = ""
	if race.config.mode == "time_trial" and race.kids_mode():
		best_label.text = tr("TT_KIDS_NO_RECORD")
	var series := String(race.config.get("series", ""))
	series_pill.visible = series == "cup" or series == "daily"
	var sl: Label = series_pill.get_meta("value")
	if series == "cup":
		sl.text = tr("CUP_HUD_RACE") % [int(race.config.get("cup_race", 0)) + 1, BakuCup.RACES]
	elif series == "daily":
		var ic := series_pill.get_child(0).get_child(0) as TextureRect
		if ic:
			ic.texture = UITheme.icon("mode_daily")
		sl.text = DailyChallenge.text(DailyChallenge.effective(race.config.get("daily", {}), race.kids_mode()))


## "+0.42" / "−0.31" (seconds, two decimals).
static func format_delta(d: float) -> String:
	if absf(d) < 0.005:
		return "0.00" # dead even with the ghost: no sign
	return ("−" if d < 0.0 else "+") + "%.2f" % absf(d)


static func format_time(t: float) -> String:
	if t <= 0.0:
		return "--:--.---"
	var m := int(t / 60.0)
	var s := fmod(t, 60.0)
	return "%d:%06.3f" % [m, s]


## low = below the countdown / START gantry (turbo start pop, 0.9.2).
## Touch: under the position badge (the left steer buttons sit low);
## keyboard/pad: bottom-left corner.
func place_minimap(touch_layout: bool) -> void:
	var h := minimap.custom_minimum_size.y
	minimap.set_anchors_preset(Control.PRESET_TOP_LEFT if touch_layout else Control.PRESET_BOTTOM_LEFT)
	minimap.offset_left = 0.0
	minimap.offset_right = minimap.custom_minimum_size.x
	minimap.offset_top = 146.0 if touch_layout else -h
	minimap.offset_bottom = minimap.offset_top + h


func show_message(text: String, kind: String = "info", low := false) -> void:
	message_label.text = text
	message_label.offset_top = maxf(140.0, message_label.get_parent().size.y * 0.56) if low else 140.0
	var col := Color.WHITE
	match kind:
		"good":
			col = UITheme.YELLOW
			UITheme.sparkle_burst(message_label, message_label.get_global_rect().get_center(), 8)
		"bad": col = Color("ff8a8a")
	message_label.add_theme_color_override("font_color", col)
	_msg_time = 1.8
	message_label.scale = Vector2.ONE * 1.25
	message_label.pivot_offset = message_label.size * 0.5


func _on_countdown(value: int) -> void:
	countdown_label.text = str(value) if value > 0 else tr("HUD_GO")
	var cols := [UITheme.LIME, UITheme.YELLOW, UITheme.ORANGE, UITheme.CORAL]
	countdown_label.add_theme_color_override("font_color", cols[clampi(value, 0, 3)])
	countdown_label.add_theme_constant_override("outline_size", 24)
	if value == 0:
		UITheme.sparkle_burst(countdown_label, countdown_label.get_global_rect().get_center(), 10, UITheme.LIME)
	countdown_label.scale = Vector2.ONE * 1.5
	countdown_label.pivot_offset = countdown_label.size * 0.5
	_count_time = 0.9 if value > 0 else 0.8


func _on_lap(r, lap: int, lap_time: float) -> void:
	if r.is_player:
		var txt := "%s %d  %s" % [tr("HUD_LAP"), lap, format_time(lap_time)]
		var kind := "info"
		if race.ghosts and not is_nan(race.ghosts.last_lap_delta):
			txt += "  " + format_delta(race.ghosts.last_lap_delta)
			kind = "good" if race.ghosts.last_lap_delta < 0.0 else "info"
		show_message(txt, kind)
		_update_static.call_deferred()


func _on_state(s) -> void:
	if s == RaceManager.RaceState.COUNTDOWN:
		countdown_label.text = ""


func _on_player_boost(src: StringName) -> void:
	match src:
		&"pad":
			caption(tr("CAP_PAD"))
		&"landing":
			caption(tr("CAP_LANDING"))
		&"start":
			caption(tr("CAP_START"))
			flash(UITheme.YELLOW)


## Full-screen colour flash (turbo start); softer with Reduce Flashing.
var near_pops := 0
var flashes := 0
func flash(col: Color) -> void:
	flashes += 1
	var a := 0.16 if Settings.get_value("accessibility", "reduced_flashing", false) else 0.38
	var r := ColorRect.new()
	r.name = "Flash"
	r.color = Color(col, a)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(r)
	move_child(r, 0)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.45)
	tw.tween_callback(r.queue_free)


## Tiny "goal done" tick (0.9.0): a small lime badge that fades out.
var goal_ticks := 0
func goal_tick(text: String) -> void:
	goal_ticks += 1
	var b := GameUI.badge("✓ " + text, Color(UITheme.LIME.darkened(0.25), 0.92), 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.name = "GoalTick"
	captions.add_child(b)
	AudioManager.play_ui("ui_confirm")
	var tw := b.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(b, "modulate:a", 0.0, 0.4)
	tw.tween_callback(b.queue_free)


func caption(text: String) -> void:
	if not bool(Settings.get_value("accessibility", "subtitles", true)):
		return
	var l := _label(text, &"HudSmall")
	l.add_theme_font_size_override("font_size", 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	captions.add_child(l)
	while captions.get_child_count() > 2:
		var oldest := captions.get_child(0)
		captions.remove_child(oldest)
		oldest.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


## 0.12.0: the new item as a small picture pill (item icon + its name)
## instead of the bracketed "[Əşya: …]" text line.
func item_caption(it: StringName) -> void:
	if not bool(Settings.get_value("accessibility", "subtitles", true)):
		return
	var names := {&"turbo": "ITEM_TURBO", &"shield": "ITEM_SHIELD", &"trap": "ITEM_TRAP"}
	var pill := PanelContainer.new()
	pill.name = "ItemCaption"
	pill.add_theme_stylebox_override("panel", UITheme.rounded(Color(UITheme.INK, 0.78), 36, 3, Color(1, 1, 1, 0.3), 6))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(h)
	var ic := ItemIcon.new()
	ic.item = it
	ic.custom_minimum_size = Vector2(44, 44)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var l := GameUI.label(tr(names.get(it, "")), 24, UITheme.YELLOW, 6)
	h.add_child(l)
	captions.add_child(pill)
	while captions.get_child_count() > 2:
		var oldest := captions.get_child(0)
		captions.remove_child(oldest)
		oldest.queue_free()
	pill.pivot_offset = Vector2(110, 26)
	pill.scale = Vector2.ONE * 0.6
	var tw := pill.create_tween()
	tw.tween_property(pill, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.8)
	tw.tween_property(pill, "modulate:a", 0.0, 0.4)
	tw.tween_callback(pill.queue_free)


func _on_item_changed(it: StringName) -> void:
	if it == &"?rolling":
		item_icon.rolling = true
		item_icon.item = &""
	else:
		var was_rolling := item_icon.rolling
		item_icon.rolling = false
		item_icon.item = it
		if it != &"" and _last_item == &"":
			item_panel.scale = Vector2.ONE * 1.2
		if it != &"" and was_rolling:
			item_caption(it)
		if it == &"" and is_instance_valid(tap_hint):
			tap_hint.dismiss() # used: the hand goes away
	_last_item = it if it != &"?rolling" else _last_item


## The steering hint waits until the big START! has faded (and any
## TURBO START message is gone) so the two never overlap (0.10.0).
static func steer_hint_ready(t: float, countdown_text: String, msg_time: float) -> bool:
	return t > 0.6 and countdown_text == "" and msg_time <= 0.0


## First-race prompts, each once: steer at the start, drift on the first
## long straight-to-corner, the item button when the first item arrives.
func _tick_hints() -> void:
	var t := race.race_time
	var p := race.player
	if _hint_step == 0 and steer_hint_ready(t, countdown_label.text, _msg_time):
		_hint_step = 1
		_msg_time = 3.0
		if not show_tap_hint(["steer_left", "steer_right"], "alternate", 3.0): # 0.13.0 wordless
			show_message(tr("HINT_STEER"), "info")
	elif _hint_step == 1 and t > 9.0:
		_hint_step = 2
		_msg_time = 3.5
		if not show_tap_hint("drift", "hold", 4.0): # 0.13.0: hold, then let go
			show_message(tr("HINT_DRIFT"), "info")
	elif _hint_step == 2 and p.kart.item != &"" and p.kart.item_roll_timer <= 0.0:
		_hint_step = 3
		if not show_tap_hint("item"):
			show_message(tr("HINT_ITEM"), "info")
			_msg_time = 3.0


## 0.12.0: on touch screens a pulsing ring + tapping hand on the button
## replaces the sentence. Returns false when there is no such button shown.
func show_tap_hint(ids, mode := "tap", duration := 3.2) -> bool:
	if touch == null or not touch.visible:
		return false
	var id_list: Array = ids if ids is Array else [ids]
	var to_root := root.get_global_transform().affine_inverse() * touch.get_global_transform()
	var sc := touch.get_global_transform().get_scale().x
	var tgs: Array = []
	for id in id_list:
		var b = touch.get_button(String(id))
		if b == null or not b.visible:
			return false
		tgs.append([to_root * b.center, b.radius * sc])
	if is_instance_valid(tap_hint):
		tap_hint.queue_free()
	tap_hint = TapHint.new()
	tap_hint.name = "TapHint"
	tap_hint.mode = mode
	tap_hint.duration = duration
	tap_hint.targets = tgs
	tap_hint.target = tgs[0][0]
	tap_hint.radius = tgs[0][1]
	root.add_child(tap_hint)
	return true


func show_pause(on: bool) -> void:
	pause_menu.open(on)
	if touch:
		touch.release_all()
		touch.visible = _uses_touch and not on


func release_touches() -> void:
	if touch:
		touch.release_all()


var _kids_hold := -1.0
const KIDS_HOLD := 1.0


func _on_kids_badge_input(e: InputEvent) -> void:
	if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.is_pressed():
		_kids_hold = 0.0
	elif (e is InputEventScreenTouch or e is InputEventMouseButton) and not e.is_pressed():
		_kids_hold = -1.0
		kids_badge.modulate = Color.WHITE


## Hold reached: Kids controls off for this race and in Settings.
func turn_off_kids_mode() -> void:
	_kids_hold = -1.0
	race.set_kids_mode(false)
	Settings.set_value("controls", "kids_auto", false)
	kids_badge.visible = false
	kids_badge.modulate = Color.WHITE
	touch.kids = false
	touch._layout()
	AudioManager.play_ui("ui_confirm")


func _process(delta: float) -> void:
	if _kids_hold >= 0.0:
		_kids_hold += delta
		kids_badge.modulate = Color.WHITE.lerp(Color(0.6, 1.0, 0.6), minf(_kids_hold / KIDS_HOLD, 1.0))
		if _kids_hold >= KIDS_HOLD:
			turn_off_kids_mode()
	if touch and race.nitro:
		if touch.nitro_level != race.nitro.level:
			touch.nitro_level = race.nitro.level
			touch.apply_settings()
		touch.nitro_charge = race.nitro.charge
	if race == null or race.player == null:
		return
	var p := race.player
	var mode: String = race.config.mode
	var in_results := race.state == RaceManager.RaceState.RESULTS
	pos_badge.visible = mode == "quick" and not in_results
	rival_strip.visible = mode == "quick" and not in_results and not p.tracker.finished
	lap_pill.visible = mode != "tutorial" and not in_results
	if p.place != _last_place:
		if _last_place != 0 and race.state == RaceManager.RaceState.RACING:
			var up := p.place < _last_place
			pos_arrow.text = "▲" if up else "▼"
			pos_arrow.add_theme_color_override("font_color", Color("5cf08a") if up else Color("ff7070"))
			_place_flash = 1.2
			pos_badge.pivot_offset = pos_badge.size * 0.5
			pos_badge.scale = Vector2.ONE * 1.25
			if up:
				UITheme.sparkle_burst(pos_badge, pos_badge.get_global_rect().get_center(), 7, UITheme.YELLOW)
				AudioManager.play("overtake", -4.0)
		_last_place = p.place
		# Gold / silver / bronze numerals for the podium, white otherwise.
		var place_cols := [UITheme.YELLOW, Color("e3ecf7"), Color("ffad6b")]
		var pc: Color = place_cols[p.place - 1] if p.place <= 3 else Color.WHITE
		pos_label.add_theme_color_override("font_color", pc)
	if _place_flash > 0.0:
		_place_flash -= delta
		if _place_flash <= 0.0:
			pos_arrow.text = ""
	pos_badge.scale = pos_badge.scale.lerp(Vector2.ONE, 1.0 - exp(-8.0 * delta))
	star_pill.scale = star_pill.scale.lerp(Vector2.ONE, 1.0 - exp(-8.0 * delta))
	if _hints_on and race.state == RaceManager.RaceState.RACING:
		_tick_hints()
	_delta_timer -= delta
	if _delta_timer <= 0.0:
		_delta_timer = 0.2
		_update_delta()
	trap_warning.visible = race.state == RaceManager.RaceState.RACING and race.items.threat_near(p.kart)
	pos_label.text = str(p.place)
	pos_total.text = "/%d" % race.racers.size()
	lap_label.text = "%s %d/%d" % [tr("HUD_LAP"), p.tracker.current_lap(), int(race.config.laps)]
	var t := race.race_time
	if p.tracker.finished:
		t = p.tracker.finish_time
	timer_label.text = format_time(maxf(t, 0.0001)) if race.state != RaceManager.RaceState.COUNTDOWN and race.state != RaceManager.RaceState.INTRO else "0:00.000"
	# Recover button only when it helps: stuck for a moment, or wrong way.
	var racing := race.state == RaceManager.RaceState.RACING
	if racing and not p.kart.controls_locked and absf(p.kart.speed) < 2.5 and p.kart.state != KartController.State.RECOVER:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	if touch:
		touch.show_recover = racing and (_stuck_time > 1.2 or p.tracker.wrong_way)
	wrong_way_label.visible = p.tracker.wrong_way and race.state == RaceManager.RaceState.RACING
	var hold := p.player_input.recover_hold_progress() if p.player_input else 0.0
	var recovering := p.kart.state == KartController.State.RECOVER
	recover_label.visible = hold > 0.0 or recovering
	recover_label.text = tr("HUD_RECOVERING") if recovering else tr("HUD_RECOVER_HOLD")
	recover_bar.visible = hold > 0.0
	recover_bar.value = hold
	# Animations
	if _count_time > 0.0:
		_count_time -= delta
		countdown_label.scale = countdown_label.scale.lerp(Vector2.ONE, 1.0 - exp(-10.0 * delta))
		if _count_time <= 0.0:
			countdown_label.text = ""
	if _msg_time > 0.0:
		_msg_time -= delta
		message_label.scale = message_label.scale.lerp(Vector2.ONE, 1.0 - exp(-10.0 * delta))
		message_label.modulate.a = clampf(_msg_time * 2.0, 0.0, 1.0)
		if _msg_time <= 0.0:
			message_label.text = ""
	item_panel.scale = item_panel.scale.lerp(Vector2.ONE, 1.0 - exp(-8.0 * delta))
	item_panel.pivot_offset = item_panel.size * 0.5
	# Optional speed blur while boosting.
	var want_blur := bool(Settings.get_value("graphics", "motion_blur", false)) and not bool(Settings.get_value("accessibility", "reduced_flashing", false))
	var target_blur := 0.0
	if want_blur and p.kart.boost.is_active() and race.state == RaceManager.RaceState.RACING:
		target_blur = clampf(p.kart.speed / p.kart.stats.top_speed - 0.85, 0.0, 0.5) * 2.0
	_blur = lerpf(_blur, target_blur, 1.0 - exp(-6.0 * delta))
	speed_blur.visible = _blur > 0.02
	if speed_blur.visible:
		(speed_blur.material as ShaderMaterial).set_shader_parameter("strength", _blur)
	var shield_on := p.kart.has_shield()
	item_panel.modulate = Color(0.75, 0.95, 1.0) if shield_on else Color.WHITE


func _sync_camera_slot() -> void:
	if touch and is_instance_valid(_tr_box):
		touch.set_camera_min_y(_tr_box.get_global_rect().end.y - touch.get_global_rect().position.y)


func _update_delta() -> void:
	var d := race.ghosts.live_delta() if race.ghosts else NAN
	delta_pill.visible = not is_nan(d) and not race.player.tracker.finished
	if delta_pill.visible:
		delta_label.text = format_delta(d)
		delta_label.add_theme_color_override("font_color", Color.WHITE if absf(d) < 0.005 else (Color("6dff8f") if d < 0.0 else Color("ff8080")))


## 0.12.0 finish replay: cinema bars, a small "replay" badge (icon + one
## word) and one big skip button. The race HUD and celebration hide.
func _build_replay_layer() -> void:
	replay_layer = Control.new()
	replay_layer.name = "ReplayLayer"
	replay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	replay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replay_layer.visible = false
	add_child(replay_layer)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.name = "BarTop" if top else "BarBottom"
		bar.color = Color(0, 0, 0, 0.88)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.anchor_bottom = 0.1 if top else 1.0
		bar.anchor_top = 0.0 if top else 0.9
		bar.offset_top = 0
		bar.offset_bottom = 0
		replay_layer.add_child(bar)
	var badge := GameUI.chip("restore", tr("REPLAY_BADGE"), 26, Color("e8384f", 0.9), Color.WHITE)
	badge.name = "ReplayBadge"
	badge.anchor_top = 0.1
	badge.anchor_bottom = 0.1
	badge.offset_left = 28
	badge.offset_top = 16
	replay_layer.add_child(badge)
	replay_skip = Button.new()
	replay_skip.name = "ReplaySkip"
	replay_skip.text = tr("REPLAY_SKIP")
	replay_skip.icon = UITheme.icon("play")
	replay_skip.expand_icon = false
	replay_skip.focus_mode = Control.FOCUS_NONE
	replay_skip.custom_minimum_size = Vector2(196, 84)
	UITheme.style_button(replay_skip, "orange", 34)
	replay_skip.add_theme_constant_override("icon_max_width", 40)
	replay_skip.add_theme_constant_override("h_separation", 10)
	# Bottom-right, above the lower cinema bar (10 % of the height).
	replay_skip.anchor_left = 1.0
	replay_skip.anchor_right = 1.0
	replay_skip.anchor_top = 0.9
	replay_skip.anchor_bottom = 0.9
	replay_skip.offset_left = -236
	replay_skip.offset_right = -40
	replay_skip.offset_top = -104
	replay_skip.offset_bottom = -20
	replay_skip.pressed.connect(func(): race.skip_replay())
	replay_layer.add_child(replay_skip)


func _on_replay_started(_kart: Node3D) -> void:
	safe.visible = false
	touch.release_all()
	touch.visible = false
	celebration.dismiss()
	replay_layer.visible = true
	replay_layer.modulate.a = 0.0
	create_tween().tween_property(replay_layer, "modulate:a", 1.0, 0.3)
	replay_skip.pivot_offset = replay_skip.custom_minimum_size * 0.5
	var tw := replay_skip.create_tween().set_loops(0)
	tw.tween_property(replay_skip, "scale", Vector2.ONE * 1.06, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(replay_skip, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	replay_skip.set_meta("pulse", tw)


func _on_replay_ended() -> void:
	replay_layer.visible = false
	safe.visible = true
	var tw = replay_skip.get_meta("pulse", null)
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()
	replay_skip.scale = Vector2.ONE

