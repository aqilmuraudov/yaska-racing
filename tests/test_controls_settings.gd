extends TestCase
## Tilt steering (axis mapping, filter, calibration, sensitivity, reaching the
## kart), button sensitivity, settings v1→v2 migration, audio switches and
## texture-quality tiers.

const TEST_SETTINGS := "user://test_settings_v2.json"
const G := 9.81
var _orig_settings_path := ""
var _orig_settings := {}
var race: RaceManager
var _orig_profile_path := ""


func before_each() -> void:
	_orig_settings_path = Settings.save_path
	_orig_settings = Settings.values.duplicate(true)
	Settings.save_path = TEST_SETTINGS
	SafeFile.delete_all(TEST_SETTINGS)
	TiltSteering.fake_gravity = Vector3.ZERO


func after_each() -> void:
	TiltSteering.fake_gravity = Vector3.ZERO
	Engine.time_scale = 1.0
	if is_instance_valid(race):
		race.queue_free()
		await tree.process_frame
		SafeFile.delete_all("user://test_profile_tilt.json")
		SaveManager.save_path = _orig_profile_path
		SaveManager.load_profile()
	for a in InputActions.GAMEPLAY_ACTIONS:
		Input.action_release(a)
	SafeFile.delete_all(TEST_SETTINGS)
	Settings.save_path = _orig_settings_path
	Settings.values = _orig_settings
	Settings.apply_all()


## Gravity (Godot convention: points down, screen axes) for a phone held
## upright in landscape and rolled by `deg` (positive = right edge lowered).
static func upright(deg: float, pitch_back := 35.0) -> Vector3:
	var r := deg_to_rad(deg)
	var p := deg_to_rad(pitch_back)
	return Vector3(sin(r) * cos(p), -cos(r) * cos(p), -sin(p)) * G


static func settle(t: TiltSteering, g: Vector3, src := "gravity", seconds := 1.0, dt := 1.0 / 60.0) -> float:
	var s := 0.0
	var n := int(round(seconds / dt))
	for i in n:
		s = t.process_sample(g, src, dt)
	return s


func test_tilt_axis_mapping_and_direction() -> void:
	var t := TiltSteering.new()
	check_near(settle(t, upright(0.0)), 0.0, 0.001, "level phone: straight")
	check(settle(t, upright(15.0)) > 0.5, "right edge down steers right")
	check(settle(t, upright(-15.0)) < -0.5, "left edge down steers left")
	# Pitching the phone towards / away from the player is not steering.
	check_near(settle(t, upright(0.0, 10.0)), 0.0, 0.001, "pitch change alone does not steer")
	check_near(settle(t, upright(0.0, 70.0)), 0.0, 0.001, "nearly flat hold, no roll: straight")
	# Held flat (screen up) and rolled right.
	var flat_right := Vector3(sin(deg_to_rad(12.0)), 0.0, -cos(deg_to_rad(12.0))) * G
	check(settle(t, flat_right) > 0.3, "flat hold rolled right steers right")
	# Stale 180° rotation in Godot's sensor handler arrives fully negated
	# (x and y); the upright picture tells us to undo it.
	var t2 := TiltSteering.new()
	var stale := upright(15.0)
	stale = Vector3(-stale.x, -stale.y, stale.z)
	check(settle(t2, stale) > 0.5, "stale reverse-landscape samples still steer right")
	check(t2.flipped, "flip detected")


func test_tilt_deadzone_bounds_and_sensitivity() -> void:
	for lvl in 3:
		var lock: float = TiltSteering.FULL_LOCK_DEG[lvl]
		check_eq(TiltSteering.angle_to_steer(1.0, lvl), 0.0, "inside dead zone (level %d)" % lvl)
		check_near(TiltSteering.angle_to_steer(lock, lvl), 1.0, 0.001, "full lock at %.0f° (level %d)" % [lock, lvl])
		check_near(TiltSteering.angle_to_steer(-lock, lvl), -1.0, 0.001, "full left lock (level %d)" % lvl)
		check_eq(TiltSteering.angle_to_steer(80.0, lvl), 1.0, "bounded beyond lock (level %d)" % lvl)
		var prev := 0.0
		var mono := true
		for d in range(0, 40):
			var s := TiltSteering.angle_to_steer(float(d), lvl)
			mono = mono and s >= prev
			prev = s
		check(mono, "monotonic curve (level %d)" % lvl)
	check(TiltSteering.angle_to_steer(10.0, 2) > TiltSteering.angle_to_steer(10.0, 1), "High needs less tilt than Normal")
	check(TiltSteering.angle_to_steer(10.0, 1) > TiltSteering.angle_to_steer(10.0, 0), "Normal needs less tilt than Low")


func test_tilt_filter_independent_of_rate_and_responsive() -> void:
	var a := TiltSteering.new()
	var b := TiltSteering.new()
	settle(a, upright(0.0), "gravity", 0.5, 1.0 / 30.0)
	settle(b, upright(0.0), "gravity", 0.5, 1.0 / 120.0)
	var sa := settle(a, upright(12.0), "gravity", 0.1, 1.0 / 30.0)
	var sb := settle(b, upright(12.0), "gravity", 0.1, 1.0 / 120.0)
	check_near(sa, sb, 0.05, "same response after 0.1 s at 30 and 120 Hz")
	var c := TiltSteering.new()
	settle(c, upright(0.0))
	var after := settle(c, upright(25.0), "gravity", 0.15)
	check(after > 0.9, "gravity source reaches full lock within 0.15 s (%.2f)" % after)


func test_tilt_ignores_short_bumps() -> void:
	var t := TiltSteering.new()
	settle(t, upright(0.0), "accelerometer")
	# One 16 ms sideways jolt of 2 g (a bump), then back to level.
	var s := t.process_sample(upright(0.0) + Vector3(2.0 * G, 0, 0), "accelerometer", 1.0 / 60.0)
	check(absf(s) < 0.6, "single jolt does not cause full steering (%.2f)" % s)
	var later := settle(t, upright(0.0), "accelerometer", 0.4)
	check_near(later, 0.0, 0.01, "settles back to straight")


func test_tilt_calibration_and_reset() -> void:
	var t := TiltSteering.new()
	settle(t, upright(10.0))
	t.calibrate()
	check_near(settle(t, upright(10.0)), 0.0, 0.001, "calibrated hold is straight ahead")
	check(settle(t, upright(25.0)) > 0.5, "tilting further right from neutral steers right")
	check(settle(t, upright(-5.0)) < -0.5, "tilting left from neutral steers left")
	t.reset()
	check_eq(t.steer, 0.0, "reset clears steering")
	# No sensor at all: no steering and "no data" after the timeout.
	var n := TiltSteering.new()
	settle(n, Vector3.ZERO, "none", 2.0)
	check(not n.has_data(), "missing sensor reported")
	check_eq(n.steer, 0.0, "missing sensor does not steer")


func test_button_sensitivity_ramp_and_max() -> void:
	var pi := PlayerInput.new()
	var dt := 1.0 / 60.0
	for lvl in 3:
		pi.steer_value = 0.0
		var t := 0.0
		var v := 0.0
		while v < 0.999 and t < 2.0:
			v = pi._ramp_digital(1.0, lvl, dt)
			t += dt
		check_near(t, PlayerInput.BUTTON_RAMP[lvl], dt + 0.001, "level %d reaches full lock in %.2f s" % [lvl, PlayerInput.BUTTON_RAMP[lvl]])
		check_near(v, 1.0, 0.0001, "level %d maximum steering is exactly 1" % lvl)
	pi.free()


func test_tilt_reaches_kart_and_turns_it() -> void:
	_orig_profile_path = SaveManager.save_path
	SaveManager.save_path = "user://test_profile_tilt.json"
	Settings.values.controls.touch_steer_mode = "tilt"
	Settings.values.gameplay.steer_assist = false # isolate tilt from the edge assist
	Settings.values.controls.steer_level = 1
	Settings.values.controls.tilt_neutral_deg = 0.0
	var cfg := Game.default_race_config()
	cfg.laps = 1
	cfg.ai_count = 0
	cfg.items = false
	cfg.debug_autopilot = false
	cfg.event_instance_id = "test-tilt"
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame
	Engine.time_scale = 4.0
	while race.state != RaceManager.RaceState.RACING:
		await tree.physics_frame
	var pi: PlayerInput = race.player.player_input
	pi.touch_active = true
	var kart := race.player.kart
	TiltSteering.fake_gravity = upright(0.0)
	await frames(60)
	# Turn-button input must not overwrite tilt: hold LEFT while tilting RIGHT.
	Input.action_press(InputActions.STEER_LEFT)
	TiltSteering.fake_gravity = upright(18.0)
	var yaw0 := kart.yaw
	await frames(25)
	check_eq(pi.steer_mode(), "tilt", "tilt mode active")
	check(kart.input.steer > 0.6, "tilt value reaches the kart controller (%.2f)" % kart.input.steer)
	check(kart.steer_smoothed > 0.3, "kart controller consumes it (%.2f)" % kart.steer_smoothed)
	var yaw_right := wrapf(kart.yaw - yaw0, -PI, PI)
	Input.action_release(InputActions.STEER_LEFT)
	TiltSteering.fake_gravity = upright(-18.0)
	await frames(12)
	check(kart.input.steer < -0.6, "tilting left steers left (%.2f)" % kart.input.steer)
	var yaw1 := kart.yaw
	await frames(15)
	var yaw_left := wrapf(kart.yaw - yaw1, -PI, PI)
	check(yaw_right < -0.05 and yaw_left > 0.02, "tilting right/left turns the kart right/left (yaw Δ %.2f / %.2f)" % [yaw_right, yaw_left])
	# Pausing clears stale steering.
	pi.release_all()
	check_eq(kart.input.steer, 0.0, "release clears steering")
	# Switching to buttons clears stale tilt and uses the steer actions.
	Settings.values.controls.touch_steer_mode = "buttons"
	await frames(5)
	check_eq(pi.steer_mode(), "buttons", "buttons mode")
	check_near(kart.input.steer, 0.0, 0.001, "tilt ignored in buttons mode")
	# A device without sensor data falls back to buttons.
	Settings.values.controls.touch_steer_mode = "tilt"
	TiltSteering.fake_gravity = Vector3.ZERO
	pi.tilt_unavailable = false
	await frames(int(TiltSteering.NO_DATA_TIMEOUT * 60) + 30)
	check(pi.tilt_unavailable and pi.steer_mode() == "buttons", "no sensor data → buttons fallback")


func test_settings_v1_migration() -> void:
	var v1 := {
		"version": 1,
		"graphics": {"fps_cap": 30, "shadows": 2, "texture_detail": 0, "preset": "custom"},
		"audio": {"master": 0.7, "music": 0.0, "engine": 0.5, "sfx": 0.4, "ui": 0.5, "mute": true},
		"controls": {"touch_steer_mode": "tilt", "touch_scale": 1.3, "steer_sensitivity": 1.0, "tilt_sensitivity": 0.6},
		"gameplay": {"language": "en"},
	}
	SafeFile.write_json(TEST_SETTINGS, v1)
	Settings.load_settings()
	var s: Dictionary = Settings.values
	check_eq(int(s.graphics.fps_cap), 30, "frame-rate preference kept")
	check_eq(int(s.graphics.shadows), 2, "shadows kept")
	check_eq(int(s.graphics.texture_detail), 0, "texture quality kept")
	check_eq(String(s.gameplay.language), "en", "language kept")
	check_eq(bool(s.audio.master_on), false, "mute → master off")
	check_eq(bool(s.audio.music_on), false, "music volume 0 → music off")
	check_eq(bool(s.audio.sfx_on), true, "effects stay on")
	check(float(s.audio.music) > 0.0, "music level restored for when it is switched on")
	check_eq(int(s.controls.button_size), 2, "large touch scale → Large")
	check_eq(int(s.controls.steer_level), 0, "low tilt sensitivity → Low")
	check_eq(String(s.controls.touch_steer_mode), "tilt", "control type kept")
	Settings.save_settings()
	Settings.load_settings()
	check_eq(int(Settings.values.version), Settings.SETTINGS_VERSION, "saved as v2")
	check_eq(int(Settings.values.controls.button_size), 2, "v2 round trip")


func test_settings_v2_migration() -> void:
	var v2 := {
		"version": 2,
		"controls": {"touch_steer_mode": "buttons", "button_size": 0, "vibration": false},
		"gameplay": {"language": "az", "steer_assist": false},
		"accessibility": {"camera_shake": 1.0},
	}
	SafeFile.write_json(TEST_SETTINGS, v2)
	Settings.load_settings()
	var s: Dictionary = Settings.values
	check_eq(bool(s.gameplay.steer_assist), false, "steering help off after v4 migration (never takes over)")
	check_near(float(s.accessibility.camera_shake), 0.6, 0.001, "camera shake becomes gentle")
	check_eq(bool(s.controls.easy_drift), true, "easy drift added, on")
	check_eq(int(s.controls.button_size), 0, "player choices kept")
	check_eq(bool(s.controls.vibration), false, "vibration choice kept")


func test_audio_switches_mute_and_restore() -> void:
	Settings.set_value("audio", "music_on", false)
	Settings.set_value("audio", "sfx_on", true)
	Settings.set_value("audio", "master_on", false)
	var master := AudioServer.get_bus_index("Master")
	var music := AudioServer.get_bus_index("Music")
	var sfx := AudioServer.get_bus_index("SFX")
	check(AudioServer.is_bus_mute(master), "master off mutes everything")
	check_eq(bool(Settings.values.audio.music_on), false, "music choice remembered")
	check_eq(bool(Settings.values.audio.sfx_on), true, "effects choice remembered")
	Settings.set_value("audio", "master_on", true)
	check(not AudioServer.is_bus_mute(master), "master on")
	check(AudioServer.is_bus_mute(music), "music stays off as chosen")
	check(not AudioServer.is_bus_mute(sfx), "effects come back")
	Settings.load_settings()
	check_eq(bool(Settings.values.audio.music_on), false, "switches persist")


func test_texture_quality_uses_asset_tiers() -> void:
	var widths := []
	for tq in 3:
		Settings.set_value("graphics", "texture_detail", tq)
		widths.append(TextureLibrary.loaded_width("road"))
	check(widths[0] > 0, "road texture exists")
	check(widths[0] < widths[1] and widths[1] < widths[2], "Low < Normal < High texture size %s" % str(widths))
	var mat := ShaderMaterial.new()
	TextureLibrary.bind(mat, "albedo_tex", "road")
	Settings.set_value("graphics", "texture_detail", 0)
	var w0: int = (mat.get_shader_parameter("albedo_tex") as Texture2D).get_width()
	Settings.set_value("graphics", "texture_detail", 2)
	var w2: int = (mat.get_shader_parameter("albedo_tex") as Texture2D).get_width()
	check(w2 > w0, "bound materials switch tier immediately (%d → %d)" % [w0, w2])


func test_fps_options() -> void:
	var opts := Settings.fps_options()
	for v in [30, 60, 90, 120]:
		check(v in opts, "%d offered" % v)
	check(Settings.fps_supported(30) and Settings.fps_supported(60), "30/60 always supported")
