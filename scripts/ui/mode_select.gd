extends MenuScreen
## Mode selection. Only modes that are fully functional are listed.

const MODES := [
	{"id": "quick", "title": "MODE_QUICK", "desc": "MODE_QUICK_DESC", "color": Color("e0344b"), "icon": "mode_quick"},
	{"id": "time_trial", "title": "MODE_TIME_TRIAL", "desc": "MODE_TIME_TRIAL_DESC", "color": Color("25c2c2"), "icon": "mode_time"},
	{"id": "tutorial", "title": "MODE_TUTORIAL", "desc": "MODE_TUTORIAL_DESC", "color": Color("ffc93c"), "icon": "mode_school"},
]

var _first: Button


func _init() -> void:
	back_state = Game.State.MAIN_MENU
	screen_title_key = "MODE_TITLE"


func build() -> void:
	stage.show_racer(SaveManager.get_selected_kart())
	stage.set_camera_offset(-2.4)
	# The cards share the height that is really available (any screen ratio,
	# safe area, UI scale); below their minimum the list scrolls, with a
	# visible scrollbar and "more" hint.
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	sc.offset_right = 664
	body.add_child(sc)
	TouchScroll.attach(sc)
	ScrollHint.attach(sc)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(row)
	for mode in MODES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(640, 118)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_stylebox_override("normal", UITheme.art_box("panel_card", 24, 14))
		b.add_theme_stylebox_override("hover", UITheme.art_box("panel_card", 24, 14))
		b.add_theme_stylebox_override("pressed", UITheme.art_box("panel_card_selected", 24, 14))
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 20
		h.offset_right = -20
		h.add_theme_constant_override("separation", 18)
		b.add_child(h)
		var ic := TextureRect.new()
		ic.texture = UITheme.icon(mode.icon)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(88, 88)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		h.add_child(v)
		var t := Label.new()
		t.text = tr(mode.title)
		t.theme_type_variation = &"Heading"
		t.add_theme_font_size_override("font_size", 38)
		t.add_theme_color_override("font_color", mode.color.lightened(0.2))
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(t)
		var d := Label.new()
		d.text = tr(mode.desc)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 22)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(d)
		var id: String = mode.id
		b.pressed.connect(func(): _choose(id))
		b.focus_entered.connect(func(): AudioManager.play_ui("ui_move"))
		row.add_child(b)
		if _first == null:
			_first = b


func _choose(mode: String) -> void:
	AudioManager.play_ui("ui_confirm")
	Game.race_config.mode = mode
	if mode == "tutorial":
		Game.race_config.kart_id = SaveManager.get_selected_kart()
		Game.race_config.paint = 0
		Game.race_config.laps = 1
		Game.race_config.ai_count = 0
		Game.race_config.items = false
		Game.start_loading_race()
	else:
		Game.goto(Game.State.KART_SELECT)


func first_focus() -> Control:
	return _first
