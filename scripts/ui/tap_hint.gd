class_name TapHint
extends Control
## 0.12.0 wordless "tap here" hint for small children: a pulsing ring on a
## touch button and a hand that taps it, instead of a sentence. Fades out
## after `duration` seconds or when `dismiss()` is called.
## 0.13.0 modes:
##  "tap"       - tap one button (item);
##  "alternate" - the hand moves between several buttons, tapping each in
##                turn (steer left / right);
##  "hold"      - press and HOLD (a ring fills around the button), then let go
##                with a burst (drift: hold, turn, release).

const HOLD_TIME := 1.3 ## s the ring takes to fill
const CYCLE_ALT := 0.9 ## s per button in "alternate"

var target := Vector2.ZERO ## centre of the button (parent coordinates)
var radius := 60.0 ## button radius
var targets: Array = [] ## [[centre, radius], ...] for "alternate"
var mode := "tap"
var duration := 3.2
var _t := 0.0
var _hand: TextureRect
var _gone := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if targets.is_empty():
		targets = [[target, radius]]
	_hand = TextureRect.new()
	_hand.texture = UITheme.icon("hint_tap")
	_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hand.custom_minimum_size = Vector2(96, 96)
	_hand.size = Vector2(96, 96)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand)


## Which target the hand is on now (index into `targets`).
func current_index() -> int:
	if mode == "alternate" and targets.size() > 1:
		return int(_t / CYCLE_ALT) % targets.size()
	return 0


## 0..1 press depth of the hand (1 = finger down).
func press() -> float:
	match mode:
		"hold":
			var c := fmod(_t, HOLD_TIME + 0.7)
			if c < 0.25:
				return c / 0.25 # finger goes down
			if c < 0.25 + HOLD_TIME:
				return 1.0 # held
			return clampf(1.0 - (c - 0.25 - HOLD_TIME) / 0.2, 0.0, 1.0) # let go
		"alternate":
			var c := fmod(_t, CYCLE_ALT) / CYCLE_ALT
			return 0.5 - 0.5 * cos(c * TAU)
	return 0.5 - 0.5 * cos(_t * TAU * 1.1)


## 0..1 fill of the hold ring ("hold" mode).
func hold_fill() -> float:
	if mode != "hold":
		return 0.0
	var c := fmod(_t, HOLD_TIME + 0.7)
	return clampf((c - 0.25) / HOLD_TIME, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	var tg: Array = targets[current_index()]
	var c: Vector2 = tg[0]
	var r: float = tg[1]
	# The fingertip sits at (44, 10) of the 128 px art -> (33, 7.5) at 96 px.
	# Near the bottom edge the hand would be cut off, so it comes from above,
	# flipped (fingertip then at (33, 88.5)).
	var p := press()
	var from_above := c.y + r + 110.0 > size.y and size.y > 0.0
	_hand.flip_v = from_above
	var off := Vector2(r * 0.35, r * 0.55) + Vector2(14, 18) * (1.0 - p)
	if from_above:
		off = Vector2(r * 0.35, -r * 0.55) + Vector2(14, -18) * (1.0 - p)
		_hand.position = c + off - Vector2(33, 88.5)
	else:
		_hand.position = c + off - Vector2(33, 7.5)
	_hand.pivot_offset = Vector2(33, 88.5 if from_above else 7.5)
	_hand.scale = Vector2.ONE * (1.0 - 0.08 * p)
	if _t > duration and not _gone:
		dismiss()
	queue_redraw()


func _draw() -> void:
	var tg: Array = targets[current_index()]
	var c: Vector2 = tg[0]
	var r: float = tg[1]
	if mode == "hold":
		var f := hold_fill()
		draw_arc(c, r * 1.08, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 8.0, true)
		if f > 0.0:
			draw_arc(c, r * 1.08, -PI * 0.5, -PI * 0.5 + TAU * f, 48, Color(1.0, 0.86, 0.25, 0.95), 8.0, true)
		var cyc := fmod(_t, HOLD_TIME + 0.7)
		if cyc > 0.25 + HOLD_TIME: # release burst
			var k := clampf((cyc - 0.25 - HOLD_TIME) / 0.7, 0.0, 1.0)
			draw_arc(c, r * (1.1 + 0.7 * k), 0.0, TAU, 48, Color(1.0, 0.6, 0.2, 1.0 - k), 6.0, true)
		return
	var k := fmod(_t * (1.0 / CYCLE_ALT if mode == "alternate" else 1.1), 1.0)
	draw_arc(c, r * (1.0 + 0.45 * k), 0.0, TAU, 48, Color(1.0, 0.86, 0.25, (1.0 - k) * 0.9), 6.0, true)
	draw_arc(c, r * 1.02, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)


func dismiss() -> void:
	if _gone:
		return
	_gone = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
