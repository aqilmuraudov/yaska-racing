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
	await _tap_text("‹  " + tr("MENU_BACK"))
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
	await _tap_text("‹  " + tr("MENU_BACK"))
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


## Finger drag on the settings list must scroll it.
func _drag_scroll_check() -> void:
	var scr := get_tree().current_scene
	var sc: ScrollContainer = scr.get("scroll") if scr else null
	if sc == null:
		_check(false, "settings scroll container found")
		return
	var r := sc.get_global_rect()
	var start := r.get_center() + Vector2(0, r.size.y * 0.3)
	var before := sc.scroll_vertical
	var values_before := JSON.stringify(Settings.values)
	await _touch(start, true)
	for i in 12:
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = start - Vector2(0, (i + 1) * 20)
		d.relative = Vector2(0, -20)
		Input.parse_input_event(d)
		await get_tree().process_frame
	await _touch(start - Vector2(0, 240), false)
	await _wait(0.2)
	_check(sc.scroll_vertical > before + 50, "finger drag scrolls settings (%d → %d)" % [before, sc.scroll_vertical])
	_check(JSON.stringify(Settings.values) == values_before, "scroll gesture did not change any setting")
