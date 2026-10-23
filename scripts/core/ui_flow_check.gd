class_name UIFlowCheck
extends Node
## Drives the real UI with injected touch taps (not direct function calls)
## to verify navigation the way a player experiences it. Started by the
## debug runner with `--ui-flow`; prints UIFLOW PASS/FAIL lines and quits.

var failures := 0


var _orig_profile := ""
var _orig_settings := ""


func run() -> void:
	# Never touch the player's real profile or settings.
	_orig_profile = SaveManager.save_path
	_orig_settings = Settings.save_path
	SaveManager.save_path = "user://uiflow_profile.json"
	Settings.save_path = "user://uiflow_settings.json"
	SaveManager.load_profile()
	await _wait(1.5)
	await _expect_scene("MainMenu", "boot reaches main menu")
	# Main Menu → Settings → Back
	await _tap_text(tr("MENU_SETTINGS"))
	await _wait(1.0)
	await _expect_scene("SettingsMenu", "settings opens from main menu")
	await _drag_scroll_check()
	await _tap_text(tr("MENU_BACK"))
	await _wait(1.0)
	await _expect_scene("MainMenu", "back returns to main menu")
	# Main Menu → Play → mode → racer → setup → race
	await _tap_text(tr("MENU_PLAY"))
	await _wait(1.0)
	await _tap_text(tr("MODE_QUICK"))
	await _wait(1.0)
	await _expect_scene("RacerSelect", "mode leads to racer selection")
	await _tap_text("Bicok")
	await _wait(0.6)
	_check(get_tree().current_scene.get("current") == 1, "tapping a racer card selects it")
	await _tap_text(tr("MENU_START_RACE"))
	var race: RaceManager = null
	for i in 200:
		await _wait(0.1)
		race = get_tree().current_scene as RaceManager
		if race and race.state == RaceManager.RaceState.RACING:
			break
	_check(race != null and race.state == RaceManager.RaceState.RACING, "race starts from menus")
	if race == null:
		return _finish()
	race.auto_pause_on_focus_loss = false
	# Race → Pause → Settings → Back → Resume
	await _tap_control(race.hud.pause_button)
	await _wait(0.4)
	_check(get_tree().paused and race.hud.pause_menu.visible, "pause button pauses the race")
	var t_paused := race.race_time
	await _tap_text(tr("PAUSE_SETTINGS"))
	await _wait(0.8)
	var ov = race.hud.pause_menu.settings_overlay
	_check(ov != null and is_instance_valid(ov), "settings opens from pause")
	_check(is_equal_approx(race.race_time, t_paused), "race clock frozen while in settings")
	if ov and is_instance_valid(ov):
		ov._show_tab(4)
		await _wait(0.3)
		await scroll_suite(ov.scroll, "paused settings")
		ov._show_tab(0)
		await _wait(0.2)
		# Language switch while paused: text changes at once, race state kept.
		var lang_before := String(Settings.get_value("gameplay", "language", "az"))
		ov._show_tab(3)
		await _wait(0.3)
		await _tap_text("English")
		await _wait(0.4)
		var pm_title: Label = race.hud.pause_menu.find_child("Title", true, false)
		_check(TranslationServer.get_locale().begins_with("en") and pm_title and pm_title.text == "Paused", "language switches live in the paused race (title=%s)" % (pm_title.text if pm_title else "?"))
		_check(ov.title_label.text == "Settings", "settings retranslated immediately")
		_check(is_equal_approx(race.race_time, t_paused) and get_tree().paused, "language change keeps race state")
		await _tap_text("Azərbaycan dili")
		await _wait(0.4)
		_check(pm_title and pm_title.text == "Fasilə", "switching back to Azerbaijani works")
		if lang_before != "az":
			Settings.set_value("gameplay", "language", lang_before)
		ov._show_tab(0)
		await _wait(0.2)
	await _tap_text(tr("MENU_BACK"))
	await _wait(0.5)
	_check(race.hud.pause_menu.settings_overlay == null, "back closes settings")
	_check(get_tree().paused and race.hud.pause_menu.visible, "race still paused after settings")
	await _tap_text(tr("PAUSE_RESUME"))
	await _wait(1.0)
	_check(not get_tree().paused, "resume unpauses")
	_check(race.race_time > t_paused + 0.3, "race clock runs after resume")
	_finish()


func _finish() -> void:
	SafeFile.delete_all(SaveManager.save_path)
	SafeFile.delete_all(Settings.save_path)
	SaveManager.save_path = _orig_profile
	Settings.save_path = _orig_settings
	print("UIFLOW DONE failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check(cond: bool, what: String) -> void:
	print("UIFLOW %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		failures += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _expect_scene(name: String, what: String) -> void:
	var s := get_tree().current_scene
	_check(s != null and s.name == name, "%s (scene=%s)" % [what, s.name if s else "null"])


func _find(node: Node, text: String) -> Control:
	if node is Control and node.is_visible_in_tree():
		if (node is Button and node.text == text) or (node is Label and node.text == text):
			return node
	for c in node.get_children():
		var f := _find(c, text)
		if f:
			return f
	return null


func _tap_text(text: String) -> void:
	var c := _find(get_tree().root, text)
	if c == null:
		_check(false, "control '%s' found" % text)
		return
	# Tap the enclosing button if the text is a label inside a card.
	var target: Control = c
	while target and not (target is BaseButton) and target.get_parent() is Control:
		target = target.get_parent()
	await _tap_control(target if target is BaseButton else c)


func _tap_control(c: Control) -> void:
	var pos := c.get_global_rect().get_center()
	pos = c.get_viewport().get_screen_transform() * pos
	await _touch(pos, true)
	await _wait(0.08)
	await _touch(pos, false)


func _touch(pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = pos
	t.pressed = pressed
	Input.parse_input_event(t)
	await get_tree().process_frame


## Finger drag on the settings list must scroll it. Uses the long developer
## list (debug builds) so there is something to scroll at 720 p.
func _drag_scroll_check() -> void:
	var scr := get_tree().current_scene
	if scr and scr.has_method("_show_tab"):
		scr._show_tab(4)
		await _wait(0.3)
	var sc: ScrollContainer = scr.get("scroll") if scr else null
	if sc == null:
		_check(false, "settings scroll container found")
		return
	await scroll_suite(sc, "settings")
	if scr and scr.has_method("_show_tab"):
		scr._show_tab(0)


## The shared TouchScroll behaviour, driven by injected touches.
func _diff(before: String) -> String:
	var a: Dictionary = JSON.parse_string(before)
	var out := []
	for sec in a.keys():
		if typeof(a[sec]) != TYPE_DICTIONARY:
			continue
		for k in a[sec].keys():
			var va = a[sec][k]
			var vb = Settings.values[sec][k]
			if typeof(vb) in [TYPE_INT, TYPE_FLOAT]:
				vb = float(vb)
			if str(va) != str(vb):
				out.append("%s.%s %s→%s" % [sec, k, a[sec][k], Settings.values[sec][k]])
	return ", ".join(out)


func scroll_suite(sc: ScrollContainer, label: String) -> void:
	var ts: TouchScroll = sc.get_node_or_null("TouchScroll")
	_check(ts != null and sc.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: one shared scroller, built-in drag off" % label)
	var r := sc.get_global_rect()
	var xf := sc.get_viewport().get_screen_transform()
	var values_before := JSON.stringify(Settings.values)
	sc.scroll_vertical = 0
	await _wait(0.1)
	# 1. Slow drag in sub-pixel steps (a phone's stretched canvas): the list
	#    must follow continuously, not stand still.
	var start := r.get_center() + Vector2(0, r.size.y * 0.3)
	await _touch(xf * start, true)
	await _drag_path(xf, start, start - Vector2(0, 20), 4) # past slop
	var y0 := sc.get_v_scroll_bar().value
	await _drag_path(xf, start - Vector2(0, 20), start - Vector2(0, 50), 50) # 0.6 px steps
	var moved := sc.get_v_scroll_bar().value - y0
	_check(absf(moved - 30.0) < 3.0, "%s: slow sub-pixel drag follows the finger (%.1f px of 30)" % [label, moved])
	# 2. Direction change mid-drag follows the finger back.
	var y1 := sc.get_v_scroll_bar().value
	await _drag_path(xf, start - Vector2(0, 50), start - Vector2(0, 30), 10)
	_check(absf((y1 - sc.get_v_scroll_bar().value) - 20.0) < 2.0, "%s: reversing direction scrolls back" % label)
	await _touch(xf * (start - Vector2(0, 30)), false)
	await _wait(0.4)
	_check(JSON.stringify(Settings.values) == values_before, "%s: drags starting over rows change no setting %s" % [label, _diff(values_before)])
	# 3. Flick: the list keeps gliding after release and then stops.
	sc.scroll_vertical = 0
	await _wait(0.1)
	await _touch(xf * start, true)
	await _drag_path(xf, start, start - Vector2(0, 160), 6)
	await _touch(xf * (start - Vector2(0, 160)), false)
	var at_release := sc.get_v_scroll_bar().value
	await _wait(0.15)
	var gliding := sc.get_v_scroll_bar().value
	_check(gliding > at_release + 20.0 and ts.is_gliding(), "%s: flick continues with momentum (%.0f → %.0f)" % [label, at_release, gliding])
	# 4. Touching gliding content stops it immediately and taps nothing.
	var tap_at := r.get_center()
	await _touch(xf * tap_at, true)
	var stopped := sc.get_v_scroll_bar().value
	await _wait(0.08)
	await _touch(xf * tap_at, false)
	await _wait(0.3)
	_check(absf(sc.get_v_scroll_bar().value - stopped) < 2.0, "%s: touch stops the glide" % label)
	_check(JSON.stringify(Settings.values) == values_before, "%s: the stopping touch activated nothing %s" % [label, _diff(values_before)])
	# 5. A plain tap still works (no drag): handled by the screen's own taps.
	sc.scroll_vertical = 0


func _drag_path(xf: Transform2D, from: Vector2, to: Vector2, steps: int) -> void:
	var prev := from
	for i in steps:
		var p := from.lerp(to, float(i + 1) / steps)
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = xf * p
		d.relative = xf.basis_xform(p - prev)
		d.velocity = d.relative * 60.0
		Input.parse_input_event(d)
		prev = p
		await get_tree().process_frame
