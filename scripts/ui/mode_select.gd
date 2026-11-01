extends MenuScreen
## Mode selection (0.10.0): four big cards — Sərbəst yarış, Bakı Kuboku,
## Rekord, Gündəlik tapşırıq — each with one short live status chip (cup
## race, best lap, today's goal / done). Drift School sits below as a
## smaller button.

const MODES := [
	{"id": "quick", "title": "MODE_QUICK", "desc": "MODE_QUICK_DESC", "color": Color("e0344b"), "icon": "mode_quick"},
	{"id": "cup", "title": "MODE_CUP", "desc": "MODE_CUP_DESC", "color": Color("ffb321"), "icon": "trophy"},
	{"id": "time_trial", "title": "MODE_TIME_TRIAL", "desc": "MODE_TIME_TRIAL_DESC", "color": Color("25c2c2"), "icon": "mode_time"},
	{"id": "daily", "title": "MODE_DAILY", "desc": "MODE_DAILY_DESC", "color": Color("8b6bff"), "icon": "mode_daily"},
]

var _first: Button
var cards := {} ## id -> Button (tests)
var status_chips := {} ## id -> PanelContainer
var school_btn: Button
var lesson_btn: Button ## 0.13.0


func _init() -> void:
	back_state = Game.State.MAIN_MENU
	screen_title_key = "MODE_TITLE"


## One-line status per card: [text, colour, icon] or [] for none.
static func status_for(id: String, data: Dictionary, today: String) -> Array:
	match id:
		"cup":
			var cup := BakuCup.current(data)
			if cup.is_empty():
				return [TranslationServer.translate("CUP_CARD_PRIZE") % Money.format(BakuCup.PRIZE[0]), UITheme.YELLOW, "manat"]
			if BakuCup.is_complete(cup):
				return [TranslationServer.translate("CUP_CARD_PODIUM"), UITheme.YELLOW, "trophy"]
			return [TranslationServer.translate("CUP_CARD_RESUME") % [int(cup.race) + 1, BakuCup.RACES], UITheme.LIME, "play"]
		"time_trial":
			# 0.11.0: record of the last picked track.
			var rec: Dictionary = data.get("records", {}).get(TrackList.valid(String(Settings.get_value("gameplay", "track", ""))), {})
			if rec.has("best_lap_ms"):
				return [RaceHUD.format_time(float(rec.best_lap_ms) / 1000.0), Color("9ff3ff"), "mode_time"]
			return [TranslationServer.translate("NO_RECORD"), UITheme.TEXT_DIM, ""]
		"daily":
			if DailyChallenge.done_today(data, today):
				return ["✓ " + TranslationServer.translate("DAILY_DONE"), UITheme.LIME, ""]
			return [Money.format(DailyChallenge.REWARD), UITheme.YELLOW, "manat"]
	return []


func build() -> void:
	# No kart here: the plaza stays as a dimmed backdrop only.
	if stage and stage.turntable:
		stage.turntable.visible = false
		stage.auto_rotate = false
	var dim := ColorRect.new()
	dim.color = Color(UITheme.BLUE_DEEP, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	root.move_child(dim, 0)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", UITheme.GAP_M)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(col)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UITheme.GAP_L)
	col.add_child(row)
	var today := Progression.today()
	var daily := DailyChallenge.generate(today, SaveManager.owned_karts())
	var btns: Array[Button] = []
	for mode in MODES:
		var b := _make_card(mode, today, daily)
		row.add_child(b)
		btns.append(b)
		cards[String(mode.id)] = b
		if _first == null:
			_first = b
	school_btn = make_button(tr("MODE_TUTORIAL"), func(): _choose("tutorial"))
	school_btn.name = "Mode_tutorial"
	school_btn.icon = UITheme.icon("mode_school")
	school_btn.expand_icon = false
	school_btn.add_theme_constant_override("icon_max_width", 40)
	UITheme.style_button(school_btn, "yellow", UITheme.FS_BTN_SMALL)
	school_btn.custom_minimum_size = Vector2(300, UITheme.H_BTN_SMALL)
	school_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# 0.13.0: the first lesson can be played again from here.
	var small_row := HBoxContainer.new()
	small_row.name = "SmallModes"
	small_row.alignment = BoxContainer.ALIGNMENT_CENTER
	small_row.add_theme_constant_override("separation", 16)
	small_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(small_row)
	small_row.add_child(school_btn)
	lesson_btn = make_button(tr("MODE_LESSON"), func(): Game.start_lesson())
	lesson_btn.name = "Mode_lesson"
	lesson_btn.icon = UITheme.icon("hint_tap")
	lesson_btn.expand_icon = false
	lesson_btn.add_theme_constant_override("icon_max_width", 40)
	UITheme.style_button(lesson_btn, "yellow", UITheme.FS_BTN_SMALL)
	lesson_btn.custom_minimum_size = Vector2(240, UITheme.H_BTN_SMALL)
	small_row.add_child(lesson_btn)
	# Four cards side by side; they scale with the space really available
	# so 20:9, 16:9 and 4:3 all fit without scrolling.
	var fit := func():
		var avail := body.size
		if avail.x <= 0.0:
			return
		var gap := float(row.get_theme_constant("separation"))
		var w := clampf((avail.x - gap * 3.0 - 16.0) / 4.0, 200.0, 360.0)
		var h := clampf(avail.y - UITheme.H_BTN_SMALL - UITheme.GAP_M - 16.0, 300.0, minf(w * 1.7, 520.0))
		var icon_px := clampf(w * 0.42, 84.0, 128.0)
		for c in btns:
			c.custom_minimum_size = Vector2(w, h)
			var ic: Control = c.find_child("Icon", true, false)
			if ic:
				ic.custom_minimum_size = Vector2(icon_px, icon_px)
	body.resized.connect(fit)
	fit.call_deferred()


func _make_card(mode: Dictionary, today: String, daily: Dictionary) -> Button:
	var id: String = mode.id
	var b := Button.new()
	b.name = "Mode_" + id
	b.add_theme_stylebox_override("normal", UITheme.art_box("panel_card", 26, 18))
	b.add_theme_stylebox_override("hover", UITheme.art_box("panel_card_selected", 26, 18))
	b.add_theme_stylebox_override("focus", UITheme.art_box("panel_card_selected", 26, 18))
	b.add_theme_stylebox_override("pressed", UITheme.art_box("panel_card_selected", 26, 18))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 20
	v.offset_bottom = -18
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", UITheme.GAP_M)
	b.add_child(v)
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(mode.color, 0.9)
	sb.set_corner_radius_all(80)
	sb.set_content_margin_all(16)
	badge.add_theme_stylebox_override("panel", sb)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(badge)
	var ic := TextureRect.new()
	ic.name = "Icon"
	ic.texture = UITheme.icon(mode.icon)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(112, 112)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(ic)
	var t := Label.new()
	t.text = tr(mode.title)
	t.theme_type_variation = &"Heading"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", UITheme.FS_H1)
	t.add_theme_color_override("font_color", mode.color.lightened(0.3))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var d := Label.new()
	d.name = "Desc"
	d.text = DailyChallenge.text(DailyChallenge.effective(daily, bool(Settings.values.controls.get("kids_auto", false)))) if id == "daily" else tr(mode.desc)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", UITheme.FS_BODY - 1)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	if id == "daily":
		# 0.11.1: today's city (picture + name) on the daily card.
		var cc := CityCards.mini_chip(String(daily.get("track", TrackList.IDS[0])), 40, 20)
		cc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(cc)
	var st := status_for(id, SaveManager.data, today)
	if not st.is_empty():
		var chip := GameUI.chip(String(st[2]), String(st[0]), 22, Color(UITheme.INK, 0.72), st[1])
		chip.name = "Status"
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(chip)
		status_chips[id] = chip
	b.pressed.connect(func(): _choose(id))
	b.focus_entered.connect(func(): AudioManager.play_ui("ui_move"))
	# Tap feedback: press squashes the card, release springs back.
	b.button_down.connect(func():
		b.pivot_offset = b.size * 0.5
		create_tween().tween_property(b, "scale", Vector2.ONE * 0.95, 0.06))
	b.button_up.connect(func():
		create_tween().tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return b


func _choose(mode: String) -> void:
	AudioManager.play_ui("ui_confirm")
	Game.reset_series()
	match mode:
		"tutorial":
			Game.race_config.mode = "tutorial"
			Game.race_config.track_id = TrackList.IDS[0] # drift school lives on the seafront
			Game.race_config.kart_id = SaveManager.get_selected_kart()
			Game.race_config.paint = SaveManager.get_paint(Game.race_config.kart_id)
			Game.race_config.laps = 1
			Game.race_config.ai_count = 0
			Game.race_config.items = false
			Game.start_loading_race()
		"cup":
			Game.race_config.mode = "quick"
			if BakuCup.is_active(SaveManager.data):
				Game.goto(Game.State.CUP) # resume: standings, then the next race
			else:
				Game.race_config.series = "cup_new"
				Game.start_race_with_selected()
		"daily":
			# One tap: today's race with the challenge's kart (or yours).
			var ch := DailyChallenge.generate(Progression.today(), SaveManager.owned_karts())
			DailyChallenge.apply_config(Game.race_config, ch, SaveManager.get_selected_kart())
			Game.race_config.paint = SaveManager.get_paint(Game.race_config.kart_id)
			Game.start_loading_race()
		_:
			# 0.11.1: Yarış and Rekord pick the city first.
			Game.race_config.mode = mode
			Game.goto(next_state(mode))


## 0.11.1: modes where the player picks the track go to "Şəhəri seç" first.
static func next_state(mode: String) -> int:
	return Game.State.CITY_SELECT if mode in ["quick", "time_trial"] else Game.State.KART_SELECT


func first_focus() -> Control:
	return _first
