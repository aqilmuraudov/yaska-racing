extends TestCase
## Finger drag-to-scroll on lists of buttons (TouchScroll), driven with
## simulated InputEventScreenTouch / InputEventScreenDrag: drag scrolls,
## flick glides then stops at the bound, a tap still presses the row, a drag
## that starts on a row does not press it.

var sc: ScrollContainer
var ts: TouchScroll
var presses := 0
var xf := Transform2D.IDENTITY
var layer: CanvasLayer


func _build() -> void:
	sc = ScrollContainer.new()
	sc.position = Vector2(40, 40)
	sc.size = Vector2(400, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	for i in 20:
		var b := Button.new()
		b.text = "Row %d" % i
		b.custom_minimum_size = Vector2(0, 72)
		b.pressed.connect(func(): presses += 1)
		v.add_child(b)
	# On its own top canvas layer: in the full run, Controls left on the root
	# by earlier tests could sit above the list and eat the tap (the old
	# "tap still presses a row" flake that only showed in full runs).
	layer = CanvasLayer.new()
	layer.layer = 127
	tree.root.add_child(layer)
	layer.add_child(sc)
	ts = TouchScroll.attach(sc)
	await frames(3)
	xf = sc.get_viewport().get_screen_transform()


func _touch(p: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = xf * p
	t.pressed = pressed
	Input.parse_input_event(t)
	await frames(1)


func _drag(from: Vector2, to: Vector2, steps: int) -> void:
	var prev := from
	for i in steps:
		var p := from.lerp(to, float(i + 1) / steps)
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = xf * p
		d.relative = xf.basis_xform(p - prev)
		Input.parse_input_event(d)
		prev = p
		await frames(1)


func _wait(sec: float) -> void:
	await tree.create_timer(sec).timeout


func test_finger_drag_scrolls_and_taps_still_work() -> void:
	await _build()
	check(ts.max_offset() > 500.0, "list is scrollable")
	var start := Vector2(240, 300)
	# Drag starting on a row: scrolls by the finger distance, presses nothing.
	await _touch(start, true)
	await _drag(start, start - Vector2(0, 20), 4)
	await frames(1)
	var y0 := sc.get_v_scroll_bar().value
	await _drag(start - Vector2(0, 20), start - Vector2(0, 120), 25)
	await frames(1)
	check_near(sc.get_v_scroll_bar().value - y0, 100.0, 4.0, "drag follows the finger")
	await _touch(start - Vector2(0, 120), false)
	await _wait(0.4)
	check_eq(presses, 0, "drag over rows pressed no button")
	# Flick: momentum glide after release.
	await _touch(start, true)
	await _drag(start, start - Vector2(0, 150), 5)
	await _touch(start - Vector2(0, 150), false)
	var at_release := sc.get_v_scroll_bar().value
	await _wait(0.15)
	check(sc.get_v_scroll_bar().value > at_release + 10.0 and ts.is_gliding(), "flick keeps gliding")
	# Touching gliding content stops it and does not press the row.
	await _touch(Vector2(240, 150), true)
	var stopped := sc.get_v_scroll_bar().value
	await _wait(0.08)
	await _touch(Vector2(240, 150), false)
	await _wait(0.2)
	check_near(sc.get_v_scroll_bar().value, stopped, 2.0, "touch stops the glide")
	check_eq(presses, 0, "stopping touch pressed nothing")
	# Overscroll-safe: a huge flick upward clamps at the bottom bound.
	for k in 3:
		await _touch(start, true)
		await _drag(start, start - Vector2(0, 250), 4)
		await _touch(start - Vector2(0, 250), false)
	await _wait(1.5)
	check(sc.get_v_scroll_bar().value <= ts.max_offset() + 0.5, "never scrolls past the end")
	check(not ts.is_gliding(), "glide ends at the bound")
	# Plain tap presses the row under the finger. (Wait on state, not on the
	# clock: under a loaded full run a glide could still be settling.)
	for i in 180:
		if not ts.is_gliding():
			break
		await frames(1)
	await frames(2)
	await _touch(Vector2(240, 150), true)
	await frames(3)
	await _touch(Vector2(240, 150), false)
	await frames(3)
	check_eq(presses, 1, "tap still presses a row")
	layer.queue_free()
	await frames(1)
