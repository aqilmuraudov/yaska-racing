extends TestCase
## Round 4 regressions (0.7.2): barriers never let a kart escape, off-track
## karts respawn, kart-kart contact never flips, grinding a wall is not
## "wrong way", and no landmark geometry hangs over the road.

var race: RaceManager
var _orig_profile_path := ""


func before_each() -> void:
	_orig_profile_path = SaveManager.save_path
	SaveManager.save_path = "user://test_profile_r4.json"
	Engine.time_scale = 4.0


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	if is_instance_valid(race):
		race.queue_free()
		await tree.process_frame
	SafeFile.delete_all("user://test_profile_r4.json")
	SaveManager.save_path = _orig_profile_path
	SaveManager.load_profile()


func _start(ai_count: int) -> void:
	var cfg := Game.default_race_config()
	cfg.laps = 3
	cfg.items = false
	cfg.ai_count = ai_count
	cfg.seed = 404
	cfg.active_seed = 404
	cfg.debug_autopilot = false
	cfg.event_instance_id = "test-r4"
	Game.race_config = cfg
	race = load("res://scenes/race/race.tscn").instantiate()
	race.headless_test = true
	tree.root.add_child(race)
	await tree.process_frame
	var n := 0
	while (race.state != RaceManager.RaceState.RACING or race.race_time < 0.3) and n < 4000:
		await tree.physics_frame
		n += 1
	for r in race.racers:
		_freeze_driver(r)


func _freeze_driver(r) -> void:
	if r.ai:
		r.ai.set_physics_process(false)
	if r.player_input:
		r.player_input.enabled = false
		r.player_input.set_physics_process(false)
		r.player_input.set_process(false)
	var inp: KartInput = r.kart.input
	inp.throttle = 0.0
	inp.steer = 0.0
	inp.brake = 0.0
	inp.drift_held = false


func _xform_at(s: float, lat: float, yaw_off: float, y_off: float = 0.6) -> Transform3D:
	var m: TrackPath = race.track.main
	var p := m.position_at(s) + m.right_at(s) * lat + Vector3.UP * y_off
	var t := m.tangent_at(s)
	var b := Basis(Vector3.UP, atan2(-t.x, -t.z) + yaw_off)
	return Transform3D(b, p)


func _place(k: KartController, xf: Transform3D) -> void:
	k.reset_for_race(xf)
	k.immunity_timer = 0.0


## (a) Max speed + drift straight into the barrier at many points on the lap,
## both sides: the kart must stay inside the barrier line and never fall.
func test_barriers_hold_at_max_speed_drift() -> void:
	await _start(0)
	var k: KartController = race.player.kart
	var tr: RaceTracker = race.player.tracker
	var m: TrackPath = race.track.main
	var wall_off := race.track.offroad_width + 0.6
	var escapes := 0
	var falls := 0
	var tried := 0
	var worst := -99.0
	var s := 10.0
	while s < m.length - 10.0:
		for side: float in [-1.0, 1.0]:
			tried += 1
			# Aim 40 deg into the wall on that side.
			_place(k, _xform_at(s, side * 1.0, -side * deg_to_rad(40.0)))
			await tree.physics_frame
			k.speed = k.stats.top_speed * 1.35
			k.input.throttle = 1.0
			k.input.steer = side
			k.input.drift_held = true
			k.input.drift_pressed = true
			var start_y := k.global_position.y
			var escaped := false
			for f in 75:
				await tree.physics_frame
				k.input.drift_pressed = false
				if k.state == KartController.State.RECOVER:
					break
				var proj := race.track.project(k.global_position, tr.s)
				var excess: float = float(proj.distance) - float(proj.half_width) - wall_off
				if int(proj.on_shortcut) < 0:
					worst = maxf(worst, excess)
					if excess > -0.2:
						escaped = true
				if k.global_position.y < start_y - 4.0:
					falls += 1
					escaped = true
					break
			if escaped:
				escapes += 1
				print("  escape at s=%.0f side=%d pos=%s" % [s, int(side), k.global_position])
		s += 45.0
	print("  barrier probes=%d escapes=%d worst excess=%.2f m" % [tried, escapes, worst])
	check(tried > 50, "probed the whole lap on both sides")
	check_eq(escapes, 0, "no kart escaped through a barrier")
	check_eq(falls, 0, "no kart fell off the course")


## (b) A kart off the track, or below it, respawns on the road within ~2 s.
func test_off_track_and_below_track_respawn() -> void:
	await _start(1)
	for r in race.racers:
		var k: KartController = r.kart
		var m: TrackPath = race.track.main
		var cases := [
			["beside", _xform_at(300.0, m.half_width_at(300.0) + race.track.offroad_width + 5.0, 0.0)],
			["below", _xform_at(900.0, 0.0, 0.0, -3.5)],
			["far_out", _xform_at(1200.0, -(m.half_width_at(1200.0) + race.track.offroad_width + 4.0), 0.0, 0.0)],
		]
		for c in cases:
			_place(k, c[1])
			r.oob_timer = 0.0
			var t := 0.0
			var started := false
			while t < 2.6:
				await tree.physics_frame
				t += 1.0 / Engine.physics_ticks_per_second
				if k.state == KartController.State.RECOVER:
					started = true
					break
			check(started, "%s %s: recover started (t=%.2f s)" % [r.name, c[0], t])
			check(t <= 2.0, "%s %s: within 2 s" % [r.name, c[0]])
			var n := 0
			while k.state == KartController.State.RECOVER and n < 400:
				await tree.physics_frame
				n += 1
			var proj := race.track.project(k.global_position)
			check(float(proj.distance) <= float(proj.half_width) + 0.5, "%s %s: respawned on the road" % [r.name, c[0]])
			var tan := race.track.route_tangent(k.global_position, proj)
			check(k.forward_dir().dot(tan) > 0.8, "%s %s: facing race direction" % [r.name, c[0]])


func _max_tilt_deg(k: KartController) -> float:
	var vis = k.get_meta("visual")
	var up: Vector3 = vis.body_pivot.global_transform.basis.y.normalized()
	var kup := k.global_transform.basis.y.normalized()
	return maxf(rad_to_deg(acos(clampf(up.y, -1.0, 1.0))), rad_to_deg(acos(clampf(kup.y, -1.0, 1.0))))


## (c) Side and rear kart-kart hits: no roll/pitch above 45 deg, no flip,
## no launch into the air.
func test_kart_contact_never_flips() -> void:
	await _start(1)
	var a: KartController = race.racers[0].kart
	var b: KartController = race.racers[1].kart
	var setups := [
		["side", 0.0, 2.6, 0.0, -2.6, 20.0, 20.0, 1.0, -1.0],
		["rear", 0.0, 0.0, 0.0, -0.0, 12.0, 30.0, 0.0, 0.0],
		["t-bone", 0.0, 3.0, deg_to_rad(80.0), 0.0, 18.0, 25.0, 0.0, 0.0],
	]
	for st in setups:
		var s0 := 420.0
		_place(a, _xform_at(s0, st[1], 0.0))
		var bs := s0 - 6.0 if st[0] == "rear" else s0
		_place(b, _xform_at(bs, st[2], st[3]))
		await tree.physics_frame
		a.speed = st[5]
		b.speed = st[6]
		a.input.throttle = 1.0
		b.input.throttle = 1.0
		a.input.steer = st[7]
		b.input.steer = st[8]
		var worst := 0.0
		var max_rise := 0.0
		var y0 := maxf(a.global_position.y, b.global_position.y)
		for f in 150:
			await tree.physics_frame
			worst = maxf(worst, maxf(_max_tilt_deg(a), _max_tilt_deg(b)))
			max_rise = maxf(max_rise, maxf(a.global_position.y, b.global_position.y) - y0)
		print("  contact %s: max tilt %.1f deg, max rise %.2f m" % [st[0], worst, max_rise])
		check(worst <= 45.0, "%s contact: tilt <= 45 deg (%.1f)" % [st[0], worst])
		check(max_rise < 1.0, "%s contact: no launch (%.2f m)" % [st[0], max_rise])
		check(a.global_transform.basis.y.y > 0.99 and b.global_transform.basis.y.y > 0.99, "%s contact: bodies upright" % st[0])


## (d) Pinned and grinding along a wall must not raise WRONG WAY.
func test_wall_grind_is_not_wrong_way() -> void:
	await _start(0)
	var k: KartController = race.player.kart
	var tr: RaceTracker = race.player.tracker
	var m: TrackPath = race.track.main
	var flagged := 0
	for s in [300.0, 880.0, 960.0, 1300.0]:
		for side: float in [-1.0, 1.0]:
			var lat: float = side * (m.half_width_at(s) + race.track.offroad_width - 0.6)
			# Nose 75 deg into the wall, crawling forward: classic pin.
			_place(k, _xform_at(s, lat, -side * deg_to_rad(75.0)))
			await tree.physics_frame
			k.input.throttle = 1.0
			k.input.steer = side
			for f in 240:
				await tree.physics_frame
				if tr.wrong_way:
					flagged += 1
					break
			k.input.steer = 0.0
	check_eq(flagged, 0, "no wrong-way while grinding a barrier")


## (e) Barrier ends and tight corners: the kart is pushed back onto the
## road, never rides up onto or into the barrier block.
func test_barrier_ends_and_corners_push_back() -> void:
	await _start(0)
	var k: KartController = race.player.kart
	var tr: RaceTracker = race.player.tracker
	var m: TrackPath = race.track.main
	var wall_face := race.track.offroad_width + 0.6 - 0.3
	# Ends: main-route segments whose neighbour is missing. Corners: sharp bends.
	var by_side := {-1.0: [], 1.0: []}
	for seg in race.builder.wall_segments:
		if int(seg.path) < 0:
			by_side[float(seg.side)].append(float(seg.s))
	var targets: Array = []
	for side: float in [-1.0, 1.0]:
		var list: Array = by_side[side]
		list.sort()
		for i in range(1, list.size()):
			if list[i] - list[i - 1] > 3.0:
				targets.append([list[i - 1], side]) # segment end before a gap
				targets.append([list[i], side]) # segment start after a gap
	var s := 0.0
	while s < m.length:
		if absf(m.curvature_at(s)) > 0.02:
			targets.append([s, signf(m.curvature_at(s))])
			targets.append([s, -signf(m.curvature_at(s))])
			s += 25.0
		s += 2.0
	check(targets.size() > 6, "found barrier ends/corners (%d)" % targets.size())
	var bad := 0
	for t in targets:
		var ts: float = t[0]
		var side: float = t[1]
		for ang in [25.0, 55.0]:
			_place(k, _xform_at(m.wrap_s(ts - 9.0), side * 1.0, -side * deg_to_rad(ang)))
			await tree.physics_frame
			k.speed = k.stats.top_speed
			k.input.throttle = 1.0
			k.input.steer = side * 0.5
			var y0 := k.global_position.y
			var fail := ""
			for f in 70:
				await tree.physics_frame
				if k.state == KartController.State.RECOVER:
					break
				var proj := race.track.project(k.global_position, tr.s)
				if int(proj.on_shortcut) >= 0:
					continue
				var excess: float = float(proj.distance) - float(proj.half_width) - wall_face
				if excess > -0.2:
					fail = "inside barrier (%.2f)" % excess
				if k.global_position.y > y0 + 0.9 and k.grounded:
					fail = "rode up the barrier"
			if fail != "":
				bad += 1
				print("  barrier end/corner s=%.0f side=%d ang=%d: %s" % [ts, int(side), int(ang), fail])
	check_eq(bad, 0, "karts are pushed back at barrier ends and corners")


## Things meant to span the road from above (arches, gantries, bunting).
const SPANS_ROAD := ["Gate", "Gantry", "Bunting", "Banner", "Flags", "Arch", "Finish", "Clouds", "WheelRing", "Lamp"]


func _collect_meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D and n.visible and (n as MeshInstance3D).mesh != null:
		out.append(n)
	if n is MultiMeshInstance3D and n.visible and (n as MultiMeshInstance3D).multimesh != null:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)


## No landmark or decor geometry may intrude into the road corridor + barrier
## line (0:24 grey slab / karts driving through the Heydar Aliyev Center).
## Landmarks: nothing above the road up to 30 m. Other decor: nothing in the
## kart band (0.3-4.5 m above the road), except pieces that span the road
## overhead by design.
func test_landmarks_and_decor_clear_of_road() -> void:
	await _start(0)
	var m: TrackPath = race.track.main
	var ow: float = race.track.offroad_width
	var cell := 12.0
	var grid := {}
	for i in m.sample_count():
		var p := m.points[i]
		var key := Vector2i(int(floor(p.x / cell)), int(floor(p.z / cell)))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(i)
	var meshes: Array = []
	_collect_meshes(race.decor, meshes)
	var bad := {}
	var worst := {}
	for mi: GeometryInstance3D in meshes:
		var path_s := str(race.decor.get_path_to(mi))
		var is_landmark := path_s.begins_with("Landmark_")
		var spans := false
		for k in SPANS_ROAD:
			if path_s.contains(k):
				spans = true
		var top := 30.0 if is_landmark else 4.5
		var margin := 3.6 if is_landmark else 0.6 # landmarks keep a clear buffer past the barrier
		if spans and not is_landmark:
			continue
		var xf := mi.global_transform
		if mi is MultiMeshInstance3D:
			var mm: MultiMesh = (mi as MultiMeshInstance3D).multimesh
			var xfs: Array = mi.get_meta("instance_xforms", [])
			for ixf: Transform3D in xfs:
				var o := xf * ixf.origin
				for dx in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						for i in grid.get(Vector2i(int(floor(o.x / cell)) + dx, int(floor(o.z / cell)) + dz), []):
							var p := m.points[i]
							var ex := Vector2(o.x - p.x, o.z - p.z).length() - (m.half_widths[i] + ow + 0.6)
							if ex < -0.3 and o.y > p.y - 1.0 and o.y < p.y + 4.5:
								bad[path_s] = int(bad.get(path_s, 0)) + 1
								if not worst.has(path_s) or ex < worst[path_s][0]:
									worst[path_s] = [ex, o]
			continue
		# Quick reject on the world AABB.
		var wa: AABB = xf * (mi as MeshInstance3D).mesh.get_aabb()
		var near_road := false
		for kx in range(int(floor(wa.position.x / cell)) - 1, int(floor(wa.end.x / cell)) + 2):
			for kz in range(int(floor(wa.position.z / cell)) - 1, int(floor(wa.end.z / cell)) + 2):
				if grid.has(Vector2i(kx, kz)):
					near_road = true
		if not near_road:
			continue
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var verts: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for vi in verts.size():
				var v := xf * verts[vi]
				var kx := int(floor(v.x / cell))
				var kz := int(floor(v.z / cell))
				for dx in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						for i in grid.get(Vector2i(kx + dx, kz + dz), []):
							var p := m.points[i]
							var hd := Vector2(v.x - p.x, v.z - p.z).length()
							if hd < m.half_widths[i] + ow + margin and v.y > p.y + 0.3 and v.y < p.y + top:
								bad[path_s] = int(bad.get(path_s, 0)) + 1
	for n in bad:
		print("  %s intrudes on road: %d verts %s" % [n, bad[n], worst.get(n, "")])
	check(bad.is_empty(), "no landmark/decor geometry inside the road corridor")
