extends TestCase
## Round 29 (0.15.2, owner): Rekord HUD overlap, garage tabs (Maşınlar /
## Tüninq), time of day on the city screen, the "Öyrən" guided tour (no lesson
## opens by itself), Qoşa Qala gate + walls in Blender.

const TEST_SETTINGS := "user://test_settings_r29.json"
const PROFILE := "user://test_profile_r29.json"
var _orig_settings_path := ""
var _orig_settings := {}
var _orig_profile_path := ""
var race: RaceManager
var screen: Node


func before_each() -> void:
	_orig_settings_path = Settings.save_path
	_orig_settings = Settings.values.duplicate(true)
	Settings.save_path = TEST_SETTINGS
	SafeFile.delete_all(TEST_SETTINGS)
	_orig_profile_path = SaveManager.save_path
	SaveManager.save_path = PROFILE
	SafeFile.delete_all(PROFILE)
	SaveManager.load_profile()


func after_each() -> void:
	if is_instance_valid(race):
		race.queue_free()
	if is_instance_valid(screen):
		screen.queue_free()
	await tree.process_frame
	SafeFile.delete_all(TEST_SETTINGS)
	Settings.save_path = _orig_settings_path
	Settings.values = _orig_settings
	SafeFile.delete_all(PROFILE)
	SaveManager.save_path = _orig_profile_path
	SaveManager.load_profile()
	Game.race_config = Game.default_race_config()
	GarageScreen.tab = 0


func _race(extra := {}, headless := true) -> void:
	var cfg := Game.default_race_config()
	cfg.laps = 1
	cfg.seed = 29
	cfg.active_seed = 29
	cfg.event_instance_id = "test-r29"
	cfg.merge(extra, true)
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = headless
	tree.root.add_child(race)
	await tree.process_frame
	await tree.process_frame


func _screen(path: String) -> void:
	tree.root.size = Vector2i(1600, 720)
	screen = load(path).instantiate()
	tree.root.add_child(screen)
	for i in 4:
		await tree.process_frame


func test_time_trial_camera_button_below_record_column() -> void:
	await _race({"mode": "time_trial", "ai_count": 0, "items": false}, false)
	var tc: TouchControls = race.hud.touch
	check(tc.camera_low, "Rekord: camera switch moved down")
	tc._layout()
	var cam: TouchControls.TouchButton
	for b in tc.buttons:
		if b.id == "camera":
			cam = b
	check(cam != null and cam.center.y - cam.radius > 200.0, "below the best-lap line and delta pill (y %.0f)" % cam.center.y)
	race.queue_free()
	await tree.process_frame
	await _race({"mode": "quick"}, false)
	check(not race.hud.touch.camera_low, "quick race keeps it high")


func test_garage_has_two_tabs() -> void:
	SaveManager.choose_starter("havhav")
	GarageScreen.tab = 0
	await _screen("res://scenes/menus/garage.tscn")
	var g: GarageScreen = screen
	check_eq(g.tab_buttons.size(), 2, "two tabs")
	check(g.find_child("KartsPage", true, false).visible, "Maşınlar page first")
	check(not g.find_child("TuningPage", true, false).visible, "Tüninq hidden")
	check_eq(g.my_karts.get_child_count(), RacerRoster.IDS.size(), "a big card per kart")
	var card: Button = g.my_karts.find_child("Kart_havhav", false, false)
	check(card != null and card.custom_minimum_size.x >= 180.0, "cards are big")
	g.show_tab(1)
	check(g.find_child("TuningPage", true, false).visible and not g.find_child("KartsPage", true, false).visible, "Tüninq page")
	check(g.paint_row.is_visible_in_tree(), "paint on the tuning page")
	check_eq(GarageScreen.tab, 1, "tab remembered for the next visit")


func test_city_select_time_of_day() -> void:
	Settings.set_value("gameplay", "time_of_day", "day")
	await _screen("res://scenes/menus/city_select.tscn")
	check_eq(screen.tod_buttons.size(), 3, "day / sunset / night")
	var b: Button = screen.tod_buttons["night"]
	check(b.custom_minimum_size.y >= 90.0, "big buttons")
	screen.pick_tod("night")
	check_eq(TimeOfDay.selected(), "night", "saved")
	check_eq(String(Game.race_config.time_of_day), "night", "next race uses it")


func test_no_lesson_by_itself_and_learn_button() -> void:
	SaveManager.choose_starter("havhav")
	var src := FileAccess.get_file_as_string("res://scripts/core/game.gd")
	var i := src.find("func play_pressed")
	var body := src.substr(i, src.find("\nfunc ", i + 10) - i)
	check(body.find("start_lesson") < 0, "Oyna never opens the lesson")
	await _screen("res://scenes/menus/mode_select.tscn")
	var learn: Button = screen.school_btn
	check(learn != null and learn.text == tr("MODE_LEARN"), "Öyrən button")
	check(learn.custom_minimum_size.y >= UITheme.H_PRIMARY, "big")


func test_guided_tour_steps() -> void:
	await _race({"mode": "tutorial", "ai_count": 0, "items": false, "kids_auto": true}, false)
	var td: TutorialDirector = race.tutorial
	check(td != null, "tour in the race")
	check(not race.kids_mode(), "every button shown in the tour")
	check_eq(td.step, TutorialDirector.Step.GAS, "starts with gas")
	td.set_process(false)
	td.next()
	check_eq(td.step, TutorialDirector.Step.STEER, "steer")
	td.next()
	td.next()
	check_eq(td.step, TutorialDirector.Step.DRIFT, "drift")
	race.player.kart.drift_started.emit(1)
	check_eq(td.step, TutorialDirector.Step.BOOST, "drift moves on by itself")
	race.player.kart.drift_boost.emit(1, false)
	check_eq(td.step, TutorialDirector.Step.ITEM, "boost moves on")
	check_eq(race.player.kart.item, &"turbo", "the tour hands a turbo")
	race.player.kart.item = &""
	race.player.kart.item_changed.emit(&"")
	check_eq(td.step, TutorialDirector.Step.CAMERA, "using it moves on")
	td.next()
	check(td.next_btn.visible, "pause step: Davam")
	td.next()
	check_eq(td.step, TutorialDirector.Step.DONE, "done")
	check(SaveManager.get_tutorial_flag("drift_done"), "remembered")
	check(td.title_label.text == tr("TUT2_DONE"), "finish card")


func test_gate_and_wall_modules() -> void:
	for id in ["gate_arch", "gate_tower", "wall_seg", "wall_tower", "wall_end"]:
		check(ResourceLoader.exists(String(PropKit.GLTF_PROPS[id]) + ".glb"), "glb for " + id)
	var gate := LandmarkKit.qosa_qala(26.0)
	check(gate.get_aabb().size.x > 26.0 + 9.0, "towers outside the span")
	check(gate.get_aabb().size.y > 15.0, "towers above the wall")
	var w := LandmarkKit.city_wall(48.0)
	check(w.get_aabb().size.y > 11.0, "wall towers above the parapet")
	check(absf(w.get_aabb().size.x - 48.0) < 8.0, "wall length fits")
