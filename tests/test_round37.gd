extends TestCase
## Round 37 (0.19.2): owner 2026-11-11 - "hər şəhərin girişində şəhərin adı,
## üzərində bayraq, görünən ölçüdə"; every building / sight right beside the
## road; the Həkəri and the things by it (boulevard, café) beside the road so
## they are seen while racing.

var _td: TrackData


func before_each() -> void:
	_td = TrackData.load_from_file(TrackList.path("karabakh"))


func _lm(id: String) -> Dictionary:
	for lm: Dictionary in _td.raw.landmarks:
		if String(lm.id) == id:
			return lm
	return {}


func _front(lm: Dictionary) -> Vector2:
	return Vector2(sin(float(lm.yaw)), cos(float(lm.yaw)))


func _gap(p: Vector2) -> float:
	var c := _td.main.closest(Vector3(p.x, 0, p.y))
	return c.distance - _td.main.half_width_at(c.s) - _td.offroad_width


func test_town_entry_signs() -> void:
	var path := _td.main
	for zone in ["khankendi", "shusha", "lachin"]:
		var lm := _lm("kb_sign_" + zone)
		check(not lm.is_empty(), "%s has an entry sign" % zone)
		if lm.is_empty():
			continue
		var z: Array = []
		for zz: Array in _td.raw.zones:
			if String(zz[0]) == zone:
				z = zz
		var p := Vector2(float(lm.x), float(lm.z))
		var c := path.closest(Vector3(p.x, 0, p.y))
		# right beside the road (behind the guardrail), large, facing the oncoming karts
		var fr := _front(lm)
		var ax := Vector2(fr.y, -fr.x)
		var g := INF
		for u: float in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			g = minf(g, _gap(p + ax * u * float(lm.w) + fr * float(lm.d) / 2.0))
		check(g > 0.0 and g < 6.0, "%s sign %.1f m behind the run-off" % [zone, g])
		check(float(lm.w) >= 20.0, "%s sign %.0f m wide" % [zone, float(lm.w)])
		var t := path.tangent_at(c.s)
		var against := _front(lm).dot(-Vector2(t.x, t.z))
		check(against > 0.7, "%s sign faces the karts (%.2f)" % [zone, against])
		# before the town: the zone starts within 250 m after it, not before
		var s_in := -1.0
		var s: float = c.s
		while s < c.s + 300.0:
			var q := path.position_at(fposmod(s, path.length))
			if Vector2(q.x - float(z[1]), q.z - float(z[2])).length() < float(z[3]):
				s_in = s
				break
			s += 2.0
		check(s_in > 0.0 and s_in - c.s < 250.0, "%s sign stands before the town (%.0f m)" % [zone, s_in - c.s])
		var r := path.right_at(c.s)
		check(Vector2(r.x, r.z).dot(p - Vector2(c.point.x, c.point.z)) > 0.0, "%s sign on the right" % zone)


func test_landmarks_beside_the_road() -> void:
	for lm: Dictionary in _td.raw.landmarks:
		var id := String(lm.id)
		var worst := INF
		var f := _front(lm)
		var a := Vector2(f.y, -f.x)
		var front_c := Vector2(float(lm.x), float(lm.z)) + f * float(lm.d) / 2.0
		for u: float in [-0.4, 0.0, 0.4]:
			worst = minf(worst, _gap(front_c + a * u * float(lm.w)))
		var limit := 14.0 if id == "kb_garden_cafe" else 10.0
		check(worst < limit, "%s front %.1f m behind the run-off" % [id, worst])


func test_view_to_every_landmark_is_open() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(String(_td.raw.terrain_dir) + "/trees.json"))
	var trees: Array = parsed.trees
	for lm: Dictionary in _td.raw.landmarks:
		var id := String(lm.id)
		if id == "kb_garden_cafe":
			continue
		var f := _front(lm)
		var front_c := Vector2(float(lm.x), float(lm.z)) + f * float(lm.d) / 2.0
		var c := _td.main.closest(Vector3(front_c.x, 0, front_c.y))
		var edge := Vector2(c.point.x, c.point.z)
		var blocked := 0
		for t: Array in trees:
			if String(t[0]) in ["kb_bush", "kb_rock"]:
				continue
			var p := Vector2(float(t[1]), float(t[3]))
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, edge, front_c)) < 3.0:
				blocked += 1
		check_eq(blocked, 0, "%s: no tree between the road and its front" % id)


func test_hakari_by_the_road_in_lachin() -> void:
	var hk: Dictionary = _td.raw.rivers[1]
	check_eq(String(hk.id), "hakari", "the Həkəri")
	var path := _td.main
	var lz: Array = []
	for zz: Array in _td.raw.zones:
		if String(zz[0]) == "lachin":
			lz = zz
	# along the town the water stays within 40 m of the run-off, never closer than 15 m
	var near := 0
	var total := 0
	var closest := INF
	for i in range(0, path.sample_count(), 4):
		var p := path.points[i]
		if Vector2(p.x - float(lz[1]), p.z - float(lz[2])).length() > float(lz[3]):
			continue
		total += 1
		var d := INF
		var pts: Array = hk.points
		for k in pts.size() - 1:
			var a := Vector2(pts[k][0], pts[k][1])
			var b := Vector2(pts[k + 1][0], pts[k + 1][1])
			var q := Vector2(p.x, p.z)
			d = minf(d, q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)))
		var bank := d - float(hk.width) / 2.0 - path.half_width_at(path.cum[i]) - _td.offroad_width
		closest = minf(closest, bank)
		if bank < 40.0:
			near += 1
	check(total > 20, "the road runs through Laçın")
	check(float(near) / float(total) > 0.6, "the Həkəri beside the road for most of Laçın (%d / %d)" % [near, total])
	check(closest > 12.0, "the bank stays %.1f m from the run-off" % closest)
	# the boulevard and the café between the road and the water, close to the road
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(String(_td.raw.terrain_dir) + "/lines.json"))
	var cafe := _lm("kb_garden_cafe")
	var cp := Vector2(float(cafe.x), float(cafe.z))
	var blvd := 0
	for t: Array in parsed.instances:
		if String(t[0]) == "kb_blvd_seg":
			blvd += 1
			var bp := Vector2(float(t[1]), float(t[3]))
			# by the road, or right behind the café where the river swings out for it
			check(_gap(bp) < 12.0 or bp.distance_to(cp) < 45.0, "boulevard by the road (%.1f m)" % _gap(bp))
	check(blvd > 20, "a long boulevard (%d modules)" % blvd)
	var cc := path.closest(Vector3(cp.x, 0, cp.y))
	var to_road := (Vector2(cc.point.x, cc.point.z) - cp).normalized()
	check(_front(cafe).dot(to_road) > 0.7, "the café terrace faces the road")


func test_fortress_wall_by_the_road() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(String(_td.raw.terrain_dir) + "/lines.json"))
	var n := 0
	for t: Array in parsed.instances:
		if String(t[0]) == "kb_wall_seg":
			n += 1
			check(_gap(Vector2(float(t[1]), float(t[3]))) < 8.0, "wall segment by the road")
	check(n > 25, "a long wall (%d segments)" % n)
