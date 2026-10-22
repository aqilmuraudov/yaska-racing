class_name TrackPath
extends RefCounted
## Evenly resampled centerline (closed loop or open branch) with per-sample
## width and elevation. Pure math, no scene dependencies, so race progress,
## AI and the mesh builder all agree on one definition of "the track".

const SAMPLE_SPACING := 2.0

var points := PackedVector3Array()
var cum := PackedFloat32Array() # distance from start at each sample
var half_widths := PackedFloat32Array()
var themes := PackedInt32Array()
var closed := true
var length := 0.0


## control: Array of Dictionaries {p: Vector3, w: float (full width), theme: int}
static func from_control_points(control: Array, is_closed: bool, spacing: float = SAMPLE_SPACING) -> TrackPath:
	var tp := TrackPath.new()
	tp.closed = is_closed
	var n := control.size()
	if n < (3 if is_closed else 2):
		push_error("TrackPath: not enough control points")
		return tp
	# Dense Catmull-Rom (centripetal) polyline first.
	var dense: Array[Vector3] = []
	var dense_w: Array[float] = []
	var dense_t: Array[int] = []
	var seg_count := n if is_closed else n - 1
	for i in seg_count:
		var p0: Dictionary = control[_wrap(i - 1, n, is_closed)]
		var p1: Dictionary = control[i]
		var p2: Dictionary = control[_wrap(i + 1, n, is_closed)]
		var p3: Dictionary = control[_wrap(i + 2, n, is_closed)]
		var steps := maxi(4, int(p1.p.distance_to(p2.p) / 0.5))
		for s in steps:
			var t := float(s) / steps
			dense.append(_centripetal(p0.p, p1.p, p2.p, p3.p, t))
			dense_w.append(lerpf(p1.w, p2.w, smoothstep(0.0, 1.0, t)))
			dense_t.append(p1.theme if t < 0.5 else p2.theme)
	if not is_closed:
		var last: Dictionary = control[n - 1]
		dense.append(last.p)
		dense_w.append(last.w)
		dense_t.append(last.theme)
	# Resample at uniform arc length.
	var dense_cum: Array[float] = [0.0]
	for i in range(1, dense.size()):
		dense_cum.append(dense_cum[i - 1] + dense[i].distance_to(dense[i - 1]))
	var total := dense_cum[dense_cum.size() - 1]
	if is_closed:
		total += dense[dense.size() - 1].distance_to(dense[0])
	var count := maxi(2, int(round(total / spacing)))
	var step := total / count
	var j := 0
	var sample_total := count if is_closed else count + 1
	for k in sample_total:
		var target := k * step
		while j < dense.size() - 1 and dense_cum[j + 1] < target:
			j += 1
		var a := dense[j]
		var b: Vector3
		var seg_len: float
		var bw: float
		if j < dense.size() - 1:
			b = dense[j + 1]
			seg_len = dense_cum[j + 1] - dense_cum[j]
			bw = dense_w[j + 1]
		else:
			b = dense[0] if is_closed else dense[j]
			seg_len = total - dense_cum[j] if is_closed else 0.0
			bw = dense_w[0] if is_closed else dense_w[j]
		var f := 0.0 if seg_len <= 0.0001 else clampf((target - dense_cum[j]) / seg_len, 0.0, 1.0)
		tp.points.append(a.lerp(b, f))
		tp.half_widths.append(lerpf(dense_w[j], bw, f) * 0.5)
		tp.themes.append(dense_t[j])
		tp.cum.append(target)
	tp.length = total
	return tp


static func _wrap(i: int, n: int, is_closed: bool) -> int:
	if is_closed:
		return posmod(i, n)
	return clampi(i, 0, n - 1)


static func _centripetal(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var alpha := 0.5
	var t0 := 0.0
	var t1 := t0 + pow(maxf(p0.distance_to(p1), 0.001), alpha)
	var t2 := t1 + pow(maxf(p1.distance_to(p2), 0.001), alpha)
	var t3 := t2 + pow(maxf(p2.distance_to(p3), 0.001), alpha)
	var tt := lerpf(t1, t2, t)
	var a1 := p0 * ((t1 - tt) / (t1 - t0)) + p1 * ((tt - t0) / (t1 - t0))
	var a2 := p1 * ((t2 - tt) / (t2 - t1)) + p2 * ((tt - t1) / (t2 - t1))
	var a3 := p2 * ((t3 - tt) / (t3 - t2)) + p3 * ((tt - t2) / (t3 - t2))
	var b1 := a1 * ((t2 - tt) / (t2 - t0)) + a2 * ((tt - t0) / (t2 - t0))
	var b2 := a2 * ((t3 - tt) / (t3 - t1)) + a3 * ((tt - t1) / (t3 - t1))
	return b1 * ((t2 - tt) / (t2 - t1)) + b2 * ((tt - t1) / (t2 - t1))


func sample_count() -> int:
	return points.size()


func wrap_s(s: float) -> float:
	if closed:
		return fposmod(s, length)
	return clampf(s, 0.0, length)


func _index_at(s: float) -> int:
	var count := points.size()
	var idx := int(s / (length / (count if closed else count - 1)))
	return clampi(idx, 0, count - 1)


func _seg(s: float) -> Array:
	s = wrap_s(s)
	var count := points.size()
	var step := length / (count if closed else count - 1)
	var i := clampi(int(s / step), 0, count - 1)
	var i2 := (i + 1) % count if closed else mini(i + 1, count - 1)
	var f := clampf((s - i * step) / step, 0.0, 1.0)
	return [i, i2, f]


func position_at(s: float) -> Vector3:
	var g := _seg(s)
	return points[g[0]].lerp(points[g[1]], g[2])


func half_width_at(s: float) -> float:
	var g := _seg(s)
	return lerpf(half_widths[g[0]], half_widths[g[1]], g[2])


func theme_at(s: float) -> int:
	return themes[_seg(s)[0]]


## Horizontal-ish forward tangent (includes slope).
func tangent_at(s: float) -> Vector3:
	var a := position_at(s - 1.0)
	var b := position_at(s + 1.0)
	var d := b - a
	if d.length_squared() < 0.0001:
		return Vector3.FORWARD
	return d.normalized()


## Right vector on the horizontal plane (perpendicular to tangent, y = 0).
func right_at(s: float) -> Vector3:
	var t := tangent_at(s)
	var r := Vector3(-t.z, 0.0, t.x)
	if r.length_squared() < 0.0001:
		return Vector3.RIGHT
	return r.normalized()


## Signed heading change per meter (radians/m), positive = turning right.
func curvature_at(s: float, span: float = 6.0) -> float:
	var t1 := tangent_at(s - span)
	var t2 := tangent_at(s + span)
	var a1 := atan2(t1.x, -t1.z)
	var a2 := atan2(t2.x, -t2.z)
	return wrapf(a2 - a1, -PI, PI) / (2.0 * span)


## Closest point query. `hint_s` < 0 does a full search; otherwise only
## samples within `window` meters of the hint are considered, which avoids
## snapping to a nearby but unrelated part of the circuit.
## Returns {s, lateral, distance, point}.
func closest(pos: Vector3, hint_s: float = -1.0, window: float = 40.0) -> Dictionary:
	var count := points.size()
	var best_i := 0
	var best_d := INF
	if hint_s < 0.0:
		for i in count:
			var d := _flat_dist_sq(points[i], pos)
			if d < best_d:
				best_d = d
				best_i = i
	else:
		var step := length / (count if closed else count - 1)
		var center := _index_at(wrap_s(hint_s))
		var reach := int(ceil(window / step))
		for k in range(-reach, reach + 1):
			var i := center + k
			if closed:
				i = posmod(i, count)
			elif i < 0 or i >= count:
				continue
			var d := _flat_dist_sq(points[i], pos)
			# Small elevation term separates stacked sections.
			d += pow(points[i].y - pos.y, 2) * 0.25
			if d < best_d:
				best_d = d
				best_i = i
	# Refine against the two neighbouring segments.
	var best_s := cum[best_i]
	var best_point := points[best_i]
	var best_dist := INF
	for seg_start in [best_i - 1, best_i]:
		var a_i: int = seg_start
		var b_i: int = seg_start + 1
		if closed:
			a_i = posmod(a_i, count)
			b_i = posmod(b_i, count)
		elif a_i < 0 or b_i >= count:
			continue
		var a := points[a_i]
		var b := points[b_i]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ap := Vector2(pos.x - a.x, pos.z - a.z)
		var l2 := ab.length_squared()
		var f := 0.0 if l2 < 0.0001 else clampf(ap.dot(ab) / l2, 0.0, 1.0)
		var q := a.lerp(b, f)
		var dd := Vector2(pos.x - q.x, pos.z - q.z).length()
		if dd < best_dist:
			best_dist = dd
			best_point = q
			var sa := cum[a_i]
			var seg_len := sqrt(l2)
			best_s = wrap_s(sa + f * seg_len)
	var right := right_at(best_s)
	var lateral := (pos - best_point).dot(right)
	return {"s": best_s, "lateral": lateral, "distance": best_dist, "point": best_point}


static func _flat_dist_sq(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz


## Forward distance from s_from to s_to along a closed loop (0..length).
func forward_delta(s_from: float, s_to: float) -> float:
	if closed:
		return fposmod(s_to - s_from, length)
	return s_to - s_from
