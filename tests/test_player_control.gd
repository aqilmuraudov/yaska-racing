extends TestCase
## Regression (0.7.0): "after bumping into things the kart steers by itself".
## Root cause: the steering help (centre pull + edge correction) was forced on
## by the v3 settings migration and hidden from Settings, so with no input the
## kart was pulled back to the road centre. Also guards stuck touch steering.

const TEST_SETTINGS := "user://test_settings_control.json"
var race: RaceManager
var _orig_path := ""
var _orig := {}
var _orig_profile := ""


func before_each() -> void:
	_orig_path = Settings.save_path
	_orig = Settings.values.duplicate(true)
	Settings.save_path = TEST_SETTINGS
	SafeFile.delete_all(TEST_SETTINGS)


func after_each() -> void:
	Engine.time_scale = 1.0
	for a in [InputActions.STEER_LEFT, InputActions.STEER_RIGHT]:
		Input.action_release(a)
	if is_instance_valid(race):
		race.queue_free()
		await tree.process_frame
		SafeFile.delete_all("user://test_profile_control.json")
		SaveManager.save_path = _orig_profile
		SaveManager.load_profile()
	SafeFile.delete_all(TEST_SETTINGS)
	Settings.save_path = _orig_path
	Settings.values = _orig


func test_steer_assist_off_by_default_and_migrated_off() -> void:
	check_eq(bool(Settings.defaults().gameplay.steer_assist), false, "steering help off by default")
	SafeFile.write_json(TEST_SETTINGS, {"version": 3, "gameplay": {"steer_assist": true}})
	Settings.load_settings()
	check_eq(bool(Settings.values.gameplay.steer_assist), false, "v3 save (forced on, hidden) migrates to off")
	check_eq(int(Settings.values.version), Settings.SETTINGS_VERSION, "version bumped")


func test_no_self_steering_after_bump_with_zero_input() -> void:
	Settings.values = Settings.defaults()
	_orig_profile = SaveManager.save_path
	SaveManager.save_path = "user://test_profile_control.json"
	var cfg := Game.default_race_config()
	cfg.laps = 1
	cfg.ai_count = 0
	cfg.items = false
	cfg.debug_autopilot = false
	cfg.event_instance_id = "test-control"
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame
	Engine.time_scale = 4.0
	while race.state != RaceManager.RaceState.RACING:
		await tree.physics_frame
	var r = race.player
	var kart: KartController = r.kart
	# Steer hard right for a while so the kart bumps the barrier / runs wide.
	Input.action_press(InputActions.STEER_RIGHT)
	await frames(150)
	Input.action_release(InputActions.STEER_RIGHT)
	var hw := maxf(race.track.main.half_width_at(r.tracker.s), 1.0)
	var max_abs := 0.0
	var off_centre := absf(r.tracker.lateral) / hw
	for i in 240:
		await tree.physics_frame
		max_abs = maxf(max_abs, absf(kart.input.steer))
	check(off_centre > 0.3, "kart was pushed off the centre line (%.2f of half width)" % off_centre)
	check_near(max_abs, 0.0, 0.0001, "no steering is applied without player input (max %.3f)" % max_abs)
	check(not r.ai.is_physics_processing(), "the player's AI driver never runs during the race")
	check(r.player_input.enabled, "player input stays enabled")


func test_touch_dropped_release_never_latches_steer() -> void:
	var pi := PlayerInput.new()
	var tc := TouchControls.new()
	tree.root.add_child(tc)
	tc.size = Vector2(1280, 720)
	tc.setup(pi)
	tc._layout()
	var left := tc.get_button("steer_left")
	var pos: Vector2 = left.center if "center" in left else Vector2.ZERO
	if pos == Vector2.ZERO:
		for x in range(0, 640, 8):
			for y in range(360, 720, 8):
				if tc._button_at(Vector2(x, y)) == left:
					pos = Vector2(x, y)
					break
			if pos != Vector2.ZERO:
				break
	check(pos != Vector2.ZERO, "found the left steer button")
	tc.handle_touch(0, pos, true)
	tc.handle_touch(0, pos, true) # Android re-sent the press, release lost
	tc.handle_touch(0, pos, false)
	check(not Input.is_action_pressed(InputActions.STEER_LEFT), "steer released after a duplicate press")
	tc.handle_touch(1, pos, true)
	tc.visible = false
	tc.handle_touch(1, pos, false)
	check(not Input.is_action_pressed(InputActions.STEER_LEFT), "hidden controls still release")
	tc.queue_free()
	pi.free()
