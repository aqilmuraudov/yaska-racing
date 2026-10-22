class_name RaceTracker
extends RefCounted
## Lap / checkpoint / ranking state for one racer. Pure logic: feed it the
## previous and current positions every physics tick.
##
## Progress is a single counter `cp_count` of gates passed in order.
## Gate 0 is the finish line. Crossing gate (cp_count % N) forward advances;
## crossing the previous gate backward undoes it. So skipped sections can
## never award a lap: every gate must be crossed, in order, forwards.
##   cp_count == 0         : on the grid, before the line
##   cp_count == 1 + k*N   : lap k completed (k >= 1), lap k+1 started
##   finished              : cp_count == 1 + laps*N

const GATE_MARGIN := 3.0
const GATE_HEIGHT := 8.0
const WRONG_WAY_TIME := 1.2

var track: TrackData
var laps := 3
var cp_count := 0
var max_cp_count := 0
var lap_start_time := 0.0
var lap_times: Array[float] = []
var best_lap := 0.0
var finished := false
var finish_time := 0.0
var s := 0.0
var lateral := 0.0
var on_shortcut := -1
var off_route_distance := 0.0
var race_distance := 0.0
var wrong_way := false
var _wrong_timer := 0.0
var last_safe_s := 0.0
var last_safe_lateral := 0.0
var _initialized := false


func _init(p_track: TrackData = null, p_laps: int = 3) -> void:
	track = p_track
	laps = p_laps


func reset(start_pos: Vector3) -> void:
	cp_count = 0
	max_cp_count = 0
	lap_start_time = 0.0
	lap_times.clear()
	best_lap = 0.0
	finished = false
	finish_time = 0.0
	wrong_way = false
	_wrong_timer = 0.0
	var p := track.project(start_pos)
	s = p.s
	lateral = p.lateral
	last_safe_s = s
	last_safe_lateral = 0.0
	_initialized = true
	_update_distance()


func current_lap() -> int:
	if cp_count <= 0:
		return 1
	return clampi((cp_count - 1) / track.checkpoint_count() + 1, 1, laps)


func laps_completed() -> int:
	if cp_count <= 0:
		return 0
	return (cp_count - 1) / track.checkpoint_count()


func next_gate() -> int:
	return cp_count % track.checkpoint_count()


## Returns a list of events: ["checkpoint", gate], ["lap", completed_lap, lap_time],
## ["finish", time], ["undo", gate].
func update(prev_pos: Vector3, pos: Vector3, race_time: float, velocity: Vector3 = Vector3.ZERO, delta: float = 1.0 / 60.0) -> Array:
	var events: Array = []
	if not _initialized:
		reset(pos)
	var proj := track.project(pos, s)
	s = proj.s
	lateral = proj.lateral
	on_shortcut = proj.on_shortcut
	off_route_distance = maxf(float(proj.distance) - float(proj.half_width), 0.0)
	if finished:
		_update_distance()
		return events
	var n := track.checkpoint_count()
	var fwd_gate := cp_count % n
	var crossing := _gate_crossing(fwd_gate, prev_pos, pos)
	if crossing > 0:
		cp_count += 1
		if cp_count > max_cp_count:
			max_cp_count = cp_count
			events.append(["checkpoint", fwd_gate])
			if fwd_gate == 0:
				if cp_count == 1:
					lap_start_time = 0.0 # lap 1 is timed from the start signal
				else:
					var lap_time := race_time - lap_start_time
					lap_times.append(lap_time)
					if best_lap <= 0.0 or lap_time < best_lap:
						best_lap = lap_time
					lap_start_time = race_time
					events.append(["lap", lap_times.size(), lap_time])
					if lap_times.size() >= laps:
						finished = true
						finish_time = race_time
						events.append(["finish", race_time])
	elif cp_count > 0:
		var back_gate := (cp_count - 1) % n
		if _gate_crossing(back_gate, prev_pos, pos) < 0:
			cp_count -= 1
			events.append(["undo", back_gate])
	_update_distance()
	_update_wrong_way(pos, proj, velocity, delta)
	return events


## +1 forward crossing, -1 backward crossing, 0 none.
func _gate_crossing(gate: int, a: Vector3, b: Vector3) -> int:
	var gs := track.checkpoint_s[gate]
	var origin := track.main.position_at(gs)
	var t := track.main.tangent_at(gs)
	var normal := Vector3(t.x, 0.0, t.z).normalized()
	var da := (a - origin).dot(normal)
	var db := (b - origin).dot(normal)
	if (da < 0.0) == (db < 0.0):
		return 0
	var f := da / (da - db)
	var hit := a.lerp(b, f)
	var right := Vector3(-normal.z, 0.0, normal.x)
	var half := track.main.half_width_at(gs) + track.offroad_width + GATE_MARGIN
	if absf((hit - origin).dot(right)) > half or absf(hit.y - origin.y) > GATE_HEIGHT:
		return 0
	return 1 if db > da else -1


## Race distance from the start line, clamped between the last gate passed
## and the next gate so off-route shortcuts or projection jumps can never
## move a racer ahead of a gate they have not crossed.
func _update_distance() -> void:
	var n := track.checkpoint_count()
	var L := track.lap_length()
	if cp_count == 0:
		var behind := track.main.forward_delta(s, track.finish_s)
		if behind > L * 0.5:
			behind = 0.0 # already slightly past the line but not crossed yet
		race_distance = -behind
		return
	var passed := cp_count - 1
	var lap_index := passed / n
	var gate := passed % n
	var gate_dist := lap_index * L + track.checkpoint_offset(gate)
	var next_offset := track.checkpoint_offset(gate + 1) if gate + 1 < n else L
	var seg_len := next_offset - track.checkpoint_offset(gate)
	var rel := track.main.forward_delta(track.checkpoint_s[gate], s)
	if rel > seg_len + (L - seg_len) * 0.5:
		rel = 0.0 # projected behind the gate (reversing over it)
	race_distance = gate_dist + clampf(rel, 0.0, seg_len)


func _update_wrong_way(pos: Vector3, proj: Dictionary, velocity: Vector3, delta: float) -> void:
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if hv.length() < 3.0:
		_wrong_timer = maxf(_wrong_timer - delta, 0.0)
	else:
		var t := track.route_tangent(pos, proj)
		var d := hv.normalized().dot(Vector3(t.x, 0.0, t.z).normalized())
		if d < -0.35:
			_wrong_timer += delta
		else:
			_wrong_timer = maxf(_wrong_timer - delta * 2.0, 0.0)
	wrong_way = _wrong_timer >= WRONG_WAY_TIME


## Called by RaceManager when the kart is in a safe, recoverable spot.
func mark_safe() -> void:
	if on_shortcut >= 0:
		return
	last_safe_s = s
	last_safe_lateral = lateral


## Ranking comparator: finished racers by time, then by race distance.
static func compare(a: RaceTracker, b: RaceTracker) -> bool:
	if a.finished != b.finished:
		return a.finished
	if a.finished:
		return a.finish_time < b.finish_time
	return a.race_distance > b.race_distance
