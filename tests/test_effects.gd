extends TestCase
## Quality-dependent effects stay within their budgets.

func test_skid_marks_respect_density_budget() -> void:
	var world := Node3D.new()
	tree.root.add_child(world)
	var kart := KartController.new()
	kart.stats = KartFactory.load_stats("balanced")
	world.add_child(kart)
	var marks := SkidMarks.new()
	world.add_child(marks)
	marks.setup([kart])
	marks.set_density(0.0)
	check_eq(marks._budget, 0, "Low density disables tyre marks")
	marks.set_density(0.5)
	var half := marks._budget
	marks.set_density(1.0)
	check(marks._budget > half and half > 0, "budget scales with density")
	# Fake a long drift by driving the kart forward while 'drifting'.
	kart.state = KartController.State.DRIFT
	kart.grounded = true
	kart.speed = 20.0
	kart.set_physics_process(false)
	marks.set_density(0.3)
	for i in 3000:
		kart.global_position += kart.forward_dir() * 0.5
		marks._physics_process(1.0 / 60.0)
	var total := 0
	for strip in marks._strips:
		total += strip.size()
	check(total <= marks._budget, "points %d within budget %d" % [total, marks._budget])
	marks.clear()
	check_eq(marks._strips.size(), 0, "clear() empties every trail (restart)")
	world.queue_free()
