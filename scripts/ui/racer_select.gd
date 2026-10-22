extends MenuScreen
## Racer selection: each animal and its kart are one package. Selecting a
## card updates the 3D preview (one model at a time), names, colour theme,
## five stat bars, speciality text and the handling used in the race.

const STAT_KEYS := [["top_speed", "STAT_TOP"], ["acceleration", "STAT_ACCEL"], ["handling", "STAT_HANDLING"], ["drift", "STAT_DRIFT"], ["boost", "STAT_BOOST"]]

var defs: Array[RacerDefinition] = []
var current := 0
var cards: Array[Button] = []
var name_label: Label
var kart_label: Label
var pers_label: Label
var spec_label: Label
var stat_rows := {}
var start_btn: Button
var setup_btn: Button
var info_panel: PanelContainer
var _dragging := false


func _init() -> void:
	back_state = Game.State.MODE_SELECT
	screen_title_key = "RACER_TITLE"


func build() -> void:
	defs = RacerRoster.all()
	current = maxi(RacerRoster.IDS.find(SaveManager.get_selected_kart()), 0)
	stage.set_camera_offset(0.2)
	stage.camera.position = Vector3(0.2, 1.9, 6.4)
	stage.camera.look_at_from_position(stage.camera.position, Vector3(0.2, 0.9, 0))
	stage.auto_rotate = true
	stage.rotation_speed = 0.3
	# Cards (left): 2 columns x 3 rows
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.position = Vector2(0, 4)
	body.add_child(grid)
	for i in defs.size():
		var d := defs[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(196, 150)
		b.focus_mode = Control.FOCUS_ALL
		b.clip_contents = true
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", -4)
		b.add_child(v)
		var icon := RacerIcon.new()
		icon.def = d
		icon.custom_minimum_size = Vector2(0, 96)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(icon)
		var nl := Label.new()
		nl.text = d.display_name
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.add_theme_font_override("font", UITheme.heading_font())
		nl.add_theme_font_size_override("font_size", 26)
		nl.add_theme_constant_override("outline_size", 6)
		nl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(nl)
		var kl := Label.new()
		kl.text = d.kart_name
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.add_theme_font_size_override("font_size", 16)
		kl.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(kl)
		var idx := i
		b.pressed.connect(func(): _select(idx))
		b.focus_entered.connect(func(): _select(idx))
		grid.add_child(b)
		cards.append(b)
	# Info panel (right)
	info_panel = PanelContainer.new()
	info_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	info_panel.offset_left = -470
	info_panel.custom_minimum_size = Vector2(470, 0)
	body.add_child(info_panel)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 4)
	info_panel.add_child(iv)
	name_label = Label.new()
	name_label.theme_type_variation = &"Heading"
	name_label.add_theme_font_size_override("font_size", 44)
	iv.add_child(name_label)
	kart_label = Label.new()
	kart_label.add_theme_font_override("font", UITheme.bold_font())
	kart_label.add_theme_font_size_override("font_size", 24)
	iv.add_child(kart_label)
	pers_label = Label.new()
	pers_label.theme_type_variation = &"Dim"
	pers_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(pers_label)
	for sk in STAT_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := Label.new()
		l.text = tr(sk[1])
		l.custom_minimum_size = Vector2(150, 0)
		l.add_theme_font_size_override("font_size", 20)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(l)
		var bar := StatBar10.new()
		bar.custom_minimum_size = Vector2(210, 24)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var num := Label.new()
		num.custom_minimum_size = Vector2(56, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num.add_theme_font_override("font", UITheme.bold_font())
		num.add_theme_font_size_override("font_size", 20)
		row.add_child(num)
		stat_rows[sk[0]] = [bar, num]
		iv.add_child(row)
	var sh := Label.new()
	sh.text = tr("RACER_SPECIALTY")
	sh.theme_type_variation = &"Dim"
	iv.add_child(sh)
	spec_label = Label.new()
	spec_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spec_label.add_theme_font_size_override("font_size", 21)
	spec_label.custom_minimum_size = Vector2(420, 0)
	iv.add_child(spec_label)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	iv.add_child(sp)
	start_btn = make_button(tr("MENU_START_RACE"), _start, true)
	start_btn.custom_minimum_size = Vector2(420, 74)
	iv.add_child(start_btn)
	setup_btn = make_button(tr("TRACK_TITLE"), _setup)
	setup_btn.custom_minimum_size = Vector2(420, 48)
	iv.add_child(setup_btn)
	_select(current, true)


func _select(i: int, force := false) -> void:
	if i == current and not force:
		return
	current = i
	var d := defs[i]
	for k in cards.size():
		var on := k == i
		var c := defs[k].accent
		cards[k].add_theme_stylebox_override("normal", UITheme.rounded(Color(c.darkened(0.45), 0.92) if not on else c.darkened(0.1), 22, 5 if on else 2, UITheme.GOLD if on else Color(c, 0.6), 6))
		cards[k].add_theme_stylebox_override("hover", UITheme.rounded(c.darkened(0.2), 22, 4, UITheme.TURQUOISE, 6))
		cards[k].add_theme_stylebox_override("pressed", UITheme.rounded(c, 22, 5, Color.WHITE, 6))
		cards[k].scale = Vector2.ONE
	cards[i].pivot_offset = cards[i].size * 0.5
	var tw := create_tween()
	cards[i].scale = Vector2.ONE * 1.08
	tw.tween_property(cards[i], "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	name_label.text = d.display_name
	name_label.add_theme_color_override("font_color", d.accent.lightened(0.25))
	kart_label.text = "%s: %s" % [tr("RACER_KART"), d.kart_name]
	pers_label.text = tr(d.personality_key)
	spec_label.text = tr(d.specialty_key)
	var r := d.ratings()
	for key in stat_rows.keys():
		var pair: Array = stat_rows[key]
		pair[0].value = int(r[key])
		pair[0].color = d.accent.lightened(0.15)
		pair[1].text = "%d/10" % int(r[key])
	info_panel.add_theme_stylebox_override("panel", UITheme.rounded(Color(UITheme.NAVY, 0.92), 26, 4, Color(d.accent, 0.8), 18))
	start_btn.add_theme_stylebox_override("normal", UITheme.rounded(d.accent.darkened(0.05), 26, 4, Color(1, 1, 1, 0.3), 16))
	start_btn.add_theme_stylebox_override("hover", UITheme.rounded(d.accent.lightened(0.12), 26, 5, UITheme.GOLD, 16))
	stage.show_racer(d.id)
	AudioManager.play_ui("ui_confirm" if not force else "ui_move")


func _commit() -> void:
	var d := defs[current]
	SaveManager.set_selected_kart(d.id)
	Game.race_config.kart_id = d.id
	Game.race_config.paint = 0


func _start() -> void:
	_commit()
	if Game.race_config.mode == "time_trial":
		Game.race_config.ai_count = 0
		Game.race_config.items = false
	Game.start_loading_race()


func _setup() -> void:
	_commit()
	Game.goto(Game.State.TRACK_SELECT)


func first_focus() -> Control:
	return cards[current] if not cards.is_empty() else null


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		stage.auto_rotate = not event.pressed
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
		stage.auto_rotate = not event.pressed
	elif event is InputEventMouseMotion and _dragging:
		stage.drag(event.relative.x * 0.01)
	elif event is InputEventScreenDrag:
		stage.drag(event.relative.x * 0.01)


class StatBar10:
	extends Control
	## Ten segments + number label beside it (readable without colour).
	var value := 5:
		set(v):
			value = v
			queue_redraw()
	var color := UITheme.TURQUOISE:
		set(v):
			color = v
			queue_redraw()

	func _draw() -> void:
		var n := 10
		var gap := 3.0
		var w := (size.x - gap * (n - 1)) / n
		for i in n:
			var r := Rect2(Vector2(i * (w + gap), 0), Vector2(w, size.y))
			draw_style_box(UITheme.rounded(color if i < value else Color(1, 1, 1, 0.13), 5, 0, Color.TRANSPARENT, 0), r)
