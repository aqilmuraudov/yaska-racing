class_name MinimapWidget
extends Control
## Minimap (0.9.3): the track drawn as a tilted 3D ribbon (2D perspective
## projection of the centreline, no SubViewport: one polyline set per frame).
## Heading-up: the map turns slowly with the player (smoothed, so it is never
## dizzy). Karts are big coloured dots with a white ring and a ground shadow;
## the player is a gold arrow with a pulse; the two nearest rivals show their
## place number.

const TILT := 0.66     ## cos(~49°): vertical squash of the ground plane
const PERSP := 0.3     ## near rows bigger, far rows smaller
const LIFT := 5.0      ## marker height above its shadow (px)
const TURN_RATE := 2.2 ## heading smoothing (1/s)
const AHEAD_M := 110.0 ## metres visible ahead of the player (~160 m total)
const ANCHOR_Y := 0.7  ## player row (fraction of height)
const DOT_R := 15.0    ## rival marker radius (px)
const EDGE := 14.0     ## inset for off-view arrows

var race: RaceManager
var _pts: Array[Vector2] = []
var _short: Array = []
var _center := Vector2.ZERO
var _radius := 1.0
var _scale := 1.0
var heading := 0.0 ## map rotation (radians); player forward points up
var _t := 0.0


func setup(p_race: RaceManager) -> void:
	race = p_race
	var td := race.track
	_pts.clear()
	var b := Rect2(Vector2(td.main.points[0].x, td.main.points[0].z), Vector2.ZERO)
	for p in td.main.points:
		_pts.append(Vector2(p.x, p.z))
		b = b.expand(Vector2(p.x, p.z))
	_center = b.get_center()
	_radius = 1.0
	for p in _pts:
		_radius = maxf(_radius, p.distance_to(_center))
	for sc in td.shortcuts:
		var sp: Array[Vector2] = []
		for p in sc.path.points:
			sp.append(Vector2(p.x, p.z))
		_short.append(sp)
	if race.player:
		heading = _target_heading()
	clip_contents = true
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	# Radar zoom: ~AHEAD_M metres from the player to the top edge.
	if size.y <= 0.0:
		return
	var top := anchor().y - 8.0
	_scale = top / (AHEAD_M * TILT / (1.0 + PERSP * 0.5))


## Player's pixel position (lower-centre).
func anchor() -> Vector2:
	return Vector2(size.x * 0.5, size.y * ANCHOR_Y)


func _origin() -> Vector2:
	if race and race.player:
		var g := race.player.kart.global_position
		return Vector2(g.x, g.z)
	return _center


func _target_heading() -> float:
	var f := race.player.kart.forward_dir()
	return atan2(f.x, -f.z)


## World position → widget pixels (rotation, tilt and perspective).
func map(p: Vector3) -> Vector2:
	return project(Vector2(p.x, p.z))


func project(q: Vector2) -> Vector2:
	var d := (q - _origin()).rotated(-heading)
	var yn := clampf(d.y / AHEAD_M, -1.0, 1.0)
	var k := 1.0 / (1.0 - PERSP * yn * 0.5)
	return anchor() + Vector2(d.x * k, d.y * TILT * k) * _scale


## Perspective size factor at a widget point (1 = middle row).
func depth_scale(m: Vector2) -> float:
	return clampf(1.0 + (m.y - size.y * 0.5) / maxf(size.y, 1.0) * 0.5, 0.75, 1.25)


func _process(delta: float) -> void:
	if race and race.player:
		heading = lerp_angle(heading, _target_heading(), 1.0 - exp(-TURN_RATE * delta))
	_t += delta
	queue_redraw()


func _line(pts: Array, closed: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(project(p))
	if closed and not pts.is_empty():
		out.append(project(pts[0]))
	return out


func _draw() -> void:
	if race == null:
		return
	draw_style_box(UITheme.rounded(Color(UITheme.NAVY_DEEP, 0.6), 18, 2, Color(1, 1, 1, 0.16), 0), Rect2(Vector2.ZERO, size))
	var mp := _line(_pts, true)
	# Thickness: dark slab under the ribbon, then white edge lines and asphalt.
	var drop := PackedVector2Array()
	for p in mp:
		drop.append(p + Vector2(0, 4))
	var w := clampf(18.0 * _scale, 50.0, 64.0)
	for sp in _short:
		draw_polyline(_line(sp, false), Color(0.85, 0.75, 0.55, 0.9), w * 0.55, true)
	draw_polyline(drop, Color(0, 0, 0, 0.5), w + 2.0, true)
	draw_polyline(mp, Color(1, 1, 1, 0.95), w, true)
	draw_polyline(mp, Color("4a5060"), w - 5.0, true)
	draw_polyline(mp, Color(1, 0.86, 0.3, 0.6), 2.0, true)
	# Start/finish checker across the ribbon.
	var fs := race.track.finish_s
	var fin := map(race.track.main.position_at(fs))
	var ahead := map(race.track.main.position_at(fs + 4.0))
	var along := (ahead - fin).normalized() if ahead.distance_to(fin) > 0.01 else Vector2.RIGHT
	var across := Vector2(-along.y, along.x)
	for i in 4:
		for j in 2:
			var o := fin + across * (i - 2) * w * 0.25 + along * (j - 1) * w * 0.25
			draw_rect(Rect2(o, Vector2(w, w) * 0.25), Color.WHITE if (i + j) % 2 == 0 else Color.BLACK)
	# Rivals: sorted far → near so nearer markers draw on top.
	var rivals: Array = []
	for r in race.racers:
		if not r.is_player:
			rivals.append(r)
	rivals.sort_custom(func(a, b): return map(a.kart.global_position).y < map(b.kart.global_position).y)
	var font := ThemeDB.fallback_font
	var inner := Rect2(Vector2.ONE * EDGE, size - Vector2.ONE * EDGE * 2.0)
	var placed: Array[Vector2] = [anchor()]
	for r in rivals:
		var g := map(r.kart.global_position)
		if inner.has_point(g):
			g = declutter(g, placed)
			placed.append(g)
		if not inner.has_point(g):
			_edge_arrow(g, r, font)
			continue
		var s := depth_scale(g)
		draw_set_transform(g + Vector2(0, 3), 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, DOT_R * s, Color(0, 0, 0, 0.45))
		draw_set_transform(Vector2.ZERO)
		var c := g - Vector2(0, LIFT * s)
		draw_circle(c, DOT_R * s, Color.WHITE)
		draw_circle(c, (DOT_R - 3.0) * s, r.paint)
		_num(font, c, str(r.place), int(15 * s))
	if race.player:
		var pg := map(race.player.kart.global_position)
		draw_set_transform(pg + Vector2(0, 2), 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.5))
		draw_set_transform(Vector2.ZERO)
		var pc := pg - Vector2(0, LIFT + 2.0)
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		draw_arc(pc, 12.0 + pulse * 5.0, 0.0, TAU, 24, Color(UITheme.GOLD, 0.6 * (1.0 - pulse)), 2.5, true)
		var f := race.player.kart.forward_dir()
		var dir := (map(race.player.kart.global_position + f) - pg).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		var perp := Vector2(-dir.y, dir.x)
		var tri := PackedVector2Array([pc + dir * 13.0, pc - dir * 8.0 + perp * 9.0, pc - dir * 4.0, pc - dir * 8.0 - perp * 9.0])
		draw_colored_polygon(tri, Color.WHITE)
		var inner_tri := PackedVector2Array([pc + dir * 9.5, pc - dir * 5.5 + perp * 6.0, pc - dir * 2.5, pc - dir * 5.5 - perp * 6.0])
		draw_colored_polygon(inner_tri, UITheme.GOLD)
	draw_style_box(UITheme.rounded(Color(0, 0, 0, 0), 18, 3, Color(1, 1, 1, 0.35), 0), Rect2(Vector2.ZERO, size))


func _num(font: Font, c: Vector2, t: String, fs: int) -> void:
	var o := c + Vector2(-font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, fs * 0.36)
	draw_string_outline(font, o, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color.BLACK)
	draw_string(font, o, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Nudge a marker sideways so packed karts stay readable (never on the player).
func declutter(g: Vector2, placed: Array[Vector2]) -> Vector2:
	var minsep := DOT_R * 2.3
	for _i in 6:
		var hit := false
		for q in placed:
			if g.distance_to(q) < minsep:
				var side := 1.0 if g.x >= q.x else -1.0
				g.x = q.x + side * sqrt(maxf(minsep * minsep - (g.y - q.y) * (g.y - q.y), 0.0)) + side
				hit = true
		if not hit:
			break
	return g


## Point on the panel edge (inset) toward widget point g, seen from the player.
func edge_point(g: Vector2) -> Vector2:
	var a := anchor()
	var d := g - a
	if d.length() < 0.001:
		return a
	var lo := Vector2.ONE * EDGE
	var hi := size - Vector2.ONE * EDGE
	var t := INF
	if d.x > 0.0: t = minf(t, (hi.x - a.x) / d.x)
	if d.x < 0.0: t = minf(t, (lo.x - a.x) / d.x)
	if d.y > 0.0: t = minf(t, (hi.y - a.y) / d.y)
	if d.y < 0.0: t = minf(t, (lo.y - a.y) / d.y)
	return a + d * minf(t, 1.0)


func _edge_arrow(g: Vector2, r, font: Font) -> void:
	var e := edge_point(g)
	var dir := (g - anchor()).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var tri := PackedVector2Array([e + dir * 9.0, e - dir * 7.0 + perp * 9.0, e - dir * 7.0 - perp * 9.0])
	draw_colored_polygon(tri, Color.WHITE)
	var tri2 := PackedVector2Array([e + dir * 5.5, e - dir * 4.5 + perp * 5.5, e - dir * 4.5 - perp * 5.5])
	draw_colored_polygon(tri2, r.paint)
	_num(font, e - dir * 17.0, str(r.place), 12)


## The n rivals closest to the player (for place numbers).
func nearest_rivals(n: int) -> Array:
	var out: Array = []
	if race == null or race.player == null:
		return out
	var pp := race.player.kart.global_position
	for r in race.racers:
		if not r.is_player:
			out.append(r)
	out.sort_custom(func(a, b): return a.kart.global_position.distance_squared_to(pp) < b.kart.global_position.distance_squared_to(pp))
	return out.slice(0, n)
