extends TestCase
## Round 24 (0.13.0): wordless steer/drift hints, rival portraits, contact
## shadow map (AoMap), wet road + lamp streaks, kart outline, first lesson,
## sticker album, new city İçərişəhər (old_city).

const TEST_SETTINGS := "user://test_settings_r24.json"
const TEST_PROFILE := "user://test_profile_r24.json"
var _orig_settings_path := ""
var _orig_settings := {}
var _orig_profile_path := ""
var race: RaceManager


func before_each() -> void:
	_orig_settings_path = Settings.save_path
	_orig_settings = Settings.values.duplicate(true)
	Settings.save_path = TEST_SETTINGS
	SafeFile.delete_all(TEST_SETTINGS)
	_orig_profile_path = SaveManager.save_path
	SaveManager.save_path = TEST_PROFILE
	SafeFile.delete_all(TEST_PROFILE)
	SaveManager.load_profile()
	Game.race_config = Game.default_race_config()


func after_each() -> void:
	if is_instance_valid(race):
		race.queue_free()
		await tree.process_frame
	SafeFile.delete_all(TEST_SETTINGS)
	SafeFile.delete_all(TEST_PROFILE)
	Settings.save_path = _orig_settings_path
	Settings.values = _orig_settings
	SaveManager.save_path = _orig_profile_path
	SaveManager.load_profile()


func _race(extra := {}) -> void:
	var cfg := Game.default_race_config()
	cfg.laps = 1
	cfg.seed = 24
	cfg.active_seed = 24
	cfg.event_instance_id = "test-r24"
	cfg.merge(extra, true)
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame


func test_tap_hint_modes() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	tree.root.add_child(host)
	var h := TapHint.new()
	h.mode = "alternate"
	h.targets = [[Vector2(100, 600), 60.0], [Vector2(300, 600), 60.0]]
	h.duration = 99.0
	host.add_child(h)
	h.size = host.size
	h._t = 0.1
	check_eq(h.current_index(), 0, "alternate starts on the first button")
	h._t = TapHint.CYCLE_ALT + 0.1
	check_eq(h.current_index(), 1, "then moves to the second")
	h.mode = "hold"
	h._t = 0.25 + TapHint.HOLD_TIME * 0.5
	check_near(h.hold_fill(), 0.5, 0.05, "hold ring half full mid-hold")
	check_near(h.press(), 1.0, 0.001, "finger down while holding")
	h._t = 0.25 + TapHint.HOLD_TIME + 0.5
	check(h.press() < 0.5, "finger lifted after the hold (let go)")
	h.mode = "tap"
	h._process(0.016)
	var hand: TextureRect = h.get_child(0)
	check(hand.flip_v, "near the bottom edge the hand comes from above")
	check(hand.position.y + 96.0 <= host.size.y + 1.0, "hand stays on screen")
	host.queue_free()


func test_rival_neighbours() -> void:
	await _race()
	var n := RivalStrip.neighbours(race.racers, 1)
	check_eq(String(n[0]), "", "leader has nobody ahead")
	check(String(n[1]) != "", "leader has someone behind")
	n = RivalStrip.neighbours(race.racers, race.racers.size())
	check_eq(String(n[1]), "", "last has nobody behind")
	n = RivalStrip.neighbours(race.racers, 3)
	var ids := []
	for r in race.racers:
		if int(r.place) in [2, 4]:
			ids.append(String(r.kart.stats.id))
	check(String(n[0]) in ids and String(n[1]) in ids and n[0] != n[1] or ids.size() < 2, "3rd sees 2nd and 4th")


func test_ao_map_built_and_cleared() -> void:
	check(AoMap.blob_for(AABB(Vector3.ZERO, Vector3(10, 0.5, 10))).is_empty(), "flat things get no shadow")
	check(AoMap.blob_for(AABB(Vector3.ZERO, Vector3(0.6, 6, 0.6))).is_empty(), "thin poles get no shadow")
	var b := AoMap.blob_for(AABB(Vector3(0, 0, 0), Vector3(8, 10, 6)))
	check(not b.is_empty() and float(b.s) > 0.2 and float(b.s) <= 0.5, "house: soft shadow 0.2-0.5")
	for tid in TrackList.IDS:
		await _race({"track_id": tid})
		check(AoMap.active, "%s: AO map active" % tid)
		check(race.decor.ao_blobs.size() > 30, "%s: footprints collected (%d)" % [tid, race.decor.ao_blobs.size()])
		check(AoMap.last_build_ms < 400.0, "%s: built in %.0f ms" % [tid, AoMap.last_build_ms])
		var img: Image = race.decor.ao_texture.get_image()
		check(img.has_mipmaps(), "%s: mipmapped" % tid)
		var dark := 1.0
		for i in 200:
			var bl: Dictionary = race.decor.ao_blobs[i % race.decor.ao_blobs.size()]
			var rr: Rect2 = race.decor.ao_rect
			var uv: Vector2 = (Vector2(bl.c) - rr.position) / rr.size
			if uv.x > 0.0 and uv.y > 0.0 and uv.x < 1.0 and uv.y < 1.0:
				dark = minf(dark, img.get_pixelv(Vector2i(uv * Vector2(img.get_size()))).r)
		check(dark < 0.85 and dark > 0.35, "%s: shaded under a footprint, never black (%.2f)" % [tid, dark])
		race.queue_free()
		race = null
		await tree.process_frame
		await tree.process_frame
		check(not AoMap.active, "%s: cleared when the race leaves" % tid)
	for f in ["ground", "road", "vcolor", "skyscraper"]:
		check((load("res://assets/materials/%s.gdshader" % f) as Shader).code.contains("yaska_ao"), "%s shader reads the AO map" % f)


func test_wet_road_and_streaks() -> void:
	check((load("res://assets/materials/road.gdshader") as Shader).code.contains("yaska_night"), "road gets wet at night")
	await _race({"time_of_day": "night"})
	var st := race.get_node_or_null("LampStreaks") as MultiMeshInstance3D
	check(st != null, "lamp streaks at night")
	if st:
		check_eq(st.multimesh.instance_count, race.decor.instance_transforms("lamp").size(), "one streak per lamp, one MultiMesh")
	race.queue_free()
	await tree.process_frame
	await _race({"time_of_day": "sunset"})
	check(race.get_node_or_null("LampStreaks") == null, "no streaks at sunset")


func test_kart_outline() -> void:
	Settings.apply_preset("medium", false)
	await _race()
	var vis: KartVisual = race.player.kart.get_node("Visual")
	check(vis.outlined.size() >= 2, "body and driver outlined (%d)" % vis.outlined.size())
	for g in vis.outlined:
		check((g as GeometryInstance3D).material_overlay == KartVisual.outline_material(), "outline overlay set")
		check((g as GeometryInstance3D).visibility_range_end > 0.0, "near model only")
	Settings.apply_preset("low", false)
	race.environment.apply_graphics()
	for g in vis.outlined:
		check((g as GeometryInstance3D).material_overlay == null, "no outline on Low")


func test_lesson_flow() -> void:
	check(not SaveManager.get_tutorial_flag(LessonDirector.FLAG), "new profile: lesson not done")
	await _race({"lesson": true, "ai_count": 2, "items": false})
	check(race.lesson != null, "lesson director in the race")
	var ls := race.lesson
	ls.leave_to_menu = false
	var guard := 0
	while race.state != RaceManager.RaceState.RACING and guard < 600:
		await tree.physics_frame
		guard += 1
	check_eq(ls.step, LessonDirector.Step.STEER, "starts with steering")
	ls.set_process(false) # the test drives it frame by frame
	ls._process(LessonDirector.START_DELAY + 0.01)
	check(ls._started, "first hint after the start delay")
	# Steer left then right (PlayerInput rewrites input.steer every physics
	# tick, so the lesson is stepped right after each value is set).
	race.player.kart.input.steer = -1.0
	ls._process(0.016)
	race.player.kart.input.steer = 1.0
	ls._process(0.016)
	check_eq(ls.step, LessonDirector.Step.DRIFT, "steering both ways passes step 1")
	check(ls.done_by_player[0], "done by the child")
	ls._process(LessonDirector.TIMEOUTS[LessonDirector.Step.DRIFT] + 0.1)
	check_eq(ls.step, LessonDirector.Step.ITEM, "a missed drift times out (no getting stuck)")
	check(not ls.done_by_player[1], "timeout is not counted as done")
	check_eq(race.player.kart.item, &"turbo", "the lesson hands a nitro")
	race.player.kart.item = &""
	ls._process(0.5)
	check_eq(ls.step, LessonDirector.Step.DONE, "using the item ends the lesson")
	check(ls.done_by_player[2], "item used by the child")
	check(SaveManager.get_tutorial_flag(LessonDirector.FLAG), "lesson remembered")
	Game.reset_series()
	check(not Game.race_config.has("lesson"), "reset_series drops the lesson flag")


func test_stickers() -> void:
	check_eq(Stickers.LIST.size(), 12, "12 stickers")
	var prev := -1
	for s in Stickers.LIST:
		check(int(s.stars) > prev, "%s: rising star goals" % s.id)
		prev = int(s.stars)
		check(Stickers.texture(String(s.id)) != null, "%s: sticker art" % s.id)
		check(Stickers.texture(String(s.id), true) != null, "%s: locked art" % s.id)
		check(tr(Stickers.name_key(String(s.id))) != Stickers.name_key(String(s.id)), "%s: name translated" % s.id)
	check_eq(Stickers.unlocked_count(0), 0, "none at 0 stars")
	check_eq(Stickers.unlocked_count(15), 3, "3 at 15 stars")
	check_eq(Stickers.unlocked_between(10, 26), ["baku_eye", "heydar_aliyev"], "crossing two goals in one race")
	check_eq(Stickers.next_goal(16), 25, "next goal")
	var d := {"stickers_seen": 1}
	check_eq(Stickers.new_count(d, 15), 2, "two new")
	Stickers.mark_seen(d, 15)
	check_eq(Stickers.new_count(d, 15), 0, "seen")


func test_old_city_track() -> void:
	check("old_city" in TrackList.IDS, "third city listed")
	check(ResourceLoader.exists("res://assets/ui/cities/old_city.jpg"), "city card picture")
	check(tr("TRACK_OLDCITY") == "İçərişəhər" or TranslationServer.get_locale().begins_with("en"), "city name")
	var td := TrackData.load_from_file("res://data/tracks/old_city.json")
	check(td != null and td.main.length > 600.0, "track loads (%.0f m)" % (td.main.length if td else 0.0))
	check_eq(td.decor_kind, "oldcity", "Old City decor")
	check_eq(td.checkpoint_s.size(), 7, "finish + 6 checkpoints")
	var trophies := 0
	for t in Progression.trophies():
		if String(t.get("track", "")) == "old_city":
			trophies += 1
			check(tr(String(t.name)) != String(t.name), "%s translated" % t.name)
	check_eq(trophies, 7, "7 Old City trophies")
	await _race({"track_id": "old_city", "debug_autopilot": true})
	check(race.decor is OldCityDecor, "OldCityDecor built")
	check(race.decor.landmarks.has("maiden_tower") and race.decor.landmarks.has("icherisheher_gate"), "Maiden Tower and Qoşa Qala")
	check(race.decor.instance_transforms("lamp").size() > 5, "lamps on the Boulevard")
	# Full lap on autopilot: everyone finishes, nobody needs a rescue.
	var guard := 0
	while race.state != RaceManager.RaceState.RESULTS and guard < 60 * 120:
		await tree.physics_frame
		guard += 1
	check_eq(race.state, RaceManager.RaceState.RESULTS, "race reaches the results")
	for r in race.racers:
		check(r.tracker.finished, "%s finished" % r.name)
		check_eq(int(r.stats.recovers), 0, "%s never needed a respawn" % r.name)
