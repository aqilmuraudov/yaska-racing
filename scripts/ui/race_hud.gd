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
var speed_label: Label
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


func setup(p_race: RaceManager) -> void:
	race = p_race
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	safe = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(safe)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_uses_touch = DisplayServer.is_touchscreen_available() or Settings.is_mobile()

	# Top-left: position and lap
	var tl := VBoxContainer.new()
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.position = Vector2(0, 0)
	tl.add_theme_constant_override("separation", -8)
	frame.add_child(tl)
	var pos_row := HBoxContainer.new()
	pos_row.add_theme_constant_override("separation", 2)
	tl.add_child(pos_row)
	pos_label = _label("1", &"HudBig")
	pos_label.add_theme_font_size_override("font_size", 76)
	pos_row.add_child(pos_label)
	pos_total = _label("/6", &"HudSmall")
	pos_total.size_flags_vertical = Control.SIZE_SHRINK_END
	pos_total.add_theme_font_size_override("font_size", 30)
	pos_row.add_child(pos_total)
	lap_label = _label("", &"HudSmall")
	lap_label.add_theme_font_size_override("font_size", 30)
	tl.add_child(lap_label)

	# Top-centre: item slot
	item_panel = PanelContainer.new()
	item_panel.theme_type_variation = &"HudPill"
	item_panel.custom_minimum_size = Vector2(104, 104)
	item_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	item_panel.position = Vector2(-52, 0)
	item_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(item_panel)
	item_icon = ItemIcon.new()
	item_icon.custom_minimum_size = Vector2(80, 80)
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_panel.add_child(item_icon)

	# Top-right: timer, best lap, minimap
	var tr_box := VBoxContainer.new()
	tr_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	tr_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr_box.add_theme_constant_override("separation", 2)
	frame.add_child(tr_box)
	var timer_row := HBoxContainer.new()
	timer_row.alignment = BoxContainer.ALIGNMENT_END
	timer_row.add_theme_constant_override("separation", 12)
	tr_box.add_child(timer_row)
	timer_label = _label("0:00.000", &"HudSmall")
	timer_label.add_theme_font_size_override("font_size", 34)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_row.add_child(timer_label)
	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.custom_minimum_size = Vector2(64, 56)
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.pressed.connect(func(): race.set_paused(true))
	timer_row.add_child(pause_button)
	best_label = _label("", &"Dim")
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr_box.add_child(best_label)
	minimap = MinimapWidget.new()
	minimap.custom_minimum_size = Vector2(230, 170)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr_box.add_child(minimap)
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
	message_label = _label("", &"Heading")
	message_label.add_theme_font_size_override("font_size", 52)
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.custom_minimum_size = Vector2(700, 80)
	message_label.position = Vector2(-350, 150)
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
	drift_meter.custom_minimum_size = Vector2(380, 84)
	drift_meter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	drift_meter.position = Vector2(-190, -84 - (150.0 if _uses_touch else 40.0))
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

	speed_label = _label("", &"HudSmall")
	speed_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	speed_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.custom_minimum_size = Vector2(200, 40)
	speed_label.position = Vector2(-200, -40 - (250.0 if _uses_touch else 0.0))
	frame.add_child(speed_label)

	# Touch controls, pause menu and results
	touch = TouchControls.new()
	touch.name = "TouchControls"
	root.add_child(touch)
	touch.setup(race.player.player_input)
	touch.visible = _uses_touch
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	root.add_child(pause_menu)
	pause_menu.setup(race)
	results = ResultsScreen.new()
	results.name = "Results"
	root.add_child(results)
	results.setup(race)

	race.countdown_tick.connect(_on_countdown)
	race.player_message.connect(func(k, kind): show_message(tr(k), kind))
	race.lap_completed.connect(_on_lap)
	race.results_ready.connect(func(res):
		touch.release_all()
		touch.visible = false
		results.show_results(res))
	race.state_changed.connect(_on_state)
	var pk := race.player.kart
	pk.drift_boost.connect(func(tier, perfect): drift_meter.show_result(tr("HUD_PERFECT") if perfect else tr("HUD_BOOST"), true))
	pk.drift_miss.connect(func(): drift_meter.show_result(tr("HUD_MISS"), false))
	pk.shield_blocked.connect(func(): show_message(tr("HUD_SHIELD_BLOCK"), "info"))
	pk.item_changed.connect(_on_item_changed)
	Settings.changed.connect(_on_settings_changed)
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
	speed_label.visible = bool(Settings.get_value("gameplay", "speedometer", true))
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
	if touch:
		touch.visible = _uses_touch
	_update_static()


func _update_static() -> void:
	var rec := SaveManager.get_record(race.config.track_id)
	if race.ghosts and race.ghosts.best_lap_ms() > 0:
		best_label.text = "%s %s" % [tr("BEST_LAP"), format_time(float(race.ghosts.best_lap_ms()) / 1000.0)]
	elif rec.has("best_lap_ms"):
		best_label.text = "%s %s" % [tr("BEST_LAP"), format_time(float(rec.best_lap_ms) / 1000.0)]
	else:
		best_label.text = ""


static func format_time(t: float) -> String:
	if t <= 0.0:
		return "--:--.---"
	var m := int(t / 60.0)
	var s := fmod(t, 60.0)
	return "%d:%06.3f" % [m, s]


func show_message(text: String, kind: String = "info") -> void:
	message_label.text = text
	var col := Color.WHITE
	match kind:
		"good": col = UITheme.GOLD
		"bad": col = Color("ff8a8a")
	message_label.add_theme_color_override("font_color", col)
	_msg_time = 1.8
	message_label.scale = Vector2.ONE * 1.25
	message_label.pivot_offset = message_label.size * 0.5


func _on_countdown(value: int) -> void:
	countdown_label.text = str(value) if value > 0 else tr("HUD_GO")
	countdown_label.add_theme_color_override("font_color", UITheme.GOLD if value == 0 else Color.WHITE)
	countdown_label.scale = Vector2.ONE * 1.5
	countdown_label.pivot_offset = countdown_label.size * 0.5
	_count_time = 0.9 if value > 0 else 0.8


func _on_lap(r, lap: int, lap_time: float) -> void:
	if r.is_player:
		show_message("%s %d  %s" % [tr("HUD_LAP"), lap, format_time(lap_time)], "info")


func _on_state(s) -> void:
	if s == RaceManager.RaceState.COUNTDOWN:
		countdown_label.text = ""


func _on_item_changed(it: StringName) -> void:
	if it == &"?rolling":
		item_icon.rolling = true
		item_icon.item = &""
	else:
		item_icon.rolling = false
		item_icon.item = it
		if it != &"" and _last_item == &"":
			item_panel.scale = Vector2.ONE * 1.2
	_last_item = it if it != &"?rolling" else _last_item


func show_pause(on: bool) -> void:
	pause_menu.open(on)
	if touch:
		touch.release_all()
		touch.visible = _uses_touch and not on


func release_touches() -> void:
	if touch:
		touch.release_all()


func _process(delta: float) -> void:
	if race == null or race.player == null:
		return
	var p := race.player
	var mode: String = race.config.mode
	pos_label.get_parent().visible = mode == "quick"
	lap_label.visible = mode != "tutorial"
	pos_label.text = str(p.place)
	pos_total.text = "/%d" % race.racers.size()
	lap_label.text = "%s %d/%d" % [tr("HUD_LAP"), p.tracker.current_lap(), int(race.config.laps)]
	var t := race.race_time
	if p.tracker.finished:
		t = p.tracker.finish_time
	timer_label.text = format_time(t) if race.state != RaceManager.RaceState.COUNTDOWN and race.state != RaceManager.RaceState.INTRO else format_time(0.0).replace("-", "0")
	speed_label.text = "%d %s" % [int(absf(p.kart.speed) * 3.6), tr("HUD_KMH")]
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
	var shield_on := p.kart.has_shield()
	item_panel.modulate = Color(0.75, 0.95, 1.0) if shield_on else Color.WHITE
