class_name ChaseCamera
extends Camera3D
## Third-person chase camera. Runs in _process from the kart's interpolated
## transform (physics interpolation) so motion is smooth at any frame rate.
## Features: speed FOV, restrained drift framing, boost kick, look-back,
## wall avoidance, respawn smoothing and accessibility-scaled shake.

const DISTANCES := [4.2, 5.0, 6.2]
const HEIGHTS := [1.8, 2.05, 2.5]

var target: KartController
var base_fov := 68.0
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


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	near = 0.15
	far = 1500.0
	fov = base_fov
	_ray_query = PhysicsRayQueryParameters3D.new()
	_ray_query.collision_mask = 1


func follow(kart: KartController) -> void:
	target = kart
	_snap = true
	if not kart.respawned.is_connected(snap):
		kart.respawned.connect(snap)
		kart.wall_hit.connect(func(s): add_shake(clampf(s, 0.0, 1.0) * 0.4))
		kart.got_hit.connect(func(_k): add_shake(0.5))
		kart.landed.connect(func(t): if t > 0.4: add_shake(clampf(t * 0.3, 0.0, 0.35)))


func snap() -> void:
	_snap = true


func add_shake(amount: float) -> void:
	var scale: float = Settings.get_value("accessibility", "camera_shake", 1.0)
	_shake = clampf(_shake + amount * scale, 0.0, 1.0)


func _process(delta: float) -> void:
	if target == null:
		return
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
	var speed_ratio := clampf(absf(target.speed) / target.stats.top_speed, 0.0, 1.4)

	# Yaw follow: responsive but not twitchy; drift framing leans slightly
	# toward the inside of the slide so the exit stays visible.
	var drift_target := 0.0
	if target.is_drifting():
		drift_target = target.drift_dir * deg_to_rad(9.0)
	_drift_offset = lerpf(_drift_offset, drift_target, 1.0 - exp(-3.0 * delta))
	var yaw_rate := 9.0 if look_back else 6.5
	if _snap:
		_yaw = kyaw
	else:
		_yaw = lerp_angle(_yaw, kyaw - _drift_offset, 1.0 - exp(-yaw_rate * delta))
	if look_back:
		_yaw = kyaw

	var back := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var desired := kpos + back * (dist + speed_ratio * 0.6) + Vector3.UP * (height - speed_ratio * 0.15)
	# Wall / scenery avoidance: pull in towards the kart if blocked.
	var pivot := kpos + Vector3.UP * 1.2
	_ray_query.from = pivot
	_ray_query.to = desired
	_ray_query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray_query)
	if not hit.is_empty():
		desired = pivot.lerp(hit.position, 0.85)
	if _snap:
		_pos = desired
		_look = kpos
		_snap = false
	else:
		_pos.x = lerpf(_pos.x, desired.x, 1.0 - exp(-14.0 * delta))
		_pos.z = lerpf(_pos.z, desired.z, 1.0 - exp(-14.0 * delta))
		_pos.y = lerpf(_pos.y, desired.y, 1.0 - exp(-6.0 * delta)) # softer vertical (jumps)
		_look = _look.lerp(kpos, 1.0 - exp(-18.0 * delta))
	var look_target := _look + Vector3.UP * 1.0 - back * 2.5

	# Shake (decays quickly; scaled by accessibility setting at add time).
	var shake_off := Vector3.ZERO
	if _shake > 0.001:
		var s := _shake * _shake * 0.35
		shake_off = Vector3(sin(_time * 47.0), sin(_time * 53.0 + 1.3), 0.0) * s
		_shake = maxf(_shake - delta * 2.2, 0.0)
	global_position = _pos + shake_off
	if global_position.distance_squared_to(look_target) > 0.01:
		look_at(look_target, Vector3.UP)

	# FOV: moderate speed widening plus a short boost kick.
	var target_fov := base_fov + speed_ratio * 8.0
	if target.boost.is_active():
		target_fov += 6.0
	_fov = lerpf(_fov, target_fov, 1.0 - exp(-4.0 * delta))
	fov = _fov
