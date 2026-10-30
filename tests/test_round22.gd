extends TestCase
## Round 22 (0.11.2): phone optimisation + night polish.
##  - render height cap per preset on phones, MSAA 2x instead of FXAA on Medium,
##    settings v5 re-derives stored preset values from the chosen level;
##  - shared mipmapped noise texture replaces per-pixel hash noise in the road,
##    ground and water shaders (global shader uniform yaska_noise);
##  - night: lamp light pools (one MultiMesh), kart head/tail lamps, rival
##    headlight cones, darker sea via yaska_night - no extra real lights;
##  - results screen no longer crashes without a race (test gap in r5-r9).

const TEST_SETTINGS := "user://test_settings_r22.json"
const TEST_PROFILE := "user://test_profile_r22.json"
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
	Settings.apply_graphics()
	SaveManager.save_path = _orig_profile_path
	SaveManager.load_profile()


func test_render_scale_caps_height_on_phones() -> void:
	# fraction, render_height, screen short side -> expected
	check_near(Settings.render_scale_for(0.8, 864, 1080), 0.8, 0.001, "1080p phone: Medium unchanged (0.8)")
	check_near(Settings.render_scale_for(0.8, 864, 1440), 0.6, 0.001, "1440p phone: Medium capped to 864 px")
	check_near(Settings.render_scale_for(1.0, 1080, 1440), 0.75, 0.001, "1440p phone: High capped to 1080 px")
	check_near(Settings.render_scale_for(0.6, 648, 720), 0.6, 0.001, "720p phone: Low keeps its fraction")
	check_near(Settings.render_scale_for(0.6, 648, 2160), 0.5, 0.001, "never below 0.5")
	check_near(Settings.render_scale_for(0.8, 0, 1440), 0.8, 0.001, "no cap -> plain fraction")
	check_near(Settings.render_scale_for(0.8, 864, 0), 0.8, 0.001, "unknown screen (desktop) -> plain fraction")


func test_presets_retuned_for_phones() -> void:
	var p: Dictionary = Settings.presets
	# 0.11.2: MSAA 2x was tried on Medium and looked MORE jagged than FXAA
	# in the Mobile-renderer screenshots (render scale 0.8), so FXAA stays.
	check_eq(int(p.medium.msaa), 0, "Medium keeps FXAA, no MSAA")
	check(bool(p.medium.fxaa), "Medium FXAA")
	check(int(p.low.render_height) < int(p.medium.render_height) and int(p.medium.render_height) < int(p.high.render_height),
		"render height rises Low < Medium < High")
	for k in ["low", "medium", "high"]:
		check(p[k].has("render_height"), "%s has render_height" % k)


func test_settings_v4_migrates_preset_values() -> void:
	var g: Dictionary = Settings.defaults().graphics.duplicate()
	g.quality = "low"
	g.preset = "low"
	g.msaa = 0
	g.fxaa = false
	g.texture_detail = 0
	g.erase("render_height")
	g.battery_saver = true
	g.fps_cap = 30
	var data := Settings.defaults()
	data.graphics = g
	data.version = 4
	SafeFile.write_json(TEST_SETTINGS, data)
	Settings.load_settings()
	var ng: Dictionary = Settings.values.graphics
	check_eq(int(ng.render_height), int(Settings.presets.low.render_height), "v4 save: render height from its own preset")
	check_eq(String(ng.quality), "low", "chosen level kept")
	check_eq(int(ng.fps_cap), 30, "frame rate kept")
	check_eq(int(ng.texture_detail), 0, "texture detail kept")
	check_eq(int(Settings.values.version), Settings.SETTINGS_VERSION, "now v5")
	check_eq(Settings.SETTINGS_VERSION, 5, "settings version 5")


func test_noise_texture_and_shaders() -> void:
	var tex: Texture2D = load("res://assets/textures/noise_value.png")
	check(tex != null, "noise texture loads")
	if tex == null:
		return
	var img := tex.get_image()
	check_eq(img.get_width(), 256, "256 px wide")
	check(img.has_mipmaps(), "mipmapped (no far shimmer)")
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	var sum := 0.0
	var seam := 0.0
	var inner := 0.0
	for y in range(0, 256, 4):
		for x in range(0, 256, 4):
			sum += img.get_pixel(x, y).r
		seam += absf(img.get_pixel(255, y).r - img.get_pixel(0, y).r)
		inner += absf(img.get_pixel(128, y).r - img.get_pixel(127, y).r)
	check_near(sum / 4096.0, 0.5, 0.06, "mean ~0.5 like the old value noise")
	check(seam <= inner * 1.6 + 0.05, "tiles without a seam (seam %.3f vs inner %.3f)" % [seam, inner])
	check(ProjectSettings.has_setting("shader_globals/yaska_noise"), "global noise uniform registered")
	check(ProjectSettings.has_setting("shader_globals/yaska_night"), "global night uniform registered")
	for f in ["road", "ground", "water"]:
		var code := (load("res://assets/materials/%s.gdshader" % f) as Shader).code
		check(code.contains("global uniform sampler2D yaska_noise"), "%s samples the shared noise" % f)
		check(not code.contains("hash12(i + vec2(1, 1))"), "%s has no per-pixel 4-hash value noise" % f)
	var ground := (load("res://assets/materials/ground.gdshader") as Shader).code
	check(not ground.contains("srgb_to_linear(tint)"), "ground converts colour per vertex, not per pixel")
	check((load("res://assets/materials/water.gdshader") as Shader).code.contains("yaska_night"), "water darkens at night")


func _race(tod: String, track := "seafront_sprint") -> void:
	var cfg := Game.default_race_config()
	cfg.time_of_day = tod
	cfg.track_id = track
	cfg.laps = 1
	cfg.seed = 22
	cfg.active_seed = 22
	cfg.event_instance_id = "test-r22"
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame


func _count_lights(n: Node) -> int:
	var c := 1 if n is Light3D and not n is DirectionalLight3D else 0
	for ch in n.get_children():
		c += _count_lights(ch)
	return c


func test_night_glow_is_faked_not_real_lights() -> void:
	for track in ["seafront_sprint", "downtown_towers"]:
		await _race("night", track)
		var pools := race.get_node_or_null("LampPools") as MultiMeshInstance3D
		var lamps: int = race.decor.instance_transforms("lamp").size()
		check(lamps > 0, "%s: lamp transforms kept after the decor flush (%d)" % [track, lamps])
		check(pools != null, "%s: lamp pools built" % track)
		if pools:
			check_eq(pools.multimesh.instance_count, lamps, "%s: one pool per lamp in ONE MultiMesh" % track)
			check_eq(int(pools.cast_shadow), int(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "%s: pools cast no shadow" % track)
		var with_lamps := 0
		var cones := 0
		for r in race.racers:
			var vis: Node = r.kart.get_node_or_null("Visual")
			var holder: Node = vis if vis else r.kart
			if holder.get_node_or_null("KartLamps"):
				with_lamps += 1
			if holder.get_node_or_null("HeadGlow"):
				cones += 1
				check(r != race.player, "%s: the player has no fake cone (real headlight)" % track)
		check_eq(with_lamps, race.racers.size(), "%s: every kart has head/tail lamps" % track)
		check_eq(cones, race.racers.size() - 1, "%s: every rival has a headlight cone" % track)
		# Only the floodlight (seafront) and the player headlight are real lights.
		var lights := _count_lights(race)
		check(lights <= 2, "%s: no extra real lights at night (%d)" % [track, lights])
		check_near(NightGlow.night_value, 1.0, 0.001, "%s: sea at night" % track)
		race.queue_free()
		await tree.process_frame
		await tree.process_frame
	check_near(NightGlow.night_value, 0.0, 0.001, "day again after the race")


func test_no_night_glow_by_day() -> void:
	await _race("day")
	check(race.get_node_or_null("LampPools") == null, "no lamp pools by day")
	for r in race.racers:
		var vis: Node = r.kart.get_node_or_null("Visual")
		check((vis if vis else r.kart).get_node_or_null("KartLamps") == null, "no kart lamps by day")
	check(race.night_lights.is_empty(), "nothing extra by day")
	check_near(NightGlow.night_value, 0.0, 0.001, "day sea")


func test_sunset_glow_is_weaker() -> void:
	check_near(NightGlow.strength("night"), 1.0, 0.001, "night full")
	check(NightGlow.strength("sunset") > 0.0 and NightGlow.strength("sunset") < 0.5, "sunset faint")
	check_near(NightGlow.strength("day"), 0.0, 0.001, "day none")


func _tris(mesh: Mesh) -> int:
	var t := 0
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var idx = a[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t


func test_kart_shadows_come_from_low_detail_proxies() -> void:
	await _race("day")
	for r in race.racers:
		var vis: KartVisual = r.kart.get_node("Visual")
		check(vis.shadow_proxies >= 1, "%s: shadow proxies built (%d)" % [r.kart.name, vis.shadow_proxies])
		var near_casters := 0
		for mi in vis.model.find_children("*", "MeshInstance3D", true, false):
			if (mi as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				near_casters += 1
		check_eq(near_casters, 0, "%s: full-detail model casts no shadow" % r.kart.name)
		var proxy_tris := 0
		var proxies := vis.find_children("ShadowProxy*", "MeshInstance3D", true, false)
		for p in proxies:
			check_eq(int((p as GeometryInstance3D).cast_shadow), int(GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY), "proxy is shadows-only")
			check_near((p as GeometryInstance3D).visibility_range_end, KartVisual.KART_LOD, 0.01, "proxy only near")
			proxy_tris += _tris((p as MeshInstance3D).mesh)
		var near_tris := 0
		for mi in vis.model.find_children("*", "MeshInstance3D", true, false):
			near_tris += _tris((mi as MeshInstance3D).mesh)
		check(proxy_tris > 0 and proxy_tris * 2 < near_tris, "%s: shadow pass draws far fewer triangles (%d vs %d)" % [r.kart.name, proxy_tris, near_tris])


func test_results_screen_without_race_sets_buttons() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	tree.root.add_child(host)
	var rs := ResultsScreen.new()
	host.add_child(rs)
	rs.setup(null)
	rs.size = host.size
	var rows: Array = []
	for i in 6:
		rows.append({"place": i + 1, "name": "R%d" % i, "is_player": i == 0, "finished": true, "time": 90.0, "best_lap": 30.0,
			"estimated": 0.0, "paint": Color.RED, "kart": "posi"})
	rs.retry_btn.text = ""
	rs.show_results({"rows": rows, "player": rows[0], "reward": 100, "stars": 1, "unlocks": [], "unlock_cards": [],
		"next_goals": [], "improved": {}, "event_instance_id": "r22"})
	await tree.process_frame
	check(rs.retry_btn.text != "", "retry button text set without a race")
	check(rs.retry_btn.icon != null, "retry button icon set without a race")
	host.queue_free()
	await tree.process_frame
