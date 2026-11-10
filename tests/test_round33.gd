extends TestCase
## Round 33 (0.17.4, first real phone pass on the Mi 12 Lite / Snapdragon 778G):
## the learned "auto" quality cap is forgotten after an update, PerfMonitor
## only judges racing frames, and the CPU savings in the track queries give
## exactly the old answers.
## Production pass (same build): profile keys that never survived a reload,
## "Yenidən" racing the already-paid goals, Kids controls stuck off after the
## Öyrən tour, cup / daily money missing from the lifetime total, HavHav as a
## free second kart, and the garage opening before the starter kart.

const TEST_SETTINGS := "user://test_settings_r33.json"
const TEST_PROFILE := "user://test_profile_r33.json"
var _orig_settings_path := ""
var _orig_settings := {}
var _orig_profile_path := ""
var _orig_data := {}
var _orig_config := {}


func before_each() -> void:
	_orig_settings_path = Settings.save_path
	_orig_settings = Settings.values.duplicate(true)
	Settings.save_path = TEST_SETTINGS
	SafeFile.delete_all(TEST_SETTINGS)
	_orig_profile_path = SaveManager.save_path
	_orig_data = SaveManager.data.duplicate(true)
	_orig_config = Game.race_config.duplicate(true)
	SaveManager.save_path = TEST_PROFILE
	SafeFile.delete_all(TEST_PROFILE)
	SaveManager.load_profile()


func after_each() -> void:
	SafeFile.delete_all(TEST_SETTINGS)
	Settings.save_path = _orig_settings_path
	Settings.values = _orig_settings
	Settings.apply_graphics()
	SafeFile.delete_all(TEST_PROFILE)
	SaveManager.save_path = _orig_profile_path
	SaveManager.data = _orig_data
	Game.race_config = _orig_config


func test_auto_cap_forgotten_after_update() -> void:
	Settings.values.graphics.quality = "auto"
	Settings.apply_preset("medium", false)
	check(Settings.auto_step_down(), "medium -> low")
	check_eq(String(Settings.values.graphics.auto_cap_build), Settings.build_version(), "cap tagged with this build")
	Settings.load_settings()
	check_eq(String(Settings.values.graphics.auto_cap), "low", "same build: cap kept")
	check_eq(String(Settings.values.graphics.preset), "low", "same build: Low kept")
	# A cap learned on an older build (0.17.3 phones were stuck on Low).
	Settings.values.graphics.auto_cap_build = "0.0.1-old"
	Settings.save_settings()
	Settings.load_settings()
	check_eq(String(Settings.values.graphics.auto_cap), "high", "old cap forgotten")
	check_eq(String(Settings.values.graphics.preset), Settings.auto_preset(), "auto tier re-derived")
	# Caps from builds before 0.17.4 have no build tag at all.
	Settings.values.graphics.auto_cap = "low"
	Settings.values.graphics.erase("auto_cap_build")
	Settings.save_settings()
	Settings.load_settings()
	check_eq(String(Settings.values.graphics.auto_cap), "high", "untagged cap forgotten")
	# A player's own choice is never touched.
	Settings.values.graphics.quality = "low"
	Settings.apply_preset("low", false)
	Settings.values.graphics.auto_cap = "low"
	Settings.values.graphics.auto_cap_build = "0.0.1-old"
	Settings.save_settings()
	Settings.load_settings()
	check_eq(String(Settings.values.graphics.preset), "low", "manual Low kept")


func test_perf_monitor_waits_for_racing_frames() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/core/perf_monitor.gd")
	check(src.contains("_racing_s < FALLBACK_WINDOW + SETTLE_TIME"), "window holds racing frames only")
	check(src.contains("_racing_s = 0.0 # the preset switch"), "settle again after a step-down")
	var pm := PerfMonitor.new()
	check(PerfMonitor.SETTLE_TIME >= 2.0, "settle time")
	pm.free()


## Reference: the 0.17.3 TrackData.project() without the bounds skip.
func _project_ref(td: TrackData, pos: Vector3, hint_s: float) -> Dictionary:
	var m := td.main.closest(pos, hint_s, 45.0)
	var best := {"s": m.s, "lateral": m.lateral, "on_shortcut": -1}
	var main_excess: float = m.distance - td.main.half_width_at(m.s)
	for i in td.shortcuts.size():
		var p: TrackPath = td.shortcuts[i].path
		var c := p.closest(pos)
		var excess: float = c.distance - p.half_width_at(c.s)
		if excess < main_excess and c.distance < p.half_width_at(c.s) + td.offroad_width + 2.0:
			var span := td.main.forward_delta(td.shortcuts[i].s_from, td.shortcuts[i].s_to)
			best = {"s": td.main.wrap_s(td.shortcuts[i].s_from + span * (c.s / maxf(p.length, 0.01))), "lateral": c.lateral, "on_shortcut": i}
			main_excess = excess
	return best


func test_track_queries_unchanged() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for id in TrackList.IDS:
		var td := TrackData.load_from_file(TrackList.path(id))
		var paths: Array[TrackPath] = [td.main]
		for sc in td.shortcuts:
			paths.append(sc.path)
		var bad := 0
		for p in paths:
			var count := p.points.size()
			var step := p.length / (count if p.closed else count - 1)
			for k in 300:
				var s := rng.randf_range(-20.0, p.length + 20.0)
				var w := p.wrap_s(s)
				var i := clampi(int(w / step), 0, count - 1)
				var i2 := (i + 1) % count if p.closed else mini(i + 1, count - 1)
				var f := clampf((w - i * step) / step, 0.0, 1.0)
				if not p.position_at(s).is_equal_approx(p.points[i].lerp(p.points[i2], f)) \
						or not is_equal_approx(p.half_width_at(s), lerpf(p.half_widths[i], p.half_widths[i2], f)):
					bad += 1
		check_eq(bad, 0, "%s: position/half width as before" % id)
		var diff := 0
		var shortcut_hits := 0
		for k in 600:
			var s := rng.randf_range(0.0, td.main.length)
			var pos := td.main.position_at(s) + td.main.right_at(s) * rng.randf_range(-25.0, 25.0) + Vector3.UP * rng.randf_range(-1.0, 2.0)
			var hint := s + rng.randf_range(-10.0, 10.0)
			var a := td.project(pos, hint)
			var b := _project_ref(td, pos, hint)
			if int(a.on_shortcut) >= 0:
				shortcut_hits += 1
			if int(a.on_shortcut) != int(b.on_shortcut) or not is_equal_approx(float(a.s), float(b.s)) or not is_equal_approx(float(a.lateral), float(b.lateral)):
				diff += 1
		# Also points on every shortcut, where the skip must not fire.
		for sc in td.shortcuts:
			var p: TrackPath = sc.path
			for k in 100:
				var ps := rng.randf_range(0.0, p.length)
				var pos := p.position_at(ps) + p.right_at(ps) * rng.randf_range(-8.0, 8.0)
				var a := td.project(pos, td.main.wrap_s(sc.s_from + ps))
				var b := _project_ref(td, pos, td.main.wrap_s(sc.s_from + ps))
				if int(a.on_shortcut) >= 0:
					shortcut_hits += 1
				if int(a.on_shortcut) != int(b.on_shortcut) or not is_equal_approx(float(a.s), float(b.s)):
					diff += 1
		check_eq(diff, 0, "%s: project() identical with the bounds skip" % id)
		if not td.shortcuts.is_empty():
			check(shortcut_hits > 0, "%s: shortcuts still found (%d)" % [id, shortcut_hits])


func test_skid_marks_rebuild_per_frame() -> void:
	var marks := SkidMarks.new()
	check(SkidMarks.REBUILD_HZ <= 30.0, "rebuild capped")
	check(marks.has_method("_process"), "rebuild moved to the frame")
	marks.free()


# --- Production pass ------------------------------------------------------------

func test_profile_keys_survive_reload() -> void:
	var data := SaveManager.data
	data.stars = 20
	Stickers.mark_seen(data, 20)
	check_eq(int(data.get(Stickers.SEEN_KEY, 0)), 3, "three stickers seen")
	check(CityCards.mark_played(data, "old_city"), "city marked played")
	SaveManager.set_tutorial_flag("basics_done", true)
	SaveManager.save_profile()
	SaveManager.load_profile()
	data = SaveManager.data
	check_eq(int(data.get(Stickers.SEEN_KEY, -1)), 3, "stickers_seen kept")
	check_eq(Stickers.new_count(data, 20), 0, "no 'Yeni!' stickers after a restart")
	check("old_city" in data.get(CityCards.PLAYED_KEY, []), "played_tracks kept")
	check(not CityCards.is_new(data, "old_city"), "no 'Yeni!' city badge after a restart")
	check(SaveManager.get_tutorial_flag("basics_done"), "HUD hints stay done")
	# Every key the game writes into the profile has a default (else
	# _merge_into drops it on load).
	var defaults := SaveManager.default_profile()
	for key in [Stickers.SEEN_KEY, CityCards.PLAYED_KEY, "race_goals", "login", "cup_progress", "cup_history", "daily_challenge", "track_stats"]:
		check(defaults.has(key), "default for %s" % key)
	for flag in ["drift_done", "lesson_done", "basics_done"]:
		check((defaults.tutorial as Dictionary).has(flag), "tutorial default %s" % flag)


func test_restart_races_the_next_goals() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/racing/race_manager.gd")
	var body := src.substr(src.find("func restart() -> void:"), 1200)
	check(body.contains("_load_goals()"), "restart() reloads the goals")
	var rm := RaceManager.new()
	rm.config = {"mode": "quick", "event_instance_id": "r33-goals"}
	SaveManager.data.race_goals = RaceGoals.generate(1)
	rm._load_goals()
	var first: Array = rm.goals.duplicate(true)
	var res := {"event_instance_id": "r33-goals"}
	rm._settle_goals(res)
	rm._load_goals()
	check_eq(rm.goals, SaveManager.data.race_goals, "the race uses the saved (next) goals")
	check_eq(rm.goals, res.next_goals, "the goals the results screen showed")
	check(rm.goals != first, "not the goals already paid")
	rm.free()


func test_reset_series_clears_kids_override() -> void:
	Game.race_config.kids_auto = false # left by the Öyrən tour
	Game.reset_series()
	check(not Game.race_config.has("kids_auto"), "Kids controls follow the setting again")
	check("kids_auto" in Game.SERIES_KEYS, "listed with the per-mode keys")


func _cup_rows(cup: Dictionary, player_place: int) -> Array:
	var ids: Array = Array(cup.roster).duplicate()
	ids.insert(player_place - 1, String(cup.kart_id))
	var rows: Array = []
	for i in ids.size():
		rows.append({"place": i + 1, "kart": String(ids[i]), "is_player": ids[i] == cup.kart_id, "finished": true,
			"time": 100.0 + i, "best_lap": 45.0, "name": String(ids[i])})
	return rows


func test_cup_prize_counts_towards_lifetime_money() -> void:
	var data := SaveManager.data
	data.starter_chosen = true
	var cup := BakuCup.start(data, "havhav", 4242)
	BakuCup.record_race(data, 0, _cup_rows(cup, 1))
	BakuCup.record_race(data, 1, _cup_rows(BakuCup.current(data), 1))
	cup = BakuCup.current(data)
	var rm := RaceManager.new()
	rm.config = {"mode": "quick", "series": "cup", "cup_race": 2, "kart_id": "havhav", "laps": 2, "track_id": "seafront_sprint"}
	var rows := _cup_rows(cup, 1)
	var res := {"rows": rows, "player": rows[0], "laps": 2, "track_id": "seafront_sprint", "mode": "quick",
		"event_instance_id": BakuCup.event_id(cup, 2)}
	var life0 := int(data.lifetime.coins)
	var money0 := SaveManager.get_money()
	rm._apply_rewards(res)
	check(bool(res.cup.complete), "cup complete")
	check_eq(int(res.cup.prize), BakuCup.PRIZE[0], "winner's prize paid")
	var earned := SaveManager.get_money() - money0
	check_eq(earned, int(res.reward) + int(res.bonus_coins), "balance = race pay + prize + bonuses")
	check_eq(int(SaveManager.data.lifetime.coins) - life0, earned, "lifetime total grows by the same money")
	rm.free()


func test_havhav_is_not_a_free_second_kart() -> void:
	SaveManager.choose_starter("yaska")
	check(not SaveManager.is_kart_owned("havhav"), "HavHav not owned with another starter")
	SaveManager.data.currency = 0
	check_eq(SaveManager.buy_kart("havhav"), "funds", "HavHav costs money")
	check_eq(load("res://scripts/ui/garage_screen.gd").next_locked_kart(), "havhav", "offered first (cheapest)")
	SaveManager.data.currency = KartShop.price("havhav")
	check_eq(SaveManager.buy_kart("havhav"), "ok", "bought")
	check_eq(SaveManager.get_money(), 0, "full price paid")


func test_garage_waits_for_the_starter_kart() -> void:
	check(SaveManager.needs_starter(), "fresh profile has no starter yet")
	var was: bool = Game._changing
	var back0 = Game.garage_back
	var pick0 := Game.starter_pick
	Game._changing = true # block the real scene change
	Game.garage_back = Game.State.KART_SELECT
	Game.open_garage("havhav", Game.State.MAIN_MENU)
	check(Game.starter_pick, "starter pick opened instead")
	check_eq(Game.garage_back, Game.State.KART_SELECT, "garage not opened")
	SaveManager.choose_starter("posi")
	Game.open_garage("posi", Game.State.MAIN_MENU)
	check_eq(Game.garage_back, Game.State.MAIN_MENU, "garage opens once a kart is owned")
	Game._changing = was
	Game.garage_back = back0
	Game.starter_pick = pick0


func test_tour_awards_the_school_trophy() -> void:
	var cfg := {"mode": "tutorial", "event_instance_id": "r33-tour", "track_id": "seafront_sprint"}
	var money0 := SaveManager.get_money()
	var out := TutorialDirector.award(cfg)
	check("school" in SaveManager.data.trophies, "school trophy won by finishing the tour")
	check(SaveManager.get_money() > money0, "its money paid")
	check(not (out.unlocks as Array).is_empty(), "shown as an unlock")
	var money1 := SaveManager.get_money()
	TutorialDirector.award(cfg)
	check_eq(SaveManager.get_money(), money1, "once per tour")
	cfg.debug_autopilot = true
	cfg.event_instance_id = "r33-tour-2"
	check(TutorialDirector.award(cfg).is_empty(), "debug runs never touch the profile")
	var src := FileAccess.get_file_as_string("res://scripts/racing/tutorial_director.gd")
	check(src.substr(src.find("func _finish()"), 300).contains("award(race.config)"), "the last card awards it")


## Owner (2026-11-10): switching Kids controls in Settings during a race only
## took effect in the next race - on and off.
func test_kids_setting_applies_in_the_running_race() -> void:
	Settings.values.controls.kids_auto = false
	var cfg := Game.default_race_config()
	cfg.laps = 1
	cfg.erase("kids_auto")
	Game.race_config = cfg
	var race: RaceManager = load("res://scenes/race/race.tscn").instantiate()
	tree.root.add_child(race)
	await tree.process_frame
	await tree.process_frame
	var pl := race.player
	check(not race.kids_mode() and pl.player_input.enabled, "starts with manual driving")
	race.set_paused(true) # Settings are reached from the pause menu
	Settings.set_value("controls", "kids_auto", true)
	check(race.kids_mode(), "Kids controls on at once")
	check(not pl.player_input.enabled and pl.ai.is_physics_processing(), "the kart drives itself")
	check_near(pl.kart.speed_scale, RaceManager.KIDS_PLAYER_SPEED, 0.001, "kids speed")
	check(race.hud.kids_badge.visible, "Avto badge shown")
	check(not race.hud.touch.get_button("steer_left").visible, "steer buttons hidden")
	Settings.set_value("controls", "kids_auto", false)
	check(not race.kids_mode(), "Kids controls off at once")
	check(pl.player_input.enabled and not pl.ai.is_physics_processing(), "manual driving back")
	check_near(pl.kart.speed_scale, 1.0, 0.001, "normal speed")
	check(not race.hud.kids_badge.visible, "badge hidden")
	check(race.hud.touch.get_button("steer_left").visible, "steer buttons back")
	check(race.kids_used(), "the race remembers it was partly auto-driven")
	race.set_paused(false)
	race.queue_free()
	await tree.process_frame
	# Rekord: a partly auto-driven run keeps no record.
	var rm := RaceManager.new()
	rm.config = {"mode": "time_trial", "kids_auto": false, "kids_used": true}
	var res := {"player": {"finished": true, "time": 80.0, "best_lap": 40.0, "kart": "havhav", "place": 1},
		"track_id": "r33_tt", "laps": 2, "mode": "time_trial", "event_instance_id": "r33-tt"}
	rm._apply_rewards(res)
	check(bool(res.records_skipped), "no record after Kids controls")
	check(SaveManager.get_record("r33_tt").is_empty(), "nothing stored")
	rm.free()


func test_tour_ignores_the_kids_setting() -> void:
	var cfg := Game.default_race_config()
	cfg.mode = "tutorial"
	cfg.laps = 1
	cfg.ai_count = 0
	cfg.kids_auto = false
	Game.race_config = cfg
	var race: RaceManager = load("res://scenes/race/race.tscn").instantiate()
	tree.root.add_child(race)
	await tree.process_frame
	await tree.process_frame
	Settings.set_value("controls", "kids_auto", true)
	check(not race.kids_mode(), "the tour keeps every button")
	race.queue_free()
	await tree.process_frame
