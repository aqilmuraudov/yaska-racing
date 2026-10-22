extends MenuScreen
## Settings. Every change applies and saves immediately. Options the current
## renderer/platform cannot honour are shown disabled with the reason.
## Works standalone (from the main menu) and as an overlay in the pause menu.

const TABS := ["SET_TAB_GRAPHICS", "SET_TAB_AUDIO", "SET_TAB_CONTROLS", "SET_TAB_GAMEPLAY", "SET_TAB_ACCESS"]

var overlay_mode := false
var tab := 0
var tab_buttons: Array[Button] = []
var content: VBoxContainer
var scroll: ScrollContainer
var _first_row: Control
var _remap_action: StringName = &""
var _remap_slot := 0
var _remap_label: Label
var _modal: Control
var _revert_timer := 0.0
var _revert_values := {}


func _init() -> void:
	back_state = Game.State.MAIN_MENU
	screen_title_key = "SET_TITLE"


func _ready() -> void:
	if overlay_mode:
		use_stage = false
		play_menu_music = false
		process_mode = Node.PROCESS_MODE_ALWAYS
	super()


func build() -> void:
	if stage:
		stage.show_kart(SaveManager.get_selected_kart(), SaveManager.get_paint(SaveManager.get_selected_kart()))
		stage.set_camera_offset(-3.2)
	if overlay_mode:
		ui_layer.layer = 20
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 10)
	body.add_child(col)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	col.add_child(tabs)
	for i in TABS.size():
		var b := Button.new()
		b.text = tr(TABS[i])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		b.pressed.connect(func(): _show_tab(idx))
		tabs.add_child(b)
		tab_buttons.append(b)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(footer)
	footer.add_child(make_button(tr("SET_RESTORE"), _confirm_restore))
	_show_tab(0)


func first_focus() -> Control:
	return tab_buttons[0] if not tab_buttons.is_empty() else null


func go_back() -> void:
	if _modal:
		return
	if overlay_mode:
		AudioManager.play_ui("ui_back")
		queue_free()
	else:
		super()


func _show_tab(i: int) -> void:
	tab = i
	for k in tab_buttons.size():
		tab_buttons[k].button_pressed = k == i
	for c in content.get_children():
		c.queue_free()
	_first_row = null
	match i:
		0: _graphics()
		1: _audio()
		2: _controls()
		3: _gameplay()
		4: _access()
	scroll.scroll_vertical = 0
	# Keyboard/controller: down from the tabs enters the list.
	for b in tab_buttons:
		if _first_row:
			b.focus_neighbor_bottom = b.get_path_to(_first_row)


func _add(c: Control) -> Control:
	content.add_child(c)
	if _first_row == null and c.focus_mode != Control.FOCUS_NONE:
		_first_row = c
	return c


func _sel(title_key: String, opts: Array, idx: int, cb: Callable, reason_option := "") -> OptionSelector:
	var s := OptionSelector.new().setup(tr(title_key), opts, idx)
	s.value_changed.connect(cb)
	if reason_option != "":
		var why := Settings.unsupported_reason(reason_option)
		if why != "":
			s.set_disabled_reason(tr(why))
	_add(s)
	return s


func _toggle(title_key: String, section: String, key: String, reason_option := "") -> CheckButton:
	var t := make_toggle(tr(title_key), bool(Settings.get_value(section, key, false)), func(on): Settings.set_value(section, key, on))
	if reason_option != "":
		var why := Settings.unsupported_reason(reason_option)
		if why != "":
			t.disabled = true
			t.tooltip_text = tr(why)
			t.text = "%s — %s" % [tr(title_key), tr(why)]
	_add(t)
	return t


func _slider(title_key: String, section: String, key: String, min_v: float, max_v: float, step_v: float, fmt := "%d%%", scale := 100.0) -> PanelContainer:
	var p := make_slider(tr(title_key), float(Settings.get_value(section, key, 0.0)), min_v, max_v, step_v, func(v): Settings.set_value(section, key, v), fmt, scale)
	content.add_child(p)
	var s: HSlider = p.get_meta("slider")
	if _first_row == null:
		_first_row = s
	return p


func _heading(key: String) -> void:
	var l := Label.new()
	l.text = tr(key)
	l.theme_type_variation = &"Heading"
	l.add_theme_font_size_override("font_size", 28)
	content.add_child(l)


# --- Tabs ---------------------------------------------------------------------

func _graphics() -> void:
	var g: Dictionary = Settings.values.graphics
	var presets := ["low", "medium", "high"]
	var opts := [tr("SET_PRESET_LOW"), tr("SET_PRESET_MEDIUM"), tr("SET_PRESET_HIGH")]
	var pidx := presets.find(String(g.preset))
	if pidx < 0:
		opts.append(tr("SET_PRESET_CUSTOM"))
		pidx = 3
	_sel("SET_PRESET", opts, pidx, func(i):
		if i < 3:
			Settings.apply_preset(presets[i])
			call_deferred("_show_tab", 0))
	_slider("SET_RES_SCALE", "graphics", "resolution_scale", 0.5, 1.0, 0.05)
	var fps_vals := [30, 60, 90, 120, 0]
	_sel("SET_FPS_CAP", ["30", "60", "90", "120", tr("SET_FPS_UNLIMITED")], maxi(fps_vals.find(int(g.fps_cap)), 1), func(i): Settings.set_value("graphics", "fps_cap", fps_vals[i]))
	_sel("SET_MSAA", [tr("OPT_OFF"), "2×", "4×"], int(g.msaa), func(i): Settings.set_value("graphics", "msaa", i), "msaa")
	_toggle("SET_FXAA", "graphics", "fxaa")
	_sel("SET_SHADOWS", [tr("SET_SHADOWS_OFF"), tr("SET_SHADOWS_LOW"), tr("SET_SHADOWS_MED"), tr("SET_SHADOWS_HIGH")], int(g.shadows), func(i): Settings.set_value("graphics", "shadows", i))
	_slider("SET_EFFECTS", "graphics", "effects_density", 0.0, 1.0, 0.05)
	_sel("SET_DECOR", [tr("SET_DECOR_0"), tr("SET_DECOR_1"), tr("SET_DECOR_2")], int(g.decor_distance), func(i): Settings.set_value("graphics", "decor_distance", i))
	_sel("SET_TEXTURE", [tr("SET_PRESET_LOW"), tr("SET_PRESET_MEDIUM"), tr("SET_PRESET_HIGH")], int(g.texture_detail), func(i): Settings.set_value("graphics", "texture_detail", i))
	_toggle("SET_SSAO", "graphics", "ssao", "ssao")
	_toggle("SET_BLOOM", "graphics", "bloom")
	_toggle("SET_MOTION_BLUR", "graphics", "motion_blur")
	_toggle("SET_DYN_RES", "graphics", "dynamic_resolution", "dynamic_resolution")
	_slider("SET_BRIGHTNESS", "graphics", "brightness", 0.6, 1.5, 0.05)
	content.add_child(_brightness_calibration())
	_toggle("SET_VSYNC", "graphics", "vsync", "vsync")
	var wm := _sel("SET_WINDOW_MODE", [tr("SET_WINDOWED"), tr("SET_FULLSCREEN")], 1 if g.window_mode == "fullscreen" else 0, func(i): _change_display("window_mode", "fullscreen" if i == 1 else "windowed"), "window_mode")
	wm.name = "WindowMode"


func _brightness_calibration() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	for c in [Color(0.06, 0.06, 0.07), Color(0.12, 0.12, 0.13), Color(0.5, 0.5, 0.5), Color(0.92, 0.92, 0.92)]:
		var r := ColorRect.new()
		r.color = c
		r.custom_minimum_size = Vector2(56, 40)
		h.add_child(r)
	var l := Label.new()
	l.text = tr("SET_BRIGHTNESS_HINT")
	l.theme_type_variation = &"Dim"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h


func _audio() -> void:
	_slider("SET_MASTER", "audio", "master", 0.0, 1.0, 0.05)
	_slider("SET_MUSIC", "audio", "music", 0.0, 1.0, 0.05)
	_slider("SET_ENGINE", "audio", "engine", 0.0, 1.0, 0.05)
	_slider("SET_SFX", "audio", "sfx", 0.0, 1.0, 0.05)
	_slider("SET_UI_VOL", "audio", "ui", 0.0, 1.0, 0.05)
	_toggle("SET_MUTE", "audio", "mute")
	_toggle("SET_BG_AUDIO", "audio", "background_audio")


func _controls() -> void:
	var c: Dictionary = Settings.values.controls
	_sel("SET_TOUCH_STEER", [tr("SET_TOUCH_BUTTONS"), tr("SET_TOUCH_TILT")], 1 if c.touch_steer_mode == "tilt" else 0, func(i): Settings.set_value("controls", "touch_steer_mode", "tilt" if i == 1 else "buttons"))
	_slider("SET_TILT_SENS", "controls", "tilt_sensitivity", 0.5, 2.0, 0.1)
	_toggle("SET_AUTO_ACCEL", "controls", "touch_auto_accelerate")
	_slider("SET_TOUCH_SIZE", "controls", "touch_scale", 0.7, 1.5, 0.05)
	_slider("SET_TOUCH_OPACITY", "controls", "touch_opacity", 0.2, 1.0, 0.05)
	_sel("SET_TOUCH_LAYOUT", [tr("SET_LAYOUT_DEFAULT"), tr("SET_LAYOUT_SWAPPED")], 1 if c.touch_layout == "swapped" else 0, func(i): Settings.set_value("controls", "touch_layout", "swapped" if i == 1 else "default"))
	_slider("SET_TOUCH_OFFSET_X", "controls", "touch_offset_x", -0.1, 0.1, 0.01, "%+d%%")
	_slider("SET_TOUCH_OFFSET_Y", "controls", "touch_offset_y", -0.1, 0.1, 0.01, "%+d%%")
	_slider("SET_DEADZONE", "controls", "deadzone", 0.05, 0.6, 0.01)
	_slider("SET_STEER_SENS", "controls", "steer_sensitivity", 0.5, 1.5, 0.05)
	_toggle("SET_VIBRATION", "controls", "vibration")
	_heading("SET_REMAP")
	_remap_label = Label.new()
	_remap_label.theme_type_variation = &"Dim"
	_remap_label.text = ""
	content.add_child(_remap_label)
	var pad_style := InputActions.pad_style_for_device(0) if Input.get_connected_joypads().size() > 0 else "xbox"
	for action in InputActions.GAMEPLAY_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := Label.new()
		l.text = tr("ACTION_%s" % action)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var key_desc := _binding_for(action, "key")
		var pad_desc := _binding_for(action, "pad")
		for slot in 2:
			var b := Button.new()
			var d: Array = key_desc if slot == 0 else pad_desc
			b.text = InputActions.describe_descriptor(d, pad_style) if not d.is_empty() else "—"
			b.custom_minimum_size = Vector2(200, 54)
			var act: StringName = action
			var sl := slot
			b.pressed.connect(func(): _begin_remap(act, sl))
			row.add_child(b)
			if _first_row == null:
				_first_row = b
		content.add_child(row)
	content.add_child(make_button(tr("SET_RESET_BINDINGS"), func():
		Settings.reset_bindings()
		_show_tab(2)))


func _binding_for(action: StringName, kind: String) -> Array:
	for ev in InputMap.action_get_events(action):
		var d := InputActions.event_to_descriptor(ev)
		if d.is_empty():
			continue
		if kind == "key" and d[0] == "key":
			return d
		if kind == "pad" and (d[0] == "joy_button" or d[0] == "joy_axis"):
			return d
	return []


func _begin_remap(action: StringName, slot: int) -> void:
	_remap_action = action
	_remap_slot = slot
	_remap_label.text = "%s: %s" % [tr("ACTION_%s" % action), tr("SET_REMAP_PRESS")]
	scroll.scroll_vertical = 0


func _input(event: InputEvent) -> void:
	if _remap_action == &"":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_remap_action = &""
			_remap_label.text = ""
			get_viewport().set_input_as_handled()
			return
		if _remap_slot == 0:
			_apply_remap(event)
			get_viewport().set_input_as_handled()
	elif _remap_slot == 1 and ((event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.6)):
		_apply_remap(event)
		get_viewport().set_input_as_handled()


func _apply_remap(event: InputEvent) -> void:
	var action := _remap_action
	_remap_action = &""
	var keep: Array[InputEvent] = []
	for ev in InputMap.action_get_events(action):
		var is_key := ev is InputEventKey
		if (_remap_slot == 0 and is_key) or (_remap_slot == 1 and not is_key):
			continue # replace this slot's bindings
		keep.append(ev)
	var new_ev: InputEvent
	if event is InputEventKey:
		var k := InputEventKey.new()
		k.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		new_ev = k
	elif event is InputEventJoypadButton:
		var jb := InputEventJoypadButton.new()
		jb.button_index = event.button_index
		jb.device = -1
		new_ev = jb
	else:
		var jm := InputEventJoypadMotion.new()
		jm.axis = event.axis
		jm.axis_value = signf(event.axis_value)
		jm.device = -1
		new_ev = jm
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, new_ev)
	for ev in keep:
		InputMap.action_add_event(action, ev)
	Settings.save_bindings_from_inputmap()
	AudioManager.play_ui("ui_confirm")
	call_deferred("_show_tab", 2)


func _gameplay() -> void:
	var gp: Dictionary = Settings.values.gameplay
	var diffs := ["easy", "medium", "hard"]
	_sel("SET_DIFFICULTY", [tr("DIFF_EASY"), tr("DIFF_MEDIUM"), tr("DIFF_HARD")], diffs.find(String(gp.difficulty)), func(i): Settings.set_value("gameplay", "difficulty", diffs[i]))
	_toggle("SET_STEER_ASSIST", "gameplay", "steer_assist")
	_toggle("SET_ACCEL_ASSIST", "gameplay", "accel_assist")
	_sel("SET_CAMERA_DIST", [tr("SET_CAM_NEAR"), tr("SET_CAM_NORMAL"), tr("SET_CAM_FAR")], int(gp.camera_distance), func(i): Settings.set_value("gameplay", "camera_distance", i))
	_toggle("SET_SPEEDO", "gameplay", "speedometer")
	_toggle("SET_CATCHUP", "gameplay", "catchup_assist")
	var langs := ["az", "en"]
	_sel("SET_LANGUAGE", ["Azərbaycan", "English"], langs.find(String(gp.language)), func(i):
		Settings.set_value("gameplay", "language", langs[i])
		call_deferred("_rebuild_after_language"))
	if not overlay_mode:
		content.add_child(make_button(tr("SET_TUTORIAL_REPLAY"), func():
			Game.race_config.mode = "tutorial"
			Game.race_config.kart_id = SaveManager.get_selected_kart()
			Game.race_config.paint = SaveManager.get_paint(Game.race_config.kart_id)
			Game.race_config.laps = 1
			Game.race_config.ai_count = 0
			Game.race_config.items = false
			Game.start_loading_race()))


func _access() -> void:
	_slider("SET_UI_SCALE", "accessibility", "ui_scale", 0.8, 1.4, 0.05)
	_slider("SET_SHAKE", "accessibility", "camera_shake", 0.0, 1.0, 0.05)
	_toggle("SET_REDUCED_FLASH", "accessibility", "reduced_flashing")
	_toggle("SET_SUBTITLES", "accessibility", "subtitles")
	_toggle("SET_HIGH_CONTRAST", "accessibility", "high_contrast")


func _rebuild_after_language() -> void:
	# Labels were created with tr(); rebuild so every string updates.
	if title_label:
		title_label.text = tr(screen_title_key)
	if back_button:
		back_button.text = "‹  " + tr("MENU_BACK")
	for i in tab_buttons.size():
		tab_buttons[i].text = tr(TABS[i])
	_show_tab(tab)


# --- Safety dialogs ---------------------------------------------------------------

func _change_display(key: String, value) -> void:
	_revert_values = {key: Settings.get_value("graphics", key)}
	Settings.set_value("graphics", key, value)
	_show_modal(tr("SET_KEEP_DISPLAY"), tr("SET_KEEP"), tr("SET_REVERT"), func(keep):
		if not keep:
			for k in _revert_values.keys():
				Settings.set_value("graphics", k, _revert_values[k])
		_show_tab(0), 10.0)


func _confirm_restore() -> void:
	_show_modal(tr("SET_RESTORE_CONFIRM"), tr("SET_YES"), tr("SET_NO"), func(yes):
		if yes:
			Settings.restore_defaults()
			_rebuild_after_language(), -1.0)


## Modal with optional auto-cancel countdown (display safety).
func _show_modal(text: String, yes_text: String, no_text: String, cb: Callable, timeout: float) -> void:
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(560, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var countdown := Label.new()
	countdown.theme_type_variation = &"Dim"
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown.visible = timeout > 0.0
	v.add_child(countdown)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var close := func(result: bool):
		if _modal:
			_modal.queue_free()
			_modal = null
		cb.call(result)
	var yes := Button.new()
	yes.text = yes_text
	yes.custom_minimum_size = Vector2(200, 62)
	yes.pressed.connect(func(): close.call(true))
	h.add_child(yes)
	var no := Button.new()
	no.text = no_text
	no.custom_minimum_size = Vector2(200, 62)
	no.pressed.connect(func(): close.call(false))
	h.add_child(no)
	root.add_child(_modal)
	if timeout > 0.0:
		no.grab_focus()
	else:
		yes.grab_focus()
	if timeout > 0.0:
		_revert_timer = timeout
		var t := Timer.new()
		t.wait_time = 0.25
		t.process_mode = Node.PROCESS_MODE_ALWAYS
		_modal.add_child(t)
		t.timeout.connect(func():
			_revert_timer -= 0.25
			countdown.text = tr("SET_REVERTING_IN") % int(ceil(_revert_timer))
			if _revert_timer <= 0.0:
				close.call(false))
		t.start()
		countdown.text = tr("SET_REVERTING_IN") % int(ceil(timeout))
