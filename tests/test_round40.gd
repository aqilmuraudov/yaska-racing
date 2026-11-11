extends TestCase
## Round 40 (0.20.1): the short Qarabağ map Laçın - a 1.6 km two-lane loop in
## the Həkəri valley (2 laps): the river beside the west leg with the
## boulevard and the garden café between the road and the water; LaCinema,
## Lachin Resort & Spa and the new houses on the town side; the LAÇIN sign with
## the flag; Hoçaz beyond the river, its cliff turned to the town.

const ID := "karabakh_lachin"
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


func test_registered_in_qarabag() -> void:
	check(ID in TrackList.IDS, "in the track list")
	check_eq(TrackList.region_of(ID), "karabakh", "in Qarabağ")
	check(tr(TrackList.name_key(ID)) != TrackList.name_key(ID), "name translated")
	check(tr(TrackList.desc_key(ID)) != TrackList.desc_key(ID), "description translated")
	check(ResourceLoader.exists("res://assets/ui/cities/%s.jpg" % ID), "city card picture (Blender render)")
	var n := 0
	for t in Progression.trophies():
		if String(t.get("track", "")) == ID:
			n += 1
			check(tr(String(t.name)) != String(t.name), "%s translated" % t.name)
	check_eq(n, 7, "seven Laçın trophies")
	check_eq(TrackList.max_laps(ID), 5, "a short map: 1-5 laps")
	check(TrackList.lap_scale(ID) > 0.8 and TrackList.lap_scale(ID) < 1.3, "lap ~ a Baku lap")


func test_layout() -> void:
	check(_td != null and _td.lanes == 2, "loads, two lanes")
	check_eq(_td.default_laps, 2, "two laps by default")
	check(_td.main.length > 1300.0 and _td.main.length < 1800.0, "lap %.0f m" % _td.main.length)
	var path := _td.main
	var n := path.sample_count()
	var grade := 0.0
	for i in n:
		var a := path.points[i]
		var b := path.points[(i + 5) % n]
		grade = maxf(grade, absf(b.y - a.y) / maxf(Vector2(b.x - a.x, b.z - a.z).length(), 0.1))
	check(grade < 0.09, "grade %.3f" % grade)
	var ids := {}
	for lm: Dictionary in _td.raw.landmarks:
		ids[String(lm.id)] = true
		var f := Vector2(sin(float(lm.yaw)), cos(float(lm.yaw)))
		var a := Vector2(f.y, -f.x)
		var front := Vector2(float(lm.x), float(lm.z)) + f * float(lm.d) / 2.0
		var g := INF
		for u: float in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			g = minf(g, _gap(front + a * u * float(lm.w)))
		check(g < 10.0, "%s beside the road (%.1f m)" % [lm.id, g])
		check(_gap(Vector2(float(lm.x), float(lm.z)) - f * 0.0) > 0.0, "%s off the road" % lm.id)
	for id in ["kb_cinema", "kb_hotel", "kb_garden_cafe", "kb_sign_lachin"]:
		check(ids.has(id), "%s on the map" % id)
	var houses := 0
	for lm: Dictionary in _td.raw.landmarks:
		if String(lm.id).begins_with("kb_house"):
			houses += 1
	check(houses >= 12, "town houses (%d)" % houses)
	# the Həkəri beside the west leg, the boulevard by the road
	var hk: Dictionary = _td.raw.rivers[0]
	check_eq(String(hk.id), "hakari", "the Həkəri")
	var near := 0
	var total := 0
	for i in range(0, path.sample_count(), 4):
		var p := path.points[i]
		if p.x > -110.0:
			continue
		total += 1
		var d := INF
		var pts: Array = hk.points
		for k in pts.size() - 1:
			var q := Vector2(p.x, p.z)
			d = minf(d, q.distance_to(Geometry2D.get_closest_point_to_segment(q, Vector2(pts[k][0], pts[k][1]), Vector2(pts[k + 1][0], pts[k + 1][1]))))
		var bank := d - float(hk.width) / 2.0 - path.half_width_at(path.cum[i]) - _td.offroad_width
		check(bank > 12.0, "the bank stays off the road (%.1f m)" % bank)
		if bank < 40.0:
			near += 1
	check(total > 20 and float(near) / float(total) > 0.8, "the river beside the west leg (%d / %d)" % [near, total])
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(String(_td.raw.terrain_dir) + "/lines.json"))
	var blvd := 0
	for t: Array in parsed.instances:
		if String(t[0]) == "kb_blvd_seg":
			blvd += 1
	check(blvd > 30, "the boulevard (%d modules)" % blvd)
	var pk: Array = _td.raw.get("peaks", [])
	check(pk.size() == 1 and String(pk[0].id) == "hocaz", "Hoçaz")


func test_terrain_under_the_road() -> void:
	var b := _builder()
	check(not b._heights.is_empty(), "height grid")
	var path := _td.main
	var bad := 0
	for i in range(0, path.sample_count(), 2):
		var s := path.cum[i]
		var p := path.points[i]
		var r := path.right_at(s)
		for side: float in [-1.0, 1.0]:
			for off: float in [0.0, path.half_width_at(s), path.half_width_at(s) + _td.offroad_width]:
				var q := p + r * side * off
				if b.terrain_height(q.x, q.z) > p.y - 0.25:
					bad += 1
	check_eq(bad, 0, "ground under the road and verges")
	for lm: Dictionary in _td.raw.landmarks:
		check(absf(b.terrain_height(float(lm.x), float(lm.z)) - float(lm.y)) < 0.6, "%s on its pad" % lm.id)
	var pk: Dictionary = _td.raw.peaks[0]
	var top := -INF
	for dx in range(-200, 201, 10):
		for dz in range(-200, 201, 10):
			top = maxf(top, b.terrain_height(float(pk.x) + dx, float(pk.z) + dz))
	check(top > 180.0, "Hoçaz rises %.0f m" % top)
	b.free()


func test_race_scene_builds() -> void:
	var cfg := Game.default_race_config()
	cfg.track_id = ID
	cfg.laps = 2
	cfg.time_of_day = "night"
	cfg.debug_autopilot = true
	Game.race_config = cfg
	var race: RaceManager = load("res://scenes/race/race.tscn").instantiate()
	tree.root.add_child(race)
	await tree.process_frame
	await tree.process_frame
	check(race.decor is KarabakhDecor, "Qarabağ decor")
	check(race.builder.get_node_or_null("Terrain") != null, "Blender terrain")
	check_eq(int(race.config.laps), 2, "two laps kept")
	var d: KarabakhDecor = race.decor
	for id in ["kb_cinema", "kb_hotel", "kb_garden_cafe", "kb_sign_lachin"]:
		check(d.landmarks.has(id), "%s in the scene" % id)
	check(d.landmarks.has("flag_lachin"), "the flag on the sign")
	var placed_houses := 0
	for c in d.get_children():
		if c is MultiMeshInstance3D and c.has_meta("instance_xforms") and String(c.get_meta("prop")).begins_with("kb_house"):
			placed_houses += (c.get_meta("instance_xforms") as Array).size()
	check(placed_houses >= 12, "houses placed (%d)" % placed_houses)
	var water := race.builder.get_node_or_null("Terrain/River_hakari")
	check(water != null, "the Həkəri water")
	var trees := 0
	for c in d.get_children():
		if c is MultiMeshInstance3D and c.has_meta("instance_xforms") and String(c.get_meta("prop")).begins_with("kb_") \
				and String(c.get_meta("prop")) in ["kb_beech", "kb_oak", "kb_hornbeam", "kb_maple", "kb_pine"]:
			trees += (c.get_meta("instance_xforms") as Array).size()
	check(trees > 600, "forest around the town (%d)" % trees)
	race.queue_free()
	await tree.process_frame
