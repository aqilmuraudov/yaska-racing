class_name MenuScreen
extends Node
## Base for menu screens: optional 3D stage, a safe-area UI root, a header
## with title + back button, consistent focus handling and back navigation.

var stage: MenuStage
var ui_layer: CanvasLayer
var root: Control
var safe: MarginContainer
var body: Control
var header: HBoxContainer
var back_button: Button
var title_label: Label
var use_stage := true
var screen_title_key := ""
var back_state := -1 ## Game.State to return to, -1 = none
var play_menu_music := true


func _ready() -> void:
	if use_stage:
		stage = MenuStage.new()
		stage.name = "Stage"
		add_child(stage)
		stage.build()
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root)
	if not use_stage:
		root.add_child(UITheme.pattern_backdrop())
	# Soft blue wash on the left keeps text readable over the bright 3D stage
	# without greying the scene.
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(UITheme.BLUE_DEEP, 0.55 if use_stage else 0.0))
	grad.set_color(1, Color(UITheme.BLUE_DEEP, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0.75, 0)
	shade.texture = gt
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	safe = MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_safe_area()
	root.add_child(safe)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	safe.add_child(col)
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	col.add_child(header)
	if back_state >= 0:
		back_button = Button.new()
		back_button.text = tr("MENU_BACK")
		back_button.name = "BackButton"
		back_button.icon = UITheme.icon("back")
		back_button.expand_icon = false
		back_button.add_theme_constant_override("icon_max_width", 30)
		back_button.custom_minimum_size = Vector2(170, 62)
		UITheme.style_button(back_button, "turquoise", 26)
		back_button.pressed.connect(go_back)
		header.add_child(back_button)
	if screen_title_key != "":
		title_label = Label.new()
		title_label.text = tr(screen_title_key)
		title_label.theme_type_variation = &"Heading"
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header.add_child(title_label)
	body = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(body)
	if play_menu_music:
		AudioManager.play_music("menu", 1.0)
	build()
	call_deferred("_focus_first")


## Override in subclasses.
func build() -> void:
	pass


func first_focus() -> Control:
	return null


func _focus_first() -> void:
	var f := first_focus()
	if f and f.is_visible_in_tree():
		f.grab_focus()


func _apply_safe_area() -> void:
	var m := 28
	var top := 20
	var left := m
	var right := m
	var bottom := 20
	if Settings.is_mobile():
		var sa := DisplayServer.get_display_safe_area()
		var win := DisplayServer.window_get_size()
		var vp := get_viewport().get_visible_rect().size
		if win.x > 0:
			var sc := vp.x / float(win.x)
			left = maxi(left, int(sa.position.x * sc) + 8)
			right = maxi(right, int((win.x - sa.end.x) * sc) + 8)
			top = maxi(top, int(sa.position.y * sc) + 6)
			bottom = maxi(bottom, int((win.y - sa.end.y) * sc) + 6)
	safe.add_theme_constant_override("margin_left", left)
	safe.add_theme_constant_override("margin_right", right)
	safe.add_theme_constant_override("margin_top", top)
	safe.add_theme_constant_override("margin_bottom", bottom)


func go_back() -> void:
	if back_state < 0:
		return
	AudioManager.play_ui("ui_back")
	Game.goto(back_state)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and back_state >= 0:
		go_back()
		get_viewport().set_input_as_handled()


# --- Widgets ------------------------------------------------------------------

static func make_button(text: String, cb: Callable, big := false) -> Button:
	var b := Button.new()
	b.text = text
	if big:
		b.theme_type_variation = &"BigButton"
		b.custom_minimum_size = Vector2(380, 84)
	else:
		b.custom_minimum_size = Vector2(300, 66)
	b.pressed.connect(func():
		AudioManager.play_ui("ui_confirm")
		UITheme.bounce(b, 0.06)
		cb.call())
	b.focus_entered.connect(func(): AudioManager.play_ui("ui_move"))
	return b


static func make_toggle(title: String, value: bool, cb: Callable) -> CheckButton:
	var t := CheckButton.new()
	t.text = title
	t.button_pressed = value
	t.custom_minimum_size = Vector2(0, 60)
	t.toggled.connect(func(on):
		AudioManager.play_ui("ui_move")
		cb.call(on))
	return t


static func make_slider(title: String, value: float, min_v: float, max_v: float, step_v: float, cb: Callable, fmt := "%d%%", fmt_scale := 100.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.rounded(Color(UITheme.NAVY_LIGHT, 0.55), 18, 0, Color.TRANSPARENT, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var l := Label.new()
	l.text = title
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(l)
	var s := SafeSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step_v
	s.value = value
	s.custom_minimum_size = Vector2(260, 40)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var vl := Label.new()
	vl.custom_minimum_size = Vector2(84, 0)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vl.add_theme_color_override("font_color", UITheme.GOLD)
	vl.text = fmt % (value * fmt_scale)
	h.add_child(vl)
	s.value_changed.connect(func(v):
		vl.text = fmt % (v * fmt_scale)
		cb.call(v))
	p.set_meta("slider", s)
	return p


static func card(min_size := Vector2.ZERO) -> PanelContainer:
	var c := PanelContainer.new()
	c.custom_minimum_size = min_size
	return c
