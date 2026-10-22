extends TestCase
## Integration: full race scene headless. Restart cleanup, repeated races /
## memory, suspend handling, race completion with six racers.

var race: RaceManager
var _orig_profile_path := ""


func before_each() -> void:
	_orig_profile_path = SaveManager.save_path
	SaveManager.save_path = "user://test_profile_scene.json"
	Engine.time_scale = 6.0


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	if is_instance_valid(race):
		race.queue_free()
		await tree.process_frame
	SafeFile.delete_all("user://test_profile_scene.json")
	SaveManager.save_path = _orig_profile_path
	SaveManager.load_profile()


func _start_race(laps: int = 3, items: bool = true, seed_value: int = 77) -> void:
	var cfg := Game.default_race_config()
	cfg.laps = laps
	cfg.items = items
	cfg.ai_count = 5
	cfg.seed = seed_value
	cfg.active_seed = seed_value
	cfg.debug_autopilot = true
	cfg.event_instance_id = "test-%d" % seed_value
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame


func _wait_race_time(t: float, timeout_frames: int = 6000) -> void:
	var n := 0
	while race.race_time < t and n < timeout_frames:
		await tree.physics_frame
		n += 1


func _count_nodes(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count_nodes(ch)
	return c


func test_race_runs_and_ranks_six_racers() -> void:
	await _start_race()
	check_eq(race.racers.size(), 6, "one player plus five AI")
	await _wait_race_time(14.0)
	check_eq(race.state, RaceManager.RaceState.RACING, "racing")
	var places := {}
	for r in race.racers:
		places[r.place] = true
		check(r.tracker.race_distance > 120.0, "%s made progress (%.0f m)" % [r.name, r.tracker.race_distance])
	check_eq(places.size(), 6, "unique positions 1..6")


func test_restart_clears_race_state() -> void:
	await _start_race()
	await _wait_race_time(10.0)
	var nodes_before := _count_nodes(race)
	# Leave lingering state behind: item in hand, active trap, boost, hit.
	var pk := race.player.kart
	pk.give_item(&"trap", 0.0)
	for i in 2:
		await tree.physics_frame
	race.items.use_item(pk)
	pk.apply_item_boost()
	race.racers[1].kart.apply_hit(&"trap")
	await tree.physics_frame
	check(race.items.active_trap_count() > 0, "a trap is on track before restart")
	race.restart()
	await tree.physics_frame
	check_eq(race.race_time, 0.0, "race clock reset")
	check(race.state in [RaceManager.RaceState.INTRO, RaceManager.RaceState.COUNTDOWN], "back to pre-start")
	check_eq(race.items.active_trap_count(), 0, "traps cleared")
	check_eq(race.finish_counter, 0, "finish counter reset")
	for r in race.racers:
		var k := r.kart
		check(k.global_position.distance_to(r.grid_xform.origin) < 1.0, "%s back on the grid" % r.name)
		check_eq(k.item, &"", "%s item cleared" % r.name)
		check(not k.boost.is_active(), "%s boost cleared" % r.name)
		check(k.state == KartController.State.NORMAL, "%s state normal" % r.name)
		check(k.controls_locked, "%s locked until GO" % r.name)
		check_eq(r.tracker.cp_count, 0, "%s checkpoints reset" % r.name)
		check_eq(r.tracker.lap_times.size(), 0, "%s lap times reset" % r.name)
		check_eq(r.ai.route, -1, "%s AI route reset" % r.name)
		check_eq(k.input.throttle, 0.0, "%s input cleared" % r.name)
	check_eq(_count_nodes(race), nodes_before, "no nodes leaked by restart")


func test_repeated_restarts_do_not_grow_memory() -> void:
	await _start_race()
	var counts: Array[int] = []
	for i in 6:
		await _wait_race_time(6.0)
		race.restart()
		await tree.physics_frame
		counts.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	var growth := counts[counts.size() - 1] - counts[1]
	check(growth < 40, "object count stable across restarts (growth %d, counts %s)" % [growth, str(counts)])


func test_focus_loss_pauses_and_releases_input() -> void:
	await _start_race()
	await _wait_race_time(1.0)
	Input.action_press(InputActions.ACCELERATE)
	race.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(tree.paused, "race pauses when the app loses focus")
	check(race.paused, "race flagged paused")
	check_eq(race.player.kart.input.throttle, 0.0, "player inputs released")
	Input.action_release(InputActions.ACCELERATE)
	race.set_paused(false)
	check(not tree.paused, "resume works")


func test_full_race_completes_with_results() -> void:
	await _start_race(1, true, 9)
	var got := {}
	race.results_ready.connect(func(res): got.merge(res))
	var n := 0
	while race.state != RaceManager.RaceState.RESULTS and n < 20000:
		await tree.physics_frame
		n += 1
	check_eq(race.state, RaceManager.RaceState.RESULTS, "race reached results")
	check(got.has("rows"), "results emitted")
	if got.has("rows"):
		check_eq(got.rows.size(), 6, "six result rows")
		var finished := 0
		for row in got.rows:
			if row.finished:
				finished += 1
				check(row.time > 30.0, "plausible finish time %.1f" % row.time)
		check(finished >= 4, "most racers finished the lap within the window (%d)" % finished)
		check_eq(got.rows[0].place, 1, "first row is P1")
