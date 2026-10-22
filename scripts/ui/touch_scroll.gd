class_name TouchScroll
extends Node
## Finger (and mouse) drag scrolling for a ScrollContainer whose rows are
## buttons, sliders and selectors. Those rows normally swallow the touch, so
## a drag that starts on them would never scroll. This helper watches input
## *before* the GUI: once a press moves vertically past a small threshold it
## becomes a scroll gesture, the control under the finger gets a cancelling
## release (so no accidental tap/slider change), and motion scrolls the list
## with a short inertial fling.

const THRESHOLD := 14.0
const FRICTION := 5.0
const CANCEL_POS := Vector2(-10000, -10000)

var scroll: ScrollContainer
var _pressed := false
var _dragging := false
var _start := Vector2.ZERO
var _velocity := 0.0
var _last_time := 0


static func attach(sc: ScrollContainer) -> TouchScroll:
	var ts := TouchScroll.new()
	ts.scroll = sc
	ts.process_mode = Node.PROCESS_MODE_ALWAYS
	sc.add_child(ts)
	return ts


func _input(event: InputEvent) -> void:
	if scroll == null or not scroll.is_visible_in_tree():
		return
	var pos := Vector2.ZERO
	var kind := ""
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		pos = event.position
		kind = "press" if event.pressed else "release"
	elif event is InputEventScreenDrag:
		if event.index != 0:
			return
		pos = event.position
		kind = "move"
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position == CANCEL_POS:
			return # our own cancelling release: let the GUI have it
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			# Mouse emulated from touch: swallow it while we own the gesture.
			if _dragging:
				get_viewport().set_input_as_handled()
			return
		pos = event.position
		kind = "press" if event.pressed else "release"
	elif event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			if _dragging:
				get_viewport().set_input_as_handled()
			return
		if not _pressed:
			return
		pos = event.position
		kind = "move"
	else:
		return
	var local := scroll.get_global_transform_with_canvas().affine_inverse() * pos
	match kind:
		"press":
			if Rect2(Vector2.ZERO, scroll.size).has_point(local):
				_pressed = true
				_dragging = false
				_start = pos
				_velocity = 0.0
				_last_time = Time.get_ticks_msec()
		"move":
			if not _pressed:
				return
			if not _dragging and absf(pos.y - _start.y) > THRESHOLD and absf(pos.y - _start.y) > absf(pos.x - _start.x):
				_dragging = true
				_start = pos
				_cancel_gui_press()
			if _dragging:
				var dy: float = event.relative.y if "relative" in event else 0.0
				scroll.scroll_vertical -= int(dy)
				var now := Time.get_ticks_msec()
				var dt := maxf((now - _last_time) / 1000.0, 0.001)
				_velocity = lerpf(_velocity, -dy / dt, 0.4)
				_last_time = now
				get_viewport().set_input_as_handled()
		"release":
			if _dragging:
				get_viewport().set_input_as_handled()
			_pressed = false
			_dragging = false


## The control that received the initial press gets a release far outside
## its rect: buttons do not fire and sliders stop grabbing.
func _cancel_gui_press() -> void:
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = CANCEL_POS
	up.global_position = up.position
	Input.parse_input_event(up)
	scroll.get_viewport().gui_release_focus()


func _process(delta: float) -> void:
	if _dragging or absf(_velocity) < 5.0 or scroll == null:
		return
	scroll.scroll_vertical += int(_velocity * delta)
	_velocity = lerpf(_velocity, 0.0, 1.0 - exp(-FRICTION * delta))
