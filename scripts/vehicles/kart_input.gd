class_name KartInput
extends RefCounted
## Device-independent driving intent for one tick. Filled by PlayerInput
## (keyboard / controller / touch through InputMap) or by AIDriver, and
## consumed by KartController. Edge fields are true for one tick only.

var throttle := 0.0 ## 0..1
var brake := 0.0 ## 0..1
var steer := 0.0 ## -1 (left) .. 1 (right)
var drift_held := false
var drift_pressed := false
var boost_pressed := false
var item_pressed := false
var look_back := false
var recover_held := false


func clear() -> void:
	throttle = 0.0
	brake = 0.0
	steer = 0.0
	drift_held = false
	drift_pressed = false
	boost_pressed = false
	item_pressed = false
	look_back = false
	recover_held = false
