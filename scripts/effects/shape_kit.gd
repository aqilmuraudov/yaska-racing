class_name ShapeKit
extends RefCounted
## Procedural rounded primitives with smooth analytic normals. Superellipsoids
## give soft, bevelled silhouettes (rounded boxes, pods, helmets) that read
## as "finished" stylised shapes rather than raw primitives.

static var _cache: Dictionary = {}
## 0.10.2 LOD: segment multiplier used while building far-LOD prop meshes
## (PropKit "<id>@lo"). 1.0 = full detail; counts never drop below a
## minimum that keeps each shape's silhouette.
static var detail := 1.0


static func _d(n: int, lo: int) -> int:
	return n if detail >= 0.999 else maxi(lo, mini(n, int(round(n * detail))))


static func _sgnpow(x: float, p: float) -> float:
	return signf(x) * pow(absf(x), p)


## size: full extents. e_v / e_h: squareness (0.1 boxy … 1 round … 2 pinched).
## front_scale / back_scale: (x, y) multipliers at z = -half (front) / +half.
## y_shift_front: lifts the front section (wedge noses).
static func superellipsoid(size: Vector3, e_v: float = 0.35, e_h: float = 0.35,
		front_scale := Vector2.ONE, back_scale := Vector2.ONE, rings: int = 10, segs: int = 18,
		y_shift_front: float = 0.0) -> ArrayMesh:
	rings = _d(rings, 4)
	segs = _d(segs, 8)
	var key := "%s|%s|%s|%s|%s|%d|%d|%s" % [size, e_v, e_h, front_scale, back_scale, rings, segs, y_shift_front]
	if _cache.has(key):
		return _cache[key]
	var h := size * 0.5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in rings + 1:
		var v := lerpf(-PI * 0.5, PI * 0.5, float(i) / rings)
		for j in segs + 1:
			var u := lerpf(-PI, PI, float(j) / segs)
			var cv := cos(v)
			var sv := sin(v)
			var cu := cos(u)
			var su := sin(u)
			var x := h.x * _sgnpow(cv, e_v) * _sgnpow(cu, e_h)
			var y := h.y * _sgnpow(sv, e_v)
			var z := h.z * _sgnpow(cv, e_v) * _sgnpow(su, e_h)
			var nx := _sgnpow(cv, 2.0 - e_v) * _sgnpow(cu, 2.0 - e_h) / maxf(h.x, 0.001)
			var ny := _sgnpow(sv, 2.0 - e_v) / maxf(h.y, 0.001)
			var nz := _sgnpow(cv, 2.0 - e_v) * _sgnpow(su, 2.0 - e_h) / maxf(h.z, 0.001)
			# Taper along z (front = -z).
			var t := clampf((z / maxf(h.z, 0.001)) * 0.5 + 0.5, 0.0, 1.0) # 0 front, 1 back
			var sc := front_scale.lerp(back_scale, t)
			var lift := y_shift_front * (1.0 - t)
			var p := Vector3(x * sc.x, y * sc.y + lift, z)
			var n := Vector3(nx / maxf(sc.x, 0.01), ny / maxf(sc.y, 0.01), nz)
			if n.length_squared() < 1e-10:
				n = Vector3(0, signf(y), 0)
			verts.append(p)
			normals.append(n.normalized())
			uvs.append(Vector2(float(j) / segs, float(i) / rings))
	var row := segs + 1
	for i in rings:
		for j in segs:
			var a := i * row + j
			var b := a + 1
			var c := a + row
			var d := c + 1
			# Godot clockwise front faces.
			indices.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[key] = mesh
	return mesh


static func mat(color: Color, roughness: float = 0.6, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var key := "mat|%s|%s|%s|%s" % [color.to_html(), roughness, metallic, emission]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Palette.vivid(color)
	m.roughness = roughness
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Palette.vivid(color)
		m.emission_energy_multiplier = emission
	_cache[key] = m
	return m


static func add_mesh(parent: Node3D, mesh: Mesh, material: Material, xform: Transform3D, node_name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if node_name != "":
		mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.transform = xform
	parent.add_child(mi)
	return mi


static func cylinder(radius: float, height: float, sides: int = 16) -> CylinderMesh:
	sides = _d(sides, 5)
	var key := "cyl|%s|%s|%d" % [radius, height, sides]
	if _cache.has(key):
		return _cache[key]
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	_cache[key] = c
	return c


static func cone(r_bottom: float, r_top: float, height: float, sides: int = 12) -> CylinderMesh:
	sides = _d(sides, 4)
	var key := "cone|%s|%s|%s|%d" % [r_bottom, r_top, height, sides]
	if _cache.has(key):
		return _cache[key]
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	_cache[key] = c
	return c


static func torus(inner: float, outer: float, rings: int = 18, ring_segments: int = 10) -> TorusMesh:
	rings = _d(rings, 6)
	ring_segments = _d(ring_segments, 4)
	var key := "torus|%s|%s|%d|%d" % [inner, outer, rings, ring_segments]
	if _cache.has(key):
		return _cache[key]
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = rings
	t.ring_segments = ring_segments
	_cache[key] = t
	return t


static func sphere(radius: float, segs: int = 16, rings: int = 10) -> SphereMesh:
	segs = _d(segs, 6)
	rings = _d(rings, 3)
	var key := "sph|%s|%d|%d" % [radius, segs, rings]
	if _cache.has(key):
		return _cache[key]
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segs
	s.rings = rings
	_cache[key] = s
	return s


## Soft round texture used by smoke / dust billboards.
static func soft_dot_texture() -> Texture2D:
	if _cache.has("soft_dot"):
		return _cache["soft_dot"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.75))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_cache["soft_dot"] = tex
	return tex
