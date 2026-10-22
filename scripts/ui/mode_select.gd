extends MenuScreen
## Mode selection. Only modes that are fully functional are listed.

const MODES := [
	{"id": "quick", "title": "MODE_QUICK", "desc": "MODE_QUICK_DESC", "color": Color("e0344b")},
	{"id": "time_trial", "title": "MODE_TIME_TRIAL", "desc": "MODE_TIME_TRIAL_DESC", "color": Color("25c2c2")},
	{"id": "tutorial", "title": "MODE_TUTORIAL", "desc": "MODE_TUTORIAL_DESC", "color": Color("ffc93c")},
]

var _first: Button


func _init() -> void:
	back_state = Game.State.MAIN_MENU
	screen_title_key = "MODE_TITLE"


func build() -> void:
	stage.show_racer(SaveManager.get_selected_kart())
	stage.set_camera_offset(-2.4)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.position = Vector2(10, 10)
	row.custom_minimum_size = Vector2(620, 0)
	body.add_child(row)
	for mode in MODES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(620, 150)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_stylebox_override("normal", UITheme.rounded(Color(UITheme.NAVY, 0.88), 24, 4, Color(mode.color, 0.6), 16))
		b.add_theme_stylebox_override("hover", UITheme.rounded(Color(UITheme.NAVY_LIGHT, 0.95), 24, 5, mode.color, 16))
		b.add_theme_stylebox_override("pressed", UITheme.rounded(Color(mode.color, 0.9), 24, 5, Color.WHITE, 16))
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 26
		v.offset_top = 14
		v.offset_right = -20
		b.add_child(v)
		var t := Label.new()
		t.text = tr(mode.title)
		t.theme_type_variation = &"Heading"
		t.add_theme_font_size_override("font_size", 36)
		t.add_theme_color_override("font_color", mode.color.lightened(0.2))
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(t)
		var d := Label.new()
		d.text = tr(mode.desc)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 21)
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
