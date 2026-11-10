extends TestCase
## Round 21 (0.11.1): "Şəhəri seç" — the city is picked in the normal
## Yarış / Rekord flow (big picture cards, Yeni! badge, remembered choice),
## the daily card names its city, kart select shows the city to load.

const TEST_SETTINGS := "user://test_settings_r21.json"
const TEST_PROFILE := "user://test_profile_r21.json"
const ModeSelect := preload("res://scripts/ui/mode_select.gd")
const RacerSelect := preload("res://scripts/ui/racer_select.gd")
var _orig_settings_path := ""
var _orig_settings := {}
var _orig_profile_path := ""
var screen: Node


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
	if is_instance_valid(screen):
		screen.queue_free()
	await tree.process_frame
	SafeFile.delete_all(TEST_SETTINGS)
	Settings.save_path = _orig_settings_path
	Settings.values = _orig_settings
	SafeFile.delete_all(TEST_PROFILE)
	SaveManager.save_path = _orig_profile_path
	SaveManager.load_profile()
	Game.race_config = Game.default_race_config()


func _host() -> Control:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	tree.root.add_child(host)
	return host


func test_flow_routes_through_city_select() -> void:
	check_eq(ModeSelect.next_state("quick"), Game.State.CITY_SELECT, "Yarış picks a city")
	check_eq(ModeSelect.next_state("time_trial"), Game.State.CITY_SELECT, "Rekord picks a city")
	check_eq(ModeSelect.next_state("cup"), Game.State.KART_SELECT, "cup keeps its fixed tracks")
	check(ResourceLoader.exists(Game.SCENES[Game.State.CITY_SELECT]), "city scene exists")
	Game.race_config.mode = "quick"
	check(RacerSelect.picks_city(), "kart select knows quick picks a city")
	var rs = RacerSelect.new()
	check_eq(rs.back_state, Game.State.CITY_SELECT, "back from kart select goes to the cities")
	rs.free()
	Game.race_config.series = "cup_new"
	check(not RacerSelect.picks_city(), "cup: no city step")
	var rs2 = RacerSelect.new()
	check_eq(rs2.back_state, Game.State.MODE_SELECT, "cup back goes to modes")
	rs2.free()


func test_reset_series_restores_chosen_city() -> void:
	Settings.set_value("gameplay", "track", "downtown_towers")
	# A daily on the seafront leaves its track behind...
	Game.race_config.series = "daily"
	Game.race_config.track_id = "seafront_sprint"
	Game.reset_series()
	check_eq(Game.race_config.track_id, "downtown_towers", "plain modes use the chosen city again")


func test_city_cards_data() -> void:
	var d := SaveManager.data
	for id in TrackList.IDS:
		check(CityCards.thumb(id) != null, "%s has a picture" % id)
		check(CityCards.length_m(id) > 500.0, "%s length" % id)
		check(CityCards.length_text(id).ends_with(" km"), "length text")
		check_eq(CityCards.trophies(d, id), Vector2i(0, 7), "%s trophies 0/7" % id)
		check_eq(CityCards.best_lap_text(d, id), "", "no record yet")
	check(not CityCards.is_new(d, "seafront_sprint"), "first city never 'new'")
	check(CityCards.is_new(d, "downtown_towers"), "new city is new")
	check(CityCards.mark_played(d, "downtown_towers"), "marked")
	check(not CityCards.mark_played(d, "downtown_towers"), "only once")
	check(not CityCards.mark_played(d, "nowhere"), "bad id ignored")
	check(not CityCards.is_new(d, "downtown_towers"), "badge gone after a race")
	# 0.11.0 players who already raced downtown don't see the badge either.
	d.erase(CityCards.PLAYED_KEY)
	d.track_stats["downtown_towers:quick_finish"] = 1
	check(not CityCards.is_new(d, "downtown_towers"), "old saves count as played")
	d.track_stats.erase("downtown_towers:quick_finish")
	SaveManager.submit_times("downtown_towers", 80000, 36500, "havhav", 2)
	check(not CityCards.is_new(d, "downtown_towers"), "a record counts as played")
	check_eq(CityCards.best_lap_text(d, "downtown_towers"), RaceHUD.format_time(36.5), "best lap shown")


func test_city_select_screen() -> void:
	var host := _host()
	Settings.set_value("gameplay", "track", "downtown_towers")
	Game.race_config.mode = "quick"
	screen = load("res://scripts/ui/city_select.gd").new()
	host.add_child(screen)
	for k in 6:
		await tree.process_frame
	check_eq(screen.cards.size(), TrackList.IDS.size(), "one card per city")
	check_eq(screen.selected, "downtown_towers", "last city pre-selected")
	check_eq(Game.race_config.track_id, "downtown_towers", "config follows the pre-selection")
	check_eq(screen.first_focus(), screen.cards["downtown_towers"], "focus on the last city")
	check(screen.new_badges.has("downtown_towers"), "Yeni! on the new city")
	check(not screen.new_badges.has("seafront_sprint"), "no badge on the seafront")
	var card: Button = screen.cards["downtown_towers"]
	for nm in ["Image", "MiniMap", "Name", "Length", "Best", "Trophies", "Go"]:
		check(card.find_child(nm, true, false) != null, "card has %s" % nm)
	check_eq((card.find_child("Name", true, false) as Label).text, tr("TRACK_DOWNTOWN"), "city name")
	# 0.18.0: four cities share the row (~280 px each at the 1280 base width).
	check(card.size.x >= 270.0 and card.size.y >= 320.0, "big cards (%s)" % card.size)
	var a: Rect2 = screen.cards["seafront_sprint"].get_global_rect()
	check(not a.intersects(card.get_global_rect()), "cards don't overlap")
	check(a.end.x <= 1280.0 + 1.0 and card.get_global_rect().end.x <= 1280.0 + 1.0, "cards fit on screen")
	screen.choose("seafront_sprint", false)
	check_eq(Game.race_config.track_id, "seafront_sprint", "tap picks the city")
	check_eq(String(Settings.get_value("gameplay", "track", "")), "seafront_sprint", "remembered")
	check_eq(Game.default_race_config().track_id, "seafront_sprint", "advanced setup sees the same city")
	host.queue_free()


func test_kart_select_shows_city() -> void:
	var host := _host()
	Settings.set_value("gameplay", "track", "downtown_towers")
	Game.race_config = Game.default_race_config()
	Game.race_config.mode = "time_trial"
	screen = RacerSelect.new()
	host.add_child(screen)
	for k in 4:
		await tree.process_frame
	check(screen.city_btn != null, "city chip on kart select")
	var nm: Label = screen.city_btn.find_child("Name", true, false)
	check_eq(nm.text, tr("TRACK_DOWNTOWN"), "names the city about to load")
	screen.queue_free()
	await tree.process_frame
	Game.race_config.series = "cup_new"
	screen = RacerSelect.new()
	host.add_child(screen)
	for k in 3:
		await tree.process_frame
	check(screen.city_btn == null, "cup: no city chip")
	host.queue_free()


func test_daily_card_names_city() -> void:
	var host := _host()
	screen = ModeSelect.new()
	host.add_child(screen)
	for k in 4:
		await tree.process_frame
	var ch := DailyChallenge.generate(Progression.today(), SaveManager.owned_karts())
	var chip: Control = screen.cards["daily"].find_child("CityChip", true, false)
	check(chip != null, "daily card shows its city")
	if chip:
		check_eq((chip.find_child("Name", true, false) as Label).text, tr(TrackList.city_key(ch.track)), "today's city name")
		check((chip.find_child("Thumb", true, false) as TextureRect).texture != null, "today's city picture")
	check(screen.cards["quick"].find_child("CityChip", true, false) == null, "only the daily card")
	host.queue_free()


func test_track_select_stays_in_sync() -> void:
	var host := _host()
	Settings.set_value("gameplay", "track", "downtown_towers")
	Game.race_config = Game.default_race_config()
	screen = load("res://scripts/ui/track_select.gd").new()
	host.add_child(screen)
	for k in 4:
		await tree.process_frame
	check_eq(screen.track_id, "downtown_towers", "Race Setup opens on the chosen city")
	screen.set_track("seafront_sprint")
	check_eq(String(Settings.get_value("gameplay", "track", "")), "seafront_sprint", "Race Setup choice saved")
	screen.queue_free()
	await tree.process_frame
	screen = load("res://scripts/ui/city_select.gd").new()
	host.add_child(screen)
	for k in 3:
		await tree.process_frame
	check_eq(screen.selected, "seafront_sprint", "city screen follows Race Setup")
	host.queue_free()


func test_tutorial_stays_on_seafront() -> void:
	Settings.set_value("gameplay", "track", "downtown_towers")
	var src := FileAccess.get_file_as_string("res://scripts/ui/mode_select.gd")
	check(src.contains("Game.race_config.track_id = TrackList.IDS[0]"), "drift school forces the seafront")
