class_name TouchControls
extends Control
## On-screen controls that press the same InputMap actions as keyboard and
## controller. Each finger is tracked separately, so steering, drifting,
## braking and using items work simultaneously. Sliding a finger between the
## steer buttons switches direction without lifting.
## Interrupted touches (focus loss, pause, app suspend) release everything.
##
## Layout (thumb zones): steering on the left; DRIFT (largest) in the right
## corner, the ITEM button above it, BRAKE beside it. Buttons only exist when
## they do something:
## * GAS appears only with Automatic Acceleration off (otherwise the kart
##   already drives and a gas button would do nothing visible).
## * The drift TURBO timing button appears only with Easy Drift off (with Easy
##   Drift, letting go of DRIFT while charged gives the boost).
## * RECOVER appears only when the kart is stuck or facing the wrong way.
## * Look-back stays on keyboard/controller only.
## The ITEM button is the item slot: it shows the actual item (nitro, shield,
## trap), a spinning roll, or an empty dimmed state, and pops when used.

class TouchButton:
	extends RefCounted
	var id := ""
	var action: StringName
	var label_key := ""
	var icon := ""
	var center := Vector2.ZERO
	var radius := 60.0
	var color := Color.WHITE
	var pressed := false
	var visible := true
	var fingers := 0
	var pop := 0.0 ## activation feedback (0..1, decays)


const ITEM_SHORT := {&"turbo": "ITEM_SHORT_TURBO", &"shield": "ITEM_SHORT_SHIELD", &"trap": "ITEM_SHORT_TRAP"}
const CHARGE_COLORS := [Color("8fd3ff"), Color("ffb21f"), Color("ff4fa3"), Color("c58bff")]

var player_input: PlayerInput
var buttons: Array[TouchButton] = []
## Set by the HUD every frame: the kart is stuck / wrong way.
var show_recover := false
var _finger_button := {} # touch index -> TouchButton
var _opacity := 0.65
var _scale := 1.0
var _tilt_layout := false
var _notice_time := 0.0
var _denied_time := 0.0
var _t := 0.0
var _last_item: StringName = &""
var _icons := {}


func setup(p_input: PlayerInput) -> void:
	player_input = p_input
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add("steer_left", InputActions.STEER_LEFT, "", "", Color("2f9ce8"))
	_add("steer_right", InputActions.STEER_RIGHT, "", "", Color("2f9ce8"))
	_add("drift", InputActions.DRIFT, "TOUCH_DRIFT", "hud_drift", Color("ff5f6d"))
	_add("boost", InputActions.BOOST, "TOUCH_BOOST", "hud_nitro", Color("ff8a1f"))
	_add("item", InputActions.USE_ITEM, "TOUCH_ITEM", "", Color("8b5cf6"))
	_add("brake", InputActions.BRAKE, "TOUCH_BRAKE", "hud_brake", Color("5b6b8f"))
	_add("gas", InputActions.ACCELERATE, "TOUCH_GAS", "hud_gas", Color("4fae2a"))
	_add("look", InputActions.LOOK_BACK, "", "hud_look_back", Color("6f7fa0"))
	_add("recover", InputActions.RECOVER, "TOUCH_RECOVER", "hud_recover", Color("4fae2a"))
	resized.connect(_layout)
	visibility_changed.connect(func():
		if player_input:
			player_input.touch_active = visible
		if not visible:
			release_all())
	apply_settings()


func _add(id: String, action: StringName, label_key: String, icon_name: String, color: Color) -> void:
	var b := TouchButton.new()
	b.id = id
	b.action = action
	b.label_key = label_key
	b.icon = icon_name
	b.color = color
	buttons.append(b)
	if icon_name != "" and not _icons.has(icon_name):
		_icons[icon_name] = UITheme.icon(icon_name)


func get_button(id: String) -> TouchButton:
	for b in buttons:
		if b.id == id:
			return b
	return null


func apply_settings() -> void:
	_opacity = maxf(float(Settings.get_value("controls", "touch_opacity", 0.65)), 0.75)
	_scale = float(Settings.get_value("controls", "touch_scale", 1.0))
	if player_input:
		player_input.touch_active = visible
	_layout()


func _layout() -> void:
	var sz := size
	if sz.x <= 0.0:
		sz = get_viewport_rect().size
	var swapped: bool = Settings.get_value("controls", "touch_layout", "default") == "swapped"
	# Steer buttons hide only while tilt really steers (sensor data present).
	var tilt: bool = player_input != null and player_input.steer_mode() == "tilt"
	_tilt_layout = tilt
	var auto_gas: bool = Settings.get_value("controls", "touch_auto_accelerate", true)
	var easy: bool = Settings.get_value("controls", "easy_drift", true)
	var ox: float = float(Settings.get_value("controls", "touch_offset_x", 0.0)) * sz.x
	var oy: float = float(Settings.get_value("controls", "touch_offset_y", 0.0)) * sz.y
	# Scale with the screen, limited by width too: on 16:9 and 4:3 screens the
	# two clusters must leave the bottom-centre speedometer free.
	var s := _scale * clampf(minf(sz.y / 720.0, sz.x / 1500.0), 0.7, 1.6)
	var m := 30.0 * s
	var left_base := Vector2(m + ox, sz.y - m + oy)
	var right_base := Vector2(sz.x - m - ox, sz.y - m + oy)
	var defs := {
		"steer_left": [left_base + Vector2(84, -96) * s, 78.0],
		"steer_right": [left_base + Vector2(262, -96) * s, 78.0],
		"drift": [right_base + Vector2(-100, -104) * s, 92.0],
		"item": [right_base + Vector2(-120, -306) * s, 72.0],
		"brake": [right_base + Vector2(-300, -70) * s, 54.0],
		"boost": [right_base + Vector2(-296, -228) * s, 58.0],
		"gas": [right_base + Vector2(-300, -96) * s, 74.0],
		"look": [Vector2(-1000, -1000), 30.0],
		"recover": [Vector2(sz.x * 0.5, 210.0 * s), 50.0],
	}
	if not auto_gas:
		defs["gas"] = [right_base + Vector2(-292, -92) * s, 74.0]
		defs["brake"] = [right_base + Vector2(-310, -262) * s, 54.0]
		defs["boost"] = [right_base + Vector2(-460, -250) * s, 58.0]
	for b in buttons:
		var d: Array = defs[b.id]
		var c: Vector2 = d[0]
		if swapped and b.id != "recover":
			c.x = sz.x - c.x
		b.center = c
		b.radius = float(d[1]) * s
		b.visible = true
		match b.id:
			"steer_left", "steer_right":
				b.visible = not tilt
			"gas":
				b.visible = not auto_gas
			"boost":
				b.visible = not easy
			"look":
				b.visible = false
			"recover":
				b.visible = show_recover
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
		b.pop = 1.0
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
	if player_input:
		player_input.release_all()
	for b in buttons:
		if b.pressed:
			Input.action_release(b.action)
		b.pressed = false
		b.fingers = 0
	_finger_button.clear()
	queue_redraw()


## DRIFT was held but no drift started (see KartController.drift_denied).
func flash_denied() -> void:
	_denied_time = 0.6


func _process(delta: float) -> void:
	if not visible or player_input == null:
		return
	_t += delta
	# Tilt reading and filtering live in PlayerInput (fixed tick). Here the
	# layout follows the effective mode: if Tilt is selected but the device
	# sends no sensor data, the steer buttons come back with a short notice.
	var tilt_now := player_input.steer_mode() == "tilt"
	if tilt_now != _tilt_layout:
		if not tilt_now and player_input.tilt_unavailable:
			_notice_time = 4.0
		release_all()
		_layout()
	var rec := get_button("recover")
	var want_rec := show_recover or rec.pressed
	if rec.visible != want_rec:
		rec.visible = want_rec
	if _notice_time > 0.0:
		_notice_time -= delta
	_denied_time = maxf(_denied_time - delta, 0.0)
	for b in buttons:
		b.pop = maxf(b.pop - delta * 4.0, 0.0)
	var kart := player_input.kart
	if kart:
		var it := kart.item if kart.item_roll_timer <= 0.0 else &"?"
		if it != _last_item:
			if it == &"" and _last_item != &"?":
				get_button("item").pop = 1.0 # used: pop
			_last_item = it
	queue_redraw()


static func _debug_overlay() -> bool:
	return OS.is_debug_build() and bool(Settings.get_value("graphics", "tilt_debug", false))


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		release_all()


func _draw() -> void:
	var font := UITheme.bold_font()
	if _notice_time > 0.0:
		var msg := tr("TILT_NO_SENSOR")
		var fs := 26
		var tsz := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var c := Vector2(size.x * 0.5, size.y * 0.24)
		var a := clampf(_notice_time, 0.0, 1.0)
		draw_rect(Rect2(c - Vector2(tsz.x * 0.5 + 24, 30), Vector2(tsz.x + 48, 52)), Color(UITheme.NAVY_DEEP, 0.85 * a))
		draw_string(font, c + Vector2(-tsz.x * 0.5, 8), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UITheme.GOLD, a))
	if _debug_overlay() and player_input:
		var lines := (player_input.tilt.debug_text() + "
mode=%s unavailable=%s kart_steer=%+.2f" % [player_input.steer_mode(), player_input.tilt_unavailable, player_input.kart.input.steer if player_input.kart else 0.0]).split("
")
		draw_rect(Rect2(Vector2(size.x * 0.5 - 330, 96), Vector2(660, 26 * lines.size() + 14)), Color(0, 0, 0, 0.7))
		for i in lines.size():
			draw_string(font, Vector2(size.x * 0.5 - 318, 120 + i * 26), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.6, 1.0, 0.7))
	for b in buttons:
		if not b.visible:
			continue
		match b.id:
			"item":
				_draw_item_button(b, font)
			"drift":
				_draw_drift_button(b, font)
			_:
				_draw_body(b, b.color, 1.0)
				if b.id.begins_with("steer"):
					_draw_arrow(b)
				else:
					_draw_icon_label(b, font)


## Glossy round button: drop shadow, ink rim, coloured body, highlight.
func _draw_body(b: TouchButton, fill: Color, dim: float) -> Vector2:
	var a := clampf(_opacity * (1.15 if b.pressed else 1.0), 0.0, 1.0) * dim
	var c := b.center + Vector2(0, 3.0 if b.pressed else 0.0)
	var r := b.radius * (1.0 + b.pop * 0.08)
	if not b.pressed:
		draw_circle(b.center + Vector2(0, 5), r, Color(UITheme.INK, 0.35 * a))
	draw_circle(c, r, Color(UITheme.INK, 0.85 * a))
	draw_circle(c, r * 0.93, Color(fill.lightened(0.12) if b.pressed else fill, 0.85 * a))
	draw_circle(c + Vector2(0, -r * 0.28), r * 0.62, Color(1, 1, 1, 0.14 * a))
	draw_arc(c, r * 0.86, PI * 1.15, PI * 1.85, 24, Color(1, 1, 1, 0.5 * a), maxf(3.0, r * 0.07), true)
	if b.pressed:
		draw_arc(c, r * 1.04, 0, TAU, 40, Color(UITheme.YELLOW, 0.95), 4.0, true)
	return c


func _draw_arrow(b: TouchButton) -> void:
	var c := _draw_body(b, b.color, 1.0)
	var dir := -1.0 if b.id == "steer_left" else 1.0
	var r := b.radius * 0.5
	var pts := PackedVector2Array([c + Vector2(dir * r, 0), c + Vector2(-dir * r * 0.55, -r * 0.95), c + Vector2(-dir * r * 0.55, r * 0.95)])
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), UITheme.INK, 9.0, true)
	draw_colored_polygon(pts, Color.WHITE)


func _draw_icon_label(b: TouchButton, font: Font) -> void:
	var c := b.center + Vector2(0, 3.0 if b.pressed else 0.0)
	var tex: Texture2D = _icons.get(b.icon)
	var has_label := b.label_key != ""
	var isz := b.radius * (1.0 if has_label else 1.25)
	if tex:
		draw_texture_rect(tex, Rect2(c - Vector2(isz, isz) * 0.5 - Vector2(0, b.radius * (0.16 if has_label else 0.0)), Vector2(isz, isz)), false)
	if has_label:
		_draw_label(font, tr(b.label_key), c + Vector2(0, b.radius * 0.52), b.radius, Color.WHITE)


## DRIFT with a charge ring: fills while drifting, colour = charge level,
## pulses with "LET GO!" (Easy Drift) / "TURBO!" when a boost is ready.
## A greyed shake explains a drift that could not start.
func _draw_drift_button(b: TouchButton, font: Font) -> void:
	var kart := player_input.kart if player_input else null
	var shake := Vector2(sin(_t * 60.0) * 5.0 * minf(_denied_time * 3.0, 1.0), 0.0)
	var saved := b.center
	b.center += shake
	var fill := b.color.lerp(Color("8a94aa"), minf(_denied_time * 3.0, 1.0))
	var c := _draw_body(b, fill, 1.0)
	_draw_icon_label(b, font)
	b.center = saved
	if kart == null or not kart.is_drifting():
		return
	var dm := kart.drift
	var lvl := clampi(dm.level(), 0, 3)
	var col: Color = CHARGE_COLORS[lvl]
	var r := b.radius * 1.14
	draw_arc(c, r, 0, TAU, 48, Color(UITheme.INK, 0.8), 13.0, true)
	draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(dm.meter, 0.0, 1.0), 48, col, 8.0, true)
	if dm.is_charged():
		var pulse := 0.5 + 0.5 * sin(_t * 14.0)
		draw_arc(c, r + 9.0, 0, TAU, 48, Color(col, 0.4 + 0.5 * pulse), 5.0, true)
		var easy: bool = kart.easy_drift
		var txt := tr("TOUCH_LET_GO") if easy else tr("TOUCH_BOOST_NOW")
		# Up-left of the button: clear of the ITEM button above and BRAKE beside.
		var side := -1.0 if b.center.x > size.x * 0.5 else 1.0
		_draw_label(font, txt, c + Vector2(side * b.radius * 1.2, -b.radius * 0.95), b.radius * 1.3, Color(col.lightened(0.4), 1.0))


## The one item control. Shows what the player holds and whether it can be
## used: empty (dimmed "?"), rolling (cycling icons), ready (big icon + name,
## gentle glow), and pops when used.
func _draw_item_button(b: TouchButton, font: Font) -> void:
	var kart := player_input.kart if player_input else null
	var it: StringName = kart.item if kart else &""
	var rolling := kart != null and it != &"" and kart.item_roll_timer > 0.0
	var ready := kart != null and it != &"" and not rolling and kart.can_use_item()
	var dim := 1.0 if (ready or rolling) else 0.55
	var c := _draw_body(b, b.color, dim)
	if rolling:
		var order := [&"turbo", &"shield", &"trap"]
		ItemIcon.draw_icon(self, order[int(_t * 12.0) % order.size()], c, b.radius * 0.55)
	elif it != &"":
		var glow := 0.5 + 0.5 * sin(_t * 5.0)
		draw_arc(c, b.radius * 1.12, 0, TAU, 48, Color(UITheme.YELLOW, 0.35 + 0.45 * glow), 6.0, true)
		ItemIcon.draw_icon(self, it, c + Vector2(0, -b.radius * 0.1), b.radius * 0.62)
		_draw_label(font, tr(ITEM_SHORT.get(it, "TOUCH_ITEM")), c + Vector2(0, b.radius * 0.66), b.radius, Color.WHITE)
	else:
		draw_arc(c, b.radius * 0.5, 0, TAU, 32, Color(1, 1, 1, 0.45), 4.0, true)
		_draw_label(font, "?", c + Vector2(0, 4), b.radius * 1.4, Color(1, 1, 1, 0.6))
	if b.pop > 0.0:
		draw_arc(c, b.radius * (1.1 + (1.0 - b.pop) * 0.5), 0, TAU, 40, Color(1, 1, 1, b.pop * 0.8), 5.0, true)


func _draw_label(font: Font, text: String, c: Vector2, r: float, col: Color) -> void:
	var fs := int(clampf(r * 0.3, 15.0, 30.0))
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string_outline(font, c + Vector2(-ts.x * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(UITheme.INK, 0.85))
	draw_string(font, c + Vector2(-ts.x * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
