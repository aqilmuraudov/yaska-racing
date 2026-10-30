class_name OptionSelector
extends PanelContainer
## "‹ value ›" selector row. One focus stop; ui_left / ui_right change the
## value, the arrow buttons work for touch and mouse. Supports a disabled
## state with an explanation line so unsupported options are never silent.

signal value_changed(index: int)

var label: Label
var value_label: Label
var reason_label: Label
var left_btn: Button
var right_btn: Button
var options: Array = [] # display strings
var index := 0
var disabled := false
var wrap := false
var _normal: StyleBox
var _focus: StyleBox


func setup(title: String, p_options: Array, p_index: int) -> OptionSelector:
	options = p_options
	index = clampi(p_index, 0, maxi(options.size() - 1, 0))
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(0, 64)
	_normal = UITheme.rounded(Color(UITheme.NAVY_LIGHT, 0.55), 18, 2, Color(1, 1, 1, 0.06), 8)
	_focus = UITheme.rounded(Color(UITheme.NAVY_LIGHT, 0.9), 18, 4, UITheme.GOLD, 8)
	add_theme_stylebox_override("panel", _normal)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	label = Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(label)
	left_btn = _arrow("‹")
	left_btn.pressed.connect(func(): step(-1))
	h.add_child(left_btn)
	value_label = Label.new()
	value_label.custom_minimum_size = Vector2(190, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_override("font", UITheme.bold_font())
	value_label.add_theme_color_override("font_color", UITheme.GOLD)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(value_label)
	right_btn = _arrow("›")
	right_btn.pressed.connect(func(): step(1))
	h.add_child(right_btn)
	reason_label = Label.new()
	reason_label.theme_type_variation = &"Dim"
	reason_label.visible = false
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(reason_label)
	focus_entered.connect(func(): add_theme_stylebox_override("panel", _focus))
	focus_exited.connect(func(): add_theme_stylebox_override("panel", _normal))
	_refresh()
	return self


func _arrow(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(UITheme.H_BTN_SMALL, UITheme.H_BTN_SMALL - 8)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", UITheme.FS_H1)
	return b


func set_disabled_reason(reason: String) -> void:
	disabled = reason != ""
	reason_label.text = reason
	reason_label.visible = disabled
	left_btn.disabled = disabled
	right_btn.disabled = disabled
	modulate.a = 0.6 if disabled else 1.0
	_refresh()


func set_index(i: int, emit := false) -> void:
	index = clampi(i, 0, options.size() - 1)
	_refresh()
	if emit:
		value_changed.emit(index)


func step(dir: int) -> void:
	if disabled or options.is_empty():
		return
	var n := index + dir
	if wrap:
		n = posmod(n, options.size())
	n = clampi(n, 0, options.size() - 1)
	if n != index:
		index = n
		_refresh()
		AudioManager.play_ui("ui_move")
		value_changed.emit(index)


func _refresh() -> void:
	if value_label == null:
		return
	value_label.text = str(options[index]) if index < options.size() else ""
	left_btn.disabled = disabled or (not wrap and index <= 0)
	right_btn.disabled = disabled or (not wrap and index >= options.size() - 1)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		step(1)
		accept_event()
