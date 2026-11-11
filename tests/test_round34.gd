extends TestCase
## Round 34 (0.18.0, limits updated for the 0.19.0 big map - see round 35):
## the Qarabağ map - a two-lane mountain road through the
## summer forest (Laçın, the Şuşa plateau, the way down to Xankəndi), terrain
## and forest modelled in Blender (tools/blender/karabakh_*.py).

const PROFILE := "user://test_profile_r34.json"
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


func test_track_is_registered() -> void:
	check("karabakh" in TrackList.IDS, "in the track list")
	check_eq(TrackList.name_key("karabakh"), "TRACK_KARABAKH", "name key")
	check_eq(tr("TRACK_KARABAKH"), "Qarabağ" if TranslationServer.get_locale().begins_with("az") else tr("TRACK_KARABAKH"), "name")
	for k in ["TRACK_KARABAKH", "TRACK_KARABAKH_DESC", "TROPHY_KB_QUICK_FINISH", "TROPHY_KB_TT_RECORD"]:
		check(tr(k) != k, "%s translated" % k)
	check(ResourceLoader.exists("res://assets/ui/cities/karabakh.jpg"), "city card picture (Blender render)")
	var kb := 0
	for t in Progression.trophies():
		if String(t.get("track", "")) == "karabakh":
			kb += 1
			check(String(t.name).begins_with("TROPHY_KB_"), "own trophy texts")
	check_eq(kb, 7, "seven Qarabağ trophies")
	check_near(TrackList.lap_scale("karabakh"), 3.4, 0.4, "lap scale ~ autopilot 175 s vs 51 s")


func test_layout_limits() -> void:
	check(_td != null, "loads")
	check_eq(_td.lanes, 2, "two-lane mountain road")
	check(not _td.has_sea, "no sea")
	check(_td.main.length > 4700.0 and _td.main.length < 5100.0, "lap length %.0f m" % _td.main.length)
	check_eq(_td.checkpoint_count(), 13, "finish + 12 checkpoints")
	var path := _td.main
	var n := path.sample_count()
	var max_grade := 0.0
	var max_bend := 0.0
	for i in n:
		var a := path.points[i]
		var b := path.points[(i + 5) % n]
		var h := Vector2(b.x - a.x, b.z - a.z).length()
		max_grade = maxf(max_grade, absf(b.y - a.y) / maxf(h, 0.1))
		# vertical curvature: change of grade over 20 m (crests launch karts)
		var c := path.points[(i + 10) % n]
		var g1 := (b.y - a.y) / maxf(h, 0.1)
		var g2 := (c.y - b.y) / maxf(Vector2(c.x - b.x, c.z - b.z).length(), 0.1)
		max_bend = maxf(max_bend, absf(g2 - g1))
	check(max_grade < 0.09, "max grade %.3f" % max_grade)
	check(max_bend < 0.05, "no sharp crest / dip (grade change %.3f per 10 m)" % max_bend)
	# Distant legs never close in plan (the tracker's search window is 45 m).
	var min_sep := INF
	for i in range(0, n, 4):
		for j in range(i + 1, n, 4):
			var along := absf(path.cum[j] - path.cum[i])
			along = minf(along, path.length - along)
			if along < 120.0:
				continue
			var d := Vector2(path.points[i].x - path.points[j].x, path.points[i].z - path.points[j].z).length()
			min_sep = minf(min_sep, d)
	check(min_sep > 60.0, "distant legs %.0f m apart" % min_sep)
	check(_td.raw.get("landmark_plots", []).size() >= 14, "landmark plots reserved (Laçın, Şuşa, Xankəndi, Xudafərin)")
	var zones := {}
	for pl: Array in _td.raw.landmark_plots:
		zones[String(pl[3])] = true
		var c := path.closest(Vector3(pl[0], 0, pl[1]))
		var gap: float = c.distance - path.half_width_at(c.s) - _td.offroad_width - float(pl[2])
		check(gap > 0.0, "plot %s clear of the road (gap %.1f m)" % [pl, gap])
	check(zones.has("lachin") and zones.has("shusha") and zones.has("khankendi"), "the three towns (0.19.1: Xudafərin has its bridges)")


func _builder() -> TrackBuilder:
	var b := TrackBuilder.new()
	b.data = _td
	b._make_materials()
	b._build_blender_terrain(String(_td.raw.terrain_dir))
	return b


func test_terrain_stays_under_the_road() -> void:
	var b := _builder()
	check(not b._heights.is_empty(), "height grid loaded")
	var path := _td.main
	var bad_edge := 0
	var bad_cam := 0
	var worst := -INF
	for i in range(0, path.sample_count(), 2):
		var s := path.cum[i]
		var p := path.points[i]
		var r := path.right_at(s)
		var t := path.tangent_at(s)
		var hw := path.half_width_at(s)
		for side: float in [-1.0, 1.0]:
			for off: float in [0.0, hw * 0.5, hw, hw + _td.offroad_width, hw + _td.offroad_width + 0.6]:
				var q := p + r * side * off
				var dy := b.terrain_height(q.x, q.z) - (p.y - 0.25)
				worst = maxf(worst, dy)
				if dy > 0.0:
					bad_edge += 1
		# Chase camera ~7 m behind and 2.5 m up, anywhere across the road.
		for lat: float in [-hw, 0.0, hw]:
			var cam := p - t * 7.0 + Vector3.UP * 2.5 + r * lat
			if b.terrain_height(cam.x, cam.z) > cam.y - 0.3:
				bad_cam += 1
	check_eq(bad_edge, 0, "ground under the road and verges (worst %.2f m)" % worst)
	check_eq(bad_cam, 0, "the chase camera never sinks into a bank")
	var root := b.get_node_or_null("Terrain")
	check(root != null, "terrain node")
	if root:
		var tiles := 0
		var fars := 0
		for c in root.get_children():
			var nm := String(c.name)
			if nm.begins_with("Tile_"):
				if nm.ends_with("_far"):
					fars += 1
					check(c.visibility_range_begin > 0.0, "%s: far LOD starts at a distance" % nm)
				else:
					tiles += 1
					check(c.visibility_range_end > 0.0, "%s: near LOD ends" % nm)
		check(tiles >= 200 and tiles == fars, "near / far tiles (%d / %d)" % [tiles, fars])
		check(root.get_node_or_null("Mountains") != null, "mountains")
		for rv in ["River_araz", "River_hakari"]:
			var w := root.get_node_or_null(rv) as MeshInstance3D
			check(w != null and w.material_override == b.materials.water, "%s is water" % rv)
	b.free()


func test_forest_from_blender() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(String(_td.raw.terrain_dir) + "/trees.json"))
	check(typeof(parsed) == TYPE_DICTIONARY, "trees.json")
	var trees: Array = parsed.trees
	check(trees.size() > 6000 and trees.size() < 11000, "forest size %d (phone budget: chunks cull, far LOD at 109 m)" % trees.size())
	var kinds := {}
	var too_close := 0
	var in_plot := 0
	var b := _builder()
	var floating := 0
	for t: Array in trees:
		kinds[String(t[0])] = int(kinds.get(String(t[0]), 0)) + 1
		var p := Vector3(t[1], t[2], t[3])
		var c := _td.main.closest(p)
		if c.distance - _td.main.half_width_at(c.s) - _td.offroad_width < 4.0:
			too_close += 1
		for pl: Array in _td.raw.landmark_plots:
			if Vector2(p.x - pl[0], p.z - pl[1]).length() < float(pl[2]):
				in_plot += 1
		if absf(b.terrain_height(p.x, p.z) - p.y) > 1.2:
			floating += 1
	b.free()
	check_eq(too_close, 0, "every tree >= 4 m behind the run-off")
	check_eq(in_plot, 0, "landmark plots stay open")
	check_eq(floating, 0, "trees stand on the ground")
	for k in ["kb_beech", "kb_oak", "kb_hornbeam", "kb_maple", "kb_pine", "kb_bush"]:
		check(int(kinds.get(k, 0)) > 0, "%s present" % k)
	# Real forest: beech, oak and hornbeam dominate, pines are few.
	var broad := int(kinds.get("kb_beech", 0)) + int(kinds.get("kb_oak", 0)) + int(kinds.get("kb_hornbeam", 0))
	check(broad > int(kinds.get("kb_pine", 0)) * 5, "broadleaf forest (%s)" % kinds)
	for id in ["kb_beech", "kb_oak", "kb_hornbeam", "kb_maple", "kb_pine", "kb_bush", "kb_rock", "kb_post", "kb_lamp"]:
		var near := PropKit.get_mesh(id)
		var far := PropKit.get_mesh(id + PropKit.LO_SUFFIX)
		check(near != null and far != null, "%s near / far models" % id)
		if near and far:
			var tn := 0
			var tf := 0
			for si in near.get_surface_count():
				tn += near.surface_get_array_index_len(si) / 3
			for si in far.get_surface_count():
				tf += far.surface_get_array_index_len(si) / 3
			check(tn <= 1300 and tf <= tn / 2, "%s: %d tris near, %d far" % [id, tn, tf])


func test_race_scene_builds_qarabag() -> void:
	var cfg := Game.default_race_config()
	cfg.track_id = "karabakh"
	cfg.laps = 1
	cfg.time_of_day = "night"
	cfg.debug_autopilot = true
	Game.race_config = cfg
	var race: RaceManager = load("res://scenes/race/race.tscn").instantiate()
	tree.root.add_child(race)
	await tree.process_frame
	await tree.process_frame
	check(race.decor is KarabakhDecor, "Qarabağ decor")
	check(race.builder.get_node_or_null("Terrain") != null, "Blender terrain")
	check(race.builder.get_node_or_null("Sea") == null, "no sea")
	var trees := 0
	var lamps := 0
	for c in race.decor.get_children():
		if c is MultiMeshInstance3D and c.has_meta("instance_xforms"):
			var prop := String(c.get_meta("prop"))
			if prop.begins_with("kb_") and prop not in ["kb_post", "kb_lamp", "kb_rock", "kb_bush"]:
				trees += (c.get_meta("instance_xforms") as Array).size()
			if prop == "kb_lamp":
				lamps += (c.get_meta("instance_xforms") as Array).size()
	check(trees > 6000, "forest placed (%d trees)" % trees)
	check(lamps > 90, "LED lamps along the road (%d)" % lamps)
	var heads: Array = race.decor.instance_transforms("lamp")
	check_eq(heads.size(), lamps, "night light pools under every lamp head")
	for h: Transform3D in heads:
		var c := race.track.main.closest(h.origin)
		if c.distance > race.track.main.half_width_at(c.s) + race.track.offroad_width + 0.5:
			check(false, "lamp head over the verge, not the forest (%.1f m)" % c.distance)
			break
	check(PropKit.PROP_GLOW.get("res://assets/models/karabakh_flora", "") == "lamps", "reflectors / LEDs glow at night")
	race.queue_free()
	await tree.process_frame


func test_menu_has_four_cities() -> void:
	check_eq(TrackList.IDS.size(), 5, "five maps (0.20.1 Şuşa)")
	var days := {}
	for d in 40:
		var date := Time.get_date_string_from_unix_time(1_800_000_000 + d * 86400)
		days[String(DailyChallenge.generate(date).track)] = true
	check(days.has("karabakh"), "Qarabağ in the daily rotation")
