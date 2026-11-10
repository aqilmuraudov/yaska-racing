extends TestCase
## Round 7 (0.8.3): game-style results, rewards tabs, main menu garage entry,
## layout fit at 16:9, 19.5:9, 20:9 and 4:3, owned_karts save field.

const PROFILE := "user://test_profile_r7.json"
const SIZES := [Vector2(1280, 720), Vector2(1560, 720), Vector2(1600, 720), Vector2(1280, 960), Vector2(1100, 720)]
var _orig := ""


## Menus: with stretch "expand" the game view is never narrower than 1280 at
## 720 high, so 1100x720 only applies to the results overlay.
const MENU_SIZES := [Vector2(1280, 720), Vector2(1560, 720), Vector2(1600, 720), Vector2(1280, 960)]
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


func _rows(player_place: int) -> Array:
	var rows: Array = []
	for i in 6:
		rows.append({"place": i + 1, "name": "Racer %d" % i, "is_player": i + 1 == player_place, "finished": i < 3,
			"time": 90.0 + i, "best_lap": 30.0, "estimated": 0.0 if i < 3 else 99.0, "paint": Color.RED,
			"kart": RacerRoster.IDS[i % RacerRoster.IDS.size()]})
	return rows


func _res(player_place: int, cards := 0) -> Dictionary:
	var rows := _rows(player_place)
	var uc: Array = []
	for i in cards:
		uc.append({"icon": "trophy", "text": "Kubok %d" % i})
	return {"rows": rows, "player": rows[player_place - 1], "reward": 215,
		"payout": {"place": 130, "driving": 85, "record": 0, "total": 215},
		"stars": 4, "stars_total": 0, "stars_added": 4, "unlocks": [], "unlock_cards": uc,
		"improved": {"lap": true, "race": true}, "event_instance_id": "r7"}


func _host(sz: Vector2) -> Control:
	tree.root.size = Vector2i(sz)
	var host := Control.new()
	host.size = sz
	tree.root.add_child(host)
	return host


# --- Results -------------------------------------------------------------------

func test_pick_rows_top3_plus_player() -> void:
	var r := ResultsScreen.pick_rows(_rows(5))
	check_eq(r.size(), 4, "top three plus player")
	check(bool(r[3].is_player), "player row last")
	check_eq(ResultsScreen.pick_rows(_rows(2)).size(), 3, "no extra row on the podium")


func test_make_cards_max_three() -> void:
	check_eq(ResultsScreen.make_cards(_res(1, 0)).size(), 0, "no cards when nothing unlocked")
	check_eq(ResultsScreen.make_cards(_res(1, 2)).size(), 2, "two cards")
	var c := ResultsScreen.make_cards(_res(1, 7))
	check_eq(c.size(), 3, "capped at three")
	check(bool(c[2].get("more", false)) and String(c[2].text) == "+5", "last card says +5")
	check_eq(ResultsScreen.short_text("Kubok: 5 yarış (+30 qəpik)"), "5 yarış", "short text")


func test_results_fit_and_count_up() -> void:
	for place in [1, 4]:
		for sz in SIZES:
			var host := _host(sz)
			var rs := ResultsScreen.new()
			host.add_child(rs)
			rs.setup(null)
			rs.size = sz
			rs.show_results(_res(place, 5))
			for k in 4:
				await tree.process_frame
			var area := Rect2(Vector2.ZERO, sz)
			for b in [rs.retry_btn, rs.menu_btn]:
				check(area.encloses(b.get_global_rect()), "button visible at %s place %d" % [sz, place])
			check(area.encloses(rs.panel.get_global_rect()), "panel inside at %s" % sz)
			check(rs.cards_row.get_child_count() <= 3, "≤3 cards")
			check_eq(rs.shown_rows.size(), 3 if place <= 3 else 4, "rows shown")
			check(rs.record_badge.visible, "record badge shown")
			rs.finish_count()
			check_eq(rs.money_shown(), 215, "count-up ends at the payout")
			host.queue_free()
			await tree.process_frame


# --- Rewards ---------------------------------------------------------------------

func test_daily_claim_single_credit() -> void:
	var data := SaveManager.data
	Progression.ensure_daily(data, "2026-10-30")
	data.daily = {"day": "2026-10-30", "goals": [Progression.DAILY_POOL[0].id], "progress": {}, "done": []}
	var g: Dictionary = Progression.daily_goal(data.daily.goals[0])
	var money0 := int(data.currency)
	var guard := 0
	while not (g.id in data.daily.done) and guard < 40:
		guard += 1
		var ev := {"mode": "quick", "finished": true, "place": 1, "track_id": "seafront_sprint", "day": "2026-10-30",
			"drift_boosts": 10, "stars": 10, "coins": 0}
		Progression.on_event(data, ev)
	check(g.id in data.daily.done, "goal completed")
	var credited := int(data.currency) - money0
	check(credited >= Progression.DAILY_COINS, "daily reward paid")
	var before := int(data.currency)
	var d2: Dictionary = data.daily.duplicate(true)
	# A further event does not pay the same daily goal again.
	Progression.on_event(data, {"mode": "quick", "finished": false, "place": 6, "track_id": "", "day": "2026-10-30", "coins": 0})
	check_eq(int(data.currency), before, "no double credit")
	check_eq(data.daily.done.count(g.id), 1, "claimed once")
	check(d2.done.has(g.id), "claimed state kept")


func test_trophy_groups_cover_all() -> void:
	var n := 0
	for grp in RewardsScreen.trophy_groups():
		n += grp.tiers.size()
		check(grp.tiers.size() >= 1, "group has tiers")
	check_eq(n, Progression.trophies().size(), "every trophy in a group")


func test_rewards_screen_tabs_fit() -> void:
	for sz in MENU_SIZES:
		var host := _host(sz)
		var scr: MenuScreen = load("res://scripts/ui/rewards_screen.gd").new()
		host.add_child(scr)
		for k in 4:
			await tree.process_frame
		check_eq(scr.tab_buttons.size(), 3, "three tabs (0.13.0: + Albom)")
		check_eq(scr.daily_cards.size(), 3, "three daily cards")
		check(scr.trophy_cards.size() >= 1, "trophy badges")
		var area := Rect2(Vector2.ZERO, sz)
		for b in scr.tab_buttons:
			check(area.encloses(b.get_global_rect()), "tab visible at %s (%s)" % [sz, b.get_global_rect()])
		scr.show_tab(1)
		scr.show_detail(RewardsScreen.trophy_groups()[0])
		await tree.process_frame
		check(scr.detail != null and scr.detail.visible, "trophy detail opens")
		host.queue_free()
		await tree.process_frame


# --- Main menu -------------------------------------------------------------------

func test_main_menu_order_fit_and_garage() -> void:
	for sz in MENU_SIZES:
		var host := _host(sz)
		var mm: MenuScreen = load("res://scripts/ui/main_menu.gd").new()
		host.add_child(mm)
		for k in 4:
			await tree.process_frame
		check_eq(mm.buttons.size(), 4, "four menu buttons (0.10.2: credits moved to Settings)")
		check_eq(mm.buttons[1], mm.garage_btn, "garage second")
		var area := Rect2(Vector2.ZERO, sz)
		var h := -1.0
		for b in mm.buttons:
			var r: Rect2 = b.get_global_rect()
			check(area.encloses(r), "%s visible at %s (%s)" % [b.text, sz, r])
			if h < 0.0:
				h = b.size.y
			check_near(b.size.y, h, 1.0, "equal button height")
		check(area.encloses(mm.money_chip.get_global_rect()), "money chip visible at %s (%s)" % [sz, mm.money_chip.get_global_rect()])
		host.queue_free()
		await tree.process_frame
	# Garage entry: back goes to the main menu (scene change blocked here).
	var mm2: MenuScreen = load("res://scripts/ui/main_menu.gd").new()
	var host2 := _host(Vector2(1560, 720))
	host2.add_child(mm2)
	await tree.process_frame
	var was: bool = Game._changing
	var back0 = Game.garage_back
	Game._changing = true
	var starter0 = SaveManager.data.get("starter_chosen", true)
	SaveManager.data.starter_chosen = true # 0.17.4: the garage needs a starter kart
	mm2.open_garage()
	SaveManager.data.starter_chosen = starter0
	Game._changing = was
	check_eq(Game.garage_back, Game.State.MAIN_MENU, "garage returns to the main menu")
	check_eq(String(Game.race_config.kart_id), SaveManager.get_selected_kart(), "selected racer opened")
	Game.garage_back = back0
	host2.queue_free()
	await tree.process_frame


# --- Owned karts -----------------------------------------------------------------

func test_owned_karts_default_and_migration() -> void:
	check_eq(SaveManager.owned_karts(), [RacerRoster.DEFAULT_ID], "fresh profile owns the standard kart")
	check(SaveManager.own_kart("yaska"), "own a kart")
	check(SaveManager.is_kart_owned("yaska"), "owned after")
	check(not SaveManager.own_kart("yaska"), "no duplicate")
	var old := {"version": 3, "currency": 500, "selected_kart": "posi"}
	SafeFile.write_json(PROFILE, old)
	SaveManager.load_profile()
	# 0.14.2: the free "own every kart" of the v4 migration is taken back (v6).
	check_eq(SaveManager.owned_karts(), [RacerRoster.DEFAULT_ID, "posi"], "old saves keep the starter and the raced kart")
	check_eq(int(SaveManager.data.currency), 500, "balance kept")
	check(SaveManager.save_profile(), "saved")
	check_eq(int(SaveManager.data.version), SaveManager.SAVE_VERSION, "migrated to the current save version")
