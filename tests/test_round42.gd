extends TestCase
## Round 42 (0.20.1): the names of the Qarabağ sights in big capitals on boards
## beside the road (owner, 2026-11-11: "LaCinema, Lachin Resort & SPA, Bayraq
## meydanı ... hamısında"), and Laçın's Bayraq meydanı with the big flag
## (tools/blender/karabakh_names.py, layout tools/karabakh_maps_layout.py).

const BOARDS := {
	"karabakh": ["kb_name_cinema", "kb_name_hotel", "kb_name_flag", "kb_name_mosque", "kb_name_vagif",
			"kb_name_victory", "kb_name_university", "kb_name_stadium", "kb_name_mountains",
			"kb_name_bridges"],
	"karabakh_lachin": ["kb_name_cinema", "kb_name_hotel", "kb_name_flag"],
	"karabakh_shusha": ["kb_name_mosque", "kb_name_vagif", "kb_name_bulbul"],
	"karabakh_khankendi": ["kb_name_victory", "kb_name_university", "kb_name_stadium", "kb_name_mountains"],   # 0.20.2
}
var _orig_config := {}


func before_each() -> void:
	_orig_config = Game.race_config.duplicate(true)


func after_each() -> void:
	Game.race_config = _orig_config


func _gap(td: TrackData, p: Vector2) -> float:
	var c := td.main.closest(Vector3(p.x, 0, p.y))
	return c.distance - td.main.half_width_at(c.s) - td.offroad_width


func test_models_ready() -> void:
	for id in BOARDS.karabakh + ["kb_name_bulbul", "kb_flag_square"]:
		check(KarabakhDecor.kb_model_ready(id), "%s model" % id)


func test_boards_beside_the_road() -> void:
	for tid: String in BOARDS:
		var td := TrackData.load_from_file(TrackList.path(tid))
		var boards: Array = td.raw.get("name_boards", [])
		var ids := {}
		for b: Dictionary in boards:
			ids[String(b.id)] = true
			var c := Vector2(float(b.x), float(b.z))
			var f := Vector2(sin(float(b.yaw)), cos(float(b.yaw)))
			var a := Vector2(f.y, -f.x)
			var g := INF
			for u: float in [-0.5, 0.5]:
				for v: float in [-0.5, 0.5]:
					g = minf(g, _gap(td, c + a * u * float(b.w) + f * v * float(b.d)))
			check(g > 1.4 and g < 15.0, "%s %s: %.1f m behind the run-off" % [tid, b.id, g])
			# it faces the road (and the oncoming karts)
			var cl := td.main.closest(Vector3(c.x, 0, c.y))
			var p := td.main.position_at(cl.s)
			check(f.dot((Vector2(p.x, p.z) - c).normalized()) > 0.2, "%s %s faces the road" % [tid, b.id])
			check(f.dot(Vector2(td.main.tangent_at(cl.s).x, td.main.tangent_at(cl.s).z)) < 0.0,
					"%s %s turned to the oncoming karts" % [tid, b.id])
		for id: String in BOARDS[tid]:
			check(ids.has(id), "%s: %s on the map" % [tid, id])
		# no town house on a board or in front of it
		for h: Dictionary in td.raw.get("town", {}).get("houses", []):
			for b: Dictionary in boards:
				check(Vector2(float(h.x) - float(b.x), float(h.z) - float(b.z)).length() > float(b.w) / 2.0 + 4.0,
						"%s: house clear of %s" % [tid, b.id])


func test_flag_square() -> void:
	for tid in ["karabakh", "karabakh_lachin"]:
		var td := TrackData.load_from_file(TrackList.path(tid))
		var sq: Dictionary = {}
		for lm: Dictionary in td.raw.landmarks:
			if String(lm.id) == "kb_flag_square":
				sq = lm
		check(not sq.is_empty(), "%s: Bayraq meydanı" % tid)
		if sq.is_empty():
			continue
		check_eq(String(sq.zone), "lachin", "%s: in Laçın" % tid)
		check(float(sq.setback) < 10.0, "%s: beside the road (%.1f m)" % [tid, sq.setback])


func test_race_scene_places_them() -> void:
	var cfg := Game.default_race_config()
	cfg.track_id = "karabakh_lachin"
	cfg.laps = 2
	cfg.debug_autopilot = true
	Game.race_config = cfg
	var race: RaceManager = load("res://scenes/race/race.tscn").instantiate()
	tree.root.add_child(race)
	await tree.process_frame
	await tree.process_frame
	var d: KarabakhDecor = race.decor
	for id in ["kb_name_cinema", "kb_name_hotel", "kb_name_flag", "kb_flag_square"]:
		check(d.landmarks.has(id), "%s in the scene" % id)
	check(d.landmarks.has("flag_square_lachin"), "the flag on the square")
	var flag: MeshInstance3D = d.landmarks.get("flag_square_lachin")
	if flag != null:
		check(flag.global_position.y > 50.0, "the flag high on its mast (y %.0f)" % flag.global_position.y)
	race.queue_free()
	await tree.process_frame
