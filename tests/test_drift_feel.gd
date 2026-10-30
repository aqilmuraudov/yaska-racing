extends TestCase
## 0.7.0 drift: subtle hop, a controllable slip angle (counter-steer closes
## it), speed mostly kept, no side-to-side body wobble. Flat open floor,
## stepped manually at 60 Hz.

const DT := 1.0 / 60.0


func _setup() -> Array:
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
	var kart := KartFactory.create("havhav", false, 0.0)
	world.add_child(kart)
	kart.place_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	kart.controls_locked = false
	kart.set_physics_process(false)
	await tree.physics_frame
	return [world, kart]


func _tick(kart: KartController, steer: float, drift: bool, was_drift: bool) -> void:
	kart.input.throttle = 1.0
	kart.input.steer = steer
	kart.input.drift_held = drift
	kart.input.drift_pressed = drift and not was_drift
	kart._physics_process(DT)


func test_slip_angle_is_controllable_and_smooth() -> void:
	var s: Array = await _setup()
	var kart: KartController = s[1]
	check(kart.stats.hop_impulse <= 3.5, "hop is subtle (%.1f)" % kart.stats.hop_impulse)
	for i in 180:
		_tick(kart, 0.0, false, false)
	var v0 := kart.speed
	var y0 := kart.global_position.y
	var max_y := 0.0
	var was := false
	var t := 0
	while not kart.is_drifting() and t < 60:
		_tick(kart, 1.0, true, was)
		was = true
		max_y = maxf(max_y, kart.global_position.y - y0)
		t += 1
	check(kart.is_drifting(), "drift starts from steer + drift")
	check(max_y < 0.3, "hop stays low (%.2f m)" % max_y)
	for i in 45:
		_tick(kart, 1.0, true, true)
	var open := absf(kart.drift_slip)
	check(open > deg_to_rad(18.0), "rear slides out (%.1f°)" % rad_to_deg(open))
	var prev := kart.drift_slip
	var max_step := 0.0
	var flipped := false
	for i in 45:
		_tick(kart, -1.0, true, true) # counter-steer
		max_step = maxf(max_step, absf(kart.drift_slip - prev))
		if signf(kart.drift_slip) != signf(prev):
			flipped = true
		prev = kart.drift_slip
	check(kart.is_drifting(), "counter-steer keeps the drift")
	check(absf(kart.drift_slip) < open * 0.6, "counter-steer reduces the slip (%.1f° → %.1f°)" % [rad_to_deg(open), rad_to_deg(absf(kart.drift_slip))])
	check(not flipped, "body never swings to the other side")
	check(max_step < deg_to_rad(1.5), "slip changes smoothly (max %.2f° per tick)" % rad_to_deg(max_step))
	check(kart.speed > v0 * 0.9, "speed mostly kept (%.1f → %.1f)" % [v0, kart.speed])
	for i in 90:
		_tick(kart, 0.0, false, true)
	check(absf(kart.drift_slip) < deg_to_rad(3.0), "grip returns after release (%.1f°)" % rad_to_deg(absf(kart.drift_slip)))
	s[0].queue_free()
	await tree.process_frame


func test_body_roll_is_subtle() -> void:
	var s: Array = await _setup()
	var kart: KartController = s[1]
	var visual: KartVisual = kart.get_meta("visual")
	visual.set_physics_process(false)
	for i in 180:
		_tick(kart, 0.0, false, false)
		visual._physics_process(DT)
	var was := false
	var max_roll := 0.0
	var flips := 0
	var prev := 0.0
	for i in 150:
		# Touch-style digital steering that flickers inside the drift.
		_tick(kart, 1.0 if (i / 10) % 2 == 0 else 0.3, true, was)
		was = true
		visual._physics_process(DT)
		max_roll = maxf(max_roll, absf(visual._roll))
		if i > 30 and signf(visual._roll) != signf(prev) and absf(visual._roll) > 0.002:
			flips += 1
		prev = visual._roll
	check(max_roll < deg_to_rad(5.0), "lean stays subtle (%.1f°)" % rad_to_deg(max_roll))
	check_eq(flips, 0, "no side-to-side wobble while drifting")
	s[0].queue_free()
	await tree.process_frame
