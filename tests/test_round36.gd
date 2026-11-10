extends TestCase
## Round 36 (0.19.1): the Qarabağ landmarks the owner named (2026-11-10) -
## Xankəndi: Zəfər meydanı with the Victory Arch, the university, the stadium,
## "Biz və bizim dağlar"; Şuşa: the fortress walls, Yuxarı Gövhər Ağa mosque,
## Vaqif's mausoleum, the ŞUŞA sign with the flag; Laçın: Hoçaz (terrain),
## the Həkəri boulevard, the garden café, LaCinema, the town houses, Lachin
## Resort & Spa. Layout: tools/karabakh_layout.py; models: tools/blender/karabakh_*.py.

var _td: TrackData
var _orig_config := {}

const EXPECTED := ["kb_victory_square", "kb_university", "kb_stadium", "kb_our_mountains", "kb_shusha_sign",
	"kb_mosque", "kb_vagif", "kb_cinema", "kb_hotel", "kb_garden_cafe", "kb_house_a", "kb_house_b", "kb_house_c"]
const LINE_MODULES := ["kb_wall_seg", "kb_wall_tower", "kb_wall_gate", "kb_blvd_seg"]


func before_each() -> void:
	_orig_config = Game.race_config.duplicate(true)
	_td = TrackData.load_from_file(TrackList.path("karabakh"))


func after_each() -> void:
	Game.race_config = _orig_config


func _builder() -> TrackBuilder:
	var b := TrackBuilder.new()
	b.data = _td
	b._make_materials()
	b._build_blender_terrain(String(_td.raw.terrain_dir))
	return b


## Sample points over a landmark footprint (shrunk by `inset` m).
func _footprint(lm: Dictionary, inset: float = 0.0, step: float = 3.0) -> Array:
	var out := []
	var yaw := float(lm.yaw)
	var f := Vector2(sin(yaw), cos(yaw))
	var a := Vector2(f.y, -f.x)
	var w := float(lm.w) / 2.0 - inset
	var d := float(lm.d) / 2.0 - inset
	var u := -w
	while u <= w + 0.01:
		var v := -d
		while v <= d + 0.01:
			out.append(Vector2(float(lm.x), float(lm.z)) + a * u + f * v)
			v += step
		u += step
	return out


func _lines() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(String(_td.raw.terrain_dir) + "/lines.json"))
	return parsed.instances if typeof(parsed) == TYPE_DICTIONARY else []


func test_every_named_landmark_is_laid_out() -> void:
	var ids := {}
	var zones := {}
	for lm: Dictionary in _td.raw.get("landmarks", []):
		ids[String(lm.id)] = true
		zones[String(lm.zone)] = true
	for id in EXPECTED:
		check(ids.has(id), "%s laid out" % id)
	check(zones.has("khankendi") and zones.has("shusha") and zones.has("lachin"), "three towns")
	var line_ids := {}
	for ln: Dictionary in _td.raw.get("lines", []):
		line_ids[String(ln.id)] = true
	check(line_ids.has("shusha_wall") and line_ids.has("hakari_boulevard"), "the fortress wall and the boulevard")
	var peaks: Array = _td.raw.get("peaks", [])
	check(peaks.size() == 1 and String(peaks[0].id) == "hocaz", "Hoçaz")


func test_footprints_clear_of_road_rivers_and_each_other() -> void:
	var path := _td.main
	var lms: Array = _td.raw.landmarks
	for lm: Dictionary in lms:
		var worst := INF
		var wet := INF
		for p: Vector2 in _footprint(lm):
			var c := path.closest(Vector3(p.x, 0, p.y))
			worst = minf(worst, c.distance - path.half_width_at(c.s) - _td.offroad_width)
			for rv: Dictionary in _td.raw.rivers:
				wet = minf(wet, _river_gap(p, rv))
		var need := 0.8 if String(lm.id) == "kb_shusha_sign" else 2.5
		check(worst > need, "%s %.1f m behind the run-off" % [lm.id, worst])
		check(wet > 5.0, "%s dry (%.1f m from a river bank)" % [lm.id, wet])
	for i in lms.size():
		for j in range(i + 1, lms.size()):
			var b: Dictionary = lms[j]
			var fx := sin(float(b.yaw))
			var fz := cos(float(b.yaw))
			var hit := false
			for p: Vector2 in _footprint(lms[i], 0.5, 2.0):
				var u := (p.x - float(b.x)) * fz - (p.y - float(b.z)) * fx
				var v := (p.x - float(b.x)) * fx + (p.y - float(b.z)) * fz
				if absf(u) < float(b.w) / 2.0 and absf(v) < float(b.d) / 2.0:
					hit = true
					break
			check(not hit, "%s and %s do not overlap" % [lms[i].id, b.id])


func _river_gap(p: Vector2, rv: Dictionary) -> float:
	var best := INF
	var pts: Array = rv.points
	for i in pts.size() - 1:
		var a := Vector2(pts[i][0], pts[i][1])
		var c := Vector2(pts[i + 1][0], pts[i + 1][1])
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, c)))
	return best - float(rv.width) / 2.0


func test_pads_level_and_open() -> void:
	var b := _builder()
	for lm: Dictionary in _td.raw.landmarks:
		var worst := 0.0
		for p: Vector2 in _footprint(lm, 1.5):
			worst = maxf(worst, absf(b.terrain_height(p.x, p.y) - float(lm.y)))
		# the small sign stands 1.5 m behind the run-off, in the road's cut bank (its plinth reaches 1.5 m down)
		var tol := 0.6 if String(lm.id) == "kb_shusha_sign" else 0.35
		check(worst < tol, "%s stands on a level pad (off by %.2f m)" % [lm.id, worst])
		# the pad lies at road height, a little under it
		var c := _td.main.closest(Vector3(float(lm.x), 0, float(lm.z)))
		var ry := _td.main.position_at(c.s).y
		if String(lm.id) == "kb_garden_cafe":
			continue # on the boulevard terrace by the river (checked below with the line modules)
		check(float(lm.y) < ry and float(lm.y) > ry - 6.0, "%s pad %.1f m under the road" % [lm.id, ry - float(lm.y)])
	# the wall modules reach the ground (foundation 4 m under their origin)
	var wall := 0
	for t: Array in _lines():
		var g := b.terrain_height(float(t[1]), float(t[3]))
		if String(t[0]).begins_with("kb_wall"):
			wall += 1
			check(float(t[2]) <= g + 0.05 and float(t[2]) > g - 3.5, "%s on the ground (%.2f vs %.2f)" % [t[0], t[2], g])
		else:
			check(absf(g - float(t[2])) < 0.4, "boulevard on its terrace (%.2f vs %.2f)" % [t[2], g])
	check(wall > 40, "the fortress wall runs %d modules" % wall)
	# the café stands on the boulevard: next to its modules, at their height
	for lm: Dictionary in _td.raw.landmarks:
		if String(lm.id) != "kb_garden_cafe":
			continue
		var best := INF
		var by := 0.0
		for t: Array in _lines():
			if String(t[0]) == "kb_blvd_seg":
				var d := Vector2(float(t[1]) - float(lm.x), float(t[3]) - float(lm.z)).length()
				if d < best:
					best = d
					by = float(t[2])
		check(best < 20.0, "the café is on the boulevard (%.1f m)" % best)
		check(absf(by - float(lm.y)) < 1.0, "at the boulevard's height")
	# no tree on a footprint or the boulevard
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(String(_td.raw.terrain_dir) + "/trees.json"))
	var inside := 0
	for t: Array in parsed.trees:
		var p := Vector2(float(t[1]), float(t[3]))
		for lm: Dictionary in _td.raw.landmarks:
			var fx := sin(float(lm.yaw))
			var fz := cos(float(lm.yaw))
			var u := (p.x - float(lm.x)) * fz - (p.y - float(lm.z)) * fx
			var v := (p.x - float(lm.x)) * fx + (p.y - float(lm.z)) * fz
			if absf(u) < float(lm.w) / 2.0 and absf(v) < float(lm.d) / 2.0:
				inside += 1
	check_eq(inside, 0, "no tree stands on a landmark")
	b.free()


func test_models_near_and_far() -> void:
	var ids := {}
	for lm: Dictionary in _td.raw.landmarks:
		ids[String(lm.id)] = true
	for id in LINE_MODULES:
		ids[id] = true
	for id: String in ids:
		check(KarabakhDecor.kb_model_ready(id), "%s built in Blender" % id)
		var near := PropKit.get_mesh(id)
		var far := PropKit.get_mesh(id + PropKit.LO_SUFFIX)
		check(near != null and far != null, "%s near / far" % id)
		if near and far:
			var tn := 0
			var tf := 0
			for si in near.get_surface_count():
				tn += near.surface_get_array_index_len(si) / 3
			for si in far.get_surface_count():
				tf += far.surface_get_array_index_len(si) / 3
			var budget := 1500 if id in LINE_MODULES or id.begins_with("kb_house") else 9000
			check(tn <= budget and tf < tn, "%s: %d tris near, %d far" % [id, tn, tf])


func test_hocaz_stands_out() -> void:
	var b := _builder()
	var pk: Dictionary = _td.raw.peaks[0]
	var top := -INF
	var at := Vector2.ZERO
	var x := float(pk.x) - float(pk.r)
	while x < float(pk.x) + float(pk.r):
		var z := float(pk.z) - float(pk.r)
		while z < float(pk.z) + float(pk.r):
			var h := b.terrain_height(x, z)
			if h > top:
				top = h
				at = Vector2(x, z)
			z += 10.0
		x += 10.0
	check(top > 260.0, "Hoçaz rises %.0f m" % top)
	# seen from the Laçın road, inside the chase camera's far plane (1500 m)
	var c := _td.main.closest(Vector3(at.x, 0, at.y))
	check(c.distance < 900.0, "the summit %.0f m from the road" % c.distance)
	# the cliff faces the town: the ground drops steeply from the summit towards it
	var face := Vector2(float(pk.face[0]), float(pk.face[1]))
	var below := b.terrain_height(at.x + face.x * 130.0, at.y + face.y * 130.0)
	check(top - below > 110.0, "a tall cliff on the town side (%.0f m over 130 m)" % (top - below))
	b.free()


func test_race_scene_places_the_landmarks() -> void:
	var cfg := Game.default_race_config()
	cfg.track_id = "karabakh"
	cfg.laps = 1
	cfg.debug_autopilot = true
	Game.race_config = cfg
	var race: RaceManager = load("res://scenes/race/race.tscn").instantiate()
	tree.root.add_child(race)
	await tree.process_frame
	await tree.process_frame
	var decor: KarabakhDecor = race.decor
	for id in ["kb_victory_square", "kb_university", "kb_stadium", "kb_our_mountains", "kb_shusha_sign", "kb_mosque",
			"kb_vagif", "kb_cinema", "kb_hotel", "kb_garden_cafe"]:
		check(decor.landmarks.has(id), "%s in the scene" % id)
	check(decor.landmarks.has("shusha_flag"), "the flag on the Şuşa sign")
	if decor.landmarks.has("shusha_flag"):
		var flag := decor.landmarks.shusha_flag as MeshInstance3D
		check(flag.get_parent() == decor.landmarks.kb_shusha_sign, "flag on its mast")
		check(flag.mesh.surface_get_material(0) == LandmarkKit.flag_material(), "the waving Azerbaijani flag material")
	var counts := {}
	for c in decor.get_children():
		if c is MultiMeshInstance3D and c.has_meta("instance_xforms"):
			var prop := String(c.get_meta("prop"))
			counts[prop] = int(counts.get(prop, 0)) + (c.get_meta("instance_xforms") as Array).size()
	check(int(counts.get("kb_wall_seg", 0)) > 30, "fortress wall segments (%d)" % int(counts.get("kb_wall_seg", 0)))
	check(int(counts.get("kb_wall_tower", 0)) > 4, "wall towers")
	check_eq(int(counts.get("kb_wall_gate", 0)), 1, "one gate")
	check(int(counts.get("kb_blvd_seg", 0)) > 15, "the Həkəri boulevard (%d)" % int(counts.get("kb_blvd_seg", 0)))
	var houses := int(counts.get("kb_house_a", 0)) + int(counts.get("kb_house_b", 0)) + int(counts.get("kb_house_c", 0))
	check(houses >= 8, "Laçın town houses (%d)" % houses)
	race.queue_free()
	await tree.process_frame
