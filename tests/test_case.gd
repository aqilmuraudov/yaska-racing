class_name TestCase
extends RefCounted
## Minimal test base. Methods named test_* are run by tests/run_tests.gd.
## Assertions record failures instead of aborting so every check reports.

var tree: SceneTree
var failures: Array[String] = []
var checks := 0
var _current := ""


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [_current, msg])


func check_eq(a, b, msg: String) -> void:
	check(a == b, "%s (got %s, expected %s)" % [msg, str(a), str(b)])


func check_near(a: float, b: float, eps: float, msg: String) -> void:
	check(absf(a - b) <= eps, "%s (got %f, expected %f ±%f)" % [msg, a, b, eps])


func frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


## Circle track used by logic tests: radius r, centred at origin, flat.
static func circle_track(radius: float = 50.0, checkpoints: int = 4, width: float = 12.0) -> TrackData:
	var control: Array = []
	var n := 24
	for i in n:
		var a := TAU * i / n
		# Counter-clockwise when seen from above (driving direction).
		control.append([cos(a) * radius, 0.0, -sin(a) * radius, width, 0])
	var cps: Array = []
	for k in range(1, checkpoints):
		var a2 := TAU * k / checkpoints
		cps.append([cos(a2) * radius, -sin(a2) * radius])
	return TrackData.from_dict({
		"id": "test_circle", "laps": 3, "offroad_width": 3.0,
		"control": control, "finish_at": [radius, 0.0], "checkpoints_at": cps,
	})
