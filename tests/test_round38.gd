extends TestCase
## Round 38 (0.20.0): owner 2026-11-11 - the city first, then its maps:
## "Şəhəri seç" shows Bakı and Qarabağ; Bakı opens its three maps, Qarabağ
## its big map. Geri / Esc goes from the maps back to the cities.

const TEST_SETTINGS := "user://test_settings_r38.json"
const TEST_PROFILE := "user://test_profile_r38.json"
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


func after_each() -> void:
	if is_instance_valid(screen):
		screen.get_parent().queue_free()
	await tree.process_frame
	SafeFile.delete_all(TEST_SETTINGS)
	Settings.save_path = _orig_settings_path
	Settings.values = _orig_settings
	SafeFile.delete_all(TEST_PROFILE)
	SaveManager.save_path = _orig_profile_path
	SaveManager.load_profile()


func _open(track: String) -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	tree.root.add_child(host)
	Settings.set_value("gameplay", "track", track)
	Game.race_config.mode = "quick"
	screen = load("res://scripts/ui/city_select.gd").new()
	host.add_child(screen)
	for k in 6:
		await tree.process_frame


func test_regions_cover_every_track_once() -> void:
	var seen := {}
	for r in TrackList.REGIONS:
		check(tr(TrackList.region_key(r)) != TrackList.region_key(r), "%s has a name" % r)
		for id in TrackList.region_tracks(r):
			check(not seen.has(id), "%s in one city only" % id)
			seen[id] = r
	for id in TrackList.IDS:
		check(seen.has(id), "%s belongs to a city" % id)
	check_eq(TrackList.region_tracks("baku"), ["seafront_sprint", "downtown_towers", "old_city"], "Bakı: three maps")
	check_eq(TrackList.region_tracks("karabakh"), ["karabakh", "karabakh_khankendi", "karabakh_shusha", "karabakh_lachin"], "Qarabağ: the big map, Xankəndi, Şuşa, Laçın")
	check_eq(TrackList.region_of("old_city"), "baku", "İçərişəhər is in Bakı")
	check_eq(TrackList.region_of("karabakh"), "karabakh", "Qarabağ")


func test_cities_first_then_maps() -> void:
	await _open("old_city")
	check_eq(screen.region, "", "the city step first")
	check_eq(screen.region_cards.size(), 2, "Bakı and Qarabağ")
	check(screen.cards.is_empty(), "no map cards yet")
	check_eq(screen.first_focus(), screen.region_cards["baku"], "focus on the last city (Bakı)")
	check_eq(screen.title_label.text, tr("CITY_TITLE"), "Şəhəri seç")
	var baku: Button = screen.region_cards["baku"]
	for nm in ["Image", "Name", "Maps", "Trophies", "Go"]:
		check(baku.find_child(nm, true, false) != null, "city card has %s" % nm)
	check_eq((baku.find_child("Pic", true, false) as Control).get_child_count(), 3, "Bakı shows its three maps")
	check_eq((baku.find_child("Name", true, false) as Label).text, tr("REGION_BAKU"), "name")
	var a: Rect2 = baku.get_global_rect()
	var b: Rect2 = (screen.region_cards["karabakh"] as Button).get_global_rect()
	check(not a.intersects(b), "cards don't overlap")
	check(a.size.x >= 300.0 and a.size.y >= 320.0, "big city cards (%s)" % a.size)
	check(b.end.x <= screen.get_viewport().get_visible_rect().size.x + 1.0, "cards fit on screen (%.0f of %.0f)" % [b.end.x, screen.get_viewport().get_visible_rect().size.x])
	# Bakı opens its three maps
	(screen.region_cards["baku"] as Button).pressed.emit()
	for k in 3:
		await tree.process_frame
	check_eq(screen.region, "baku", "Bakı open")
	check_eq(screen.cards.size(), 3, "three Baku maps")
	check(screen.cards.has("old_city") and not screen.cards.has("karabakh"), "only Baku maps")
	check_eq(screen.first_focus(), screen.cards["old_city"], "the last map pre-selected")
	check(screen.title_label.text.begins_with(tr("REGION_BAKU")), "title names the city")
	# Geri: back to the cities, the screen stays
	screen.go_back()
	await tree.process_frame
	check_eq(screen.region, "", "back to the cities")
	check(is_instance_valid(screen) and screen.is_inside_tree(), "still on the screen")
	check_eq(screen.region_cards.size(), 2, "the cities again")
	# Qarabağ opens its map; a tap picks it
	screen.open_region("karabakh")
	await tree.process_frame
	check_eq(screen.cards.size(), 4, "the big map, Xankəndi, Şuşa, Laçın")
	check(screen.cards.has("karabakh"), "Qarabağ map")
	screen.choose("karabakh", false)
	check_eq(Game.race_config.track_id, "karabakh", "picked")
	check_eq(String(Settings.get_value("gameplay", "track", "")), "karabakh", "remembered")
	var one: Button = screen.cards["karabakh"]
	check(one.size.x >= 300.0 and one.size.x <= 620.0, "map cards keep a sensible size (%s)" % one.size)


func test_new_badge_on_a_city() -> void:
	await _open("seafront_sprint")
	check(screen.new_badges.has("baku"), "Yeni! on Bakı (two maps never raced)")
	check(screen.new_badges.has("karabakh"), "Yeni! on Qarabağ")
	for id in TrackList.IDS:
		CityCards.mark_played(SaveManager.data, id)
	screen.show_regions()
	await tree.process_frame
	check(not screen.new_badges.has("baku") and not screen.new_badges.has("karabakh"), "badges gone once raced")
