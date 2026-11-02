extends TestCase
## Round 14 (0.9.6): soft shadows tied to presets, Baku ambiance pieces.

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
	cfg.seed = 14
	cfg.active_seed = 14
	cfg.event_instance_id = "test-r14"
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame
	var n := 0
	while (race.state != RaceManager.RaceState.RACING or race.race_time < 0.3) and n < 4000:
		await tree.physics_frame
		n += 1


func test_baku_extras_present() -> void:
	await _start()
	var d: TrackDecor = race.decor
	check(d.landmarks.has("tv_tower"), "TV tower placed")
	check(d.landmarks.has("crystal_hall"), "Crystal Hall placed")
	check(d.get_node_or_null("CaspianHorizon") != null, "oil platforms / ships on the horizon")
	var signs := 0
	var flags := 0
	for c in d.get_children():
		if c.is_in_group("street_sign"):
			signs += 1
			var has_az := false
			for l in c.get_children():
				if l is Label3D and String(l.text) in TrackDecor.STREET_NAMES:
					has_az = true
			check(has_az, "sign has an Azerbaijani street name")
		elif c.is_in_group("flag_pole"):
			flags += 1
	check(signs >= 3, "street signs placed (%d)" % signs)
	check(flags >= 5, "flag poles on the promenade (%d)" % flags)
	# Landmarks stay off the playable corridor (full check in round 4). 0.17.3:
	# their own plots are reserved now, so test the footprint against the road.
	for id in ["tv_tower", "crystal_hall"]:
		var n: Node3D = d.landmarks[id]
		var mesh: Mesh = (n.get_node("Near") as MeshInstance3D).mesh
		check(d.footprint_clear_of_road(n.global_position, n.rotation.y, mesh.get_aabb(), 3.6), "%s away from the road" % id)


func test_soft_shadows_per_preset() -> void:
	await _start()
	var env: RaceEnvironment = race.environment
	Settings.apply_preset("low", false)
	check(not env.sun.shadow_enabled, "low: blob shadows only")
	check(env.blob_shadows_enabled, "low: blob contact shadows on")
	Settings.apply_preset("medium", false)
	check(env.sun.shadow_enabled, "medium: real-time shadows")
	check_eq(env.sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "medium: 2 splits")
	Settings.apply_preset("high", false)
	check_eq(env.sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "high: 4 splits")
	check(env.sun.directional_shadow_max_distance >= 100.0, "high: longer shadow distance")
	check_eq(RaceEnvironment.SHADOW_FILTER.size(), 4, "a soft filter level per shadow setting")
	check(env.sun.shadow_normal_bias >= 1.0 and env.sun.shadow_bias > 0.0, "bias set against acne")
	check_eq(env.env.tonemap_mode, Environment.TONE_MAPPER_ACES, "ACES tonemapping")
