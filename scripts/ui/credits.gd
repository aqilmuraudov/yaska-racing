extends MenuScreen
## Credits and licences.

var _scroll: ScrollContainer


func _init() -> void:
	back_state = Game.State.SETTINGS
	screen_title_key = "CREDITS_TITLE"


func build() -> void:
	stage.show_racer("leloyun")
	stage.set_camera_offset(-2.6)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.custom_minimum_size = Vector2(720, 0)
	panel.offset_right = 720
	body.add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.focus_mode = Control.FOCUS_ALL
	panel.add_child(_scroll)
	TouchScroll.attach(_scroll)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	_scroll.add_child(inner)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/yaska_racing_logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(660, 170)
	inner.add_child(logo)
	var text := Label.new()
	text.text = tr("CREDITS_BODY")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(660, 0)
	text.add_theme_font_size_override("font_size", 24)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(text)


func first_focus() -> Control:
	return back_button


func _process(delta: float) -> void:
	var dir := Input.get_axis("ui_up", "ui_down")
	if absf(dir) > 0.1 and _scroll:
		_scroll.scroll_vertical += int(dir * 600.0 * delta)
