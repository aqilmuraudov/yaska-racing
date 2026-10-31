extends TestCase
## Round 23 (0.12.0): winner's finish replay, wordless item hint (tap hand),
## item picture pill, strict test runner (tools/run_tests.py).

const TEST_SETTINGS := "user://test_settings_r23.json"
const TEST_PROFILE := "user://test_profile_r23.json"
var _orig_settings_path := ""
var _orig_settings := {}
var _orig_profile_path := ""
var race: RaceManager


func before_each() -> void:
	_orig_settings_path = Settings.save_path
	_orig_settings = Settings.values.duplicate(true)
	Settings.save_path = TEST_SETTINGS
	SafeFile.delete_all(TEST_SETTINGS)
	_orig_profile_path = SaveManager.save_path
	SaveManager.save_path = TEST_PROFILE
	SafeFile.delete_all(TEST_PROFILE)
	SaveManager.load_profile()
	Game.race_config = Game.default_race_config()


func after_each() -> void:
	if is_instance_valid(race):
		race.queue_free()
		await tree.process_frame
	SafeFile.delete_all(TEST_SETTINGS)
	SafeFile.delete_all(TEST_PROFILE)
	Settings.save_path = _orig_settings_path
	Settings.values = _orig_settings
	SaveManager.save_path = _orig_profile_path
	SaveManager.load_profile()


func _race(extra := {}) -> void:
	var cfg := Game.default_race_config()
	cfg.laps = 1
	cfg.seed = 23
	cfg.active_seed = 23
	cfg.event_instance_id = "test-r23"
	cfg.merge(extra, true)
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame
	var guard := 0
	while race.state != RaceManager.RaceState.RACING and guard < 600:
		await tree.physics_frame
		guard += 1


## Same as the --force-finish debug path: the player crosses now, 1st.
func _force_finish() -> void:
	race.player.tracker.finished = true
	race.player.tracker.finish_time = race.race_time
	race._handle_event(race.player, ["finish", race.race_time])


func _physics(n: int) -> void:
	for i in n:
		await tree.physics_frame


func test_replay_buffer_and_targets() -> void:
	await _race()
	check(race.replay != null, "replay node built")
	await _physics(420) # ~7 s of racing
	var rp := race.replay
	check(rp.frame_count() > 100, "frames recorded (%d)" % rp.frame_count())
	check(rp.frame_count() <= rp.capacity(), "ring buffer capped")
	check_near(rp.span(), race.race_time - rp._times[0], 0.05, "span matches race time")
	var now := race.race_time
	check(not rp.covers(now), "a crossing 'now' has no after-window yet")
	check(rp.covers(now - FinishReplay.WINDOW_AFTER - 0.1), "a recent crossing is covered")
	check(not rp.covers(rp._times[0] + 0.5), "too old for the before-window")
	var player_i := race.racers.find(race.player)
	check_eq(rp.pick_target(-1, 0.0, player_i, now - 2.0), player_i, "no winner -> the player")
	check_eq(rp.pick_target(0, rp._times[0], player_i, now - 2.0), player_i, "winner out of the buffer -> the player")
	check_eq(rp.pick_target(0, now - 2.0, player_i, now - 1.6), 0, "winner in the buffer -> the winner")
	check_near(rp.rate_at(rp.cross_time), FinishReplay.SLOWMO, 0.001, "slow motion at the line")
	check_near(rp.rate_at(rp.cross_time - 2.0), 1.0, 0.001, "normal speed away from the line")
	# Long races keep only the last BUFFER_S seconds.
	await _physics(int(FinishReplay.BUFFER_S * 60.0) + 120)
	check(rp.frame_count() <= rp.capacity(), "still capped after > BUFFER_S")
	check(rp.span() <= FinishReplay.BUFFER_S + 0.1, "span <= BUFFER_S (%.2f)" % rp.span())


func test_replay_plays_skips_and_restores() -> void:
	await _race({"force_replay": true})
	await _physics(300)
	_force_finish()
	check_eq(race.state, RaceManager.RaceState.FINISHING, "finishing after the line")
	var started := [false]
	race.replay_started.connect(func(_k): started[0] = true)
	await _physics(int(RaceManager.RESULTS_DELAY * 60.0) + 6)
	check(started[0], "replay started after the celebration")
	check(race.is_replaying(), "replaying")
	check_eq(race.state, RaceManager.RaceState.FINISHING, "results wait for the replay")
	check_eq(race.camera.mode, ChaseCamera.Mode.CINEMATIC, "cinematic camera during the replay")
	for r in race.racers:
		check(not r.kart.is_physics_processing(), "%s physics paused" % r.name)
	var rp := race.replay
	var ti := rp.target_index
	var t_before := race.race_time
	await _physics(30)
	check_near(race.race_time, t_before, 0.0001, "race clock frozen during the replay")
	var want := rp.transform_at(ti, rp.t)
	check(race.racers[ti].kart.global_position.distance_to(want.origin) < 0.05, "target kart follows the recording")
	var snap: Vector3 = rp._snapshot[0].xf.origin
	race.skip_replay()
	await tree.physics_frame
	check(not race.is_replaying(), "skip ends the replay")
	check_eq(race.state, RaceManager.RaceState.RESULTS, "results after the replay")
	check(race.racers[0].kart.global_position.distance_to(snap) < 0.5, "karts restored to where they were")
	for r in race.racers:
		check(r.kart.is_physics_processing(), "%s physics back on" % r.name)
	check_eq(race.camera.mode, race._replay_cam_mode, "camera view restored")
	check(race.camera.target == race.player.kart, "camera back on the player")


func test_replay_runs_to_the_end_by_itself() -> void:
	await _race({"force_replay": true})
	await _physics(300)
	_force_finish()
	await _physics(int(RaceManager.RESULTS_DELAY * 60.0) + 6)
	check(race.is_replaying(), "replaying")
	var rp := race.replay
	var real_len := 0.0
	var tt := rp.t_start
	while tt < rp.t_end: # replay length in real seconds incl. slow motion
		tt += (1.0 / 60.0) * rp.rate_at(tt)
		real_len += 1.0 / 60.0
	check(real_len > FinishReplay.WINDOW_BEFORE and real_len < 9.0, "replay %.1f s long" % real_len)
	await _physics(int(real_len * 60.0) + 10)
	check(not race.is_replaying(), "replay ended by itself")
	check_eq(race.state, RaceManager.RaceState.RESULTS, "then the results")


func test_restart_during_replay_gives_no_results() -> void:
	await _race({"force_replay": true})
	await _physics(300)
	_force_finish()
	var results := [0]
	race.results_ready.connect(func(_r): results[0] += 1)
	await _physics(int(RaceManager.RESULTS_DELAY * 60.0) + 6)
	check(race.is_replaying(), "replaying")
	race.restart()
	await _physics(3)
	check(not race.is_replaying(), "restart stops the replay")
	check_eq(results[0], 0, "no results from the aborted race")
	for r in race.racers:
		check(r.kart.is_physics_processing(), "%s physics back on after restart" % r.name)
	check_eq(race.replay.frame_count(), 0, "buffer cleared for the new race")


func test_replay_off_in_tests_and_tutorial() -> void:
	await _race()
	check(not race.replay_enabled(), "headless tests skip the replay unless forced")
	race.queue_free()
	await tree.process_frame
	await _race({"force_replay": true, "mode": "tutorial"})
	check(not race.replay_enabled(), "no replay in the tutorial")
	race.queue_free()
	await tree.process_frame
	await _race({"force_replay": true, "finish_replay": false})
	check(not race.replay_enabled(), "config can turn it off")


func test_tap_hint_and_item_pill() -> void:
	check(UITheme.icon("hint_tap") != null, "tap hand icon")
	var host := Control.new()
	host.size = Vector2(1280, 720)
	tree.root.add_child(host)
	var h := TapHint.new()
	h.target = Vector2(1100, 400)
	h.radius = 60
	h.duration = 0.3
	host.add_child(h)
	await tree.process_frame
	await tree.process_frame
	check(h.get_child_count() == 1, "hand drawn")
	check(h.mouse_filter == Control.MOUSE_FILTER_IGNORE, "never blocks touches")
	var hand: Control = h.get_child(0)
	check(hand.get_rect().grow(70).has_point(h.target), "hand next to the button")
	var guard := 0
	while is_instance_valid(h) and guard < 120:
		await tree.process_frame
		guard += 1
	check(not is_instance_valid(h), "fades away by itself")
	host.queue_free()
	var src := FileAccess.get_file_as_string("res://scripts/ui/race_hud.gd")
	check(not src.contains("tr(\"CAP_ITEM\")"), "bracketed item text no longer used")
	check(src.contains("func item_caption"), "item picture pill")
	check(tr("REPLAY_SKIP") != "REPLAY_SKIP" and tr("REPLAY_BADGE") != "REPLAY_BADGE", "replay strings translated")


func test_strict_runner_exists() -> void:
	var src := FileAccess.get_file_as_string("res://tools/run_tests.py")
	check(src.contains("SCRIPT ERROR"), "strict runner reads script errors")
