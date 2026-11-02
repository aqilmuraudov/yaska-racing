extends TestCase
## Round 32 (0.17.3, owner screenshots): no touch button covers another
## (NITRO sat on BRAKE with manual gas; the camera switch on the best-lap line
## and the cup pill), every famous building stands right beside the road,
## softer lit windows at sunset / night, malls keep their full model far away.

const TEST_SETTINGS := "user://test_settings_r32.json"
const TEST_PROFILE := "user://test_profile_r32.json"
var _orig_settings_path := ""
var _orig_settings := {}
var _orig_profile_path := ""
var race: RaceManager
var tc: TouchControls


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
	if is_instance_valid(race):
		race.queue_free()
	if is_instance_valid(tc):
		tc.queue_free()
	await tree.process_frame
	SafeFile.delete_all(TEST_SETTINGS)
	Settings.save_path = _orig_settings_path
	Settings.values = _orig_settings
	SafeFile.delete_all(TEST_PROFILE)
	SaveManager.save_path = _orig_profile_path
	SaveManager.load_profile()
	Game.race_config = Game.default_race_config()


func _race(extra := {}, headless := true) -> void:
	var cfg := Game.default_race_config()
	cfg.laps = 1
	cfg.seed = 32
	cfg.active_seed = 32
	cfg.event_instance_id = "test-r32"
	cfg.merge(extra, true)
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = headless
	tree.root.add_child(race)
	await tree.process_frame
	await tree.process_frame


func test_touch_buttons_never_overlap() -> void:
	tc = TouchControls.new()
	tree.root.add_child(tc)
	tc.nitro_level = 1
	tc.setup(null)
	for sz: Vector2 in [Vector2(1600, 720), Vector2(2400, 1080), Vector2(1280, 720), Vector2(1024, 768)]:
		for auto_gas in [true, false]:
			for easy in [true, false]:
				for layout in ["default", "swapped"]:
					Settings.values.controls.touch_auto_accelerate = auto_gas
					Settings.values.controls.easy_drift = easy
					Settings.values.controls.touch_layout = layout
					tc.size = sz
					tc._layout()
					var vis := tc.buttons.filter(func(b: TouchControls.TouchButton) -> bool: return b.visible)
					for i in vis.size():
						for j in range(i + 1, vis.size()):
							var a: TouchControls.TouchButton = vis[i]
							var b: TouchControls.TouchButton = vis[j]
							check(a.center.distance_to(b.center) >= a.radius + b.radius,
								"%s / %s apart (%s gas %s easy %s %s)" % [a.id, b.id, sz, auto_gas, easy, layout])
	var nitro := tc.get_button("nitro")
	check(nitro.visible, "nitro shown when owned")


func test_camera_switch_under_top_right_column() -> void:
	await _race({"mode": "quick", "series": "cup", "cup_race": 0, "ai_count": 0}, false)
	for i in 4:
		await tree.process_frame
	var hud = race.hud
	hud.best_label.text = "Ən yaxşı dövr 1:01.200"
	hud.delta_pill.visible = true
	for i in 3:
		await tree.process_frame
	var cam: TouchControls.TouchButton = hud.touch.get_button("camera")
	var col_bottom: float = hud._tr_box.get_global_rect().end.y - hud.touch.get_global_rect().position.y
	check(hud.series_pill.visible, "cup pill shown")
	check(cam.center.y - cam.radius >= col_bottom, "camera (top %.0f) below the column (%.0f)" % [cam.center.y - cam.radius, col_bottom])
	var item: TouchControls.TouchButton = hud.touch.get_button("item")
	check(cam.center.distance_to(item.center) >= cam.radius + item.radius, "camera clear of ITEM")


## Gap (m) between a landmark's turned footprint and the road + run-off.
func _gap(td: TrackData, n: Node3D) -> float:
	var mesh: Mesh = n.mesh if n is MeshInstance3D else (n.get_node("Near") as MeshInstance3D).mesh
	var bb := mesh.get_aabb()
	var xf := n.global_transform
	var gap := INF
	for i in 7:
		for j in 7:
			var q: Vector3 = xf * Vector3(lerpf(bb.position.x, bb.end.x, i / 6.0), 0, lerpf(bb.position.z, bb.end.z, j / 6.0))
			var c := td.main.closest(Vector3(q.x, 0, q.z))
			gap = minf(gap, c.distance - td.main.half_width_at(c.s) - td.offroad_width)
	return gap


func _landmarks_by_road(track_id: String, ids: Array, max_gap: float) -> void:
	await _race({"track_id": track_id})
	for id in ids:
		check(race.decor.landmarks.has(id), "%s placed on %s" % [id, track_id])
		if race.decor.landmarks.has(id):
			var g := _gap(race.track, race.decor.landmarks[id])
			check(g > 0.0 and g <= max_gap, "%s beside the road on %s (%.1f m)" % [id, track_id, g])


func test_seafront_landmarks_beside_road() -> void:
	await _landmarks_by_road("seafront_sprint", ["flag_square", "flame_towers", "crescent", "government_house",
		"carpet_museum", "port_baku", "tv_tower", "maiden_tower"], 11.0)
	# West-to-east order along the bay kept.
	var lm: Dictionary = race.decor.landmarks
	check(lm.flag_square.position.x < lm.carpet_museum.position.x and lm.carpet_museum.position.x < lm.government_house.position.x
		and lm.government_house.position.x < lm.crescent.position.x, "west-to-east order")


func test_downtown_landmarks_beside_road() -> void:
	await _landmarks_by_road("downtown_towers", ["philharmonic", "city_hall", "ismailiyya", "flame_towers"], 8.0)
	check(_gap(race.track, race.decor.landmarks.fountain_plaza) <= 12.0, "Fountain Square near the avenue")
	check(race.decor.nizami_buildings >= 12, "Nizami street still lined (%d)" % race.decor.nizami_buildings)
	check(race.decor.landmarks.flame_towers.get_node("Near") != null, "Flame Towers near model")


func test_old_city_landmarks_beside_road() -> void:
	await _landmarks_by_road("old_city", ["maiden_tower", "flame_towers", "shirvanshah", "juma_mosque", "siniqqala", "caravanserai"], 8.0)
	var houses := 0
	for ch in race.decor.get_children():
		if ch is MultiMeshInstance3D and ch.has_meta("instance_xforms") and String(ch.get_meta("prop")).begins_with("house_"):
			houses += (ch.get_meta("instance_xforms") as Array).size()
	check(houses > 200 and houses <= 300, "house count kept (%d, 0.17.2: 299)" % houses)


func test_softer_windows() -> void:
	check(float(TimeOfDay.params("sunset").windows) <= 0.3, "sunset windows dimmer")
	check(float(TimeOfDay.params("night").windows) >= 0.99, "night keeps the switch at 1")
	var src := FileAccess.get_file_as_string("res://assets/materials/prop_baked.gdshader")
	check(src.contains("lit_share = 0.38") and src.contains("pane"), "baked props: fewer, smaller lit panes")
	var sky := FileAccess.get_file_as_string("res://assets/materials/skyscraper.gdshader")
	check(sky.contains("step(0.7, hash2(cell))") and sky.contains("pane"), "towers: fewer, smaller lit panes")
	for id in TrackDecor.FULL_LOD_PROPS:
		check(PropKit.get_mesh(id) != null, "%s full far model" % id)
