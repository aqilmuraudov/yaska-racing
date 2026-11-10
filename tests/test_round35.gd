extends TestCase
## Round 35 (0.19.0): the big Qarabağ map - one 4.9 km lap Xankəndi -> Şuşa
## plateau -> Laçın -> Həkəri valley -> the Araz bank with the Xudafərin
## bridges -> forest hills back to Xankəndi. Zones, rivers, the bridges
## (tools/blender/karabakh_bridges.py) and the one-lap rule.

const PROFILE := "user://test_profile_r35.json"
var _orig_profile := ""
var _orig_config := {}
var _td: TrackData


func before_each() -> void:
	_orig_profile = SaveManager.save_path
	_orig_config = Game.race_config.duplicate(true)
	SaveManager.save_path = PROFILE
	SafeFile.delete_all(PROFILE)
	SaveManager.load_profile()
	_td = TrackData.load_from_file(TrackList.path("karabakh"))


func after_each() -> void:
	SafeFile.delete_all(PROFILE)
	SaveManager.save_path = _orig_profile
	SaveManager.load_profile()
	Game.race_config = _orig_config


func _builder() -> TrackBuilder:
	var b := TrackBuilder.new()
	b.data = _td
	b._make_materials()
	b._build_blender_terrain(String(_td.raw.terrain_dir))
	return b


func _poly_dist(p: Vector2, pts: Array) -> float:
	var best := INF
	for i in pts.size() - 1:
		var a := Vector2(pts[i][0], pts[i][1])
		var c := Vector2(pts[i + 1][0], pts[i + 1][1])
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, c)))
	return best


func test_zones_on_the_course() -> void:
	var zones: Array = _td.raw.get("zones", [])
	check_eq(zones.size(), 4, "four zones")
	var order := []
	for z: Array in zones:
		var c := _td.main.closest(Vector3(z[1], 0, z[2]))
		check(c.distance < float(z[3]) * 0.5, "%s lies on the road (%.0f m)" % [z[0], c.distance])
		order.append([c.s if c.s >= _td.finish_s else c.s + _td.main.length, String(z[0])])
	order.sort_custom(func(a, b): return a[0] < b[0])
	var names := []
	for o in order:
		names.append(o[1])
	check_eq(names, ["khankendi", "shusha", "lachin", "khudafarin"], "the trip: Xankəndi, Şuşa, Laçın, Xudafərin")
	# The geography: Şuşa is the high plateau, the Araz bank the lowest ground.
	var y := {}
	for z: Array in zones:
		y[String(z[0])] = _td.main.position_at(_td.main.closest(Vector3(z[1], 0, z[2])).s).y
	check(y.shusha > y.lachin + 15.0 and y.shusha > y.khankendi + 25.0, "Şuşa stands high (%s)" % y)
	check(y.khudafarin < y.lachin - 10.0 and y.khudafarin < y.khankendi - 5.0, "the Araz bank is the low point")


func test_rivers_beside_the_road() -> void:
	var rivers: Array = _td.raw.get("rivers", [])
	check_eq(rivers.size(), 2, "the Araz and the Həkəri")
	var b := _builder()
	var path := _td.main
	for rv: Dictionary in rivers:
		var hw := float(rv.width) * 0.5
		var closest := INF
		var wet := 0
		for i in range(0, path.sample_count(), 2):
			var p := path.points[i]
			var d := _poly_dist(Vector2(p.x, p.z), rv.points) - hw
			closest = minf(closest, d)
			# The road never dips to the water (the Araz level; the Həkəri ends at -2.4).
			if d < 60.0 and p.y < float(rv.get("level", -2.4) if rv.get("level") != null else -2.4) + 3.0:
				wet += 1
		check(closest > path.half_width_at(0.0) + _td.offroad_width + 8.0, "%s: the road stays %.0f m off the bank" % [rv.id, closest])
		check(closest < 120.0, "%s: seen from the road" % rv.id)
		check_eq(wet, 0, "%s: the road stays above the water" % rv.id)
	# The Araz bed lies under its water level, the banks above it.
	var araz: Dictionary = rivers[0]
	check_eq(String(araz.id), "araz", "the Araz first")
	var level := float(araz.level)
	for x: float in [-400.0, -170.0, 0.0, 80.0, 300.0]:
		var zc := 0.0
		for i in araz.points.size() - 1:
			var a: Array = araz.points[i]
			var c: Array = araz.points[i + 1]
			if x >= float(a[0]) and x <= float(c[0]):
				zc = lerpf(float(a[1]), float(c[1]), (x - float(a[0])) / (float(c[0]) - float(a[0])))
		check(b.terrain_height(x, zc) < level - 0.8, "river bed under the water at x %.0f (%.1f)" % [x, b.terrain_height(x, zc)])
		check(b.terrain_height(x, zc - float(araz.width) * 0.5 - 12.0) > level, "north bank above the water at x %.0f" % x)
		check(b.terrain_height(x, zc + float(araz.width) * 0.5 + 12.0) > level, "south bank above the water at x %.0f" % x)
	b.free()


func test_khudafarin_bridges() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(String(_td.raw.terrain_dir) + "/bridges.json"))
	check(typeof(parsed) == TYPE_DICTIONARY, "bridges.json")
	var count := {}
	var path := _td.main
	var araz: Dictionary = _td.raw.rivers[0]
	var nearest := INF
	for t: Array in parsed.instances:
		var id := String(t[0])
		count[id] = int(count.get(id, 0)) + 1
		check_near(float(t[2]), float(araz.level), 0.01, "%s stands at the water level" % id)
		var p := Vector3(t[1], 0, t[3])
		var c := path.closest(p)
		nearest = minf(nearest, c.distance - path.half_width_at(c.s) - _td.offroad_width)
		var near := PropKit.get_mesh(id)
		var far := PropKit.get_mesh(id + PropKit.LO_SUFFIX)
		check(near != null and far != null, "%s near / far models" % id)
	check(nearest > 2.0, "no bridge stone on the road or the run-off (%.1f m)" % nearest)
	check(nearest < 25.0, "the 15-span bridge starts beside the road")
	# The 15-span bridge: 15 arches on 16 piers, an approach ramp at each end.
	check_eq(int(count.get("kb_br_arch_w", 0)) + int(count.get("kb_br_arch_n", 0)), 15, "fifteen spans")
	check(int(count.get("kb_br_arch_w", 0)) > 0 and int(count.get("kb_br_arch_n", 0)) > 0, "spans of two widths")
	check_eq(int(count.get("kb_br_pier", 0)), 16, "sixteen piers")
	check_eq(int(count.get("kb_br_ramp", 0)), 2, "two ramps")
	# The broken 11-span bridge: three spans stand on four piers, eight piers are ruins.
	check_eq(int(count.get("kb_br11_arch", 0)), 3, "three standing spans")
	check_eq(int(count.get("kb_br11_pier", 0)), 4, "four whole piers")
	check_eq(int(count.get("kb_br11_ruin_a", 0)) + int(count.get("kb_br11_ruin_b", 0)), 8, "eight ruined piers")
	# Both cross the whole river, the old bridge upstream (west) of the 15-span one.
	var info: Dictionary = parsed.bridges
	for k in ["khudafarin15", "khudafarin11"]:
		var bi: Dictionary = info[k]
		check(float(bi.z_north) < float(bi.river_z) - float(araz.width) * 0.5 and float(bi.z_south) > float(bi.river_z) + float(araz.width) * 0.5, "%s spans bank to bank" % k)
	check(float(info.khudafarin11.x) < float(info.khudafarin15.x) - 150.0, "the 11-span bridge lies upstream")
	var tris := 0
	for id in count:
		var m := PropKit.get_mesh(id)
		for si in m.get_surface_count():
			tris += m.surface_get_array_index_len(si) / 3 * int(count[id])
	check(tris < 30000, "both bridges %d triangles near" % tris)


func test_one_lap_everywhere() -> void:
	check_eq(TrackList.max_laps("karabakh"), 1, "Qarabağ: one lap")
	check_eq(TrackList.max_laps("seafront_sprint"), 5, "the city tracks keep 1-5 laps")
	check_eq(TrackList.clamp_laps("karabakh", 3), 1, "clamped")
	check_eq(TrackList.clamp_laps("old_city", 3), 3, "untouched")
	check_eq(_td.default_laps, 1, "track default")
	for d in 60:
		var ch := DailyChallenge.generate(Time.get_date_string_from_unix_time(1_800_000_000 + d * 86400))
		if String(ch.track) == "karabakh":
			check_eq(int(ch.laps), 1, "daily on Qarabağ: one lap")
			if String(ch.type) == "time":
				check(int(ch.n) > 150 and int(ch.n) < 420, "daily time goal fits a 3-minute lap (%d s)" % int(ch.n))
		else:
			check_eq(int(ch.laps), DailyChallenge.LAPS, "daily elsewhere: unchanged")
	var cfg := Game.default_race_config()
	cfg.track_id = "karabakh"
	cfg.laps = 3
	cfg.debug_autopilot = true
	Game.race_config = cfg
	var race: RaceManager = load("res://scenes/race/race.tscn").instantiate()
	tree.root.add_child(race)
	await tree.process_frame
	await tree.process_frame
	check_eq(int(race.config.laps), 1, "a 3-lap request races one lap")
	var bridges := 0
	for c in race.decor.get_children():
		if c is MultiMeshInstance3D and c.has_meta("instance_xforms") and String(c.get_meta("prop")).begins_with("kb_br"):
			bridges += (c.get_meta("instance_xforms") as Array).size()
	check_eq(bridges, 48, "both bridges placed in the race scene")
	race.queue_free()
	await tree.process_frame
