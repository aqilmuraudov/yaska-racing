class_name TrackData
extends RefCounted
## Loaded track definition (data/tracks/*.json) with resolved distances.
##
## Feature positions in the JSON are authored as world XZ points ("at") and
## resolved to arc length on load, so editing the centerline does not break
## checkpoints, pads or item rows.

const THEME_BOULEVARD := 0
const THEME_CONNECTOR := 1
const THEME_OLDCITY := 2
const THEME_DOWNTOWN := 3 ## 0.11.0 Göydələnlər şəhəri streets

var id := ""
var name_key := ""
var decor_kind := "seafront" ## "seafront" (TrackDecor) or "downtown" (DowntownDecor)
var ground := "" ## "" seafront hills, "city" flat paved blocks
var default_laps := 3
var main: TrackPath
var finish_s := 0.0
## Checkpoint distances along the main path. Index 0 is the finish line.
var checkpoint_s: Array[float] = []
var shortcuts: Array[Dictionary] = [] # {path, s_from, s_to, surface, side}
var boost_pads: Array[Dictionary] = [] # {s, lateral, length, width}
var ramps: Array[Dictionary] = [] # {s, length, height}
var item_rows: Array[Dictionary] = [] # {s, count}
var offroad_width := 4.0
var sea_z := 1.0e9
var sea_level := -1.6
var raw: Dictionary = {}


static func load_from_file(path: String) -> TrackData:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("TrackData: cannot parse %s" % path)
		return null
	return from_dict(parsed)


static func from_dict(d: Dictionary) -> TrackData:
	var td := TrackData.new()
	td.raw = d
	td.id = d.get("id", "track")
	td.name_key = d.get("name_key", "")
	td.decor_kind = String(d.get("decor", "seafront"))
	td.ground = String(d.get("ground", ""))
	td.default_laps = int(d.get("laps", 3))
	td.offroad_width = float(d.get("offroad_width", 4.0))
	if d.has("sea"):
		td.sea_z = float(d.sea.z)
		td.sea_level = float(d.sea.level)
	td.main = TrackPath.from_control_points(_control(d.control), true)
	td.finish_s = td.resolve(d.get("finish_at", [0, 0]))
	td.checkpoint_s.append(td.finish_s)
	for at in d.get("checkpoints_at", []):
		td.checkpoint_s.append(td.resolve(at))
	# Keep checkpoints in driving order starting from the finish line.
	var rel := td.checkpoint_s.slice(1)
	rel.sort_custom(func(a, b): return td.main.forward_delta(td.finish_s, a) < td.main.forward_delta(td.finish_s, b))
	td.checkpoint_s = [td.finish_s]
	td.checkpoint_s.append_array(rel)
	for sc in d.get("shortcuts", []):
		var path := TrackPath.from_control_points(_control(sc.control), false)
		var s_from: float = td.main.closest(path.points[0]).s
		var s_to: float = td.main.closest(path.points[path.points.size() - 1]).s
		var side := signf(td.main.closest(path.position_at(minf(20.0, path.length * 0.3))).lateral)
		td.shortcuts.append({"path": path, "s_from": s_from, "s_to": s_to,
			"surface": StringName(sc.get("surface", "rough")), "side": side})
	for pad in d.get("boost_pads", []):
		td.boost_pads.append({"s": td.resolve(pad.at), "lateral": float(pad.get("lateral", 0.0)),
			"length": float(pad.get("length", 6.0)), "width": float(pad.get("width", 4.0))})
	for r in d.get("ramps", []):
		td.ramps.append({"s": td.resolve(r.at), "length": float(r.get("length", 6.0)),
			"height": float(r.get("height", 1.4))})
	for row in d.get("item_rows", []):
		td.item_rows.append({"s": td.resolve(row.at), "count": int(row.get("count", 4))})
	return td


static func _control(list: Array) -> Array:
	var out: Array = []
	for e in list:
		# [x, y, z, width, theme]
		out.append({"p": Vector3(e[0], e[1], e[2]), "w": float(e[3]), "theme": int(e[4]) if e.size() > 4 else 0})
	return out


func resolve(at) -> float:
	if typeof(at) == TYPE_FLOAT or typeof(at) == TYPE_INT:
		return main.wrap_s(float(at))
	var p := Vector3(at[0], 0.0, at[1]) if at.size() == 2 else Vector3(at[0], at[1], at[2])
	return main.closest(p).s


func checkpoint_count() -> int:
	return checkpoint_s.size()


## Distance along the race from the finish line to checkpoint index `cp`.
func checkpoint_offset(cp: int) -> float:
	return main.forward_delta(finish_s, checkpoint_s[cp % checkpoint_s.size()])


func lap_length() -> float:
	return main.length


## Projects a world position onto the race route, including shortcuts.
## Returns {s (main-equivalent), lateral, distance, on_shortcut, half_width}.
func project(pos: Vector3, hint_s: float = -1.0) -> Dictionary:
	var m := main.closest(pos, hint_s, 45.0)
	var best := {"s": m.s, "lateral": m.lateral, "distance": m.distance,
		"on_shortcut": -1, "half_width": main.half_width_at(m.s)}
	var main_excess: float = m.distance - main.half_width_at(m.s)
	for i in shortcuts.size():
		var sc: Dictionary = shortcuts[i]
		var p: TrackPath = sc.path
		# 0.17.4: a shortcut can only win within its widest half width +
		# run-off + 2 m (the check below) - skip the full search beyond that.
		if not p.near_xz(pos, offroad_width + 2.5):
			continue
		var c := p.closest(pos)
		var excess: float = c.distance - p.half_width_at(c.s)
		if excess < main_excess and c.distance < p.half_width_at(c.s) + offroad_width + 2.0:
			var span := main.forward_delta(sc.s_from, sc.s_to)
			var mapped := main.wrap_s(sc.s_from + span * (c.s / maxf(p.length, 0.01)))
			best = {"s": mapped, "lateral": c.lateral, "distance": c.distance,
				"on_shortcut": i, "half_width": p.half_width_at(c.s)}
			main_excess = excess
	return best


## Driving-direction tangent at the projected location.
func route_tangent(pos: Vector3, proj: Dictionary) -> Vector3:
	if int(proj.on_shortcut) >= 0:
		var p: TrackPath = shortcuts[proj.on_shortcut].path
		return p.tangent_at(p.closest(pos).s)
	return main.tangent_at(proj.s)
