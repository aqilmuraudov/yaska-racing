class_name ChaseCamera
extends Camera3D
## Third-person chase camera. Runs in _process from the kart's interpolated
## transform (physics interpolation) so motion is smooth at any frame rate.
## Features: speed FOV, restrained drift framing, boost kick, look-back,
## wall avoidance, respawn smoothing and accessibility-scaled shake.
##
## The rig is kept relative to the kart (smoothed offset, not a smoothed
## world position): smoothing the world position made the camera trail by
## speed / rate, about 2 m extra at top speed and 2.6 m on nitro, so the
## player's kart looked small and far away. Speed sensations (FOV, a small
## deliberate stretch) are driven by the kart's real speed above its normal
## top speed, so they appear exactly when the kart really travels faster.

## Chase framing: far enough back and high enough that the road and the city
## ahead fill the upper two thirds of the screen (0.6.0's 3.9 m / 1.65 m with
## a look point at the kart filled the view with the driver's head).
const DISTANCES := [4.6, 5.4, 6.4]
const HEIGHTS := [2.0, 2.35, 2.8]
const LOOK_AHEAD := 7.0 ## metres ahead of the kart the chase camera aims at

## Selectable views (Settings → Controls, the HUD camera button, C key, R3).
signal mode_changed(mode: int)

enum Mode { CHASE, DRONE, RIGHT, LEFT, CINEMATIC }
const MODE_KEYS := ["CAM_CHASE", "CAM_DRONE", "CAM_RIGHT", "CAM_LEFT", "CAM_CINEMATIC"]

## Cinematic (0.10.2): TV-style shots that cut every few seconds.
enum Shot { TRACKSIDE, HELI, FRONT, FLYBY }
const SHOT_ORDER := [Shot.TRACKSIDE, Shot.HELI, Shot.FRONT, Shot.FLYBY]
const SHOT_TIME := [4.2, 5.0, 3.2, 4.6] ## seconds per shot
const SHOT_FOV := [42.0, 54.0, 60.0, 58.0]
const FLYBY_RANGE := 650.0 ## landmarks farther than this are not used
## World positions of big landmarks the fly-by frames behind the kart (set by
## the race from the decor; Flame Towers and Heydar Aliyev Center first).
var landmarks: Array[Vector3] = []
## 0.11.0: decor line test (TrackDecor.segment_hit: a -> b fraction or -1)
## and the other karts, so non-colliding props and rivals never fill the
## cinematic frame (the pink-blob frame of 0.10.2).
var occluder := Callable()
var others: Array = []
var _cuts_this_shot := 0
var shot: int = Shot.TRACKSIDE
var shot_index := -1
var _shot_t := 0.0
var _shot_len := 4.0
var _anchor := Vector3.ZERO ## trackside camera spot / fly-by landmark
var _side := 1.0
var _cine_pos := Vector3.ZERO
var _cine_look := Vector3.ZERO
const TRANSITION_TIME := 0.7 ## seconds of slower blending after a switch
const FOV_SPEED := 5.0 ## degrees added from standstill to top speed
const FOV_OVERSPEED := 26.0 ## degrees per 100 % above top speed (boosts)
const FOV_MAX := 80.0
const STRETCH_OVERSPEED := 1.6 ## metres of pull-back per 100 % above top speed

var target: KartController
var base_fov := 64.0
var _yaw := 0.0
var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var _fov := 68.0
var _shake := 0.0
var _drift_offset := 0.0
var _snap := true
var _time := 0.0
var _ray_query: PhysicsRayQueryParameters3D
var orbit := false ## pre-race / results orbit
var _orbit_angle := 0.0
var _offset := Vector3.ZERO ## camera position relative to the kart (smoothed)
var _stretch := 0.0
var _kick := 0.0 ## short FOV kick when a boost starts
var mode: int = Mode.CHASE
var _blend := 0.0 ## > 0 while blending to a newly chosen view
var _look_smooth := Vector3.ZERO


static func mode_count() -> int:
	return MODE_KEYS.size()


## Next view in the cycle; saved so the choice persists between races.
func cycle_mode() -> void:
	set_mode((mode + 1) % mode_count(), true)


func set_mode(m: int, save := false) -> void:
	m = clampi(m, 0, mode_count() - 1)
	if m == mode:
		return
	mode = m
	_blend = TRANSITION_TIME
	mode_changed.emit(m)
	if save:
		Settings.set_value("gameplay", "camera_mode", m)


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	near = 0.15
	far = 1500.0
	fov = base_fov
	_ray_query = PhysicsRayQueryParameters3D.new()
	_ray_query.collision_mask = 1
	mode = clampi(int(Settings.get_value("gameplay", "camera_mode", 0)), 0, mode_count() - 1)
	Settings.changed.connect(_on_setting_changed)


func _on_setting_changed(section: String, key: String) -> void:
	if section == "gameplay" and key == "camera_mode":
		set_mode(int(Settings.get_value("gameplay", "camera_mode", 0)))


func follow(kart: KartController) -> void:
	target = kart
	_snap = true
	if not kart.respawned.is_connected(snap):
		kart.respawned.connect(snap)
		kart.wall_hit.connect(func(s): add_shake(clampf(s, 0.0, 1.0) * 0.4))
		kart.got_hit.connect(func(_k): add_shake(0.5))
		kart.landed.connect(func(t): if t > 0.4: add_shake(clampf(t * 0.3, 0.0, 0.35)))
		kart.boost_started.connect(func(_s): _kick = 1.0 if GameFeel.speed_fx_enabled() else 0.0)


func snap() -> void:
	_snap = true


func add_shake(amount: float) -> void:
	var scale: float = Settings.get_value("accessibility", "camera_shake", 1.0)
	_shake = clampf(_shake + amount * scale, 0.0, 1.0)


func _process(delta: float) -> void:
	if target == null:
		return
	if not orbit and not get_tree().paused and Input.is_action_just_pressed(InputActions.CAMERA):
		cycle_mode()
	_time += delta
	var xf := target.get_global_transform_interpolated()
	var kpos := xf.origin
	if orbit:
		_orbit_angle += delta * 0.35
		var op := kpos + Vector3(sin(_orbit_angle) * 5.0, 2.0, cos(_orbit_angle) * 5.0)
		global_position = global_position.lerp(op, 1.0 - exp(-3.0 * delta)) if not _snap else op
		_snap = false
		# Frame the racer in the left half (results panel docks on the right).
		var cam_right := global_transform.basis.x
		look_at(kpos + Vector3.UP * 0.8 + cam_right * 1.8, Vector3.UP)
		return
	var dist_idx: int = Settings.get_value("gameplay", "camera_distance", 1)
	var dist: float = DISTANCES[clampi(dist_idx, 0, 2)]
	var height: float = HEIGHTS[clampi(dist_idx, 0, 2)]
	var kyaw := target.yaw
	var look_back := target.input.look_back and target.state != KartController.State.RECOVER
	if look_back:
		kyaw += PI
	var speed_ratio := clampf(absf(target.speed) / target.stats.top_speed, 0.0, 1.6)
	var overspeed := maxf(speed_ratio - 1.0, 0.0)
	_stretch = lerpf(_stretch, overspeed * STRETCH_OVERSPEED, 1.0 - exp(-3.0 * delta))
	_kick = maxf(_kick - delta * 2.5, 0.0)

	# Yaw follow: responsive but not twitchy; drift framing leans slightly
	# toward the inside of the slide so the exit stays visible.
	var drift_target := 0.0
	if target.is_drifting() or absf(target.drift_slip) > 0.03:
		# Follows the slide: ~35 % of the slip angle (≈9° at a full slide).
		drift_target = -target.drift_slip * 0.35
	_drift_offset = lerpf(_drift_offset, drift_target, 1.0 - exp(-3.0 * delta))
	var yaw_rate := 9.0 if look_back else 6.5
	if _snap:
		_yaw = kyaw
	else:
		_yaw = lerp_angle(_yaw, kyaw - _drift_offset, 1.0 - exp(-yaw_rate * delta))
	if look_back:
		_yaw = kyaw

	var back := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var view := mode if not look_back else Mode.CHASE
	if view == Mode.CINEMATIC:
		_cinematic(delta, kpos, target.yaw)
		return
	if shot_index >= 0:
		shot_index = -1 # leaving cinematic: next time it starts fresh
		_snap = true
	var desired: Vector3
	var look_target: Vector3
	match view:
		Mode.DRONE:
			# High, slightly behind: the track ahead and the corners are readable.
			desired = kpos + back * (6.5 + _stretch) + Vector3.UP * 13.0
			look_target = kpos - back * 5.0
		Mode.RIGHT, Mode.LEFT:
			var side := 1.0 if view == Mode.RIGHT else -1.0
			desired = kpos + right * side * 5.2 + back * 1.6 + Vector3.UP * 1.7
			look_target = kpos + Vector3.UP * 0.6 - back * 2.5
		_:
			desired = kpos + back * (dist + minf(speed_ratio, 1.0) * 0.4 + _stretch) + Vector3.UP * (height - minf(speed_ratio, 1.0) * 0.1)
			look_target = kpos + Vector3.UP * 1.0 - back * LOOK_AHEAD
	# Wall / scenery avoidance: pull in towards the kart if blocked.
	var pivot := kpos + Vector3.UP * 1.2
	_ray_query.from = pivot
	_ray_query.to = desired
	_ray_query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray_query)
	if not hit.is_empty() and view != Mode.DRONE:
		desired = pivot.lerp(hit.position, 0.85)
	var want := desired - kpos
	var look_rel := look_target - kpos
	# After a view switch the rig glides to the new spot instead of cutting.
	_blend = maxf(_blend - delta, 0.0)
	var rate := lerpf(14.0, 3.5, _blend / TRANSITION_TIME)
	if _snap:
		_offset = want
		_look_smooth = look_rel
		_look = kpos
		_snap = false
	else:
		_offset.x = lerpf(_offset.x, want.x, 1.0 - exp(-rate * delta))
		_offset.z = lerpf(_offset.z, want.z, 1.0 - exp(-rate * delta))
		_offset.y = lerpf(_offset.y, want.y, 1.0 - exp(-minf(rate, 6.0) * delta)) # softer vertical
		_look_smooth = _look_smooth.lerp(look_rel, 1.0 - exp(-rate * delta))
		# Look point: exact horizontally (no trailing), soft vertically (jumps).
		_look = Vector3(kpos.x, lerpf(_look.y, kpos.y, 1.0 - exp(-8.0 * delta)), kpos.z)
	_pos = kpos + _offset
	look_target = _look + _look_smooth

	# Shake (decays quickly; scaled by accessibility setting at add time).
	var shake_off := Vector3.ZERO
	if _shake > 0.001:
		var s := _shake * _shake * 0.35
		shake_off = Vector3(sin(_time * 47.0), sin(_time * 53.0 + 1.3), 0.0) * s
		_shake = maxf(_shake - delta * 2.2, 0.0)
	global_position = _pos + shake_off
	if global_position.distance_squared_to(look_target) > 0.01:
		look_at(look_target, Vector3.UP)

	# FOV from the real speed: gentle up to top speed, clearly wider only when
	# the kart really goes faster than normal (boosts), plus a short kick.
	var target_fov := base_fov + minf(speed_ratio, 1.0) * FOV_SPEED + overspeed * FOV_OVERSPEED + _kick * 5.0
	target_fov = minf(target_fov, FOV_MAX)
	_fov = lerpf(_fov, target_fov, 1.0 - exp(-5.0 * delta))
	fov = _fov


# --- Cinematic ---------------------------------------------------------------

## Starts the next TV shot (a hard cut, like a broadcast).
func next_shot(kpos: Vector3, kyaw: float) -> void:
	shot_index = (shot_index + 1) % SHOT_ORDER.size()
	shot = SHOT_ORDER[shot_index]
	_cuts_this_shot = 0
	if shot == Shot.FLYBY and _nearest_landmark(kpos) == Vector3.INF:
		shot = Shot.HELI
	_shot_t = 0.0
	_shot_len = SHOT_TIME[shot]
	_side = -_side
	var fwd := -Vector3(sin(kyaw), 0.0, cos(kyaw))
	var right := Vector3(cos(kyaw), 0.0, -sin(kyaw))
	match shot:
		Shot.TRACKSIDE:
			# A fixed low camera beside the road ahead; the kart drives past it.
			var ahead := clampf(absf(target.speed) * 1.6, 10.0, 26.0)
			_anchor = kpos + fwd * ahead + right * _side * 5.5 + Vector3.UP * 0.7
			if _view_blocked(kpos + Vector3.UP * 1.0, _anchor):
				_anchor = kpos + fwd * ahead - right * _side * 5.5 + Vector3.UP * 0.7
				if _view_blocked(kpos + Vector3.UP * 1.0, _anchor):
					_anchor = kpos + fwd * ahead + Vector3.UP * 3.0
		Shot.FLYBY:
			_anchor = _nearest_landmark(kpos)
	_cine_pos = _shot_target(kpos, kyaw)
	_cine_look = _shot_look(kpos, kyaw)
	fov = SHOT_FOV[shot]
	_fov = fov


func _nearest_landmark(kpos: Vector3) -> Vector3:
	var best := Vector3.INF
	var bd := FLYBY_RANGE
	for l in landmarks:
		var d := Vector2(l.x - kpos.x, l.z - kpos.z).length()
		if d < bd:
			bd = d
			best = l
	return best


## Physics walls, decor boxes or a rival kart between the kart and `to`.
func _view_blocked(from: Vector3, to: Vector3) -> bool:
	return _blocked(from, to) or _decor_hit(from, to) >= 0.0 or _kart_in_view(from, to)


func _decor_hit(from: Vector3, to: Vector3) -> float:
	if not occluder.is_valid():
		return -1.0
	return float(occluder.call(from, to))


## A rival within 3 m of the lens, or crossing the line to the kart.
func _kart_in_view(from: Vector3, to: Vector3) -> bool:
	for k in others:
		if not is_instance_valid(k) or k == target:
			continue
		var p: Vector3 = (k as Node3D).global_position + Vector3.UP * 0.5
		if p.distance_to(to) < 3.0:
			return true
		var q := Geometry3D.get_closest_point_to_segment(p, from, to)
		if q.distance_to(p) < 1.3 and q.distance_to(from) > 2.0:
			return true
	return false


func _blocked(from: Vector3, to: Vector3) -> bool:
	if not is_inside_tree():
		return false
	_ray_query.from = from
	_ray_query.to = to
	_ray_query.exclude = [target.get_rid()] if target else []
	return not get_world_3d().direct_space_state.intersect_ray(_ray_query).is_empty()


static func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Where the camera wants to be for the current shot (before collision).
func _shot_target(kpos: Vector3, kyaw: float) -> Vector3:
	var u := _ease(_shot_t / _shot_len)
	var back := Vector3(sin(kyaw), 0.0, cos(kyaw))
	var right := Vector3(cos(kyaw), 0.0, -sin(kyaw))
	match shot:
		Shot.TRACKSIDE:
			return _anchor
		Shot.HELI:
			# Slow eased orbit high above, starting behind-left.
			var a := kyaw + _side * (-0.9 + u * 1.5)
			return kpos + Vector3(sin(a), 0.0, cos(a)) * 11.0 + Vector3.UP * (8.0 - u * 1.5)
		Shot.FRONT:
			# Leading the kart, facing it, drifting slightly sideways.
			return kpos - back * (6.2 - u * 0.8) + right * _side * (1.2 - u * 0.8) + Vector3.UP * 1.5
		Shot.FLYBY:
			# Behind the kart on the far side from the landmark, sweeping
			# sideways and rising so the tower(s) rise up behind the kart.
			var to_l := Vector3(_anchor.x - kpos.x, 0.0, _anchor.z - kpos.z).normalized()
			var side := to_l.cross(Vector3.UP).normalized()
			return kpos - to_l * 7.5 + side * _side * lerpf(3.0, -1.0, u) + Vector3.UP * lerpf(1.8, 4.0, u)
	return kpos + back * 6.0 + Vector3.UP * 2.0


func _shot_look(kpos: Vector3, _kyaw: float) -> Vector3:
	match shot:
		Shot.FLYBY:
			var to_l := Vector3(_anchor.x - kpos.x, 0.0, _anchor.z - kpos.z).normalized()
			return kpos + to_l * 5.0 + Vector3.UP * 2.6
		Shot.HELI:
			return kpos + Vector3.UP * 0.3
	return kpos + Vector3.UP * 0.7


func _cinematic(delta: float, kpos: Vector3, kyaw: float) -> void:
	_shot_t += delta
	var far_from_kart := shot == Shot.TRACKSIDE and (_anchor.distance_to(kpos) > 30.0 or (_shot_t > 1.0 and _anchor.distance_to(kpos) > 20.0 and (_anchor - kpos).dot(-Vector3(sin(kyaw), 0.0, cos(kyaw))) < 0.0))
	if shot_index < 0 or _snap or _shot_t >= _shot_len or far_from_kart:
		_snap = false
		next_shot(kpos, kyaw)
	var desired := _shot_target(kpos, kyaw)
	# Never inside walls or buildings: pull in towards the kart when blocked.
	var pivot := kpos + Vector3.UP * 1.2
	if shot != Shot.TRACKSIDE and _blocked(pivot, desired):
		var hit := get_world_3d().direct_space_state.intersect_ray(_ray_query)
		if not hit.is_empty():
			desired = pivot.lerp(hit.position, 0.85)
	# Decor has no collision: pull in in front of the first prop box.
	var dh := _decor_hit(pivot, desired)
	if dh >= 0.0 and shot != Shot.TRACKSIDE:
		desired = pivot.lerp(desired, maxf(dh * 0.8, 0.15))
	# A rival or a prop in a fixed trackside view, or a rival at the lens:
	# cut to the next shot (at most 3 cuts in a row, then accept the view).
	if _cuts_this_shot < 3 and ((shot == Shot.TRACKSIDE and _decor_hit(pivot, _anchor) >= 0.0) or _kart_in_view(pivot, _cine_pos if _shot_t > 0.05 else desired)):
		var c := _cuts_this_shot + 1
		next_shot(kpos, kyaw)
		_cuts_this_shot = c
		desired = _shot_target(kpos, kyaw)
	var rate := 0.0 if shot == Shot.TRACKSIDE else 6.0
	_cine_pos = desired if rate == 0.0 else _cine_pos.lerp(desired, 1.0 - exp(-rate * delta))
	# The kart must stay readable: keep the camera within a sane distance.
	var off := _cine_pos - kpos
	if off.length() > 36.0:
		_cine_pos = kpos + off.normalized() * 36.0
	_cine_look = _cine_look.lerp(_shot_look(kpos, kyaw), 1.0 - exp(-10.0 * delta))
	global_position = _cine_pos
	if global_position.distance_squared_to(_cine_look) > 0.01:
		look_at(_cine_look, Vector3.UP)
	# Trackside zooms in a little as the kart gets further away.
	var want_fov: float = SHOT_FOV[shot]
	if shot == Shot.TRACKSIDE:
		want_fov = clampf(SHOT_FOV[shot] * 14.0 / maxf(_cine_pos.distance_to(kpos), 6.0), 26.0, 60.0)
	_fov = lerpf(_fov, want_fov, 1.0 - exp(-4.0 * delta))
	fov = _fov
