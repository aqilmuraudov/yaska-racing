extends MenuScreen
## Kart selection with a rotatable 3D preview, handling stats and paint.

var kart_ids := KartFactory.KART_IDS
var current := 0
var paint := 0
var name_label: Label
var desc_label: Label
var stat_bars := {}
var swatch_row: HBoxContainer
var tab_buttons: Array[Button] = []
var confirm_btn: Button
var _dragging := false


func _init() -> void:
	back_state = Game.State.MODE_SELECT
	screen_title_key = "KART_TITLE"


func build() -> void:
	current = maxi(kart_ids.find(SaveManager.get_selected_kart()), 0)
	paint = SaveManager.get_paint(kart_ids[current])
	stage.set_camera_offset(1.9)
	stage.auto_rotate = true
	# Kart tabs (top-left)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	tabs.position = Vector2(0, 0)
	body.add_child(tabs)
	for i in kart_ids.size():
		var st := KartFactory.load_stats(kart_ids[i])
		var b := Button.new()
		b.text = tr(st.name_key)
		b.custom_minimum_size = Vector2(170, 64)
		b.toggle_mode = true
		var idx := i
		b.pressed.connect(func(): _select(idx))
		b.focus_entered.connect(func(): _select(idx))
		tabs.add_child(b)
		tab_buttons.append(b)
	var hint := Label.new()
	hint.text = tr("KART_ROTATE_HINT")
	hint.theme_type_variation = &"Dim"
	hint.position = Vector2(4, 80)
	body.add_child(hint)
	# Info panel (right)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -520
	panel.custom_minimum_size = Vector2(520, 0)
	body.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	name_label = Label.new()
	name_label.theme_type_variation = &"Heading"
	name_label.add_theme_font_size_override("font_size", 48)
	name_label.add_theme_color_override("font_color", UITheme.GOLD)
	v.add_child(name_label)
	desc_label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(460, 64)
	v.add_child(desc_label)
	for key in ["STAT_SPEED", "STAT_ACCEL", "STAT_HANDLING"]:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = tr(key)
		l.custom_minimum_size = Vector2(180, 0)
		row.add_child(l)
		var bar := StatBar.new()
		bar.custom_minimum_size = Vector2(220, 30)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var num := Label.new()
		num.custom_minimum_size = Vector2(40, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(num)
		stat_bars[key] = [bar, num]
		v.add_child(row)
	var pl := Label.new()
	pl.text = tr("KART_PAINT")
	pl.theme_type_variation = &"Dim"
	v.add_child(pl)
	swatch_row = HBoxContainer.new()
	swatch_row.add_theme_constant_override("separation", 12)
	v.add_child(swatch_row)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	confirm_btn = make_button(tr("MENU_CONFIRM"), _confirm, true)
	confirm_btn.custom_minimum_size = Vector2(460, 80)
	v.add_child(confirm_btn)
	_select(current, true)


func _select(i: int, force := false) -> void:
	if i == current and not force:
		return
	if i != current:
		paint = SaveManager.get_paint(kart_ids[i])
	current = i
	for k in tab_buttons.size():
		tab_buttons[k].button_pressed = k == current
	var st := KartFactory.load_stats(kart_ids[current])
	name_label.text = tr(st.name_key)
	desc_label.text = tr(st.desc_key)
	_set_stat("STAT_SPEED", st.stat_speed)
	_set_stat("STAT_ACCEL", st.stat_accel)
	_set_stat("STAT_HANDLING", st.stat_handling)
	_build_swatches(st)
	stage.show_kart(kart_ids[current], paint)
	AudioManager.play_ui("ui_move")


func _set_stat(key: String, value: int) -> void:
	var pair: Array = stat_bars[key]
	pair[0].value = value
	pair[1].text = "%d/5" % value


func _build_swatches(st: KartStats) -> void:
	for c in swatch_row.get_children():
		c.queue_free()
	for i in st.paints.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 64)
		var col: Color = st.paints[i]
		var sel := i == paint
		b.add_theme_stylebox_override("normal", UITheme.rounded(col, 32, 5 if sel else 2, UITheme.GOLD if sel else Color(1, 1, 1, 0.4), 0))
		b.add_theme_stylebox_override("hover", UITheme.rounded(col.lightened(0.1), 32, 5, UITheme.TURQUOISE, 0))
		b.add_theme_stylebox_override("pressed", UITheme.rounded(col, 32, 6, Color.WHITE, 0))
		if sel:
			b.text = "✓"
			b.add_theme_color_override("font_color", Color.WHITE if col.get_luminance() < 0.6 else UITheme.NAVY_DEEP)
		var idx := i
		b.pressed.connect(func():
			paint = idx
			_build_swatches(st)
			stage.show_kart(kart_ids[current], paint)
			AudioManager.play_ui("ui_move"))
		swatch_row.add_child(b)


func _confirm() -> void:
	SaveManager.set_selected_kart(kart_ids[current], paint)
	Game.race_config.kart_id = kart_ids[current]
	Game.race_config.paint = paint
	Game.goto(Game.State.TRACK_SELECT)


func first_focus() -> Control:
	return tab_buttons[current]


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


class StatBar:
	extends Control
	## Five numbered segments: readable without relying on colour.
	var value := 3:
		set(v):
			value = v
			queue_redraw()

	func _draw() -> void:
		var n := 5
		var gap := 6.0
		var w := (size.x - gap * (n - 1)) / n
		for i in n:
			var r := Rect2(Vector2(i * (w + gap), 0), Vector2(w, size.y))
			var on := i < value
			draw_style_box(UITheme.rounded(UITheme.TURQUOISE if on else Color(1, 1, 1, 0.12), 8, 0, Color.TRANSPARENT, 0), r)
