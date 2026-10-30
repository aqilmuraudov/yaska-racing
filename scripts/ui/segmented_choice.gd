class_name SegmentedChoice
extends HBoxContainer
## Row of large pill buttons, one selected (yellow). Used for every player
## setting: tap an option to choose it; keyboard / controller use left and
## right while the group has focus. Options can be disabled individually with
## a short reason shown by the owning row.

signal value_changed(index: int)

var options: Array = []
var index := 0
var buttons: Array[Button] = []
var _disabled: Array[bool] = []


func setup(p_options: Array, p_index: int, min_width := 96.0) -> SegmentedChoice:
	options = p_options
	index = clampi(p_index, 0, maxi(options.size() - 1, 0))
	add_theme_constant_override("separation", 8)
	focus_mode = Control.FOCUS_ALL
	for i in options.size():
		var b := Button.new()
		b.text = str(options[i])
		b.custom_minimum_size = Vector2(min_width, UITheme.H_BTN_SMALL)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = false
		b.toggle_mode = false
		var idx := i
		b.pressed.connect(func(): choose(idx, true))
		add_child(b)
		buttons.append(b)
		_disabled.append(false)
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	_refresh()
	return self


func set_option_disabled(i: int, disabled: bool) -> void:
	if i >= 0 and i < _disabled.size():
		_disabled[i] = disabled
		_refresh()


func is_option_disabled(i: int) -> bool:
	return i >= 0 and i < _disabled.size() and _disabled[i]


func choose(i: int, from_user := false) -> void:
	if i < 0 or i >= options.size() or is_option_disabled(i):
		if from_user:
			UITheme.bounce(buttons[clampi(i, 0, buttons.size() - 1)], -0.06)
		return
	var changed := i != index
	index = i
	_refresh()
	if from_user:
		AudioManager.play_ui("ui_select" if AudioManager.get_stream("ui_select") else "ui_move")
		UITheme.bounce(buttons[i])
		if changed:
			UITheme.sparkle_burst(self, buttons[i].get_global_rect().get_center(), 5)
	if changed or from_user:
		value_changed.emit(index)


func _refresh() -> void:
	for i in buttons.size():
		var b := buttons[i]
		var color := "yellow" if i == index else "blue"
		UITheme.style_button(b, color, UITheme.FS_BTN_SMALL)
		if _disabled[i]:
			b.disabled = true
		else:
			b.disabled = false
	# Focus ring around the whole group (keyboard / controller).
	modulate = Color(1, 1, 1)
	if has_focus():
		buttons[index].add_theme_stylebox_override("normal", _focus_box())


func _focus_box() -> StyleBox:
	var sb := UITheme.art_box("btn_orange")
	return sb


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		_step(1)
		accept_event()


func _step(dir: int) -> void:
	var n := index + dir
	while n >= 0 and n < options.size() and is_option_disabled(n):
		n += dir
	if n >= 0 and n < options.size():
		choose(n, true)
