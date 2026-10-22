class_name DriftMeterWidget
extends Control
## Drift / boost meter readable on a phone: a thick bar with a hatched boost
## window, a marked perfect zone, three tier pips with numbers, and a "GO"
## chevron that pops when the window is open. Timing never relies on colour
## alone: the window is hatched, the pips are numbered and the bar pulses.

var kart: KartController
var high_contrast := false
var _flash := 0.0
var _flash_text := ""
var _flash_good := true
var _pulse := 0.0


func show_result(text: String, good: bool) -> void:
	_flash = 0.9
	_flash_text = text
	_flash_good = good


func _process(delta: float) -> void:
	_pulse += delta
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if kart == null:
		return
	var dm := kart.drift
	var drifting := kart.is_drifting()
	if not drifting and _flash <= 0.0:
		return
	var font := UITheme.bold_font()
	var w := size.x
	var h := minf(size.y * 0.42, 30.0)
	var bar := Rect2(Vector2(0, size.y - h - 4), Vector2(w, h))
	var alpha := 1.0 if drifting else clampf(_flash * 2.0, 0.0, 1.0)
	var bg := Color(UITheme.NAVY_DEEP, 0.85 * alpha)
	draw_style_box(UITheme.rounded(bg, int(h * 0.5), 3, Color(1, 1, 1, 0.25 * alpha), 0), bar.grow(4))
	# Window and perfect zone
	var wx := bar.position.x + bar.size.x * dm.window_start
	var px := bar.position.x + bar.size.x * dm.perfect_start
	var win := Rect2(Vector2(wx, bar.position.y), Vector2(bar.end.x - wx, bar.size.y))
	draw_rect(win, Color(1, 0.79, 0.24, 0.28 * alpha))
	# Hatching (shape cue for the window)
	var step := 9.0
	var x := win.position.x
	while x < win.end.x + h:
		var a := Vector2(clampf(x, win.position.x, win.end.x), win.end.y)
		var b := Vector2(clampf(x + h, win.position.x, win.end.x), win.position.y)
		draw_line(a, b, Color(1, 1, 1, 0.22 * alpha), 2.0)
		x += step
	draw_line(Vector2(px, bar.position.y - 3), Vector2(px, bar.end.y + 3), Color(1, 1, 1, 0.9 * alpha), 3.0)
	# Fill
	var ready := dm.in_window()
	var fill_col := UITheme.TURQUOISE
	if ready:
		fill_col = UITheme.GOLD if not dm.in_perfect() else Color("ffffff")
	if high_contrast:
		fill_col = Color.WHITE if ready else Color("9fe8ff")
	var fill := Rect2(bar.position, Vector2(bar.size.x * clampf(dm.meter, 0.0, 1.0), bar.size.y))
	if fill.size.x > 2.0:
		draw_style_box(UITheme.rounded(Color(fill_col, alpha), int(h * 0.5), 0, Color.TRANSPARENT, 0), fill)
	if ready:
		var pulse := 0.5 + 0.5 * sin(_pulse * 18.0)
		draw_style_box(UITheme.rounded(Color.TRANSPARENT, int(h * 0.5) + 4, 4, Color(1, 1, 1, (0.5 + 0.5 * pulse) * alpha), 0), bar.grow(7))
		# "Boost now" chevrons above the bar
		var cx := win.get_center().x
		var cy := bar.position.y - 14.0
		for i in 2:
			var ox := cx - 12.0 + i * 14.0
			draw_polyline(PackedVector2Array([Vector2(ox, cy - 8), Vector2(ox + 8, cy), Vector2(ox, cy + 8)]), Color(1, 1, 1, alpha), 4.0)
	# Tier pips with numbers
	for i in DriftMeter.MAX_CHAIN:
		var c := Vector2(bar.position.x + 20 + i * 34, bar.position.y - 22)
		var done := i < dm.chain
		draw_circle(c, 14, Color(UITheme.NAVY_DEEP, 0.9 * alpha))
		draw_circle(c, 11, Color(UITheme.GOLD if done else Color(1, 1, 1, 0.18), alpha))
		var txt := str(i + 1)
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		draw_string(font, c + Vector2(-ts.x * 0.5, 6), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(UITheme.NAVY_DEEP if done else Color.WHITE, alpha))
	# Result flash text
	if _flash > 0.0 and _flash_text != "":
		var fs := 30
		var tsz := UITheme.heading_font().get_string_size(_flash_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var pos := Vector2(w * 0.5 - tsz.x * 0.5, bar.position.y - 30)
		var col := UITheme.GOLD if _flash_good else Color("ff8a8a")
		draw_string_outline(UITheme.heading_font(), pos, _flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0, 0, 0, 0.6 * minf(_flash * 2.0, 1.0)))
		draw_string(UITheme.heading_font(), pos, _flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, minf(_flash * 2.0, 1.0)))
