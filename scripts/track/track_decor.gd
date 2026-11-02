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

const CHUNK := 70.0 ## 0.10.2: 140 -> 70 m for tighter culling and LOD
## 0.10.2: chunk-centre distance where decor switches to the far LOD mesh
## (Low 60 m, Medium ~109 m, High 200 m; see lod_for).
const LOD_DISTANCE := 109.0
var lod_distance := LOD_DISTANCE


static func lod_for(decor_meters: float) -> float:
	return clampf(decor_meters * 0.42, 60.0, 200.0)
const NO_SHADOW_PROPS := ["bench", "bollard", "umbrella", "kiosk", "baluster", "chevron_left", "chevron_right", "tire_stack", "boat"]

var _lod_nodes: Array = []
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
## Landmark footprints: [centre, radius]; scatter and buildings keep out.
var _reserved: Array = []
## Placed Baku landmarks by id (tests and screenshot views use these).
var landmarks := {}
const WHEEL_SITE := Vector3(-40.0, 0.0, 22.0)
## 0.15.3 (owner: mini Baku): real west-to-east order along the bay (+x is
## east, the sea is +z): Flag Square + Crystal Hall at Bayil in the west, the
## TV tower on the western hill, Flame Towers and the Carpet Museum west of
## the centre, Government House in the centre-east, Port Baku and the
## the Crescent in the east, the Heydar Aliyev Center inland to the north-east.
## 0.17.3 (owner: the landmarks stood too far from the road to be seen or
## recognised): every one moved up to the road, ~5 m behind the run-off,
## keeping the west-to-east order.
const LANDMARK_SITES := {
	# id: [x, z, footprint radius, yaw]
	"flag_square": [-353.0, -27.0, 36.0, 0.0],
	"heydar_aliyev": [175.0, -285.0, 66.0, 0.45],
	"flame_towers": [-164.0, -404.0, 66.0, 0.69],
	# Crescent stands on the shore of the Boulevard, facing Port Baku Mall
	# across the avenue (owner).
	"crescent": [266.0, 38.0, 42.0, 0.0],
	"government_house": [41.0, -43.0, 64.0, 0.0],
	# Lies along the Boulevard like the real rolled carpet.
	"carpet_museum": [-226.0, -55.5, 56.0, 0.0],
	"port_baku": [317.0, -53.0, 38.0, 0.0],
}


func build(td: TrackData, env: RaceEnvironment) -> void:
	for step in build_steps(td, env):
		step.call()


## The build as separate steps, so the loading screen can keep animating and
## report real progress between them. Order matters; run all of them.
func build_steps(td: TrackData, env: RaceEnvironment) -> Array[Callable]:
	return [
		func(): _begin(td); _reserve_seafront(),
		_place_wall_props,
		_place_promenade,
		_place_boulevard_inland,
		_place_old_city,
		_place_connector_greenery,
		_place_corner_signs,
		_place_landmarks,
		_place_bunting,
		_place_backdrop,
		_place_baku_extras,
		_flush_instances,
		func(): _finish(env),
	]


func _begin(td: TrackData) -> void:
	data = td
	builder = get_parent().get_node_or_null("Track")
	rng.seed = 20251022


## Seafront plots (before 0.17.3 every map reserved them, which left holes
## in the Old City where the seafront landmarks would stand).
func _reserve_seafront() -> void:
	for id in LANDMARK_SITES.keys():
		var site: Array = LANDMARK_SITES[id]
		_reserved.append([Vector3(site[0], 0.0, site[1]), float(site[2])])
		if id in ["government_house", "carpet_museum"]:
			# Long buildings: the round plot does not reach their ends.
			_reserve_footprint(Vector3(site[0], 0.0, site[1]), float(site[3]), 1.5 if id == "carpet_museum" else 1.0,
				LandmarkKit.get_mesh(id).get_aabb())
	for id in EXTRA_SITES.keys():
		var es: Array = EXTRA_SITES[id]
		_reserved.append([Vector3(es[0], 0.0, es[1]), float(es[3])])
	_reserved.append([WHEEL_SITE, 34.0])


## Reserves a row of circles covering a (turned, scaled) mesh footprint.
func _reserve_footprint(c: Vector3, yaw: float, scale: float, bb: AABB) -> void:
	var b := Basis(Vector3.UP, yaw)
	var long_x := bb.size.x >= bb.size.z
	var r := minf(bb.size.x, bb.size.z) * 0.5 * scale + 1.0
	var length := maxf(bb.size.x, bb.size.z) * scale
	var mid := (bb.position + bb.size * 0.5) * scale
	var n := int(ceil(length / r))
	for i in n + 1:
		var t := -length * 0.5 + length * i / n
		var local := Vector3(mid.x + (t if long_x else 0.0), 0.0, mid.z + (0.0 if long_x else t))
		var w := c + b * local
		_reserved.append([Vector3(w.x, 0.0, w.z), r])


func _finish(env: RaceEnvironment) -> void:
	_flush_carpets()
	_build_ao_map()
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
	for z in _reserved:
		if Vector2(p.x - z[0].x, p.z - z[0].z).length() < z[1] + r:
			return false
	for e in _paths():
		var path: TrackPath = e.path
		var c := path.closest(p)
		var limit: float = path.half_width_at(c.s) + e.ow + 0.6 + margin + r
		if c.distance < limit:
			return false
	return true


## 0.17.3: a turned footprint (mesh AABB at p, yaw) clear of every driving
## corridor by `margin` m; tighter than a round plot for long buildings.
func footprint_clear_of_road(p: Vector3, yaw: float, bb: AABB, margin: float = 1.0) -> bool:
	var b := Basis(Vector3.UP, yaw)
	for i in 7:
		for j in 7:
			var q := p + b * Vector3(lerpf(bb.position.x, bb.end.x, i / 6.0), 0.0, lerpf(bb.position.z, bb.end.z, j / 6.0))
			for e in _paths():
				var path: TrackPath = e.path
				var c := path.closest(Vector3(q.x, 0.0, q.z))
				if c.distance < path.half_width_at(c.s) + e.ow + margin:
					return false
	return true


func _free_of_reserved(p: Vector3) -> bool:
	for z in _reserved:
		if Vector2(p.x - z[0].x, p.z - z[0].z).length() < z[1]:
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


## 0.11.0: per-prop chunk size (big buildings use larger chunks, fewer draw
## calls) and a minimum far distance for skyline props (towers stay visible
## on Low, they are only ~40 triangles each).
var chunk_size := {}
var skyline_min := {}


## 0.11.2: every placed transform of one prop (e.g. "lamp" for NightGlow).
## 0.13.0 contact shadows (AoMap): footprints of every instanced prop that is
## tall and wide enough, plus the landmarks, painted into one ground map.
var ao_blobs: Array = []
var ao_texture: ImageTexture
var ao_rect := Rect2()


func _collect_ao_blobs() -> void:
	for prop in _instances.keys():
		var mesh := PropKit.get_mesh(prop)
		if mesh == null:
			continue
		var aabb := mesh.get_aabb()
		if aabb.size.y < AoMap.MIN_H:
			continue
		for key in _instances[prop].keys():
			for xf in _instances[prop][key]:
				var b := AoMap.blob_for((xf as Transform3D) * aabb)
				if not b.is_empty():
					ao_blobs.append(b)


func _build_ao_map() -> void:
	if data == null or data.main == null:
		return
	if "landmarks" in self:
		for lm in landmarks.values():
			if not (lm is Node3D) or not is_instance_valid(lm):
				continue
			for mi in ([lm] + (lm as Node).find_children("*", "MeshInstance3D", true, false)):
				if mi is MeshInstance3D and (mi as MeshInstance3D).mesh:
					var b := AoMap.blob_for((mi as Node3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb())
					if not b.is_empty() and (b.r as Vector2).x < 140.0 and (b.r as Vector2).y < 140.0:
						ao_blobs.append(b)
	ao_rect = AoMap.rect_for(data.main.points)
	ao_texture = AoMap.build(ao_rect, ao_blobs)
	AoMap.apply(ao_rect, ao_texture)


func _exit_tree() -> void:
	if ao_texture != null:
		AoMap.clear() # menus and the next race start without the old map


## _instances is cleared after the MultiMeshes are built, so the props listed
## in KEEP_TRANSFORMS are copied into _kept first.
const KEEP_TRANSFORMS := ["lamp"]
const FULL_LOD_PROPS := ["ganjlik_mall", "mall_28", "port_baku", "park_bulvar"]
var _kept := {} # prop_id -> Array[Transform3D]


func instance_transforms(prop: String) -> Array:
	var out: Array = (_kept.get(prop, []) as Array).duplicate()
	for key in _instances.get(prop, {}).keys():
		out.append_array(_instances[prop][key])
	return out


func add_instance(prop: String, xform: Transform3D) -> void:
	if not _instances.has(prop):
		_instances[prop] = {}
	var cs: float = chunk_size.get(prop, CHUNK)
	var key := Vector2i(int(floor(xform.origin.x / cs)), int(floor(xform.origin.z / cs)))
	if not _instances[prop].has(key):
		_instances[prop][key] = []
	_instances[prop][key].append(xform)


## 0.11.0 cinematic fix: decor has no collision, so the camera's physics ray
## could not see signs, palms or beds and they slid in front of the kart. Every
## instanced prop taller than OCC_MIN_H (and not standing on the road) is kept
## as a world AABB in a coarse grid; segment_hit() tests a camera line.
const OCC_CELL := 24.0
const OCC_MIN_H := 1.2
var _occ := {} # Vector2i -> Array[AABB]
var occluder_count := 0


func add_occluder(box: AABB) -> void:
	var c0 := Vector2i(int(floor(box.position.x / OCC_CELL)), int(floor(box.position.z / OCC_CELL)))
	var c1 := Vector2i(int(floor(box.end.x / OCC_CELL)), int(floor(box.end.z / OCC_CELL)))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			var k := Vector2i(cx, cz)
			if not _occ.has(k):
				_occ[k] = []
			_occ[k].append(box)
	occluder_count += 1


## Fraction (0..1) along a->b of the first decor box hit, or -1 when clear.
func segment_hit(a: Vector3, b: Vector3) -> float:
	var len := a.distance_to(b)
	if len < 0.01:
		return -1.0
	var lo := Vector2(minf(a.x, b.x), minf(a.z, b.z))
	var hi := Vector2(maxf(a.x, b.x), maxf(a.z, b.z))
	var best := 2.0
	for cx in range(int(floor(lo.x / OCC_CELL)), int(floor(hi.x / OCC_CELL)) + 1):
		for cz in range(int(floor(lo.y / OCC_CELL)), int(floor(hi.y / OCC_CELL)) + 1):
			for box: AABB in _occ.get(Vector2i(cx, cz), []):
				var hit = box.intersects_segment(a, b)
				if hit != null:
					best = minf(best, a.distance_to(hit) / len)
	return best if best <= 1.0 else -1.0


func _register_occluders(mesh: Mesh, list: Array) -> void:
	if mesh == null or data == null:
		return
	var ab := mesh.get_aabb()
	if ab.size.y < OCC_MIN_H or maxf(ab.size.x, ab.size.z) < 0.25:
		return
	for x: Transform3D in list:
		var box: AABB = x * ab
		var c := box.get_center()
		# Overhead pieces spanning the road (gates, bunting) are not walls.
		var cl := data.main.closest(Vector3(c.x, 0.0, c.z))
		if cl.distance < data.main.half_width_at(cl.s) + 0.5:
			continue
		add_occluder(box.grow(0.15))


func _flush_instances() -> void:
	for prop in _instances.keys():
		var mesh := PropKit.get_mesh(prop)
		# 0.17.3: the malls keep their full model far away too (a few hundred
		# triangles; Ganjlik Mall's far model read as a blank grey box).
		var lo := mesh if prop in FULL_LOD_PROPS else PropKit.get_mesh(prop + PropKit.LO_SUFFIX)
		for key in _instances[prop].keys():
			var list: Array = _instances[prop][key]
			_register_occluders(mesh, list)
			# 0.10.2 LOD: full mesh near the camera, half-segment mesh without
			# shadows beyond LOD_DISTANCE (chunk centre), cut at the decor distance.
			for far in [false, true]:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = lo if far else mesh
				mm.instance_count = list.size()
				for i in list.size():
					mm.set_instance_transform(i, list[i])
				var mmi := MultiMeshInstance3D.new()
				mmi.name = "%s_%d_%d%s" % [prop, key.x, key.y, "_lo" if far else ""]
				mmi.set_meta("prop", prop)
				mmi.multimesh = mm
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				if far:
					mmi.visibility_range_begin = LOD_DISTANCE
					mmi.visibility_range_begin_margin = 10.0
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					_lod_nodes.append(mmi)
				else:
					mmi.set_meta("instance_xforms", list) # CPU copy for layout checks (tests)
					mmi.visibility_range_end = LOD_DISTANCE
					mmi.visibility_range_end_margin = 10.0
					if prop in NO_SHADOW_PROPS:
						mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					_chunk_nodes.append(mmi)
				add_child(mmi)
	_collect_ao_blobs()
	for kp in KEEP_TRANSFORMS:
		if _instances.has(kp):
			var keep: Array = _kept.get(kp, [])
			for key in _instances[kp].keys():
				keep.append_array(_instances[kp][key])
			_kept[kp] = keep
	_instances.clear()


func set_decor_distance(meters: float) -> void:
	# Near chunks stop at the LOD switch (or earlier on Low); far LOD chunks
	# carry on to the decor distance.
	lod_distance = lod_for(meters)
	for n in _chunk_nodes:
		if is_instance_valid(n):
			n.visibility_range_end = lod_distance
	for n in _lod_nodes:
		if is_instance_valid(n):
			n.visibility_range_begin = lod_distance
			n.visibility_range_end = maxf(meters, skyline_min.get(n.get_meta("prop", ""), 0.0))
	for c in _carpets:
		if is_instance_valid(c):
			c.visibility_range_end = meters * 0.6


func _face(pos: Vector3, forward: Vector3) -> Transform3D:
	# Local +Z faces `forward`.
	var f := Vector3(forward.x, 0, forward.z).normalized()
	var basis := Basis.looking_at(-f, Vector3.UP)
	return Transform3D(basis, pos)


## 0.17.0: a Blender landmark prop (PropKit glTF id) as its own node - the
## near model up to LANDMARK_NEAR m, the decimated far model beyond - and
## registered for --landmark-views. Its footprint must be reserved before
## the houses / towers are placed (see the decor's _begin).
const LANDMARK_NEAR := 260.0


func _landmark_prop(id: String, p: Vector3, yaw: float, node_name: String) -> MeshInstance3D:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var near := _landmark(PropKit.get_mesh(id), xf, node_name)
	near.visibility_range_end = LANDMARK_NEAR
	near.visibility_range_end_margin = 20.0
	near.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	var far := _landmark(PropKit.get_mesh(id + PropKit.LO_SUFFIX), xf, node_name + "Far")
	far.visibility_range_begin = LANDMARK_NEAR
	far.visibility_range_begin_margin = 20.0
	far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	landmarks[id] = near
	return near


## 0.17.3: the Flame Towers beside the road (downtown, Old City) - the near
## model up to 380 m like on the seafront, the light far model beyond.
func _flame_towers_node(p: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	root.name = "FlameTowers"
	root.transform = Transform3D(Basis(Vector3.UP, yaw), p)
	add_child(root)
	var near := MeshInstance3D.new()
	near.name = "Near"
	near.mesh = LandmarkKit.get_mesh("flame_towers")
	near.visibility_range_end = 380.0
	near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(near)
	var far := MeshInstance3D.new()
	far.name = "Far"
	far.mesh = LandmarkKit.get_mesh("flame_towers_far")
	far.visibility_range_begin = 380.0
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(far)
	landmarks["flame_towers"] = root
	return root


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
		if _free_of_reserved(p):
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
			var fb := Vector3(x - 5.5, -0.05, sea - 10.5)
			if clear_of_track(fb, 2.6, 0.3):
				add_instance("flower_bed" if k % 4 < 2 else "flower_bed_b", Transform3D(Basis.IDENTITY, fb))
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
					add_instance(["tree", "tree", "pine", "cypress"][rng.randi() % 4], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(tp.x, ground_y(tp), tp.z)))
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
				if tower_pos != Vector3.INF and Vector2(c.x - tower_pos.x, c.z - tower_pos.z).length() < 46.0:
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


## 0.15.3: the Blender carpet (rod, folds, fringe) when present. Its UVs are
## rebuilt from the cloth position (1.6 x 2.4 m, centred) so the carpet
## shader paints the pattern exactly as on the old flat quad.
static func _carpet_mesh() -> Mesh:
	if not LandmarkKit._has_gltf("carpet_hang"):
		var quad := QuadMesh.new()
		quad.size = Vector2(1.6, 2.4)
		return quad
	var src := PropKit.get_mesh("carpet_hang")
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs := PackedVector2Array()
	uvs.resize(verts.size())
	for i in verts.size():
		uvs[i] = Vector2(verts[i].x / 1.6 + 0.5, 0.5 - verts[i].y / 2.4)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _add_carpet(house_xf: Transform3D, idx: int) -> void:
	var variant := idx % 4
	var local := Vector3(rng.randf_range(-2.5, 2.5), 2.4, 4.08)
	if not _carpet_xforms.has(variant):
		_carpet_xforms[variant] = []
	_carpet_xforms[variant].append(house_xf * Transform3D(Basis.IDENTITY, local))


func _flush_carpets() -> void:
	var quad: Mesh = _carpet_mesh()
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
			add_instance(["tree", "pine", "pine", "cypress"][rng.randi() % 4], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q.x, ground_y(q) - 0.1, q.z)))


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
		# Street level of the Old City block (the real tower has no pedestal).
		var ty := builder.terrain_height(tp.x, tp.z) if builder else tp.y
		_landmark(PropKit.get_mesh("maiden_tower"), Transform3D(Basis(Vector3.UP, -PI * 0.5).scaled(Vector3.ONE * 1.3), Vector3(tp.x, ty - 0.05, tp.z)), "OldTower")
	_build_gate()
	_build_gantry()
	_place_baku_landmarks()
	# Observation wheel on the promenade near the east hairpin.
	# (west of the Flag Square sight line along the Boulevard straight)
	# The ring faces the road (XY plane) so it never hangs over the track.
	var wp := WHEEL_SITE + Vector3(0, -0.05, 0)
	var frame := _landmark(PropKit.get_mesh("wheel_frame"), Transform3D(Basis.IDENTITY, wp), "WheelFrame")
	wheel_ring = Node3D.new()
	wheel_ring.name = "WheelRing"
	# Rotated per frame in _process, so it must not be physics-interpolated.
	wheel_ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	wheel_ring.transform = Transform3D(Basis.IDENTITY, wp + Vector3(0, 34.0, 0))
	add_child(wheel_ring)
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = PropKit.get_mesh("wheel_ring")
	wheel_ring.add_child(ring_mi)
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## The requested Baku landmarks, spread around the lap so each owns a view:
## Flag Square dead ahead at the end of the Boulevard straight; the Crescent
## out in the bay straight ahead on the return leg down to the sea; Heydar Aliyev Center beside
## the modern connector; the Flame Towers on a hill straight ahead on the
## westbound connector, rising above the Old City walls; the Maiden Tower
## inside the Old City (placed above). Far LODs swap in beyond 380 m.
func _place_baku_landmarks() -> void:
	for id in LANDMARK_SITES.keys():
		var site: Array = LANDMARK_SITES[id]
		var p := Vector3(site[0], 0.0, site[1])
		var y := ground_y(p)
		if id == "crescent":
			y = maxf(ground_y(p), data.sea_level + 0.4) # on the shore, not in the sea
		elif id == "flag_square":
			# 0.15.3: the round plaza sits on the highest ground under it (its
			# skirt reaches down), so the slope never buries half of it.
			for k in 13:
				var ang := TAU * k / 12.0
				var q := p + Vector3(cos(ang), 0, sin(ang)) * (30.0 if k < 12 else 0.0)
				y = maxf(y, ground_y(q))
				if builder:
					y = maxf(y, builder.terrain_height(q.x, q.z) + 0.05)
		elif id == "flame_towers":
			y = ground_y(p) + 5.0
			var hill := MeshInstance3D.new()
			hill.name = "FlameHill"
			hill.mesh = ShapeKit.superellipsoid(Vector3(150, 26, 130), 0.9, 0.9, Vector2.ONE, Vector2.ONE, 8, 14)
			hill.material_override = ShapeKit.mat(Color("6fbf4a"), 0.95)
			hill.position = Vector3(p.x, y - 9.0, p.z)
			hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(hill)
		var xf := Transform3D(Basis(Vector3.UP, float(site[3])), Vector3(p.x, y, p.z))
		if id == "carpet_museum":
			xf.basis = xf.basis.scaled(Vector3.ONE * 1.5)
		var root := Node3D.new()
		root.name = "Landmark_" + id
		root.transform = xf
		add_child(root)
		var near := MeshInstance3D.new()
		near.name = "Near"
		near.mesh = LandmarkKit.get_mesh(id)
		root.add_child(near)
		var far_id: String = id + "_far"
		if id != "flag_square" and id != "port_baku":
			near.visibility_range_end = 380.0
			var far := MeshInstance3D.new()
			far.name = "Far"
			far.mesh = LandmarkKit.get_mesh(far_id)
			far.visibility_range_begin = 380.0
			far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(far)
		if id in ["crescent", "flame_towers"]:
			near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if id == "crescent":
			# Reclaimed shore under the Crescent: a paved plaza joined to the
			# promenade, so it stands on land like the real one.
			var shore := MeshInstance3D.new()
			shore.name = "CrescentShore"
			shore.mesh = ShapeKit.cylinder(40.0, 3.0, 40)
			shore.material_override = ShapeKit.mat(Color("d9d2c4"), 0.85)
			shore.position = Vector3(0, -1.55, 8.0)
			root.add_child(shore)
		if id == "flag_square":
			# Wind blows towards the sea (+z): seen from the Boulevard the
			# hoist is on the left and the flag reads the right way round.
			LandmarkKit.attach_flag(root)
		landmarks[id] = root
	var tp := _tower_position()
	if tp != Vector3.INF:
		landmarks["maiden_tower"] = get_node_or_null("OldTower")


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
	# Qoşa Qala: the Old City's double gate, with crenellated walls running
	# off both sides (cut short wherever they would reach another road).
	var basis := Basis(r, Vector3.UP, r.cross(Vector3.UP)).orthonormalized()
	var gate := _landmark(LandmarkKit.qosa_qala(half * 2.0), Transform3D(basis, p + Vector3.DOWN * 0.05), "CityGate")
	gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_sign(gate, "İÇƏRİŞƏHƏR", Vector3(0, 11.2, 0), 1.25, Color("fff3d6"), Color("7a4a2a"))
	landmarks["icherisheher_gate"] = gate
	for side: float in [-1.0, 1.0]:
		var start := half + 3.6 + 10.4
		var length := 0.0
		while length < 80.0:
			var q := p + r * side * (start + length + 4.0)
			if not clear_of_track(q, 3.0, 1.0):
				break
			length += 4.0
		if length < 8.0:
			continue
		var wall_dir := r * side
		var wb := Basis(wall_dir, Vector3.UP, wall_dir.cross(Vector3.UP)).orthonormalized()
		var origin := p + r * side * start
		_landmark(LandmarkKit.city_wall(length), Transform3D(wb, Vector3(origin.x, ground_y(origin) - 0.05, origin.z)), "CityWall")
		var end := origin + wall_dir * length
		if LandmarkKit._has_gltf("wall_end"):
			_landmark(PropKit.get_mesh("wall_end"), Transform3D(Basis.IDENTITY, Vector3(end.x, ground_y(end) - 0.05, end.z)), "WallTower")
			continue
		var tower := PropKit.Accum.new()
		tower.add(ShapeKit.cylinder(3.4, 11.0, 16), PropKit.T(Vector3(0, 5.5, 0)), PropKit.m("limestone_warm"))
		for k in 10:
			var ang := TAU * k / 10.0
			tower.add(PropKit.box(Vector3(0.9, 1.2, 0.7)), PropKit.T(Vector3(cos(ang) * 3.3, 11.6, sin(ang) * 3.3), Vector3(0, -ang, 0)), PropKit.m("limestone_warm"))
		_landmark(tower.commit(), Transform3D(Basis.IDENTITY, Vector3(end.x, ground_y(end) - 0.05, end.z)), "WallTower")


func _build_gantry() -> void:
	var s := data.finish_s
	var p := data.main.position_at(s)
	var r := data.main.right_at(s)
	var half := data.main.half_width_at(s) + 1.6
	var a := PropKit.Accum.new()
	var h := 7.6
	var blender := LandmarkKit._has_gltf("gantry_seg")
	if blender:
		# 0.15.3 Blender gantry: two legs, 2 m checkered beam pieces across
		# the road, the countdown light box in the middle.
		var span := half * 2.0 + 1.2
		var n := maxi(int(round(span / 2.0)), 1)
		var sx := span / (n * 2.0)
		for k in n:
			a.add_committed(PropKit.get_mesh("gantry_seg"), Transform3D(Basis.from_scale(Vector3(sx, 1, 1)), Vector3(-span * 0.5 + k * 2.0 * sx, 0, 0)))
		for side: float in [-1.0, 1.0]:
			a.add_committed(PropKit.get_mesh("gantry_pillar"), Transform3D(Basis.IDENTITY, Vector3(side * half, 0, 0)))
		a.add_committed(PropKit.get_mesh("gantry_lights"), Transform3D.IDENTITY)
	for side: float in ([] if blender else [-1.0, 1.0]):
		a.add(PropKit.rbox(Vector3(0.9, h, 0.9), 0.2), Transform3D(Basis.IDENTITY, Vector3(side * half, h * 0.5, 0)), PropKit.m("navy"))
	if not blender:
		a.add(PropKit.rbox(Vector3(half * 2.0 + 1.2, 1.5, 1.0), 0.2), Transform3D(Basis.IDENTITY, Vector3(0, h + 0.3, 0)), PropKit.m("navy"))
	# Checkered band
	for i in (0 if blender else 24):
		var x := -half + (i + 0.5) * (half * 2.0 / 24.0)
		a.add(PropKit.box(Vector3(half * 2.0 / 24.0, 0.5, 0.05)), Transform3D(Basis.IDENTITY, Vector3(x, h + 0.65, 0.52)), PropKit.m("white" if i % 2 == 0 else "navy"))
		a.add(PropKit.box(Vector3(half * 2.0 / 24.0, 0.5, 0.05)), Transform3D(Basis.IDENTITY, Vector3(x, h - 0.05, 0.52)), PropKit.m("navy" if i % 2 == 0 else "white"))
	var basis := Basis(r, Vector3.UP, r.cross(Vector3.UP)).orthonormalized()
	var gantry := _landmark(a.commit(), Transform3D(basis, p + Vector3.DOWN * 0.05), "StartGantry")
	_sign(gantry, "YASKA RACING", Vector3(0, h + 0.3, 0), 0.55, Color("ffc93c"), Color("1b2a4a"))
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
		l.position = Vector3(-1.6 + i * 1.6, h + 1.85, 0.0) if blender else Vector3(-1.6 + i * 1.6, h + 0.3, -0.6)
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


## Two-sided readable sign text (Label3D, Azerbaijani-capable font).
func _sign(parent: Node3D, text: String, pos: Vector3, depth: float, col: Color, outline: Color) -> void:
	for side: float in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = text
		l.font = UITheme.heading_font()
		l.font_size = 128
		l.pixel_size = 0.008
		l.outline_size = 22
		l.modulate = col
		l.outline_modulate = outline
		l.position = pos + Vector3(0, 0, side * depth)
		l.rotation.y = 0.0 if side > 0.0 else PI
		l.double_sided = false
		l.shaded = false
		parent.add_child(l)


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
			if LandmarkKit._has_gltf("bunting_pole"):
				a.add_committed(PropKit.get_mesh("bunting_pole"), Transform3D(Basis.IDENTITY, r * side * half))
			else:
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
	# 0.14.4 Baku skyline north-east (owner's photos; the Flame Towers are a
	# placed landmark): SOCAR-like twisted tower, crowned spire tower, stacked
	# cubes, glass slabs, sandstone blocks with white domes, residential towers.
	var towers := [["socar_tower", Vector3(430, 0, -420)], ["crown_tower", Vector3(470, 0, -360)],
		["stack_tower", Vector3(520, 0, -440)], ["glass_slab", Vector3(380, 0, -480)], ["resid_tower", Vector3(560, 0, -330)],
		["stalin_block", Vector3(330, 0, -380)], ["glass_slab", Vector3(600, 0, -400)], ["resid_tower", Vector3(300, 0, -450)],
		["resid_tower", Vector3(490, 0, -500)]]
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
		var rot := Basis(Vector3.UP, rng.randf_range(-0.2, 0.2))
		if LandmarkKit._has_gltf("block9_a"):
			# 0.15.3 (owner): ordinary city = new 9-storey Baku blocks, unscaled
			# so the windows keep their proportions (30 x 16 m footprint).
			if not clear_of_track(q, 26.0, 30.0):
				continue
			var kind9: String = ["block9_a", "block9_b", "block9_c"][i % 3]
			var yaw9 := Basis(Vector3.UP, rng.randf_range(-0.25, 0.25) + (PI if i % 2 == 0 else 0.0))
			city.add_committed(PropKit.get_mesh(kind9 + PropKit.LO_SUFFIX), Transform3D(yaw9, q + Vector3(0, -1.0, 0)))
		elif PropKit.gltf_enabled and PropKit.GLTF_PROPS.has("stalin_block"):
			# 0.14.4: baked sandstone blocks / residential towers (far LOD, one mesh).
			var kind := "stalin_block" if i % 3 != 0 else "resid_tower"
			var base: Vector3 = Vector3(40, 26, 22) if kind == "stalin_block" else Vector3(24, 62, 20)
			var sc := Vector3(bs.x / base.x, bh / base.y, bs.z / base.z)
			if kind == "resid_tower":
				sc = Vector3(sc.x, sc.y * 1.6, sc.z)
			city.add_committed(PropKit.get_mesh(kind + PropKit.LO_SUFFIX), Transform3D(rot.scaled(sc), q + Vector3(0, -1.0, 0)))
		else:
			city.add(PropKit.box(bs), Transform3D(rot, q + Vector3(0, bh * 0.5 - 1.0, 0)), plaster[i % plaster.size()])
	var city_mi := _landmark(city.commit(), Transform3D.IDENTITY, "CityBlocks")
	city_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Soft low-poly clouds (one merged mesh, no shadows).
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(1, 1, 1)
	cloud_mat.roughness = 1.0
	cloud_mat.emission_enabled = true
	cloud_mat.emission = Color(0.85, 0.88, 0.95)
	cloud_mat.emission_energy_multiplier = 0.35
	cloud_mat.disable_receive_shadows = true
	var clouds := PropKit.Accum.new()
	for i in 14:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(450.0, 800.0)
		var cpos := center + Vector3(cos(ang) * dist, rng.randf_range(110.0, 180.0), sin(ang) * dist)
		for k in 5:
			var sz := Vector3(rng.randf_range(40, 80), rng.randf_range(14, 24), rng.randf_range(26, 48))
			var off := Vector3(rng.randf_range(-35, 35), rng.randf_range(-4, 6), rng.randf_range(-15, 15))
			# 0.14.2: 450-800 m away, so 5 x 8 / 3 x 6 segments look the same (-40 %).
			clouds.add(ShapeKit.superellipsoid(sz, 1.0, 1.0, Vector2.ONE, Vector2.ONE, 5, 8), Transform3D(Basis.IDENTITY, cpos + off), cloud_mat)
			# flat, slightly grey base like a cumulus
			clouds.add(ShapeKit.superellipsoid(Vector3(sz.x * 1.2, sz.y * 0.35, sz.z * 1.1), 1.0, 1.0, Vector2.ONE, Vector2.ONE, 3, 6), Transform3D(Basis.IDENTITY, cpos + off - Vector3(0, sz.y * 0.3, 0)), cloud_mat)
	var cloud_mi := _landmark(clouds.commit(), Transform3D.IDENTITY, "Clouds")
	cloud_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 0.9.6 ambiance: TV Tower on the northern hills, Crystal Hall on the bay,
## oil platforms and ships on the Caspian horizon, flag poles along the
## promenade and Azerbaijani street signs beside the road.
## 0.17.3: the TV tower stands beside the north-west corner (was on a far
## hill, 330 m off the road), Crystal Hall right at the seawall.
const EXTRA_SITES := {
	# id: [x, z, yaw, footprint radius]
	"tv_tower": [-314.0, -230.0, 0.0, 12.0],
	"crystal_hall": [-320.0, 69.0, 0.0, 44.0],
}
const STREET_NAMES := ["Neftçilər prospekti", "Dənizkənarı bulvar", "İçərişəhər", "Azadlıq meydanı", "Üzeyir Hacıbəyov küç."]


func _place_baku_extras() -> void:
	for id in EXTRA_SITES.keys():
		var site: Array = EXTRA_SITES[id]
		var p := Vector3(site[0], 0.0, site[1])
		var y := ground_y(p) - 0.5
		if id == "crystal_hall":
			y = data.sea_level - 0.6
		var root := Node3D.new()
		root.name = "Landmark_" + id
		root.transform = Transform3D(Basis(Vector3.UP, float(site[2])), Vector3(p.x, y, p.z))
		add_child(root)
		var mi := MeshInstance3D.new()
		mi.name = "Near"
		mi.mesh = BakuExtras.get_mesh(id)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		landmarks[id] = root
	# Horizon: oil platforms far out, a few freighters nearer.
	var sea := data.sea_z
	var hz := PropKit.Accum.new()
	for i in 5:
		var op := Vector3(-700.0 + i * 340.0 + rng.randf_range(-60, 60), data.sea_level, sea + rng.randf_range(430.0, 620.0))
		hz.add_committed(BakuExtras.get_mesh("oil_platform"), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), op))
	for i in 3:
		var sp := Vector3(-350.0 + i * 360.0 + rng.randf_range(-50, 50), data.sea_level, sea + rng.randf_range(220.0, 380.0))
		hz.add_committed(BakuExtras.get_mesh("ship"), Transform3D(Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.3, 0.3)), sp))
	var hz_mi := _landmark(hz.commit(), Transform3D.IDENTITY, "CaspianHorizon")
	hz_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hz_mark := Node3D.new()
	hz_mark.name = "HorizonMark"
	hz_mark.position = Vector3(0.0, data.sea_level, sea + 300.0)
	add_child(hz_mark)
	landmarks["caspian_horizon"] = hz_mark
	# Azerbaijani flags along the promenade.
	var flag_mesh := LandmarkKit.flag_mesh(2.2, 1.1)
	var x := -300.0
	while x < 290.0:
		var fp := Vector3(x, -0.05, sea - 5.0)
		if clear_of_track(fp, 0.6, 0.6):
			var pole := _landmark(BakuExtras.get_mesh("flag_pole"), Transform3D(Basis.IDENTITY, fp), "FlagPole")
			pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pole.add_to_group("flag_pole")
			var f := MeshInstance3D.new()
			f.name = "Flag"
			f.mesh = flag_mesh
			f.position = Vector3(0, 7.9, 0)
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			f.extra_cull_margin = 2.0
			pole.add_child(f)
		x += 48.0
	# Street signs (blue name plates) beside the road.
	var L := data.main.length
	for i in STREET_NAMES.size():
		var half: float = 0.45 + String(STREET_NAMES[i]).length() * 0.08
		var placed := false
		for k in 16:
			if placed:
				break
			var s := fposmod(L * (0.08 + 0.19 * i) + k * 9.0, L)
			var p := data.main.position_at(s)
			var r := data.main.right_at(s)
			var off: float = data.main.half_width_at(s) + data.offroad_width + 2.0 + half
			for side: float in [1.0, -1.0]:
				var sp: Vector3 = p + r * side * off
				if clear_of_track(sp, half + 0.4, 0.6):
					_street_sign(STREET_NAMES[i], Vector3(sp.x, p.y - 0.05, sp.z), data.main.tangent_at(s))
					placed = true
					break


func _street_sign(text: String, pos: Vector3, along: Vector3) -> void:
	var root := Node3D.new()
	root.name = "StreetSign"
	root.add_to_group("street_sign")
	add_child(root)
	# Plate faces the oncoming karts.
	root.global_transform = _face(pos, -along)
	var w := 0.5 + text.length() * 0.16
	var pole := MeshInstance3D.new()
	pole.mesh = ShapeKit.cylinder(0.06, 3.4, 6)
	pole.material_override = PropKit.m("metal_grey")
	pole.position = Vector3(-w * 0.5 + 0.2, 1.7, 0)
	root.add_child(pole)
	var plate := MeshInstance3D.new()
	plate.mesh = PropKit.box(Vector3(w, 0.62, 0.06))
	plate.material_override = ShapeKit.mat(Color("1d5fae"), 0.5)
	plate.position = Vector3(0, 3.1, 0)
	root.add_child(plate)
	for side: float in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = text
		l.font = UITheme.heading_font()
		l.font_size = 64
		l.pixel_size = 0.0045
		l.outline_size = 0
		l.modulate = Color.WHITE
		l.position = Vector3(0, 3.1, side * 0.04)
		l.rotation.y = 0.0 if side > 0.0 else PI
		l.double_sided = false
		l.shaded = false
		root.add_child(l)


func _process(delta: float) -> void:
	if wheel_ring:
		wheel_ring.rotate_object_local(Vector3.BACK, delta * 0.05)
