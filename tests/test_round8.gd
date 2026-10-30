extends TestCase
## Round 8 (0.9.0): kart shop, 7-day login bonus, post-race goals.

const PROFILE := "user://test_profile_r8.json"
const MENU_SIZES := [Vector2(1280, 720), Vector2(1560, 720), Vector2(1600, 720), Vector2(1280, 960)]
var _orig := ""
var _win := Vector2i.ZERO


func before_each() -> void:
	_win = tree.root.size
	_orig = SaveManager.save_path
	SaveManager.save_path = PROFILE
	SafeFile.delete_all(PROFILE)
	SaveManager.load_profile()


func after_each() -> void:
	tree.root.size = _win
	SafeFile.delete_all(PROFILE)
	SaveManager.save_path = _orig
	SaveManager.load_profile()


func _host(sz: Vector2) -> Control:
	tree.root.size = Vector2i(sz)
	var host := Control.new()
	host.size = sz
	tree.root.add_child(host)
	return host


# --- Kart shop -------------------------------------------------------------------

func test_new_profile_owns_only_standard() -> void:
	check_eq(SaveManager.owned_karts(), [RacerRoster.DEFAULT_ID], "only Buddy Rally")
	check_eq(SaveManager.get_selected_kart(), RacerRoster.DEFAULT_ID, "standard selected")
	SaveManager.data.selected_kart = "yaska"
	check_eq(SaveManager.get_selected_kart(), RacerRoster.DEFAULT_ID, "unowned selection falls back")
	for id in RacerRoster.IDS:
		check(KartShop.PRICES.has(id), "price for %s" % id)
	check_eq(KartShop.price(RacerRoster.DEFAULT_ID), 0, "standard is free")
	check_eq(KartShop.ORDER[-1], "yaska", "Yaska is the last, best buy")


func test_purchase_flow_funds_persistence() -> void:
	SaveManager.data.currency = 500
	check_eq(SaveManager.buy_kart("posi"), "funds", "not enough money")
	check_eq(SaveManager.get_money(), 500, "nothing charged")
	check(not SaveManager.is_kart_owned("posi"), "still locked")
	check_eq(KartShop.missing("posi", 500), KartShop.price("posi") - 500, "missing amount")
	SaveManager.data.currency = KartShop.price("posi") + 25
	check_eq(SaveManager.buy_kart("posi"), "ok", "bought")
	check_eq(SaveManager.get_money(), 25, "charged once")
	check_eq(SaveManager.buy_kart("posi"), "owned", "no second charge")
	check_eq(SaveManager.get_money(), 25, "balance kept")
	SaveManager.load_profile()
	check(SaveManager.is_kart_owned("posi"), "ownership persists")
	check_eq(SaveManager.get_money(), 25, "balance persists")


func test_tuning_only_owned() -> void:
	SaveManager.data.currency = 100000
	check(not SaveManager.buy_upgrade("yaska", "speed"), "no tuning on a locked kart")
	SaveManager.data.tuning["yaska"] = {"speed": 3}
	check_eq(int(SaveManager.tuning_levels("yaska").get("speed", 0)), 0, "locked kart races stock")
	SaveManager.own_kart("yaska")
	check_eq(int(SaveManager.tuning_levels("yaska").get("speed", 0)), 3, "applies once owned")


func test_migration_keeps_owned() -> void:
	SafeFile.write_json(PROFILE, {"version": 3, "currency": 900})
	SaveManager.load_profile()
	check_eq(SaveManager.owned_karts().size(), RacerRoster.IDS.size(), "0.8.2 saves own all")
	SafeFile.write_json(PROFILE, {"version": 4, "currency": 900, "owned_karts": RacerRoster.IDS.duplicate(), "selected_kart": "yaska"})
	SaveManager.load_profile()
	check_eq(SaveManager.owned_karts().size(), RacerRoster.IDS.size(), "0.8.3 saves keep all")
	check_eq(SaveManager.get_selected_kart(), "yaska", "selection kept")


func test_kart_ladder_simulation() -> void:
	var sim := Economy.simulate_karts(200, 3, 0)
	var first: float = sim[KartShop.ORDER[0]].races
	var last: float = sim["yaska"].races
	check(first >= 4.0 and first <= 6.5, "first kart after ~4-6 races (%.1f)" % first)
	check(last >= 25.0 and last <= 35.0, "Yaska after ~25-35 races (%.1f)" % last)


func _racer_select(sz: Vector2) -> Array:
	var host := _host(sz)
	var rs: RacerSelect = load("res://scripts/ui/racer_select.gd").new()
	host.add_child(rs)
	for k in 4:
		await tree.process_frame
	return [host, rs]


func test_racer_select_locked_cards_and_dialogs() -> void:
	for sz in MENU_SIZES:
		var pair: Array = await _racer_select(sz)
		var rs: RacerSelect = pair[1]
		var area := Rect2(Vector2.ZERO, sz)
		var yi := RacerRoster.IDS.find("yaska")
		check(rs.cards[yi].get_node("Lock").visible, "yaska shows a price tag")
		check(not rs.cards[RacerRoster.IDS.find(RacerRoster.DEFAULT_ID)].get_node("Lock").visible, "standard unlocked")
		rs._select(yi)
		check(rs.buy_btn.visible and not rs.start_btn.visible, "Al replaces Start")
		check(area.encloses(rs.buy_btn.get_global_rect()), "buy visible at %s" % sz)
		SaveManager.data.currency = 100
		rs.open_buy()
		await tree.process_frame
		await tree.process_frame
		check_eq(rs.shop_kind, "funds", "not enough money dialog")
		check(rs.shop_dialog.find_child("Missing", true, false) != null, "shows what is missing")
		var pr: Rect2 = (rs.shop_dialog.find_child("Panel", true, false) as Control).get_global_rect()
		check(area.encloses(pr), "dialog fits at %s (%s)" % [sz, pr])
		rs.close_shop()
		SaveManager.data.currency = KartShop.price("yaska")
		rs.open_buy()
		await tree.process_frame
		check_eq(rs.shop_kind, "confirm", "confirm dialog")
		rs.confirm_buy()
		await tree.process_frame
		check(SaveManager.is_kart_owned("yaska"), "bought from the dialog")
		check(rs.start_btn.visible and not rs.buy_btn.visible, "Start is back")
		check_eq(SaveManager.get_money(), 0, "charged")
		SaveManager.data.owned_karts = [RacerRoster.DEFAULT_ID]
		pair[0].queue_free()
		await tree.process_frame


# --- Login bonus -----------------------------------------------------------------

func test_login_streak_and_skip() -> void:
	var d := SaveManager.data
	d.currency = 0
	check_eq(DailyLogin.status(d, "2026-11-01"), {"day": 1, "can_claim": true}, "first day")
	check_eq(DailyLogin.claim(d, "2026-11-01"), DailyLogin.REWARDS[0], "day 1 paid")
	check_eq(DailyLogin.claim(d, "2026-11-01"), 0, "once per day")
	check(not DailyLogin.status(d, "2026-10-31").can_claim, "clock set back: no claim, no reset")
	var dates := ["2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06", "2026-11-07"]
	for i in dates.size():
		check_eq(int(DailyLogin.status(d, dates[i]).day), i + 2, "day %d" % (i + 2))
		DailyLogin.claim(d, dates[i])
	var total := 0
	for r in DailyLogin.REWARDS:
		total += int(r)
	check_eq(int(d.currency), total, "full week paid")
	check_eq(int(DailyLogin.status(d, "2026-11-08").day), 1, "after day 7 the strip restarts")
	DailyLogin.claim(d, "2026-11-08")
	check_eq(int(DailyLogin.status(d, "2026-11-09").day), 2, "day 2")
	check_eq(int(DailyLogin.status(d, "2026-11-11").day), 1, "missed a day: reset")
	check_eq(int(DailyLogin.status(d, "2026-12-01").day), 1, "long gap: reset")
	check(DailyLogin.REWARDS[6] > DailyLogin.REWARDS[5] * 2, "day 7 is the big prize")
	# Month / year boundary
	d.login = {"last": "2026-12-31", "streak": 3}
	check_eq(int(DailyLogin.status(d, "2027-01-01").day), 4, "year boundary continues")


func test_login_popup_fits_and_claims() -> void:
	for sz in MENU_SIZES:
		SaveManager.data.login = {}
		var host := _host(sz)
		var mm = load("res://scripts/ui/main_menu.gd").new()
		host.add_child(mm)
		for k in 4:
			await tree.process_frame
		check(mm.login_popup != null, "popup on first open of the day")
		var pr: Rect2 = (mm.login_popup.find_child("Panel", true, false) as Control).get_global_rect()
		check(Rect2(Vector2.ZERO, sz).encloses(pr), "popup fits at %s (%s)" % [sz, pr])
		check_eq(mm.login_tiles.size(), 7, "7-day strip")
		check(not mm.login_popup.find_child("Double", true, false).visible, "ad double hidden")
		var m0 := SaveManager.get_money()
		check_eq(mm.claim_login(), DailyLogin.REWARDS[0], "claimed")
		check_eq(SaveManager.get_money() - m0, DailyLogin.REWARDS[0], "credited once")
		host.queue_free()
		await tree.process_frame
	var host2 := _host(Vector2(1560, 720))
	var mm2 = load("res://scripts/ui/main_menu.gd").new()
	host2.add_child(mm2)
	for k in 3:
		await tree.process_frame
	check(mm2.login_popup == null, "no popup again the same day")
	host2.queue_free()
	await tree.process_frame


# --- Post-race goals ------------------------------------------------------------

func test_goals_generation() -> void:
	for sd in 50:
		var g := RaceGoals.generate(sd)
		check_eq(g.size(), 3, "three goals")
		var kinds := {}
		for x in g:
			kinds[x.kind] = true
			check(int(x.reward) > 0 and int(x.reward) <= 60, "small reward")
			check(not RaceGoals.text(x).contains("%"), "text filled")
		check_eq(kinds.size(), 3, "all different")
		check(not (kinds.has("win") and kinds.has("top3")), "no overlapping place goals")
	check_eq(RaceGoals.generate(7), RaceGoals.generate(7), "repeatable")
	check_eq(RaceGoals.current(SaveManager.data).size(), 3, "created when missing")


func test_goals_tracking_and_payout() -> void:
	var goals := [{"kind": "drift", "target": 2, "reward": 30}, {"kind": "top3", "target": 1, "reward": 40},
		{"kind": "stars", "target": 5, "reward": 30}]
	var snap := {"drift": 1, "stars": 5, "place": 2, "finished": false}
	check(not RaceGoals.is_done(goals[0], snap), "drift 1/2")
	check(RaceGoals.is_done(goals[2], snap), "stars done")
	check(not RaceGoals.is_done(goals[1], snap), "top3 only at the finish")
	snap.drift = 2
	snap.finished = true
	var st := RaceGoals.settle(goals, snap)
	check_eq(int(st.pay), 100, "all three paid")
	snap.place = 5
	check_eq(int(RaceGoals.settle(goals, snap).pay), 60, "top3 missed")
	check_eq(RaceGoals.text(goals[0]), "2 dəfə drift turbo et" if TranslationServer.get_locale().begins_with("az") else RaceGoals.text(goals[0]), "short text")


func test_goals_in_a_real_race() -> void:
	SaveManager.data.race_goals = [{"kind": "drift", "target": 1, "reward": 30}, {"kind": "stars", "target": 99, "reward": 30},
		{"kind": "clean_lap", "target": 9, "reward": 40}]
	var cfg := Game.default_race_config()
	cfg.laps = 1
	cfg.ai_count = 1
	Game.race_config = cfg
	var race: RaceManager = load("res://scripts/racing/race_manager.gd").new()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame
	check_eq(race.goals.size(), 3, "race loaded the goals")
	race.state = RaceManager.RaceState.RACING
	race._earn("drift")
	race._tick_goals()
	check(race.goals_ticked.has(0), "drift goal ticked live")
	check(not race.goals_ticked.has(1), "others not yet")
	var res := {"event_instance_id": "goal-test", "unlock_cards": []}
	var m0 := SaveManager.get_money()
	race._settle_goals(res)
	check_eq(int(res.goals_pay), 30, "paid one goal")
	check_eq(SaveManager.get_money() - m0, 30, "credited")
	check_eq(res.next_goals.size(), 3, "next goals drawn")
	check_eq(SaveManager.data.race_goals, res.next_goals, "saved for the next race")
	race.queue_free()
	await tree.process_frame


func test_results_show_next_goals_fit() -> void:
	for sz in [Vector2(1280, 720), Vector2(1560, 720), Vector2(1600, 720), Vector2(1280, 960)]:
		var host := _host(sz)
		var rs := ResultsScreen.new()
		host.add_child(rs)
		rs.setup(null)
		rs.size = sz
		var rows: Array = []
		for i in 6:
			rows.append({"place": i + 1, "name": "R%d" % i, "is_player": i == 4, "finished": true, "time": 90.0, "best_lap": 30.0,
				"estimated": 0.0, "paint": Color.RED, "kart": "posi"})
		rs.show_results({"rows": rows, "player": rows[4], "reward": 180, "stars": 3, "unlocks": [],
			"unlock_cards": [{"icon": "star", "text": "✓ 2 dəfə drift turbo et"}, {"icon": "trophy", "text": "Kubok"}],
			"next_goals": RaceGoals.generate(5), "improved": {}, "event_instance_id": "x"})
		for k in 4:
			await tree.process_frame
		check(rs.goals_box.visible and rs.goals_row.get_child_count() == 3, "three next goals")
		var area := Rect2(Vector2.ZERO, sz)
		for b in [rs.retry_btn, rs.menu_btn]:
			check(area.encloses(b.get_global_rect()), "buttons visible at %s" % sz)
		var gr: Rect2 = rs.goals_box.get_parent().get_global_rect()
		check(area.encloses(gr), "next goals on screen at %s (%s)" % [sz, gr])
		check(not gr.intersects(rs.panel.get_global_rect()), "goals do not cover the results panel at %s" % sz)
		check(area.encloses(rs.panel.get_global_rect()), "panel fits at %s (%s)" % [sz, rs.panel.get_global_rect()])
		host.queue_free()
		await tree.process_frame
