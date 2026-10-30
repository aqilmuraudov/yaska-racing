extends TestCase
## Round 15 (0.9.7): landmark fidelity pass, trees, shadows.

var race: RaceManager


func after_each() -> void:
	if is_instance_valid(race):
		race.queue_free()
		await tree.process_frame
	Settings.apply_preset("medium", false)


func _start() -> void:
	var cfg := Game.default_race_config()
	cfg.laps = 1
	cfg.ai_count = 0
	cfg.seed = 15
	cfg.active_seed = 15
	cfg.event_instance_id = "test-r15"
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame
	var n := 0
	while (race.state != RaceManager.RaceState.RACING or race.race_time < 0.3) and n < 4000:
		await tree.physics_frame
		n += 1



func test_props_and_walls() -> void:
	check(PropKit.get_mesh("pine") != null, "stone pine prop")
	check(PropKit.get_mesh("tree") != null, "plane tree prop")
	var w: Mesh = LandmarkKit.city_wall(48.0)
	check(w != null and w.get_aabb().size.y > 11.0, "city wall has towers above the parapet")


func test_horizon_and_landmarks() -> void:
	await _start()
	var d: TrackDecor = race.decor
	check(d.landmarks.has("caspian_horizon"), "horizon glance mark")
	for k in ["flame_towers", "heydar_aliyev", "maiden_tower", "government_house", "icherisheher_gate"]:
		check(d.landmarks.has(k), "landmark %s" % k)
	var sun: DirectionalLight3D = race.find_children("*", "DirectionalLight3D", true, false)[0]
	check(sun.shadow_opacity >= 0.99, "full-strength shadows")
