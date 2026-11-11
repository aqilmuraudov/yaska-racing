extends TestCase
## Round 39 (0.20.1): the first short Qarabağ map, Şuşa - a 1.5 km two-lane
## loop on the plateau (2 laps), the mosque, Vaqif's mausoleum, the ŞUŞA sign
## with the flag, the fortress wall on the gorge side; its own Blender terrain
## (tools/blender/karabakh_terrain.py --track karabakh_shusha), the landmarks
## laid out by tools/karabakh_maps_layout.py.

const ID := "karabakh_shusha"
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
	check_eq(n, 7, "seven Şuşa trophies")
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
		if lm.get("spans_road", false):
			continue # Şuşa qalası: the road through its gates (round 43)
		var f := Vector2(sin(float(lm.yaw)), cos(float(lm.yaw)))
		var a := Vector2(f.y, -f.x)
		var front := Vector2(float(lm.x), float(lm.z)) + f * float(lm.d) / 2.0
		var g := INF
		for u: float in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			g = minf(g, _gap(front + a * u * float(lm.w)))
		check(g < 10.0, "%s beside the road (%.1f m)" % [lm.id, g])
		check(_gap(Vector2(float(lm.x), float(lm.z)) - f * 0.0) > 0.0, "%s off the road" % lm.id)
	for id in ["kb_mosque", "kb_vagif", "kb_sign_shusha", "kb_bulbul"]:
		check(ids.has(id), "%s on the map" % id)
	var houses := 0
	for lm: Dictionary in _td.raw.landmarks:
		if String(lm.id).begins_with("kb_sh_house"):
			houses += 1
	check(houses >= 12, "old stone houses along the streets (%d)" % houses)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(String(_td.raw.terrain_dir) + "/lines.json"))
	var wall := 0
	for t: Array in parsed.instances:
		if String(t[0]) == "kb_wall_seg":
			wall += 1
	check_eq(wall, 0, "no long wall (0.20.1: the fortress on the road, round 43)")
	check(ids.has("kb_sh_fortress"), "Şuşa qalası")


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
	for id in ["kb_mosque", "kb_vagif", "kb_sign_shusha", "kb_bulbul"]:
		check(d.landmarks.has(id), "%s in the scene" % id)
	var placed_houses := 0
	for c in d.get_children():
		if c is MultiMeshInstance3D and c.has_meta("instance_xforms") and String(c.get_meta("prop")).begins_with("kb_sh_house"):
			placed_houses += (c.get_meta("instance_xforms") as Array).size()
	check(placed_houses >= 12, "houses placed in the race (%d)" % placed_houses)
	check(d.landmarks.has("flag_shusha"), "the flag on the sign")
	var trees := 0
	for c in d.get_children():
		if c is MultiMeshInstance3D and c.has_meta("instance_xforms") and String(c.get_meta("prop")).begins_with("kb_") \
				and String(c.get_meta("prop")) in ["kb_beech", "kb_oak", "kb_hornbeam", "kb_maple", "kb_pine"]:
			trees += (c.get_meta("instance_xforms") as Array).size()
	check(trees > 600, "forest around the town (%d)" % trees)
	race.queue_free()
	await tree.process_frame
