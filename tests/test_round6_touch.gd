extends TestCase
## 0.8.1: the hero kart on racer select AND garage must follow REAL finger
## input (InputEventScreenTouch/ScreenDrag pushed through the window at screen
## coordinates, with the whole UI on top), pinch with two fingers, and the
## mouse (real and touch-emulated).

var scr: Node
var _win := Vector2i.ZERO


func before_each() -> void:
	# The headless window is 64x64; use a real phone-like 16:9 window so window
	# pixels map 1:1 onto the 1280x720 canvas, as on a device.
	_win = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame


func after_each() -> void:
	tree.root.size = _win
	if is_instance_valid(scr):
		scr.queue_free()
		await tree.process_frame
		await tree.process_frame


func _open(path: String) -> void:
	scr = load(path).instantiate()
	tree.root.add_child(scr)
	for i in 4:
		await tree.process_frame


func _kart_point() -> Vector2:
	# Middle of the free area left of the panel, in window pixels.
	var vis := tree.root.get_visible_rect().size
	var to_win := tree.root.get_final_transform()
	return to_win * Vector2((vis.x - 640.0) * 0.5, vis.y * 0.6)


func _touch(idx: int, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = down
	tree.root.push_input(e)


func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = rel
	e.screen_relative = rel
	tree.root.push_input(e)


func _swipe(start: Vector2, delta: Vector2, steps := 10) -> void:
	_touch(0, start, true)
	await tree.process_frame
	var p := start
	for i in steps:
		p += delta / steps
		_drag(0, p, delta / steps)
		await tree.process_frame
	_touch(0, p, false)
	await tree.process_frame


func _pinch(c: Vector2, from: float, to: float) -> void:
	_touch(0, c - Vector2(from, 0), true)
	_touch(1, c + Vector2(from, 0), true)
	await tree.process_frame
	for i in 8:
		var h := lerpf(from, to, (i + 1) / 8.0)
		var hp := lerpf(from, to, i / 8.0)
		_drag(0, c - Vector2(h, 0), Vector2(hp - h, 0))
		_drag(1, c + Vector2(h, 0), Vector2(h - hp, 0))
		await tree.process_frame
	_touch(0, c - Vector2(to, 0), false)
	_touch(1, c + Vector2(to, 0), false)
	await tree.process_frame


func _mouse(pos: Vector2, delta: Vector2, emulated: bool) -> void:
	var dev := InputEvent.DEVICE_ID_EMULATION if emulated else 0
	var b := InputEventMouseButton.new()
	b.device = dev
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = true
	b.position = pos
	b.global_position = pos
	tree.root.push_input(b)
	await tree.process_frame
	for i in 6:
		var m := InputEventMouseMotion.new()
		m.device = dev
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		pos += delta / 6.0
		m.position = pos
		m.global_position = pos
		m.relative = delta / 6.0
		tree.root.push_input(m)
		await tree.process_frame
	var u := b.duplicate()
	u.pressed = false
	u.position = pos
	tree.root.push_input(u)
	await tree.process_frame


func test_racer_select_follows_real_touch() -> void:
	await _open("res://scenes/menus/racer_select.tscn")
	var tt: Node3D = scr.stage.turntable
	var p := _kart_point()
	check(scr.orbit_pad != null, "orbit pad present")
	var hit: Control = tree.root.gui_get_hovered_control() if false else null
	var yaw0 := tt.rotation.y
	await _swipe(p, Vector2(200, 0))
	var dyaw := tt.rotation.y - yaw0
	check(dyaw > 0.6, "horizontal finger swipe turns the kart (%.2f rad)" % dyaw)
	var pitch0: float = scr.view_pitch
	await _swipe(p, Vector2(0, 80))
	check(scr.view_pitch > pitch0 + 0.15, "vertical swipe tilts the camera (%.2f)" % scr.view_pitch)
	var z0: float = scr.view_zoom
	await _pinch(p, 60.0, 160.0)
	check(scr.view_zoom < z0 - 0.15, "two-finger pinch out zooms in (%.2f)" % scr.view_zoom)
	await _pinch(p, 160.0, 50.0)
	check(scr.view_zoom > z0 - 0.05, "pinch in zooms back out (%.2f)" % scr.view_zoom)
	var yaw1 := tt.rotation.y
	await _mouse(p, Vector2(-150, 0), false)
	check(tt.rotation.y < yaw1 - 0.4, "real mouse drag also turns the kart")
	# Emulated mouse alone (no touch events, e.g. emulate_mouse_from_touch only).
	var yaw2 := tt.rotation.y
	await _mouse(p, Vector2(150, 0), true)
	check(tt.rotation.y > yaw2 + 0.4, "touch-emulated mouse drag turns the kart")
	# The right panel keeps its own input: a swipe there must not orbit.
	var vis := tree.root.get_visible_rect().size
	for i in 120:
		await tree.process_frame # let the flick inertia settle
	var yaw3 := tt.rotation.y
	await _swipe(tree.root.get_final_transform() * Vector2(vis.x - 300, 420), Vector2(-100, 0))
	check_near(tt.rotation.y, yaw3, 0.05, "panel drags do not orbit")


func test_touch_and_emulated_mouse_do_not_double() -> void:
	await _open("res://scenes/menus/racer_select.tscn")
	var tt: Node3D = scr.stage.turntable
	var p := _kart_point()
	var yaw0 := tt.rotation.y
	_touch(0, p, true)
	var b := InputEventMouseButton.new()
	b.device = InputEvent.DEVICE_ID_EMULATION
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = true
	b.position = p
	tree.root.push_input(b)
	await tree.process_frame
	for i in 5:
		p += Vector2(20, 0)
		_drag(0, p, Vector2(20, 0))
		var m := InputEventMouseMotion.new()
		m.device = InputEvent.DEVICE_ID_EMULATION
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		m.position = p
		m.relative = Vector2(20, 0)
		tree.root.push_input(m)
		await tree.process_frame
	check_near(tt.rotation.y - yaw0, 100.0 * RacerSelect.ORBIT_RAD_PER_PX, 0.06, "rotation follows the finger 1:1 (no double count)")
	_touch(0, p, false)
	await tree.process_frame


func test_garage_follows_real_touch() -> void:
	await _open("res://scenes/menus/garage.tscn")
	var tt: Node3D = scr.stage.turntable
	var p := _kart_point()
	var yaw0 := tt.rotation.y
	await _swipe(p, Vector2(-200, 0))
	check(tt.rotation.y < yaw0 - 0.6, "garage kart turns with the finger")
	var f0: float = scr.stage.camera.fov
	await _pinch(p, 60.0, 160.0)
	check(scr.stage.camera.fov < f0 - 3.0, "garage pinch zooms (fov %.1f)" % scr.stage.camera.fov)
