extends MenuScreen
## Credits and licences.

var _scroll: ScrollContainer


func _init() -> void:
	back_state = Game.State.MAIN_MENU
	screen_title_key = "CREDITS_TITLE"


func build() -> void:
	stage.show_kart("agile", 0)
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
	var text := Label.new()
	text.text = tr("CREDITS_BODY")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(660, 0)
	text.add_theme_font_size_override("font_size", 24)
	_scroll.add_child(text)


func first_focus() -> Control:
	return back_button


func _process(delta: float) -> void:
	var dir := Input.get_axis("ui_up", "ui_down")
	if absf(dir) > 0.1 and _scroll:
		_scroll.scroll_vertical += int(dir * 600.0 * delta)
