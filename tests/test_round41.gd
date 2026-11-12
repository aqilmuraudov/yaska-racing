extends TestCase
## Round 41 (0.20.1): Laçın as a town (owner's aerial photos, 2026-11-11): a
## dense hillside town of white houses with terracotta roofs, contour streets
## and cross streets painted into the terrain, two roundabouts, blocks of flats,
## cypresses and garden trees. The plan comes from tools/karabakh_maps_layout.py
## ("town" in the track JSON), the heights / pads from the Blender terrain
## (town.json); Godot instances everything (MultiMesh).

const ID := "karabakh_lachin"
const HOUSE_IDS := ["kb_lc_house_1", "kb_lc_house_2", "kb_lc_house_3", "kb_lc_house_4", "kb_lc_block",
		"kb_house_a", "kb_house_b", "kb_house_c"]
var _td: TrackData
var _orig_config := {}


func before_each() -> void:
	_orig_config = Game.race_config.duplicate(true)
	_td = TrackData.load_from_file(TrackList.path(ID))


func after_each() -> void:
	Game.race_config = _orig_config


func _builder() -> TrackBuilder:
	var b := TrackBuilder.new()
	b.data = _td
	b._make_materials()
	b._build_blender_terrain(String(_td.raw.terrain_dir))
	return b


func _gap(p: Vector2) -> float:
	var c := _td.main.closest(Vector3(p.x, 0, p.y))
	return c.distance - _td.main.half_width_at(c.s) - _td.offroad_width


func _corners(h: Dictionary, inset: float) -> Array:
	var f := Vector2(sin(float(h.yaw)), cos(float(h.yaw)))
	var a := Vector2(f.y, -f.x)
	var c := Vector2(float(h.x), float(h.z))
	var out := []
	for u: float in [-1.0, 1.0]:
		for v: float in [-1.0, 1.0]:
			out.append(c + a * u * (float(h.w) / 2.0 - inset) + f * v * (float(h.d) / 2.0 - inset))
	return out


func _town_instances() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(String(_td.raw.terrain_dir) + "/town.json"))
	return parsed.instances if typeof(parsed) == TYPE_DICTIONARY else []


func test_models_ready() -> void:
	for id in HOUSE_IDS + ["kb_lc_round", "kb_cypress"]:
		check(KarabakhDecor.kb_model_ready(id), "%s model" % id)


func test_town_plan() -> void:
	var town: Dictionary = _td.raw.get("town", {})
	var houses: Array = town.get("houses", [])
	check(houses.size() >= 300, "a dense town (%d houses)" % houses.size())
	var on_road := 0
	var blocks := 0
	for h: Dictionary in houses:
		check(String(h.id) in HOUSE_IDS, "%s is a town house" % h.id)
		if String(h.front) == "road":
			on_road += 1
		if String(h.id) == "kb_lc_block":
			blocks += 1
		var g := INF
		for q: Vector2 in _corners(h, 0.0):
			g = minf(g, _gap(q))
		check(g > 2.9, "%s at (%.0f, %.0f) behind the run-off (%.1f m)" % [h.id, h.x, h.z, g])
	check(on_road >= 80, "houses along the race road (%d)" % on_road)
	check(blocks >= 3, "blocks of flats (%d)" % blocks)
	# no two houses overlap (corners of one inside the other)
	var overlaps := 0
	for i in houses.size():
		var a: Dictionary = houses[i]
		for j in range(i + 1, houses.size()):
			var b: Dictionary = houses[j]
			if Vector2(float(a.x) - float(b.x), float(a.z) - float(b.z)).length() > 30.0:
				continue
			var f := Vector2(sin(float(b.yaw)), cos(float(b.yaw)))
			for q: Vector2 in _corners(a, 0.3):
				var r := q - Vector2(float(b.x), float(b.z))
				if absf(r.dot(Vector2(f.y, -f.x))) < float(b.w) / 2.0 and absf(r.dot(f)) < float(b.d) / 2.0:
					overlaps += 1
	check_eq(overlaps, 0, "no overlapping houses")
	# houses keep off the landmarks and the river
	for lm: Dictionary in _td.raw.landmarks:
		var lc := Vector2(float(lm.x), float(lm.z))
		var lf := Vector2(sin(float(lm.yaw)), cos(float(lm.yaw)))
		for h: Dictionary in houses:
			for q: Vector2 in _corners(h, 0.3):
				var r := q - lc
				var inside := absf(r.dot(Vector2(lf.y, -lf.x))) < float(lm.w) / 2.0 and absf(r.dot(lf)) < float(lm.d) / 2.0
				check(not inside, "%s clear of %s" % [h.id, lm.id])
	var streets: Array = town.get("streets", [])
	check(streets.size() >= 6, "streets (%d)" % streets.size())
	var metres := 0.0
	for st: Dictionary in streets:
		var pts: Array = st.points
		for k in pts.size():
			check(_gap(Vector2(pts[k][0], pts[k][1])) > -0.5, "%s off the race road" % st.id)
			if k > 0:
				metres += Vector2(pts[k][0], pts[k][1]).distance_to(Vector2(pts[k - 1][0], pts[k - 1][1]))
	check(metres > 2500.0, "%.0f m of streets" % metres)
	check_eq((town.get("rounds", []) as Array).size(), 2, "two roundabouts")


## The owner's complaint (2026-11-11): long empty stretches between the sights.
## Along the race road a building (house or landmark) stands within 40 m of
## every point, except beside the river (the boulevard / café side).
func test_no_empty_stretches() -> void:
	var path := _td.main
	var spots: Array = []
	for h: Dictionary in _td.raw.town.houses:
		spots.append(Vector2(float(h.x), float(h.z)))
	for lm: Dictionary in _td.raw.landmarks:
		spots.append(Vector2(float(lm.x), float(lm.z)))
	var worst := 0.0
	var where := Vector2.ZERO
	for i in range(0, path.sample_count(), 4):
		var p := Vector2(path.points[i].x, path.points[i].z)
		var best := INF
		for q: Vector2 in spots:
			best = minf(best, p.distance_to(q))
		if best > worst:
			worst = best
			where = p
	check(worst < 40.0, "the nearest building is at most %.0f m away (worst at %.0f, %.0f)" % [worst, where.x, where.y])


func test_town_on_the_terrain() -> void:
	var inst := _town_instances()
	check(inst.size() >= 302, "town.json (%d instances)" % inst.size())
	var b := _builder()
	var bad := 0
	for t: Array in inst:
		var y := b.terrain_height(float(t[1]), float(t[3]))
		if absf(y - float(t[2])) > 0.6:
			bad += 1
	check_eq(bad, 0, "every house / island on its pad")
	# houses on slopes: the pad is level under the whole footprint
	var tilted := 0
	for h: Dictionary in _td.raw.town.houses:
		var ys: Array = []
		for q: Vector2 in _corners(h, 1.5):
			ys.append(b.terrain_height(q.x, q.y))
		if (ys.max() as float) - (ys.min() as float) > 0.6:
			tilted += 1
	check_eq(tilted, 0, "level pads")
	# the town climbs a hill (the owner's photos): the middle of the loop well above the road
	var top := -INF
	for h: Dictionary in _td.raw.town.houses:
		top = maxf(top, b.terrain_height(float(h.x), float(h.z)))
	var road_max := -INF
	for p: Vector3 in _td.main.points:
		road_max = maxf(road_max, p.y)
	check(top > road_max + 8.0, "the town rises %.0f m over the road" % (top - road_max))
	b.free()


func test_race_scene_instances_the_town() -> void:
	var cfg := Game.default_race_config()
	cfg.track_id = ID
	cfg.laps = 2
	cfg.debug_autopilot = true
	Game.race_config = cfg
	var t0 := Time.get_ticks_msec()
	var race: RaceManager = load("res://scenes/race/race.tscn").instantiate()
	tree.root.add_child(race)
	await tree.process_frame
	await tree.process_frame
	print("  Laçın race scene built in %d ms (headless)" % (Time.get_ticks_msec() - t0))
	var d: KarabakhDecor = race.decor
	var counts := {}
	for c in d.get_children():
		if c is MultiMeshInstance3D and c.has_meta("instance_xforms"):
			var prop := String(c.get_meta("prop"))
			counts[prop] = int(counts.get(prop, 0)) + (c.get_meta("instance_xforms") as Array).size()
	var houses := 0
	for id in HOUSE_IDS:
		houses += int(counts.get(id, 0))
	check(houses >= 300, "houses in the scene (%d)" % houses)
	check_eq(int(counts.get("kb_lc_round", 0)), 2, "roundabout islands")
	check(int(counts.get("kb_cypress", 0)) > 50, "cypresses (%d)" % int(counts.get("kb_cypress", 0)))
	race.queue_free()
	await tree.process_frame


## The big map's Laçın got the same town (tools/karabakh_maps_layout.py karabakh: "town" only,
## its old landmarks / plots untouched).
func test_big_map_lachin_town() -> void:
	var td := TrackData.load_from_file(TrackList.path("karabakh"))
	var houses: Array = td.raw.get("town", {}).get("houses", [])
	check(houses.size() >= 200, "big map: town houses (%d)" % houses.size())
	var zones := {}
	for zn: Array in td.raw.zones:
		zones[String(zn[0])] = Vector2(float(zn[1]), float(zn[2]))
	var n_lachin := 0
	for h: Dictionary in houses:
		# 0.20.2 two towns on the big map: the Xankəndi set round Xankəndi, the rest in Laçın
		# 0.20.4 + the Şuşa old houses on the plateau (round 46)
		var zid := "khankendi" if String(h.id).begins_with("kb_xk_") else 			("shusha" if String(h.id).begins_with("kb_sh_house") else "lachin")
		if zid == "lachin":
			n_lachin += 1
		var d := Vector2(float(h.x), float(h.z)).distance_to(zones[zid])
		# the town areas (karabakh_maps_layout.py: Laçın centre 60 m east of the zone, r 240 + 15;
		# Xankəndi (640, -515) r 230)
		check(d < 320.0, "%s in %s (%.0f m from its centre)" % [h.id, zid, d])
		var g := INF
		for q: Vector2 in _corners(h, 0.0):
			var c := td.main.closest(Vector3(q.x, 0, q.y))
			g = minf(g, c.distance - td.main.half_width_at(c.s) - td.offroad_width)
		check(g > 2.9, "%s behind the run-off (%.1f m)" % [h.id, g])
	check(n_lachin >= 100, "big map: Laçın houses (%d)" % n_lachin)
	var n_xk := houses.filter(func(q): return String(q.id).begins_with("kb_xk_")).size()
	check(n_xk >= 80, "big map: Xankəndi buildings (%d)" % n_xk)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(String(td.raw.terrain_dir) + "/town.json"))
	check(typeof(parsed) == TYPE_DICTIONARY and (parsed.instances as Array).size() >= houses.size(), "big map town.json")
	var b := TrackBuilder.new()
	b.data = td
	b._make_materials()
	b._build_blender_terrain(String(td.raw.terrain_dir))
	var bad := 0
	for t: Array in parsed.instances:
		if absf(b.terrain_height(float(t[1]), float(t[3])) - float(t[2])) > 0.6:
			bad += 1
	check_eq(bad, 0, "big map: every house on its pad")
	b.free()
