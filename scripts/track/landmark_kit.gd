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
##  government_house  symmetric limestone block with a stepped central
##                 tower, arched top-floor loggias and corner pavilions
##  carpet_museum  long building shaped like a half-rolled carpet
##  qosa_qala      Icherisheher double gate: two crenellated semicircular
##                 towers, two pointed arches, battlements (walls separate)
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


## 0.14.4 Blender-made landmarks (tools/blender/landmarks.py); "<id>_far"
## comes from the far glTF. Missing file -> the procedural mesh below.
const GLTF_LANDMARKS := ["government_house", "carpet_museum", "crystal_hall", "tv_tower", "crescent"]
const GLTF_LANDMARK_BASE := "res://assets/models/landmarks/landmarks"


static func gltf_landmark(id: String) -> ArrayMesh:
	var far := id.ends_with("_far")
	var base_id := id.trim_suffix("_far")
	if not PropKit.gltf_enabled or not base_id in GLTF_LANDMARKS:
		return null
	var path := GLTF_LANDMARK_BASE + ("_far" if far else "") + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var inst := (load(path) as PackedScene).instantiate()
	var mi := inst.find_child(base_id, true, false) as MeshInstance3D
	var mesh: ArrayMesh = mi.mesh as ArrayMesh if mi else null
	inst.free()
	if mesh:
		mesh.surface_set_material(0, PropKit.baked_material(path.get_base_dir()))
	return mesh


static func get_mesh(id: String) -> ArrayMesh:
	if _meshes.has(id):
		return _meshes[id]
	var gm := gltf_landmark(id)
	if gm:
		_meshes[id] = gm
		return gm
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
		"government_house": mesh = _government_house(false)
		"government_house_far": mesh = _government_house(true)
		"carpet_museum": mesh = _carpet_museum(false)
		"carpet_museum_far": mesh = _carpet_museum(true)
		"qosa_qala": mesh = qosa_qala(22.0)
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
# Real: three flame-shaped glass towers (HOK, 2012) of 182 / 165 / 161 m on
# the hill above the Old City, set on a triangle with the convex faces turned
# outwards; blue glass with a mullion grid and an LED skin that shows moving
# flames at night. Here: 0.66 scale, same height ratios and arrangement, the
# towers clearly apart so each flame reads on its own.

static var _flame_mats: Array = []
static var _flame_amount := 0.0


static func flame_glass(height: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLASS_SHADER
	m.set_shader_parameter("height", height)
	m.set_shader_parameter("glass_low", Color(0.07, 0.24, 0.58))
	m.set_shader_parameter("glass_high", Color(0.46, 0.72, 0.98))
	m.set_shader_parameter("floor_h", 3.4)
	m.set_shader_parameter("mullion_w", 2.4)
	m.set_shader_parameter("flame_led", _flame_amount)
	_flame_mats.append(m)
	return m


## LED flame animation on/off (on for the High-type presets).
static func set_flame_led(amount: float) -> void:
	_flame_amount = amount
	for m in _flame_mats:
		m.set_shader_parameter("flame_led", amount)


## One flame (0.15.3, from photos of the real towers): an almost straight,
## slightly bellied column with a teardrop plan - round "front" (+x) and a
## narrower back edge (-x). Over the top ~40 % the round front sweeps up and
## back in a curve and meets the near-vertical back edge at a sharp tip, so
## the tip stands over the back edge (like a tongue of fire). Section width
## shrinks with the section length, closing the tip.
const FLAME_CURL := 0.5 ## height fraction where the front starts to curl back


static func flame_point(u: float, v: float, height: float, radius: float) -> Vector3:
	var th := u * TAU
	var belly := 1.0 + 0.07 * sin(PI * minf(v / FLAME_CURL, 1.0))
	var r := radius * belly
	# Back edge: near vertical, leaning in a little towards the tip.
	var x_back := -r * (1.0 - 0.1 * v * v)
	var x_front := r
	if v > FLAME_CURL:
		var t := (v - FLAME_CURL) / (1.0 - FLAME_CURL)
		x_front = x_back + (r - x_back) * pow(maxf(1.0 - pow(t, 1.6), 0.0), 0.7)
	var length := maxf(x_front - x_back, 0.0)
	# Teardrop section: round at the front, pointed towards the back edge.
	var c := cos(th)
	var x := x_back + length * (1.0 + c) * 0.5
	var half_w := minf(length, 2.0 * r) * 0.43
	var z := half_w * sin(th) * pow((1.0 + c) * 0.5, 0.3)
	return Vector3(x, v * height, z)


static func _flame(height: float, radius: float, lod: bool) -> ArrayMesh:
	var nu := 16 if lod else 48
	var nv := 10 if lod else 40
	return grid(nu, nv, func(u: float, v: float) -> Vector3: return flame_point(u, v, height, radius), true, true)


## Tower layout in the group's local frame: [height, radius, centre].
## Real 182 / 165 / 161 m at ~0.66; tallest at the back (-z), centres on a
## triangle of 42 m circumradius (from the sea all three read apart).
static func flame_defs() -> Array:
	return [[120.0, 21.0, Vector3(0, 0, -42)], [109.0, 19.5, Vector3(-36.4, 0, 21)], [106.0, 19.0, Vector3(36.4, 0, 21)]]


static func _flame_towers(lod: bool) -> ArrayMesh:
	var parts: Array = []
	for d in flame_defs():
		var h: float = d[0]
		var c: Vector3 = d[2]
		# The tip (back edge, -x local) points away from the triangle centre,
		# the round fronts face each other (as seen from the Boulevard).
		var yaw := atan2(-c.z, c.x) + PI
		var mat: Material = flame_glass(h) # 0.10.1: far LOD shows the LED show too
		parts.append([_flame(h, d[1], lod), Transform3D(Basis(Vector3.UP, yaw), c), mat])
	# Stepped podium with terraces under the towers (stone + glass bands).
	var seg := 28 if not lod else 14
	parts.append([ShapeKit.cone(74.0, 70.0, 4.0, seg), Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0)), PropKit.m("stone_dark")])
	parts.append([ShapeKit.cone(68.0, 66.0, 3.0, seg), Transform3D(Basis.IDENTITY, Vector3(0, 3.5, 0)), PropKit.m("limestone")])
	parts.append([ShapeKit.cylinder(62.0, 0.6, seg), Transform3D(Basis.IDENTITY, Vector3(0, 5.1, 0)), PropKit.m("hedge")])
	return _merge(parts)


# --- Heydar Aliyev Center ------------------------------------------------------------
# Real (Zaha Hadid, 2012): ~74 m high, a brilliant white continuous skin with
# no corners. Seen from the plaza it rises from the ground on the left into a
# tall curling peak, dips, rolls up into a second lower crest and sweeps back
# down into the plaza on the right; a huge dark curved glass wall is tucked
# under the overhanging lip; terraced lawns step down in front. ~1:1.4 scale.
# Local frame: length along x (left = -x seen from the front), front = +z.

const HAC_L := 196.0
const HAC_D := 74.0
const HAC_EDGE := 0.4 # front lip height as a fraction of the local height


## 0.15.3 (from photos): low glazed arch on the left, a dip, then the shell
## sweeps up into the tall round-topped arch portal (steep right side), and a
## long low wing tapers away to the right.
static func hac_height(u: float) -> float:
	var foot := smoothstep(0.0, 0.05, u) * smoothstep(1.0, 0.93, u)
	var low_arch := 20.0 * exp(-pow((u - 0.12) / 0.075, 2.0))
	var base := 9.0 * smoothstep(0.03, 0.1, u) * smoothstep(0.62, 0.52, u)
	var d := u - 0.47
	var portal := 46.0 * (exp(-pow(d / 0.15, 2.0)) if d < 0.0 else exp(-pow(d / 0.06, 4.0)))
	var wing := 13.0 * smoothstep(0.5, 0.6, u) * smoothstep(1.0, 0.72, u)
	return foot * maxf(maxf(low_arch + base, portal), wing)


## The pointed "horn" rising behind the left half (auditorium roof).
static func hac_horn_point(u: float, v: float) -> Vector3:
	var th := u * TAU
	var r := 19.0 * pow(maxf(1.0 - v, 0.0), 0.72)
	var h := 52.0
	var lean := 7.0 * v * v
	return Vector3(-40.0 + cos(th) * r, v * h, -16.0 + lean + sin(th) * r * 0.8)


static func _hac_theta_end() -> float:
	return asin(HAC_EDGE)


## Point on the shell: v = 0 at the back foot, over the crest, v = 1 at the
## front lip. The crest leans forward over the glass like a breaking wave.
static func hac_point(u: float, v: float) -> Vector3:
	var h := hac_height(u)
	var th := lerpf(PI, _hac_theta_end(), v)
	var rz := HAC_D * 0.5
	var zc := 5.0 * sin(u * PI * 1.4 + 0.5) - 4.0
	var s := sin(th)
	var curl := 0.3 * h * pow(s, 4.0) * (h / 54.0)
	var x := (u - 0.5) * HAC_L
	return Vector3(x, h * s + 0.25, zc + rz * cos(th) + curl)


## Brilliant white skin that stays white on the shaded side too (the
## building's identity), slightly glossy.
static func hac_white() -> StandardMaterial3D:
	if not _mats.has("hac_white"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.97, 0.97, 0.98)
		m.roughness = 0.28
		m.metallic_specular = 0.75
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.rim_enabled = true
		m.rim = 0.3
		m.emission_enabled = true
		m.emission = Color(0.8, 0.82, 0.86)
		m.emission_energy_multiplier = 0.32
		_mats["hac_white"] = m
	return _mats["hac_white"]


static func hac_glass() -> ShaderMaterial:
	if not _mats.has("hac_glass"):
		var m := ShaderMaterial.new()
		m.shader = GLASS_SHADER
		m.set_shader_parameter("height", 50.0)
		m.set_shader_parameter("glass_low", Color(0.06, 0.1, 0.16))
		m.set_shader_parameter("glass_high", Color(0.22, 0.32, 0.44))
		m.set_shader_parameter("sky_tint", Color(0.55, 0.62, 0.7))
		m.set_shader_parameter("frame_color", Color(0.55, 0.6, 0.66))
		m.set_shader_parameter("floor_h", 5.0)
		m.set_shader_parameter("mullion_w", 3.0)
		m.set_shader_parameter("sparkle", 0.12)
		_mats["hac_glass"] = m
	return _mats["hac_glass"]


static func _heydar_aliyev(lod: bool) -> ArrayMesh:
	var nu := 30 if lod else 104
	var nv := 10 if lod else 30
	var shell := grid(nu, nv, func(u: float, v: float) -> Vector3: return hac_point(u, v))
	var horn := grid(12 if lod else 32, 8 if lod else 20, func(u: float, v: float) -> Vector3: return hac_horn_point(u, v), true, true)
	if _has_gltf("hac_base"):
		# 0.15.3: Blender glass front + plaza under the self-lit white shell.
		var acc := PropKit.Accum.new()
		acc.add_committed(_merge([[shell, Transform3D.IDENTITY, hac_white()], [horn, Transform3D.IDENTITY, hac_white()]]), Transform3D.IDENTITY)
		acc.add_committed(PropKit.get_mesh("hac_base" + (PropKit.LO_SUFFIX if lod else "")), Transform3D.IDENTITY)
		return acc.commit()
	# Curved dark glass wall recessed under the lip: from the ground up to
	# where it meets the underside of the shell, well behind the front edge.
	var th_g := _hac_theta_end() + 0.32
	var vg := (PI - th_g) / (PI - _hac_theta_end())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nu:
		var a := hac_point(float(i) / nu, vg)
		var b := hac_point(float(i + 1) / nu, vg)
		if a.y < 2.0 and b.y < 2.0:
			continue
		var a0 := Vector3(a.x, 0.0, a.z - 2.0)
		var b0 := Vector3(b.x, 0.0, b.z - 2.0)
		for p in [a0, b, b0, a0, a, b]:
			st.set_uv(Vector2(p.x / 4.0, p.y / 4.0))
			st.add_vertex(p)
	st.generate_normals()
	var facade := st.commit()
	var parts: Array = [
		[shell, Transform3D.IDENTITY, hac_white()],
		[horn, Transform3D.IDENTITY, hac_white()],
		[facade, Transform3D.IDENTITY, hac_glass()],
	]
	# Broad plaza with terraced lawns stepping down towards the viewer.
	var front := HAC_D * 0.5 + 4.0
	parts.append([PropKit.box(Vector3(HAC_L * 1.05, 0.5, 12.0)), Transform3D(Basis.IDENTITY, Vector3(0, 0.25, front + 6.0)), PropKit.m("plaster_white")])
	for k in 3:
		var w := HAC_L * (0.78 - k * 0.12)
		var z := front + 14.0 + k * 11.0
		parts.append([PropKit.box(Vector3(w, 1.6 - k * 0.5, 8.0)), Transform3D(Basis.IDENTITY, Vector3(k * 8.0 + 6.0, (1.6 - k * 0.5) * 0.5, z)), PropKit.m("hedge")])
		parts.append([PropKit.box(Vector3(w, 0.3, 3.0)), Transform3D(Basis.IDENTITY, Vector3(k * 8.0 + 6.0, 0.15, z + 5.5)), PropKit.m("plaster_white")])
	if not lod:
		# a few round reflecting pools on the plaza
		for k in 3:
			parts.append([ShapeKit.cylinder(4.5, 0.3, 20), Transform3D(Basis.IDENTITY, Vector3(-50.0 + k * 50.0, 0.55, front + 6.0)), PropKit.m("water_fountain")])
	return _merge(parts)


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
	if _has_gltf("flag_square"):
		return PropKit.get_mesh("flag_square") # 0.15.3 Blender square, same mast height
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


# --- Government House (Hökumət Evi) ---------------------------------------------

static func _government_house(lod: bool) -> ArrayMesh:
	# Hökumət Evi: symmetric sand-coloured Stalinist-Oriental block. Front
	# faces +z: long main block with a ground-floor arcade, two projecting
	# side wings with their own stepped tops, a projecting centre with a
	# giant portal and a stepped tower crowned by a spire and the flag.
	var a := PropKit.Accum.new()
	var sand := PropKit.m("sand")
	var trim := PropKit.m("sand_light")
	var shade := PropKit.m("sand_shade")
	var win := PropKit.m("window_dark")
	var L := 176.0
	var D := 28.0
	var H := 31.0
	var fz := D * 0.5 # main front face
	a.add(PropKit.box(Vector3(L, H, D)), PropKit.T(Vector3(0, H * 0.5, 0)), sand)
	a.add(PropKit.box(Vector3(L + 1.6, 1.4, D + 1.6)), PropKit.T(Vector3(0, H + 0.2, 0)), trim) # cornice
	a.add(PropKit.box(Vector3(L + 2.0, 2.2, D + 2.0)), PropKit.T(Vector3(0, 1.1, 0)), shade) # plinth
	a.add(PropKit.box(Vector3(L + 0.6, 0.8, D + 0.6)), PropKit.T(Vector3(0, 12.6, 0)), trim) # band over the arcade
	# Ground-floor arcade (loggia) along the main block between the wings.
	var arc_w := 4.6
	var nar := int((L - 64.0) / arc_w)
	for k in nar:
		var x := (k - (nar - 1) * 0.5) * arc_w
		if absf(x) < 23.0:
			continue
		_pointed_recess(a, Vector3(x, 2.2, fz + 0.06), 3.2, 9.6, win)
	# Rows of tall windows above (two floors per opening), arched top row.
	if not lod:
		for k in nar:
			var x2 := (k - (nar - 1) * 0.5) * arc_w
			if absf(x2) < 23.0:
				continue
			for f in 2:
				a.add(PropKit.box(Vector3(1.9, 5.0, 0.2)), PropKit.T(Vector3(x2, 16.2 + f * 6.0, fz + 0.06)), win)
			a.add(PropKit.box(Vector3(2.8, 0.4, 0.6)), PropKit.T(Vector3(x2, 13.4, fz + 0.3)), trim) # sills
	# Crenellated parapet along the front.
	if not lod:
		_merlons(a, Vector3(0, H + 0.9, fz + 0.4), L, trim)
	# Projecting side wings with stepped tops and arched corner pavilions.
	for sx: float in [-1.0, 1.0]:
		var wx := sx * (L * 0.5 - 13.0)
		var WH := H + 7.0
		var wz := fz + 8.0
		a.add(PropKit.box(Vector3(26.0, WH, 16.0)), PropKit.T(Vector3(wx, WH * 0.5, wz)), sand)
		a.add(PropKit.box(Vector3(27.4, 1.4, 17.4)), PropKit.T(Vector3(wx, WH + 0.2, wz)), trim)
		a.add(PropKit.box(Vector3(26.8, 0.8, 16.8)), PropKit.T(Vector3(wx, 12.6, wz)), trim)
		a.add(PropKit.box(Vector3(18.0, 7.0, 12.0)), PropKit.T(Vector3(wx, WH + 3.9, wz)), sand)
		a.add(PropKit.box(Vector3(19.2, 1.0, 13.2)), PropKit.T(Vector3(wx, WH + 7.6, wz)), trim)
		a.add(PropKit.box(Vector3(9.0, 6.0, 7.0)), PropKit.T(Vector3(wx, WH + 11.1, wz)), sand)
		a.add(PropKit.box(Vector3(10.0, 0.8, 8.0)), PropKit.T(Vector3(wx, WH + 14.5, wz)), trim)
		var front_w := wz + 8.0 + 0.06
		for k in 4:
			_pointed_recess(a, Vector3(wx - 7.5 + k * 5.0, 2.2, front_w), 3.2, 9.6, win)
		if not lod:
			for c in 4:
				for f in 3:
					a.add(PropKit.box(Vector3(1.8, 4.6, 0.2)), PropKit.T(Vector3(wx - 7.5 + c * 5.0, 16.2 + f * 6.6, front_w)), win)
			for k in 4:
				_pointed_recess(a, Vector3(wx - 6.0 + k * 4.0, WH + 1.2, wz + 6.06), 2.4, 5.0, win)
			for k in 2:
				_pointed_recess(a, Vector3(wx - 2.0 + k * 4.0, WH + 8.8, wz + 3.56), 2.0, 4.4, win)
			_merlons(a, Vector3(wx, WH + 0.9, front_w + 0.3), 26.0, trim)
	# Projecting centre with a giant pointed portal between paired columns.
	var CW := 46.0
	var CH := H + 9.0
	var cz := fz + 5.0
	a.add(PropKit.box(Vector3(CW, CH, 10.0)), PropKit.T(Vector3(0, CH * 0.5, cz)), sand)
	a.add(PropKit.box(Vector3(CW + 1.4, 1.4, 11.4)), PropKit.T(Vector3(0, CH + 0.2, cz)), trim)
	_pointed_recess(a, Vector3(0, 2.2, cz + 5.06), 13.0, 27.0, win)
	for sx2: float in [-1.0, 1.0]:
		for k in 2:
			a.add(ShapeKit.cylinder(0.9, 27.0, 10 if not lod else 6), PropKit.T(Vector3(sx2 * (8.6 + k * 2.6), 15.7, cz + 6.0)), trim)
		_pointed_recess(a, Vector3(sx2 * 17.0, 2.2, cz + 5.06), 4.0, 11.0, win)
		if not lod:
			for f in 3:
				a.add(PropKit.box(Vector3(2.2, 4.6, 0.2)), PropKit.T(Vector3(sx2 * 17.0, 17.0 + f * 6.6, cz + 5.06)), win)
	if not lod:
		_merlons(a, Vector3(0, CH + 0.9, cz + 5.4), CW, trim)
	# Stepped central tower ("wedding cake") with arched loggias, spire, flag.
	var tiers := [[34.0, 10.0, 24.0], [25.0, 9.0, 18.0], [17.0, 8.0, 13.0], [10.0, 7.0, 8.0]]
	var y := CH + 0.9
	for t in tiers:
		a.add(PropKit.box(Vector3(t[0], t[1], t[2])), PropKit.T(Vector3(0, y + t[1] * 0.5, 0.0)), sand)
		a.add(PropKit.box(Vector3(t[0] + 1.4, 1.0, t[2] + 1.4)), PropKit.T(Vector3(0, y + t[1] + 0.3, 0.0)), trim)
		var n := int(t[0] / 4.2)
		for k in n:
			var x3 := (k - (n - 1) * 0.5) * 4.0
			_pointed_recess(a, Vector3(x3, y + 1.4, t[2] * 0.5 + 0.06), 2.4, t[1] - 2.8, win)
		y += t[1] + 0.8
	a.add(ShapeKit.cone(3.4, 0.25, 12.0, 8), PropKit.T(Vector3(0, y + 6.0, 0.0)), trim)
	a.add(ShapeKit.cylinder(0.12, 9.0, 6), PropKit.T(Vector3(0, y + 16.0, 0.0)), PropKit.m("metal_grey"))
	a.add(PropKit.box(Vector3(5.0, 0.9, 0.08)), PropKit.T(Vector3(2.5, y + 19.6, 0.0)), PropKit.m("blue"))
	a.add(PropKit.box(Vector3(5.0, 0.9, 0.08)), PropKit.T(Vector3(2.5, y + 18.7, 0.0)), PropKit.m("red"))
	a.add(PropKit.box(Vector3(5.0, 0.9, 0.08)), PropKit.T(Vector3(2.5, y + 17.8, 0.0)), PropKit.m("green"))
	# Garden and forecourt in front.
	a.add(PropKit.box(Vector3(L * 0.7, 0.3, 22.0)), PropKit.T(Vector3(0, 0.15, fz + 26.0)), PropKit.m("hedge"))
	a.add(PropKit.box(Vector3(30.0, 0.32, 24.0)), PropKit.T(Vector3(0, 0.16, fz + 26.0)), PropKit.m("plaster_cream"))
	return a.commit()


## Row of small battlement blocks centred on c, running along x.
static func _merlons(a: PropKit.Accum, c: Vector3, length: float, mat: Material) -> void:
	var n := int(length / 2.8)
	for k in n:
		var x := c.x + (k - (n - 1) * 0.5) * 2.8
		a.add(PropKit.box(Vector3(1.5, 1.6, 0.9)), PropKit.T(Vector3(x, c.y + 0.8, c.z)), mat)


## Dark recess with a pointed (Islamic) arch top, front facing +z.
static func _pointed_recess(a: PropKit.Accum, base: Vector3, w: float, h: float, mat: Material) -> void:
	var rect_h := h - w * 0.7
	a.add(PropKit.box(Vector3(w, rect_h, 0.2)), PropKit.T(base + Vector3(0, rect_h * 0.5, 0)), mat)
	var steps := 4
	for i in steps:
		var f := float(i + 1) / steps
		var ww := w * (1.0 - f * f * 0.9)
		var hh := w * 0.7 / steps
		a.add(PropKit.box(Vector3(ww, hh, 0.2)), PropKit.T(base + Vector3(0, rect_h + hh * (i + 0.5), 0)), mat)


# --- Carpet Museum (Xalça Muzeyi) --------------------------------------------------

static func _carpet_profile(u: float) -> Vector2:
	# 0..0.62: the flat carpet lifts gently from the ground; after that it
	# rolls into a spiral, like a carpet half rolled up. x along the length.
	var x_end := 22.0
	var r0 := 8.0
	if u < 0.62:
		var t := u / 0.62
		return Vector2(-34.0 + t * (x_end + 34.0), r0 * 2.0 * smoothstep(0.0, 1.0, t) * 0.999)
	var t2 := (u - 0.62) / 0.38
	var ang := PI * 0.5 - t2 * PI * 2.6 # from the top, rolling over the front
	var r := r0 * (1.0 - 0.45 * t2)
	return Vector2(x_end, r0) + Vector2(r * cos(ang), r * sin(ang))


static func _carpet_museum(lod: bool) -> ArrayMesh:
	var W := 18.0
	var nu := 30 if lod else 90
	var ribbon := grid(nu, 2, func(u: float, v: float) -> Vector3:
		var p := _carpet_profile(u)
		return Vector3(p.x, p.y, (v - 0.5) * W))
	var back := grid(nu, 2, func(u: float, v: float) -> Vector3:
		var p := _carpet_profile(u)
		return Vector3(p.x, p.y - 0.35, (v - 0.5) * W), false, true)
	var parts: Array = [
		[ribbon, Transform3D.IDENTITY, PropKit.carpet_material(0)],
		[back, Transform3D.IDENTITY, PropKit.carpet_material(2)],
	]
	# Glass hall under the rising carpet, plus end caps of the roll.
	parts.append([PropKit.box(Vector3(36.0, 7.0, W - 2.0)), Transform3D(Basis.IDENTITY, Vector3(2.0, 3.5, 0)), dark_glass()])
	parts.append([PropKit.box(Vector3(14.0, 12.0, W - 2.0)), Transform3D(Basis.IDENTITY, Vector3(14.0, 6.0, 0)), dark_glass()])
	for sz: float in [-1.0, 1.0]:
		parts.append([ShapeKit.cylinder(8.0, 0.4, 24 if not lod else 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(22.0, 8.0, sz * (W * 0.5 - 0.2))), PropKit.carpet_material(1)])
	parts.append([PropKit.box(Vector3(80.0, 0.4, W + 12.0)), Transform3D(Basis.IDENTITY, Vector3(-4.0, 0.2, 2.0)), PropKit.m("limestone")])
	return _merge(parts)


# --- Qoşa Qala gate -------------------------------------------------------------

## Built in the gate's own frame: x across the road, z along it, y up.
## Two crenellated semicircular towers stand outside `half` and the wall
## over the road has a real pointed arch (clearance > 8 m) next to a second,
## smaller blind arch on each tower side, the "double" gate.
static func qosa_qala(span: float) -> ArrayMesh:
	var gm := _gltf_gate(span)
	if gm:
		return gm
	var a := PropKit.Accum.new()
	var stone := PropKit.m("limestone_warm")
	var light := PropKit.m("limestone")
	var half := span * 0.5
	var wall_h := 13.0
	var th := 2.6
	# Wall over the road: vertical strips whose bottoms trace a pointed arch.
	var n := 28
	var spring := 7.5
	for i in n:
		var x0 := -half + span * float(i) / n
		var x1 := -half + span * float(i + 1) / n
		var xm := (x0 + x1) * 0.5
		var t := absf(xm) / half # 0 centre, 1 edge
		var bottom := maxf(spring + (1.0 - pow(t, 1.6)) * 3.6, 8.6)
		a.add(PropKit.box(Vector3(x1 - x0 + 0.02, wall_h - bottom, th)), PropKit.T(Vector3(xm, (wall_h + bottom) * 0.5, 0)), stone)
	# Machicolation band and merlons on top of the gate wall
	a.add(PropKit.box(Vector3(span, 0.8, th + 1.0)), PropKit.T(Vector3(0, wall_h - 0.6, 0)), light)
	for k in int(span / 2.0):
		a.add(PropKit.box(Vector3(1.1, 1.3, th + 0.6)), PropKit.T(Vector3(-half + 1.0 + k * 2.0, wall_h + 0.65, 0)), stone)
	# Twin semicircular towers
	for sx: float in [-1.0, 1.0]:
		var c := Vector3(sx * (half + 3.6), 0, 0)
		var tw_h := wall_h + 3.0
		a.add(ShapeKit.cylinder(4.6, tw_h, 20), PropKit.T(c + Vector3(0, tw_h * 0.5, 0)), stone)
		a.add(ShapeKit.cylinder(4.9, 0.8, 20), PropKit.T(c + Vector3(0, tw_h - 0.4, 0)), light)
		for k in 12:
			var ang := TAU * k / 12.0
			a.add(PropKit.box(Vector3(1.0, 1.4, 0.8)), PropKit.T(c + Vector3(cos(ang) * 4.5, tw_h + 0.7, sin(ang) * 4.5), Vector3(0, -ang, 0)), stone)
		# Second (smaller) gate arch beside each tower, blind
		_pointed_recess(a, c + Vector3(sx * 6.4, 0, th * 0.5 + 0.06), 3.4, 6.0, PropKit.m("wood"))
		_pointed_recess(a, c + Vector3(sx * 6.4, 0, -th * 0.5 - 0.06), 3.4, 6.0, PropKit.m("wood"))
		a.add(PropKit.box(Vector3(8.0, wall_h - 1.0, th)), PropKit.T(c + Vector3(sx * 6.4, (wall_h - 1.0) * 0.5, 0)), stone)
	return a.commit()


## Blender gate: the arch module is built for GATE_SPAN and stretched across
## the road; the towers keep their shape (the left one is turned 180°).
const GATE_SPAN := 22.0


static func _gltf_gate(span: float) -> ArrayMesh:
	if not _has_gltf("gate_arch"):
		return null
	var a := PropKit.Accum.new()
	a.add_committed(PropKit.get_mesh("gate_arch"), Transform3D(Basis.from_scale(Vector3(span / GATE_SPAN, 1, 1)), Vector3.ZERO))
	var tower := PropKit.get_mesh("gate_tower")
	var off := span * 0.5 + 3.6
	a.add_committed(tower, Transform3D(Basis.IDENTITY, Vector3(off, 0, 0)))
	a.add_committed(tower, Transform3D(Basis(Vector3.UP, PI), Vector3(-off, 0, 0)))
	return a.commit()


## Blender wall: 4 m segments plus a half-round tower every ~24 m, one mesh.
static func _gltf_wall(length: float) -> ArrayMesh:
	if not _has_gltf("wall_seg"):
		return null
	var a := PropKit.Accum.new()
	var seg := PropKit.get_mesh("wall_seg")
	var n := maxi(int(round(length / 4.0)), 1)
	var sx := length / (n * 4.0)
	for k in n:
		a.add_committed(seg, Transform3D(Basis.from_scale(Vector3(sx, 1, 1)), Vector3(k * 4.0 * sx, 0, 0)))
	var tower := PropKit.get_mesh("wall_tower")
	var nt := maxi(int(length / 24.0), 1)
	for t in nt + 1:
		a.add_committed(tower, Transform3D(Basis.IDENTITY, Vector3(length * float(t) / nt, 0, 0)))
	return a.commit()


static func _has_gltf(id: String) -> bool:
	return PropKit.gltf_enabled and ResourceLoader.exists(String(PropKit.GLTF_PROPS[id]) + ".glb")


## Straight crenellated wall segment along +x from the origin.
static func city_wall(length: float) -> ArrayMesh:
	var gm := _gltf_wall(length)
	if gm:
		return gm
	var a := PropKit.Accum.new()
	var stone := PropKit.m("limestone_warm")
	var h := 9.0
	# 0.9.7: battered base course, walkway parapet with rounded-top
	# merlons and half-round towers every ~24 m (İçərişəhər walls).
	a.add(PropKit.box(Vector3(length, h, 2.4)), PropKit.T(Vector3(length * 0.5, h * 0.5, 0)), stone)
	a.add(PropKit.box(Vector3(length, 1.6, 3.2)), PropKit.T(Vector3(length * 0.5, 0.8, 0)), PropKit.m("stone_dark"))
	a.add(PropKit.box(Vector3(length, 0.35, 2.8)), PropKit.T(Vector3(length * 0.5, h - 0.2, 0)), PropKit.m("stone_dark"))
	for k in int(length / 2.0):
		a.add(PropKit.box(Vector3(1.0, 1.0, 2.6)), PropKit.T(Vector3(1.0 + k * 2.0, h + 0.5, 0)), stone)
		a.add(ShapeKit.cylinder(0.5, 2.6, 8), PropKit.T(Vector3(1.0 + k * 2.0, h + 1.0, 0), Vector3(PI * 0.5, 0, 0)), stone)
	var nt := maxi(int(length / 24.0), 1)
	for t in nt + 1:
		var x := length * float(t) / nt
		# Towers stand out on the outer (-z) face, away from the road side.
		a.add(ShapeKit.cylinder(3.4, h + 2.5, 14), PropKit.T(Vector3(x, (h + 2.5) * 0.5, -1.6)), stone)
		for k in 8:
			var ang := PI + PI * float(k) / 7.0
			a.add(PropKit.box(Vector3(0.9, 1.1, 0.9)), PropKit.T(Vector3(x + cos(ang) * 3.1, h + 3.0, -1.6 + sin(ang) * 3.1)), stone)
	return a.commit()
