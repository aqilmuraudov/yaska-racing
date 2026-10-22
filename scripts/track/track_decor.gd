class_name TrackDecor
extends Node3D
## Places Baku scenery around the generated circuit.
##
## Rules that keep the race readable:
## - Nothing is placed inside any driving corridor (road + off-road + margin);
##   every candidate footprint is tested against all paths.
## - Overhead features (gate, gantry, bunting) keep >= 7 m clearance.
## - Decor is visual only. Race-critical collision lives in TrackBuilder and
##   is identical on every graphics preset.
## - Repeated props are MultiMesh-instanced in spatial chunks so the
##   "scenery distance" setting can cull them; landmarks are always visible.

const CHUNK := 140.0
const NO_SHADOW_PROPS := ["bench", "bollard", "umbrella", "kiosk", "baluster", "chevron_left", "chevron_right", "tire_stack", "boat"]

var data: TrackData
var builder: TrackBuilder
var rng := RandomNumberGenerator.new()
var _instances := {} # prop_id -> {chunk_key: [Transform3D]}
var _chunk_nodes: Array[GeometryInstance3D] = []
var _carpets: Array = []
var wheel_ring: Node3D
var gantry_lights: Array[MeshInstance3D] = []
var _light_on_mat: StandardMaterial3D
var _light_off_mat: StandardMaterial3D


func build(td: TrackData, env: RaceEnvironment) -> void:
	data = td
	builder = get_parent().get_node_or_null("Track")
	rng.seed = 20251022
	_place_wall_props()
	_place_promenade()
	_place_boulevard_inland()
	_place_old_city()
	_place_connector_greenery()
	_place_corner_signs()
	_place_landmarks()
	_place_bunting()
	_place_backdrop()
	_flush_instances()
	_flush_carpets()
	if env:
		env.decor_distance_changed.connect(set_decor_distance)
		set_decor_distance(env.decor_distance())


# --- Helpers ------------------------------------------------------------------

func _paths() -> Array:
	var list: Array = [{"path": data.main, "ow": data.offroad_width, "index": -1}]
	for i in data.shortcuts.size():
		list.append({"path": data.shortcuts[i].path, "ow": 1.2, "index": i})
	return list


## True when point p (with radius r) is clear of every driving corridor.
func clear_of_track(p: Vector3, r: float, margin: float = 1.0) -> bool:
	for e in _paths():
		var path: TrackPath = e.path
		var c := path.closest(p)
		var limit: float = path.half_width_at(c.s) + e.ow + 0.6 + margin + r
		if c.distance < limit:
			return false
	return true


func ground_y(p: Vector3) -> float:
	var c := data.main.closest(p)
	var y := data.main.position_at(c.s).y
	for sc in data.shortcuts:
		var cc: Dictionary = sc.path.closest(p)
		if cc.distance < c.distance:
			c = cc
			y = sc.path.position_at(cc.s).y
	if p.z > data.sea_z - 16.0 and p.z <= data.sea_z:
		y = maxf(y, -0.06)
	return y - 0.05


func add_instance(prop: String, xform: Transform3D) -> void:
	if not _instances.has(prop):
		_instances[prop] = {}
	var key := Vector2i(int(floor(xform.origin.x / CHUNK)), int(floor(xform.origin.z / CHUNK)))
	if not _instances[prop].has(key):
		_instances[prop][key] = []
	_instances[prop][key].append(xform)


func _flush_instances() -> void:
	for prop in _instances.keys():
		var mesh := PropKit.get_mesh(prop)
		for key in _instances[prop].keys():
			var list: Array = _instances[prop][key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d_%d" % [prop, key.x, key.y]
			mmi.multimesh = mm
			mmi.visibility_range_end_margin = 20.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			if prop in NO_SHADOW_PROPS:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
			_chunk_nodes.append(mmi)
	_instances.clear()


func set_decor_distance(meters: float) -> void:
	for n in _chunk_nodes:
		if is_instance_valid(n):
			n.visibility_range_end = meters
	for c in _carpets:
		if is_instance_valid(c):
			c.visibility_range_end = meters * 0.6


func _face(pos: Vector3, forward: Vector3) -> Transform3D:
	# Local +Z faces `forward`.
	var f := Vector3(forward.x, 0, forward.z).normalized()
	var basis := Basis.looking_at(-f, Vector3.UP)
	return Transform3D(basis, pos)


func _landmark(mesh: Mesh, xform: Transform3D, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.transform = xform
	add_child(mi)
	return mi


# --- Barrier-line props ----------------------------------------------------------

func _place_wall_props() -> void:
	if builder == null:
		return
	var acc := 0.0
	for seg in builder.wall_segments:
		var a: Vector3 = seg.a
		var b: Vector3 = seg.b
		var out: Vector3 = seg.out
		var length := a.distance_to(b)
		if seg.style == "balustrade":
			# One 2 m baluster segment per 2 m of barrier, facing outwards.
			acc += length
			while acc >= 2.0:
				acc -= 2.0
				var t := clampf(1.0 - acc / maxf(length, 0.01), 0.0, 1.0)
				var p := a.lerp(b, t) + out * 0.22 + Vector3.UP * 0.22
				var along := (b - a).normalized()
				var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP)).orthonormalized()
				add_instance("baluster", Transform3D(basis, p))


# --- Boulevard ---------------------------------------------------------------------

func _place_promenade() -> void:
	var sea := data.sea_z
	var x0 := -330.0
	var x1 := 300.0
	# Sea-edge balustrade along the seawall.
	var x := x0
	while x < x1:
		var p := Vector3(x, -0.05, sea - 0.4)
		add_instance("baluster", Transform3D(Basis.IDENTITY, p))
		x += 2.0
	# Palms and lamps alternate along the promenade, benches between.
	x = x0 + 4.0
	var k := 0
	while x < x1:
		var pz := sea - 7.0
		var pp := Vector3(x + rng.randf_range(-1.0, 1.0), -0.05, pz)
		if clear_of_track(pp, 1.0, 0.5):
			if k % 2 == 0:
				add_instance("palm" if k % 4 == 0 else "palm_b", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pp))
			else:
				add_instance("lamp", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, -0.05, sea - 3.2)))
				add_instance("bench", _face(Vector3(x + 4.0, -0.05, sea - 2.0), Vector3(0, 0, -1)))
		x += 11.0
		k += 1
	# Café clusters with umbrellas and kiosks.
	for cx in [-250.0, -60.0, 60.0, 140.0]:
		for j in 4:
			var up := Vector3(cx + j * 4.5, -0.05, sea - 11.5 + (j % 2) * 2.5)
			if clear_of_track(up, 2.0, 0.5):
				add_instance("umbrella", Transform3D(Basis.IDENTITY, up))
		var kp := Vector3(cx - 6.0, -0.05, sea - 11.0)
		if clear_of_track(kp, 2.5, 0.5):
			add_instance("kiosk", _face(kp, Vector3(0, 0, -1)))
	# Fountain plaza
	var fp := Vector3(-110.0, -0.05, sea - 10.0)
	if clear_of_track(fp, 3.5, 0.5):
		_landmark(PropKit.get_mesh("fountain"), Transform3D(Basis.IDENTITY, fp), "Fountain")
	# Boats on the Caspian
	for i in 7:
		var bp := Vector3(rng.randf_range(-400.0, 400.0), data.sea_level + 0.1, sea + rng.randf_range(40.0, 260.0))
		add_instance("boat", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), bp))


func _place_boulevard_inland() -> void:
	# Park trees then a row of modern blocks behind the inland barrier.
	var s := 0.0
	var L := data.main.length
	var mods := ["modern_a", "modern_b", "modern_c"]
	var mi := 0
	while s < L:
		if data.main.theme_at(s) == TrackData.THEME_BOULEVARD:
			var p := data.main.position_at(s)
			var r := data.main.right_at(s)
			var hw := data.main.half_width_at(s)
			var inward := -r if r.z > 0.0 else r # side away from the sea
			if absf(r.z) > 0.6:
				var tp := p + inward * (hw + data.offroad_width + 5.0 + rng.randf_range(0.0, 4.0))
				if clear_of_track(tp, 2.0):
					add_instance("tree" if rng.randf() < 0.7 else "cypress", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(tp.x, ground_y(tp), tp.z)))
				if int(s) % 36 < 12:
					var bp := p + inward * (hw + data.offroad_width + 26.0)
					if clear_of_track(bp, 12.0):
						add_instance(mods[mi % 3], _face(Vector3(bp.x, ground_y(bp), bp.z), -inward))
						mi += 1
		s += 12.0
	# Grandstand facing the start/finish straight.
	var fs := data.finish_s + 12.0
	var fp := data.main.position_at(fs)
	var fr := data.main.right_at(fs)
	var inward2 := -fr if fr.z > 0.0 else fr
	var gp := fp + inward2 * (data.main.half_width_at(fs) + data.offroad_width + 4.0)
	_landmark(PropKit.get_mesh("grandstand"), _face(Vector3(gp.x, ground_y(gp), gp.z), -inward2), "Grandstand")


# --- Old City ------------------------------------------------------------------------

func _place_old_city() -> void:
	var houses := ["house_a", "house_b", "house_c", "house_d"]
	var widths := {"house_a": 9.0, "house_b": 8.0, "house_c": 10.0, "house_d": 7.5}
	var tower_pos := _tower_position()
	var carpet_idx := 0
	for e in _paths():
		var path: TrackPath = e.path
		for side: float in [-1.0, 1.0]:
			var s := 0.0
			while s < path.length:
				if path.theme_at(s) != TrackData.THEME_OLDCITY:
					s += 4.0
					continue
				var id: String = houses[rng.randi() % houses.size()]
				var w: float = widths[id]
				var sc := s + w * 0.5
				var p := path.position_at(sc)
				var r := path.right_at(sc)
				var off: float = path.half_width_at(sc) + e.ow + 0.6 + 0.9 + 4.0
				var c := p + r * side * off
				var corners := [c + r * side * 4.0, c - r * side * 4.0]
				var t := path.tangent_at(sc)
				var ok := clear_of_track(c, 3.6, 0.6)
				for q in corners:
					if not clear_of_track(q + t * (w * 0.45), 0.4, 0.4) or not clear_of_track(q - t * (w * 0.45), 0.4, 0.4):
						ok = false
				if tower_pos != Vector3.INF and Vector2(c.x - tower_pos.x, c.z - tower_pos.z).length() < 14.0:
					ok = false
				if ok:
					var gy := path.position_at(sc).y - 0.05
					var xf := _face(Vector3(c.x, gy, c.z), -r * side)
					add_instance(id, xf)
					# Carpets on some balconies / facades.
					if rng.randf() < 0.35:
						_add_carpet(xf, carpet_idx)
						carpet_idx += 1
					s += w + 0.4
				else:
					s += 3.0


var _carpet_xforms := {} # variant -> [Transform3D]


func _add_carpet(house_xf: Transform3D, idx: int) -> void:
	var variant := idx % 4
	var local := Vector3(rng.randf_range(-2.5, 2.5), 2.4, 4.08)
	if not _carpet_xforms.has(variant):
		_carpet_xforms[variant] = []
	_carpet_xforms[variant].append(house_xf * Transform3D(Basis.IDENTITY, local))


func _flush_carpets() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 2.4)
	for variant in _carpet_xforms.keys():
		var list: Array = _carpet_xforms[variant]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = quad
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = PropKit.carpet_material(variant)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_carpets.append(mmi)
	_carpet_xforms.clear()


func _tower_position() -> Vector3:
	if data.shortcuts.is_empty():
		return Vector3.INF
	var sc: Dictionary = data.shortcuts[0]
	var span := data.main.forward_delta(sc.s_from, sc.s_to)
	var apex := data.main.position_at(sc.s_from + span * 0.5)
	var mid: Vector3 = sc.path.position_at(sc.path.length * 0.5)
	return (apex + mid) * 0.5


# --- Greenery, signs ---------------------------------------------------------------

func _place_connector_greenery() -> void:
	var s := 0.0
	while s < data.main.length:
		if data.main.theme_at(s) == TrackData.THEME_CONNECTOR:
			var p := data.main.position_at(s)
			var r := data.main.right_at(s)
			var hw := data.main.half_width_at(s)
			for side: float in [-1.0, 1.0]:
				if rng.randf() < 0.75:
					var d := hw + data.offroad_width + 3.5 + rng.randf_range(0.0, 10.0)
					var tp := p + r * side * d
					if clear_of_track(tp, 2.0):
						var id := "cypress" if rng.randf() < 0.45 else ("tree" if rng.randf() < 0.7 else "palm_b")
						add_instance(id, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(tp.x, ground_y(tp), tp.z)))
		s += 9.0
	# Scatter trees across open ground (infield parks), away from the course.
	var b := AABB(data.main.points[0], Vector3.ZERO)
	for p2 in data.main.points:
		b = b.expand(p2)
	for i in 260:
		var q := Vector3(rng.randf_range(b.position.x - 60, b.end.x + 60), 0, rng.randf_range(b.position.z - 60, minf(b.end.z, data.sea_z - 20.0)))
		if clear_of_track(q, 3.0, 4.0):
			add_instance("tree" if rng.randf() < 0.65 else "cypress", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q.x, ground_y(q) - 0.1, q.z)))


func _place_corner_signs() -> void:
	var s := 0.0
	var L := data.main.length
	while s < L:
		var c := data.main.curvature_at(s, 8.0)
		if absf(c) > 0.016:
			# Outside of the corner: opposite to the turn direction.
			var outside := -signf(c)
			var p := data.main.position_at(s)
			var r := data.main.right_at(s)
			var off := data.main.half_width_at(s) + data.offroad_width + 1.6
			var sp := p + r * outside * off
			var t := data.main.tangent_at(s)
			if clear_of_track(sp, 0.2, -0.6):
				var xf := _face(Vector3(sp.x, p.y - 0.05, sp.z), -t)
				# Arrow points toward the inside of the corner (screen direction).
				add_instance("chevron_right" if c > 0.0 else "chevron_left", xf)
			var tp := p + r * outside * (off + 2.2)
			if rng.randf() < 0.5 and clear_of_track(tp, 0.5, -0.4):
				add_instance("tire_stack", Transform3D(Basis.IDENTITY, Vector3(tp.x, p.y - 0.05, tp.z)))
			s += 11.0
		else:
			s += 4.0


# --- Landmarks --------------------------------------------------------------------

func _place_landmarks() -> void:
	# Maiden-Tower-inspired keep inside the Old City block.
	var tp := _tower_position()
	if tp != Vector3.INF:
		_landmark(PropKit.get_mesh("maiden_tower"), Transform3D(Basis(Vector3.UP, 0.4), Vector3(tp.x, tp.y - 0.05, tp.z)), "OldTower")
	_build_gate()
	_build_gantry()
	# Observation wheel on the promenade near the east hairpin.
	var wp := Vector3(196.0, -0.05, data.sea_z - 8.0)
	var frame := _landmark(PropKit.get_mesh("wheel_frame"), Transform3D(Basis(Vector3.UP, PI * 0.5), wp), "WheelFrame")
	wheel_ring = Node3D.new()
	wheel_ring.name = "WheelRing"
	wheel_ring.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), wp + Vector3(0, 34.0, 0))
	add_child(wheel_ring)
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = PropKit.get_mesh("wheel_ring")
	wheel_ring.add_child(ring_mi)
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _build_gate() -> void:
	# Twin-tower gate at the first Old City section of the main route.
	var s := 0.0
	var prev := data.main.theme_at(0.0)
	var gate_s := -1.0
	while s < data.main.length:
		var th := data.main.theme_at(s)
		if th == TrackData.THEME_OLDCITY and prev != TrackData.THEME_OLDCITY:
			gate_s = s + 6.0
			break
		prev = th
		s += 2.0
	if gate_s < 0.0:
		return
	var p := data.main.position_at(gate_s)
	var r := data.main.right_at(gate_s)
	var t := data.main.tangent_at(gate_s)
	var half := data.main.half_width_at(gate_s) + data.offroad_width + 1.4
	var a := PropKit.Accum.new()
	var tower_h := 11.0
	for side: float in [-1.0, 1.0]:
		var c := r * side * (half + 1.8)
		a.add(PropKit.rbox(Vector3(3.6, tower_h, 3.6), 0.18), Transform3D(Basis.IDENTITY, c + Vector3.UP * tower_h * 0.5), PropKit.m("limestone_warm"))
		for k in 4:
			var ang := TAU * k / 4.0 + PI * 0.25
			a.add(PropKit.box(Vector3(0.9, 1.0, 0.9)), Transform3D(Basis.IDENTITY, c + Vector3(cos(ang) * 1.5, tower_h + 0.5, sin(ang) * 1.5)), PropKit.m("limestone"))
	# Arch beam high above the road (clearance > 8 m).
	var span := (half + 1.8) * 2.0
	a.add(PropKit.rbox(Vector3(span, 1.6, 2.4), 0.15), Transform3D(Basis.IDENTITY, Vector3.UP * (tower_h - 1.6)), PropKit.m("limestone_warm"))
	a.add(PropKit.rbox(Vector3(span - 3.0, 0.5, 2.6), 0.2), Transform3D(Basis.IDENTITY, Vector3.UP * (tower_h - 0.6)), PropKit.m("limestone"))
	var basis := Basis(r, Vector3.UP, r.cross(Vector3.UP)).orthonormalized()
	_landmark(a.commit(), Transform3D(basis, p + Vector3.DOWN * 0.05), "CityGate")


func _build_gantry() -> void:
	var s := data.finish_s
	var p := data.main.position_at(s)
	var r := data.main.right_at(s)
	var half := data.main.half_width_at(s) + 1.6
	var a := PropKit.Accum.new()
	var h := 7.6
	for side: float in [-1.0, 1.0]:
		a.add(PropKit.rbox(Vector3(0.9, h, 0.9), 0.2), Transform3D(Basis.IDENTITY, Vector3(side * half, h * 0.5, 0)), PropKit.m("navy"))
	a.add(PropKit.rbox(Vector3(half * 2.0 + 1.2, 1.5, 1.0), 0.2), Transform3D(Basis.IDENTITY, Vector3(0, h + 0.3, 0)), PropKit.m("navy"))
	# Checkered band
	for i in 24:
		var x := -half + (i + 0.5) * (half * 2.0 / 24.0)
		a.add(PropKit.box(Vector3(half * 2.0 / 24.0, 0.5, 0.05)), Transform3D(Basis.IDENTITY, Vector3(x, h + 0.65, 0.52)), PropKit.m("white" if i % 2 == 0 else "navy"))
		a.add(PropKit.box(Vector3(half * 2.0 / 24.0, 0.5, 0.05)), Transform3D(Basis.IDENTITY, Vector3(x, h - 0.05, 0.52)), PropKit.m("navy" if i % 2 == 0 else "white"))
	var basis := Basis(r, Vector3.UP, r.cross(Vector3.UP)).orthonormalized()
	var gantry := _landmark(a.commit(), Transform3D(basis, p + Vector3.DOWN * 0.05), "StartGantry")
	# Countdown lights (lit by RaceManager's countdown signal).
	_light_on_mat = StandardMaterial3D.new()
	_light_on_mat.albedo_color = Color("ff3b3b")
	_light_on_mat.emission_enabled = true
	_light_on_mat.emission = Color("ff3b3b")
	_light_on_mat.emission_energy_multiplier = 3.0
	_light_off_mat = StandardMaterial3D.new()
	_light_off_mat.albedo_color = Color("3a1f24")
	for i in 3:
		var l := MeshInstance3D.new()
		l.mesh = ShapeKit.sphere(0.45, 14, 8)
		l.material_override = _light_off_mat
		l.position = Vector3(-1.6 + i * 1.6, h + 0.3, -0.6)
		gantry.add_child(l)
		gantry_lights.append(l)


## 3, 2, 1 → red lights; 0 → all green.
func set_countdown_lights(value: int) -> void:
	if gantry_lights.is_empty():
		return
	var green := StandardMaterial3D.new()
	green.albedo_color = Color("46e06b")
	green.emission_enabled = true
	green.emission = Color("46e06b")
	green.emission_energy_multiplier = 3.0
	for i in gantry_lights.size():
		if value <= 0:
			gantry_lights[i].material_override = green
		else:
			gantry_lights[i].material_override = _light_on_mat if i < 4 - value else _light_off_mat


func reset_lights() -> void:
	for l in gantry_lights:
		l.material_override = _light_off_mat


func _place_bunting() -> void:
	# Pennant strings across the road on the boulevard and in the Old City.
	var mb_cols := ["red", "turquoise", "gold", "white", "green", "orange"]
	var all := PropKit.Accum.new()
	var s := 30.0
	while s < data.main.length:
		var th := data.main.theme_at(s)
		if th == TrackData.THEME_CONNECTOR or absf(data.main.curvature_at(s)) > 0.012:
			s += 20.0
			continue
		var p := data.main.position_at(s)
		var r := data.main.right_at(s)
		var half := data.main.half_width_at(s) + data.offroad_width + 0.9
		var left := p - r * half + Vector3.UP * 8.2
		var right := p + r * half + Vector3.UP * 8.2
		var a := PropKit.Accum.new()
		for side: float in [-1.0, 1.0]:
			a.add(ShapeKit.cylinder(0.08, 8.6, 6), Transform3D(Basis.IDENTITY, p + r * side * half + Vector3.UP * 4.25 - p), PropKit.m("metal_grey"))
		var n := int(half * 2.0 / 1.1)
		for i in n:
			var f := (i + 0.5) / n
			var pos := left.lerp(right, f) + Vector3.DOWN * (sin(f * PI) * 1.2) - p
			var mbld := MeshBuilder.new()
			var w := r * 0.42
			mbld.tri(pos - w, pos + w, pos + Vector3.DOWN * 0.75)
			mbld.tri(pos + w, pos - w, pos + Vector3.DOWN * 0.75)
			a.add_builder(mbld, PropKit.m(mb_cols[i % mb_cols.size()]))
		all.add_committed(a.commit(), Transform3D(Basis.IDENTITY, p))
		s += 70.0 if th == TrackData.THEME_BOULEVARD else 45.0
	var mi := _landmark(all.commit(), Transform3D.IDENTITY, "Bunting")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Skyline & backdrop --------------------------------------------------------------

func _place_backdrop() -> void:
	# Distant hills ring so the world does not end at the terrain edge.
	var b := AABB(data.main.points[0], Vector3.ZERO)
	for p in data.main.points:
		b = b.expand(p)
	var center := b.get_center()
	var hill_mat := ShapeKit.mat(Color("8fb07a"), 0.95)
	var hill_mat2 := ShapeKit.mat(Color("b9a47c"), 0.95)
	var a := PropKit.Accum.new()
	for i in 28:
		var ang := PI + PI * float(i) / 27.0 # northern half (inland)
		var dist := rng.randf_range(560.0, 760.0)
		var hp := center + Vector3(cos(ang) * dist * 1.3, -6.0, sin(ang) * dist)
		var sz := Vector3(rng.randf_range(160, 320), rng.randf_range(40, 95), rng.randf_range(120, 220))
		a.add(ShapeKit.superellipsoid(sz, 1.0, 1.0, Vector2.ONE, Vector2.ONE, 8, 12), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), hp), hill_mat if i % 3 else hill_mat2)
	var hills := _landmark(a.commit(), Transform3D.IDENTITY, "Hills")
	hills.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Flame-like towers on the hill to the north-west, glass towers north-east.
	var flames := [["flame_a", Vector3(-560, 22, -560)], ["flame_b", Vector3(-610, 22, -520)], ["flame_c", Vector3(-600, 22, -610)]]
	for f in flames:
		var mi := _landmark(PropKit.get_mesh(f[0]), Transform3D(Basis(Vector3.UP, 0.6), f[1]), f[0])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var towers := [["tower_a", Vector3(430, 0, -420)], ["tower_b", Vector3(470, 0, -360)], ["tower_c", Vector3(520, 0, -440)],
		["tower_b", Vector3(380, 0, -480)], ["tower_a", Vector3(560, 0, -330)], ["modern_b", Vector3(330, 0, -380)]]
	for tw in towers:
		var mi2 := _landmark(PropKit.get_mesh(tw[0]), Transform3D(Basis(Vector3.UP, rng.randf() * 0.6), tw[1]), tw[0])
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Low city blocks filling the middle distance.
	var city := PropKit.Accum.new()
	var plaster := [PropKit.m("plaster_cream"), PropKit.m("plaster_peach"), PropKit.m("plaster_white"), PropKit.m("limestone_warm")]
	for i in 180:
		var q := Vector3(rng.randf_range(b.position.x - 260, b.end.x + 260), 0, rng.randf_range(b.position.z - 300, b.position.z - 150))
		if not clear_of_track(q, 20.0, 30.0):
			continue
		var bh := rng.randf_range(8.0, 30.0)
		var bs := Vector3(rng.randf_range(10, 24), bh, rng.randf_range(10, 22))
		city.add(PropKit.box(bs), Transform3D(Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)), q + Vector3(0, bh * 0.5 - 1.0, 0)), plaster[i % plaster.size()])
	var city_mi := _landmark(city.commit(), Transform3D.IDENTITY, "CityBlocks")
	city_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	if wheel_ring:
		wheel_ring.rotate_object_local(Vector3.BACK, delta * 0.05)
