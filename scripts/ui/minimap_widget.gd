class_name MinimapWidget
extends Control
## Compact minimap: track outline (main + shortcut), finish marker and racer
## dots (player larger, ringed). Rotated so north is up.

var race: RaceManager
var _poly := PackedVector2Array()
var _short_polys: Array[PackedVector2Array] = []
var _bounds := Rect2()
var _scale := 1.0
var _offset := Vector2.ZERO


func setup(p_race: RaceManager) -> void:
	race = p_race
	var td := race.track
	var pts: Array[Vector2] = []
	for p in td.main.points:
		pts.append(Vector2(p.x, p.z))
	_bounds = Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		_bounds = _bounds.expand(p)
	_poly = PackedVector2Array(pts)
	_poly.append(pts[0])
	for sc in td.shortcuts:
		var sp := PackedVector2Array()
		for p in sc.path.points:
			sp.append(Vector2(p.x, p.z))
		_short_polys.append(sp)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	var pad := 10.0
	var avail := size - Vector2(pad, pad) * 2.0
	if _bounds.size.x <= 0.0 or avail.x <= 0.0:
		return
	_scale = minf(avail.x / _bounds.size.x, avail.y / _bounds.size.y)
	_offset = Vector2(pad, pad) + (avail - _bounds.size * _scale) * 0.5 - _bounds.position * _scale


func _to_map(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z) * _scale + _offset


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if race == null:
		return
	draw_style_box(UITheme.rounded(Color(UITheme.NAVY_DEEP, 0.55), 18, 2, Color(1, 1, 1, 0.12), 0), Rect2(Vector2.ZERO, size))
	var mp := PackedVector2Array()
	for p in _poly:
		mp.append(p * _scale + _offset)
	draw_polyline(mp, Color(0, 0, 0, 0.45), 9.0, true)
	draw_polyline(mp, Color(1, 0.98, 0.92, 0.95), 5.0, true)
	for sp in _short_polys:
		var m2 := PackedVector2Array()
		for p in sp:
			m2.append(p * _scale + _offset)
		draw_polyline(m2, Color(0.85, 0.75, 0.55, 0.9), 3.0, true)
	var fin := _to_map(race.track.main.position_at(race.track.finish_s))
	draw_rect(Rect2(fin - Vector2(4, 4), Vector2(8, 8)), Color.BLACK)
	draw_rect(Rect2(fin - Vector2(4, 4), Vector2(4, 4)), Color.WHITE)
	draw_rect(Rect2(fin, Vector2(4, 4)), Color.WHITE)
	for r in race.racers:
		if r.is_player:
			continue
		var c := _to_map(r.kart.global_position)
		draw_circle(c, 5.5, Color(0, 0, 0, 0.6))
		draw_circle(c, 4.0, r.paint)
	if race.player:
		var pc := _to_map(race.player.kart.global_position)
		var f := race.player.kart.forward_dir()
		var dir := Vector2(f.x, f.z).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var tri := PackedVector2Array([pc + dir * 9.0, pc - dir * 6.0 + perp * 6.0, pc - dir * 6.0 - perp * 6.0])
		draw_circle(pc, 9.0, Color(0, 0, 0, 0.5))
		draw_colored_polygon(tri, UITheme.GOLD)
