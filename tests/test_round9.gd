extends TestCase
## Round 9 (0.9.1): game feel — turbo start, drift tier sparks, near miss,
## speed effects switch, wall sparks; monotonic kart prices; compact goals.

const PROFILE := "user://test_profile_r9.json"
var _orig := ""
var _win := Vector2i.ZERO
var _fx := true


func before_each() -> void:
	_win = tree.root.size
	_orig = SaveManager.save_path
	SaveManager.save_path = PROFILE
	SafeFile.delete_all(PROFILE)
	SaveManager.load_profile()
	_fx = bool(Settings.get_value("graphics", "speed_effects", true))


func after_each() -> void:
	tree.root.size = _win
	Settings.set_value("graphics", "speed_effects", _fx)
	SafeFile.delete_all(PROFILE)
	SaveManager.save_path = _orig
	SaveManager.load_profile()


func test_turbo_start_window() -> void:
	check_eq(GameFeel.start_result(0.1, true), "perfect", "right on GO")
	check_eq(GameFeel.start_result(GameFeel.START_PERFECT, true), "perfect", "perfect edge")
	check_eq(GameFeel.start_result(0.35, true), "good", "inside window")
	check_eq(GameFeel.start_result(GameFeel.START_WINDOW, true), "good", "window edge")
	check_eq(GameFeel.start_result(0.9, true), "stall", "too early stalls")
	check_eq(GameFeel.start_result(0.1, false), "none", "released before GO")
	check_eq(GameFeel.start_result(-1.0, true), "none", "never pressed")
	check(GameFeel.start_quality("perfect") > GameFeel.start_quality("good"), "perfect is stronger")
	check_eq(GameFeel.start_quality("stall"), 0.0, "stall gives nothing")
	check_eq(RaceManager.START_BOOST_WINDOW, GameFeel.START_WINDOW, "race uses the same window")


func test_drift_tier_colours_and_boost() -> void:
	var seen := {}
	for t in 4:
		seen[GameFeel.tier_color(t).to_html()] = true
	check_eq(seen.size(), 4, "each tier its own colour")
	check(GameFeel.tier_color(1).b > GameFeel.tier_color(1).r, "tier 1 blue")
	check(GameFeel.tier_color(2).r > GameFeel.tier_color(2).b, "tier 2 orange")
	check(GameFeel.tier_color(3).r > 0.8 and GameFeel.tier_color(3).b > 0.8, "tier 3 pink/purple")
	check_eq(GameFeel.tier_color(9), GameFeel.tier_color(3), "clamped")
	var st := KartStats.new()
	var prev := 0.0
	for t in [1, 2, 3]:
		var b := GameFeel.drift_boost(st, t)
		check(float(b.strength) > prev, "tier %d boost stronger" % t)
		prev = float(b.strength)
	check_eq(float(GameFeel.drift_boost(st, 1).strength), st.boost_strength, "tier 1 = base boost")


func test_near_miss_detection() -> void:
	check(GameFeel.is_near_miss(-0.5, 0.3, 1.2, 0.9, false), "close fast pass")
	check(not GameFeel.is_near_miss(-0.5, 0.3, 3.5, 0.9, false), "too far sideways")
	check(not GameFeel.is_near_miss(-0.5, 0.3, 1.2, 0.4, false), "too slow")
	check(not GameFeel.is_near_miss(-0.5, 0.3, 1.2, 0.9, true), "contact is not a near miss")
	check(not GameFeel.is_near_miss(0.2, 0.6, 1.2, 0.9, false), "already ahead")
	check(not GameFeel.is_near_miss(-40.0, 30.0, 0.0, 0.9, false), "lap wrap jump ignored")
	var t := Economy.Tally.new()
	check_eq(t.add("near_miss"), Economy.NEAR_MISS, "near miss pays")
	t.total = Economy.DRIVING_CAP
	check_eq(t.add("near_miss"), 0, "inside the driving cap")


func test_near_miss_in_race() -> void:
	var cfg := Game.default_race_config()
	cfg.laps = 1
	cfg.ai_count = 1
	Game.race_config = cfg
	var race: RaceManager = load("res://scripts/racing/race_manager.gd").new()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame
	var pops := [0]
	race.near_miss.connect(func(_k): pops[0] += 1)
	race.state = RaceManager.RaceState.RACING
	race.race_time = 10.0
	var p := race.player
	var ai: RaceManager.Racer = race.racers[0] if race.racers[0] != p else race.racers[1]
	p.kart.speed = p.kart.stats.top_speed
	p.tracker.lateral = 0.0
	ai.tracker.lateral = 1.3
	ai.kart.global_position = p.kart.global_position + Vector3(0, 0, 50)
	p.tracker.race_distance = 100.0
	ai.tracker.race_distance = 100.5
	race._tick_near_miss(0.016)
	p.tracker.race_distance = 101.0
	race._tick_near_miss(0.016)
	check_eq(pops[0], 1, "near miss fired")
	check_eq(race.near_misses, 1, "counted")
	check_eq(int(race.earn.counts.get("near_miss", 0)), 1, "paid as driving income")
	p.tracker.race_distance = 99.0
	race._tick_near_miss(0.016)
	p.tracker.race_distance = 102.0
	race._tick_near_miss(0.016)
	check_eq(pops[0], 1, "cooldown blocks spam")
	# Wall sparks + drift tier burst on the player kart.
	var fx: KartEffects = p.kart.get_node("Visual").effects
	var w0 := fx.wall_bursts
	p.kart.wall_hit.emit(0.8)
	check_eq(fx.wall_bursts, w0 + 1, "wall hit sparks")
	var d0 := fx.drift_bursts
	p.kart.drift_boost.emit(3, true)
	check_eq(fx.drift_bursts, d0 + 1, "drift release burst")
	check_eq(fx.boost_burst.color, GameFeel.tier_color(3), "burst in tier colour")
	race.queue_free()
	await tree.process_frame


func test_speed_effects_toggle() -> void:
	Settings.set_value("graphics", "speed_effects", true)
	check(GameFeel.speed_fx_enabled(), "on by default")
	Settings.set_value("graphics", "speed_effects", false)
	check(not GameFeel.speed_fx_enabled(), "switch turns them off")
	check(Settings.defaults().graphics.has("speed_effects"), "in defaults")
	var host := Control.new()
	tree.root.add_child(host)
	var sm: Node = load("res://scripts/ui/settings_menu.gd").new()
	host.add_child(sm)
	await tree.process_frame
	await tree.process_frame
	sm._show_tab(0)
	await tree.process_frame
	check(_find_text(sm, tr("SET_SPEED_FX")), "settings shows the switch")
	host.queue_free()
	await tree.process_frame


func _find_text(n: Node, t: String) -> bool:
	if n is Label and (n as Label).text == t:
		return true
	for c in n.get_children():
		if _find_text(c, t):
			return true
	return false


func test_prices_monotonic() -> void:
	var prev := 0
	for id in KartShop.ORDER:
		check(KartShop.price(id) > prev, "%s costs more than the one before" % id)
		prev = KartShop.price(id)
	check_eq(KartShop.ORDER[-1], "yaska", "Yaska last")
	var total := 0
	for id in KartShop.ORDER:
		total += KartShop.price(id)
	check_eq(total, 6400, "same total progression")


func test_results_goal_chips_compact() -> void:
	for sz in [Vector2(1100, 720), Vector2(1280, 720), Vector2(1560, 720), Vector2(1600, 720), Vector2(1280, 960)]:
		tree.root.size = Vector2i(sz)
		var host := Control.new()
		host.size = sz
		tree.root.add_child(host)
		var rs := ResultsScreen.new()
		host.add_child(rs)
		rs.setup(null)
		rs.size = sz
		var rows: Array = []
		for i in 6:
			rows.append({"place": i + 1, "name": "R%d" % i, "is_player": i == 3, "finished": true, "time": 90.0, "best_lap": 30.0,
				"estimated": 0.0, "paint": Color.RED, "kart": "posi"})
		rs.show_results({"rows": rows, "player": rows[3], "reward": 180, "stars": 3, "unlocks": [],
			"unlock_cards": [{"icon": "star", "text": "✓ 2 rəqibi keç"}, {"icon": "trophy", "text": "1 yarışı bitir"}, {"icon": "trophy", "text": "Dənizkənarı: sürətli yarışı bitir"}],
			"next_goals": [{"kind": "drift", "target": 5, "reward": 30}, {"kind": "clean_lap", "target": 2, "reward": 40}, {"kind": "top3", "target": 1, "reward": 40}],
			"improved": {}, "event_instance_id": "x"})
		for k in 4:
			await tree.process_frame
		var area := Rect2(Vector2.ZERO, sz)
		var gr: Rect2 = rs.goals_box.get_parent().get_global_rect()
		check(area.encloses(gr), "goals on screen at %s" % sz)
		check(gr.size.y <= 110.0, "one compact row at %s (h=%.0f)" % [sz, gr.size.y])
		check(not gr.intersects(rs.panel.get_global_rect()), "no overlap with panel at %s" % sz)
		for b in [rs.retry_btn, rs.menu_btn]:
			check(not gr.intersects(b.get_global_rect()), "no overlap with buttons at %s" % sz)
			check(area.encloses(b.get_global_rect()), "buttons on screen at %s" % sz)
		for chip in rs.goals_row.get_children():
			var r: Rect2 = chip.get_global_rect()
			check(r.size.y <= 52.0, "chip one line at %s" % sz)
		host.queue_free()
		await tree.process_frame
