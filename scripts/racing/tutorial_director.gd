class_name TutorialDirector
extends CanvasLayer
## Drift School: teaches hop → powerslide → timed boost → chained boosts by
## doing them on the real track, advancing only when the player succeeds.
## Prompts show the actual bindings for keyboard, controller and touch.

enum Step { HOP, DRIFT, BOOST, CHAIN, DONE }

const STEP_KEYS := {Step.HOP: "TUT_HOP", Step.DRIFT: "TUT_DRIFT", Step.BOOST: "TUT_BOOST", Step.CHAIN: "TUT_CHAIN", Step.DONE: "TUT_DONE"}

var race: RaceManager
var kart: KartController
var step: Step = Step.HOP
var _hops := 0
var panel: PanelContainer
var text_label: Label
var hint_label: Label
var progress_label: Label
var skip_btn: Button
var _done_timer := -1.0


func setup(p_race: RaceManager) -> void:
	race = p_race
	kart = race.player.kart
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.custom_minimum_size = Vector2(660, 0)
	panel.position = Vector2(-330, 128)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	progress_label = Label.new()
	progress_label.theme_type_variation = &"Dim"
	v.add_child(progress_label)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 28)
	text_label.add_theme_font_override("font", UITheme.bold_font())
	v.add_child(text_label)
	hint_label = Label.new()
	hint_label.add_theme_color_override("font_color", UITheme.GOLD)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint_label)
	skip_btn = Button.new()
	skip_btn.text = tr("TUT_SKIP")
	skip_btn.custom_minimum_size = Vector2(0, 52)
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.pressed.connect(_finish)
	v.add_child(skip_btn)
	kart.hopped.connect(_on_hop)
	kart.drift_started.connect(func(_d): _advance_if(Step.DRIFT))
	kart.drift_boost.connect(_on_boost)
	_refresh()


func reset() -> void:
	step = Step.HOP
	_hops = 0
	_done_timer = -1.0
	_refresh()


func _on_hop() -> void:
	if step == Step.HOP:
		_hops += 1
		if _hops >= 2:
			_set_step(Step.DRIFT)


func _on_boost(tier: int, _perfect: bool) -> void:
	if step == Step.BOOST:
		_set_step(Step.CHAIN)
	elif step == Step.CHAIN and tier >= 2:
		_set_step(Step.DONE)


func _advance_if(expected: Step) -> void:
	if step == expected:
		_set_step(expected + 1)


func _set_step(s: int) -> void:
	step = s as Step
	AudioManager.play("tutorial_step", -2.0)
	_refresh()
	if step == Step.DONE:
		SaveManager.set_tutorial_flag("drift_done", true)
		_done_timer = 3.0


func _refresh() -> void:
	text_label.text = tr(STEP_KEYS[step])
	progress_label.text = "%d / %d" % [mini(int(step) + 1, 5), 5]
	match step:
		Step.HOP:
			hint_label.text = _binding_hint(InputActions.DRIFT, "TOUCH_DRIFT")
		Step.DRIFT:
			hint_label.text = "%s  +  %s / %s" % [_binding_hint(InputActions.DRIFT, "TOUCH_DRIFT"), _binding_text(InputActions.STEER_LEFT), _binding_text(InputActions.STEER_RIGHT)]
		Step.BOOST, Step.CHAIN:
			hint_label.text = _binding_hint(InputActions.BOOST, "TOUCH_BOOST")
		Step.DONE:
			hint_label.text = ""


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


func _binding_hint(action: StringName, touch_key: String) -> String:
	var t := _binding_text(action)
	if race.player.player_input and race.player.player_input.touch_active:
		t += "  •  " + tr(touch_key)
	return t


func _finish() -> void:
	SaveManager.set_tutorial_flag("drift_done", true)
	race.quit_to_mode_select()


func _process(delta: float) -> void:
	if _done_timer > 0.0:
		_done_timer -= delta
		if _done_timer <= 0.0:
			_finish()
