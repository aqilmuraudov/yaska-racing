extends MenuScreen
## Compact, child-friendly Settings: four tabs (Graphics, Audio, Controls,
## Language) of large illustrated rows, each with a short explanation and
## big touch targets. Every change applies and saves immediately.
## Works standalone (from the main menu) and as an overlay in the pause menu.
##
## Renderer / profiling / developer options live in a separate developer tab
## that exists only in debug builds and opens with a long press on the title.

const TABS := [
	["SET_TAB_GRAPHICS", "tab_graphics", "blue"],
	["SET_TAB_AUDIO", "tab_audio", "blue"],
	["SET_TAB_CONTROLS", "tab_controls", "blue"],
	["SET_TAB_LANGUAGE", "tab_language", "blue"],
]
const DEV_TAB := 4
## Rail order: the child's everyday choices first, picture quality (for
## grown-ups) last. Tab ids above stay stable for tools and tests.
const RAIL_ORDER := [2, 1, 3, 0]
const FIRST_TAB := 2
const LONG_PRESS := 1.0

var overlay_mode := false
var tab := 0
var tab_buttons: Array[Button] = []
var content: VBoxContainer
var scroll: ScrollContainer
var touch_scroll: TouchScroll
var _first_row: Control
var _modal: Control
var _calib_label: Label
var _tilt_live: Label
var _title_hold := -1.0


func _init() -> void:
	back_state = Game.State.MAIN_MENU
	screen_title_key = "SET_TITLE"


func _ready() -> void:
	if overlay_mode:
		use_stage = false
		play_menu_music = false
		process_mode = Node.PROCESS_MODE_ALWAYS
	super()
	Settings.changed.connect(_on_setting_changed)


func build() -> void:
	if stage:
		stage.show_racer(SaveManager.get_selected_kart())
		stage.set_camera_offset(-3.6)
	if overlay_mode:
		ui_layer.layer = 20
	if title_label:
		title_label.mouse_filter = Control.MOUSE_FILTER_STOP
		title_label.gui_input.connect(_on_title_input)
		var gear := TextureRect.new()
		gear.texture = UITheme.icon("gear")
		gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gear.custom_minimum_size = Vector2(52, 52)
		header.add_child(gear)
		header.move_child(gear, title_label.get_index())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	var restore := Button.new()
	restore.text = tr("SET2_RESTORE")
	restore.icon = UITheme.icon("restore")
	restore.expand_icon = false
	restore.add_theme_constant_override("icon_max_width", 34)
	restore.custom_minimum_size = Vector2(0, 60)
	UITheme.style_button(restore, "coral", 22)
	restore.pressed.connect(_confirm_restore)
	restore.name = "Restore"
	header.add_child(restore)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 10)
	rail.custom_minimum_size = Vector2(196, 0)
	row.add_child(rail)
	var tab_count := TABS.size() + (1 if _dev_available() else 0)
	tab_buttons.resize(tab_count)
	var order: Array = RAIL_ORDER.duplicate()
	if tab_count > TABS.size():
		order.append(DEV_TAB)
	for i: int in order:
		var b := Button.new()
		var def: Array = TABS[i] if i < TABS.size() else ["Dev", "gear", "violet"]
		b.text = tr(def[0]) if i < TABS.size() else "Developer"
		b.icon = UITheme.icon(def[1])
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(196, 100 if i < TABS.size() else 64)
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var idx := i
		b.pressed.connect(func():
			AudioManager.play_ui("ui_move")
			UITheme.bounce(b, 0.06)
			_show_tab(idx))
		rail.add_child(b)
		tab_buttons[i] = b
		if i >= TABS.size():
			b.visible = false # revealed by the long press
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	touch_scroll = TouchScroll.attach(scroll)
	ScrollHint.attach(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	_show_tab(FIRST_TAB)


func _dev_available() -> bool:
	return OS.is_debug_build()


func first_focus() -> Control:
	return tab_buttons[FIRST_TAB] if not tab_buttons.is_empty() else null


func go_back() -> void:
	if _modal:
		_close_modal()
		return
	if overlay_mode:
		AudioManager.play_ui("ui_back")
		queue_free()
	else:
		super()


func _on_title_input(event: InputEvent) -> void:
	if not _dev_available():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_title_hold = 0.0 if event.pressed else -1.0


func _process(delta: float) -> void:
	if _title_hold >= 0.0:
		_title_hold += delta
		if _title_hold >= LONG_PRESS:
			_title_hold = -1.0
			tab_buttons[DEV_TAB].visible = true
			_show_tab(DEV_TAB)
	if _tilt_live and is_instance_valid(_tilt_live) and _tilt_live.is_visible_in_tree():
		_update_tilt_live(delta)


func _show_tab(i: int) -> void:
	tab = i
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner in tab_buttons and i < tab_buttons.size():
		tab_buttons[i].grab_focus() # the focus ring follows the chosen tab
	for k in tab_buttons.size():
		var color := "yellow" if k == i else ("violet" if k == DEV_TAB else "blue")
		UITheme.style_button(tab_buttons[k], color, 24 if k < TABS.size() else 20)
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	_first_row = null
	_calib_label = null
	_tilt_live = null
	match i:
		0: _graphics()
		1: _audio()
		2: _controls()
		3: _language()
		DEV_TAB: _developer()
	scroll.scroll_vertical = 0
	if touch_scroll:
		touch_scroll.velocity = 0.0
	for b in tab_buttons:
		if _first_row:
			b.focus_neighbor_right = b.get_path_to(_first_row)


# --- Row building ---------------------------------------------------------------

## One setting card: illustrated icon, title, one-line purpose, the control,
## and an optional reason line for disabled choices.
func _row(icon_name: String, title_key: String, hint_key: String, control: Control) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)
	var ic := TextureRect.new()
	ic.texture = UITheme.icon(icon_name)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(60, 60)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var t := Label.new()
	t.text = tr(title_key)
	t.add_theme_font_override("font", UITheme.heading_font())
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_constant_override("outline_size", 8)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	if hint_key != "":
		var d := Label.new()
		d.text = tr(hint_key)
		d.theme_type_variation = &"Dim"
		d.add_theme_font_size_override("font_size", 21)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(180, 0)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.name = "Hint"
		v.add_child(d)
	var reason := Label.new()
	reason.name = "Reason"
	reason.visible = false
	reason.add_theme_color_override("font_color", UITheme.YELLOW)
	reason.add_theme_font_size_override("font_size", 19)
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(reason)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(control)
	content.add_child(card)
	if _first_row == null and control.focus_mode != Control.FOCUS_NONE:
		_first_row = control
	card.set_meta("reason", reason)
	return card


func _choice(icon_name: String, title_key: String, hint_key: String, option_keys: Array, idx: int, cb: Callable, min_w := 104.0) -> SegmentedChoice:
	var names: Array = []
	for k in option_keys:
		names.append(tr(k) if k is String else str(k))
	var sc := SegmentedChoice.new().setup(names, idx, min_w)
	sc.value_changed.connect(cb)
	var card := _row(icon_name, title_key, hint_key, sc)
	sc.set_meta("card", card)
	return sc


func _switch(icon_name: String, title_key: String, hint_key: String, section: String, key: String) -> SegmentedChoice:
	var on := bool(Settings.get_value(section, key, true))
	return _choice(icon_name, title_key, hint_key, ["OPT_ON", "OPT_OFF"], 0 if on else 1,
		func(i): Settings.set_value(section, key, i == 0), 120.0)


func _set_reason(sc: SegmentedChoice, text: String) -> void:
	var card: Control = sc.get_meta("card")
	var l: Label = card.get_meta("reason")
	l.text = text
	l.visible = text != ""


# --- Tabs ---------------------------------------------------------------------

func _graphics() -> void:
	var g: Dictionary = Settings.values.graphics
	_row("parents", "SET3_GROWNUPS", "SET3_GROWNUPS_HINT", Control.new())
	_choice("texture", "SET2_TEXTURE", "SET2_TEXTURE_HINT", ["OPT_Q_LOW", "OPT_Q_NORMAL", "OPT_Q_HIGH"], int(g.texture_detail),
		func(i): Settings.set_value("graphics", "texture_detail", i))
	var caps: Array = Settings.fps_options()
	var names: Array = []
	for v in caps:
		names.append(tr("SET_FPS_UNLIMITED") if int(v) == 0 else str(v))
	var fps := _choice("fps", "SET2_FPS", "SET2_FPS_HINT", names, maxi(caps.find(int(g.fps_cap)), 0),
		func(i): Settings.set_value("graphics", "fps_cap", caps[i]), 80.0)
	var unsupported: Array = []
	for i in caps.size():
		if not Settings.fps_supported(int(caps[i])):
			fps.set_option_disabled(i, true)
			unsupported.append(int(caps[i]))
	if not unsupported.is_empty():
		var hz := int(round(Settings.display_refresh_rate()))
		_set_reason(fps, tr("SET2_FPS_UNSUPPORTED") % [hz, unsupported[0]] if hz > 0 else tr("SET2_FPS_UNKNOWN"))
	_switch("fps", "SET3_FPS_FALLBACK", "SET3_FPS_FALLBACK_HINT", "graphics", "fps_fallback")
	_choice("shadows", "SET2_SHADOWS", "SET2_SHADOWS_HINT", ["OPT_OFF", "OPT_Q_LOW", "OPT_Q_NORMAL", "OPT_Q_HIGH"], int(g.shadows),
		func(i): Settings.set_value("graphics", "shadows", i), 92.0)


func _audio() -> void:
	_switch("master", "SET2_MASTER", "", "audio", "master_on")
	var music := _switch("music", "SET2_MUSIC", "", "audio", "music_on")
	var sfx := _switch("sfx", "SET2_SFX", "", "audio", "sfx_on")
	if not bool(Settings.get_value("audio", "master_on", true)):
		# Choices stay editable and remembered; say why nothing is heard.
		_set_reason(music, tr("SET2_MASTER_OFF_NOTE"))
		_set_reason(sfx, tr("SET2_MASTER_OFF_NOTE"))


func _controls() -> void:
	var c: Dictionary = Settings.values.controls
	var tilt_mode := String(c.touch_steer_mode) == "tilt"
	var ct := _choice("control_type", "SET2_CONTROL_TYPE", "SET2_CONTROL_TYPE_HINT", ["OPT_BUTTONS", "OPT_TILT"], 1 if tilt_mode else 0,
		func(i):
			Settings.set_value("controls", "touch_steer_mode", "tilt" if i == 1 else "buttons")
			call_deferred("_rebuild_keep_scroll"), 130.0)
	var reason := Settings.unsupported_reason("tilt")
	if reason != "":
		ct.set_option_disabled(1, true)
		_set_reason(ct, tr(reason))
	if tilt_mode:
		_calibrate_row()
	_switch("auto_accel", "SET2_AUTO_ACCEL", "SET2_AUTO_ACCEL_HINT", "controls", "touch_auto_accelerate")
	_switch("easy_drift", "SET3_EASY_DRIFT", "SET3_EASY_DRIFT_HINT", "controls", "easy_drift")
	_switch("steer_help", "SET3_STEER_HELP", "SET3_STEER_HELP_HINT", "gameplay", "steer_assist")
	_choice("button_size", "SET2_BUTTON_SIZE", "", ["OPT_SMALL", "OPT_MEDIUM", "OPT_LARGE"], int(c.button_size),
		func(i): Settings.set_value("controls", "button_size", i))
	_choice("steering", "SET2_STEER_SENS", "SET2_STEER_SENS_HINT_TILT" if tilt_mode else "SET2_STEER_SENS_HINT_BUTTONS",
		["OPT_S_LOW", "OPT_S_NORMAL", "OPT_S_HIGH"], int(c.steer_level),
		func(i): Settings.set_value("controls", "steer_level", i))
	var shake_levels := [0.0, 0.6, 1.0]
	var shake := float(Settings.get_value("accessibility", "camera_shake", 0.6))
	var shake_idx := 0 if shake < 0.3 else (1 if shake < 0.8 else 2)
	_choice("camera_shake", "SET3_SHAKE", "", ["OPT_OFF", "OPT_S_LOW", "OPT_S_NORMAL"], shake_idx,
		func(i): Settings.set_value("accessibility", "camera_shake", shake_levels[i]))
	var vib := _switch("vibration", "SET3_VIBRATION", "", "controls", "vibration")
	var vib_reason := Settings.unsupported_reason("vibration")
	if vib_reason != "":
		vib.set_option_disabled(0, true)
		_set_reason(vib, tr(vib_reason))


## Shown only with Tilt selected: live tilt bar + Calibrate.
var _preview_tilt := TiltSteering.new()


func _calibrate_row() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var b := Button.new()
	b.text = tr("SET2_CALIBRATE")
	b.icon = UITheme.icon("calibrate")
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 36)
	b.custom_minimum_size = Vector2(250, 64)
	UITheme.style_button(b, "lime", 24)
	b.pressed.connect(func():
		_preview_tilt.calibrate()
		Settings.set_value("controls", "tilt_neutral_deg", _preview_tilt.neutral_deg)
		UITheme.bounce(b)
		UITheme.sparkle_burst(b, b.get_global_rect().get_center(), 8, UITheme.LIME)
		AudioManager.play_ui("ui_confirm")
		if _calib_label:
			_calib_label.text = tr("SET2_CALIBRATED"))
	box.add_child(b)
	_tilt_live = Label.new()
	_tilt_live.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tilt_live.add_theme_font_size_override("font_size", 20)
	box.add_child(_tilt_live)
	var card := _row("calibrate", "SET2_CALIBRATE", "SET2_CALIBRATE_HINT", box)
	_calib_label = card.find_child("Hint", true, false)
	_preview_tilt.neutral_deg = float(Settings.get_value("controls", "tilt_neutral_deg", 0.0))
	_preview_tilt.reset()


func _update_tilt_live(delta: float) -> void:
	_preview_tilt.sensitivity = int(Settings.get_value("controls", "steer_level", 1))
	var s := _preview_tilt.update_from_sensors(delta)
	if not _preview_tilt.has_data():
		_tilt_live.text = ""
		return
	var cells := 9
	var pos := int(round((s + 1.0) * 0.5 * (cells - 1)))
	var bar := ""
	for i in cells:
		bar += "●" if i == pos else "·"
	_tilt_live.text = "%s  %s" % [tr("SET2_TILT_LIVE"), bar]


func _language() -> void:
	var langs := [["az", "flag_az", "Azərbaycan dili"], ["en", "flag_en", "English"]]
	var cur := String(Settings.get_value("gameplay", "language", "az"))
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 18)
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	for l in langs:
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 220)
		b.focus_mode = Control.FOCUS_ALL
		UITheme.style_button(b, "yellow" if l[0] == cur else "blue", 30)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 12)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var flag := TextureRect.new()
		flag.texture = UITheme.icon(l[1])
		flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flag.custom_minimum_size = Vector2(176, 88)
		flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(flag)
		var name_l := Label.new()
		name_l.text = l[2]
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_font_override("font", UITheme.heading_font())
		name_l.add_theme_font_size_override("font_size", 32)
		name_l.add_theme_color_override("font_color", UITheme.INK if l[0] == cur else UITheme.TEXT)
		name_l.add_theme_constant_override("outline_size", 0 if l[0] == cur else 8)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(name_l)
		var code: String = l[0]
		b.pressed.connect(func():
			UITheme.bounce(b)
			AudioManager.play_ui("ui_confirm")
			if code != String(Settings.get_value("gameplay", "language", "az")):
				Settings.set_value("gameplay", "language", code))
		grid.add_child(b)
		if _first_row == null:
			_first_row = b
	_row("tab_language", "SET_TAB_LANGUAGE", "SET2_LANGUAGE_HINT", Control.new())
	content.add_child(grid)


## Development-only tab (debug builds): renderer, profiling and tuning
## controls the child-facing tabs deliberately leave out. English only.
func _developer() -> void:
	var g: Dictionary = Settings.values.graphics
	var note := Label.new()
	note.text = "Developer options (debug builds only). Renderer: %s, display %.0f Hz." % [Settings.rendering_method(), Settings.display_refresh_rate()]
	note.theme_type_variation = &"Dim"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	var presets := ["low", "medium", "high"]
	_dev_sel("Quality preset (all knobs)", ["low", "medium", "high", "custom"], maxi(presets.find(String(g.preset)), 3 if String(g.preset) == "custom" else 0), func(i):
		if i < 3:
			Settings.apply_preset(presets[i])
			call_deferred("_rebuild_keep_scroll"))
	_dev_slider("Resolution scale", "graphics", "resolution_scale", 0.5, 1.0, 0.05)
	if Settings.unsupported_reason("msaa") == "":
		_dev_sel("MSAA", ["off", "2x", "4x"], int(g.msaa), func(i): Settings.set_value("graphics", "msaa", i))
	_dev_toggle("FXAA", "graphics", "fxaa")
	_dev_toggle("Bloom", "graphics", "bloom")
	if Settings.unsupported_reason("ssao") == "":
		_dev_toggle("SSAO", "graphics", "ssao")
	_dev_slider("Effects density", "graphics", "effects_density", 0.0, 1.0, 0.05)
	_dev_sel("Scenery distance", ["short", "medium", "far"], int(g.decor_distance), func(i): Settings.set_value("graphics", "decor_distance", i))
	_dev_toggle("Dynamic resolution", "graphics", "dynamic_resolution")
	_dev_toggle("Speed blur", "graphics", "motion_blur")
	_dev_slider("Brightness", "graphics", "brightness", 0.6, 1.5, 0.05)
	if Settings.is_desktop():
		_dev_toggle("VSync", "graphics", "vsync")
		_dev_sel("Window", ["windowed", "fullscreen"], 1 if g.window_mode == "fullscreen" else 0, func(i): Settings.set_value("graphics", "window_mode", "fullscreen" if i == 1 else "windowed"))
	_dev_toggle("Tilt sensor debug overlay (race HUD)", "graphics", "tilt_debug")
	_dev_toggle("Performance overlay (race HUD)", "graphics", "dev_overlay")
	_dev_slider("Touch button opacity", "controls", "touch_opacity", 0.2, 1.0, 0.05)
	_dev_sel("Touch layout", ["standard", "mirrored"], 1 if Settings.values.controls.touch_layout == "swapped" else 0, func(i): Settings.set_value("controls", "touch_layout", "swapped" if i == 1 else "default"))
	_dev_toggle("Vibration", "controls", "vibration")
	_dev_sel("Camera distance", ["near", "normal", "far"], int(Settings.values.gameplay.camera_distance), func(i): Settings.set_value("gameplay", "camera_distance", i))
	_dev_toggle("Speedometer", "gameplay", "speedometer")
	_dev_toggle("Steering assist", "gameplay", "steer_assist")
	_dev_toggle("Subtitles / captions", "accessibility", "subtitles")
	_dev_toggle("Reduce flashing", "accessibility", "reduced_flashing")
	_dev_slider("Camera shake", "accessibility", "camera_shake", 0.0, 1.0, 0.05)
	_dev_toggle("Play audio in background", "audio", "background_audio")
	for k in ["master", "music", "engine", "sfx", "ui"]:
		_dev_slider("Mix level: " + k, "audio", k, 0.0, 1.0, 0.05)


func _dev_sel(title: String, opts: Array, idx: int, cb: Callable) -> void:
	var s := OptionSelector.new().setup(title, opts, idx)
	s.value_changed.connect(cb)
	content.add_child(s)


func _dev_toggle(title: String, section: String, key: String) -> void:
	content.add_child(make_toggle(title, bool(Settings.get_value(section, key, false)), func(on): Settings.set_value(section, key, on)))


func _dev_slider(title: String, section: String, key: String, min_v: float, max_v: float, step_v: float) -> void:
	content.add_child(make_slider(title, float(Settings.get_value(section, key, 0.0)), min_v, max_v, step_v, func(v): Settings.set_value(section, key, v)))


# --- Reactions ------------------------------------------------------------------

func _on_setting_changed(section: String, key: String) -> void:
	if section == "gameplay" and key == "language":
		call_deferred("_rebuild_after_language")
	elif section == "audio" and key == "master_on" and tab == 1:
		call_deferred("_rebuild_keep_scroll")


func _rebuild_keep_scroll() -> void:
	if not is_inside_tree():
		return
	var y := scroll.scroll_vertical
	_show_tab(tab)
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = y


func _rebuild_after_language() -> void:
	if not is_inside_tree():
		return
	# Text was created with tr(); rebuild so every string updates at once.
	if title_label:
		title_label.text = tr(screen_title_key)
	if back_button:
		back_button.text = tr("MENU_BACK")
	for i in mini(tab_buttons.size(), TABS.size()):
		tab_buttons[i].text = tr(TABS[i][0])
	var restore: Button = header.get_node_or_null("Restore")
	if restore:
		restore.text = tr("SET2_RESTORE")
	_show_tab(tab)


# --- Confirmation -----------------------------------------------------------------

func _confirm_restore() -> void:
	_show_modal(tr("SET2_RESTORE_CONFIRM"), tr("SET_YES"), tr("SET_NO"), func(yes):
		if yes:
			# Keep the chosen language: restoring should not switch the
			# child's reading language away under them.
			var lang: String = Settings.get_value("gameplay", "language", "az")
			Settings.restore_defaults()
			if lang != Settings.get_value("gameplay", "language", "az"):
				Settings.set_value("gameplay", "language", lang)
			_rebuild_after_language())


func _close_modal() -> void:
	if _modal:
		_modal.queue_free()
		_modal = null


func _show_modal(text: String, yes_text: String, no_text: String, cb: Callable) -> void:
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(560, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	p.add_child(v)
	var ic := TextureRect.new()
	ic.texture = UITheme.icon("restore")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(0, 72)
	v.add_child(ic)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UITheme.heading_font())
	l.add_theme_font_size_override("font_size", 30)
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 18)
	v.add_child(h)
	var close := func(result: bool):
		_close_modal()
		cb.call(result)
	var yes := Button.new()
	yes.text = yes_text
	yes.custom_minimum_size = Vector2(200, 70)
	UITheme.style_button(yes, "coral", 28)
	yes.pressed.connect(func(): close.call(true))
	h.add_child(yes)
	var no := Button.new()
	no.text = no_text
	no.custom_minimum_size = Vector2(200, 70)
	UITheme.style_button(no, "blue", 28)
	no.pressed.connect(func(): close.call(false))
	h.add_child(no)
	root.add_child(_modal)
	no.grab_focus()
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2.ONE * 0.85
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
