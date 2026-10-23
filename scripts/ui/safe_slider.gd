class_name SafeSlider
extends HSlider
## Slider for scrollable lists. A stock HSlider jumps to the press position
## on press, so a vertical scroll gesture starting on it changed the value.
## This one changes only on a tap (release without moving) or once the finger
## clearly moves sideways; vertical motion is left to TouchScroll.

const SLOP := 12.0

var _pressing := false
var _horizontal := false
var _start := Vector2.ZERO


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			_pressing = true
			_horizontal = false
			_start = event.position
			grab_focus()
		elif _pressing:
			_pressing = false
			var inside := Rect2(Vector2.ZERO, size).has_point(event.position)
			if inside and (_horizontal or event.position.distance_to(_start) <= SLOP):
				_set_from_x(event.position.x)
	elif event is InputEventMouseMotion and _pressing:
		accept_event()
		var d: Vector2 = event.position - _start
		if not _horizontal and absf(d.x) > SLOP and absf(d.x) > absf(d.y):
			_horizontal = true
		if _horizontal:
			_set_from_x(event.position.x)


func _set_from_x(x: float) -> void:
	var grab_w := 30.0
	var ratio := clampf((x - grab_w * 0.5) / maxf(size.x - grab_w, 1.0), 0.0, 1.0)
	value = min_value + ratio * (max_value - min_value)
