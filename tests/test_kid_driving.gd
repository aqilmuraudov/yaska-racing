extends TestCase
## Child-friendly driving: nitro really covers more ground, Easy Drift,
## forgiving drift entry, edge steering help and predictable wall scraping.

var _world: Node3D


func _stats() -> KartStats:
	return KartFactory.load_stats("havhav")


func _flat_world(with_wall := false) -> Node3D:
	_world = Node3D.new()
	tree.root.add_child(_world)
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000, 1, 4000)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)
	_world.add_child(floor_body)
	if with_wall:
		# Barrier along -Z at x = 3 (the kart drives towards -Z).
		var wall := StaticBody3D.new()
		var wcs := CollisionShape3D.new()
		var wbox := BoxShape3D.new()
		wbox.size = Vector3(1, 2, 4000)
		wcs.shape = wbox
		wcs.position = Vector3(3.5, 1.0, 0)
		wall.add_child(wcs)
		_world.add_child(wall)
	return _world


func _kart() -> KartController:
	var kart := KartController.new()
	kart.stats = _stats()
	var kcs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.6
	cap.height = 2.0
	kcs.shape = cap
	kcs.rotation = Vector3(PI * 0.5, 0, 0)
	kcs.position = Vector3(0, 0.6, 0)
	kart.add_child(kcs)
	_world.add_child(kart)
	kart.place_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)))
	kart.controls_locked = false
	return kart


## Ground covered in `seconds`, measured from positions (not the speed value).
func _distance(kart: KartController, seconds: float) -> float:
	var p0 := kart.global_position
	var travelled := 0.0
	for i in int(round(seconds * 60.0)):
		kart.input.throttle = 1.0
		await tree.physics_frame
		var p := kart.global_position
		travelled += Vector2(p.x - p0.x, p.z - p0.z).length()
		p0 = p
	return travelled


func test_nitro_covers_more_ground_per_second() -> void:
	_flat_world()
	var kart := _kart()
	await _distance(kart, 5.0) # reach top speed
	var cruise: float = await _distance(kart, 1.0)
	kart.apply_item_boost()
	await _distance(kart, 0.25) # ramp up
	var nitro: float = await _distance(kart, 1.0)
	print("    nitro check: %.1f m/s cruising, %.1f m/s on nitro (x%.2f); readout %d → %d km/h" % [cruise, nitro, nitro / cruise, int(kart.stats.top_speed * 3.6), int((kart.stats.top_speed + kart.stats.item_boost_strength) * 3.6)])
	check(cruise > kart.stats.top_speed * 0.97, "cruise ground speed matches top speed (%.1f m/s)" % cruise)
	check(nitro >= cruise * 1.25, "nitro covers >= 25%% more ground per second (%.1f vs %.1f m)" % [nitro, cruise])
	check_near(nitro, absf(kart.speed), 1.0, "distance per second equals the speed shown")
	_world.queue_free()


func test_easy_drift_charges_without_overheat_and_boosts_on_release() -> void:
	var dm := DriftMeter.new()
	dm.configure(_stats())
	dm.easy = true
	dm.start()
	var missed := false
	for i in 60: # 1 s: beyond the window, past the old overheat time
		if dm.tick(1.0 / 60.0) == DriftMeter.Result.MISS:
			missed = true
	check(not missed, "no overheat miss while holding")
	check(dm.is_charged(), "charged after the meter fills")
	check_eq(dm.level(), 1, "charge level 1 when just full")
	for i in int(dm.charge_time * 60.0 * 2.0) + 2:
		dm.tick(1.0 / 60.0)
	check_eq(dm.level(), 3, "holding longer raises the charge to level 3")
	var r := dm.release()
	check_eq(r.result, DriftMeter.Result.BOOST, "letting go while charged boosts")
	check_eq(r.tier, 3, "boost tier = charge level")
	var early := DriftMeter.new()
	early.configure(_stats())
	early.easy = true
	early.start()
	early.tick(0.2)
	check_eq(early.release().result, DriftMeter.Result.NONE, "letting go too early is no boost and no penalty")


func test_late_steer_still_starts_drift_and_denial_is_reported() -> void:
	_flat_world()
	var kart := _kart()
	await _distance(kart, 3.0)
	var denied: Array = []
	kart.drift_denied.connect(func(r): denied.append(r))
	# Press and hold DRIFT with no steering: hop, land, then steer late.
	kart.input.drift_pressed = true
	kart.input.drift_held = true
	await tree.physics_frame
	kart.input.drift_pressed = false
	var landed_normal := false
	for i in 60:
		await tree.physics_frame
		if kart.state == KartController.State.NORMAL:
			landed_normal = true
			break
	check(landed_normal, "hop lands")
	await frames(6) # 0.1 s after landing, inside the grace window
	kart.input.steer = 0.6
	await frames(2)
	check_eq(kart.state, KartController.State.DRIFT, "late steering still starts the drift")
	check(denied.is_empty(), "no denial when the drift started")
	# Again without ever steering: the reason is reported.
	kart.input.drift_held = false
	kart.input.steer = 0.0
	await frames(30)
	kart.input.drift_pressed = true
	kart.input.drift_held = true
	await tree.physics_frame
	kart.input.drift_pressed = false
	await frames(60)
	check(denied.has(&"steer"), "holding DRIFT without steering reports 'steer'")
	_world.queue_free()


func test_edge_assist_only_near_edge_and_heading_out() -> void:
	check_eq(RaceManager.edge_assist(0.0, 0.3), 0.0, "no help in the middle of the road")
	check_eq(RaceManager.edge_assist(0.9, -0.2), 0.0, "no help when already heading away from the edge")
	var a := RaceManager.edge_assist(0.9, 0.2)
	check(a < -0.2, "near the right edge heading right: steer left (%.2f)" % a)
	check(RaceManager.edge_assist(-0.9, -0.2) > 0.2, "mirror on the left edge")
	check(absf(RaceManager.edge_assist(1.4, 1.0)) <= RaceManager.EDGE_ASSIST_MAX + 0.0001, "capped, the child can still steer")


func test_wall_scrape_is_predictable() -> void:
	_flat_world(true)
	var kart := _kart()
	await _distance(kart, 4.0)
	var v0 := kart.speed
	# Angle 8° into the barrier on the right and keep pushing for 1.5 s.
	kart.yaw -= deg_to_rad(8.0)
	var min_speed := v0
	for i in 90:
		kart.input.throttle = 1.0
		kart.input.steer = 0.6 # keeps steering into the barrier
		await tree.physics_frame
		min_speed = minf(min_speed, kart.speed)
	print("    wall scrape: %.1f → min %.1f m/s, end %.1f m/s" % [v0, min_speed, kart.speed])
	check(min_speed > v0 * 0.6, "scraping keeps most of the speed (min %.1f of %.1f)" % [min_speed, v0])
	_world.queue_free()


func test_star_field_player_collects_and_respawns() -> void:
	_flat_world()
	var kart := _kart()
	var track := TestCase.circle_track(60.0)
	var field := StarField.new()
	_world.add_child(field)
	field.build(track, kart, true)
	check_eq(field._positions.size(), StarField.GROUPS * StarField.PER_GROUP, "stars placed")
	var got: Array = []
	field.collected.connect(func(n): got.append(n))
	kart.global_position = field._positions[0] - Vector3.UP * 0.6
	await frames(2)
	check_eq(field.count, 1, "driving through a star collects it")
	check(not got.is_empty(), "collected signal for the HUD")
	await frames(2)
	check_eq(field.count, 1, "a collected star is gone (no double count)")
	kart.global_position = Vector3(0, 0.1, 0)
	field._respawn[0] = 0.01
	await frames(3)
	check(field._respawn[0] <= 0.0, "it comes back for the next lap")
	field.reset()
	check_eq(field.count, 0, "restart clears the race count")
	_world.queue_free()
