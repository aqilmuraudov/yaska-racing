class_name KartController
extends CharacterBody3D
## Arcade kart simulation on a fixed 60 Hz tick.
##
## The body stays upright and only yaws; its velocity is rebuilt every tick
## from a signed forward speed, a decaying sideways slip and a vertical speed.
## Visuals (lean, drift angle, ground alignment, wheels) live in KartVisual,
## so animation can never disturb collision. Players and AI share this code;
## only the KartInput source differs.

signal hopped
signal landed(airtime: float)
signal drift_started(dir: int)
signal drift_ended
signal drift_boost(tier: int, perfect: bool)
signal drift_miss
signal boost_started(source: StringName)
signal wall_hit(strength: float)
signal got_hit(kind: StringName)
signal shield_blocked
signal respawn_started
signal respawned
signal item_changed(item: StringName)

enum State { NORMAL, HOP, DRIFT, AIR, HIT, RECOVER }

## Bump whenever handling behaviour changes; ghosts from other versions are
## rejected because they would no longer be reproducible against.
const PHYSICS_VERSION := 1

const HIT_DURATION := 1.0
const HIT_IMMUNITY := 1.6 ## after a hit ends; prevents stun chaining
const RESPAWN_PROTECTION := 2.0
const RECOVER_FADE := 0.55
const RECOVER_TIME_COST := 0.6 ## extra seconds before control returns
const HARD_HIT_COOLDOWN := 0.35

@export var stats: KartStats

var racer_index := 0
var display_name := ""
var is_player := false
var input := KartInput.new()
var boost := KartBoost.new()
var drift := DriftMeter.new()

var state: State = State.NORMAL
var yaw := 0.0
var speed := 0.0
var lateral := 0.0
var vertical := 0.0
var steer_smoothed := 0.0
var drift_dir := 0
var airtime := 0.0
var grounded := true
var surface: StringName = &"road"
var controls_locked := true
var finished := false
## AI skill / catch-up scale on the speed cap (players always 1.0).
var speed_scale := 1.0

var hit_timer := 0.0
var immunity_timer := 0.0
var shield_timer := 0.0
var recover_timer := 0.0
var item: StringName = &""
var item_roll_timer := 0.0
var landing_boost_armed := false

var _reverse_timer := 0.0
var _hard_hit_cooldown := 0.0
var _hop_timer := 0.0
var _rehop_cooldown := 0.0
var last_airtime := 0.0
## > 0 while (recently) touching a barrier; enables low-speed pivoting.
var _wall_contact := 0.0
## Preferred escape direction along the barrier (race direction), set by RaceManager.
var route_forward := Vector3.ZERO
var _last_wall_normal := Vector3.ZERO
var _respawn_target := Transform3D.IDENTITY
var _pending_push := Vector3.ZERO
var _last_floor_normal := Vector3.UP
## Set by RaceManager: returns a safe Transform3D for recovery.
var respawn_provider: Callable
## Debug: what the last hard wall contact was.
var last_wall_info := ""


func _ready() -> void:
	if stats == null:
		stats = KartStats.new()
	boost.configure(stats)
	drift.configure(stats)
	boost.started.connect(func(src): boost_started.emit(src))
	collision_layer = 2
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.6
	floor_constant_speed = true
	floor_stop_on_slope = true
	floor_block_on_wall = true
	wall_min_slide_angle = deg_to_rad(5.0)
	max_slides = 5
	safe_margin = 0.02
	yaw = rotation.y


func forward_dir() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func right_dir() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func max_speed_absolute() -> float:
	return stats.top_speed * speed_scale + stats.boost_max_bonus


func is_invulnerable() -> bool:
	return immunity_timer > 0.0 or state == State.RECOVER


func is_drifting() -> bool:
	return state == State.DRIFT


func place_at(xform: Transform3D) -> void:
	global_transform = Transform3D(Basis.IDENTITY, xform.origin)
	var f := -xform.basis.z
	yaw = atan2(-f.x, -f.z)
	rotation = Vector3(0.0, yaw, 0.0)
	speed = 0.0
	lateral = 0.0
	vertical = 0.0
	velocity = Vector3.ZERO
	reset_physics_interpolation()


## Full reset for race restarts (no lingering timers, items or boosts).
func reset_for_race(xform: Transform3D) -> void:
	place_at(xform)
	state = State.NORMAL
	boost.cancel()
	drift.stop()
	drift_dir = 0
	hit_timer = 0.0
	immunity_timer = 0.0
	shield_timer = 0.0
	recover_timer = 0.0
	item = &""
	item_roll_timer = 0.0
	controls_locked = true
	finished = false
	steer_smoothed = 0.0
	_pending_push = Vector3.ZERO
	input.clear()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if state == State.RECOVER:
		_tick_recover(delta)
		return
	var on_floor := is_on_floor()
	var steer_in := clampf(input.steer, -1.0, 1.0)
	steer_smoothed = move_toward(steer_smoothed, steer_in, stats.steer_response * delta)

	if controls_locked:
		speed = move_toward(speed, 0.0, stats.brake_decel * delta)
		_integrate(delta, on_floor)
		return

	if input.recover_held and state != State.HIT:
		start_recover()
		return

	match state:
		State.NORMAL:
			if not on_floor:
				_enter_air()
			elif input.drift_pressed and _rehop_cooldown <= 0.0:
				_hop()
			else:
				_drive(delta, false)
				_steer_ground(delta)
		State.HOP:
			_drive(delta, false)
			_steer_air(delta, 2.2)
			if input.drift_held and absf(steer_in) > 0.3:
				drift_dir = int(signf(steer_in))
			if on_floor and vertical <= 0.0 and _hop_timer > 0.08:
				_land_from_hop()
		State.DRIFT:
			if not input.drift_held or speed < stats.drift_min_speed * 0.6:
				_end_drift()
				_drive(delta, false)
				_steer_ground(delta)
			elif not on_floor and airtime > 0.3:
				_end_drift()
				_enter_air()
			else:
				_drive(delta, true)
				_steer_drift(delta, steer_in)
				if drift.tick(delta) == DriftMeter.Result.MISS:
					drift_miss.emit()
				if input.boost_pressed:
					var r := drift.press()
					if r.result == DriftMeter.Result.BOOST:
						_award_drift_boost(r.tier, r.perfect)
					elif r.result == DriftMeter.Result.MISS:
						drift_miss.emit()
		State.AIR:
			speed = move_toward(speed, 0.0, stats.air_drag * delta)
			_steer_air(delta, 1.0)
			if input.drift_pressed:
				landing_boost_armed = true
			if on_floor and vertical <= 0.0:
				_land_from_air()
		State.HIT:
			speed = move_toward(speed, 0.0, 22.0 * delta)
			if hit_timer <= 0.0:
				state = State.NORMAL
				immunity_timer = maxf(immunity_timer, HIT_IMMUNITY)

	_integrate(delta, on_floor)


func _tick_timers(delta: float) -> void:
	boost.tick(delta)
	_hard_hit_cooldown = maxf(_hard_hit_cooldown - delta, 0.0)
	_wall_contact = maxf(_wall_contact - delta, 0.0)
	if state == State.HOP:
		_hop_timer += delta
	_rehop_cooldown = maxf(_rehop_cooldown - delta, 0.0)
	if hit_timer > 0.0:
		hit_timer -= delta
	if immunity_timer > 0.0:
		immunity_timer -= delta
	if shield_timer > 0.0:
		shield_timer -= delta
	if item_roll_timer > 0.0:
		item_roll_timer -= delta
		if item_roll_timer <= 0.0:
			item_changed.emit(item)


# --- Longitudinal -----------------------------------------------------------

func surface_speed_factor() -> float:
	match surface:
		&"offroad": return stats.offroad_speed_factor
		&"rough": return stats.rough_speed_factor
	return 1.0


func _drive(delta: float, drifting: bool) -> void:
	var offroad := surface == &"offroad" or surface == &"rough"
	var cap := stats.top_speed * surface_speed_factor() * speed_scale
	if drifting:
		cap *= stats.drift_speed_factor
	var boosted := boost.is_active()
	var target_cap := cap + boost.effective_bonus(offroad)
	var throttle := input.throttle
	var accel_factor := stats.offroad_accel_factor if surface == &"offroad" else 1.0

	if input.brake > 0.1 and speed > 0.5 and not boosted:
		speed -= stats.brake_decel * input.brake * delta
		_reverse_timer = 0.0
	elif input.brake > 0.1 and speed <= 0.5 and throttle < 0.1 and not boosted:
		_reverse_timer += delta
		if _reverse_timer >= stats.reverse_delay:
			speed = move_toward(speed, -stats.reverse_speed, stats.acceleration * 0.6 * delta)
		else:
			speed = move_toward(speed, 0.0, stats.brake_decel * delta)
	elif throttle > 0.05 or boosted:
		_reverse_timer = 0.0
		if speed < 0.0:
			speed = move_toward(speed, 0.0, stats.brake_decel * delta)
		var desired := target_cap if boosted else target_cap * throttle
		if speed < desired:
			var ratio := clampf(speed / maxf(cap, 0.1), 0.0, 1.0)
			var a := stats.acceleration * accel_factor * (1.0 - stats.accel_taper * ratio)
			if boosted:
				a = maxf(a, stats.boost_accel)
			speed = minf(speed + a * delta, desired)
		else:
			var decay := stats.overspeed_decay * (2.5 if offroad and not boosted else 1.0)
			speed = move_toward(speed, desired, decay * delta)
	else:
		_reverse_timer = 0.0
		var coast := stats.coast_decel * (2.0 if offroad else 1.0)
		speed = move_toward(speed, 0.0, coast * delta)
	speed = clampf(speed, -stats.reverse_speed, max_speed_absolute())


# --- Steering ---------------------------------------------------------------

func _steer_ground(delta: float) -> void:
	var spd := absf(speed)
	var ratio := clampf(spd / stats.top_speed, 0.0, 1.0)
	var rate := deg_to_rad(lerpf(stats.steer_rate_low, stats.steer_rate_high, ratio))
	var authority := clampf(spd / stats.steer_min_speed, 0.0, 1.0)
	if _wall_contact > 0.0:
		# Pinned against a barrier: keep enough authority to pivot away.
		authority = maxf(authority, 0.6)
	rate *= authority
	var grip := stats.lateral_grip * (stats.offroad_grip_factor if surface == &"offroad" else 1.0)
	var dir := 1.0 if speed >= 0.0 else -1.0
	yaw -= steer_smoothed * rate * dir * delta
	# Slow and pressing into a barrier: ease the nose round to run along it
	# (towards the race direction when known) so the kart never stays pinned.
	if _wall_contact > 0.0 and spd < 4.0 and input.throttle > 0.3 and _last_wall_normal != Vector3.ZERO:
		var along := Vector3(-_last_wall_normal.z, 0.0, _last_wall_normal.x)
		var pref := route_forward if route_forward != Vector3.ZERO else forward_dir()
		if along.dot(pref) < 0.0:
			along = -along
		yaw = lerp_angle(yaw, atan2(-along.x, -along.z), 1.0 - exp(-2.5 * delta))
	lateral = lerpf(lateral, 0.0, 1.0 - exp(-grip * delta))


func _steer_drift(delta: float, steer_in: float) -> void:
	var inward := steer_in * drift_dir # +1 = steering into the drift
	var rate := deg_to_rad(stats.drift_turn_base + inward * stats.drift_turn_range)
	yaw -= drift_dir * rate * delta
	# A small outward slide sells the powerslide without losing control.
	var slip_target := -drift_dir * speed * 0.09
	lateral = lerpf(lateral, slip_target, 1.0 - exp(-6.0 * delta))


func _steer_air(delta: float, scale: float) -> void:
	yaw -= steer_smoothed * deg_to_rad(stats.air_steer_rate) * scale * delta
	lateral = lerpf(lateral, 0.0, 1.0 - exp(-2.0 * delta))


# --- State transitions ------------------------------------------------------

func _hop() -> void:
	state = State.HOP
	vertical = stats.hop_impulse
	_hop_timer = 0.0
	drift_dir = int(signf(input.steer)) if absf(input.steer) > 0.3 else 0
	grounded = false
	hopped.emit()


func _land_from_hop() -> void:
	if input.drift_held and drift_dir != 0 and speed >= stats.drift_min_speed:
		state = State.DRIFT
		drift.start()
		drift_started.emit(drift_dir)
	else:
		state = State.NORMAL
		drift_dir = 0
	_rehop_cooldown = 0.12


func _enter_air() -> void:
	state = State.AIR
	landing_boost_armed = input.drift_held


func _land_from_air() -> void:
	var t := last_airtime
	landed.emit(t)
	if t >= stats.landing_boost_airtime and (landing_boost_armed or input.drift_held):
		var s := clampf(t / 1.2, 0.5, 1.0)
		boost.add(stats.pad_strength * s, 0.5 + 0.5 * s, &"landing")
	landing_boost_armed = false
	if input.drift_held and absf(input.steer) > 0.3 and speed >= stats.drift_min_speed:
		drift_dir = int(signf(input.steer))
		state = State.DRIFT
		drift.start()
		drift_started.emit(drift_dir)
	else:
		state = State.NORMAL


func _end_drift() -> void:
	drift.stop()
	state = State.NORMAL
	drift_dir = 0
	drift_ended.emit()


func _award_drift_boost(tier: int, perfect: bool) -> void:
	var strength := stats.boost_strength + (tier - 1) * stats.boost_tier_bonus
	var duration := stats.boost_duration + (tier - 1) * 0.12
	if perfect:
		strength += stats.boost_perfect_bonus
		duration += 0.2
	boost.add(strength, duration, &"drift")
	speed = minf(speed + 2.0, max_speed_absolute())
	drift_boost.emit(tier, perfect)


# --- External events --------------------------------------------------------

func apply_boost_pad() -> void:
	boost.add(stats.pad_strength, stats.pad_duration, &"pad")


func apply_item_boost() -> void:
	boost.add(stats.item_boost_strength, stats.item_boost_duration, &"item")


func apply_start_boost(quality: float) -> void:
	boost.add(stats.start_boost_strength * quality, stats.start_boost_duration * quality, &"start")


## Returns true when the hit landed (not blocked by shield or immunity).
func apply_hit(kind: StringName) -> bool:
	if state == State.RECOVER or finished:
		return false
	if shield_timer > 0.0:
		shield_timer = 0.0
		immunity_timer = maxf(immunity_timer, 0.5)
		shield_blocked.emit()
		return false
	if immunity_timer > 0.0 or state == State.HIT:
		return false
	if state == State.DRIFT:
		_end_drift()
	state = State.HIT
	hit_timer = HIT_DURATION
	boost.cancel()
	speed *= 0.45
	vertical = maxf(vertical, 3.5)
	got_hit.emit(kind)
	return true


func give_shield(duration: float) -> void:
	shield_timer = duration


func has_shield() -> bool:
	return shield_timer > 0.0


func give_item(new_item: StringName, roll_time: float) -> void:
	item = new_item
	item_roll_timer = roll_time
	item_changed.emit(&"?rolling")


func can_use_item() -> bool:
	return item != &"" and item_roll_timer <= 0.0 and state not in [State.HIT, State.RECOVER] and not controls_locked


func take_item() -> StringName:
	var it := item
	item = &""
	item_changed.emit(item)
	return it


## Velocity change from contacts (kart bumps). Applied next tick.
func add_push(dv: Vector3) -> void:
	_pending_push += Vector3(dv.x, 0.0, dv.z)


# --- Recovery ---------------------------------------------------------------

func start_recover() -> void:
	if state == State.RECOVER:
		return
	if state == State.DRIFT:
		_end_drift()
	state = State.RECOVER
	recover_timer = RECOVER_FADE + RECOVER_TIME_COST
	boost.cancel()
	speed = 0.0
	lateral = 0.0
	vertical = 0.0
	velocity = Vector3.ZERO
	if respawn_provider.is_valid():
		_respawn_target = respawn_provider.call(self)
	else:
		_respawn_target = global_transform
	respawn_started.emit()


func _tick_recover(delta: float) -> void:
	var before := recover_timer
	recover_timer -= delta
	if before > RECOVER_TIME_COST and recover_timer <= RECOVER_TIME_COST:
		place_at(_respawn_target)
		respawned.emit()
	if recover_timer <= 0.0:
		state = State.NORMAL
		immunity_timer = RESPAWN_PROTECTION
	velocity = Vector3.ZERO


func recover_progress() -> float:
	if state != State.RECOVER:
		return 0.0
	return 1.0 - recover_timer / (RECOVER_FADE + RECOVER_TIME_COST)


# --- Integration ------------------------------------------------------------

func _integrate(delta: float, on_floor: bool) -> void:
	if _pending_push != Vector3.ZERO:
		speed += _pending_push.dot(forward_dir())
		lateral += _pending_push.dot(right_dir())
		_pending_push = Vector3.ZERO
	var fwd := forward_dir()
	var right := right_dir()
	var horizontal := fwd * speed + right * lateral
	if on_floor and state != State.HOP and vertical <= 0.5:
		# Follow the floor plane exactly so crests do not launch the kart,
		# while real ramps (steep floor) still produce upward speed.
		var n := get_floor_normal()
		_last_floor_normal = n
		if n.y > 0.2:
			vertical = -(n.x * horizontal.x + n.z * horizontal.z) / n.y
		vertical -= 0.5 # light down-force keeps contact over seams
	else:
		vertical -= stats.gravity * delta
	vertical = maxf(vertical, -45.0)
	var pre := horizontal
	velocity = horizontal + Vector3.UP * vertical
	rotation = Vector3(0.0, yaw, 0.0)
	move_and_slide()
	_after_slide(pre, delta)


func _after_slide(pre_horizontal: Vector3, delta: float) -> void:
	var now_floor := is_on_floor()
	var floor_surface: StringName = &""
	var hard := false
	var glancing := false
	var glance_ratio := 0.0
	var glance_tangent := Vector3.ZERO
	var pre_speed := pre_horizontal.length()
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		var collider := c.get_collider()
		if n.y > 0.6:
			if collider != null and collider.has_meta("surface"):
				floor_surface = collider.get_meta("surface")
			elif floor_surface == &"":
				floor_surface = &"road"
			continue
		if collider is KartController:
			continue
		var hn := Vector3(n.x, 0.0, n.z)
		if hn.length_squared() < 0.0001:
			continue
		hn = hn.normalized()
		_wall_contact = 0.25
		_last_wall_normal = hn
		var into := -pre_horizontal.dot(hn)
		if into <= 0.3:
			continue
		var ratio := into / maxf(pre_speed, 0.1)
		if ratio >= stats.wall_hard_ratio and into > 8.0 and _hard_hit_cooldown <= 0.0:
			hard = true
			_hard_hit_cooldown = HARD_HIT_COOLDOWN
			last_wall_info = "%s n=%s pos=%s" % [collider.name if collider else "?", n, c.get_position()]
			speed = speed * (1.0 - stats.wall_hard_loss)
			lateral = 0.0
			_pending_push += hn * stats.wall_bounce
			if state == State.DRIFT:
				_end_drift()
			boost.cancel()
			wall_hit.emit(ratio)
		elif not hard:
			glancing = true
			glance_ratio = maxf(glance_ratio, ratio)
			glance_tangent = pre_horizontal - hn * pre_horizontal.dot(hn)
			if into > 3.0:
				wall_hit.emit(ratio * 0.5)

	if glancing and not hard:
		# Slide along the barrier: the slide already removed the component
		# into the wall; add light friction and align the kart with the wall.
		var vh := Vector3(velocity.x, 0.0, velocity.z)
		speed = vh.dot(forward_dir()) * (1.0 - stats.wall_glance_loss * glance_ratio)
		lateral = vh.dot(right_dir()) * 0.5
		if speed > 2.0 and state != State.DRIFT and glance_tangent.length_squared() > 0.01:
			var t := glance_tangent.normalized()
			yaw = lerp_angle(yaw, atan2(-t.x, -t.z), 0.18)
	if floor_surface != &"":
		surface = floor_surface
	if now_floor:
		vertical = minf(velocity.y, 0.0)
		if not grounded:
			last_airtime = airtime
			if airtime > 0.05 and state not in [State.AIR, State.HOP]:
				landed.emit(airtime)
		grounded = true
		airtime = 0.0
	else:
		vertical = velocity.y
		grounded = false
		airtime += delta
