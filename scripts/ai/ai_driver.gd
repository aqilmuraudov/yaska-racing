class_name AIDriver
extends Node
## Computer driver. Produces KartInput for the same KartController the player
## uses: no teleporting, no extra speed beyond a small capped skill factor.
##
## Pipeline per tick: route selection (main / shortcut) → lane choice
## (racing line, avoidance, hazards) → look-ahead steering → curvature-aware
## speed target → drift / boost decisions → item use → stuck recovery.

const LOOKAHEAD_BASE := 6.0
const LOOKAHEAD_SPEED := 0.55

var kart: KartController
var tracker: RaceTracker
var track: TrackData
var profile: Dictionary
var rng := RandomNumberGenerator.new()
var racers: Array = [] # Array of KartController (for avoidance)
var item_system: Node # optional ItemSystem
var autopilot := false ## player's kart after finishing / demo
var catchup_enabled := true

var route := -1 ## -1 main, >= 0 shortcut index
var route_s := 0.0
var _lane := 0.0
var _lane_target := 0.0
var _lane_timer := 0.0
var _shortcut_decided_lap := -1
var _drift_cooldown := 0.0
var _boost_wait := -1.0
var _will_miss := false
var _stuck_timer := 0.0
var _reverse_timer := 0.0
var _mistake_timer := 0.0
var _mistake_steer := 0.0
var _item_hold := 0.0
var _noise_phase := 0.0
var _reaction_buffer: Array = []


func setup(p_kart: KartController, p_tracker: RaceTracker, p_track: TrackData, difficulty: String, seed_value: int) -> void:
	kart = p_kart
	tracker = p_tracker
	track = p_track
	profile = load_profile(difficulty)
	rng.seed = seed_value
	_lane = rng.randf_range(-0.4, 0.4)
	_lane_target = _lane
	_noise_phase = rng.randf() * 100.0
	process_physics_priority = -10
	if not autopilot:
		kart.speed_scale = float(profile.speed_factor)


static func load_profile(difficulty: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/difficulty/profiles.json"))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has(difficulty):
		return {"corner_factor": 0.95, "steer_gain": 2.6, "steer_noise": 0.05, "reaction": 0.15,
			"drift_chance": 0.6, "boost_accuracy": 0.7, "perfect_chance": 0.3, "item_skill": 0.6,
			"mistake_rate": 0.01, "shortcut_chance": 0.3, "start_boost_chance": 0.5, "speed_factor": 0.97,
			"avoid_skill": 0.7, "catchup_max": 0.03}
	return parsed[difficulty]


func reset() -> void:
	route = -1
	route_s = 0.0
	_shortcut_decided_lap = -1
	_drift_cooldown = 0.0
	_boost_wait = -1.0
	_stuck_timer = 0.0
	_reverse_timer = 0.0
	_mistake_timer = 0.0
	_item_hold = 0.0
	_reaction_buffer.clear()
	if kart:
		kart.input.clear()


func wants_start_boost() -> bool:
	return rng.randf() < float(profile.start_boost_chance)


func _physics_process(delta: float) -> void:
	var _pt := Time.get_ticks_usec()
	_phys_tick(delta)
	Prof.add(&"ai", _pt)


func _phys_tick(delta: float) -> void:
	if kart == null or tracker == null:
		return
	var inp := kart.input
	if kart.controls_locked or kart.state == KartController.State.RECOVER:
		inp.clear()
		return
	_drift_cooldown = maxf(_drift_cooldown - delta, 0.0)
	_noise_phase += delta
	var pos := kart.global_position
	_update_route(pos)
	var path := _route_path()
	var speed := maxf(kart.speed, 0.0)

	# --- Lane selection --------------------------------------------------
	var hw := path.half_width_at(route_s)
	_lane_timer -= delta
	if _lane_timer <= 0.0:
		_lane_timer = rng.randf_range(2.0, 5.0)
		_lane_target = rng.randf_range(-0.35, 0.35)
	# Racing line: lean toward the inside of the next corner (modestly).
	var curv_ahead := path.curvature_at(route_s + 14.0 + speed * 0.5, 10.0)
	var inside := clampf(curv_ahead * 18.0, -0.35, 0.35) * float(profile.corner_factor)
	var lane := clampf(_lane_target + inside, -0.6, 0.6)
	var _t0 := Time.get_ticks_usec()
	lane += _avoidance(pos, path, hw) # racers and hazards
	Prof.add(&"a_avoid", _t0)
	lane = clampf(lane, -0.7, 0.7)
	if _near_ramp():
		lane = 0.0
	_lane = lerpf(_lane, lane, 1.0 - exp(-2.5 * delta))

	# --- Steering ----------------------------------------------------------
	# Pure pursuit on a lane expressed as a fraction of the *usable* width
	# (wheels stay on asphalt), aimed slightly wide to cancel the corner
	# cutting that pursuit steering naturally does (sagitta ≈ la²·κ/8).
	var la := 4.0 + speed * 0.38
	var tgt_s := route_s + la
	var usable := maxf(path.half_width_at(tgt_s) - 1.6, 0.5)
	var kappa := path.curvature_at(tgt_s - la * 0.5, 6.0)
	var target := path.position_at(tgt_s) + path.right_at(tgt_s) * (_lane * usable - la * la * kappa / 8.0)
	var to_t := target - pos
	to_t.y = 0.0
	var fwd := kart.forward_dir()
	var angle := fwd.signed_angle_to(to_t.normalized(), Vector3.UP) # + = target to the left
	var steer := clampf(-angle * float(profile.steer_gain), -1.0, 1.0)
	steer += sin(_noise_phase * 1.7) * float(profile.steer_noise)
	# Edge guard: steer back before the wheels reach the off-road strip.
	var lat := _current_lateral(pos, path)
	var edge := hw - 1.1
	if absf(lat) > edge:
		steer = clampf(steer - signf(lat) * clampf((absf(lat) - edge) / 1.2, 0.0, 1.0) * 0.9, -1.0, 1.0)
	_mistake_timer -= delta
	if _mistake_timer > 0.0:
		steer = clampf(steer + _mistake_steer, -1.0, 1.0)
	elif rng.randf() < float(profile.mistake_rate) * delta:
		_mistake_timer = rng.randf_range(0.3, 0.7)
		_mistake_steer = rng.randf_range(-0.6, 0.6)

	# --- Speed target --------------------------------------------------------
	var _t := Time.get_ticks_usec()
	var v_target := _speed_target(path, speed)
	Prof.add(&"a_speed", _t)
	var throttle := 1.0
	var brake := 0.0
	if speed > v_target + 1.5:
		throttle = 0.0
		brake = clampf((speed - v_target) / 6.0, 0.0, 1.0) if speed > v_target + 3.5 else 0.0
	elif speed > v_target:
		throttle = 0.4

	# --- Drift ---------------------------------------------------------------
	var drift_held := false
	var drift_pressed := false
	var boost_pressed := false
	if kart.is_drifting():
		var corner := path.curvature_at(route_s + 6.0, 8.0)
		var needed := absf(corner) * maxf(speed, 1.0) # rad/s yaw needed
		var base := deg_to_rad(kart.stats.drift_turn_base)
		var rng_r := deg_to_rad(kart.stats.drift_turn_range)
		var inward := clampf((needed - base) / rng_r, -1.0, 1.0)
		# Combine with geometric steering so drifting AI still holds its line.
		inward = clampf(inward * 0.5 + (-angle * float(profile.steer_gain)) * kart.drift_dir * 0.8, -1.0, 1.0)
		steer = inward * kart.drift_dir
		var corner_sign := int(signf(corner)) if absf(corner) > 0.004 else 0
		drift_held = corner_sign == kart.drift_dir and absf(angle) < 0.9
		# Release a drift that is carrying the kart onto the outside edge.
		if lat * -kart.drift_dir > edge - 0.6:
			drift_held = false
		throttle = 1.0
		brake = 0.0
		boost_pressed = _drift_boost_decision(delta)
	elif _should_drift(path, speed):
		var c := path.curvature_at(route_s + 12.0, 10.0)
		steer = signf(c)
		drift_pressed = true
		drift_held = true
		_drift_cooldown = 1.5
	elif kart.state == KartController.State.HOP:
		drift_held = true
		var c2 := path.curvature_at(route_s + 10.0, 10.0)
		steer = signf(c2) if absf(c2) > 0.004 else steer

	# --- Stuck / recovery ----------------------------------------------------
	var recover := false
	if absf(kart.speed) < 2.0 and throttle > 0.5 and kart.state == KartController.State.NORMAL:
		_stuck_timer += delta
	else:
		_stuck_timer = maxf(_stuck_timer - delta * 2.0, 0.0)
	if _stuck_timer > 1.4 and _reverse_timer <= 0.0:
		_reverse_timer = 1.1
	if _reverse_timer > 0.0:
		_reverse_timer -= delta
		throttle = 0.0
		brake = 1.0
		steer = -steer
		drift_pressed = false
		drift_held = false
	if _stuck_timer > 4.0 or tracker.off_route_distance > track.offroad_width + 5.0 or tracker.wrong_way:
		recover = true
		_stuck_timer = 0.0

	# Reaction delay on edge inputs (difficulty): buffer drift presses.
	inp.steer = clampf(steer, -1.0, 1.0)
	inp.throttle = throttle
	inp.brake = brake
	inp.drift_held = drift_held
	inp.drift_pressed = drift_pressed
	inp.boost_pressed = boost_pressed
	var _t1 := Time.get_ticks_usec()
	inp.item_pressed = _item_decision(delta, path, speed)
	Prof.add(&"a_item", _t1)
	inp.look_back = false
	inp.recover_held = recover
	if catchup_enabled and not autopilot:
		_apply_catchup()


## Signed lateral offset from the current route's centreline (+ = right).
func _current_lateral(pos: Vector3, path: TrackPath) -> float:
	if route < 0:
		return tracker.lateral
	return path.closest(pos).lateral


func _route_path() -> TrackPath:
	if route >= 0:
		return track.shortcuts[route].path
	return track.main


func _update_route(pos: Vector3) -> void:
	if route < 0:
		route_s = tracker.s
		for i in track.shortcuts.size():
			var sc: Dictionary = track.shortcuts[i]
			var before := track.main.forward_delta(route_s, sc.s_from)
			if before < 45.0 and before > 2.0 and _shortcut_decided_lap != tracker.current_lap():
				_shortcut_decided_lap = tracker.current_lap()
				var chance := float(profile.shortcut_chance)
				if kart.item == &"turbo" or kart.boost.is_active():
					chance = minf(chance + 0.5, 1.0)
				if autopilot:
					chance = 0.0
				if rng.randf() < chance:
					# Head for the alley entrance; route_s clamps to 0 until we reach it.
					route = i
					route_s = 0.0
					_lane_target = 0.0
					return
	else:
		var p: TrackPath = track.shortcuts[route].path
		route_s = p.closest(pos).s
		if route_s >= p.length - 6.0:
			route = -1
			route_s = tracker.s


func _speed_target(path: TrackPath, speed: float) -> float:
	var top := kart.stats.top_speed * kart.speed_scale
	var brake_dist := speed * speed / (2.0 * kart.stats.brake_decel * 0.6) + 8.0
	var max_c := 0.0
	var d := 4.0
	while d < brake_dist + 20.0:
		var c := absf(path.curvature_at(route_s + d, 5.0))
		# Corners further away matter less (we have time to brake).
		var weight := clampf(1.0 - (d - brake_dist) / 20.0, 0.0, 1.0) if d > brake_dist else 1.0
		max_c = maxf(max_c, c * weight)
		d += 4.0
	if max_c < 0.002:
		return top
	var rate := deg_to_rad(kart.stats.steer_rate_high)
	if kart.is_drifting():
		rate = deg_to_rad(kart.stats.drift_turn_base + kart.stats.drift_turn_range)
	var v := rate / max_c * float(profile.corner_factor)
	if path == track.main and route < 0 and tracker.off_route_distance > 0.5:
		v *= 0.9
	return clampf(v, 9.0, top)


func _should_drift(path: TrackPath, speed: float) -> bool:
	if _drift_cooldown > 0.0 or kart.state != KartController.State.NORMAL or _near_ramp():
		return false
	if speed < kart.stats.drift_min_speed + 4.0:
		return false
	# Long, consistent corner ahead?
	var c1 := path.curvature_at(route_s + 8.0, 6.0)
	var c2 := path.curvature_at(route_s + 20.0, 6.0)
	var c3 := path.curvature_at(route_s + 32.0, 6.0)
	if signf(c1) != signf(c2) or signf(c2) != signf(c3):
		return false
	var mn := minf(absf(c1), minf(absf(c2), absf(c3)))
	if mn < 0.011:
		return false
	return rng.randf() < float(profile.drift_chance) * 0.15


func _drift_boost_decision(delta: float) -> bool:
	var dm := kart.drift
	if dm.chain >= DriftMeter.MAX_CHAIN:
		return false
	if _boost_wait < 0.0 and dm.meter > 0.25:
		# Plan this boost: accurate drivers wait for the perfect zone.
		var acc := float(profile.boost_accuracy)
		_will_miss = rng.randf() > acc
		var perfect := rng.randf() < float(profile.perfect_chance)
		var target_meter := dm.perfect_start + 0.02 if perfect else rng.randf_range(dm.window_start + 0.02, dm.perfect_start)
		if _will_miss:
			target_meter = rng.randf_range(0.45, dm.window_start - 0.04) if rng.randf() < 0.6 else 1.1
		_boost_wait = target_meter
	if _boost_wait >= 0.0 and dm.meter >= minf(_boost_wait, 0.999):
		if _boost_wait > 1.0:
			return false # deliberately late: let it overheat
		_boost_wait = -1.0
		return true
	if dm.meter < 0.05:
		_boost_wait = -1.0
	return false


func _near_ramp() -> bool:
	if route >= 0:
		return false
	for r in track.ramps:
		var ahead := track.main.forward_delta(route_s, r.s)
		if ahead < 28.0 or ahead > track.main.length - 6.0:
			return true
	return false


## Lateral offset (fraction of half width) to avoid racers and hazards ahead.
func _avoidance(pos: Vector3, path: TrackPath, hw: float) -> float:
	var skill := float(profile.avoid_skill)
	var fwd := kart.forward_dir()
	var right := kart.right_dir()
	var push := 0.0
	for other in racers:
		if other == kart or not is_instance_valid(other):
			continue
		var rel: Vector3 = other.global_position - pos
		var ahead := rel.dot(fwd)
		var side := rel.dot(right)
		if ahead > 0.0 and ahead < 14.0 and absf(side) < 2.4:
			var closing: float = kart.speed - other.speed
			if closing > -1.0:
				var dir := -signf(side) if absf(side) > 0.2 else (1.0 if _lane < 0.0 else -1.0)
				push += dir * (1.0 - ahead / 14.0) * 0.6 * skill
	if item_system != null and item_system.has_method("hazards_near"):
		for h in item_system.hazards_near(pos, 30.0):
			var rel2: Vector3 = h - pos
			var ahead2 := rel2.dot(fwd)
			var side2 := rel2.dot(right)
			if ahead2 > 2.0 and ahead2 < 26.0 and absf(side2) < 2.5:
				push += -signf(side2 + 0.01) * 0.7 * skill
	return clampf(push, -0.8, 0.8)


func _item_decision(delta: float, path: TrackPath, speed: float) -> bool:
	if not kart.can_use_item():
		_item_hold = 0.0
		return false
	_item_hold += delta
	var skill := float(profile.item_skill)
	var min_hold := lerpf(3.0, 0.8, skill)
	if _item_hold < min_hold:
		return false
	match kart.item:
		&"turbo":
			var straight := absf(path.curvature_at(route_s + 25.0, 15.0)) < 0.006
			return (straight and not _near_ramp()) or _item_hold > 8.0 or (route >= 0)
		&"shield":
			if item_system != null and item_system.has_method("threat_near") and item_system.threat_near(kart):
				return true
			return _racer_close_behind(10.0) or _item_hold > 9.0
		&"trap":
			return _racer_close_behind(18.0) or _item_hold > 7.0
	return _item_hold > 5.0


func _racer_close_behind(dist: float) -> bool:
	var fwd := kart.forward_dir()
	for other in racers:
		if other == kart or not is_instance_valid(other):
			continue
		var rel: Vector3 = other.global_position - kart.global_position
		var d := rel.dot(fwd)
		if d < -1.0 and d > -dist and absf(rel.dot(kart.right_dir())) < 4.0:
			return true
	return false


## Modest, capped catch-up: AI far behind the leader gains a few percent of
## top speed, AI far ahead loses a little. Configurable (Settings) and off
## in Time Trial.
var _player_ref: RaceTracker
func set_catchup_reference(player_tracker: RaceTracker) -> void:
	_player_ref = player_tracker


func _apply_catchup() -> void:
	var base := float(profile.speed_factor)
	if _player_ref == null or not bool(Settings.get_value("gameplay", "catchup_assist", true)):
		kart.speed_scale = base
		return
	var gap := _player_ref.race_distance - tracker.race_distance # + = AI behind player
	var m := float(profile.catchup_max)
	var adj := clampf(gap / 150.0, -1.0, 1.0) * m
	kart.speed_scale = base + adj
