extends TestCase
## Boost stacking limits, cancellation and drift timing rules.

func _stats() -> KartStats:
	return KartFactory.load_stats("balanced")


func test_boost_bank_and_bonus_are_capped() -> void:
	var b := KartBoost.new()
	b.configure(_stats())
	for i in 20:
		b.add(7.0 + i, 1.0, &"drift")
	check(b.time_left <= b.max_stored + 0.0001, "bank capped at max_stored")
	check(b.bonus <= b.max_bonus + 0.0001, "bonus capped at max_bonus")


func test_strongest_source_not_sum() -> void:
	var b := KartBoost.new()
	b.configure(_stats())
	b.add(6.0, 0.5, &"drift")
	b.add(4.0, 0.5, &"pad")
	check_near(b.bonus, 6.0, 0.001, "bonus is the strongest active, not 10")
	b.add(9.0, 0.5, &"item")
	check_near(b.bonus, 9.0, 0.001, "stronger source raises bonus")


func test_cancel_and_expiry() -> void:
	var b := KartBoost.new()
	b.configure(_stats())
	b.add(6.0, 0.4, &"drift")
	b.cancel()
	check(not b.is_active(), "cancel empties the bank")
	check_eq(b.bonus, 0.0, "cancel resets bonus")
	b.add(6.0, 0.3, &"drift")
	for i in 30:
		b.tick(1.0 / 60.0)
	check(not b.is_active(), "boost expires after its duration")


func test_offroad_halves_bonus() -> void:
	var b := KartBoost.new()
	b.configure(_stats())
	b.add(8.0, 1.0, &"pad")
	check_near(b.effective_bonus(true), 4.0, 0.001, "off-road halves the bonus")
	check_near(b.effective_bonus(false), 8.0, 0.001, "road keeps full bonus")


func test_kart_speed_never_exceeds_absolute_cap() -> void:
	var world := Node3D.new()
	tree.root.add_child(world)
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000, 1, 4000)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)
	world.add_child(floor_body)
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
	world.add_child(kart)
	kart.place_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)))
	kart.controls_locked = false
	var max_seen := 0.0
	for i in 400:
		kart.input.throttle = 1.0
		if i % 20 == 0:
			kart.apply_item_boost()
			kart.apply_boost_pad()
			kart.apply_start_boost(1.0)
		await tree.physics_frame
		max_seen = maxf(max_seen, kart.speed)
	check(max_seen <= kart.max_speed_absolute() + 0.01, "speed %.2f <= absolute cap %.2f" % [max_seen, kart.max_speed_absolute()])
	check(max_seen > kart.stats.top_speed, "boosts do push above normal top speed")
	# Hits cancel boosts.
	kart.apply_item_boost()
	kart.apply_hit(&"trap")
	check(not kart.boost.is_active(), "hit cancels boost")
	world.queue_free()


func test_drift_window_boost_and_tiers() -> void:
	var d := DriftMeter.new()
	d.configure(_stats())
	d.start()
	# Fill to inside the window but before perfect.
	while d.meter < d.window_start + 0.05:
		d.tick(1.0 / 60.0)
	var r := d.press()
	check_eq(r.result, DriftMeter.Result.BOOST, "press in window boosts")
	check_eq(r.tier, 1, "first tier")
	check(not r.perfect, "not perfect before perfect zone")
	while d.meter < d.perfect_start + 0.01:
		d.tick(1.0 / 60.0)
	r = d.press()
	check(r.perfect, "perfect zone detected")
	check_eq(r.tier, 2, "second tier")
	while d.meter < d.window_start + 0.02:
		d.tick(1.0 / 60.0)
	r = d.press()
	check_eq(r.tier, 3, "third tier")
	for i in 120:
		d.tick(1.0 / 60.0)
	r = d.press()
	check_eq(r.result, DriftMeter.Result.NONE, "no more than three boosts per drift")


func test_drift_early_press_is_light_miss() -> void:
	var d := DriftMeter.new()
	d.configure(_stats())
	d.start()
	for i in 10:
		d.tick(1.0 / 60.0)
	var r := d.press()
	check_eq(r.result, DriftMeter.Result.MISS, "early press misses")
	check_eq(d.chain, 0, "chain kept (not reduced)")
	check_eq(d.meter, 0.0, "meter restarts")
	var pressed_during_cooldown := d.press()
	check_eq(pressed_during_cooldown.result, DriftMeter.Result.NONE, "short cooldown, no double penalty")


func test_drift_overheat_miss() -> void:
	var d := DriftMeter.new()
	d.configure(_stats())
	d.start()
	var missed := false
	for i in 200:
		if d.tick(1.0 / 60.0) == DriftMeter.Result.MISS:
			missed = true
			break
	check(missed, "holding at full meter overheats into a miss")
