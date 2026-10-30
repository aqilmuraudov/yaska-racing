extends TestCase
## Racer packages: exact names, rating table, ratings → real handling,
## fair collision, selection → race, AI roster, persistence.

const EXPECTED := {
	"posi": ["Posi", "panda", "Bamboo Sprint", [6, 10, 7, 6, 6]],
	"bicok": ["Bicok", "fox", "Amber Dash", [9, 6, 8, 6, 6]],
	"leloyun": ["Ləlöyün", "rabbit", "Hop Rocket", [7, 9, 9, 5, 5]],
	"mestan": ["Məstan", "cat", "Velvet Slide", [7, 6, 7, 10, 5]],
	"havhav": ["HavHav", "dog", "Buddy Rally", [7, 7, 7, 7, 7]],
	"cepis": ["Çəpiş", "lamb", "Cloud Booster", [8, 5, 5, 7, 10]],
	"yaska": ["Yaska", "girl", "Yaska Star", [10, 9, 10, 9, 8]],
}


func test_roster_names_species_karts_and_ratings() -> void:
	check_eq(RacerRoster.IDS.size(), 7, "seven racers")
	for id in EXPECTED.keys():
		var d := RacerRoster.get_def(id)
		var e: Array = EXPECTED[id]
		check_eq(d.display_name, e[0], "%s name" % id)
		check_eq(d.species, e[1], "%s species" % id)
		check_eq(d.kart_name, e[2], "%s kart" % id)
		check_eq([d.top_speed, d.acceleration, d.handling, d.drift, d.boost], e[3], "%s ratings" % id)
		check(d.kart_style != "" and tr(d.specialty_key) != d.specialty_key, "%s has kart style and translated specialty" % id)


func test_karts_have_distinct_styles() -> void:
	var styles := {}
	for d in RacerRoster.all():
		styles[d.kart_style] = true
	check_eq(styles.size(), 7, "every racer has its own kart body")


func test_ratings_drive_real_handling() -> void:
	var s := {}
	for id in RacerRoster.IDS:
		s[id] = KartFactory.load_stats(id)
	check(s.bicok.top_speed > s.posi.top_speed, "Bicok (9) faster top speed than Posi (6)")
	check(s.posi.acceleration > s.cepis.acceleration, "Posi (10) accelerates harder than Çəpiş (5)")
	check(s.leloyun.steer_rate_high > s.cepis.steer_rate_high, "Ləlöyün (9) steers sharper than Çəpiş (5)")
	check(s.mestan.drift_window_start < s.leloyun.drift_window_start, "Məstan (10) has the most forgiving boost window")
	check(s.mestan.drift_overheat_time > s.leloyun.drift_overheat_time, "Məstan holds full meter longer")
	check(s.cepis.boost_strength > s.posi.boost_strength and s.cepis.boost_duration > s.posi.boost_duration, "Çəpiş boosts stronger and longer")
	# Bounded: no value outside its named curve.
	for id in RacerRoster.IDS:
		var st: KartStats = s[id]
		check(st.top_speed >= 26.5 - 0.01 and st.top_speed <= 27.7 + 0.01, "%s top speed within curve" % id)
		check(st.boost_max_bonus <= 11.0 + 0.01, "%s boost cap bounded" % id)


func test_collision_footprint_identical() -> void:
	var sizes := {}
	for id in RacerRoster.IDS:
		var k := KartFactory.create(id, false, 0.0)
		for c in k.get_children():
			if c is CollisionShape3D:
				var cap: CapsuleShape3D = c.shape
				sizes[Vector2(cap.radius, cap.height)] = true
		k.free()
	check_eq(sizes.size(), 1, "same capsule for every racer (cosmetics do not affect collision)")


func test_selected_racer_loads_with_five_distinct_rivals() -> void:
	var cfg := Game.default_race_config()
	cfg.kart_id = "mestan"
	cfg.debug_autopilot = true
	cfg.seed = 5
	cfg.active_seed = 5
	cfg.event_instance_id = "test-racers"
	Game.race_config = cfg
	var race: RaceManager = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame
	var pdef: RacerDefinition = race.player.kart.get_meta("racer")
	check_eq(pdef.id, "mestan", "player drives the selected racer")
	var shown: KartStats = RacerRoster.get_def("mestan").make_stats()
	check_near(race.player.kart.stats.top_speed, shown.top_speed, 0.0001, "race uses the stats the selection screen shows (stock kart)")
	check_near(race.player.kart.stats.acceleration, shown.acceleration, 0.0001, "same acceleration as shown")
	var ids := {}
	for r in race.racers:
		if not r.is_player:
			ids[(r.kart.get_meta("racer") as RacerDefinition).id] = true
	check_eq(ids.size(), 5, "five different rivals")
	check(not ids.has("mestan"), "rivals exclude the player's racer")
	race.queue_free()
	await tree.process_frame


func test_selection_persists_across_reload() -> void:
	var orig := SaveManager.save_path
	var orig_data := SaveManager.data.duplicate(true)
	SaveManager.save_path = "user://test_profile_racers.json"
	SafeFile.delete_all(SaveManager.save_path)
	SaveManager.load_profile()
	SaveManager.own_kart("cepis") # 0.9.0: only owned karts can be selected
	SaveManager.set_selected_kart("cepis")
	SaveManager.data = {}
	SaveManager.load_profile()
	check_eq(SaveManager.get_selected_kart(), "cepis", "selected racer restored after relaunch")
	SaveManager.data.selected_kart = "balanced" # id from the first version
	check_eq(SaveManager.get_selected_kart(), RacerRoster.DEFAULT_ID, "old kart ids migrate to a valid racer")
	SafeFile.delete_all(SaveManager.save_path)
	SaveManager.save_path = orig
	SaveManager.data = orig_data


func test_yaska_is_fastest_and_most_stable() -> void:
	var y := RacerRoster.get_def("yaska")
	for d in RacerRoster.all():
		if d.id != "yaska":
			check(y.top_speed >= d.top_speed and y.handling >= d.handling, "Yaska >= %s in speed and handling" % d.id)
	check(y.make_stats().top_speed > RacerRoster.get_def("bicok").make_stats().top_speed, "Yaska strictly fastest")
