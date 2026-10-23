class_name TiltSteering
extends RefCounted
## Turns the phone's gravity direction into a steering value in [-1, 1].
##
## Axes (checked against the Godot 4.4.1 Android sources, GodotInputHandler /
## InputEventRunnable): Godot already rotates sensor samples into the current
## display orientation and negates them, so `Input.get_gravity()` /
## `get_accelerometer()` point *down* in screen coordinates: +x = towards the
## right edge of the screen as the player sees it, +y = towards the top edge.
## Lowering the right edge (turning the phone like a steering wheel to the
## right) therefore makes x positive in any landscape orientation.
##
## Godot caches the display rotation and only refreshes it on configuration
## changes, which a 180° flip between the two landscape orientations does not
## send. If the cached rotation is stale both x and y arrive negated; the
## screen's "up" then points along +y, which a player looking at an upright
## picture cannot do, so the sign is corrected (with hysteresis).
##
## The steering angle is the phone's rotation in the screen plane
## (atan2(x, down)) when it is held upright like a wheel, blending to the
## lean of the screen's horizontal axis (asin(x / |g|)) when held flat.
## Sensor data must be enabled in project.godot
## (`input_devices/sensors/enable_gravity` and `enable_accelerometer`); they
## default to off in Godot 4.4, which is why tilt previously did nothing.

## Full-lock angles (degrees) for Low / Normal / High sensitivity.
const FULL_LOCK_DEG := [30.0, 22.0, 15.0]
const DEADZONE_DEG := 1.8
## Low-pass time constants (s). The gravity sensor is already a fused,
## filtered estimate; the raw accelerometer also contains bumps and
## linear acceleration, so it is smoothed more.
const TAU_GRAVITY := 0.04
const TAU_ACCEL := 0.11
const MAX_NEUTRAL_DEG := 45.0
const NO_DATA_TIMEOUT := 1.2

var sensitivity := 1 ## 0 low, 1 normal, 2 high
var neutral_deg := 0.0 ## calibrated rest angle
var source := "none" ## gravity | accelerometer | none
var raw := Vector3.ZERO ## last sensor sample (m/s², screen axes)
var filtered := Vector3.ZERO
var angle_deg := 0.0 ## filtered lean, before calibration
var steer := 0.0 ## final value
var flipped := false
var _no_data_time := 0.0
var _have_filter := false
## Development only (`--fake-tilt`, tests): replaces the sensor reading.
static var fake_gravity := Vector3.ZERO


## Reads the sensors (gravity preferred) and updates `steer`. Call from a
## fixed-rate tick so the filter does not depend on the render frame rate.
func update_from_sensors(dt: float) -> float:
	var g := Input.get_gravity()
	var src := "gravity"
	if fake_gravity != Vector3.ZERO:
		g = fake_gravity
	if g.length_squared() < 1.0:
		g = Input.get_accelerometer()
		src = "accelerometer"
	if g.length_squared() < 1.0:
		src = "none"
	return process_sample(g, src, dt)


## Pure filter step (unit tested): sample in m/s², screen axes.
func process_sample(sample: Vector3, src: String, dt: float) -> float:
	if src == "none":
		_no_data_time += dt
		source = "none" if _no_data_time > NO_DATA_TIMEOUT else source
		steer = move_toward(steer, 0.0, dt * 4.0)
		return steer
	_no_data_time = 0.0
	source = src
	raw = sample
	if not _have_filter:
		filtered = sample
		_have_filter = true
	else:
		var tau := TAU_GRAVITY if src == "gravity" else TAU_ACCEL
		var w := 1.0 - exp(-dt / tau)
		if src == "accelerometer":
			# Raw accelerometer = gravity + linear acceleration. Samples whose
			# magnitude is far from 1 g are mostly bumps or shakes, not a
			# change of hold, so they get little weight.
			var dev := (sample.length() - 9.81) / (0.25 * 9.81)
			w *= exp(-dev * dev)
		filtered = filtered.lerp(sample, w)
	var g := filtered
	# Stale-rotation correction: screen-up along gravity means negated axes.
	if g.y > 3.0:
		flipped = true
	elif g.y < -3.0:
		flipped = false
	var x := -g.x if flipped else g.x
	var y := g.y if flipped else -g.y # screen-down component (> 0 when upright)
	var len := maxf(g.length(), 0.001)
	# Upright (wheel-style) holds: rotation within the screen plane, exact
	# whatever the backward pitch. Flat holds: lean of the horizontal axis.
	var lean := asin(clampf(x / len, -1.0, 1.0))
	var wheel := atan2(x, maxf(y, 0.001))
	var upright_w := smoothstep(0.25, 0.55, y / len)
	angle_deg = rad_to_deg(lerpf(lean, wheel, upright_w))
	steer = angle_to_steer(angle_deg - neutral_deg, sensitivity)
	return steer


## Dead zone, then linear up to the full-lock angle; always bounded.
static func angle_to_steer(rel_deg: float, sens: int) -> float:
	var lock: float = FULL_LOCK_DEG[clampi(sens, 0, 2)]
	var mag := absf(rel_deg)
	if mag <= DEADZONE_DEG:
		return 0.0
	return signf(rel_deg) * clampf((mag - DEADZONE_DEG) / (lock - DEADZONE_DEG), 0.0, 1.0)


## Makes the current hold the straight-ahead position.
func calibrate() -> void:
	if source != "none" and _have_filter:
		neutral_deg = clampf(angle_deg, -MAX_NEUTRAL_DEG, MAX_NEUTRAL_DEG)
	steer = 0.0


## Forget filter history (after pause, backgrounding or a mode switch) so a
## stale sample cannot steer the kart.
func reset() -> void:
	_have_filter = false
	steer = 0.0
	_no_data_time = 0.0


func has_data() -> bool:
	return source != "none"


func debug_text() -> String:
	return "TILT src=%s raw=(%.2f %.2f %.2f) filt=(%.2f %.2f %.2f) flip=%s\nangle=%.1f° neutral=%.1f° sens=%d steer=%+.2f" % [
		source, raw.x, raw.y, raw.z, filtered.x, filtered.y, filtered.z, flipped,
		angle_deg, neutral_deg, sensitivity, steer]
