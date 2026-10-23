class_name LandmarkKit
extends RefCounted
## Stylised, recognisable Baku landmarks built procedurally (original
## geometry, no third-party models). Silhouettes come first; surfaces are
## smooth parametric grids with generated normals rather than dense detail,
## and every landmark has a simple far LOD. Scale and placement are adapted
## to the fictional circuit, not to real geography.
##
##  flame_towers   three curved, flame-shaped glass towers (group)
##  heydar_aliyev  flowing white wave-roof building with a glass front
##  crescent       upright crescent-shaped tower on a podium in the bay
##  flag_square    stepped plaza, very tall pole; the flag is a separate
##                 waving mesh (see flag_mesh / flag_material)
##  maiden_tower   lives in PropKit (Old City prop set), refined there

const GLASS_SHADER := preload("res://assets/materials/glass_tower.gdshader")
const FLAG_SHADER := preload("res://assets/materials/flag.gdshader")

static var _meshes := {}
static var _mats := {}


static func glass(height: float, warm := false) -> ShaderMaterial:
	var key := "glass_%d_%s" % [int(height), warm]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = GLASS_SHADER
	m.set_shader_parameter("height", height)
	if warm:
		m.set_shader_parameter("glass_low", Color(0.16, 0.36, 0.74))
		m.set_shader_parameter("glass_high", Color(0.62, 0.82, 1.0))
	_mats[key] = m
	return m


static func dark_glass() -> ShaderMaterial:
	if not _mats.has("dark_glass"):
		var m := ShaderMaterial.new()
		m.shader = GLASS_SHADER
		m.set_shader_parameter("height", 30.0)
		m.set_shader_parameter("glass_low", Color(0.05, 0.14, 0.34))
		m.set_shader_parameter("glass_high", Color(0.16, 0.36, 0.62))
		m.set_shader_parameter("floor_h", 5.0)
		m.set_shader_parameter("mullion_w", 2.2)
		_mats["dark_glass"] = m
	return _mats["dark_glass"]


static func white_shell() -> StandardMaterial3D:
	if not _mats.has("white"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.97, 0.97, 0.98)
		m.roughness = 0.32
		m.metallic_specular = 0.7
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.rim_enabled = true
		m.rim = 0.25
		_mats["white"] = m
	return _mats["white"]


static func flag_material() -> ShaderMaterial:
	if not _mats.has("flag"):
		var m := ShaderMaterial.new()
		m.shader = FLAG_SHADER
		TextureLibrary.bind(m, "flag_tex", "flag_az")
		_mats["flag"] = m
	return _mats["flag"]


static func get_mesh(id: String) -> ArrayMesh:
	if _meshes.has(id):
		return _meshes[id]
	var mesh: ArrayMesh
	match id:
		"flame_towers": mesh = _flame_towers(false)
		"flame_towers_far": mesh = _flame_towers(true)
		"heydar_aliyev": mesh = _heydar_aliyev(false)
		"heydar_aliyev_far": mesh = _heydar_aliyev(true)
		"crescent": mesh = _crescent(false)
		"crescent_far": mesh = _crescent(true)
		"flag_square": mesh = _flag_square()
		"flag": mesh = flag_mesh(24.0, 12.0)
	_meshes[id] = mesh
	return mesh


# --- Helpers ---------------------------------------------------------------------

## Indexed parametric grid f(u, v) -> point, u wraps when closed_u.
## Smooth normals are generated from the shared vertices.
static func grid(nu: int, nv: int, f: Callable, closed_u := false, flip := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := nu if closed_u else nu + 1
	for j in nv + 1:
		for i in cols:
			var u := float(i) / nu
			var v := float(j) / nv
			st.set_uv(Vector2(u, v))
			st.add_vertex(f.call(u, v))
	for j in nv:
		for i in nu:
			var i1 := (i + 1) % cols if closed_u else i + 1
			var a := j * cols + i
			var b := j * cols + i1
			var c := (j + 1) * cols + i1
			var d := (j + 1) * cols + i
			if flip:
				st.add_index(a); st.add_index(c); st.add_index(b)
				st.add_index(a); st.add_index(d); st.add_index(c)
			else:
				st.add_index(a); st.add_index(b); st.add_index(c)
				st.add_index(a); st.add_index(c); st.add_index(d)
	st.generate_normals()
	return st.commit()


static func _merge(parts: Array) -> ArrayMesh:
	# parts: [[mesh, xform, material], ...] → one mesh, one surface per material
	var acc := PropKit.Accum.new()
	for p in parts:
		acc.add(p[0], p[1], p[2])
	return acc.commit()


# --- Flame Towers ------------------------------------------------------------------

## One flame: egg-shaped plan that narrows to a pointed tip while the front
## face curves backwards, like a flame licking upwards.
static func _flame(height: float, radius: float, lean: float, lod: bool) -> ArrayMesh:
	var nu := 12 if lod else 28
	var nv := 6 if lod else 22
	return grid(nu, nv, func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var r := radius * (1.0 + 0.28 * cos(th)) # pointed-egg plan, +x is the front
		var w := pow(maxf(1.0 - pow(v, 2.4), 0.0), 0.55)
		var back := -radius * lean * v * v
		return Vector3(cos(th) * r * w + back, v * height, sin(th) * r * 0.78 * w), true, true)


static func _flame_towers(lod: bool) -> ArrayMesh:
	# Three towers on a triangle, each front facing outwards; middle tallest.
	var defs := [[86.0, 15.0, 0.9, Vector3(0, 0, -16), PI * 0.5], [72.0, 13.0, 1.0, Vector3(-17, 0, 12), PI * 1.17], [66.0, 12.5, 1.0, Vector3(17, 0, 12), -PI * 0.17]]
	var parts: Array = []
	for d in defs:
		var h: float = d[0]
		var mesh := _flame(h, d[1], d[2], lod)
		parts.append([mesh, Transform3D(Basis(Vector3.UP, d[4]), d[3]), glass(h, d[0] < 70.0)])
	# Shared podium
	parts.append([ShapeKit.cylinder(34.0, 3.0, 24 if not lod else 12), Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), PropKit.m("stone_dark")])
	return _merge(parts)


# --- Heydar Aliyev Center ------------------------------------------------------------

static func _hac_height(u: float) -> float:
	# Three flowing crests, the tallest towards one end.
	return 12.0 + 10.0 * exp(-pow((u - 0.2) / 0.12, 2.0)) + 18.0 * exp(-pow((u - 0.66) / 0.17, 2.0))


static func _hac_point(u: float, v: float, L: float, W: float) -> Vector3:
	var env := smoothstep(0.0, 0.16, u) * smoothstep(1.0, 0.84, u)
	var f: float
	if v < 0.78:
		f = pow(sin(v / 0.78 * PI * 0.5), 1.3)
	else:
		f = 1.0 + 0.07 * sin((v - 0.78) / 0.22 * PI) # rolled front lip
	var y := _hac_height(u) * env * f
	var z := (v - 0.5) * W + sin(u * PI * 1.6 + 0.4) * 7.0 * v # wavy plan
	var x := (u - 0.5) * L - (1.0 - env) * 6.0 * (1.0 if u < 0.5 else -1.0)
	return Vector3(x, y, z)


static func _heydar_aliyev(lod: bool) -> ArrayMesh:
	var L := 120.0
	var W := 54.0
	var nu := 20 if lod else 56
	var nv := 8 if lod else 22
	var shell := grid(nu, nv, func(u: float, v: float) -> Vector3: return _hac_point(u, v, L, W))
	# Glass facade under the lip (front, +z), set slightly back.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nu:
		var u0 := float(i) / nu
		var u1 := float(i + 1) / nu
		var a := _hac_point(u0, 1.0, L, W)
		var b := _hac_point(u1, 1.0, L, W)
		var a0 := Vector3(a.x, 0.0, a.z - 2.5)
		var b0 := Vector3(b.x, 0.0, b.z - 2.5)
		var a1 := Vector3(a.x, a.y * 0.9, a.z - 1.5)
		var b1 := Vector3(b.x, b.y * 0.9, b.z - 1.5)
		if a.y < 0.5 and b.y < 0.5:
			continue
		for p in [a0, b1, b0, a0, a1, b1]: # clockwise seen from the front
			st.set_normal(Vector3(0, 0, 1))
			st.set_uv(Vector2(p.x / 4.0, p.y / 4.0))
			st.add_vertex(p)
	var facade := st.commit()
	var plaza := ShapeKit.cylinder(1.0, 0.3, 24)
	return _merge([
		[shell, Transform3D.IDENTITY, white_shell()],
		[facade, Transform3D.IDENTITY, dark_glass()],
		[plaza, Transform3D(Basis.IDENTITY.scaled(Vector3(L * 0.62, 1.0, W * 0.75)), Vector3(0, 0.15, 6.0)), PropKit.m("plaster_white")],
	])


# --- Baku Crescent ---------------------------------------------------------------------

## Upright crescent: outer circle minus an offset inner circle, extruded.
## Opening faces up-left; it stands on a round podium in the water.
static func _crescent(lod: bool) -> ArrayMesh:
	var R := 46.0
	var oc := Vector2(0, R) # outer centre (bottom touches y = 0)
	var r := 39.0
	var ic := Vector2(-15.0, R + 12.0)
	# Circle intersections (the two tips).
	var d := oc.distance_to(ic)
	var a := (R * R - r * r + d * d) / (2.0 * d)
	var h := sqrt(maxf(R * R - a * a, 0.0))
	var dir := (ic - oc) / d
	var mid := oc + dir * a
	var perp := Vector2(-dir.y, dir.x)
	var t1 := mid + perp * h
	var t2 := mid - perp * h
	var n := 14 if lod else 40
	# Outer arc from t1 to t2 the long way (away from the inner circle).
	var oa1 := (t1 - oc).angle()
	var oa2 := (t2 - oc).angle()
	var away := (oc - ic).angle()
	var outer: Array[Vector2] = []
	var inner: Array[Vector2] = []
	var span := wrapf(oa2 - oa1, 0.0, TAU)
	var mid_ang := oa1 + span * 0.5
	if absf(wrapf(mid_ang - away, -PI, PI)) > PI * 0.5:
		span -= TAU
	var ia1 := (t1 - ic).angle()
	var ia2 := (t2 - ic).angle()
	var ispan := wrapf(ia2 - ia1, 0.0, TAU)
	if absf(wrapf(ia1 + ispan * 0.5 - away, -PI, PI)) > PI * 0.5:
		ispan -= TAU
	for i in n + 1:
		var t := float(i) / n
		outer.append(oc + Vector2.from_angle(oa1 + span * t) * R)
		inner.append(ic + Vector2.from_angle(ia1 + ispan * t) * r)
	var depth := 22.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zf := depth * 0.5
	for i in n:
		var o0 := outer[i]
		var o1 := outer[i + 1]
		var i0 := inner[i]
		var i1 := inner[i + 1]
		# front and back faces
		_tri(st, Vector3(o0.x, o0.y, zf), Vector3(i0.x, i0.y, zf), Vector3(o1.x, o1.y, zf), Vector3(0, 0, 1))
		_tri(st, Vector3(o1.x, o1.y, zf), Vector3(i0.x, i0.y, zf), Vector3(i1.x, i1.y, zf), Vector3(0, 0, 1))
		_tri(st, Vector3(o0.x, o0.y, -zf), Vector3(o1.x, o1.y, -zf), Vector3(i0.x, i0.y, -zf), Vector3(0, 0, -1))
		_tri(st, Vector3(o1.x, o1.y, -zf), Vector3(i1.x, i1.y, -zf), Vector3(i0.x, i0.y, -zf), Vector3(0, 0, -1))
		# outer wall (normal away from the outer centre) and inner wall
		var no := Vector3((o0 + o1 - oc * 2.0).normalized().x, (o0 + o1 - oc * 2.0).normalized().y, 0)
		_quad_wall(st, o0, o1, zf, no)
		var ni := Vector3(-(i0 + i1 - ic * 2.0).normalized().x, -(i0 + i1 - ic * 2.0).normalized().y, 0)
		_quad_wall(st, i1, i0, zf, ni)
	var body := st.commit()
	return _merge([
		[body, Transform3D.IDENTITY, glass(92.0, true)],
		[ShapeKit.cylinder(40.0, 4.0, 28 if not lod else 14), Transform3D(Basis.IDENTITY, Vector3(0, -1.5, 0)), PropKit.m("stone_dark")],
		[ShapeKit.cylinder(41.0, 0.6, 28 if not lod else 14), Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)), PropKit.m("white")],
	])


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	# Wind to match the requested normal.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp := b
		b = c
		c = tmp
	for p in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(p.x, p.y) / 4.0)
		st.add_vertex(p)


static func _quad_wall(st: SurfaceTool, p0: Vector2, p1: Vector2, zf: float, n: Vector3) -> void:
	var a := Vector3(p0.x, p0.y, zf)
	var b := Vector3(p1.x, p1.y, zf)
	var c := Vector3(p1.x, p1.y, -zf)
	var d := Vector3(p0.x, p0.y, -zf)
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)


# --- National Flag Square ------------------------------------------------------------------

const FLAG_POLE_H := 64.0


static func _flag_square() -> ArrayMesh:
	var parts: Array = []
	var plaza := ShapeKit.cylinder(34.0, 0.4, 40)
	parts.append([plaza, Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 0)), PropKit.m("plaster_cream")])
	for k in 3:
		var rr: float = [20.0, 14.5, 9.0][k]
		parts.append([ShapeKit.cylinder(rr, 0.7, 36), Transform3D(Basis.IDENTITY, Vector3(0, 0.6 + k * 0.7, 0)), PropKit.m("limestone")])
	# Blue / red / green rings around the base (the flag's colours).
	var ring_cols := ["blue", "red", "green"]
	for k in 3:
		parts.append([ShapeKit.torus(23.0 + k * 1.6, 23.8 + k * 1.6, 48, 4), Transform3D(Basis.IDENTITY, Vector3(0, 0.38, 0)), PropKit.m(ring_cols[k])])
	parts.append([ShapeKit.cone(0.9, 0.45, FLAG_POLE_H, 12), Transform3D(Basis.IDENTITY, Vector3(0, 2.6 + FLAG_POLE_H * 0.5, 0)), PropKit.m("metal_grey")])
	parts.append([ShapeKit.sphere(1.0, 10, 6), Transform3D(Basis.IDENTITY, Vector3(0, 2.6 + FLAG_POLE_H + 0.6, 0)), PropKit.m("gold")])
	# Ring of lamps
	for i in 8:
		var ang := TAU * i / 8.0
		parts.append([ShapeKit.cylinder(0.18, 6.0, 8), Transform3D(Basis.IDENTITY, Vector3(cos(ang) * 30.0, 3.0, sin(ang) * 30.0)), PropKit.m("metal_dark")])
		parts.append([ShapeKit.sphere(0.6, 8, 6), Transform3D(Basis.IDENTITY, Vector3(cos(ang) * 30.0, 6.2, sin(ang) * 30.0)), PropKit.m("lantern")])
	return _merge(parts)


## Flag cloth in the local YZ plane: hoist at z = 0, fly towards +z, top at
## y = 0. Seen from -x the hoist is on the viewer's left (correct face).
static func flag_mesh(length: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 24
	var nv := 8
	for j in nv + 1:
		for i in nu + 1:
			var u := float(i) / nu
			var v := float(j) / nv
			st.set_uv(Vector2(u, v))
			st.set_normal(Vector3(-1, 0, 0))
			st.add_vertex(Vector3(0, -v * height, u * length))
	for j in nv:
		for i in nu:
			var a := j * (nu + 1) + i
			var b := a + 1
			var c := a + nu + 2
			var d := a + nu + 1
			st.add_index(a); st.add_index(d); st.add_index(c)
			st.add_index(a); st.add_index(c); st.add_index(b)
	var mesh := st.commit()
	mesh.surface_set_material(0, flag_material())
	return mesh


## Adds the waving flag to a placed flag square (node at the plaza origin).
static func attach_flag(parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Flag"
	mi.mesh = get_mesh("flag")
	mi.position = Vector3(0, 2.6 + FLAG_POLE_H - 0.4, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	parent.add_child(mi)
	return mi
