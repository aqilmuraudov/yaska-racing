class_name LessonDirector
extends Node
## 0.13.0 "İlk dərs": a ~30 s wordless first lesson on the real track.
## Three steps, each shown with the tap-hand (TapHint) on the real touch
## buttons (sentences only for keyboard / controller):
##   STEER - tap left and right (the hand alternates);
##   DRIFT - hold DRIFT, then let go (a ring fills);
##   ITEM  - a nitro is given; tap the item button.
## A step ends when the child does it, or after a few seconds anyway (no
## frustration). Three dots at the top fill with a pop; at the end a big
## "Əla!" and the game goes to mode select. Remembered (tutorial flag
## "lesson_done"), so the first "Oyna" opens it only once.

signal step_changed(step: int)
signal finished

enum Step { STEER, DRIFT, ITEM, DONE }
const TIMEOUTS := {Step.STEER: 9.0, Step.DRIFT: 11.0, Step.ITEM: 9.0}
const START_DELAY := 0.8 ## s after GO before the first hint
const END_DELAY := 2.6 ## s on the "Əla!" before leaving
const FLAG := "lesson_done"

var race: RaceManager
var kart: KartController
var step: int = Step.STEER
var step_time := 0.0
var done_by_player: Array[bool] = [false, false, false]
var _seen_left := false
var _seen_right := false
var _drifted := false
var _started := false
var _end_t := -1.0
var dots: HBoxContainer
var leave_to_menu := true ## tests turn this off


func setup(p_race: RaceManager) -> void:
	race = p_race
	kart = race.player.kart
	# 0.14.2: the lesson is shown once per profile even if it is left early
	# (pause → menu, or the lap ends first); owner report: it kept coming back.
	if not race.headless_test:
		SaveManager.set_tutorial_flag(FLAG, true)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	kart.drift_boost.connect(func(_t, _p): _drifted = true)
	kart.boost_started.connect(func(src): if String(src).begins_with("drift"): _drifted = true)
	if race.hud and "_hints_on" in race.hud:
		race.hud._hints_on = false # the lesson replaces the first-race sentences
	if race.hud:
		_build_dots()
	if race.kids_mode():
		step = Step.DRIFT # the kart steers by itself in kids mode
		done_by_player[0] = true


func _build_dots() -> void:
	dots = HBoxContainer.new()
	dots.name = "LessonDots"
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.add_theme_constant_override("separation", 18)
	dots.set_anchors_preset(Control.PRESET_CENTER_TOP)
	dots.position = Vector2(-75, 108)
	for i in 3:
		var d := LessonDot.new()
		d.custom_minimum_size = Vector2(38, 38)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(d)
	race.hud.root.add_child(dots)
	_refresh_dots()


func _refresh_dots() -> void:
	if dots == null:
		return
	for i in 3:
		var d: LessonDot = dots.get_child(i)
		d.filled = i < step or step == Step.DONE
		d.current = i == step
		d.queue_redraw()


func _process(delta: float) -> void:
	if race == null or race.state != RaceManager.RaceState.RACING:
		if _end_t >= 0.0:
			_tick_end(delta)
		return
	step_time += delta
	if not _started:
		if step_time < START_DELAY:
			return
		_started = true
		_show_hint()
	match step:
		Step.STEER:
			var s := kart.input.steer
			_seen_left = _seen_left or s < -0.5
			_seen_right = _seen_right or s > 0.5
			if _seen_left and _seen_right:
				_complete(true)
		Step.DRIFT:
			if _drifted:
				_complete(true)
		Step.ITEM:
			if kart.item == &"" and step_time > 0.3:
				_complete(true)
	if step != Step.DONE and step_time > float(TIMEOUTS.get(step, 10.0)):
		_complete(false)
	if _end_t >= 0.0:
		_tick_end(delta)


func _show_hint() -> void:
	var hud = race.hud
	match step:
		Step.STEER:
			if hud and not hud.show_tap_hint(["steer_left", "steer_right"], "alternate", 99.0):
				hud.show_message(tr("HINT_STEER"), "info")
		Step.DRIFT:
			if hud and not hud.show_tap_hint("drift", "hold", 99.0):
				hud.show_message(tr("HINT_DRIFT"), "info")
		Step.ITEM:
			kart.give_item(&"turbo", 0.0)
			if hud and not hud.show_tap_hint("item", "tap", 99.0):
				hud.show_message(tr("HINT_ITEM"), "info")


func _complete(by_player: bool) -> void:
	if step >= Step.DONE:
		return
	done_by_player[step] = by_player
	if race.hud and is_instance_valid(race.hud.tap_hint):
		race.hud.tap_hint.dismiss()
	if by_player:
		AudioManager.play_ui("ui_confirm") # existing SFX-bus UI sound
	step += 1
	step_time = 0.0
	_drifted = false
	_refresh_dots()
	if dots and step - 1 < 3:
		var d: Control = dots.get_child(step - 1)
		d.pivot_offset = d.custom_minimum_size * 0.5
		d.scale = Vector2.ONE * 1.5
		d.create_tween().tween_property(d, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	step_changed.emit(step)
	if step == Step.DONE:
		if race.hud:
			race.hud.show_message("★ " + tr("LESSON_DONE") + " ★", "good")
		SaveManager.set_tutorial_flag(FLAG, true)
		SaveManager.save_profile()
		_end_t = 0.0
	else:
		_show_hint()


func _tick_end(delta: float) -> void:
	_end_t += delta
	if _end_t >= END_DELAY:
		_end_t = -1.0
		finished.emit()
		if leave_to_menu:
			Game.reset_series()
			Game.goto(Game.State.MODE_SELECT)


## One progress dot: hollow white ring, a brighter ring for the current
## step, solid yellow when done.
class LessonDot:
	extends Control
	var filled := false
	var current := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(c, r, Color(UITheme.INK, 0.55))
		if filled:
			draw_circle(c, r - 2.0, UITheme.YELLOW)
		draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 1.0 if (filled or current) else 0.5), 4.0, true)

