extends TestCase
## Round 44 (0.20.2): the short Qarabağ map Xankəndi (owner, 2026-11-12: "build
## Xankəndi; its town and houses after modern photos"): a 1.7 km two-lane loop
## through the town - the new avenue on the east leg (start) with the new
## four-storey arcade buildings, the Victory square and the university, "Biz
## və bizim dağlar" on the north bend, the stadium on the south bend; a town of
## five-storey tuff blocks, nine-storey towers, white classical houses and old
## stone houses with red / rust metal roofs (tools/blender/karabakh_khankendi_town.py).

const ID := "karabakh_khankendi"
const XK := ["kb_xk_block5", "kb_xk_tower9", "kb_xk_new4", "kb_xk_villa", "kb_xk_house_1", "kb_xk_house_2"]
const BLOCKS := ["kb_xk_block5", "kb_xk_tower9", "kb_xk_new4"]
var _td: TrackData
var _orig_config := {}


func before_each() -> void:
	_orig_config = Game.race_config.duplicate(true)
	_td = TrackData.load_from_file(TrackList.path(ID))


func after_each() -> void:
	Game.race_config = _orig_config


func _gap(p: Vector2) -> float:
	var c := _td.main.closest(Vector3(p.x, 0, p.y))
	return c.distance - _td.main.half_width_at(c.s) - _td.offroad_width


func test_registered_in_qarabag() -> void:
	check(ID in TrackList.IDS, "in the track list")
	check_eq(TrackList.region_of(ID), "karabakh", "in Qarabağ")
	check_eq(TrackList.region_tracks("karabakh")[1], ID, "right after the big map (Xankəndi, Şuşa, Laçın)")
	TranslationServer.set_locale("az")
	check_eq(tr(TrackList.name_key(ID)), "Xankəndi", "Azerbaijani name")
	check(tr(TrackList.desc_key(ID)) != TrackList.desc_key(ID), "description translated")
	check(ResourceLoader.exists("res://assets/ui/cities/%s.jpg" % ID), "city card picture (Blender render)")
	var n := 0
	for t in Progression.trophies():
		if String(t.get("track", "")) == ID:
			n += 1
			check(tr(String(t.name)) != String(t.name), "%s translated" % t.name)
	check_eq(n, 7, "seven Xankəndi trophies")
	check_eq(TrackList.max_laps(ID), 5, "a short map: 1-5 laps")
	check(TrackList.lap_scale(ID) > 0.9 and TrackList.lap_scale(ID) < 1.5, "lap ~ a Baku lap")


func test_layout_and_landmarks() -> void:
	check(_td != null and _td.lanes == 2, "loads, two lanes")
	check_eq(_td.default_laps, 2, "two laps by default")
	check(_td.main.length > 1500.0 and _td.main.length < 1900.0, "lap %.0f m" % _td.main.length)
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
		check_eq(String(lm.zone), "khankendi", "%s in Xankəndi" % lm.id)
		var f := Vector2(sin(float(lm.yaw)), cos(float(lm.yaw)))
		var a := Vector2(f.y, -f.x)
		var front := Vector2(float(lm.x), float(lm.z)) + f * float(lm.d) / 2.0
		var g := INF
		for u: float in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			g = minf(g, _gap(front + a * u * float(lm.w)))
		check(g < 10.0, "%s beside the road (%.1f m)" % [lm.id, g])
		check(_gap(Vector2(float(lm.x), float(lm.z))) > 0.0, "%s off the road" % lm.id)
	for id in ["kb_victory_square", "kb_university", "kb_stadium", "kb_our_mountains", "kb_sign_khankendi"]:
		check(ids.has(id), "%s on the map" % id)
	var boards := {}
	for b: Dictionary in _td.raw.name_boards:
		boards[String(b.id)] = true
	for id in ["kb_name_victory", "kb_name_university", "kb_name_stadium", "kb_name_mountains"]:
		check(boards.has(id), "%s beside the road" % id)
	# the start on the avenue: the sign comes first, the avenue is the wide part of the road
	var start: float = path.closest(Vector3(float(_td.raw.finish_at[0]), 0, float(_td.raw.finish_at[1]))).s
	var sign_s := INF
	for lm: Dictionary in _td.raw.landmarks:
		var s: float = fposmod(path.closest(Vector3(float(lm.x), 0, float(lm.z))).s - start, path.length)
		if String(lm.id) == "kb_sign_khankendi":
			sign_s = s
	check(sign_s < 80.0, "the XANKƏNDİ sign just after the start (%.0f m)" % sign_s)
	check(path.half_width_at(start) > 8.0, "the avenue is wide (%.1f m)" % (path.half_width_at(start) * 2.0))


func test_town_after_the_photos() -> void:
	var town: Dictionary = _td.raw.town
	var count := {}
	for h: Dictionary in town.houses:
		count[String(h.id)] = int(count.get(String(h.id), 0)) + 1
	var blocks := 0
	for id in BLOCKS:
		blocks += int(count.get(id, 0))
	check(town.houses.size() >= 250, "a town (%d buildings)" % town.houses.size())
	check(blocks >= 100, "blocks of flats and towers (%d)" % blocks)
	for id in XK:
		check(int(count.get(id, 0)) >= 10, "%s used (%d)" % [id, count.get(id, 0)])
	# the new avenue (east leg): mostly the new arcade buildings
	var avenue := 0
	var avenue_new := 0
	for h: Dictionary in town.houses:
		if String(h.front) == "road" and float(h.x) > 100.0:
			avenue += 1
			if String(h.id) == "kb_xk_new4":
				avenue_new += 1
	check(avenue >= 10 and avenue_new * 2 >= avenue, "the avenue's new buildings (%d of %d)" % [avenue_new, avenue])
	# every building clear of the road and the others (big blocks with room for their banks)
	for h: Dictionary in town.houses:
		var f := Vector2(sin(float(h.yaw)), cos(float(h.yaw)))
		var a := Vector2(f.y, -f.x)
		var c := Vector2(float(h.x), float(h.z))
		var g := INF
		for u: float in [-0.5, 0.5]:
			for v: float in [-0.5, 0.5]:
				g = minf(g, _gap(c + a * u * float(h.w) + f * v * float(h.d)))
		check(g > 2.9, "%s at (%.0f, %.0f) off the road (%.1f m)" % [h.id, h.x, h.z, g])
	for lm: Dictionary in _td.raw.landmarks:
		for h: Dictionary in town.houses:
			var d := Vector2(float(h.x) - float(lm.x), float(h.z) - float(lm.z)).length()
			check(d > (float(h.w) + float(h.d)) / 4.0, "%s clear of %s" % [h.id, lm.id])


func test_terrain_and_pads() -> void:
	var b := TrackBuilder.new()
	b.data = _td
	b._make_materials()
	b._build_blender_terrain(String(_td.raw.terrain_dir))
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
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(String(_td.raw.terrain_dir) + "/town.json"))
	check(typeof(parsed) == TYPE_DICTIONARY, "town.json")
	var off := 0.0
	for t: Array in parsed.instances:
		off = maxf(off, absf(b.terrain_height(float(t[1]), float(t[3])) - float(t[2])))
	check(off < 0.6, "every building on its pad (worst %.2f m)" % off)
	b.free()


func test_no_pop_in_for_the_new_set() -> void:
	var d := KarabakhDecor.new()
	d.data = _td
	d._reserve_kb_plots()
	for id in XK:
		check(KarabakhDecor.kb_model_ready(id), "%s model" % id)
		check(d.full_lod.has(id), "%s: one model at every distance" % id)
		check(float(d.skyline_min.get(id, 0.0)) >= 800.0, "%s seen over the whole town" % id)
	d.free()


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
	var d: KarabakhDecor = race.decor
	for id in ["kb_victory_square", "kb_university", "kb_stadium", "kb_our_mountains", "kb_sign_khankendi"]:
		check(d.landmarks.has(id), "%s in the scene" % id)
	check(d.landmarks.has("flag_khankendi"), "the flag on the sign")
	var placed := 0
	for c in d.get_children():
		if c is MultiMeshInstance3D and c.has_meta("instance_xforms") and String(c.get_meta("prop")).begins_with("kb_xk_"):
			placed += (c.get_meta("instance_xforms") as Array).size()
	check(placed >= 250, "town buildings placed (%d)" % placed)
	race.queue_free()
	await tree.process_frame
