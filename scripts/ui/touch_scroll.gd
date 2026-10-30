class_name TouchScroll
extends Node
## The one scrolling implementation shared by every scrollable screen.
## Finger (and mouse) drag scrolling with momentum for a ScrollContainer whose
## rows are buttons, switches and selectors.
##
## Why it exists / what it replaces:
## * The rows swallow presses, so a drag starting on them never reached the
##   ScrollContainer. This helper sees pointer input *before* the GUI.
## * ScrollContainer's own touch dragging only runs on devices with a
##   touchscreen and fought with this helper (two drag/inertia systems), so it
##   is switched off: the container is set to MOUSE_FILTER_IGNORE and this node
##   handles drag, fling and the mouse wheel itself.
## * Positions are kept as floats. Drag deltas on a phone are fractions of a
##   viewport pixel (the 1280×720 canvas is stretched), and truncating them to
##   int made slow drags stand still and fast drags stepped.
##
## Input source: the first finger's native ScreenTouch/ScreenDrag events, and
## real (non-emulated) mouse events on desktop — one stream per gesture.
## Gesture rules: a press that moves past SLOP mostly vertically becomes a
## scroll; the control under the finger then gets a cancelling release, so no
## button fires and nothing toggles. A press while the list is still gliding
## only stops the glide (no tap). Mostly-horizontal motion is left to the row.

const SLOP := 12.0 ## px of movement before a press becomes a drag
const FRICTION := 2.6 ## 1/s exponential velocity decay of a fling
const MIN_FLING := 60.0 ## px/s below which a release does not glide
const STOP_SPEED := 18.0 ## px/s at which a glide ends
const MAX_SPEED := 6000.0
const SAMPLE_WINDOW_US := 100000 ## velocity is averaged over the last 0.1 s
const CANCEL_POS := Vector2(-10000, -10000)
## Our own cancelling events carry this device id. (Matching CANCEL_POS was
## not enough: push_input applies the stretch transform, so on a phone the
## position no longer matched and the cancel ended every drag at once —
## the "only the scrollbar scrolls" bug.)
const SYNTH_DEVICE := 0x7A5C

var scroll: ScrollContainer
var pos := 0.0 ## current scroll offset (float, authoritative while active)
var velocity := 0.0 ## px/s, positive = content moves up (offset grows)
var dragging := false
var _pressed := false
var _caught_glide := false
var _decided := false
var _start := Vector2.ZERO
var _last_y := 0.0
var _samples: Array[Vector2] = [] # (time_us, offset delta)
var _wheel_target := -1.0


static func attach(sc: ScrollContainer) -> TouchScroll:
	var ts := TouchScroll.new()
	ts.name = "TouchScroll"
	ts.scroll = sc
	ts.process_mode = Node.PROCESS_MODE_ALWAYS # works while the race is paused
	# Disable the container's built-in drag/wheel handling (see header).
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.add_child(ts)
	return ts


func max_offset() -> float:
	if scroll == null:
		return 0.0
	var bar := scroll.get_v_scroll_bar()
	return maxf(bar.max_value - bar.page, 0.0)


func is_gliding() -> bool:
	return not dragging and absf(velocity) > STOP_SPEED


func _set_offset(v: float) -> void:
	pos = clampf(v, 0.0, max_offset())
	var bar := scroll.get_v_scroll_bar()
	bar.step = 0.0 # fractional offsets; children are snapped to pixels when drawn
	bar.value = pos


func _input(event: InputEvent) -> void:
	if scroll == null or not scroll.is_visible_in_tree():
		return
	# Fingers: native touch events (first finger only). Mouse events that the
	# engine emulates from touch are ignored, so a gesture is read exactly
	# once and works whether or not emulate_mouse_from_touch is enabled.
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release()
		return
	if event is InputEventScreenDrag:
		if event.index == 0 and _pressed:
			_on_motion(event.position)
		return
	if event is InputEventMouse and (event.device == InputEvent.DEVICE_ID_EMULATION or event.device == SYNTH_DEVICE):
		return
	if event is InputEventMouseButton:
		if event.position == CANCEL_POS:
			return # our own cancelling release
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_on_press(event.position)
				else:
					_on_release()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed and _inside(event.position):
					var dir := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
					var base := _wheel_target if _wheel_target >= 0.0 else scroll.get_v_scroll_bar().value
					_wheel_target = clampf(base + dir * 90.0 * maxf(event.factor, 1.0), 0.0, max_offset())
					velocity = 0.0
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pressed:
		if event.position == CANCEL_POS:
			return
		_on_motion(event.position)
	elif event is InputEventPanGesture and _inside(event.position):
		_wheel_target = -1.0
		velocity = 0.0
		_set_offset(scroll.get_v_scroll_bar().value + event.delta.y * 24.0)
		get_viewport().set_input_as_handled()


func _inside(p: Vector2) -> bool:
	var local := scroll.get_global_transform_with_canvas().affine_inverse() * p
	return Rect2(Vector2.ZERO, scroll.size).has_point(local)


func _on_press(at: Vector2) -> void:
	if not _inside(at):
		return
	_pressed = true
	dragging = false
	_decided = false
	_caught_glide = is_gliding() or _wheel_target >= 0.0
	velocity = 0.0 # touching moving content stops it at once
	_wheel_target = -1.0
	pos = scroll.get_v_scroll_bar().value # pick up scrollbar / focus changes
	_start = at
	_last_y = at.y
	_samples.clear()
	if _caught_glide:
		# The touch only stops the glide: the row under the finger must not fire.
		_cancel_gui_press()


func _on_motion(p: Vector2) -> void:
	if not dragging:
		var d := p - _start
		if not _decided and d.length() > SLOP:
			_decided = true
			if absf(d.y) >= absf(d.x):
				dragging = true
				_last_y = p.y # start from here: no jump by the slop distance
				_cancel_gui_press()
		if not dragging:
			return
	var dy := p.y - _last_y
	_last_y = p.y
	_set_offset(pos - dy)
	var now := Time.get_ticks_usec()
	_samples.append(Vector2(now, -dy))
	while _samples.size() > 1 and now - int(_samples[0].x) > SAMPLE_WINDOW_US:
		_samples.pop_front()
	get_viewport().set_input_as_handled()


func _on_release() -> void:
	if not _pressed:
		return
	_pressed = false
	if dragging:
		dragging = false
		velocity = _release_velocity()
		get_viewport().set_input_as_handled()
	_caught_glide = false


## Average speed over the last SAMPLE_WINDOW_US; zero if the finger rested
## before lifting (so a slow, careful drag never glides on).
func _release_velocity() -> float:
	if _samples.size() < 2:
		return 0.0
	var now := Time.get_ticks_usec()
	var last_t := int(_samples[-1].x)
	if now - last_t > 60000:
		return 0.0
	var first_t := int(_samples[0].x)
	var dist := 0.0
	for i in range(1, _samples.size()):
		dist += _samples[i].y
	var dt := float(last_t - first_t) / 1000000.0
	if dt < 0.008:
		return 0.0
	var v := clampf(dist / dt, -MAX_SPEED, MAX_SPEED)
	return v if absf(v) >= MIN_FLING else 0.0


## The control that received the press gets a motion and then a release far
## outside its rect: buttons do not fire, switches do not toggle, sliders stop
## grabbing. (BaseButton decides on release from `pressing_inside`, which
## only motion events update, so a release alone would still fire it.)
## Pushed straight into the viewport so it arrives before further motion.
func _cancel_gui_press() -> void:
	_push_motion_off()
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = CANCEL_POS
	up.global_position = CANCEL_POS
	up.device = SYNTH_DEVICE
	scroll.get_viewport().push_input(up)
	scroll.get_viewport().gui_release_focus()


func _push_motion_off() -> void:
	var mm := InputEventMouseMotion.new()
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	mm.position = CANCEL_POS
	mm.global_position = CANCEL_POS
	mm.device = SYNTH_DEVICE
	scroll.get_viewport().push_input(mm)


func _process(delta: float) -> void:
	if scroll == null or dragging:
		return
	if _wheel_target >= 0.0:
		var cur := scroll.get_v_scroll_bar().value
		var nxt := lerpf(cur, _wheel_target, 1.0 - exp(-18.0 * delta))
		if absf(nxt - _wheel_target) < 0.5:
			nxt = _wheel_target
			_wheel_target = -1.0
		_set_offset(nxt)
		return
	if absf(velocity) <= STOP_SPEED:
		velocity = 0.0
		return
	var before := pos
	_set_offset(pos + velocity * delta)
	if is_equal_approx(before, pos):
		velocity = 0.0 # reached a bound: stop instead of pushing against it
		return
	velocity *= exp(-FRICTION * delta)
