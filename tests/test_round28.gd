extends TestCase
## Round 28 (0.15.1): Azerbaijani character voice lines (ElevenLabs) and the
## Settings → Səs "Personaj səsləri" switch.

const TEST_SETTINGS := "user://test_settings_r28.json"
var _orig_settings_path := ""
var _orig_settings := {}
var race: RaceManager


func before_each() -> void:
	_orig_settings_path = Settings.save_path
	_orig_settings = Settings.values.duplicate(true)
	Settings.save_path = TEST_SETTINGS
	SafeFile.delete_all(TEST_SETTINGS)


func after_each() -> void:
	if is_instance_valid(race):
		race.queue_free()
	await tree.process_frame
	SafeFile.delete_all(TEST_SETTINGS)
	Settings.save_path = _orig_settings_path
	Settings.values = _orig_settings
	Game.race_config = Game.default_race_config()


func test_every_line_has_a_file() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/voice_lines.json"))
	for id in RacerRoster.IDS:
		check(data.lines.has(id), "%s has lines" % id)
		for cat in VoiceDirector.COUNTS:
			var lines: Array = data.lines[id].get(cat, [])
			check_eq(lines.size(), int(VoiceDirector.COUNTS[cat]), "%s %s count" % [id, cat])
			for i in lines.size():
				var p := VoiceDirector.PATH % [id, cat, i]
				check(ResourceLoader.exists(p), "file " + p)


func test_voice_files_are_short_and_mono_sized() -> void:
	var s: AudioStream = load(VoiceDirector.PATH % ["yaska", "win", 0])
	check(s != null, "loads")
	check(s.get_length() > 0.4 and s.get_length() < 5.0, "short line (%.2f s)" % s.get_length())


func test_switch_default_and_settings_row() -> void:
	check(Settings.defaults().audio.has("voices_on"), "in defaults")
	check(bool(Settings.defaults().audio.voices_on), "on by default")
	check(VoiceDirector.enabled(), "enabled")
	Settings.set_value("audio", "voices_on", false)
	check(not VoiceDirector.enabled(), "switch turns voices off")
	Settings.set_value("audio", "voices_on", true)
	Settings.set_value("audio", "master_on", false)
	check(not VoiceDirector.enabled(), "master off silences voices")
	Settings.set_value("audio", "master_on", true)
	var host := Control.new()
	tree.root.add_child(host)
	var sm: Node = load("res://scripts/ui/settings_menu.gd").new()
	host.add_child(sm)
	await tree.process_frame
	await tree.process_frame
	sm._show_tab(1)
	await tree.process_frame
	check(_find_text(sm, tr("SET2_VOICES")), "audio tab shows the voices switch")
	host.queue_free()
	await tree.process_frame


func test_director_plays_on_sfx_bus_and_respects_switch() -> void:
	var cfg := Game.default_race_config()
	cfg.laps = 1
	cfg.seed = 28
	cfg.active_seed = 28
	cfg.event_instance_id = "test-r28"
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame
	var v: VoiceDirector = race.voice
	check(v != null, "race has a voice director")
	check_eq(v.out.bus, &"SFX", "SFX bus")
	check(race.player.racer_id != "", "player racer id")
	check(v.say(race.player, "start"), "speaks")
	check(not v.say(race.player, "pass"), "one speaker at a time")
	check(v.say(race.player, "win", true), "finish interrupts")
	v.reset()
	var a := v.spoken.size()
	Settings.set_value("audio", "voices_on", false)
	check(not v.say(race.player, "start"), "silent when switched off")
	check_eq(v.spoken.size(), a, "nothing logged")
	Settings.set_value("audio", "voices_on", true)
	# No immediate repeat of the same line.
	var last := ""
	for i in 6:
		v.reset()
		v.say(race.player, "approach")
		check(v.spoken[-1] != last, "no repeat")
		last = v.spoken[-1]


func _find_text(n: Node, t: String) -> bool:
	if n is Label and (n as Label).text == t:
		return true
	for c in n.get_children():
		if _find_text(c, t):
			return true
	return false
