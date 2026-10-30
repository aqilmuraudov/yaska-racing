extends TestCase
## Round 17 (0.10.0): game modes — Bakı Kuboku, Rekord (ghost + delta),
## Gündəlik tapşırıq, 4-card mode select, START/hint overlap fix.

const PROFILE := "user://test_profile_r17.json"
const GHOST_DIR := "user://test_ghosts_r17"
var _orig := ""
var race: RaceManager
var scr: Node
var _ledger: Array = []


func before_each() -> void:
	_orig = SaveManager.save_path
	SaveManager.save_path = PROFILE
	SafeFile.delete_all(PROFILE)
	SaveManager.load_profile()
	_ledger = []


func after_each() -> void:
	if is_instance_valid(race):
		race.queue_free()
	if is_instance_valid(scr):
		scr.queue_free()
	await tree.process_frame
	SafeFile.delete_all(PROFILE)
	SaveManager.save_path = _orig
	SaveManager.load_profile()
	Game.race_config = Game.default_race_config()
	Settings.values.controls.kids_auto = false


## Ledger-style grant for plain dictionaries: pays once per id.
func _grant(id: String, amount: int) -> int:
	if id in _ledger:
		return 0
	_ledger.append(id)
	return amount


## Result rows with the given racer ids in finishing order.
func _rows(order: Array, player_id: String) -> Array:
	var rows: Array = []
	for i in order.size():
		rows.append({"place": i + 1, "kart": order[i], "is_player": order[i] == player_id, "finished": true, "time": 80.0 + i})
	return rows


func _order_with_player_at(cup: Dictionary, place: int) -> Array:
	var o: Array = Array(cup.roster).duplicate()
	o.insert(place - 1, String(cup.kart_id))
	return o


# --- Cup -------------------------------------------------------------------------

func test_cup_points_standings_prize() -> void:
	var data := SaveManager.default_profile()
	var cup := BakuCup.start(data, "havhav", 77)
	check_eq((cup.roster as Array).size(), 5, "five fixed rivals")
	check(not ("havhav" in cup.roster), "player kart not among rivals")
	check_eq(BakuCup.points_for(1), 10, "1st = 10")
	check_eq(BakuCup.points_for(6), 1, "6th = 1")
	check_eq(BakuCup.points_for(7), 0, "7th = 0")
	# Race 1: player 1st; race 2: player 3rd; race 3: player 2nd.
	var r1 := BakuCup.record_race(data, 0, _rows(_order_with_player_at(cup, 1), "havhav"))
	check(r1.ok and int(r1.gained.havhav) == 10, "race 1 scores 10")
	var again := BakuCup.record_race(data, 0, _rows(_order_with_player_at(cup, 1), "havhav"))
	check(not again.ok, "the same race never scores twice")
	cup = BakuCup.current(data)
	check_eq(int(cup.race), 1, "one race done")
	check_eq(int(cup.points.havhav), 10, "10 points after race 1")
	check_eq(String(BakuCup.standings(cup)[0].id), "havhav", "leader after race 1")
	check_eq(int(BakuCup.standings(cup, true)[0].points), 0, "previous totals kept for the animation")
	BakuCup.record_race(data, 1, _rows(_order_with_player_at(cup, 3), "havhav"))
	cup = BakuCup.current(data)
	BakuCup.record_race(data, 2, _rows(_order_with_player_at(cup, 2), "havhav"))
	cup = BakuCup.current(data)
	check(BakuCup.is_complete(cup), "complete after three races")
	check_eq(int(cup.points.havhav), 10 + 6 + 8, "10 + 6 + 8 points")
	var st := BakuCup.standings(cup)
	var total := 0
	for r in st:
		total += int(r.points)
	check_eq(total, 31 * 3, "every race hands out 31 points")
	for i in range(1, st.size()):
		check(int(st[i - 1].points) >= int(st[i].points), "standings sorted by points")
	var place := BakuCup.player_place(cup)
	check_eq(int(cup.prize), BakuCup.prize_for(place), "prize by cup place")
	check(BakuCup.prize_for(1) > Economy.PLACE_PAY[0], "cup win pays more than a race win")
	var paid := BakuCup.pay_prize(cup, _grant)
	check_eq(paid, BakuCup.prize_for(place), "prize paid")
	check_eq(BakuCup.pay_prize(cup, _grant), 0, "prize paid once")
	check_eq(BakuCup.record_race(data, 3, []).ok, false, "no 4th race")


func test_cup_resume_and_reset() -> void:
	var cup := BakuCup.start(SaveManager.data, "bicok", 4242)
	BakuCup.record_race(SaveManager.data, 0, _rows(_order_with_player_at(cup, 2), "bicok"))
	SaveManager.save_profile()
	SaveManager.load_profile() # app closed and opened again
	var c := BakuCup.current(SaveManager.data)
	check(not c.is_empty(), "cup survives a restart")
	check_eq(int(c.race), 1, "resumes at race 2")
	check_eq(int(c.points.bicok), 8, "points kept")
	check_eq(int(c.seed), 4242, "seed kept")
	var cfg := BakuCup.apply_config({}, c)
	check_eq(int(cfg.cup_race), 1, "next race is race 2")
	check_eq(String(cfg.fixed_event_id), "cup:4242:1", "fixed event id per cup race")
	check_eq(int(cfg.laps), 3, "race 2 has 3 laps")
	check_eq(String(cfg.grid_order[cfg.grid_order.size() - 1]), String(BakuCup.standings(c)[0].id), "leader starts last in race 2")
	# Damaged state: clean reset.
	SaveManager.data.cup_progress = {"seed": 1, "race": 1, "kart_id": "nobody", "roster": [], "points": {}}
	SaveManager.save_profile()
	SaveManager.load_profile()
	check(BakuCup.current(SaveManager.data).is_empty(), "damaged cup state is dropped")
	check(not BakuCup.is_active(SaveManager.data), "no active cup after reset")
	# Quit: closes without a history entry; a finished cup is counted.
	cup = BakuCup.start(SaveManager.data, "havhav", 5)
	BakuCup.close(SaveManager.data)
	check(SaveManager.data.cup_progress.is_empty(), "quit clears the cup")
	check_eq(int(SaveManager.data.cup_history.get("played", 0)), 0, "quitting is not a played cup")
	cup = BakuCup.start(SaveManager.data, "havhav", 6)
	for i in 3:
		BakuCup.record_race(SaveManager.data, i, _rows(_order_with_player_at(BakuCup.current(SaveManager.data), 1), "havhav"))
	BakuCup.close(SaveManager.data)
	check_eq(int(SaveManager.data.cup_history.played), 1, "finished cup counted")
	check_eq(int(SaveManager.data.cup_history.won), 1, "cup win counted")


func test_cup_grid_and_race() -> void:
	var data := SaveManager.default_profile()
	var cup := BakuCup.start(data, "havhav", 99)
	var g1 := BakuCup.grid_order(cup, 0)
	check_eq(g1.find("havhav"), 3, "race 1: player starts 4th as usual")
	check_eq(RaceManager.grid_slots("havhav", Array(cup.roster), []).find("havhav"), 3, "default grid unchanged")
	check_eq(RaceManager.grid_slots("havhav", Array(cup.roster), ["x"]).find("havhav"), 3, "invalid order ignored")
	check(not bool(BakuCup.STAGES[2].items) and bool(BakuCup.STAGES[0].items), "final race has no items")
	check(int(BakuCup.STAGES[0].laps) != int(BakuCup.STAGES[1].laps), "lap count varies")
	# Race 2 in the real race scene: same rivals, grid by reverse standings.
	SaveManager.data.cup_progress = cup
	BakuCup.record_race(SaveManager.data, 0, _rows(_order_with_player_at(cup, 1), "havhav"))
	cup = BakuCup.current(SaveManager.data)
	var cfg := Game.default_race_config()
	BakuCup.apply_config(cfg, cup)
	cfg.active_seed = int(cfg.seed)
	cfg.event_instance_id = String(cfg.fixed_event_id)
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame
	check_eq(race.racers.size(), 6, "six racers")
	var ids: Array = []
	for r in race.racers:
		ids.append(String(r.kart.stats.id))
	check_eq(ids, Array(cfg.grid_order), "grid follows the cup order")
	check_eq(race.player.index, 5, "race 2: the leader (player) starts last")
	check(race.goals.is_empty(), "no quick-race goals in a cup race")
	check_eq(String(race.config.event_instance_id), "cup:99:1", "cup race event id")
	# Scoring through the race manager (rows from build_results).
	var res := {"rows": _rows(ids, "havhav"), "player": {"place": 6, "finished": true, "kart": "havhav", "time": 90.0}}
	var extra := race.apply_series(res, SaveManager.data, _grant)
	check_eq(extra, 0, "no prize before the final")
	check(res.cup.ok and int(res.cup.gained) == BakuCup.points_for(6), "race manager scores the race")
	check_eq(int(BakuCup.current(SaveManager.data).race), 2, "cup advanced")


func test_cup_screen_and_podium() -> void:
	var cup := BakuCup.start(SaveManager.data, "havhav", 31)
	BakuCup.record_race(SaveManager.data, 0, _rows(_order_with_player_at(cup, 4), "havhav"))
	scr = load("res://scenes/menus/cup.tscn").instantiate()
	tree.root.add_child(scr)
	for i in 4:
		await tree.process_frame
	check_eq(scr.view, "standings", "standings between races")
	check_eq(scr.rows.size(), 6, "six rows")
	scr.finish_animation()
	await tree.process_frame
	var st := BakuCup.standings(BakuCup.current(SaveManager.data))
	for r in st:
		var row: Control = scr.rows[String(r.id)]
		check_near(row.position.y, (int(r.place) - 1) * (scr.ROW_H + scr.ROW_GAP), 0.5, "row %s slid to its place" % r.id)
		check_near(scr.bars[String(r.id)].value, float(r.points), 0.01, "bar shows the new total")
	check(scr.start_btn.visible, "start next race button")
	scr._on_reset()
	check(BakuCup.is_active(SaveManager.data), "first tap only arms the reset")
	scr.queue_free()
	await tree.process_frame
	for i in range(1, 3):
		BakuCup.record_race(SaveManager.data, i, _rows(_order_with_player_at(BakuCup.current(SaveManager.data), 1), "havhav"))
	scr = load("res://scenes/menus/cup.tscn").instantiate()
	tree.root.add_child(scr)
	for i in 4:
		await tree.process_frame
	check_eq(scr.view, "podium", "podium after race 3")
	check(scr.find_child("Trophy", true, false) != null, "trophy shown")
	check(scr.prize_chip != null and scr.prize_chip.get_meta("value").text == Money.format(int(BakuCup.current(SaveManager.data).prize)), "prize shown in manat")


# --- Rekord ----------------------------------------------------------------------

func _tt_race(kids := false) -> void:
	var cfg := Game.default_race_config()
	cfg.mode = "time_trial"
	cfg.ai_count = 0
	cfg.items = false
	cfg.laps = 2
	cfg.seed = 17
	cfg.active_seed = 17
	cfg.kids_auto = kids
	cfg.event_instance_id = "test-r17-tt"
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame


func _fake_samples(n: int, speed: float) -> Array:
	var out: Array = []
	for i in n:
		out.append([0.0, 0.0, 0.0, 0.0, i * GhostSystem.INTERVAL * speed])
	return out


func test_ghost_record_and_playback() -> void:
	await _tt_race()
	var gs := race.ghosts
	check(gs != null, "time trial has a ghost system")
	DirAccess.make_dir_recursive_absolute(GHOST_DIR)
	gs.ghost_dir_override = GHOST_DIR
	SafeFile.delete_all(gs.ghost_path())
	check(gs.save_ghost(_fake_samples(800, 20.0), 40.0), "ghost saved")
	check(gs.has_splits(), "format 2 ghost has lap distances")
	check_near(gs.ghost_time_at(200.0), 10.0, 0.06, "ghost time at 200 m (20 m/s)")
	check(is_nan(gs.ghost_time_at(1e6)), "beyond the ghost lap: unknown")
	var loaded := gs.load_ghost()
	check_eq(gs.status, "loaded", "ghost reloads from disk")
	check_eq(int(loaded.format), GhostSystem.FORMAT, "saved in the current format")
	# Format 1 ghosts (0.9.x) still replay, without the live delta.
	var old := loaded.duplicate(true)
	old.format = 1
	var smp: Array = []
	for s in old.samples:
		smp.append((s as Array).slice(0, 4))
	old.samples = smp
	check(GhostSystem.is_compatible(old, gs.track_id, gs.track_version), "format 1 ghost still compatible")
	# Playback: the ghost appears once racing and follows its samples.
	var n := 0
	while race.state != RaceManager.RaceState.RACING and n < 3000:
		await tree.physics_frame
		n += 1
	for i in 10:
		await tree.process_frame
	check(gs._ghost_model != null and gs._ghost_model.visible, "ghost kart visible while racing")
	# Live delta: player at d metres after t seconds vs ghost at 20 m/s.
	race.race_time = 12.0
	gs._lap_start_time = 0.0
	var d := gs.lap_distance()
	var ghost_t := gs.ghost_time_at(d)
	if d >= 20.0:
		check_near(gs.live_delta(), 12.0 - ghost_t, 0.001, "live delta = lap time - ghost time")
	check_eq(RaceHUD.format_delta(-0.314), "−0.31", "ahead: minus")
	check_eq(RaceHUD.format_delta(0.5), "+0.50", "behind: plus")
	check_eq(RaceHUD.format_delta(-0.003), "0.00", "dead even: no sign")
	# A slower lap keeps the old ghost; a faster one replaces it.
	gs._recording = _fake_samples(10, 20.0)
	gs._on_lap(race.player, 1, 45.0)
	check_eq(gs.best_lap_ms(), 40000, "slower lap does not replace the record ghost")
	check_near(gs.last_lap_delta, 5.0, 0.001, "lap delta +5.00")
	gs._recording = _fake_samples(10, 20.0)
	gs._on_lap(race.player, 2, 38.5)
	check_eq(gs.best_lap_ms(), 38500, "faster lap becomes the ghost")
	check_near(gs.last_lap_delta, -1.5, 0.001, "lap delta −1.50")
	SafeFile.delete_all(gs.ghost_path())


func test_best_time_persistence_and_record_reward() -> void:
	var imp := SaveManager.submit_times("seafront_sprint", 82000, 40500, "havhav", 2)
	check(imp.lap and imp.race, "first times are records")
	SaveManager.save_profile()
	SaveManager.load_profile()
	var rec := SaveManager.get_record("seafront_sprint")
	check_eq(int(rec.best_lap_ms), 40500, "best lap persisted")
	check_eq(int(rec.best_race_ms_2), 82000, "best 2-lap race persisted")
	var worse := SaveManager.submit_times("seafront_sprint", 90000, 41000, "havhav", 2)
	check(not worse.lap and not worse.race, "slower is not a record")
	check_eq(int(SaveManager.get_record("seafront_sprint").best_lap_ms), 40500, "record unchanged")
	var p1 := Economy.payout("time_trial", 1, true, 0, true)
	var p0 := Economy.payout("time_trial", 1, true, 0, false)
	check_eq(int(p1.total) - int(p0.total), Economy.RECORD_BONUS, "small bonus for a new record")
	check(SaveManager.grant_reward("tt-1", int(p1.total)) > 0 and SaveManager.grant_reward("tt-1", int(p1.total)) == 0, "paid once per record race")


# --- Daily -----------------------------------------------------------------------

func test_daily_seeding_and_reward() -> void:
	var a := DailyChallenge.generate("2026-10-30", ["havhav", "posi"])
	var b := DailyChallenge.generate("2026-10-30", ["posi", "havhav"])
	check_eq(a, b, "same day, same challenge")
	var types := {}
	var seeds := {}
	for day in range(1, 31):
		var ch := DailyChallenge.generate("2026-11-%02d" % day, ["havhav", "posi", "bicok"])
		types[ch.type] = true
		seeds[ch.seed] = true
		check(DailyChallenge.text(ch) != "", "challenge has a text (%s)" % ch.type)
		if ch.type == "win_kart":
			check(String(ch.kart) in ["havhav", "posi", "bicok"], "win_kart uses an owned kart")
	check(types.size() >= 4, "a month mixes the challenge types (%d)" % types.size())
	check(seeds.size() >= 28, "different rivals each day")
	var solo := DailyChallenge.generate("2026-11-05", ["havhav"])
	check(solo.type != "win_kart", "one owned kart: no kart challenge")
	# Once per day.
	var data := SaveManager.default_profile()
	var ch := DailyChallenge.generate("2026-10-30")
	check(not DailyChallenge.done_today(data, "2026-10-30"), "not done yet")
	check_eq(DailyChallenge.complete(data, ch, _grant), DailyChallenge.REWARD, "reward paid")
	check(DailyChallenge.done_today(data, "2026-10-30"), "done state")
	check_eq(DailyChallenge.complete(data, ch, _grant), 0, "paid once per day")
	check(not DailyChallenge.done_today(data, "2026-10-31"), "a new day is open again")
	# Goal checks.
	var win := {"type": "win", "date": "x"}
	check(DailyChallenge.is_done(win, {"finished": true, "place": 1}), "win done")
	check(not DailyChallenge.is_done(win, {"finished": true, "place": 2}), "2nd is not a win")
	check(not DailyChallenge.is_done(win, {"finished": false, "place": 1}), "must finish")
	check(DailyChallenge.is_done({"type": "stars", "n": 6}, {"finished": true, "stars": 6}), "stars done")
	check(DailyChallenge.is_done({"type": "time", "n": 90}, {"finished": true, "time": 89.5}), "time done")
	check(not DailyChallenge.is_done({"type": "clean"}, {"finished": true, "place": 1, "hard_hits": 1}), "a wall hit fails clean")
	check(DailyChallenge.REWARD < Economy.PLACE_PAY[0], "daily bonus below a race win (fair economy)")


func test_daily_through_race_and_mode_card() -> void:
	var cfg := Game.default_race_config()
	var ch := {"date": Progression.today(), "type": "win", "laps": 2, "seed": 123, "kart": "", "n": 0}
	DailyChallenge.apply_config(cfg, ch, "havhav")
	cfg.laps = 1
	cfg.active_seed = 123
	cfg.event_instance_id = "test-r17-daily"
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame
	var res := {"rows": [], "player": {"place": 1, "finished": true, "kart": "havhav", "time": 80.0}, "stars": 3}
	check_eq(race.apply_series(res, SaveManager.data, SaveManager.grant_reward), DailyChallenge.REWARD, "daily paid through the race")
	var res2 := {"rows": [], "player": {"place": 1, "finished": true, "kart": "havhav", "time": 80.0}, "stars": 3}
	check_eq(race.apply_series(res2, SaveManager.data, SaveManager.grant_reward), 0, "second win today pays nothing")
	check(res2.daily.already, "already done today")
	race.queue_free()
	await tree.process_frame
	scr = load("res://scenes/menus/mode_select.tscn").instantiate()
	tree.root.add_child(scr)
	for i in 4:
		await tree.process_frame
	check_eq(scr.cards.size(), 4, "four mode cards")
	for id in ["quick", "cup", "time_trial", "daily"]:
		check(scr.cards.has(id), "card %s" % id)
	check(scr.school_btn != null, "Drift School still reachable")
	var chip: PanelContainer = scr.status_chips.get("daily")
	check(chip != null and String(chip.get_meta("value").text).begins_with("✓"), "daily card shows done")


# --- Kids mode -------------------------------------------------------------------

func test_kids_mode_interaction() -> void:
	var win := {"type": "win", "date": "d", "n": 0, "kart": ""}
	var kw := DailyChallenge.effective(win, true)
	check_eq(kw.type, "podium", "kids: win becomes top 3")
	check(DailyChallenge.is_done(kw, {"finished": true, "place": 3}), "kids podium counts")
	check_eq(int(DailyChallenge.effective({"type": "time", "n": 100, "date": "d"}, true).n), 115, "kids: more time")
	check_eq(DailyChallenge.effective(win, false).type, "win", "normal controls unchanged")
	# Rekord with kids controls: no ghost saved, no record.
	await _tt_race(true)
	var gs := race.ghosts
	gs.ghost_dir_override = GHOST_DIR
	SafeFile.delete_all(gs.ghost_path())
	gs._best = {}
	gs._recording = _fake_samples(10, 20.0)
	gs._on_lap(race.player, 1, 30.0)
	check_eq(gs.best_lap_ms(), 0, "kids lap never becomes the record ghost")
	check(not FileAccess.file_exists(gs.ghost_path()), "no ghost file written")
	var res := {"player": {"place": 1, "finished": true}, "records_skipped": true, "unlock_cards": []}
	race.apply_series(res, SaveManager.data, _grant)
	check(String(res.unlock_cards[0].text) == tr("TT_KIDS_NO_RECORD"), "results say no record in kids mode")
	race.queue_free()
	await tree.process_frame
	# Cup with kids controls: the cup config keeps working.
	var cfg := Game.default_race_config()
	var cup := BakuCup.start(SaveManager.data, "havhav", 8)
	BakuCup.apply_config(cfg, cup)
	cfg.kids_auto = true
	cfg.active_seed = int(cfg.seed)
	cfg.event_instance_id = String(cfg.fixed_event_id)
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame
	check(race.kids_mode() and race.auto_drive(), "kids auto-drive in a cup race")
	check_eq(race.racers.size(), 6, "full cup field")


# --- HUD / save --------------------------------------------------------------------

func test_steer_hint_never_overlaps_start() -> void:
	check(not RaceHUD.steer_hint_ready(0.7, "START!", 0.0), "no hint while START! shows")
	check(not RaceHUD.steer_hint_ready(1.2, "", 1.0), "no hint over TURBO START")
	check(not RaceHUD.steer_hint_ready(0.3, "", 0.0), "not in the first moment")
	check(RaceHUD.steer_hint_ready(1.0, "", 0.0), "hint once START! has faded")


func test_save_v5_backward_compatible() -> void:
	check_eq(SaveManager.SAVE_VERSION, 5, "save version 5")
	var v4 := {"version": 4, "currency": 1234, "owned_karts": ["havhav", "posi"], "records": {"seafront_sprint": {"best_lap_ms": 41000}},
		"cup_progress": {"junk": 1}}
	SafeFile.write_json(PROFILE, v4)
	SaveManager.load_profile()
	check_eq(int(SaveManager.data.currency), 1234, "money kept")
	check_eq(SaveManager.owned_karts().size(), 2, "owned karts kept")
	check_eq(int(SaveManager.get_record("seafront_sprint").best_lap_ms), 41000, "records kept")
	check(SaveManager.data.cup_progress.is_empty(), "foreign cup state dropped")
	check(SaveManager.data.has("daily_challenge") and SaveManager.data.has("cup_history"), "new keys added")
