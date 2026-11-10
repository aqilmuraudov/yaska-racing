extends TestCase
## Round 20 (0.11.0): new downtown track "Göydələnlər şəhəri" (16-storey
## skyscrapers, malls, mall bridge), track picker, per-track cup / daily /
## trophies, garage kart shop, cinematic occlusion and menu polish.

const TEST_SETTINGS := "user://test_settings_r20.json"
const TEST_PROFILE := "user://test_profile_r20.json"
var _orig_settings_path := ""
var _orig_settings := {}
var _orig_profile_path := ""
var race: RaceManager
var screen: Node


func before_each() -> void:
	_orig_settings_path = Settings.save_path
	_orig_settings = Settings.values.duplicate(true)
	Settings.save_path = TEST_SETTINGS
	SafeFile.delete_all(TEST_SETTINGS)
	_orig_profile_path = SaveManager.save_path
	SaveManager.save_path = TEST_PROFILE
	SafeFile.delete_all(TEST_PROFILE)
	SaveManager.load_profile()


func after_each() -> void:
	if is_instance_valid(race):
		race.queue_free()
	if is_instance_valid(screen):
		screen.queue_free()
	await tree.process_frame
	SafeFile.delete_all(TEST_SETTINGS)
	Settings.save_path = _orig_settings_path
	Settings.values = _orig_settings
	SafeFile.delete_all(TEST_PROFILE)
	SaveManager.save_path = _orig_profile_path
	SaveManager.load_profile()
	Game.race_config = Game.default_race_config()


func _host() -> Control:
	tree.root.size = Vector2i(1280, 720)
	var host := Control.new()
	host.size = Vector2(1280, 720)
	tree.root.add_child(host)
	return host


# --- Track list / data ----------------------------------------------------------

func test_track_list() -> void:
	# 0.13.0: İçərişəhər added as the third city; 0.18.0 Qarabağ the fourth.
	check_eq(TrackList.IDS, ["seafront_sprint", "downtown_towers", "old_city", "karabakh"], "four tracks, seafront first")
	check_eq(TrackList.valid("nope"), "seafront_sprint", "unknown -> seafront")
	TranslationServer.set_locale("az")
	check_eq(tr(TrackList.name_key("downtown_towers")), "Göydələnlər şəhəri", "Azerbaijani name")
	check(tr(TrackList.desc_key("downtown_towers")).contains("16"), "description mentions 16 floors")
	for id in TrackList.IDS:
		var td := TrackData.load_from_file(TrackList.path(id))
		check(td != null and td.main != null, "%s loads" % id)
		check_eq(td.id, id, "id matches file")
		check(TrackList.lap_scale(id) > 0.4 and TrackList.lap_scale(id) <= 1.3, "lap scale sane")


func test_downtown_data() -> void:
	var td := TrackData.load_from_file(TrackList.path("downtown_towers"))
	check_eq(td.decor_kind, "downtown", "downtown scenery")
	check_eq(td.ground, "city", "paved city ground")
	check(td.main.length > 900.0 and td.main.length < 1300.0, "lap length %.0f m" % td.main.length)
	check_eq(td.checkpoint_s.size(), 7, "finish + six checkpoints")
	var last := -1.0
	for s in td.checkpoint_s:
		var rel := fposmod(s - td.finish_s, td.main.length)
		check(rel > last, "checkpoints in lap order")
		last = rel
	check_eq(td.ramps.size(), 1, "one ramp")
	check_eq(td.boost_pads.size(), 2, "two boost pads")
	check(td.item_rows.size() >= 4, "item rows")
	check(td.raw.has("mall_bridge"), "mall bridge site")
	# The road never crosses itself (street circuit): far apart where not adjacent.
	var pts: Array = td.main.points
	var n := pts.size()
	var min_gap := 1e9
	for i in range(0, n, 6):
		for j in range(i + 60, n, 6):
			if n - j + i < 60:
				continue
			min_gap = minf(min_gap, Vector2(pts[i].x - pts[j].x, pts[i].z - pts[j].z).length())
	check(min_gap > 40.0, "no road overlaps (closest %.1f m)" % min_gap)


func test_city_kit() -> void:
	for id in CityKit.IDS:
		var m := PropKit.get_mesh(id)
		check(m != null and m.get_surface_count() > 0, "%s builds" % id)
	for id in CityKit.TOWERS:
		var ab := PropKit.get_mesh(id).get_aabb()
		check(ab.end.y >= CityKit.TOWER_H, "%s is 16 floors tall (%.1f m)" % [id, ab.end.y])
		check(ab.size.y < 85.0, "%s not absurd" % id)
	check_eq(CityKit.FLOORS, 16, "16 storeys")
	check_near(CityKit.TOWER_H, 57.6, 0.01, "3.6 m floors")
	var g := CityKit.glass(0)
	check(g.shader.resource_path.ends_with("skyscraper.gdshader"), "skyscraper shader")
	TimeOfDay.apply_materials("night")
	check(float(g.get_shader_parameter("window_glow")) > 0.5, "lit windows at night")
	TimeOfDay.apply_materials("day")
	check_eq(float(g.get_shader_parameter("window_glow")), 0.0, "dark windows by day")
	var mall := PropKit.get_mesh("mall_a").get_aabb()
	check(mall.size.x > 50.0 and mall.size.y > 12.0, "mall is big")


# --- Downtown race --------------------------------------------------------------

func _race(track_id: String) -> void:
	var cfg := Game.default_race_config()
	cfg.track_id = track_id
	cfg.laps = 1
	cfg.seed = 20
	cfg.active_seed = 20
	cfg.event_instance_id = "test-r20"
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame


func test_downtown_race() -> void:
	await _race("downtown_towers")
	check_eq(race.track.id, "downtown_towers", "downtown loaded")
	var decor = race.decor
	check(decor is DowntownDecor, "downtown decor")
	check(decor.towers_placed >= 60, "many skyscrapers (%d)" % decor.towers_placed)
	check_eq(decor.malls_placed, 4, "four malls")
	check(decor.landmarks.has("mall_bridge") and decor.landmarks.has("tower_avenue"), "landmarks for fly-bys")
	check(race.camera.landmarks.size() >= 2, "cinematic knows downtown landmarks")
	check(decor.occluder_count > 50, "towers block the cinematic camera (%d)" % decor.occluder_count)
	# Every near tower chunk stays off the road and its sidewalk.
	var td: TrackData = race.track
	var towers := 0
	for n in decor._chunk_nodes:
		var prop := String(n.get_meta("prop", ""))
		if not prop in CityKit.TOWERS and not prop.begins_with("mall"):
			continue
		for x: Transform3D in n.get_meta("instance_xforms", []):
			towers += 1
			var c := td.main.closest(Vector3(x.origin.x, 0, x.origin.z))
			check(c.distance > td.main.half_width_at(c.s) + td.offroad_width + 8.0, "%s clear of the road (%.1f m)" % [prop, c.distance])
	check(towers > 50, "towers counted (%d)" % towers)
	# Mall bridge: road passes under with >= 7 m headroom.
	var br: Node3D = decor.landmarks.mall_bridge
	var c2 := td.main.closest(br.global_position)
	check(c2.distance < 1.0, "bridge straddles the road")
	var road_y := td.main.position_at(c2.s).y
	check(br.global_position.y + DowntownDecor.BRIDGE_CLEAR - road_y >= 7.0, "7 m+ headroom")
	check(br.find_child("*", true, false) != null, "bridge has signs / lights")
	var signs := 0
	for l in br.find_children("*", "Label3D", true, false):
		if (l as Label3D).text.contains("MALL"):
			signs += 1
	check(signs >= 2, "MALL sign on both faces")
	var mall_signs := 0
	for l in decor.find_children("*", "Label3D", true, false):
		var t := (l as Label3D).text
		if t.ends_with("MALL") or t in ["PORT BAKU", "PARK BULVAR", "28"]: # 0.15.3 real malls
			mall_signs += 1
	check(mall_signs >= 6, "mall signage (%d)" % mall_signs)
	# Gameplay: items, checkpoints, minimap, respawn on the road.
	check(race.items._boxes.size() >= 12, "item boxes (%d)" % race.items._boxes.size())
	var mm := MinimapWidget.new()
	mm.size = Vector2(250, 180)
	race.add_child(mm)
	mm.setup(race)
	var m0 := mm.map(td.main.position_at(0.0))
	check(is_finite(m0.x) and is_finite(m0.y), "minimap maps the downtown layout")
	mm.queue_free()
	var t := race._respawn_transform(race.player.kart)
	var c3 := td.main.closest(t.origin)
	check(c3.distance < td.main.half_width_at(c3.s), "respawn on the road")
	check_eq(race.racers.size(), int(Game.race_config.ai_count) + 1, "full grid")


func test_occluder_segment() -> void:
	await _race("downtown_towers")
	var decor = race.decor
	# Find one tower and shoot a segment through it.
	for n in decor._chunk_nodes:
		if String(n.get_meta("prop", "")) == "sky_a":
			var x: Transform3D = n.get_meta("instance_xforms")[0]
			var a := x.origin + Vector3(0, 80, 0)
			var b := x.origin + Vector3(0, 30, 0)
			var f: float = decor.segment_hit(a, b)
			check(f > 0.0 and f < 1.0, "segment through a tower hits (%.2f)" % f)
			check_eq(decor.segment_hit(x.origin + Vector3(-5, 95, 0), x.origin + Vector3(5, 95, 0)), -1.0, "above the roof is clear")
			return
	check(false, "no sky_a tower found")


# --- Menus and modes ------------------------------------------------------------

func test_track_select_picker() -> void:
	var host := _host()
	Game.race_config = Game.default_race_config()
	screen = load("res://scripts/ui/track_select.gd").new()
	host.add_child(screen)
	for k in 6:
		await tree.process_frame
	check_eq(screen.track_btns.size(), TrackList.IDS.size(), "one tab per track")
	screen.set_track("downtown_towers")
	check_eq(screen.track_id, "downtown_towers", "picked")
	check_eq(Game.race_config.track_id, "downtown_towers", "config follows")
	check_eq(String(Settings.get_value("gameplay", "track", "")), "downtown_towers", "remembered")
	check_eq(screen.track_name.text, tr("TRACK_DOWNTOWN"), "name shown")
	check_eq(screen.preview.track.id, "downtown_towers", "preview redrawn")
	check_eq(Game.default_race_config().track_id, "downtown_towers", "next race defaults to it")
	var ls = load("res://scripts/ui/loading_screen.gd").new()
	check_eq(ls._track_name_key(), "TRACK_DOWNTOWN", "loading screen names the track")
	ls.free()
	host.queue_free()


func test_cup_and_daily_tracks() -> void:
	var cup := BakuCup.new_cup("havhav", 2026)
	var seen := {}
	for i in BakuCup.RACES:
		cup.race = i
		var cfg := BakuCup.apply_config(Game.default_race_config(), cup)
		check(TrackList.is_valid(cfg.track_id), "cup race %d has a track" % i)
		seen[cfg.track_id] = true
	check(seen.has("downtown_towers") and seen.has("seafront_sprint"), "cup visits both tracks")
	var days := {}
	for d in 40:
		var date := "2026-11-%02d" % (d % 28 + 1) if d < 28 else "2026-12-%02d" % (d - 27)
		var ch := DailyChallenge.generate(date, ["havhav", "posi"])
		check(TrackList.is_valid(ch.track), "daily has a track")
		days[ch.track] = true
		check_eq(ch.track, DailyChallenge.generate(date, ["havhav", "posi"]).track, "same track all day")
		if ch.type == "time":
			check(ch.n < 60 * 3, "time goal fits a 2-lap race")
		var cfg := DailyChallenge.apply_config(Game.default_race_config(), ch, "havhav")
		check_eq(cfg.track_id, ch.track, "daily race uses its track")
	check_eq(days.size(), TrackList.IDS.size(), "daily rotates every track")


func test_downtown_trophies() -> void:
	TranslationServer.set_locale("az")
	var ids := {}
	for t in Progression.trophies():
		ids[t.id] = t
	check(ids.has("downtown_towers:quick_win_1"), "downtown win trophy")
	check(ids.has("seafront_sprint:quick_win_1"), "seafront trophy kept")
	check(tr(ids["downtown_towers:quick_finish_1"].name).begins_with("Göydələnlər"), "named for the track")


# --- Garage kart shop -----------------------------------------------------------

func test_garage_buy_flow() -> void:
	var host := _host()
	var first := DowntownGarageHelper.next()
	check(first != "", "a kart is for sale")
	var price := KartShop.price(first)
	# Not enough money: dialog says so, nothing changes.
	SaveManager.data.currency = price - 10
	screen = load("res://scripts/ui/garage_screen.gd").new()
	host.add_child(screen)
	for k in 6:
		await tree.process_frame
	# 0.15.2: the price sits on the kart's own card in the "Maşınlar" tab.
	var card: Button = screen.my_karts.find_child("Kart_" + first, false, false)
	check(card != null, "kart card")
	check(_has_text(card, Money.format(price)), "card shows the price")
	screen.open_buy()
	check_eq(screen.shop_kind(), "funds", "not enough money")
	check(screen.shop_dialog.find_child("Missing", true, false) != null, "shows what's missing")
	screen.close_shop()
	check(not SaveManager.is_kart_owned(first), "still locked")
	# Enough money: confirm buys it and saves.
	SaveManager.data.currency = price + 500
	screen.open_buy()
	check_eq(screen.shop_kind(), "confirm", "confirm dialog")
	screen.confirm_buy()
	check(SaveManager.is_kart_owned(first), "bought")
	check_eq(SaveManager.get_money(), 500, "price paid")
	check(screen.new_kart_id != first, "card moves to the next kart")
	SaveManager.load_profile()
	check(SaveManager.is_kart_owned(first), "purchase saved")
	# Everything owned: friendly message, no button.
	for id in KartShop.ORDER:
		SaveManager.data.currency = 100000
		SaveManager.buy_kart(id)
	screen._build_new_kart()
	await tree.process_frame
	check(screen.new_kart_btn == null, "no buy button when all owned")
	check(screen.new_kart_box.find_child("AllKarts", true, false) != null, "all karts message")
	host.queue_free()


func _has_text(n: Node, t: String) -> bool:
	if n is Label and (n as Label).text.contains(t):
		return true
	for c in n.get_children():
		if _has_text(c, t):
			return true
	return false


class DowntownGarageHelper:
	static func next() -> String:
		return load("res://scripts/ui/garage_screen.gd").next_locked_kart()
