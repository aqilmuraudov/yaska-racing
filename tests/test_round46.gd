extends TestCase
## Round 46 (0.20.4): the owner asked for the Şuşa houses on the big Qarabağ
## map too (2026-11-12: Şuşa had only its sights there). The short map's old
## stone houses (kb_sh_house_a/b/c) on the plateau road and on contour streets
## both sides, kept on the plateau table and off the Daşaltı gorge cliffs
## (tools/karabakh_maps_layout.py, third big-map town "sh_").

var _td: TrackData
var _town := {}


func before_each() -> void:
	_td = TrackData.load_from_file(TrackList.path("karabakh"))
	var f := FileAccess.open(TrackList.path("karabakh"), FileAccess.READ)
	_town = JSON.parse_string(f.get_as_text()).get("town", {})


func _houses(prefix: String) -> Array:
	return (_town.get("houses", []) as Array).filter(func(h): return str(h["id"]).begins_with(prefix))


func test_shusha_town_on_big_map() -> void:
	var sh := _houses("kb_sh_house")
	check(sh.size() >= 80, "Şuşa old houses on the big map (%d)" % sh.size())
	var on_road := sh.filter(func(h): return h["front"] == "road").size()
	check(on_road >= 15, "Şuşa houses along the race road (%d)" % on_road)
	var streets := (_town.get("streets", []) as Array).filter(func(s): return str(s["id"]).begins_with("sh_"))
	check(streets.size() >= 4, "Şuşa streets (%d)" % streets.size())


func test_shusha_houses_on_the_table() -> void:
	# plateau ellipse (50, -255, 300 x 150), flat inside 0.8; the gorge cut ends 52 m (+9 m wobble)
	var gorge := [Vector2(345, -140), Vector2(200, -92), Vector2(20, -68), Vector2(-150, -92)]
	var bad := 0
	for h in _houses("kb_sh_house"):
		var p := Vector2(h["x"], h["z"])
		var e := Vector2((p.x - 50.0) / 300.0, (p.y + 255.0) / 150.0).length()
		var dg := 1e9
		for i in gorge.size() - 1:
			dg = minf(dg, p.distance_to(Geometry2D.get_closest_point_to_segment(p, gorge[i], gorge[i + 1])))
		if e > 0.78 or dg < 68.0:
			bad += 1
	check_eq(bad, 0, "no Şuşa house off the plateau or on the gorge cliffs")


func test_other_towns_unchanged() -> void:
	check_eq(_houses("kb_xk_").size(), 114, "Xankəndi town as in 0.20.2")
	check_eq(_houses("kb_lc_").size() + _houses("kb_house").size(), 155, "Laçın town as in 0.20.1")


func test_shusha_houses_clear_of_road() -> void:
	var worst := 1e9
	for h in _houses("kb_sh_house"):
		var c := _td.main.closest(Vector3(h["x"], 0, h["z"]))
		worst = minf(worst, c.distance - _td.main.half_width_at(c.s) - _td.offroad_width - float(h["d"]) / 2.0)
	check(worst > 2.0, "house fronts behind the run-off (worst %.1f m)" % worst)
