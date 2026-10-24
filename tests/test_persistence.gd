extends TestCase
## Save/load, corruption recovery, duplicate-reward prevention, settings.

const TEST_PROFILE := "user://test_profile.json"
const TEST_SETTINGS := "user://test_settings.json"
var _orig_profile_path := ""
var _orig_data := {}
var _orig_settings_path := ""
var _orig_settings := {}


func before_each() -> void:
	_orig_profile_path = SaveManager.save_path
	_orig_data = SaveManager.data.duplicate(true)
	_orig_settings_path = Settings.save_path
	_orig_settings = Settings.values.duplicate(true)
	SaveManager.save_path = TEST_PROFILE
	SafeFile.delete_all(TEST_PROFILE)
	SaveManager.load_profile()
	Settings.save_path = TEST_SETTINGS
	SafeFile.delete_all(TEST_SETTINGS)


func after_each() -> void:
	SafeFile.delete_all(TEST_PROFILE)
	SafeFile.delete_all(TEST_SETTINGS)
	SaveManager.save_path = _orig_profile_path
	SaveManager.data = _orig_data
	Settings.save_path = _orig_settings_path
	Settings.values = _orig_settings
	Settings.apply_all()


func test_reward_granted_once_per_event() -> void:
	var before := int(SaveManager.data.currency)
	check_eq(SaveManager.grant_reward("evt-1", 100), 100, "first grant applies")
	check_eq(SaveManager.grant_reward("evt-1", 100), 0, "second grant ignored")
	check_eq(int(SaveManager.data.currency), before + 100, "currency increased once")
	SaveManager.save_profile()
	SaveManager.load_profile()
	check_eq(SaveManager.grant_reward("evt-1", 100), 0, "ledger survives reload")
	check_eq(int(SaveManager.data.currency), before + 100, "currency persisted")


func test_results_reapplied_do_not_duplicate() -> void:
	var rm := RaceManager.new()
	rm.config = {"debug_autopilot": false, "mode": "quick"}
	var res := {"player": {"finished": true, "time": 120.0, "best_lap": 40.0, "kart": "balanced", "place": 1},
		"track_id": "test_track", "laps": 3, "mode": "quick", "event_instance_id": "race-xyz"}
	var c0 := int(SaveManager.data.currency)
	rm._apply_rewards(res)
	var c1 := int(SaveManager.data.currency)
	rm._apply_rewards(res.duplicate(true))
	var c2 := int(SaveManager.data.currency)
	check(c1 > c0, "reward applied")
	check_eq(c2, c1, "reloading results does not duplicate the reward")
	rm.free()


func test_records_keep_best() -> void:
	var imp := SaveManager.submit_times("t", 120000, 40000, "balanced", 3)
	check(imp.lap and imp.race, "first times are records")
	imp = SaveManager.submit_times("t", 125000, 41000, "balanced", 3)
	check(not imp.lap and not imp.race, "slower times are not records")
	imp = SaveManager.submit_times("t", 119000, 39500, "fast", 3)
	check(imp.lap and imp.race, "faster times replace records")
	check_eq(int(SaveManager.get_record("t").best_lap_ms), 39500, "best lap stored")
	imp = SaveManager.submit_times("t", 200000, 0, "fast", 5)
	check(imp.race, "race records are per lap count")


func test_corrupted_primary_falls_back_to_backup() -> void:
	SaveManager.data.currency = 321
	SaveManager.save_profile()
	SaveManager.data.currency = 555
	SaveManager.save_profile() # previous good file becomes .bak
	var f := FileAccess.open(TEST_PROFILE, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	SaveManager.load_profile()
	check_eq(SaveManager.last_load_source, "backup", "backup used after corruption")
	check_eq(int(SaveManager.data.currency), 321, "backup data restored")


func test_newer_version_is_not_loaded_silently() -> void:
	var d := SaveManager.default_profile()
	d.version = 999
	d.currency = 77
	SafeFile.write_json(TEST_PROFILE, d)
	SaveManager.load_profile()
	check(int(SaveManager.data.currency) != 77, "future-version save rejected")


func test_invalid_types_fall_back_to_defaults() -> void:
	var d := SaveManager.default_profile()
	d.selected_kart = 12345 # wrong type
	d.currency = 50
	SafeFile.write_json(TEST_PROFILE, d)
	SaveManager.load_profile()
	check_eq(SaveManager.get_selected_kart(), RacerRoster.DEFAULT_ID, "bad field replaced by default")
	check_eq(int(SaveManager.data.currency), 50, "valid fields kept")


func test_settings_persist_and_sanitize() -> void:
	Settings.values = Settings.defaults()
	Settings.set_value("audio", "music", 0.25)
	Settings.set_value("graphics", "shadows", 3)
	Settings.set_value("gameplay", "language", "en")
	Settings.values = {}
	Settings.load_settings()
	check_near(float(Settings.get_value("audio", "music")), 0.25, 0.001, "music volume persisted")
	check_eq(int(Settings.get_value("graphics", "shadows")), 3, "shadow quality persisted")
	check_eq(Settings.get_value("graphics", "preset"), "custom", "manual change marks preset custom")
	var raw := Settings.values.duplicate(true)
	raw.graphics.resolution_scale = 9.0
	raw.gameplay.difficulty = "impossible"
	SafeFile.write_json(TEST_SETTINGS, raw)
	Settings.load_settings()
	check(float(Settings.get_value("graphics", "resolution_scale")) <= 1.0, "out-of-range scale clamped")
	check_eq(Settings.get_value("gameplay", "difficulty"), "medium", "unknown difficulty reset")


func test_presets_change_settings_measurably() -> void:
	Settings.values = Settings.defaults()
	Settings.apply_preset("low", false)
	var low: Dictionary = Settings.values.graphics.duplicate()
	Settings.apply_preset("high", false)
	var high: Dictionary = Settings.values.graphics.duplicate()
	check(float(low.resolution_scale) < float(high.resolution_scale), "low renders fewer pixels")
	check(int(low.shadows) < int(high.shadows), "low uses cheaper shadows")
	check(float(low.effects_density) < float(high.effects_density), "low uses fewer particles")
	check(int(low.decor_distance) < int(high.decor_distance), "low culls scenery sooner")


func test_stars_added_once_and_unlock_paints() -> void:
	check_eq(SaveManager.get_stars(), 0, "new profile has no stars")
	check_eq(SaveManager.add_stars("race-a", 12), 12, "stars from a race are added")
	check_eq(SaveManager.add_stars("race-a", 12), 0, "the same race never adds twice")
	check_eq(SaveManager.get_stars(), 12, "total kept")
	SaveManager.set_paint("havhav", 1)
	check_eq(SaveManager.get_paint("havhav"), 0, "a locked paint cannot be chosen")
	SaveManager.add_stars("race-b", 5)
	SaveManager.set_paint("havhav", 1)
	check_eq(SaveManager.get_paint("havhav"), 1, "unlocked at %d stars" % KartPaints.cost(1))
	SaveManager.load_profile()
	check_eq(SaveManager.get_stars(), 17, "stars survive a reload")
	check_eq(SaveManager.get_paint("havhav"), 1, "paint survives a reload")
	var def := RacerRoster.get_def("havhav")
	check_eq(KartPaints.painted(def, 1).kart_primary, KartPaints.COLORS[0], "paint changes the body colour")
	check_eq(def.kart_primary, RacerRoster.get_def("havhav").kart_primary, "the shared definition is not modified")
