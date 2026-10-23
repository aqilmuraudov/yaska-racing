extends MenuScreen
## Main menu: the selected animal and kart on a Baku Boulevard plaza, Play as
## the one big primary action, Settings close at hand, Credits and (desktop
## only) Quit. Buttons pop in once; the title floats gently.

var play_btn: Button
var _title: Label
var _t := 0.0


func _init() -> void:
	back_state = -1


func build() -> void:
	var racer_id := SaveManager.get_selected_kart()
	stage.show_racer(racer_id)
	stage.set_camera_offset(-1.9)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.position = Vector2(16, 0)
	body.add_child(col)
	_title = Label.new()
	_title.text = tr("GAME_TITLE")
	_title.theme_type_variation = &"Title"
	_title.add_theme_font_size_override("font_size", 104)
	_title.add_theme_color_override("font_color", UITheme.YELLOW)
	_title.add_theme_constant_override("outline_size", 22)
	col.add_child(_title)
	var sub := Label.new()
	sub.text = tr("GAME_SUBTITLE")
	sub.add_theme_font_override("font", UITheme.heading_font())
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_constant_override("outline_size", 8)
	col.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	col.add_child(spacer)
	play_btn = make_button(tr("MENU_PLAY"), func(): Game.goto(Game.State.MODE_SELECT), true)
	play_btn.icon = UITheme.icon("play")
	play_btn.expand_icon = false
	play_btn.add_theme_constant_override("icon_max_width", 40)
	play_btn.custom_minimum_size = Vector2(400, 96)
	play_btn.add_theme_font_size_override("font_size", 46)
	col.add_child(play_btn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var settings := make_button(tr("MENU_SETTINGS"), func(): Game.goto(Game.State.SETTINGS))
	settings.icon = UITheme.icon("gear")
	settings.expand_icon = false
	settings.add_theme_constant_override("icon_max_width", 36)
	settings.custom_minimum_size = Vector2(250, 72)
	UITheme.style_button(settings, "blue", 28)
	row.add_child(settings)
	var credits := make_button(tr("MENU_CREDITS"), func(): Game.goto(Game.State.CREDITS))
	credits.icon = UITheme.icon("trophy")
	credits.expand_icon = false
	credits.add_theme_constant_override("icon_max_width", 34)
	credits.custom_minimum_size = Vector2(0, 72)
	UITheme.style_button(credits, "violet", 24)
	row.add_child(credits)
	if Settings.is_desktop():
		var quit := make_button(tr("MENU_QUIT"), func(): Game.quit_game())
		quit.custom_minimum_size = Vector2(250, 56)
		UITheme.style_button(quit, "coral", 22)
		col.add_child(quit)
	# Pop-in once (staggered), then everything stays still.
	var i := 0
	for c in [play_btn, settings, credits]:
		c.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.18)
		tw.parallel().tween_callback(func(): UITheme.bounce(c, 0.08))
		i += 1
	# Racer nameplate (lower right) and coins.
	var d := RacerRoster.get_def(racer_id)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UITheme.art_box("panel_card_selected", 22, 8))
	plate.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	plate.position = Vector2(-20, -20)
	body.add_child(plate)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", -6)
	plate.add_child(pv)
	var pn := Label.new()
	pn.text = d.display_name if d else ""
	pn.add_theme_font_override("font", UITheme.heading_font())
	pn.add_theme_font_size_override("font_size", 38)
	pn.add_theme_color_override("font_color", UITheme.INK)
	pn.add_theme_constant_override("outline_size", 0)
	pv.add_child(pn)
	var pk := Label.new()
	pk.text = d.kart_name if d else ""
	pk.add_theme_font_size_override("font_size", 20)
	pk.add_theme_color_override("font_color", Color(UITheme.INK, 0.8))
	pk.add_theme_constant_override("outline_size", 0)
	pv.add_child(pk)
	var footer := HBoxContainer.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.position = Vector2(16, -44)
	body.add_child(footer)
	var coins := Label.new()
	coins.text = "%s: %d" % [tr("RESULTS_COINS").capitalize(), int(SaveManager.data.currency)]
	coins.add_theme_font_override("font", UITheme.heading_font())
	coins.add_theme_font_size_override("font_size", 28)
	coins.add_theme_color_override("font_color", UITheme.YELLOW)
	coins.add_theme_constant_override("outline_size", 8)
	footer.add_child(coins)
	var ver := Label.new()
	ver.text = "   v%s" % ProjectSettings.get_setting("application/config/version", "0.0")
	ver.theme_type_variation = &"Dim"
	footer.add_child(ver)


func _process(delta: float) -> void:
	_t += delta
	if _title:
		_title.position.y = sin(_t * 1.6) * 3.0


func first_focus() -> Control:
	return play_btn


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and Settings.is_desktop():
		pass # no accidental quit from the root menu
