extends TestCase
## Round 31 (0.17.0, owner: "mini Baku" on every map): the Old City's own
## landmarks (Shirvanshahs' Palace, Juma Mosque, Sınıqqala, caravanserai) and
## the historic centre in Göydələnlər (Philharmonic, City Hall, Ismailiyya,
## Fountain Square, Flame Towers on the western hill) as Blender models in
## their real relative places, clear of the road and of the houses / towers.

const ICHERI := ["shirvanshah", "juma_mosque", "siniqqala", "caravanserai"]
const CENTRE := ["philharmonic", "city_hall", "ismailiyya", "fountain_tiered", "fountain_spheres", "fountain_plaza"]
const TEST_SETTINGS := "user://test_settings_r31.json"
const TEST_PROFILE := "user://test_profile_r31.json"
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


func after_each() -> void:
	if is_instance_valid(race):
		race.queue_free()
	await tree.process_frame
	SafeFile.delete_all(TEST_SETTINGS)
	Settings.save_path = _orig_settings_path
	Settings.values = _orig_settings
	SafeFile.delete_all(TEST_PROFILE)
	SaveManager.save_path = _orig_profile_path
	SaveManager.load_profile()
	Game.race_config = Game.default_race_config()


func test_models_exist() -> void:
	for id in ICHERI + CENTRE:
		check(ResourceLoader.exists(String(PropKit.GLTF_PROPS[id]) + ".glb"), "glb " + id)
		check(ResourceLoader.exists(String(PropKit.GLTF_PROPS[id]) + "_far.glb"), "far glb " + id)
		var m := PropKit.get_mesh(id)
		check(m != null and m.get_surface_count() > 0, "mesh " + id)
		var lo := PropKit.get_mesh(id + PropKit.LO_SUFFIX)
		check(lo != null and lo.get_aabb().size.length() > 1.0, "far mesh " + id)


func _half_diag(id: String) -> float:
	var bb := PropKit.get_mesh(id).get_aabb()
	return maxf(Vector2(bb.position.x, bb.position.z).length(), Vector2(bb.end.x, bb.end.z).length())


func test_footprints_fit_reservations() -> void:
	for l: Array in OldCityDecor.OC_LANDMARKS:
		check(_half_diag(l[0]) <= float(l[4]) + 0.5, "%s fits its %.0f m plot (%.1f)" % [l[0], l[4], _half_diag(l[0])])
	for c: Array in DowntownDecor.CENTRE:
		check(_half_diag(c[0]) <= float(c[4]) + 0.5, "%s fits its %.0f m plot (%.1f)" % [c[0], c[4], _half_diag(c[0])])
	check(_half_diag("fountain_plaza") <= 34.5, "Fountain Square plaza fits")


func test_shapes_read_right() -> void:
	# Minarets stand tall over their halls; domes and towers where photos show them.
	check(PropKit.get_mesh("juma_mosque").get_aabb().end.y > 22.0, "Juma minaret ~24 m")
	check(PropKit.get_mesh("siniqqala").get_aabb().end.y > 22.0, "Sınıqqala minaret over the hall")
	check(PropKit.get_mesh("shirvanshah").get_aabb().end.y > 20.0, "Shah mosque minaret")
	check(PropKit.get_mesh("caravanserai").get_aabb().end.y < 11.0, "caravanserai stays low")
	check(PropKit.get_mesh("philharmonic").get_aabb().end.y > 27.0, "Philharmonic towers with finials")
	check(PropKit.get_mesh("city_hall").get_aabb().end.y > 33.0, "City Hall clock tower + flag")
	check(PropKit.get_mesh("ismailiyya").get_aabb().size.x > 36.0, "Ismailiyya long Gothic front")
	check(PropKit.GLTF_PROPS["philharmonic"].begins_with("res://assets/models/center"), "centre set")
	check(PropKit.PROP_GLOW.has("res://assets/models/icheri") and PropKit.PROP_GLOW.has("res://assets/models/center"),
		"lit windows at night")


func _race(track_id: String) -> void:
	var cfg := Game.default_race_config()
	cfg.track_id = track_id
	cfg.laps = 1
	cfg.seed = 31
	cfg.active_seed = 31
	cfg.event_instance_id = "test-r31"
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame


## No instance of `props` stands inside a landmark's plot.
func _no_overlap(decor: TrackDecor, plots: Array, props: Array) -> void:
	for id in props:
		for x: Transform3D in decor.instance_transforms(id):
			for pl: Array in plots:
				var d := Vector2(x.origin.x - pl[0].x, x.origin.z - pl[0].z).length()
				check(d >= pl[1] - 0.5, "%s clear of %s (%.1f m)" % [id, pl[2], d])


func _clear_of_road(td: TrackData, node: Node3D, id: String) -> void:
	var bb: AABB = node.transform * PropKit.get_mesh(id).get_aabb()
	for corner in [bb.position, Vector3(bb.end.x, 0, bb.position.z), Vector3(bb.position.x, 0, bb.end.z), bb.end]:
		var c := td.main.closest(Vector3(corner.x, 0, corner.z))
		check(c.distance > td.main.half_width_at(c.s) + td.offroad_width, "%s corner off the road (%.1f m)" % [id, c.distance])


func test_old_city_landmarks_placed() -> void:
	await _race("old_city")
	var decor = race.decor
	check(decor is OldCityDecor, "Old City decor")
	var plots := []
	for l: Array in OldCityDecor.OC_LANDMARKS:
		check(decor.landmarks.has(l[0]), "%s placed" % l[0])
		if decor.landmarks.has(l[0]):
			var n: Node3D = decor.landmarks[l[0]]
			check(decor.find_child(String(l[5]) + "Far", false, false) != null, "%s far model" % l[0])
			_clear_of_road(race.track, n, l[0])
			plots.append([n.position, float(l[4]), l[0]])
	_no_overlap(decor, plots, ["house_a", "house_b", "house_c", "house_d"])
	check(decor.landmarks.has("maiden_tower"), "Maiden Tower kept")
	# Real relative layout: palace north-west, caravanserai north of the tower.
	var tower: Vector3 = decor.landmarks.maiden_tower.position
	var palace: Vector3 = decor.landmarks.shirvanshah.position
	check(palace.x < tower.x and palace.z < tower.z, "palace north-west of the Maiden Tower")
	check(decor.landmarks.caravanserai.position.z < tower.z, "caravanserai north of the tower")


func test_downtown_centre_placed() -> void:
	await _race("downtown_towers")
	var decor = race.decor
	check(decor is DowntownDecor, "downtown decor")
	check_eq(decor.malls_placed, 4, "four malls still placed")
	var plots := []
	for c: Array in DowntownDecor.CENTRE:
		check(decor.landmarks.has(c[0]), "%s placed" % c[0])
		if decor.landmarks.has(c[0]):
			var n: Node3D = decor.landmarks[c[0]]
			_clear_of_road(race.track, n, c[0])
			plots.append([n.position, float(c[4]), c[0]])
	for id in ["fountain_plaza", "fountain_tiered", "fountain_spheres", "flame_towers"]:
		check(decor.landmarks.has(id), "%s placed" % id)
	plots.append([DowntownDecor.FOUNTAIN_SQUARE, 34.0, "Fountain Square"])
	_no_overlap(decor, plots, CityKit.TOWERS + ["block9_a", "block9_b", "block9_c", "mall_28", "port_baku",
		"park_bulvar", "ganjlik_mall"])
	# West to east as in Baku: Philharmonic, City Hall, Ismailiyya.
	var xs: Array = []
	for id in ["philharmonic", "city_hall", "ismailiyya"]:
		xs.append(decor.landmarks[id].position.x)
	check(xs[0] < xs[1] and xs[1] < xs[2], "west-to-east order")
	check(decor.towers_placed >= 50, "still a city of towers (%d)" % decor.towers_placed)
