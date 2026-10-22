class_name TouchControls
extends Control
## On-screen controls that press the same InputMap actions as keyboard and
## controller. Each finger is tracked separately, so steering, accelerating,
## drifting, boosting and using items work simultaneously. Sliding a finger
## between the steer buttons switches direction without lifting.
## Interrupted touches (focus loss, pause, app suspend) release everything.

class TouchButton:
	extends RefCounted
	var id := ""
	var action: StringName
	var label_key := ""
	var center := Vector2.ZERO
	var radius := 60.0
	var color := Color.WHITE
	var pressed := false
	var visible := true
	var fingers := 0


var player_input: PlayerInput
var buttons: Array[TouchButton] = []
var _finger_button := {} # touch index -> TouchButton
var _opacity := 0.65
var _scale := 1.0


func setup(p_input: PlayerInput) -> void:
	player_input = p_input
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add("steer_left", InputActions.STEER_LEFT, "", Color("25c2c2"))
	_add("steer_right", InputActions.STEER_RIGHT, "", Color("25c2c2"))
	_add("drift", InputActions.DRIFT, "TOUCH_DRIFT", Color("e0344b"))
	_add("boost", InputActions.BOOST, "TOUCH_BOOST", Color("ffc93c"))
	_add("item", InputActions.USE_ITEM, "TOUCH_ITEM", Color("4b5bd6"))
	_add("brake", InputActions.BRAKE, "TOUCH_BRAKE", Color("8a8f99"))
	_add("gas", InputActions.ACCELERATE, "TOUCH_GAS", Color("5cc46a"))
	_add("look", InputActions.LOOK_BACK, "", Color("8a8f99"))
	_add("recover", InputActions.RECOVER, "", Color("8a8f99"))
	resized.connect(_layout)
	visibility_changed.connect(func():
		if player_input:
			player_input.touch_active = visible
		if not visible:
			release_all())
	apply_settings()


func _add(id: String, action: StringName, label_key: String, color: Color) -> void:
	var b := TouchButton.new()
	b.id = id
	b.action = action
	b.label_key = label_key
	b.color = color
	buttons.append(b)


func get_button(id: String) -> TouchButton:
	for b in buttons:
		if b.id == id:
			return b
	return null


func apply_settings() -> void:
	_opacity = float(Settings.get_value("controls", "touch_opacity", 0.65))
	_scale = float(Settings.get_value("controls", "touch_scale", 1.0))
	if player_input:
		player_input.touch_active = visible
	_layout()


func _layout() -> void:
	var sz := size
	if sz.x <= 0.0:
		sz = get_viewport_rect().size
	var swapped: bool = Settings.get_value("controls", "touch_layout", "default") == "swapped"
	var tilt: bool = Settings.get_value("controls", "touch_steer_mode", "buttons") == "tilt"
	var auto_gas: bool = Settings.get_value("controls", "touch_auto_accelerate", true)
	var ox: float = float(Settings.get_value("controls", "touch_offset_x", 0.0)) * sz.x
	var oy: float = float(Settings.get_value("controls", "touch_offset_y", 0.0)) * sz.y
	var s := _scale * clampf(sz.y / 720.0, 0.75, 1.6)
	var m := 34.0 * s
	# Positions for the default (steer left, actions right) layout.
	var left_base := Vector2(m + ox, sz.y - m + oy)
	var right_base := Vector2(sz.x - m - ox, sz.y - m + oy)
	var defs := {
		"steer_left": [left_base + Vector2(78, -92) * s, 74.0],
		"steer_right": [left_base + Vector2(250, -92) * s, 74.0],
		"drift": [right_base + Vector2(-96, -96) * s, 84.0],
		"boost": [right_base + Vector2(-262, -70) * s, 64.0],
		"item": [right_base + Vector2(-96, -278) * s, 60.0],
		"brake": [left_base + Vector2(164, -238) * s, 50.0] if auto_gas else [right_base + Vector2(-410, -60) * s, 54.0],
		"gas": [right_base + Vector2(-262, -232) * s, 64.0],
		"look": [Vector2(sz.x * 0.5 + 0.0, sz.y - m - 10.0 * s) + Vector2(-200, 0) * s, 34.0],
		"recover": [Vector2(sz.x * 0.5, sz.y - m - 10.0 * s) + Vector2(200, 0) * s, 34.0],
	}
	if not auto_gas:
		defs["boost"] = [right_base + Vector2(-96, -278) * s, 60.0]
		defs["item"] = [right_base + Vector2(-262, -232) * s, 56.0]
		defs["gas"] = [right_base + Vector2(-262, -70) * s, 70.0]
	for b in buttons:
		var d: Array = defs[b.id]
		var c: Vector2 = d[0]
		if swapped:
			c.x = sz.x - c.x
		b.center = c
		b.radius = float(d[1]) * s
		b.visible = true
		if b.id in ["steer_left", "steer_right"] and tilt:
			b.visible = false
		if b.id == "gas" and auto_gas:
			b.visible = false
	if swapped:
		# Keep left/right steering semantically correct when mirrored.
		var l := get_button("steer_left")
		var r := get_button("steer_right")
		var tmp := l.center
		l.center = r.center
		r.center = tmp
	queue_redraw()


func _button_at(p: Vector2) -> TouchButton:
	var best: TouchButton = null
	var best_d := INF
	for b in buttons:
		if not b.visible:
			continue
		var d := p.distance_to(b.center)
		# Generous hit area (1.25x) so thumbs do not miss.
		if d < b.radius * 1.25 and d < best_d:
			best = b
			best_d = d
	return best


func _input(event: InputEvent) -> void:
	if not visible or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		handle_drag(event.index, event.position)


func handle_touch(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		var b := _button_at(pos)
		if b != null:
			_finger_button[index] = b
			_press(b)
			get_viewport().set_input_as_handled()
	else:
		if _finger_button.has(index):
			_release(_finger_button[index])
			_finger_button.erase(index)


func handle_drag(index: int, pos: Vector2) -> void:
	if not _finger_button.has(index):
		return
	var cur: TouchButton = _finger_button[index]
	var b := _button_at(pos)
	# Allow sliding between the steering pair only (actions stay latched).
	if b != null and b != cur and cur.id.begins_with("steer") and b.id.begins_with("steer"):
		_release(cur)
		_finger_button[index] = b
		_press(b)


func _press(b: TouchButton) -> void:
	b.fingers += 1
	if not b.pressed:
		b.pressed = true
		Input.action_press(b.action, 1.0)
		if bool(Settings.get_value("controls", "vibration", true)) and b.id in ["drift", "boost", "item"]:
			Input.vibrate_handheld(18)
	queue_redraw()


func _release(b: TouchButton) -> void:
	b.fingers = maxi(b.fingers - 1, 0)
	if b.fingers == 0 and b.pressed:
		b.pressed = false
		Input.action_release(b.action)
	queue_redraw()


func release_all() -> void:
	for b in buttons:
		if b.pressed:
			Input.action_release(b.action)
		b.pressed = false
		b.fingers = 0
	_finger_button.clear()
	queue_redraw()


func _process(_delta: float) -> void:
	if not visible or player_input == null:
		return
	if Settings.get_value("controls", "touch_steer_mode", "buttons") == "tilt":
		var acc := Input.get_accelerometer()
		var orient := DisplayServer.screen_get_orientation()
		var lateral := acc.y if orient != DisplayServer.SCREEN_REVERSE_LANDSCAPE else -acc.y
		var sens := float(Settings.get_value("controls", "tilt_sensitivity", 1.0))
		player_input.tilt_steer = clampf(lateral / (9.81 * 0.42) * sens, -1.0, 1.0)
	else:
		player_input.tilt_steer = 0.0


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		release_all()


func _draw() -> void:
	var font := UITheme.bold_font()
	for b in buttons:
		if not b.visible:
			continue
		var a := _opacity * (1.0 if b.pressed else 0.75)
		var fill := Color(b.color, 0.35 * a + (0.3 if b.pressed else 0.0))
		draw_circle(b.center, b.radius, Color(UITheme.NAVY_DEEP, 0.45 * a))
		draw_circle(b.center, b.radius * 0.9, fill)
		draw_arc(b.center, b.radius * 0.92, 0, TAU, 40, Color(1, 1, 1, 0.75 * a), 3.0 + (2.0 if b.pressed else 0.0), true)
		var col := Color(1, 1, 1, minf(1.0, a + 0.2))
		match b.id:
			"steer_left", "steer_right":
				var dir := -1.0 if b.id == "steer_left" else 1.0
				var r := b.radius * 0.42
				var pts := PackedVector2Array([b.center + Vector2(dir * r, 0), b.center + Vector2(-dir * r * 0.6, -r), b.center + Vector2(-dir * r * 0.6, r)])
				draw_colored_polygon(pts, col)
			"look":
				draw_arc(b.center, b.radius * 0.45, PI * 0.2, PI * 1.8, 16, col, 4.0)
				draw_colored_polygon(PackedVector2Array([b.center + Vector2(b.radius * 0.45, -b.radius * 0.35), b.center + Vector2(b.radius * 0.2, -b.radius * 0.05), b.center + Vector2(b.radius * 0.62, 0)]), col)
			"recover":
				draw_arc(b.center, b.radius * 0.45, -PI * 0.9, PI * 0.6, 16, col, 4.0)
				draw_colored_polygon(PackedVector2Array([b.center + Vector2(-b.radius * 0.6, -b.radius * 0.05), b.center + Vector2(-b.radius * 0.25, -b.radius * 0.05), b.center + Vector2(-b.radius * 0.45, -b.radius * 0.45)]), col)
			"item":
				var it: StringName = player_input.kart.item if player_input and player_input.kart else &""
				if it != &"" and player_input.kart.item_roll_timer <= 0.0:
					ItemIcon.draw_icon(self, it, b.center, b.radius * 0.5)
				else:
					_draw_label(font, tr(b.label_key), b.center, b.radius, col)
			_:
				_draw_label(font, tr(b.label_key), b.center, b.radius, col)


func _draw_label(font: Font, text: String, c: Vector2, r: float, col: Color) -> void:
	var fs := int(clampf(r * 0.36, 14.0, 30.0))
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string_outline(font, c + Vector2(-ts.x * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.5))
	draw_string(font, c + Vector2(-ts.x * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
