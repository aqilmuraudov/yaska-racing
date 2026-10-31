class_name TapHint
extends Control
## 0.12.0 wordless "tap here" hint for small children: a pulsing ring on a
## touch button and a hand that taps it, instead of a sentence. Fades out
## after `duration` seconds or when `dismiss()` is called.

var target := Vector2.ZERO ## centre of the button (parent coordinates)
var radius := 60.0 ## button radius
var duration := 3.2
var _t := 0.0
var _hand: TextureRect
var _gone := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hand = TextureRect.new()
	_hand.texture = UITheme.icon("hint_tap")
	_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hand.custom_minimum_size = Vector2(96, 96)
	_hand.size = Vector2(96, 96)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand)


func _process(delta: float) -> void:
	_t += delta
	# The fingertip sits at (44, 10) of the 128 px art -> (33, 7.5) at 96 px.
	var tap := 0.5 - 0.5 * cos(_t * TAU * 1.1) # 0..1, ~1.1 taps per second
	var off := Vector2(radius * 0.35, radius * 0.55) + Vector2(14, 18) * (1.0 - tap)
	_hand.position = target + off - Vector2(33, 7.5)
	_hand.scale = Vector2.ONE * (1.0 - 0.08 * tap)
	if _t > duration and not _gone:
		dismiss()
	queue_redraw()


func _draw() -> void:
	var k := fmod(_t * 1.1, 1.0)
	var col := Color(1.0, 0.86, 0.25, (1.0 - k) * 0.9)
	draw_arc(target, radius * (1.0 + 0.45 * k), 0.0, TAU, 48, col, 6.0, true)
	draw_arc(target, radius * 1.02, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)


func dismiss() -> void:
	if _gone:
		return
	_gone = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
