extends TestCase
## Round 19 (0.10.2): main-menu redesign (4 big buttons, credits in
## Settings), Android performance (decor / kart LOD, auto quality tier with a
## learned step-down) and the cinematic camera.

const TEST_SETTINGS := "user://test_settings_r19.json"
const SIZES := [Vector2(1280, 720), Vector2(2400, 1080), Vector2(1440, 1080)]
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


func _host(sz: Vector2) -> Control:
	tree.root.size = Vector2i(sz)
	var host := Control.new()
	host.size = sz
	tree.root.add_child(host)
	return host


# --- Task 1: main menu --------------------------------------------------------

func test_main_menu_layout() -> void:
	var was: bool = load("res://scripts/ui/main_menu.gd").login_popup_enabled
	load("res://scripts/ui/main_menu.gd").login_popup_enabled = false
	for sz in SIZES:
		var host := _host(sz)
		var mm = load("res://scripts/ui/main_menu.gd").new()
		host.add_child(mm)
		for k in 30:
			await tree.process_frame
		var area: Rect2 = mm.root.get_viewport_rect()
		check_eq(mm.buttons.size(), 4, "four big buttons")
		check_eq(mm.buttons[0], mm.play_btn, "Oyna first")
		check_eq(mm.buttons[1], mm.garage_btn, "Qaraj second")
		check_eq(mm.buttons[0].text, tr("MENU_PLAY"), "play label")
		check_eq(mm.buttons[2].text, tr("MENU_REWARDS"), "rewards label")
		var y0: float = mm.tiles[0].get_global_rect().position.y
		var last_x := -1.0
		for i in mm.buttons.size():
			var b: Button = mm.buttons[i]
			var r: Rect2 = b.get_global_rect()
			check(area.encloses(r), "%s inside %s (%s)" % [b.text, sz, r])
			check(mm.tiles[i].get_global_rect().position.y > area.size.y * 0.6, "%s in the bottom row" % b.text)
			check_near(mm.tiles[i].get_global_rect().position.y, y0, 1.0, "one row")
			check(r.position.x > last_x, "left to right")
			last_x = r.position.x + r.size.x - 2.0
			check(b.size.y >= 90.0, "chunky (%s)" % b.size.y)
		for b in mm.buttons:
			for c in mm.buttons:
				if b != c:
					check(not b.get_global_rect().grow(-3).intersects(c.get_global_rect().grow(-3)), "buttons don't overlap")
		check(mm.find_child("Icon", true, false) is TextureRect, "icons above the labels")
		check(area.encloses(mm.money_chip.get_global_rect()), "balance pill visible at %s" % sz)
		check(area.encloses(mm.title_badge.get_global_rect()), "title pill visible at %s" % sz)
		check(area.encloses(mm.gear_btn.get_global_rect()), "gear visible at %s" % sz)
		check(mm.gear_btn.get_global_rect().position.x < area.size.x * 0.2, "gear top-left")
		check(mm.money_chip.get_global_rect().position.x > area.size.x * 0.5, "balance top-right")
		check(not mm.title_badge.get_global_rect().intersects(mm.money_chip.get_global_rect()), "pills don't overlap")
		var plank := mm.find_child("Plank", true, false) as Control
		check(plank != null and area.encloses(plank.get_global_rect()), "subtitle plank visible")
		check(mm.find_child("Crown", true, false) != null, "crown on the logo")
		for b in mm.buttons:
			check(not mm.title_badge.get_global_rect().intersects(b.get_global_rect()), "pills clear of the buttons")
		check(mm.stage.showcase, "boulevard showcase built")
		check(mm.stage.find_child("NeonRing", true, false) != null, "glowing turntable")
		check_eq(String(mm.title_badge.get_meta("value").text), tr(Progression.title_for(int(SaveManager.data.lifetime.get("stars", 0))).name), "title from progression")
		host.queue_free()
		await tree.process_frame
	load("res://scripts/ui/main_menu.gd").login_popup_enabled = was


func test_menu_strings() -> void:
	check_eq(TranslationServer.get_translation_object("az").get_message("MENU_REWARDS"), "Mükafatlar", "spelled with k")
	check_eq(TranslationServer.get_translation_object("az").get_message("CAM_CINEMATIC"), "Sinematik", "camera label")


func test_credits_in_settings() -> void:
	var host := _host(Vector2(1280, 720))
	var sm = load("res://scripts/ui/settings_menu.gd").new()
	host.add_child(sm)
	for k in 3:
		await tree.process_frame
	sm._show_tab(3)
	for k in 3:
		await tree.process_frame
	check(sm.credits_btn != null and is_instance_valid(sm.credits_btn), "credits button on the language tab")
	if sm.credits_btn:
		check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(sm.credits_btn.get_global_rect()), "credits button visible")
	var cr = load("res://scripts/ui/credits.gd").new()
	check_eq(cr.back_state, Game.State.SETTINGS, "credits back goes to Settings")
	cr.free()
	host.queue_free()
	await tree.process_frame


# --- Task 2: performance ------------------------------------------------------

func test_auto_quality_tier() -> void:
	Settings.values.graphics.auto_cap = "high"
	check_eq(Settings.auto_preset("NVIDIA GeForce", 8, 0), "high", "desktop high")
	check_eq(Settings.auto_preset("Adreno (TM) 740", 8, 1), "high", "flagship phone high")
	check_eq(Settings.auto_preset("Mali-G68", 8, 1), "medium", "mid phone medium")
	check_eq(Settings.auto_preset("Adreno (TM) 506", 8, 1), "low", "old GPU low")
	check_eq(Settings.auto_preset("Adreno (TM) 740", 4, 1), "low", "4 cores low")
	Settings.values.graphics.auto_cap = "medium"
	check_eq(Settings.auto_preset("Adreno (TM) 740", 8, 1), "medium", "learned cap applies")


func test_auto_step_down() -> void:
	Settings.apply_preset("high", false)
	check(Settings.auto_step_down(), "high -> medium")
	check_eq(String(Settings.values.graphics.preset), "medium", "now medium")
	check_eq(String(Settings.values.graphics.auto_cap), "medium", "cap remembered")
	check(Settings.auto_step_down(), "medium -> low")
	check(not Settings.auto_step_down(), "low is the floor")
	Settings.load_settings()
	check_eq(String(Settings.values.graphics.get("auto_cap", "")), "low", "cap survives a restart")


func test_lod_distance() -> void:
	check_near(TrackDecor.lod_for(260.0), 109.2, 0.5, "medium decor -> ~109 m")
	check_near(TrackDecor.lod_for(50.0), 60.0, 0.01, "floor 60 m")
	check_near(TrackDecor.lod_for(900.0), 200.0, 0.01, "cap 200 m")
	var full := PropKit.get_mesh("palm")
	var lo := PropKit.get_mesh("palm" + PropKit.LO_SUFFIX)
	check(full != lo, "separate far mesh")
	var tris := func(m: Mesh) -> int:
		var n := 0
		for s in m.get_surface_count():
			var a := m.surface_get_arrays(s)
			n += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if a[Mesh.ARRAY_INDEX] != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		return n
	check(int(tris.call(lo)) < int(tris.call(full)), "far palm is lighter (%d < %d)" % [tris.call(lo), tris.call(full)])
	check_eq(ShapeKit.detail, 1.0, "detail restored")


func _race() -> void:
	var cfg := Game.default_race_config()
	cfg.laps = 1
	cfg.seed = 19
	cfg.active_seed = 19
	cfg.event_instance_id = "test-r19"
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame


func test_race_lod_and_cinematic() -> void:
	await _race()
	var decor = race.decor
	check(decor != null and decor._lod_nodes.size() > 0, "far LOD chunks built")
	for n in decor._lod_nodes:
		check(n.visibility_range_begin > 0.0, "LOD chunk starts far")
		check_eq(n.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "no shadows far away")
		break
	var vis = race.player.kart.get_meta("visual")
	check(vis.model_lo != null, "kart far model")
	check(vis.model_lo.find_children("*", "MeshInstance3D", true, false).size() > 0, "far model has meshes")
	# Cinematic camera.
	var cam: ChaseCamera = race.camera
	check_eq(ChaseCamera.mode_count(), 5, "five views")
	check_eq(ChaseCamera.MODE_KEYS[ChaseCamera.Mode.CINEMATIC], "CAM_CINEMATIC", "cinematic key")
	check(cam.landmarks.size() >= 2, "fly-by landmarks known (%d)" % cam.landmarks.size())
	Settings.set_value("gameplay", "camera_mode", 4, false)
	check_eq(int(Settings.values.gameplay.camera_mode), 4, "setting accepts cinematic")
	cam.set_mode(ChaseCamera.Mode.CINEMATIC)
	var seen := {}
	var kart: KartController = race.player.kart
	for i in 60:
		cam._process(0.25)
		seen[cam.shot] = true
		var d := cam.global_position.distance_to(kart.global_position)
		check(d < 40.0, "kart stays readable (%.1f m)" % d)
		check(cam.global_position.y > kart.global_position.y - 0.5, "camera above the ground")
	check(seen.size() >= 3, "shots cycle (%s)" % [seen.keys()])
	cam.cycle_mode()
	check_eq(cam.mode, ChaseCamera.Mode.CHASE, "cycle wraps back to chase")
