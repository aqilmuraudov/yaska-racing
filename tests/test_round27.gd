extends TestCase
## Round 27 (0.14.2): owner reports - wheels spin too fast, the first lesson
## keeps coming back, every kart could be raced without buying it.

const PROFILE := "user://test_profile_r27.json"
var _orig_profile_path := ""


func before_each() -> void:
	_orig_profile_path = SaveManager.save_path
	SaveManager.save_path = PROFILE
	SafeFile.delete_all(PROFILE)
	SaveManager.load_profile()


func after_each() -> void:
	SafeFile.delete_all(PROFILE)
	SaveManager.save_path = _orig_profile_path
	SaveManager.load_profile()


func test_wheel_spin_is_capped() -> void:
	var kart := KartController.new()
	tree.root.add_child(kart)
	var vis := KartVisual.new()
	kart.add_child(vis)
	vis.setup(kart, RacerRoster.get_def("yaska"), 0.7)
	var w0: float = vis.model.wheel_spinners[2].rotation.x
	kart.speed = 36.0 # ~130 km/h: the true rate would be ~106 rad/s
	for i in 60:
		vis._physics_process(1.0 / 60.0)
	var turned := absf(vis.model.wheel_spinners[2].rotation.x - w0)
	check(turned <= KartVisual.MAX_WHEEL_RATE * 1.01, "one second turns at most the cap (%.1f rad)" % turned)
	check(turned > 10.0, "still clearly spinning (%.1f rad)" % turned)
	kart.free()


func test_lesson_is_remembered_when_it_starts() -> void:
	check(not SaveManager.get_tutorial_flag(LessonDirector.FLAG), "new profile: lesson pending")
	var src := FileAccess.get_file_as_string("res://scripts/racing/lesson_director.gd")
	var at := src.find("SaveManager.set_tutorial_flag(FLAG, true)")
	check(at > src.find("func setup(") and at < src.find("func _build_dots"), "flag written in setup(), not only when all steps are done")
	check(src.find("SaveManager.set_tutorial_flag(FLAG, true)", at + 1) > 0, "and still when the lesson completes")
	SaveManager.set_tutorial_flag(LessonDirector.FLAG, true)
	check(SaveManager.get_tutorial_flag(LessonDirector.FLAG), "remembered in the profile")


func test_free_karts_taken_back_by_v6() -> void:
	SafeFile.write_json(PROFILE, {"version": 5, "currency": 1200, "owned_karts": RacerRoster.IDS.duplicate(),
		"selected_kart": "mestan"})
	SaveManager.load_profile()
	check_eq(SaveManager.owned_karts(), [RacerRoster.DEFAULT_ID, "mestan"], "starter + raced kart kept")
	check_eq(int(SaveManager.data.currency), 1200, "balance untouched")
	check_eq(SaveManager.get_selected_kart(), "mestan", "still races the same kart")
	# A profile that really bought two karts keeps them.
	SafeFile.write_json(PROFILE, {"version": 5, "owned_karts": [RacerRoster.DEFAULT_ID, "posi", "bicok"],
		"selected_kart": "posi"})
	SaveManager.load_profile()
	check_eq(SaveManager.owned_karts(), [RacerRoster.DEFAULT_ID, "posi", "bicok"], "real purchases kept")
	check(SaveManager.save_profile() and int(SaveManager.data.version) == SaveManager.SAVE_VERSION, "saved as the current version")


## 0.14.3: the flag must survive a save -> load from disk (it was dropped by
## _merge_into because the default tutorial dictionary did not know it).
func test_lesson_flag_survives_reload() -> void:
	SaveManager.set_tutorial_flag(LessonDirector.FLAG, true)
	SaveManager.save_profile()
	SaveManager.load_profile()
	check(SaveManager.get_tutorial_flag(LessonDirector.FLAG), "lesson_done kept after reload")
	SafeFile.write_json(PROFILE, {"version": 6, "stats": {"races": 3, "wins": 0, "podiums": 0},
		"tutorial": {"drift_done": true}})
	SaveManager.load_profile()
	check(SaveManager.get_tutorial_flag(LessonDirector.FLAG), "v7: a profile that has raced skips the lesson")
	SafeFile.write_json(PROFILE, {"version": 6, "stats": {"races": 0, "wins": 0, "podiums": 0}})
	SaveManager.load_profile()
	check(not SaveManager.get_tutorial_flag(LessonDirector.FLAG), "a profile that never raced still gets it once")


## 0.14.3: Kids controls left on hid every button; holding the badge brings them back.
func test_hold_badge_turns_kids_off() -> void:
	var cfg := Game.default_race_config()
	cfg.laps = 1
	cfg.kids_auto = true
	Game.race_config = cfg
	var race: RaceManager = load("res://scenes/race/race.tscn").instantiate()
	tree.root.add_child(race)
	await tree.process_frame
	await tree.process_frame
	check(race.kids_mode() and race.hud.kids_badge.visible, "kids on, badge shown")
	check(not race.hud.touch.get_button("steer_left").visible, "steer hidden in kids mode")
	race.hud.turn_off_kids_mode()
	check(not race.kids_mode() and race.player.player_input.enabled, "manual driving back")
	check(race.hud.touch.get_button("steer_left").visible, "steer buttons back")
	Settings.set_value("controls", "kids_auto", false)
	race.queue_free()
	await tree.process_frame


## 0.14.4 (owner): pick one starter kart on the first launch; races use the
## garage's kart (no kart screen); "Maşınlarım" in the garage switches / buys.
func test_starter_pick_and_garage_kart() -> void:
	SaveManager.data = SaveManager.default_profile()
	check(SaveManager.needs_starter(), "fresh profile: starter pick pending")
	Game.play_pressed()
	check(Game.starter_pick, "first Oyna opens the starter pick")
	Game.starter_pick = false
	SaveManager.choose_starter("leloyun")
	check(not SaveManager.needs_starter(), "asked once")
	check_eq(SaveManager.owned_karts(), ["leloyun"], "the pick is the only kart owned")
	check_eq(SaveManager.get_selected_kart(), "leloyun", "and the race kart")
	Game.race_config = Game.default_race_config()
	Game.race_config.mode = "time_trial"
	Game.race_config.kart_id = "havhav"
	Game._changing = true # do not leave the test scene
	Game.start_race_with_selected()
	Game._changing = false
	check_eq(String(Game.race_config.kart_id), "leloyun", "races use the garage kart")
	check_eq(int(Game.race_config.ai_count), 0, "time trial runs alone")
	SafeFile.write_json(PROFILE, {"version": 7, "owned_karts": ["havhav", "posi"], "selected_kart": "posi"})
	SaveManager.load_profile()
	check(not SaveManager.needs_starter(), "existing players are never asked")
	var src := FileAccess.get_file_as_string("res://scripts/ui/city_select.gd")
	check(src.find("Game.start_race_with_selected()") > 0 and src.find("State.KART_SELECT") < 0, "city select starts the race")
	var g := FileAccess.get_file_as_string("res://scripts/ui/garage_screen.gd")
	check(g.find("_build_my_karts(") > 0 and g.find("func pick_kart") > 0, "garage has My karts")
