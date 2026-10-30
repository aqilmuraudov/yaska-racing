extends TestCase
## Round 18 (0.10.1): time of day (day / sunset / night), Flame Towers LED
## show only at sunset and night, night lights.

const TEST_SETTINGS := "user://test_settings_r18.json"
var _orig_settings_path := ""
var _orig_settings := {}
var race: RaceManager
var scr: Node


func before_each() -> void:
	_orig_settings_path = Settings.save_path
	_orig_settings = Settings.values.duplicate(true)
	Settings.save_path = TEST_SETTINGS
	SafeFile.delete_all(TEST_SETTINGS)


func after_each() -> void:
	if is_instance_valid(race):
		race.queue_free()
	if is_instance_valid(scr):
		scr.queue_free()
	await tree.process_frame
	SafeFile.delete_all(TEST_SETTINGS)
	Settings.save_path = _orig_settings_path
	Settings.values = _orig_settings
	Game.race_config = Game.default_race_config()
	TimeOfDay.apply_materials("day")


func test_setting_persists() -> void:
	Settings.load_settings()
	check_eq(TimeOfDay.selected(), "day", "default is day")
	Settings.set_value("gameplay", "time_of_day", "night")
	Settings.load_settings()
	check_eq(TimeOfDay.selected(), "night", "night survives a restart")
	check_eq(String(Game.default_race_config().time_of_day), "night", "new races use the choice")
	Settings.set_value("gameplay", "time_of_day", "noon")
	check_eq(TimeOfDay.selected(), "day", "unknown value falls back to day")
	Settings.set_value("gameplay", "time_of_day", "sunset")
	# Cup race 3 forces sunset, races 1-2 day; back to the player's choice afterwards.
	var cup := BakuCup.new_cup("havhav", 5)
	cup.race = 2
	var cfg := Game.default_race_config()
	BakuCup.apply_config(cfg, cup)
	check_eq(String(cfg.time_of_day), "sunset", "cup final at sunset")
	cup.race = 0
	BakuCup.apply_config(cfg, cup)
	check_eq(String(cfg.time_of_day), "day", "cup race 1 in daylight")
	check(BakuCup.stage_text(2).size() == 4 and BakuCup.stage_text(0).size() == 3, "sunset shown as a stage chip")
	Settings.set_value("gameplay", "time_of_day", "night")
	Game.race_config = cfg
	cfg.series = "cup"
	Game.reset_series()
	check_eq(String(Game.race_config.time_of_day), "night", "leaving the cup restores the choice")


func test_environment_params() -> void:
	var day := TimeOfDay.params("day")
	var sunset := TimeOfDay.params("sunset")
	var night := TimeOfDay.params("night")
	check(float(sunset.sun_pitch) > -15.0 and float(day.sun_pitch) < -20.0, "sunset sun is low (long shadows)")
	check(sunset.sun_color.r > 0.9 and sunset.sun_color.b < 0.4, "warm orange sunset sun")
	check(sunset.sky_horizon.r > sunset.sky_horizon.g and sunset.sky_top.b > sunset.sky_top.g, "pink horizon, purple top")
	check(night.sky_top.get_luminance() < 0.05, "dark night sky")
	check(night.sun_color.b > night.sun_color.r, "cool moonlight")
	check(float(night.ambient_energy) >= 0.6, "night fill keeps the road readable")
	check(bool(night.headlights) and not bool(day.headlights) and not bool(sunset.headlights), "headlights only at night")
	for id in TimeOfDay.IDS:
		var env := RaceEnvironment.new()
		tree.root.add_child(env)
		env.build(id)
		var p := TimeOfDay.params(id)
		check_near(env.sun.light_energy, float(p.sun_energy), 0.001, "%s sun energy" % id)
		check_near(rad_to_deg(env.sun.rotation.x), float(p.sun_pitch), 0.01, "%s sun height" % id)
		var sky := env.env.sky.sky_material as ProceduralSkyMaterial
		check(sky.sky_top_color.is_equal_approx(p.sky_top), "%s sky colour" % id)
		check_near(env.env.ambient_light_energy, float(p.ambient_energy), 0.001, "%s ambient" % id)
		check_eq(env.gulls.is_empty(), id == "night", "%s gulls" % id)
		env.free()
	var e2 := RaceEnvironment.new()
	tree.root.add_child(e2)
	e2.build("bogus")
	check_eq(e2.time_of_day, "day", "invalid id builds daylight")
	e2.free()


func test_led_only_at_sunset_and_night() -> void:
	var m := LandmarkKit.flame_glass(100.0)
	var globe := BakuExtras._mat("globe") as StandardMaterial3D
	var glass := PropKit.m("glass") as StandardMaterial3D
	for id in TimeOfDay.IDS:
		var env := RaceEnvironment.new()
		tree.root.add_child(env)
		env.build(id)
		var on: bool = id != "day"
		check_eq(float(m.get_shader_parameter("flame_led")) > 0.5, on, "%s: LED show %s" % [id, "on" if on else "off"])
		check_eq(glass.emission_enabled, on, "%s: lit windows" % id)
		env.apply_graphics() # graphics changes must not switch the show off
		check_eq(float(m.get_shader_parameter("flame_led")) > 0.5, on, "%s: LED kept after graphics change" % id)
		if id == "night":
			check(globe.emission_energy_multiplier > 3.0, "lamp globes glow at night")
			check(LandmarkKit.hac_white().emission_energy_multiplier > 0.6, "HAC uplit at night")
		env.free() # leaving the race returns shared materials to daylight
		check_near(float(m.get_shader_parameter("flame_led")), 0.0, 0.001, "%s: LED off after the race" % id)
		check(not glass.emission_enabled, "%s: windows off after the race" % id)
	check(LandmarkKit.flame_defs().size() == 3, "three towers")


func _race(tod: String) -> void:
	var cfg := Game.default_race_config()
	cfg.time_of_day = tod
	cfg.laps = 1
	cfg.seed = 18
	cfg.active_seed = 18
	cfg.event_instance_id = "test-r18"
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame


func test_night_lights_in_race() -> void:
	await _race("night")
	check_eq(race.environment.time_of_day, "night", "race built at night")
	var hl := race.player.kart.get_node_or_null("Headlight") as SpotLight3D
	check(hl != null and not hl.shadow_enabled, "player headlight, no shadows")
	var ai_lights := 0
	for r in race.racers:
		if r != race.player and r.kart.get_node_or_null("Headlight"):
			ai_lights += 1
	check_eq(ai_lights, 0, "only the player kart has a spotlight")
	if race.decor and race.decor.landmarks.has("government_house"):
		check(race.get_node_or_null("GovFloodlight") != null, "Government House floodlight")
	race.queue_free()
	await tree.process_frame
	await _race("day")
	check(race.player.kart.get_node_or_null("Headlight") == null, "no headlight by day")
	check(race.night_lights.is_empty(), "no extra lights by day")


func test_race_setup_buttons() -> void:
	Settings.load_settings()
	Game.race_config = Game.default_race_config()
	scr = load("res://scenes/menus/track_select.tscn").instantiate()
	tree.root.add_child(scr)
	for i in 4:
		await tree.process_frame
	check_eq(scr.tod_btns.size(), 3, "three time-of-day buttons")
	check_eq(scr.tod_id, "day", "day selected by default")
	(scr.tod_btns["night"] as Button).pressed.emit()
	check_eq(TimeOfDay.selected(), "night", "button saves the choice")
	check_eq(String(Game.race_config.time_of_day), "night", "and sets the race")
	var vis := tree.root.get_visible_rect()
	var b: Button = scr.tod_btns["sunset"]
	check(vis.encloses(b.get_global_rect()), "buttons on screen")
	check(vis.encloses(scr.start_btn.get_global_rect()), "start button still on screen")
