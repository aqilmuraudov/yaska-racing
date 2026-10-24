class_name SpeedLines
extends Control
## Subtle speed streaks at the screen edges while the kart really travels
## faster than its normal top speed (boosts). Intensity comes from the kart's
## real speed, so streaks rise and fade with the actual acceleration. Drawn as
## a few thin lines (no full-screen shader, negligible fill cost); never in the
## middle of the screen; halved with Reduce Flashing.

const COUNT := 26

var kart: KartController
var _intensity := 0.0
var _lines: Array = [] # [angle, radial position 0..1, speed]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7
	for i in COUNT:
		_lines.append([_rng.randf() * TAU, _rng.randf(), _rng.randf_range(0.8, 1.4)])


func _process(delta: float) -> void:
	if kart == null:
		return
	var over := clampf((absf(kart.speed) / kart.stats.top_speed - 1.0) / 0.3, 0.0, 1.0)
	if Settings.get_value("accessibility", "reduced_flashing", false):
		over *= 0.5
	_intensity = lerpf(_intensity, over, 1.0 - exp(-6.0 * delta))
	if _intensity < 0.02:
		if visible:
			visible = false
		return
	visible = true
	for l in _lines:
		l[1] += delta * 2.4 * float(l[2])
		if l[1] > 1.0:
			l[1] -= 1.0
			l[0] = _rng.randf() * TAU
	queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.42) # the road's vanishing area
	var reach := size.length() * 0.55
	for l in _lines:
		var dir := Vector2(cos(float(l[0])), sin(float(l[0])))
		var p := float(l[1])
		var r0 := reach * (0.62 + p * 0.38) # outer ring only
		var r1 := r0 + reach * (0.06 + 0.1 * _intensity)
		var a := _intensity * 0.32 * sin(p * PI)
		draw_line(c + dir * r0, c + dir * r1, Color(1, 1, 1, a), 2.0 + 2.0 * _intensity, true)
