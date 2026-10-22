extends TestCase
## Checkpoint order, lap counting, skip prevention, wrong way and ranking.

const R := 50.0
var td: TrackData


func before_each() -> void:
	td = circle_track(R, 4)


func _pos(angle: float) -> Vector3:
	return Vector3(cos(angle) * R, 0.0, -sin(angle) * R)


func _vel(angle: float, dir: float = 1.0) -> Vector3:
	return Vector3(-sin(angle), 0.0, -cos(angle)) * 20.0 * dir


## Drives along the circle from a0 to a1 (radians) in small steps.
func _drive(tr: RaceTracker, a0: float, a1: float, t0: float, steps_per_rad: float = 40.0) -> Array:
	var events: Array = []
	var n := int(absf(a1 - a0) * steps_per_rad) + 1
	var prev := _pos(a0)
	var dir := signf(a1 - a0)
	for i in range(1, n + 1):
		var a := lerpf(a0, a1, float(i) / n)
		var p := _pos(a)
		events.append_array(tr.update(prev, p, t0 + i * 0.05, _vel(a, dir), 0.05))
		prev = p
	return events


func _count(events: Array, kind: String) -> int:
	var c := 0
	for e in events:
		if e[0] == kind:
			c += 1
	return c


func test_three_laps_finish() -> void:
	var tr := RaceTracker.new(td, 3)
	tr.reset(_pos(-0.2))
	var events := _drive(tr, -0.2, TAU * 3 + 0.3, 0.0)
	check_eq(_count(events, "lap"), 3, "three laps completed")
	check_eq(_count(events, "finish"), 1, "finish fired once")
	check(tr.finished, "tracker finished")
	check_eq(tr.laps_completed(), 3, "laps_completed")
	check(tr.best_lap > 0.0, "best lap recorded")


func test_skipping_checkpoints_awards_nothing() -> void:
	var tr := RaceTracker.new(td, 3)
	tr.reset(_pos(-0.2))
	_drive(tr, -0.2, 0.2, 0.0) # cross the line: lap 1 starts
	check_eq(tr.cp_count, 1, "crossed start line")
	_drive(tr, 0.2, deg_to_rad(80.0), 1.0)
	# Teleport across the infield, skipping gates 1 and 2.
	var events := tr.update(_pos(deg_to_rad(80.0)), _pos(deg_to_rad(260.0)), 3.0, _vel(deg_to_rad(260.0)), 0.05)
	events.append_array(_drive(tr, deg_to_rad(260.0), TAU + 0.2, 3.1))
	check_eq(_count(events, "lap"), 0, "no lap for a skipped route")
	check_eq(tr.cp_count, 1, "progress did not advance past the missed gate")
	check_eq(tr.current_lap(), 1, "still on lap 1")


func test_backward_crossing_undoes_and_no_duplicate_events() -> void:
	var tr := RaceTracker.new(td, 3)
	tr.reset(_pos(-0.2))
	_drive(tr, -0.2, deg_to_rad(100.0), 0.0)
	check_eq(tr.cp_count, 2, "line + gate 1")
	var back := _drive(tr, deg_to_rad(100.0), deg_to_rad(80.0), 2.0)
	check_eq(_count(back, "undo"), 1, "reversing over gate 1 undoes it")
	check_eq(tr.cp_count, 1, "cp_count decremented")
	var again := _drive(tr, deg_to_rad(80.0), deg_to_rad(100.0), 3.0)
	check_eq(tr.cp_count, 2, "re-crossed")
	check_eq(_count(again, "checkpoint"), 0, "no duplicate checkpoint event")


func test_backward_over_finish_cannot_fake_a_lap() -> void:
	var tr := RaceTracker.new(td, 3)
	tr.reset(_pos(-0.2))
	_drive(tr, -0.2, 0.3, 0.0)
	# Rock back and forth over the line repeatedly.
	var events: Array = []
	for i in 5:
		events.append_array(_drive(tr, 0.3, -0.3, 1.0 + i))
		events.append_array(_drive(tr, -0.3, 0.3, 1.5 + i))
	check_eq(_count(events, "lap"), 0, "line rocking never counts a lap")
	check_eq(tr.laps_completed(), 0, "laps_completed stays 0")


func test_wrong_way_detected() -> void:
	var tr := RaceTracker.new(td, 3)
	tr.reset(_pos(1.0))
	var prev := _pos(1.0)
	for i in 60:
		var a := 1.0 - i * 0.01
		var p := _pos(a)
		tr.update(prev, p, i * 0.05, _vel(a, -1.0), 0.05)
		prev = p
	check(tr.wrong_way, "driving backwards for 3 s flags wrong way")


func test_ranking_by_progress_and_finish() -> void:
	var a := RaceTracker.new(td, 1)
	var b := RaceTracker.new(td, 1)
	var c := RaceTracker.new(td, 1)
	for t in [a, b, c]:
		t.reset(_pos(-0.2))
	_drive(a, -0.2, 2.0, 0.0)
	_drive(b, -0.2, 3.0, 0.0)
	_drive(c, -0.2, TAU + 0.3, 0.0) # c finishes the 1-lap race
	var order := [a, b, c]
	order.sort_custom(RaceTracker.compare)
	check(order[0] == c, "finished racer ranks first")
	check(order[1] == b, "further racer ranks second")
	check(order[2] == a, "least progress ranks last")


func test_distance_clamped_to_next_gate() -> void:
	var tr := RaceTracker.new(td, 3)
	tr.reset(_pos(-0.2))
	_drive(tr, -0.2, 0.3, 0.0)
	var before := tr.race_distance
	# Projection far ahead without crossing gate 1 (e.g. off-route).
	tr.update(_pos(0.3), _pos(0.3) + Vector3(0, 0, 0), 1.0)
	tr.s = td.main.wrap_s(td.checkpoint_s[2] + 5.0)
	tr._update_distance()
	var gate1 := td.checkpoint_offset(1)
	check(tr.race_distance <= gate1 + 0.01, "distance never passes an uncrossed gate")
	check(before >= 0.0, "distance positive after start")


func test_seafront_checkpoint_layout_is_valid() -> void:
	var sea := TrackData.load_from_file("res://data/tracks/seafront_sprint.json")
	check(sea.checkpoint_count() >= 6, "enough checkpoints")
	check(sea.lap_length() > 1300.0 and sea.lap_length() < 1900.0, "lap length suits a 60-90 s beginner lap")
	# No checkpoint inside the main-route section that the shortcut skips.
	for sc in sea.shortcuts:
		var span := sea.main.forward_delta(sc.s_from, sc.s_to)
		for cs in sea.checkpoint_s:
			var rel := sea.main.forward_delta(sc.s_from, cs)
			check(not (rel > 0.0 and rel < span), "checkpoint %.0f not inside shortcut-skipped section" % cs)
		# Gates must not be crossable from inside the shortcut corridor.
		var p: TrackPath = sc.path
		for k in range(0, int(p.length), 4):
			var pt := p.position_at(k)
			for g in sea.checkpoint_count():
				var origin := sea.main.position_at(sea.checkpoint_s[g])
				var half := sea.main.half_width_at(sea.checkpoint_s[g]) + sea.offroad_width + RaceTracker.GATE_MARGIN
				check(origin.distance_to(pt) > half, "shortcut point %d clear of gate %d" % [k, g])
	# Checkpoints are in increasing order from the finish line.
	for i in range(1, sea.checkpoint_count()):
		check(sea.checkpoint_offset(i) > sea.checkpoint_offset(i - 1), "checkpoint %d after %d" % [i, i - 1])
