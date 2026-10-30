extends TestCase
## Round 12 (0.9.5): Kids controls (auto drive).

const TEST_SETTINGS := "user://test_settings_kids.json"
var _orig_path := ""
var _orig_values := {}
var race: RaceManager


func before_each() -> void:
	_orig_path = Settings.save_path
	_orig_values = Settings.values.duplicate(true)
	Settings.save_path = TEST_SETTINGS
	SafeFile.delete_all(TEST_SETTINGS)


func after_each() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(race):
		race.queue_free()
		await tree.process_frame
	for a in InputActions.GAMEPLAY_ACTIONS:
		Input.action_release(a)
	SafeFile.delete_all(TEST_SETTINGS)
	Settings.save_path = _orig_path
	Settings.values = _orig_values
	Settings.apply_all()


func _start(kids: bool, laps := 1, seed_value := 5, headless := true) -> void:
	var cfg := Game.default_race_config()
	cfg.laps = laps
	cfg.ai_count = 5
	cfg.seed = seed_value
	cfg.active_seed = seed_value
	cfg.kids_auto = kids
	cfg.event_instance_id = "kids-%d" % seed_value
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = headless
	tree.root.add_child(race)
	await tree.process_frame


func test_setting_persists() -> void:
	check_eq(Settings.defaults().controls.kids_auto, false, "off by default")
	Settings.set_value("controls", "kids_auto", true)
	Settings.values = {}
	Settings.load_settings()
	check_eq(bool(Settings.get_value("controls", "kids_auto", false)), true, "kids mode saved and loaded")
	# Old settings files (no key) load as off.
	var f := FileAccess.open(TEST_SETTINGS, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 4, "controls": {"touch_auto_accelerate": true}}))
	f.close()
	Settings.values = {}
	Settings.load_settings()
	check_eq(bool(Settings.get_value("controls", "kids_auto", true)), false, "backward compatible")


func test_race_reads_setting() -> void:
	Settings.set_value("controls", "kids_auto", true)
	var cfg := Game.default_race_config()
	cfg.erase("kids_auto")
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	tree.root.add_child(race)
	await tree.process_frame
	check(race.kids_mode(), "race picks up the Settings switch")
	check(race.hud.kids_badge.visible, "HUD badge shown")


func test_auto_vs_manual_and_touch_ignored() -> void:
	await _start(false, 1, 5, false)
	check(race.player.player_input.enabled, "manual: player input on")
	check(not race.player.ai.is_physics_processing(), "manual: no autopilot")
	check(not race.hud.kids_badge.visible, "manual: no badge")
	race.queue_free()
	await tree.process_frame
	await _start(true, 1, 5, false)
	check(not race.player.player_input.enabled, "kids: player input off")
	check(race.player.ai.is_physics_processing(), "kids: autopilot drives")
	var t: TouchControls = race.hud.touch
	t.kids = true
	t._layout()
	for id in ["steer_left", "steer_right", "gas", "brake", "drift"]:
		check(not t.get_button(id).visible, "kids: %s hidden" % id)
	for r in race.racers:
		if not r.is_player:
			check_near(float(r.ai.profile.speed_factor), float(AIDriver.load_profile("easy").speed_factor), 0.001, "gentler rivals")
	await _wait(3.0)
	# Hold steer-left hard: the autopilot must keep driving straight on track.
	Input.action_press(InputActions.STEER_LEFT)
	Input.action_press(InputActions.BRAKE)
	var s0 := race.player.tracker.race_distance
	await _wait(6.0)
	Input.action_release(InputActions.STEER_LEFT)
	Input.action_release(InputActions.BRAKE)
	check(race.player.tracker.race_distance > s0 + 40.0, "touch/keys ignored, kart keeps racing")


func _wait(t: float) -> void:
	var end := race.race_time + t
	var n := 0
	while race.race_time < end and n < 20000:
		await tree.physics_frame
		n += 1


func test_full_three_lap_race() -> void:
	Engine.time_scale = 4.0
	await _start(true, 3, 11)
	var off := 0.0
	var worst_off := 0.0
	var stall := 0.0
	var worst_stall := 0.0
	var last_d := 0.0
	var n := 0
	var tr: RaceTracker = race.player.tracker
	while not tr.finished and n < 60 * 400:
		await tree.physics_frame
		n += 1
		if race.state != RaceManager.RaceState.RACING:
			continue
		var dt := 1.0 / 60.0
		var hw: float = race.track.main.half_width_at(tr.s)
		if tr.on_shortcut < 0 and absf(tr.lateral) > hw + 1.5:
			off += dt
		else:
			off = 0.0
		worst_off = maxf(worst_off, off)
		if tr.race_distance > last_d + 0.5:
			last_d = tr.race_distance
			stall = 0.0
		else:
			stall += dt
		worst_stall = maxf(worst_stall, stall)
	check(tr.finished, "autopilot finished 3 laps")
	check_eq(tr.laps_completed(), 3, "three laps")
	check(worst_off < 3.0, "never off-track for long (%.1f s)" % worst_off)
	check(worst_stall < 5.0, "never stuck (%.1f s)" % worst_stall)
	print("  kids race: place %d, time %.1f s, worst off %.1f s, worst stall %.1f s" % [race.player.finish_place, tr.finish_time, worst_off, worst_stall])


func test_goals_swap() -> void:
	var g := [{"kind": "drift", "target": 4, "reward": 30}, {"kind": "overtake", "target": 2, "reward": 30}, {"kind": "stars", "target": 5, "reward": 30}]
	var k := RaceGoals.kids_safe(g)
	check_eq(k.size(), 3, "still three goals")
	var kinds := []
	for x in k:
		kinds.append(String(x.kind))
		check(not String(x.kind) in RaceGoals.SKILL_KINDS, "no skill goal: %s" % x.kind)
	check("finish" in kinds and "stars" in kinds, "simple goals")
	check_eq(RaceGoals.value({"kind": "finish", "target": 1}, {"finished": true}), 1, "finish goal counts")
	for i in 50:
		for x in RaceGoals.generate(i):
			check(String(x.kind) != "finish", "finish only in kids mode")
