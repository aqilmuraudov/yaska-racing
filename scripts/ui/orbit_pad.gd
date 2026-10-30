class_name OrbitPad
extends Control
## Transparent touch area over the 3D hero kart (0.8.1). It is the TOP-most
## control on the left side of the screen, so real finger events
## (InputEventScreenTouch / ScreenDrag, routed by the GUI) reach it before any
## full-screen container can swallow them. Panels and buttons on the right are
## outside its rect.
##
## Root cause of the 0.8.0 bug: the orbit code lived in _unhandled_input and
## turned the kart only from InputEventMouseMotion. On a phone those are the
## mouse events emulated from the finger, and the GUI pass hands them to the
## MenuScreen's full-screen root Control (mouse_filter STOP), which consumes
## them, so they never become "unhandled". Pinch kept only the touch list in
## sync and never got two tracked fingers for the same reason.

signal orbit(rel: Vector2)
signal zoom(factor: float)
signal held(on: bool)

var _touches := {} # index -> position
var _pinch := 0.0
var _mouse_down := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


## Fingers: handled in _input, before the GUI. Godot does not route
## InputEventScreenTouch/Drag to Control._gui_input (only the emulated mouse
## of the first finger), and once a full-screen Control consumed them they
## never reached _unhandled_input either. Only touches that START inside this
## pad's rect are taken, so the panel on the right keeps its own input.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if not get_global_rect().has_point(event.position):
				return
			_touches[event.index] = event.position
		elif _touches.has(event.index):
			_touches.erase(event.index)
		else:
			return
		_pinch = _distance()
		held.emit(not _touches.is_empty())
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var d := _distance()
			if _pinch > 0.0 and d > 0.0:
				zoom.emit(_pinch / d)
			_pinch = d
		elif _touches.size() == 1:
			orbit.emit(event.relative)
		get_viewport().set_input_as_handled()


## Mouse (desktop, or touch-emulated mouse when no touch events arrive).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		zoom.emit(1.0 / maxf(event.factor, 0.01))
		accept_event()
	elif event is InputEventMouseButton:
		accept_event()
		# The emulated mouse duplicates a finger already handled in _input.
		if event.device == InputEvent.DEVICE_ID_EMULATION and not _touches.is_empty():
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_down = event.pressed
			held.emit(event.pressed)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom.emit(0.92 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.08)
	elif event is InputEventMouseMotion:
		accept_event()
		if event.device == InputEvent.DEVICE_ID_EMULATION and not _touches.is_empty():
			return
		if _mouse_down:
			orbit.emit(event.relative)


func is_held() -> bool:
	return _mouse_down or not _touches.is_empty()


func touch_count() -> int:
	return _touches.size()


func _distance() -> float:
	if _touches.size() < 2:
		return 0.0
	var p: Array = _touches.values()
	return (p[0] as Vector2).distance_to(p[1])


## Covers the screen minus a right panel and the header strip.
static func make(right_reserve: float, top_reserve := 96.0) -> OrbitPad:
	var pad := OrbitPad.new()
	pad.name = "OrbitPad"
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.offset_top = top_reserve
	pad.offset_right = -right_reserve
	return pad
