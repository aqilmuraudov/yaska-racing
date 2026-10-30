extends TestCase
## Round 11 (0.9.3): tilted 3D minimap, heading-up, clear kart markers.

var _win := Vector2i.ZERO


func before_each() -> void:
	_win = tree.root.size


func after_each() -> void:
	tree.root.size = _win


func _race() -> RaceManager:
	var cfg := Game.default_race_config()
	cfg.laps = 1
	cfg.ai_count = 5
	Game.race_config = cfg
	var race: RaceManager = load("res://scripts/racing/race_manager.gd").new()
	race.headless_test = true
	tree.root.add_child(race)
	return race


func test_marker_mapping() -> void:
	var race := _race()
	await tree.process_frame
	var mm := MinimapWidget.new()
	mm.size = Vector2(250, 180)
	tree.root.add_child(mm)
	mm.setup(race)
	mm.set_process(false)
	var rect := Rect2(Vector2.ZERO, mm.size)
	var pk := race.player.kart
	# Radar: player sits at the lower-centre anchor; nearby track is in view.
	check(mm.map(pk.global_position).distance_to(mm.anchor()) < 0.5, "player at anchor")
	check(mm.anchor().y > mm.size.y * 0.55, "player in lower part")
	var near_in := 0
	for p in race.track.main.points:
		if p.distance_to(pk.global_position) < 40.0:
			near_in += int(rect.has_point(mm.map(p)))
	check(near_in > 0, "local track visible")
	# Zoom: 50 m ahead spans a big part of the panel height.
	mm.heading = mm._target_heading()
	var up := mm.map(pk.global_position + pk.forward_dir() * 50.0)
	check(mm.anchor().y - up.y > mm.size.y * 0.25, "zoomed in (~160 m view)")
	# Far rival clamps to the edge.
	var far := mm.map(pk.global_position + pk.forward_dir() * 500.0)
	var e := mm.edge_point(far)
	check(not rect.grow(-1).has_point(far), "far point off view")
	var pts: Array[Vector2] = [mm.anchor()]
	var d1 := mm.declutter(mm.anchor() + Vector2(2, 1), pts)
	check(d1.distance_to(mm.anchor()) >= MinimapWidget.DOT_R * 1.5, "packed marker nudged off player")
	check(rect.has_point(e) and (e.y <= MinimapWidget.EDGE + 0.5), "edge arrow on top edge")
	# Heading-up: a point ahead of the player is drawn above it.
	mm.heading = mm._target_heading()
	var a := mm.map(pk.global_position)
	var b := mm.map(pk.global_position + pk.forward_dir() * 10.0)
	check(b.y < a.y - 1.0, "forward is up")
	check(absf(b.x - a.x) < absf(b.y - a.y) * 0.2, "straight up")
	# Right of the player draws to the right.
	var r := mm.map(pk.global_position + pk.right_dir() * 10.0)
	check(r.x > a.x + 1.0, "right is right")
	# Same world position → same pixel; further apart → further apart.
	check(mm.map(pk.global_position).is_equal_approx(a), "stable")
	var c := mm.map(pk.global_position + pk.forward_dir() * 20.0)
	check(a.distance_to(c) > a.distance_to(b), "distance preserved in order")
	# Far rows smaller (perspective).
	check(mm.depth_scale(Vector2(0, 10)) < mm.depth_scale(Vector2(0, 170)), "near markers bigger")
	check_eq(mm.nearest_rivals(2).size(), 2, "two nearest rivals labelled")
	check(not race.player in mm.nearest_rivals(5), "player not a rival")
	mm.queue_free()
	race.queue_free()
	await tree.process_frame


func test_minimap_clear_of_controls() -> void:
	var race := _race()
	await tree.process_frame
	for sz in [Vector2(1100, 720), Vector2(1280, 720), Vector2(1560, 720), Vector2(1600, 720), Vector2(1280, 960)]:
		tree.root.size = Vector2i(sz)
		var hud := RaceHUD.new()
		tree.root.add_child(hud)
		hud.setup(race)
		for touch_layout in [true, false]:
			hud.place_minimap(touch_layout)
			hud.touch.visible = touch_layout
			for i in 6:
				await tree.process_frame
			var mr := hud.minimap.get_global_rect()
			check(mr.size.x >= 240.0, "bigger map at %s" % sz)
			check(hud.minimap.get_viewport_rect().encloses(mr), "map on screen at %s touch=%s" % [sz, touch_layout])
			for btn in hud.touch.buttons:
				if btn.visible and touch_layout:
					var br := Rect2(hud.touch.global_position + btn.center - Vector2.ONE * btn.radius, Vector2.ONE * btn.radius * 2.0)
					check(not mr.intersects(br), "map clear of %s at %s touch=%s (%s vs %s)" % [btn.id, sz, touch_layout, mr, br])
			for w in [hud.speed_gauge, hud.drift_meter, hud.pos_badge]:
				if w.visible:
					check(not mr.intersects(w.get_global_rect()), "map clear of %s at %s touch=%s" % [w.name, sz, touch_layout])
		hud.queue_free()
		await tree.process_frame
	race.queue_free()
	await tree.process_frame
