extends MenuScreen
## Main menu: Play, Settings, Credits and (desktop only) Quit.

var play_btn: Button


func _init() -> void:
	back_state = -1


func build() -> void:
	stage.show_kart(SaveManager.get_selected_kart(), SaveManager.get_paint(SaveManager.get_selected_kart()))
	stage.set_camera_offset(-1.6)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.position = Vector2(20, 10)
	body.add_child(col)
	var title := Label.new()
	title.text = tr("GAME_TITLE")
	title.theme_type_variation = &"Title"
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", UITheme.GOLD)
	col.add_child(title)
	var sub := Label.new()
	sub.text = tr("GAME_SUBTITLE")
	sub.add_theme_font_size_override("font_size", 26)
	col.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	col.add_child(spacer)
	play_btn = make_button(tr("MENU_PLAY"), func(): Game.goto(Game.State.MODE_SELECT), true)
	col.add_child(play_btn)
	col.add_child(make_button(tr("MENU_SETTINGS"), func(): Game.goto(Game.State.SETTINGS)))
	col.add_child(make_button(tr("MENU_CREDITS"), func(): Game.goto(Game.State.CREDITS)))
	if Settings.is_desktop():
		col.add_child(make_button(tr("MENU_QUIT"), func(): Game.quit_game()))
	# Footer: coins and version
	var footer := HBoxContainer.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.offset_top = -44
	body.add_child(footer)
	var ver := Label.new()
	ver.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0")
	ver.theme_type_variation = &"Dim"
	ver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(ver)
	var coins := Label.new()
	coins.text = "%s: %d" % [tr("RESULTS_COINS").capitalize(), int(SaveManager.data.currency)]
	coins.add_theme_color_override("font_color", UITheme.GOLD)
	footer.add_child(coins)


func first_focus() -> Control:
	return play_btn


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and Settings.is_desktop():
		pass # no accidental quit from the root menu
