extends TestCase
## 0.7.0 rewards: early rewards come fast, later ones need many races, each
## event counts once, daily goals and old saves stay compatible.

const TEST_PROFILE := "user://test_profile_progression.json"
var _orig_path := ""


func before_each() -> void:
	_orig_path = SaveManager.save_path
	SaveManager.save_path = TEST_PROFILE
	SafeFile.delete_all(TEST_PROFILE)
	SaveManager.load_profile()


func after_each() -> void:
	SafeFile.delete_all(TEST_PROFILE)
	SaveManager.save_path = _orig_path
	SaveManager.load_profile()


func _race(id: String, place: int, stars := 6, boosts := 2, mode := "quick", coins := 60) -> Dictionary:
	return SaveManager.apply_progression(id, {"mode": mode, "finished": true, "place": place, "stars": stars,
		"drift_boosts": boosts, "coins": coins, "track_id": "seafront_sprint", "record": false, "day": "2026-10-29"})


func test_first_race_gives_quick_rewards() -> void:
	var out := _race("r1", 2)
	check(out.unlocks.size() >= 3, "first race unlocks several rewards (%d)" % out.unlocks.size())
	check(out.coins > 0, "trophies pay coins (%d)" % out.coins)
	check("races_1" in SaveManager.data.trophies, "first-race trophy")
	check("podiums_1" in SaveManager.data.trophies, "first-podium trophy")
	check("seafront_sprint:quick_podium_1" in SaveManager.data.trophies, "per-track trophy")
	check(KartPaints.cost(1) <= 6, "first paint after about one race")
	check_eq(_race("r1", 1).unlocks.size(), 0, "the same event never counts twice")


func test_long_term_rewards_need_many_races() -> void:
	var total := Progression.trophies().size()
	check(total >= 30, "many trophies (%d)" % total)
	check(KartPaints.count() >= 12, "12 paints")
	check(Progression.PARTS.size() >= 6 and Progression.TITLES.size() >= 8, "parts and titles")
	for i in 10:
		_race("x%d" % i, 4, 6, 3)
	var got: int = SaveManager.data.trophies.size()
	check(got < total * 0.6, "ten races do not unlock most trophies (%d/%d)" % [got, total])
	check(not Progression.part_unlocked(SaveManager.data, Progression.PARTS.size() - 1), "last part still locked")
	check(Progression.next_title(Progression.stat(SaveManager.data, "stars")).size() > 0, "more titles to earn")


func test_daily_goals_are_optional_and_pay_once() -> void:
	var d := SaveManager.data
	Progression.ensure_daily(d, "2026-10-29")
	check_eq(d.daily.goals.size(), 3, "three goals a day")
	var goals: Array = d.daily.goals.duplicate()
	Progression.ensure_daily(d, "2026-10-29")
	check_eq(d.daily.goals, goals, "same day keeps the same goals")
	for i in 6:
		_race("d%d" % i, 1, 10, 4)
	_race("dt", 1, 4, 2, "time_trial", 15)
	check_eq(d.daily.done.size(), 3, "all goals done after a few races")
	var lt := int(d.lifetime.daily_done)
	_race("d9", 1)
	check_eq(int(d.lifetime.daily_done), lt, "goals pay only once a day")
	Progression.ensure_daily(d, "2026-10-30")
	check_eq(d.daily.done.size(), 0, "new day, new goals")


func test_old_save_is_compatible() -> void:
	SafeFile.write_json(TEST_PROFILE, {"version": 1, "currency": 500, "stars": 42, "selected_kart": "posi",
		"paints": {"posi": 2}, "stats": {"races": 12, "wins": 3, "podiums": 6}, "reward_ledger": [], "records": {}})
	SaveManager.load_profile()
	var d := SaveManager.data
	check_eq(int(d.currency), 500 * Money.COINS_TO_QEPIK, "old coins converted to qəpik (1 coin = 2 qəpik)")
	check_eq(SaveManager.get_stars(), 42, "stars kept")
	check_eq(SaveManager.get_paint("posi"), 2, "paint choice kept")
	check_eq(int(d.lifetime.stars), 42, "lifetime stars seeded")
	check_eq(int(d.lifetime.races), 12, "lifetime races seeded")
	check(Progression.part_unlocked(d, 0), "old coins count towards parts")
	var out := _race("o1", 5)
	check("races_5" in d.trophies and "wins_1" in d.trophies, "old progress earns its trophies")
	check(out.unlocks.size() > 0, "and they are announced")
	SaveManager.load_profile()
	check("races_5" in SaveManager.data.trophies, "trophies survive a reload")
	check_eq(int(SaveManager.data.track_stats.get("seafront_sprint:quick_finish", 0)), 1, "per-track counters survive a reload")
