class_name DowntownDecor
extends TrackDecor
## 0.11.0 scenery for "Göydələnlər şəhəri" (downtown_towers.json): Tower
## Avenue lined with 16-storey glass skyscrapers, four shopping malls with
## parking, a mall bridge the course runs under, sidewalks with lamps,
## planters and billboards, and the sea promenade to the south. Same
## MultiMesh + far-LOD pipeline as the seafront (TrackDecor), and the same
## 13 build steps so the loading screen and RaceManager need no changes.

const MALLS := [
	# [x, z, yaw (front = +Z rotated), prop, name, parking [dx, dz, yaw]]
	# 0.15.3 (owner: mini Baku): the real malls, modelled from photos
	# (tools/blender/malls_props.py); Park Bulvar is the one by the sea.
	[-6.0, -116.0, PI, "mall_28", "28 MALL", null],
	[118.0, -140.0, -PI * 0.5, "port_baku", "PORT BAKU", [0.0, -46.0, 0.0]],
	[45.0, 48.0, PI, "park_bulvar", "PARK BULVAR", [62.0, 0.0, PI * 0.5]],
	[-172.0, -152.0, 0.0, "ganjlik_mall", "GƏNCLİK MALL", [-2.0, -46.0, 0.0]],
]
## Name sign position on each mall (local), and its pixel size.
const MALL_SIGN := {"mall_28": [Vector3(4.0, 15.9, 16.5), 0.02], "port_baku": [Vector3(0.0, 13.3, 33.7), 0.022],
	"park_bulvar": [Vector3(2.0, 9.0, 15.4), 0.02], "ganjlik_mall": [Vector3(0.0, 21.6, 17.8), 0.022],
	"mall_a": [Vector3(0, 15.35, 19.0), 0.022], "mall_b": [Vector3(0, 15.35, 19.0), 0.022]}
## 0.17.0 (owner: mini Baku) the historic centre along the sea side of
## Tower Avenue, west to east as in Baku: Philharmonic, City Hall, Ismailiyya;
## Fountain Square (paving + both fountains) north of them in the infield.
## [prop id, x, z, yaw, reserved radius, node name]
const CENTRE := [
	["philharmonic", -200.0, 44.0, PI, 28.5, "Philharmonic"],
	["city_hall", -130.0, 44.0, PI, 26.0, "CityHall"],
	["ismailiyya", -62.0, 42.0, PI, 24.0, "Ismailiyya"],
]
const FOUNTAIN_SQUARE := Vector3(-30.0, 0.0, -53.0)
## Nizami street: the pedestrian street running west from Fountain Square,
## lined both sides with 19th-century sandstone buildings (the Blender
## Neftçilər-style blocks: rustication, arched shop fronts, iron balconies)
## instead of glass towers; also keeps the view onto the square open.
const NIZAMI_WEST := -205.0 ## x where the street ends
const NIZAMI_W := 14.0 ## paved width
const NIZAMI_BLOCKS := {"modern_a": 16.0, "modern_b": 12.0, "modern_c": 20.0} ## width; depth 12
const FLAME_SITE := Vector3(-560.0, 0.0, 10.0) ## west, near the bay (sea = +z)
const MALL_R := 38.0
const TOWER_R := {"sky_a": 16.0, "sky_b": 17.0, "sky_c": 13.5, "sky_d": 19.0}
const BRIDGE_CLEAR := 8.0 ## m of headroom under the mall bridge
const SIGN_COL := Color("ffd23f")
const SIGN_OUT := Color("1b2a4a")

var towers_placed := 0
var nizami_buildings := 0
var malls_placed := 0
var bridge: Node3D


func build_steps(td: TrackData, env: RaceEnvironment) -> Array[Callable]:
	return [
		func(): _begin(td),
		_place_wall_props,
		func(): _place_centre(); _place_malls(),
		_place_mall_bridge,
		_place_avenue_towers,
		_place_city_towers,
		_place_sidewalks,
		_place_corner_signs,
		_place_city_landmarks,
		_place_city_promenade,
		_place_city_skyline,
		_flush_instances,
		func(): _finish(env),
	]


func _begin(td: TrackData) -> void:
	data = td
	builder = get_parent().get_node_or_null("Track")
	rng.seed = 20261030
	for id in CityKit.TOWERS:
		chunk_size[id] = 160.0
		skyline_min[id] = 560.0
	for id in ["mall_a", "mall_b", "mall_28", "port_baku", "park_bulvar", "ganjlik_mall"]:
		chunk_size[id] = 140.0
		skyline_min[id] = 420.0


## y of flat city ground at p, or INF where the terrain rises (flyover
## embankment, outer hills), so buildings never float or stand in a slope.
func city_y(p: Vector3, r: float) -> float:
	var c: Dictionary = data.main.closest(Vector3(p.x, 0.0, p.z))
	if c.distance > 160.0 - r:
		return INF
	if c.distance < r + 70.0:
		# Raised road nearby (flyover): the ground is lifted around it.
		var s := data.main.length
		var i := 0.0
		while i < s:
			var q := data.main.position_at(i)
			if q.y > 0.6 and Vector2(q.x - p.x, q.z - p.z).length() < r + 62.0:
				return INF
			i += 8.0
	if p.z > data.sea_z - 20.0 - r:
		return INF
	return -0.12


func _place_building(prop: String, p: Vector3, yaw: float, r: float, margin: float) -> bool:
	if not clear_of_track(p, r, margin):
		return false
	var y := city_y(p, r)
	if y == INF:
		return false
	add_instance(prop, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.z)))
	_reserved.append([Vector3(p.x, 0.0, p.z), r])
	return true


# --- Mall bridge ---------------------------------------------------------------

## The course runs under a glass bridge between two mall blocks: 8 m clear
## headroom, a 34 m wide opening and "MALL" signs facing both directions.
func _place_mall_bridge() -> void:
	var at: Array = data.raw.get("mall_bridge", {}).get("at", [])
	if at.size() < 2:
		return
	var c := data.main.closest(Vector3(at[0], 0.0, at[1]))
	var s: float = c.s
	var p := data.main.position_at(s)
	var t := data.main.tangent_at(s)
	var r := data.main.right_at(s)
	var half := data.main.half_width_at(s) + data.offroad_width + 4.0 # opening half-width
	var blk := 16.0 # side block width
	var depth := 18.0 # along the road
	var h := 19.0
	var a := PropKit.Accum.new()
	var glass := CityKit.glass(4, 3.8, h)
	for side: float in [-1.0, 1.0]:
		var cx := side * (half + blk * 0.5)
		a.add(PropKit.box(Vector3(blk, h, depth)), PropKit.T(Vector3(cx, h * 0.5, 0)), glass)
		a.add(PropKit.box(Vector3(blk + 0.6, 1.2, depth + 0.6)), PropKit.T(Vector3(cx, h + 0.6, 0)), PropKit.m("plaster_white"))
		a.add(PropKit.box(Vector3(0.8, h, depth + 0.4)), PropKit.T(Vector3(side * (half + 0.4), h * 0.5, 0)), PropKit.m("red"))
	# Deck (glass walkway with a white frame) over the road.
	var deck_h := h - BRIDGE_CLEAR
	a.add(PropKit.box(Vector3(half * 2.0, deck_h - 2.0, depth - 4.0)), PropKit.T(Vector3(0, BRIDGE_CLEAR + 1.0 + (deck_h - 2.0) * 0.5, 0)), glass)
	a.add(PropKit.box(Vector3(half * 2.0 + 0.2, 1.0, depth)), PropKit.T(Vector3(0, BRIDGE_CLEAR + 0.5, 0)), PropKit.m("plaster_white"))
	a.add(PropKit.box(Vector3(half * 2.0 + 0.2, 1.0, depth)), PropKit.T(Vector3(0, h - 0.5, 0)), PropKit.m("plaster_white"))
	# Sign bands over the road on both faces.
	for f: float in [-1.0, 1.0]:
		a.add(PropKit.box(Vector3(half * 1.5, 3.2, 0.6)), PropKit.T(Vector3(0, BRIDGE_CLEAR + 4.2, f * (depth * 0.5 - 1.6))), PropKit.m("red"))
	var mesh := a.commit()
	var basis := Basis(r, Vector3.UP, r.cross(Vector3.UP)).orthonormalized()
	bridge = _landmark(mesh, Transform3D(basis, Vector3(p.x, -0.12, p.z)), "MallBridge")
	# Ceiling light strips under the deck (glow at night and in the tunnel shade).
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("fff2c8")
	lm.emission_enabled = true
	lm.emission = Color("fff2c8")
	lm.emission_energy_multiplier = 2.2
	for i in 4:
		var strip := MeshInstance3D.new()
		strip.mesh = PropKit.box(Vector3(half * 1.8, 0.12, 0.5))
		strip.material_override = lm
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		strip.position = Vector3(0, BRIDGE_CLEAR - 0.06, -6.0 + i * 4.0)
		bridge.add_child(strip)
	# "MALL" letters on both faces (Label3D faces its local +Z).
	for f: float in [-1.0, 1.0]:
		var l := _big_label("28 MALL", 0.024)
		l.position = Vector3(0, BRIDGE_CLEAR + 4.2, f * (depth * 0.5 - 1.2))
		l.rotation.y = 0.0 if f > 0.0 else PI
		bridge.add_child(l)
	landmarks["mall_bridge"] = bridge
	# Keep scenery off the bridge blocks, and let the cinematic camera know.
	for side: float in [-1.0, 1.0]:
		var cp := p + r * side * (half + blk * 0.5)
		_reserved.append([Vector3(cp.x, 0.0, cp.z), blk * 0.5 + depth * 0.5])
		add_occluder(AABB(cp - Vector3(blk * 0.6, 0.2, blk * 0.6), Vector3(blk * 1.2, h, blk * 1.2)))
	add_occluder(AABB(p + Vector3(-half, BRIDGE_CLEAR, -half), Vector3(half * 2.0, deck_h, half * 2.0)))
	var _unused := t


func _big_label(text: String, px: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UITheme.heading_font()
	l.font_size = 128
	l.pixel_size = px
	l.outline_size = 24
	l.modulate = SIGN_COL
	l.outline_modulate = SIGN_OUT
	l.double_sided = false
	l.shaded = false
	return l


# --- Malls ---------------------------------------------------------------------

func _place_centre() -> void:
	for c: Array in CENTRE:
		var p := Vector3(float(c[1]), 0.0, float(c[2]))
		if not clear_of_track(p, float(c[4]), 0.5):
			push_warning("DowntownDecor: %s overlaps the course" % c[5])
			continue
		_landmark_prop(c[0], Vector3(p.x, -0.12, p.z), float(c[3]), c[5])
		_reserved.append([p, float(c[4])])
	var fs := FOUNTAIN_SQUARE
	if clear_of_track(fs, 34.0, 0.5):
		_landmark_prop("fountain_plaza", Vector3(fs.x, -0.12, fs.z), 0.0, "FountainSquare")
		_landmark_prop("fountain_tiered", Vector3(fs.x - 12.0, -0.02, fs.z), 0.0, "FountainTiered")
		_landmark_prop("fountain_spheres", Vector3(fs.x + 13.0, -0.02, fs.z + 2.0), 0.0, "FountainSpheres")
		_reserved.append([fs, 34.0])
		# Benches and lamps round the square, a few plane trees.
		for k in 10:
			var a := TAU * k / 10.0
			var q := fs + Vector3(cos(a) * 26.0, -0.1, sin(a) * 18.0)
			add_instance("lamp" if k % 2 == 0 else "bench", _face(q, fs - q))
		for k in 6:
			var a := TAU * (k + 0.5) / 6.0
			add_instance("tree", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), fs + Vector3(cos(a) * 31.0, -0.1, sin(a) * 23.0)))
	else:
		push_warning("DowntownDecor: Fountain Square overlaps the course")
	_place_nizami()


func _place_nizami() -> void:
	var z := FOUNTAIN_SQUARE.z
	var x_east := FOUNTAIN_SQUARE.x - 28.0 # the plaza's west edge
	var length := x_east - NIZAMI_WEST
	# Paving (cobbles, warm) following the gentle slope up to the flyover;
	# visual only, no collision.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := int(ceil(length / 4.0))
	for i in cols:
		for jz in 2:
			var x0 := x_east - length * i / cols
			var x1 := x_east - length * (i + 1) / cols
			var z0 := z - NIZAMI_W * 0.5 + NIZAMI_W * jz * 0.5
			var z1 := z0 + NIZAMI_W * 0.5
			var q := [Vector3(x0, _street_y(x0, z0), z0), Vector3(x1, _street_y(x1, z0), z0),
				Vector3(x1, _street_y(x1, z1), z1), Vector3(x0, _street_y(x0, z1), z1)]
			for t in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = q[t]
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v.x, v.z) / 3.0)
				st.add_vertex(v)
	var paving := MeshInstance3D.new()
	paving.name = "NizamiStreet"
	paving.mesh = st.commit()
	paving.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	mat.albedo_color = Color("e8d2b0")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	TextureLibrary.bind(mat, "albedo_texture", "cobbles")
	paving.material_override = mat
	add_child(paving)
	var mark := Node3D.new()
	mark.name = "NizamiStreetMark"
	mark.position = Vector3(x_east - length * 0.5, 4.0, z)
	add_child(mark)
	landmarks["nizami_street"] = mark
	# Sandstone buildings on both sides of the street.
	var ids: Array = NIZAMI_BLOCKS.keys()
	var placed := 0
	for side: float in [-1.0, 1.0]: # -1 north (-z), +1 south
		var x := x_east - 2.0
		var k := 0 if side < 0.0 else 1
		while true:
			var id: String = ids[k % ids.size()]
			var w: float = NIZAMI_BLOCKS[id]
			if x - w < NIZAMI_WEST:
				break
			var p := Vector3(x - w * 0.5, 0.0, z + side * (NIZAMI_W * 0.5 + 6.5))
			if clear_of_track(p, 9.0, 1.0):
				# On the slope: stand on the lowest corner (the uphill side sinks in).
				var gy := INF
				for c in [Vector2(-w * 0.5, -6.0), Vector2(w * 0.5, -6.0), Vector2(-w * 0.5, 6.0), Vector2(w * 0.5, 6.0)]:
					gy = minf(gy, _street_y(p.x + c.x, p.z + c.y))
				# Fronts face the race road nearest to each row (the players never
				# drive the street itself): south row to the avenue, north row to
				# the flyover.
				add_instance(id, Transform3D(Basis(Vector3.UP, PI if side < 0.0 else 0.0), Vector3(p.x, gy - 0.15, p.z)))
				placed += 1
			x -= w + 1.5
			k += 1
	nizami_buildings = placed
	# Lamps and benches down the street, a plane tree now and then.
	var lx := x_east - 6.0
	var j := 0
	while lx > NIZAMI_WEST + 4.0:
		for side: float in [-1.0, 1.0]:
			var q := Vector3(lx, 0.0, z + side * (NIZAMI_W * 0.5 - 1.0))
			q.y = _street_y(q.x, q.z) - 0.05
			if j % 3 == 2:
				add_instance("tree", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q))
			else:
				add_instance("lamp" if j % 3 == 0 else "bench", _face(q, Vector3(0, 0, -side)))
		lx -= 12.0
		j += 1
	# Keep towers off the street and both rows.
	var rx := x_east
	while rx > NIZAMI_WEST:
		_reserved.append([Vector3(rx, 0.0, z), NIZAMI_W * 0.5 + 13.0])
		rx -= 10.0


## Ground height on Nizami street (the city ground is -0.12; the terrain
## rises gently towards the flyover).
func _street_y(x: float, z: float) -> float:
	var t := builder.terrain_height(x, z) if builder else 0.0
	return maxf(-0.06, t + 0.04)


func _place_malls() -> void:
	var i := 0
	for m: Array in MALLS:
		var p := Vector3(m[0], 0.0, m[1])
		var yaw: float = m[2]
		if not clear_of_track(p, 30.0, 1.0):
			push_warning("DowntownDecor: mall %s overlaps the course" % m[4])
			continue
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, -0.12, p.z))
		add_instance(m[3], xf)
		_reserved.append([p, MALL_R])
		malls_placed += 1
		# Sign letters on the coloured band (the band is at local y 15.4, z 18.9).
		var holder := Node3D.new()
		holder.name = "MallSign%d" % i
		holder.transform = xf
		add_child(holder)
		var sign: Array = MALL_SIGN[m[3]]
		var l := _big_label(m[4], float(sign[1]))
		l.position = sign[0]
		holder.add_child(l)
		if m[3] == "mall_28":
			# The tall glowing "28" panel on the corner tower.
			var big := _big_label("28", 0.06)
			big.position = Vector3(-26.0, 13.0, 18.45)
			holder.add_child(big)
		if i == 2:
			landmarks["sea_mall"] = holder
		# Parking lot with parked cars.
		if m[5] != null:
			var pk: Array = m[5]
			var lp := xf * Vector3(pk[0], 0.0, pk[1])
			if clear_of_track(lp, 22.0, 0.5):
				var lxf := Transform3D(Basis(Vector3.UP, yaw + float(pk[2])), Vector3(lp.x, -0.1, lp.z))
				add_instance("parking", lxf)
				_reserved.append([Vector3(lp.x, 0, lp.z), 23.0])
				for row: float in [-1.0, 1.0]:
					for b in 10:
						if rng.randf() < 0.62:
							var cx := -15.75 + b * 3.5
							var car: String = ["car_a", "car_b", "car_c"][rng.randi() % 3]
							var cb := Basis(Vector3.UP, 0.0 if row > 0.0 else PI)
							add_instance(car, lxf * Transform3D(cb, Vector3(cx, 0.12, row * 8.6)))
		i += 1


# --- Towers --------------------------------------------------------------------

func _tower_kind(i: int) -> String:
	return CityKit.TOWERS[i % CityKit.TOWERS.size()]


## Both sides of Tower Avenue (the main straight): a wall of glass.
func _place_avenue_towers() -> void:
	var s := 0.0
	var L := data.main.length
	var k := 0
	var mid := Vector3.ZERO
	var n_mid := 0
	while s < L:
		var p := data.main.position_at(s)
		var t := data.main.tangent_at(s)
		var straight := absf(data.main.curvature_at(s, 20.0)) < 0.004
		if straight and absf(p.y) < 0.3:
			var r := data.main.right_at(s)
			for side: float in [-1.0, 1.0]:
				var kind := _tower_kind(k + (0 if side > 0.0 else 2))
				var rad: float = TOWER_R[kind]
				var off := data.main.half_width_at(s) + data.offroad_width + 6.0 + rad
				var tp := p + r * side * off
				# Long faces parallel to the road, entrance toward it.
				var fwd := -r * side
				var yaw := atan2(fwd.x, fwd.z)
				if _place_building(kind, tp, yaw, rad, 2.5):
					towers_placed += 1
					if data.main.half_width_at(s) > 9.5:
						mid += tp
						n_mid += 1
			k += 1
			s += 40.0
		else:
			s += 6.0
	if n_mid > 0:
		var m := Node3D.new()
		m.name = "TowerAvenue"
		m.position = mid / n_mid + Vector3(0, 30, 0)
		add_child(m)
		landmarks["tower_avenue"] = m


## Infield blocks and the ring around the course.
func _place_city_towers() -> void:
	var step := 44.0
	var k := 0
	var z := -330.0
	while z < 70.0:
		var x := -400.0
		while x < 330.0:
			var p := Vector3(x + rng.randf_range(-6, 6), 0.0, z + rng.randf_range(-6, 6))
			var kind := _tower_kind(k * 7 + int(absf(x * 0.13)))
			var yaw := (rng.randi() % 4) * PI * 0.5
			if _place_building(kind, p, yaw, TOWER_R[kind], 4.0):
				towers_placed += 1
			k += 1
			x += step
		z += step


# --- Streets -------------------------------------------------------------------

## Sidewalk dressing on both sides: lamps and planters alternate, a bench
## now and then, billboards on the outside of long straights.
func _place_sidewalks() -> void:
	var s := 0.0
	var L := data.main.length
	var k := 0
	while s < L:
		var p := data.main.position_at(s)
		var r := data.main.right_at(s)
		var t := data.main.tangent_at(s)
		var off := data.main.half_width_at(s) + data.offroad_width + 1.4
		for side: float in [-1.0, 1.0]:
			var sp := p + r * side * off
			if not clear_of_track(sp, 0.6, -0.8):
				continue
			var y := p.y - 0.05 if absf(p.y) > 0.4 else -0.08
			if k % 2 == 0:
				add_instance("lamp", _face(Vector3(sp.x, y, sp.z), -r * side))
			else:
				add_instance("planter", Transform3D(Basis.IDENTITY, Vector3(sp.x, y, sp.z)))
			if k % 6 == 3:
				var bp := sp + r * side * 1.8 + t * 2.5
				if clear_of_track(bp, 0.8, -0.6):
					add_instance("bench", _face(Vector3(bp.x, y, bp.z), -r * side))
		if k % 7 == 2 and absf(data.main.curvature_at(s, 12.0)) < 0.006:
			for side: float in [1.0, -1.0]:
				var bb := p + r * side * (off + 4.0)
				if clear_of_track(bb, 4.5, 0.2) and absf(p.y) < 0.4:
					add_instance("billboard", _face(Vector3(bb.x, -0.1, bb.z), -t))
					break
		k += 1
		s += 13.0


func _place_city_landmarks() -> void:
	_build_gantry()
	# The Flame Towers on the hill in the south-west, as seen from the centre.
	var ft := _landmark(LandmarkKit.get_mesh("flame_towers_far"),
		Transform3D(Basis(Vector3.UP, 1.2), Vector3(FLAME_SITE.x, (builder.terrain_height(FLAME_SITE.x, FLAME_SITE.z) if builder else 0.0) - 1.0, FLAME_SITE.z)), "FlameTowers")
	ft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	landmarks["flame_towers"] = ft


func _place_city_promenade() -> void:
	var sea := data.sea_z
	var x := -330.0
	while x < 300.0:
		var p := Vector3(x, -0.05, sea - 0.4)
		add_instance("baluster", Transform3D(Basis.IDENTITY, p))
		x += 2.0
	x = -326.0
	var k := 0
	while x < 300.0:
		var pp := Vector3(x, -0.05, sea - 7.0)
		if clear_of_track(pp, 1.0, 0.5):
			if k % 2 == 0:
				add_instance("palm" if k % 4 == 0 else "palm_b", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pp))
			else:
				add_instance("lamp", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, -0.05, sea - 3.2)))
				add_instance("bench", _face(Vector3(x + 4.0, -0.05, sea - 2.0), Vector3(0, 0, -1)))
		x += 11.0
		k += 1


## Far skyline beyond the playable blocks (sunk into the hills, never on
## the sea side) so the city reads as big from every corner.
func _place_city_skyline() -> void:
	var k := 0
	for ring in [[260.0, 26], [360.0, 30]]:
		var rad: float = ring[0]
		var n: int = ring[1]
		for i in n:
			var a := TAU * (i + 0.5 * (k % 2)) / n
			var p := Vector3(-45.0 + cos(a) * rad * 1.15, 0.0, -90.0 + sin(a) * rad)
			if p.z > data.sea_z - 40.0:
				continue
			var kind := _tower_kind(i * 3 + k)
			if not clear_of_track(p, TOWER_R[kind], 30.0):
				continue
			var sc := rng.randf_range(0.9, 1.25)
			add_instance(kind, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, sc, 1)), Vector3(p.x, -4.0, p.z)))
			towers_placed += 1
		k += 1
