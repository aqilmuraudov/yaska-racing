class_name TutorialDirector
extends CanvasLayer
## 0.15.2 "Öyrən" (owner): opened only from the button under the race modes,
## never by itself. A guided tour of every race button on the real seafront
## track: a big card (the button's picture, what it does) and a pulsing ring
## with an arrow on the real touch button. A step moves on when the player
## uses that button; look-only steps (and any step after a while) have
## "Davam". Keyboard / controller players see the key names instead.

enum Step { GAS, STEER, BRAKE, DRIFT, BOOST, ITEM, CAMERA, PAUSE, DONE }

## step -> [title key, text key, icon, touch button ids]
const INFO := {
	Step.GAS: ["TUT2_GAS", "TUT2_GAS_TEXT", "hud_gas", ["gas"]],
	Step.STEER: ["TUT2_STEER", "TUT2_STEER_TEXT", "steering", ["steer_left", "steer_right"]],
	Step.BRAKE: ["TUT2_BRAKE", "TUT2_BRAKE_TEXT", "hud_brake", ["brake"]],
	Step.DRIFT: ["TUT2_DRIFT", "TUT2_DRIFT_TEXT", "hud_drift", ["drift"]],
	Step.BOOST: ["TUT2_BOOST", "TUT2_BOOST_TEXT", "hud_nitro", ["drift"]],
	Step.ITEM: ["TUT2_ITEM", "TUT2_ITEM_TEXT", "star", ["item"]],
	Step.CAMERA: ["TUT2_CAMERA", "TUT2_CAMERA_TEXT", "hud_camera", ["camera"]],
	Step.PAUSE: ["TUT2_PAUSE", "TUT2_PAUSE_TEXT", "gear", []],
	Step.DONE: ["TUT2_DONE", "TUT2_DONE_TEXT", "trophy", []],
}
const KEYS := {Step.GAS: InputActions.ACCELERATE, Step.BRAKE: InputActions.BRAKE, Step.CAMERA: InputActions.CAMERA,
	Step.ITEM: InputActions.USE_ITEM}
const NEXT_AFTER := 12.0 ## "Davam" appears on any step after this long
const STEP_COUNT := 8

var race: RaceManager
var kart: KartController
var step: Step = Step.GAS
var step_time := 0.0
var _steer_seen := {}
var _was := {}
var panel: PanelContainer
var icon_rect: TextureRect
var count_label: Label
var title_label: Label
var text_label: Label
var keys_label: Label
var next_btn: Button
var exit_btn: Button
var pointer: Control


func setup(p_race: RaceManager) -> void:
	race = p_race
	kart = race.player.kart
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	if race.kids_mode():
		# Every button is shown in the lesson (Kids controls hide them).
		if race.hud and race.hud.has_method("turn_off_kids_mode"):
			race.hud.turn_off_kids_mode()
		else:
			race.set_kids_mode(false)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	pointer = Pointer.new()
	pointer.director = self
	pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pointer)
	panel = PanelContainer.new()
	panel.name = "TutorialCard"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.custom_minimum_size = Vector2(780, 0)
	panel.position = Vector2(-390, 112)
	panel.add_theme_stylebox_override("panel", UITheme.art_box("panel_card", 22, 16))
	root.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	panel.add_child(h)
	var disc := PanelContainer.new()
	disc.add_theme_stylebox_override("panel", UITheme.rounded(UITheme.YELLOW, 60, 5, UITheme.INK, 14))
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(disc)
	icon_rect = TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(92, 92)
	disc.add_child(icon_rect)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	count_label = GameUI.label("", UITheme.FS_CAPTION, UITheme.TEXT, 5)
	v.add_child(count_label)
	title_label = GameUI.label("", UITheme.FS_TITLE, UITheme.YELLOW, 10)
	title_label.name = "Title"
	v.add_child(title_label)
	text_label = GameUI.label("", UITheme.FS_H2, UITheme.TEXT, 6, false)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(text_label)
	keys_label = GameUI.label("", UITheme.FS_BODY, UITheme.GOLD, 5)
	keys_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(keys_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	exit_btn = Button.new()
	exit_btn.name = "Exit"
	exit_btn.text = tr("TUT2_EXIT")
	exit_btn.focus_mode = Control.FOCUS_NONE
	exit_btn.custom_minimum_size = Vector2(170, UITheme.H_BTN_SMALL)
	UITheme.style_button(exit_btn, "blue", UITheme.FS_BTN)
	exit_btn.pressed.connect(_finish)
	row.add_child(exit_btn)
	next_btn = Button.new()
	next_btn.name = "Next"
	next_btn.text = tr("TUT2_NEXT")
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.custom_minimum_size = Vector2(220, UITheme.H_BTN_SMALL)
	UITheme.style_button(next_btn, "lime", UITheme.FS_BTN)
	next_btn.pressed.connect(next)
	row.add_child(next_btn)
	kart.drift_started.connect(func(_d): if step == Step.DRIFT: next())
	kart.drift_boost.connect(func(_t, _p): if step == Step.BOOST: next())
	kart.item_changed.connect(func(it): if step == Step.ITEM and it == &"": next())
	_refresh()


func reset() -> void:
	_set_step(Step.GAS)


## Next step (also the "Davam" button). On the last card it leaves.
func next() -> void:
	if step == Step.DONE:
		_finish()
		return
	var s := int(step) + 1
	_set_step(s as Step)


func _set_step(s: Step) -> void:
	step = s
	step_time = 0.0
	_steer_seen.clear()
	_was.clear()
	AudioManager.play("tutorial_step", -2.0)
	if step == Step.ITEM:
		kart.item = &"turbo"
		kart.item_changed.emit(kart.item)
	if step == Step.DONE:
		SaveManager.set_tutorial_flag("drift_done", true)
		SaveManager.set_tutorial_flag(LessonDirector.FLAG, true)
	_refresh()
	UITheme.pop_in(panel)


func touch_on() -> bool:
	return race.hud != null and race.hud.touch != null and race.hud.touch.visible


func auto_gas() -> bool:
	return bool(Settings.get_value("controls", "touch_auto_accelerate", true)) and touch_on()


func _refresh() -> void:
	var info: Array = INFO[step]
	icon_rect.texture = UITheme.icon(info[2])
	title_label.text = tr(info[0])
	var key: String = info[1]
	if step == Step.GAS and auto_gas():
		key = "TUT2_GAS_AUTO_TEXT"
	if step == Step.BOOST and not _easy():
		key = "TUT2_BOOST_PRESS_TEXT"
	text_label.text = tr(key)
	count_label.text = "" if step == Step.DONE else "%d / %d" % [int(step) + 1, STEP_COUNT]
	keys_label.text = "" if touch_on() else _keys_hint()
	next_btn.text = tr("TUT2_START_RACE") if step == Step.DONE else tr("TUT2_NEXT")
	exit_btn.visible = step != Step.DONE
	_update_next()


func _update_next() -> void:
	next_btn.visible = step in [Step.PAUSE, Step.DONE] or (step == Step.GAS and auto_gas()) or step_time >= NEXT_AFTER


func _easy() -> bool:
	return kart.easy_drift or bool(Settings.get_value("controls", "easy_drift", true))


func _keys_hint() -> String:
	match step:
		Step.STEER:
			return "%s / %s" % [_binding_text(InputActions.STEER_LEFT), _binding_text(InputActions.STEER_RIGHT)]
		Step.DRIFT, Step.BOOST:
			return _binding_text(InputActions.BOOST if step == Step.BOOST and not _easy() else InputActions.DRIFT)
		Step.PAUSE:
			return _binding_text(InputActions.PAUSE)
	if KEYS.has(step):
		return _binding_text(KEYS[step])
	return ""


func _binding_text(action: StringName) -> String:
	var parts: Array[String] = []
	for ev in InputMap.action_get_events(action):
		var d := InputActions.event_to_descriptor(ev)
		if d.is_empty():
			continue
		var txt := InputActions.describe_descriptor(d)
		if not parts.has(txt):
			parts.append(txt)
		if parts.size() >= 2:
			break
	return " / ".join(parts)


## Screen points the ring marks for this step (touch buttons, or the pause
## button of the HUD).
func targets() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not touch_on():
		return out
	if step == Step.PAUSE:
		var pb: Control = race.hud.pause_button
		if pb and pb.is_visible_in_tree():
			out.append(pb.get_global_rect().get_center())
		return out
	var ids: Array = INFO[step][3]
	if step == Step.GAS and auto_gas():
		return out
	if step == Step.BOOST and not _easy():
		ids = ["boost"]
	var tc: TouchControls = race.hud.touch
	for b in tc.buttons:
		if b.visible and b.id in ids:
			out.append(tc.get_global_transform_with_canvas() * b.center)
	return out


func target_radius() -> float:
	if step == Step.PAUSE or not touch_on():
		return 54.0
	var ids: Array = INFO[step][3]
	for b in race.hud.touch.buttons:
		if b.id in ids:
			return b.radius * race.hud.touch.get_global_transform_with_canvas().get_scale().x + 14.0
	return 60.0


func _pressed_now(action: StringName) -> bool:
	var on := Input.is_action_pressed(action)
	var fresh := on and not bool(_was.get(action, false))
	_was[action] = on
	return fresh


func _process(delta: float) -> void:
	if get_tree().paused and step != Step.PAUSE:
		return
	step_time += delta
	_update_next()
	match step:
		Step.GAS:
			if auto_gas():
				if step_time > 4.0 and kart.speed > 6.0:
					next()
			elif _pressed_now(InputActions.ACCELERATE):
				next()
		Step.STEER:
			for a in [InputActions.STEER_LEFT, InputActions.STEER_RIGHT]:
				if Input.is_action_pressed(a):
					_steer_seen[a] = true
			if _steer_seen.size() >= 2:
				next()
		Step.BRAKE:
			if _pressed_now(InputActions.BRAKE):
				next()
		Step.CAMERA:
			if _pressed_now(InputActions.CAMERA):
				next()
	pointer.queue_redraw()


func _finish() -> void:
	SaveManager.set_tutorial_flag("drift_done", true)
	SaveManager.set_tutorial_flag(LessonDirector.FLAG, true)
	race.quit_to_mode_select()


## Pulsing ring + bouncing arrow over the button of the current step.
class Pointer:
	extends Control
	var director: TutorialDirector
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta

	func _draw() -> void:
		if director == null:
			return
		var r := director.target_radius()
		var pulse := 0.5 + 0.5 * sin(t * 6.0)
		for c in director.targets():
			var p := c - get_global_rect().position
			draw_arc(p, r + pulse * 10.0, 0.0, TAU, 48, Color(UITheme.YELLOW, 0.95), 7.0, true)
			draw_arc(p, r + 16.0 + pulse * 14.0, 0.0, TAU, 48, Color(1, 1, 1, 0.45 * (1.0 - pulse)), 4.0, true)
			# Arrow above the ring, bobbing towards it.
			var tip := p + Vector2(0, -r - 18.0 - pulse * 12.0)
			var pts := PackedVector2Array([tip, tip + Vector2(-26, -36), tip + Vector2(-10, -36), tip + Vector2(-10, -70),
				tip + Vector2(10, -70), tip + Vector2(10, -36), tip + Vector2(26, -36)])
			draw_colored_polygon(pts, UITheme.YELLOW)
			var outline := pts.duplicate()
			outline.append(tip)
			draw_polyline(outline, UITheme.INK, 4.0, true)
