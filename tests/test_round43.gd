extends TestCase
## Round 43 (0.20.1, the owner's phone videos, 2026-11-12):
##  * nothing pops up while driving: the Qarabağ town houses keep their full
##    model at every distance and stay in view over the whole town (900 m), the
##    forest to 450 m;
##  * the name boards are small (letters 1.1-1.3 m, the board under ~5 m) - the
##    sight itself is seen;
##  * the Həkəri in Laçın is seen from the road (water 0.6-3.7 m under the road,
##    the boulevard 0.5 m over the water, a low river wall);
##  * HOÇAZ in big white letters on the mountain, facing the town;
##  * Şuşa: the ŞUŞA sign first (just after the start), then the mosque; a town
##    of old stone houses; Şuşa qalası is a small fortress the road runs
##    through, ŞUŞA in red letters on its gates.

const SIZES := "res://assets/models/karabakh_names/sizes.json"
var _orig_config := {}


func before_each() -> void:
	_orig_config = Game.race_config.duplicate(true)


func after_each() -> void:
	Game.race_config = _orig_config


func _td(id: String) -> TrackData:
	return TrackData.load_from_file(TrackList.path(id))


func test_no_pop_in_for_the_town() -> void:
	var d := KarabakhDecor.new()
	d.data = _td("karabakh_lachin")
	d._reserve_kb_plots()
	for id in ["kb_lc_house_1", "kb_lc_block", "kb_house_a", "kb_sh_house_b", "kb_cypress"]:
		check(d.full_lod.has(id), "%s: one model at every distance" % id)
		check(float(d.skyline_min.get(id, 0.0)) >= 800.0, "%s seen over the whole town" % id)
	check(float(d.skyline_min.get("kb_oak", 0.0)) >= 400.0, "the forest reaches 400 m+")
	check(float(d.skyline_min.get("kb_hl_h", 0.0)) >= 2000.0, "HOÇAZ seen from everywhere")
	d.free()


func test_name_boards_are_small() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SIZES))
	check(typeof(parsed) == TYPE_DICTIONARY, "sizes.json")
	for id: String in parsed.sizes:
		if not id.begins_with("kb_name_"):
			continue
		var s: Array = parsed.sizes[id]
		check(float(s[2]) < 5.5, "%s board %.1f m high" % [id, s[2]])
		check(float(s[0]) < 15.0, "%s board %.1f m wide" % [id, s[0]])


func test_hakari_seen_from_the_road() -> void:
	var td := _td("karabakh_lachin")
	var hk: Dictionary = td.raw.rivers[0]
	var b := TrackBuilder.new()
	b.data = td
	b._make_materials()
	b._build_blender_terrain(String(td.raw.terrain_dir))
	var water := b.get_node_or_null("Terrain/River_hakari")
	check(water != null, "the water")
	# the water level beside the west leg (karabakh_terrain.py: Chaikin x3, level falls with the length)
	var pts: Array = []
	for q: Array in hk.points:
		pts.append(Vector2(q[0], q[1]))
	for _r in 3:
		var nq: Array = [pts[0]]
		for k in pts.size() - 1:
			nq.append((pts[k] as Vector2) * 0.75 + (pts[k + 1] as Vector2) * 0.25)
			nq.append((pts[k] as Vector2) * 0.25 + (pts[k + 1] as Vector2) * 0.75)
		nq.append(pts[pts.size() - 1])
		pts = nq
	var cum: Array = [0.0]
	for k in range(1, pts.size()):
		cum.append(float(cum[k - 1]) + (pts[k] as Vector2).distance_to(pts[k - 1]))
	var total: float = cum[cum.size() - 1]
	var worst := 0.0
	var best := INF
	var path := td.main
	for i in range(0, path.sample_count(), 6):
		var p := path.points[i]
		if p.x > -110.0:
			continue
		var k_best := 0
		var dk := INF
		for k in pts.size():
			var dd := Vector2(p.x, p.z).distance_to(pts[k])
			if dd < dk:
				dk = dd
				k_best = k
		var lev := float(hk.drop[0]) + (float(hk.drop[1]) - float(hk.drop[0])) * float(cum[k_best]) / total
		worst = maxf(worst, p.y - lev)
		best = minf(best, p.y - lev)
	check(best > 0.3, "the water stays under the road (%.1f m at the least)" % best)
	check(worst < 4.0, "the water close under the road (%.1f m at the most)" % worst)
	b.free()


func test_hocaz_label() -> void:
	for tid in ["karabakh", "karabakh_lachin"]:
		var td := _td(tid)
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(String(td.raw.terrain_dir) + "/lines.json"))
		var letters: Array = []
		for t: Array in parsed.instances:
			if String(t[0]).begins_with("kb_hl_"):
				letters.append(t)
		check_eq(letters.size(), 5, "%s: H O Ç A Z" % tid)
		if letters.size() != 5:
			continue
		check_eq(String(letters[2][0]), "kb_hl_c", "%s: Ç in the middle" % tid)
		var pk: Dictionary = td.raw.peaks[0]
		var y0 := float(letters[0][2])
		for t: Array in letters:
			check(absf(float(t[2]) - y0) < 0.01, "%s: one baseline" % tid)
			check(float(t[2]) > 60.0, "%s: high on the mountain (y %.0f)" % [tid, t[2]])
			var d := Vector2(float(t[1]) - float(pk.x), float(t[3]) - float(pk.z)).length()
			check(d < float(pk.r), "%s: on Hoçaz (%.0f m from its centre)" % [tid, d])
			# the letter's front (+z) faces the town (the peak's face direction)
			var f := Vector2(sin(float(t[4])), cos(float(t[4])))
			check(f.dot(Vector2(pk.face[0], pk.face[1])) > 0.95, "%s: faces the town" % tid)
		check(KarabakhDecor.kb_model_ready("kb_hl_c"), "letter models")


func test_shusha_order_town_and_fortress() -> void:
	var td := _td("karabakh_shusha")
	var path := td.main
	var start: float = path.closest(Vector3(float(td.raw.finish_at[0]), 0, float(td.raw.finish_at[1]))).s
	var at := {}
	for lm: Dictionary in td.raw.landmarks:
		var s: float = fposmod(path.closest(Vector3(float(lm.x), 0, float(lm.z))).s - start, path.length)
		at[String(lm.id)] = s
	check(at.has("kb_sign_shusha") and at.has("kb_mosque"), "sign and mosque")
	check(float(at.kb_sign_shusha) < float(at.kb_mosque), "the ŞUŞA sign before the mosque")
	check(float(at.kb_sign_shusha) < 60.0, "the sign just after the start (%.0f m)" % at.kb_sign_shusha)
	var houses: int = (td.raw.get("town", {}).get("houses", []) as Array).size()
	check(houses >= 150, "Şuşa town houses (%d)" % houses)
	for tid in ["karabakh", "karabakh_shusha"]:
		var t2 := _td(tid)
		var fort: Dictionary = {}
		for lm: Dictionary in t2.raw.landmarks:
			if String(lm.id) == "kb_sh_fortress":
				fort = lm
		check(not fort.is_empty(), "%s: Şuşa qalası" % tid)
		if fort.is_empty():
			continue
		# the road (and its run-off) runs through both gates: 26 m wide, 72 m apart
		var c := Vector2(float(fort.x), float(fort.z))
		var ax := Vector2(cos(float(fort.yaw)), -sin(float(fort.yaw)))
		var worst := 0.0
		var n := 0
		for i in t2.main.sample_count():
			var p := Vector2(t2.main.points[i].x, t2.main.points[i].z)
			var r := p - c
			if absf(r.dot(ax)) > 36.0 or r.length() > 60.0:
				continue
			n += 1
			worst = maxf(worst, absf(r.dot(Vector2(-ax.y, ax.x))) + t2.main.half_width_at(t2.main.cum[i]) + t2.offroad_width)
		check(n > 10, "%s: the road passes the fortress (%d samples)" % [tid, n])
		check(worst < 13.0, "%s: road + run-off inside the gates (%.1f of 13 m)" % [tid, worst])
		check(t2.raw.get("lines", []).filter(func(l): return String(l.id) == "shusha_wall").is_empty(),
				"%s: no long wall" % tid)
	check(KarabakhDecor.kb_model_ready("kb_sh_fortress"), "fortress model")


func test_race_scene_has_the_fortress() -> void:
	var cfg := Game.default_race_config()
	cfg.track_id = "karabakh_shusha"
	cfg.laps = 2
	cfg.debug_autopilot = true
	Game.race_config = cfg
	var race: RaceManager = load("res://scenes/race/race.tscn").instantiate()
	tree.root.add_child(race)
	await tree.process_frame
	await tree.process_frame
	var d: KarabakhDecor = race.decor
	check(d.landmarks.has("kb_sh_fortress"), "Şuşa qalası in the scene")
	var houses := 0
	for c in d.get_children():
		if c is MultiMeshInstance3D and c.has_meta("instance_xforms") and String(c.get_meta("prop")).begins_with("kb_sh_house"):
			houses += (c.get_meta("instance_xforms") as Array).size()
	check(houses >= 150, "Şuşa houses in the scene (%d)" % houses)
	race.queue_free()
	await tree.process_frame
