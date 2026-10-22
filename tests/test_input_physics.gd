extends TestCase
## Simultaneous touch input, interruption handling and frame-rate
## independence of the vehicle simulation.

func _make_touch() -> TouchControls:
	var pi := PlayerInput.new()
	tree.root.add_child(pi)
	var tc := TouchControls.new()
	tc.size = Vector2(1280, 720)
	tree.root.add_child(tc)
	tc.setup(pi)
	tc.size = Vector2(1280, 720)
	tc._layout()
	tc.visible = true
	return tc


func _release_all_actions() -> void:
	for a in InputActions.GAMEPLAY_ACTIONS:
		Input.action_release(a)


func test_simultaneous_touches() -> void:
	_release_all_actions()
	var tc := _make_touch()
	var left := tc.get_button("steer_left")
	var drift := tc.get_button("drift")
	var boost := tc.get_button("boost")
	var item := tc.get_button("item")
	tc.handle_touch(0, left.center, true)
	tc.handle_touch(1, drift.center, true)
	tc.handle_touch(2, boost.center, true)
	tc.handle_touch(3, item.center, true)
	check(Input.is_action_pressed(InputActions.STEER_LEFT), "steer held")
	check(Input.is_action_pressed(InputActions.DRIFT), "drift held at the same time")
	check(Input.is_action_pressed(InputActions.BOOST), "boost held at the same time")
	check(Input.is_action_pressed(InputActions.USE_ITEM), "item held at the same time")
	tc.handle_touch(2, boost.center, false)
	check(not Input.is_action_pressed(InputActions.BOOST), "releasing one finger releases only its button")
	check(Input.is_action_pressed(InputActions.DRIFT), "other fingers unaffected")
	# Slide the steering finger onto the right button.
	tc.handle_drag(0, tc.get_button("steer_right").center)
	check(not Input.is_action_pressed(InputActions.STEER_LEFT), "slide releases left")
	check(Input.is_action_pressed(InputActions.STEER_RIGHT), "slide presses right")
	# Interruption (focus loss) releases everything.
	tc.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	for a in [InputActions.STEER_RIGHT, InputActions.DRIFT, InputActions.USE_ITEM]:
		check(not Input.is_action_pressed(a), "%s released on focus loss" % a)
	tc.queue_free()
	_release_all_actions()


func test_touch_layout_fits_wide_and_16_9_screens() -> void:
	var tc := _make_touch()
	for sz in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1560, 720)]:
		tc.size = sz
		tc._layout()
		for b in tc.buttons:
			if not b.visible:
				continue
			var inside: bool = b.center.x - b.radius >= 0.0 and b.center.x + b.radius <= sz.x and b.center.y - b.radius >= 0.0 and b.center.y + b.radius <= sz.y
			check(inside, "%s fully on screen at %s" % [b.id, sz])
		# No two visible buttons overlap.
		for i in tc.buttons.size():
			for j in range(i + 1, tc.buttons.size()):
				var a = tc.buttons[i]
				var c = tc.buttons[j]
				if a.visible and c.visible:
					check(a.center.distance_to(c.center) >= a.radius + c.radius - 2.0, "%s and %s do not overlap at %s" % [a.id, c.id, sz])
	tc.queue_free()


## The kart's state after N physics ticks must not depend on how many
## render frames (and _process calls) happened in between.
func test_simulation_independent_of_render_frames() -> void:
	var results: Array = []
	for variant in 2:
		var world := Node3D.new()
		tree.root.add_child(world)
		var floor_body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2000, 1, 2000)
		cs.shape = box
		cs.position = Vector3(0, -0.5, 0)
		floor_body.add_child(cs)
		world.add_child(floor_body)
		var kart := KartFactory.create("balanced", 0, false, 0.0)
		world.add_child(kart)
		kart.place_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
		kart.controls_locked = false
		kart.set_physics_process(false) # step manually
		var visual: KartVisual = kart.get_meta("visual")
		visual.set_physics_process(false)
		await tree.physics_frame
		for tick in 240:
			kart.input.throttle = 1.0
			kart.input.steer = sin(tick * 0.05)
			kart.input.drift_pressed = tick == 60
			kart.input.drift_held = tick >= 60 and tick < 150
			kart.input.boost_pressed = tick == 120
			kart._physics_process(1.0 / 60.0)
			# Variant 1 renders 3 visual frames per tick, variant 0 none.
			if variant == 1:
				for k in 3:
					visual._physics_process(1.0 / 180.0)
					kart.get_meta("audio")._process(1.0 / 180.0)
		results.append([kart.global_position, kart.yaw, kart.speed])
		world.queue_free()
		await tree.process_frame
	check(results[0][0].distance_to(results[1][0]) < 0.001, "same position regardless of render frames (%s vs %s)" % [results[0][0], results[1][0]])
	check_near(results[0][1], results[1][1], 0.0001, "same heading")
	check_near(results[0][2], results[1][2], 0.0001, "same speed")


func test_physics_tick_is_fixed() -> void:
	check_eq(Engine.physics_ticks_per_second, 60, "fixed 60 Hz simulation")
	check(ProjectSettings.get_setting("physics/common/physics_interpolation"), "physics interpolation enabled for smooth visuals")
