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
