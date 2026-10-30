extends TestCase
## Round 5 (0.8.0): the race ends on the line crossing, compact results fit
## every aspect, garage tuning (purchase, persistence, stat effect), manat
## economy payouts and pacing, save v2 → v3 migration, nitro add-on.

const PROFILE := "user://test_profile_r5.json"
var race: RaceManager
var _orig := ""


func before_each() -> void:
	_orig = SaveManager.save_path
	SaveManager.save_path = PROFILE
	SafeFile.delete_all(PROFILE)
	SaveManager.load_profile()


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	if is_instance_valid(race):
		race.queue_free()
		await tree.process_frame
	SafeFile.delete_all(PROFILE)
	SaveManager.save_path = _orig
	SaveManager.load_profile()


# --- Finish ------------------------------------------------------------------

func test_finish_triggers_on_line_crossing() -> void:
	var track := TrackData.load_from_file("res://data/tracks/seafront_sprint.json")
	check_near(float(track.checkpoint_s[0]), track.finish_s, 0.001, "finish gate sits at the visual finish line s")
	var t := RaceTracker.new(track, 2)
	var n := track.checkpoint_count()
	var before := track.main.position_at(track.finish_s - 0.3) + Vector3.UP * 0.4
	var after := track.main.position_at(track.finish_s + 0.3) + Vector3.UP * 0.4
	t.reset(before)
	t.cp_count = n * 2 # every gate of 2 laps passed, the final line remains
	t.max_cp_count = t.cp_count
	t.lap_times = [60.0]
	t.lap_start_time = 60.0
	var ev := t.update(before, after, 120.0)
	var got := false
	for e in ev:
		if e[0] == "finish":
			got = true
	check(got and t.finished, "finish fires on the frame the kart crosses the line (0.6 m step)")
	var t2 := RaceTracker.new(track, 2)
	t2.reset(before)
	t2.cp_count = n * 2
	t2.max_cp_count = t2.cp_count
	t2.lap_times = [60.0]
	var far := track.main.position_at(track.finish_s - 1.5) + Vector3.UP * 0.4
	t2.update(far, before, 119.0)
	check(not t2.finished, "no finish before the line")


func _start_race(ai: int, laps := 2) -> void:
	var cfg := Game.default_race_config()
	cfg.laps = laps
	cfg.items = false
	cfg.ai_count = ai
	cfg.seed = 55
	cfg.active_seed = 55
	cfg.event_instance_id = "test-r5"
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame
	var n := 0
	while race.state != RaceManager.RaceState.RACING and n < 4000:
		await tree.physics_frame
		n += 1


func test_race_ends_for_player_at_crossing() -> void:
	Engine.time_scale = 4.0
	await _start_race(3)
	var crossed := []
	race.player_crossed_finish.connect(func(p): crossed.append(p))
	var got_results := []
	race.results_ready.connect(func(r): got_results.append(r))
	# Simulate the final crossing for the player only.
	race.player.tracker.finished = true
	race.player.tracker.finish_time = race.race_time
	race._handle_event(race.player, ["finish", race.race_time])
	check_eq(crossed.size(), 1, "crossing signal fires immediately")
	check_eq(race.state, RaceManager.RaceState.FINISHING, "finishing celebration state")
	var n := 0
	while got_results.is_empty() and n < 2000:
		await tree.physics_frame
		n += 1
	check(not got_results.is_empty(), "results open without waiting for the AI")
	check(race.state_time < 1.0, "results open right after RESULTS_DELAY")
	var est := 0
	for row in got_results[0].rows:
		if not row.finished and float(row.estimated) > 0.0:
			est += 1
	check(est >= 1, "unfinished AI rows get a projected time")


# --- Results panel ---------------------------------------------------------------

func _fake_results() -> Dictionary:
	var rows: Array = []
	for i in 8:
		rows.append({"place": i + 1, "name": "Yarışçı Uzunad %d" % i, "is_player": i == 2, "finished": i < 4,
			"time": 101.5 + i, "best_lap": 33.0, "estimated": 0.0 if i < 4 else 120.0 + i, "paint": Color.RED, "kart": "havhav"})
	var unlocks := []
	for i in 9:
		unlocks.append("Kubok: çox uzun bir kubok adı nümunəsi %d (+40 qəpik)" % i)
	return {"rows": rows, "player": rows[2], "reward": 215, "payout": {"place": 130, "driving": 85, "record": 0, "total": 215},
		"stars": 7, "stars_total": 3, "stars_added": 7, "unlocks": unlocks, "improved": {"lap": true, "race": false},
		"event_instance_id": "x"}


func test_results_panel_fits_all_aspects() -> void:
	for sz in [Vector2(1280, 720), Vector2(1560, 720), Vector2(1600, 720), Vector2(1280, 960), Vector2(1100, 720)]:
		var host := Control.new()
		host.size = sz
		tree.root.add_child(host)
		var rs := ResultsScreen.new()
		host.add_child(rs)
		rs.setup(null)
		rs.size = sz
		rs.show_results(_fake_results())
		for k in 4:
			await tree.process_frame
		var area := Rect2(Vector2.ZERO, sz)
		for b in [rs.retry_btn, rs.menu_btn]:
			var r: Rect2 = b.get_global_rect()
			check(area.encloses(r), "%s fully visible at %s (%s)" % [b.text, sz, r])
			check(r.size.y >= UITheme.H_BTN_SMALL, "button touch height at %s" % sz)
		check(area.encloses(rs.panel.get_global_rect()), "panel inside the screen at %s" % sz)
		check(rs.panel.size.x <= ResultsScreen.PANEL_W + 1.0, "panel compact width at %s" % sz)
		check(rs.cards_row.get_child_count() <= 3, "at most three unlock cards at %s" % sz)
		check(rs.shown_rows.size() <= 4, "podium rows only at %s" % sz)
		host.queue_free()
		await tree.process_frame


# --- Garage / tuning ---------------------------------------------------------------

func test_tuning_purchase_persistence_and_effect() -> void:
	var id := RacerRoster.DEFAULT_ID
	SaveManager.data.currency = 1000
	check(SaveManager.buy_upgrade(id, "speed"), "buy speed level 1")
	check_eq(SaveManager.get_money(), 1000 - KartTuning.COSTS[0], "price deducted")
	check(SaveManager.buy_upgrade(id, "speed"), "buy speed level 2")
	check(SaveManager.buy_upgrade(id, "nitro"), "fit nitro")
	SaveManager.data.currency = 10
	check(not SaveManager.buy_upgrade(id, "engine"), "cannot buy without money")
	check_eq(SaveManager.get_money(), 10, "no charge on a failed purchase")
	SaveManager.load_profile()
	var lv := SaveManager.tuning_levels(id)
	check_eq(int(lv.speed), 2, "levels persist across a reload")
	check_eq(int(lv.nitro), 1, "nitro persists")
	var stock := KartFactory.load_stats(id)
	var tuned := KartFactory.create(id, true, 0.0, 0, lv)
	check_near(tuned.stats.top_speed, stock.top_speed * (1.0 + 2 * KartTuning.PER_LEVEL.speed), 0.001, "upgrade raises top speed")
	check_near(KartFactory.load_stats(id).top_speed, stock.top_speed, 0.0001, "shared stock stats untouched")
	tuned.free()
	var maxed := {}
	for c in KartTuning.CATEGORIES:
		maxed[c] = 99
	var s := stock.duplicate()
	KartTuning.apply(s, maxed)
	check(s.top_speed <= stock.top_speed * 1.125, "top speed gain capped (+12 %)")
	check(s.acceleration <= stock.acceleration * 1.26, "acceleration gain capped")
	check_eq(int(KartTuning.ai_levels({"speed": 5, "engine": 5, "brakes": 5, "steering": 5, "tyres": 5}, "hard").speed), 5, "hard AI matches a maxed player")
	check_eq(int(KartTuning.ai_levels({"speed": 4, "engine": 4, "brakes": 4, "steering": 4, "tyres": 4}, "easy").speed), 2, "easy AI gets half")
	# Paint bought with manat
	SaveManager.data.currency = 500
	var locked := KartPaints.count() - 1
	check(not SaveManager.is_paint_unlocked(id, locked), "top paint locked by stars")
	check(SaveManager.buy_paint(id, locked), "paint bought with manat")
	check(SaveManager.is_paint_unlocked(id, locked) and SaveManager.get_paint(id) == locked, "bought paint selected")


func test_race_applies_tuning_to_player_and_ai() -> void:
	var id := RacerRoster.DEFAULT_ID
	SaveManager.data.tuning[id] = {"speed": 5, "engine": 5, "brakes": 0, "steering": 0, "tyres": 0, "nitro": 2}
	Engine.time_scale = 4.0
	var cfg_kart := id
	await _start_race(2)
	check(race.player.kart.stats.top_speed > KartFactory.load_stats(cfg_kart).top_speed, "player kart uses its upgrades")
	check(race.nitro != null and race.nitro.level == 2, "nitro add-on present in the race")
	race.nitro.charge = 1.0
	check(race.fire_nitro(), "nitro fires when charged")
	check(race.player.kart.boost.is_active(), "nitro gives a boost")
	check(not race.fire_nitro(), "nitro needs to recharge")
	for r in race.racers:
		if not r.is_player:
			var stock := KartFactory.load_stats(r.kart.stats.id if RacerRoster.is_valid(r.kart.stats.id) else id)
			check(r.kart.stats != stock, "AI gets its own tuned stats copy")


# --- Economy -----------------------------------------------------------------------

func test_money_format() -> void:
	check_eq(Money.format(250), "2,50 ₼", "manat format")
	check_eq(Money.format(5), "0,05 ₼", "small amount")
	check_eq(Money.format(123456), "1 234,56 ₼", "thousands grouping")
	check_eq(Money.format_delta(80), "+80 " + tr("MONEY_QEPIK"), "qəpik delta")
	check_eq(Money.format_delta(120), "+1,20 ₼", "manat delta")


func test_economy_payouts_and_pacing() -> void:
	var p1 := Economy.payout("quick", 1, true, 0, false)
	var p4 := Economy.payout("quick", 4, true, 0, false)
	check_near(float(p1.place) / float(p4.place), 2.0, 0.01, "1st pays 2x of 4th")
	check(Economy.payout("quick", 8, true, 0, false).place > 0, "last place still earns")
	check_eq(int(Economy.payout("quick", 1, true, 999, true).driving), Economy.DRIVING_CAP, "driving income capped")
	var t := Economy.Tally.new()
	t.add("drift", 3)
	t.add("overtake", 2)
	check_eq(t.total, 3 * Economy.DRIFT_BOOST + 2 * Economy.OVERTAKE, "tally sums driving events")
	var sim := Economy.simulate(200, 3)
	print("    ECONOMY SIM ", JSON.stringify(sim))
	check(sim.level1 <= 1.2, "a level-1 upgrade after about one race (%.2f)" % sim.level1)
	check(sim.paint <= 1.3, "a paint after about one race (%.2f)" % sim.paint)
	check(sim.nitro >= 2.5 and sim.nitro <= 5.0, "nitro after 3-5 races (%.2f)" % sim.nitro)
	check(sim.stat_max >= 8.0 and sim.stat_max <= 15.0, "one stat maxed in ~10-15 races (%.2f)" % sim.stat_max)
	check(sim.kart_full >= 40.0 and sim.kart_full <= 62.0, "full kart in ~40-60 races (%.2f)" % sim.kart_full)
	check(float(sim.by_place[6]) >= KartTuning.COSTS[0], "even 6th place affords a level-1 upgrade")


func test_race_payout_granted_once() -> void:
	SaveManager.data.currency = 0
	var res := {"rows": [], "player": {"place": 1, "finished": true, "time": 100.0, "best_lap": 33.0, "kart": "havhav"},
		"laps": 2, "track_id": "seafront_sprint", "mode": "quick", "event_instance_id": "pay-once"}
	var pay := Economy.payout("quick", 1, true, 20, false)
	var g := SaveManager.grant_reward(res.event_instance_id, int(pay.total))
	check_eq(g, 220, "1st place + 20 qəpik driving")
	check_eq(SaveManager.grant_reward(res.event_instance_id, int(pay.total)), 0, "never paid twice")
	check_eq(SaveManager.claim_ad_bonus("pay-once", 220), 220, "rewarded-ad hook doubles once")
	check_eq(SaveManager.claim_ad_bonus("pay-once", 220), 0, "ad bonus once per race")


# --- Save migration ------------------------------------------------------------------

func test_save_v2_migrates_to_manat() -> void:
	var old := {"version": 2, "currency": 345, "stars": 12, "selected_kart": RacerRoster.DEFAULT_ID,
		"lifetime": {"coins": 900, "stars": 12, "seeded": true}, "stats": {"races": 9, "wins": 2, "podiums": 4}}
	SafeFile.write_json(PROFILE, old)
	SaveManager.load_profile()
	check_eq(SaveManager.get_money(), 345 * Money.COINS_TO_QEPIK, "coins converted to qəpik")
	check_eq(int(SaveManager.data.lifetime.coins), 900 * Money.COINS_TO_QEPIK, "lifetime total converted")
	check_eq(int(SaveManager.data.version), SaveManager.SAVE_VERSION, "version bumped")
	check(SaveManager.data.tuning is Dictionary and SaveManager.data.tuning.is_empty(), "tuning added empty")
	check_eq(SaveManager.get_stars(), 12, "stars kept")
	SaveManager.save_profile()
	SaveManager.load_profile()
	check_eq(SaveManager.get_money(), 345 * Money.COINS_TO_QEPIK, "v3 save not converted again")
	# Kart parts keep their unlock state across the conversion (thresholds x2).
	check(Progression.part_unlocked(SaveManager.data, 1) == (900 >= 350), "part unlocks unchanged by migration")
