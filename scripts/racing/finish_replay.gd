class_name FinishReplay
extends Node
## 0.12.0 Winner's finish replay.
## While racing, every other physics tick the transform and speed of every
## kart go into a ring buffer (last BUFFER_S seconds). After the finish
## celebration the race manager asks for a replay: the camera follows the
## race winner (the player when the winner crossed too long ago) through the
## WINDOW_BEFORE s before the line and WINDOW_AFTER s after it, with slow
## motion around the crossing. Karts are moved from the buffer with their own
## physics paused; at the end (or on "skip") everything is restored exactly
## and the results open. Purely visual: no physics, AI or race data change.

signal finished

const BUFFER_S := 15.0
const RECORD_EVERY := 2 ## physics ticks (60 Hz -> 30 samples / s)
const WINDOW_BEFORE := 3.6
const WINDOW_AFTER := 1.4
const SLOWMO := 0.45 ## playback rate around the line
const SLOWMO_RANGE := 0.7 ## s either side of the crossing

var _karts: Array = [] ## KartController
var _times := PackedFloat32Array() ## race time per frame
var _frames: Array = [] ## Array[Array[Transform3D]] per frame
var _speeds: Array = [] ## Array[PackedFloat32Array] per frame
var _tick := 0

var playing := false
var target_index := -1 ## kart shown (index into the karts array)
var t := 0.0 ## replay clock in race time
var t_start := 0.0
var t_end := 0.0
var cross_time := 0.0
var _snapshot: Array = []


func setup(karts: Array) -> void:
	_karts = karts.duplicate()
	clear()


func clear() -> void:
	_times = PackedFloat32Array()
	_frames.clear()
	_speeds.clear()
	_tick = 0
	playing = false


func capacity() -> int:
	return int(BUFFER_S * 60.0 / RECORD_EVERY) + 2


func frame_count() -> int:
	return _times.size()


func span() -> float:
	return 0.0 if _times.is_empty() else _times[_times.size() - 1] - _times[0]


## Called by the race manager on every physics tick while racing.
func record(race_time: float) -> void:
	if playing or _karts.is_empty():
		return
	_tick += 1
	if _tick % RECORD_EVERY != 0:
		return
	var xf: Array = []
	var sp := PackedFloat32Array()
	for k in _karts:
		var kart := k as KartController
		xf.append(kart.global_transform)
		sp.append(kart.speed)
	_times.append(race_time)
	_frames.append(xf)
	_speeds.append(sp)
	if _times.size() > capacity():
		_times.remove_at(0)
		_frames.pop_front()
		_speeds.pop_front()


## Whether a crossing at `finish_t` can be shown with the full window.
func covers(finish_t: float) -> bool:
	if _times.size() < 4:
		return false
	return finish_t - WINDOW_BEFORE >= _times[0] - 0.01 and finish_t + WINDOW_AFTER <= _times[_times.size() - 1] + 0.01


## Picks who to show: the winner if their crossing is still in the buffer,
## else the player. Returns -1 when nothing usable was recorded.
func pick_target(winner_index: int, winner_finish: float, player_index: int, player_finish: float) -> int:
	if winner_index >= 0 and covers(winner_finish):
		cross_time = winner_finish
		return winner_index
	if player_index >= 0 and covers(player_finish):
		cross_time = player_finish
		return player_index
	return -1


func start(index: int) -> bool:
	if index < 0 or index >= _karts.size() or _times.size() < 4:
		return false
	target_index = index
	t_start = maxf(cross_time - WINDOW_BEFORE, _times[0])
	t_end = minf(cross_time + WINDOW_AFTER, _times[_times.size() - 1])
	t = t_start
	_snapshot.clear()
	for k in _karts:
		var kart := k as KartController
		_snapshot.append({"xf": kart.global_transform, "vel": kart.velocity, "speed": kart.speed,
			"yaw": kart.yaw, "pp": kart.is_physics_processing()})
		kart.set_physics_process(false)
	playing = true
	_apply(t)
	for k in _karts:
		(k as Node3D).reset_physics_interpolation()
	return true


## Playback rate at replay time `tt`: slow motion near the line.
func rate_at(tt: float) -> float:
	return SLOWMO if absf(tt - cross_time) < SLOWMO_RANGE else 1.0


## Advances the replay by a real-time step; returns true when it ended.
func step(delta: float) -> bool:
	if not playing:
		return true
	t += delta * rate_at(t)
	if t >= t_end:
		stop()
		return true
	_apply(t)
	return false


func stop() -> void:
	if not playing:
		return
	playing = false
	for i in _karts.size():
		var kart := _karts[i] as KartController
		var s: Dictionary = _snapshot[i]
		kart.global_transform = s.xf
		kart.velocity = s.vel
		kart.speed = s.speed
		kart.yaw = s.yaw
		kart.set_physics_process(bool(s.pp))
		kart.reset_physics_interpolation()
	_snapshot.clear()
	finished.emit()


## Interpolated transforms for race time `tt`.
func _apply(tt: float) -> void:
	var i := _index_at(tt)
	var j := mini(i + 1, _times.size() - 1)
	var span_t := maxf(_times[j] - _times[i], 0.0001)
	var w := clampf((tt - _times[i]) / span_t, 0.0, 1.0)
	var a: Array = _frames[i]
	var b: Array = _frames[j]
	for k in _karts.size():
		var kart := _karts[k] as KartController
		var xa: Transform3D = a[k]
		var xb: Transform3D = b[k]
		kart.global_transform = xa.interpolate_with(xb, w)
		kart.speed = lerpf((_speeds[i] as PackedFloat32Array)[k], (_speeds[j] as PackedFloat32Array)[k], w)


func _index_at(tt: float) -> int:
	# Binary search for the last frame with time <= tt.
	var lo := 0
	var hi := _times.size() - 1
	if tt <= _times[0]:
		return 0
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if _times[mid] <= tt:
			lo = mid
		else:
			hi = mid - 1
	return lo


## Transform of kart `k` at race time `tt` (tests).
func transform_at(k: int, tt: float) -> Transform3D:
	var i := _index_at(tt)
	var j := mini(i + 1, _times.size() - 1)
	var w := clampf((tt - _times[i]) / maxf(_times[j] - _times[i], 0.0001), 0.0, 1.0)
	return (_frames[i][k] as Transform3D).interpolate_with(_frames[j][k] as Transform3D, w)
