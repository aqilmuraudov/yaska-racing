class_name SpeedGauge
extends Control
## Compact graphical speedometer: coloured semicircular dial, a smoothly
## animated needle, a small numeric readout and an outer boost ring that shows
## how much boost time is left. Everything is driven by the kart's real speed
## (KartController.speed, m/s); the dial's red zone starts at the kart's normal
## top speed, so the needle only enters it when the kart really goes faster.

var kart: KartController
var _shown := 0.0 ## displayed speed (km/h), critically damped toward real
var _vel := 0.0
var _boost_shown := 0.0
var _t := 0.0

const SPRING := 18.0 ## 1/s, needle response (critically damped)


func _process(delta: float) -> void:
	if kart == null:
		return
	_t += delta
	var real := absf(kart.speed) * 3.6
	# Critically damped spring: smooth, no overshoot, no lag at steady speed.
	# Exact critically damped step: stable for any frame time (the explicit
	# Euler step diverged to NaN on long frames > ~0.11 s, e.g. during a
	# hitch, and the readout then showed -9223372036854775808).
	var x0 := _shown - real
	var e := exp(-SPRING * delta)
	var tmp := (_vel + SPRING * x0) * delta
	_shown = real + (x0 + tmp) * e
	_vel = (_vel - SPRING * tmp) * e
	if not is_finite(_shown) or not is_finite(_vel):
		_shown = real
		_vel = 0.0
	var frac := kart.boost.time_left / maxf(kart.boost.max_stored, 0.01)
	_boost_shown = lerpf(_boost_shown, frac, 1.0 - exp(-10.0 * delta))
	queue_redraw()


func max_kmh() -> float:
	return kart.stats.top_speed * 3.6 * 1.4


func _draw() -> void:
	if kart == null:
		return
	var r := minf(size.x * 0.5, size.y) - 14.0
	var c := Vector2(size.x * 0.5, size.y - 6.0)
	var top_kmh := kart.stats.top_speed * 3.6
	var vmax := max_kmh()
	# Backplate
	_semi(c, r + 15.0, Color(UITheme.INK, 0.8))
	_semi(c, r + 8.0, Color(UITheme.BLUE_DEEP, 0.9))
	# Coloured band: green → yellow → orange up to top speed, red = boosted.
	var zones := [[0.0, 0.55, UITheme.LIME], [0.55, 0.85, UITheme.YELLOW], [0.85, 1.0, UITheme.ORANGE], [1.0, 1.4, UITheme.CORAL]]
	for z in zones:
		var a0 := PI + PI * (float(z[0]) * top_kmh / vmax)
		var a1 := PI + PI * (float(z[1]) * top_kmh / vmax)
		draw_arc(c, r - 6.0, a0, a1, 16, z[2], 12.0, true)
	# Ticks every 20 km/h
	var k := 0.0
	while k <= vmax + 0.1:
		var a := PI + PI * k / vmax
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * (r - 20.0), c + dir * (r - 13.0), Color(1, 1, 1, 0.8), 2.0, true)
		k += 20.0
	# Boost ring: time left, glowing while active.
	var boosting := kart.boost.is_active()
	draw_arc(c, r + 9.0, PI, TAU, 32, Color(UITheme.INK, 0.9), 11.0, true)
	if _boost_shown > 0.01:
		var col: Color = UITheme.TURQUOISE if kart.boost.last_source == &"item" else UITheme.ORANGE
		var glow := 0.75 + 0.25 * sin(_t * 16.0) if boosting else 0.6
		draw_arc(c, r + 9.0, PI, PI + PI * clampf(_boost_shown, 0.0, 1.0), 32, Color(col.lightened(0.2), glow), 8.0, true)
	# Needle
	var na := PI + PI * clampf(_shown / vmax, 0.0, 1.0)
	var nd := Vector2(cos(na), sin(na))
	var needle_col := Color.WHITE if _shown <= top_kmh + 1.0 else UITheme.YELLOW
	draw_line(c, c + nd * (r - 10.0), Color(UITheme.INK, 0.9), 9.0, true)
	draw_line(c, c + nd * (r - 12.0), needle_col, 4.5, true)
	draw_circle(c, 13.0, UITheme.INK)
	draw_circle(c, 9.0, needle_col)
	# Small numeric readout (secondary to the needle) in a pill on the right
	# end of the dial base, where the needle never passes.
	var font := UITheme.heading_font()
	var txt := str(int(round(maxf(_shown, 0.0))))
	var fs := int(clampf(r * 0.3, 16.0, 28.0))
	var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var unit := tr("HUD_KMH")
	var ufs := 13
	var us := UITheme.bold_font().get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, ufs)
	var pill := Rect2(c + Vector2(r + 16.0, -fs - 10.0), Vector2(maxf(ts.x, us.x) + 20.0, fs + us.y + 10.0))
	draw_style_box(UITheme.rounded(Color(UITheme.INK, 0.85), 10, 2, Color(1, 1, 1, 0.25), 0), pill)
	var tx := pill.position.x + (pill.size.x - ts.x) * 0.5
	draw_string(font, Vector2(tx, pill.position.y + fs + 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, needle_col)
	draw_string(UITheme.bold_font(), Vector2(pill.position.x + (pill.size.x - us.x) * 0.5, pill.end.y - 5.0), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, ufs, Color(1, 1, 1, 0.85))


func _semi(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var a := PI + PI * float(i) / 24.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	pts.append(c + Vector2(r, 4))
	pts.append(c + Vector2(-r, 4))
	draw_colored_polygon(pts, col)
