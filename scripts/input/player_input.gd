class_name PlayerInput
extends Node
## Reads InputMap actions (keyboard, controller and touch all feed the same
## actions) into a KartInput every physics tick, applying player assists.

var kart: KartController
var enabled := true
## Set by TouchControls when the on-screen layout is active.
var touch_active := false
var tilt_steer := 0.0
var _steer_assist_target: Callable


func setup(p_kart: KartController, steer_assist_target: Callable = Callable()) -> void:
	kart = p_kart
	_steer_assist_target = steer_assist_target
	process_physics_priority = -10 # before the kart simulates


func _physics_process(_delta: float) -> void:
	if kart == null:
		return
	var inp := kart.input
	if not enabled:
		inp.clear()
		return
	var sens: float = Settings.get_value("controls", "steer_sensitivity", 1.0)
	var steer := Input.get_axis(InputActions.STEER_LEFT, InputActions.STEER_RIGHT)
	if touch_active and Settings.get_value("controls", "touch_steer_mode", "buttons") == "tilt" and absf(tilt_steer) > absf(steer):
		steer = tilt_steer
	steer = clampf(steer * sens, -1.0, 1.0)
	var throttle := Input.get_action_strength(InputActions.ACCELERATE)
	var brake := Input.get_action_strength(InputActions.BRAKE)
	var auto_accel: bool = Settings.get_value("gameplay", "accel_assist", false) or (touch_active and Settings.get_value("controls", "touch_auto_accelerate", true))
	if auto_accel and brake < 0.1:
		throttle = 1.0
	if Settings.get_value("gameplay", "steer_assist", false) and _steer_assist_target.is_valid():
		# Gentle pull towards the track centre when the player is not steering.
		var assist: float = _steer_assist_target.call()
		if absf(steer) < 0.15:
			steer = clampf(steer + assist * 0.5, -1.0, 1.0)
	inp.steer = steer
	inp.throttle = throttle
	inp.brake = brake
	inp.drift_held = Input.is_action_pressed(InputActions.DRIFT)
	inp.drift_pressed = Input.is_action_just_pressed(InputActions.DRIFT)
	inp.boost_pressed = Input.is_action_just_pressed(InputActions.BOOST)
	inp.item_pressed = Input.is_action_just_pressed(InputActions.USE_ITEM)
	inp.look_back = Input.is_action_pressed(InputActions.LOOK_BACK)
	inp.recover_held = _recover_hold()


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


func release_all() -> void:
	_recover_time = 0.0
	if kart:
		kart.input.clear()
