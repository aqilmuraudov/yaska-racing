class_name PlayerInput
extends Node
## Reads InputMap actions (keyboard, controller and touch all feed the same
## actions) into a KartInput every physics tick, applying player assists.
##
## Steering source is exclusive: in Tilt mode (touch layout active) only the
## phone's tilt steers, so no button or key value can overwrite it; in
## Buttons mode the steer actions are used. Switching modes clears stale
## steering. Steering Sensitivity (Low / Normal / High) changes how quickly
## digital buttons reach full lock, or how far the phone must tilt; full lock
## is always exactly ±1. Everything here runs on the fixed physics tick, so a
## higher frame-rate cap changes nothing.

## Seconds a digital steer input takes from centre to full lock, per level.
const BUTTON_RAMP := [0.28, 0.12, 0.0]

var kart: KartController
var enabled := true
## Set by TouchControls when the on-screen layout is active.
var touch_active := false
var tilt := TiltSteering.new()
## True when Tilt is selected but no sensor data arrives (buttons fallback).
var tilt_unavailable := false
var steer_value := 0.0
var _mode := ""
var _steer_assist_target: Callable


func setup(p_kart: KartController, steer_assist_target: Callable = Callable()) -> void:
	kart = p_kart
	_steer_assist_target = steer_assist_target
	process_physics_priority = -10 # before the kart simulates
	tilt.neutral_deg = float(Settings.get_value("controls", "tilt_neutral_deg", 0.0))


## "tilt" or "buttons" — what actually steers right now.
func steer_mode() -> String:
	if touch_active and Settings.get_value("controls", "touch_steer_mode", "buttons") == "tilt" and not tilt_unavailable:
		return "tilt"
	return "buttons"


func _physics_process(delta: float) -> void:
	if kart == null:
		return
	var inp := kart.input
	if not enabled:
		inp.clear()
		return
	var level := int(Settings.get_value("controls", "steer_level", 1))
	var mode := steer_mode()
	if mode != _mode:
		_mode = mode
		steer_value = 0.0
		tilt.reset()
	var steer := 0.0
	if mode == "tilt":
		tilt.sensitivity = level
		steer = tilt.update_from_sensors(delta)
		if not tilt.has_data() and tilt._no_data_time > TiltSteering.NO_DATA_TIMEOUT:
			tilt_unavailable = true # TouchControls shows the buttons + a message
	else:
		if touch_active and Settings.get_value("controls", "touch_steer_mode", "buttons") == "tilt":
			# Fallback active: keep sampling so tilt resumes if data appears.
			tilt.update_from_sensors(delta)
			if tilt.has_data():
				tilt_unavailable = false
		steer = _ramp_digital(Input.get_axis(InputActions.STEER_LEFT, InputActions.STEER_RIGHT), level, delta)
	steer_value = clampf(steer, -1.0, 1.0)
	steer = steer_value
	var throttle := Input.get_action_strength(InputActions.ACCELERATE)
	var brake := Input.get_action_strength(InputActions.BRAKE)
	var auto_accel: bool = Settings.get_value("gameplay", "accel_assist", false) or (touch_active and Settings.get_value("controls", "touch_auto_accelerate", true))
	if auto_accel and brake < 0.1:
		throttle = 1.0
	if Settings.get_value("gameplay", "steer_assist", false) and _steer_assist_target.is_valid():
		# Optional edge help only (never a centre pull, never while the
		# player steers): a small correction near the barrier while heading
		# into it. Off by default; the player keeps full authority.
		var assist: Vector2 = _steer_assist_target.call()
		if absf(steer) < 0.05:
			steer = clampf(steer + assist.y * 0.5, -1.0, 1.0)
	inp.steer = steer
	inp.throttle = throttle
	inp.brake = brake
	kart.easy_drift = bool(Settings.get_value("controls", "easy_drift", true))
	inp.drift_held = Input.is_action_pressed(InputActions.DRIFT)
	inp.drift_pressed = Input.is_action_just_pressed(InputActions.DRIFT)
	inp.boost_pressed = Input.is_action_just_pressed(InputActions.BOOST)
	inp.item_pressed = Input.is_action_just_pressed(InputActions.USE_ITEM)
	inp.look_back = Input.is_action_pressed(InputActions.LOOK_BACK)
	inp.recover_held = _recover_hold()


## Digital (button/key) steering ramps to the target; analog sticks are
## already proportional, but share the same ramp so levels feel consistent.
## Returning towards centre is twice as fast as turning in.
func _ramp_digital(target: float, level: int, delta: float) -> float:
	var t: float = BUTTON_RAMP[clampi(level, 0, 2)]
	if t <= 0.0:
		steer_value = target
		return target
	var rate := 1.0 / t
	if absf(target) < absf(steer_value) or signf(target) != signf(steer_value):
		rate *= 2.0
	steer_value = move_toward(steer_value, target, rate * delta)
	return steer_value


## Straight-ahead = how the phone is held now. Saved for the next race.
func calibrate_tilt() -> void:
	tilt.calibrate()
	Settings.set_value("controls", "tilt_neutral_deg", tilt.neutral_deg)


var _recover_time := 0.0
const RECOVER_HOLD_TIME := 0.5


## Recovery needs a deliberate 0.5 s hold so it is never triggered by accident.
func _recover_hold() -> bool:
	if Input.is_action_pressed(InputActions.RECOVER):
		_recover_time += get_physics_process_delta_time()
	else:
		_recover_time = 0.0
	if _recover_time >= RECOVER_HOLD_TIME:
		_recover_time = 0.0
		return true
	return false


func recover_hold_progress() -> float:
	return clampf(_recover_time / RECOVER_HOLD_TIME, 0.0, 1.0)


## Pause, focus loss, app suspend, restart: drop all held steering and the
## tilt filter history so nothing stale steers when play resumes.
func release_all() -> void:
	_recover_time = 0.0
	steer_value = 0.0
	tilt.reset()
	if kart:
		kart.input.clear()
