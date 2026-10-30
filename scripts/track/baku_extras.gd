class_name BakuExtras
extends RefCounted
## 0.9.6 Baku ambiance pieces, procedural and low-poly: Baku TV Tower,
## Crystal Hall, Caspian oil platforms and ships on the horizon, a
## boulevard-style triple-globe lamp, small Azerbaijani flag poles and
## Azerbaijani street signs. Origin at ground (or water) level.

static var _meshes := {}
static var _mats := {}


static func _mat(id: String) -> Material:
	if _mats.has(id):
		return _mats[id]
	var m: Material
	match id:
		"tv_white": m = ShapeKit.mat(Color("eef0f2"), 0.45)
		"tv_red": m = ShapeKit.mat(Color("d8342c"), 0.5)
		"tv_glass": m = ShapeKit.mat(Color("27527a"), 0.08, 0.7)
		"steel": m = ShapeKit.mat(Color("6c7480"), 0.5, 0.6)
		"rust": m = ShapeKit.mat(Color("8a5a3c"), 0.8)
		"flare":
			var f := ShapeKit.mat(Color("ffb347"), 0.5, 0.0, 3.0)
			f.emission = Color("ff9a2e")
			m = f
		"hull": m = ShapeKit.mat(Color("2b3a55"), 0.6)
		"hull_red": m = ShapeKit.mat(Color("9e2b2b"), 0.6)
		"deck_white": m = ShapeKit.mat(Color("f2f2ee"), 0.6)
		"crystal": m = LandmarkKit.glass(30.0, true)
		"crystal_frame": m = ShapeKit.mat(Color("c9d3dc"), 0.3, 0.7)
		"iron": m = ShapeKit.mat(Color("1f2a2a"), 0.45, 0.6)
		"globe":
			var g := ShapeKit.mat(Color("fff6dc"), 0.25, 0.0, 0.8)
			g.emission = Color("ffe2a0")
			m = g
		"sign_blue": m = ShapeKit.mat(Color("1d5fae"), 0.5)
	_mats[id] = m
	return m


static func get_mesh(id: String) -> ArrayMesh:
	if _meshes.has(id):
		return _meshes[id]
	var a := PropKit.Accum.new()
	match id:
		"tv_tower": _tv_tower(a)
		"crystal_hall": _crystal_hall(a)
		"oil_platform": _oil_platform(a)
		"ship": _ship(a)
		"lamp_baku": _lamp_baku(a)
		"flag_pole": _flag_pole(a)
		"street_sign": _street_sign(a)
	var mesh := a.commit()
	_meshes[id] = mesh
	return mesh


static func T(p: Vector3, r := Vector3.ZERO, s := Vector3.ONE) -> Transform3D:
	return PropKit.T(p, r, s)


## Baku TV Tower (Teleqüllə): tapered white shaft, the restaurant pod
## two thirds up, then a red/white banded antenna. ~160 m.
static func _tv_tower(a: PropKit.Accum) -> void:
	a.add(ShapeKit.cone(9.0, 6.0, 8.0, 12), T(Vector3(0, 4, 0)), _mat("tv_white"))
	a.add(ShapeKit.cone(5.2, 2.6, 100.0, 12), T(Vector3(0, 58, 0)), _mat("tv_white"))
	# Pod: lower ring, glass band, upper ring.
	a.add(ShapeKit.cone(3.0, 9.5, 5.0, 16), T(Vector3(0, 104, 0)), _mat("tv_white"))
	a.add(ShapeKit.cylinder(9.0, 4.5, 16), T(Vector3(0, 108.7, 0)), _mat("tv_glass"))
	a.add(ShapeKit.cone(9.8, 4.0, 4.0, 16), T(Vector3(0, 113, 0)), _mat("tv_white"))
	a.add(ShapeKit.cylinder(2.2, 8.0, 10), T(Vector3(0, 119, 0)), _mat("tv_white"))
	for i in 8:
		a.add(ShapeKit.cone(1.4 - i * 0.12, 1.3 - i * 0.12, 5.0, 8), T(Vector3(0, 125.5 + i * 5.0, 0)), _mat("tv_red" if i % 2 == 0 else "tv_white"))


## Crystal Hall: a faceted ring of tilted glass panels on a low podium.
static func _crystal_hall(a: PropKit.Accum) -> void:
	a.add(ShapeKit.cylinder(44.0, 3.0, 24), T(Vector3(0, 1.5, 0)), PropKit.m("concrete"))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 18
	var r0 := 38.0
	var r1 := 30.0
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var h0 := 20.0 + 5.0 * float(i % 3)
		var h1 := 20.0 + 5.0 * float((i + 1) % 3)
		var b0 := Vector3(cos(a0) * r0, 3, sin(a0) * r0)
		var b1 := Vector3(cos(a1) * r0, 3, sin(a1) * r0)
		var t0 := Vector3(cos(a0) * r1, 3 + h0, sin(a0) * r1)
		var t1 := Vector3(cos(a1) * r1, 3 + h1, sin(a1) * r1)
		var mid := (t0 + t1 + b0 + b1) * 0.25 + Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5)) * 2.5
		for tri in [[b0, mid, b1], [b0, t0, mid], [t0, t1, mid], [b1, mid, t1]]:
			var nrm: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
			for v in tri:
				st.set_normal(nrm)
				st.set_uv(Vector2(v.x * 0.05, v.y * 0.05))
				st.add_vertex(v)
		# Roof fan to the centre.
		var c := Vector3(0, 3 + 22.0, 0)
		var nr: Vector3 = (t1 - t0).cross(c - t0).normalized()
		if nr.y < 0:
			nr = -nr
		for v in [t0, c, t1]:
			st.set_normal(nr)
			st.set_uv(Vector2(v.x * 0.05, v.z * 0.05))
			st.add_vertex(v)
	st.set_material(_mat("crystal"))
	var m := st.commit()
	a.add(m, Transform3D.IDENTITY, _mat("crystal"))
	for i in n:
		var ang := TAU * i / n
		var top := 23.0 + 5.0 * float(i % 3)
		a.add(PropKit.box(Vector3(0.6, top, 0.6)), Transform3D(Basis(Vector3.UP, -ang).rotated(Vector3(-sin(ang), 0, cos(ang)), -0.2), Vector3(cos(ang) * 34.5, 3 + top * 0.5, sin(ang) * 34.5)), _mat("crystal_frame"))


## Caspian oil platform silhouette (Neft Daşları style).
static func _oil_platform(a: PropKit.Accum) -> void:
	for x in [-9.0, 9.0]:
		for z in [-7.0, 7.0]:
			a.add(ShapeKit.cylinder(1.1, 16.0, 8), T(Vector3(x, 6, z)), _mat("rust"))
	a.add(PropKit.box(Vector3(24, 2.0, 18)), T(Vector3(0, 14, 0)), _mat("steel"))
	a.add(PropKit.box(Vector3(10, 6, 8)), T(Vector3(-5, 18, -3)), _mat("deck_white"))
	a.add(ShapeKit.cone(4.5, 0.6, 26.0, 4), T(Vector3(5, 28, 2)), _mat("steel"))
	a.add(PropKit.box(Vector3(0.8, 0.8, 18)), Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(-8, 24, 4)), _mat("tv_red"))
	a.add(ShapeKit.cylinder(0.5, 14.0, 6), Transform3D(Basis(Vector3.FORWARD, -0.5), Vector3(14, 19, 0)), _mat("steel"))
	a.add(ShapeKit.sphere(1.3, 8, 5), T(Vector3(17.5, 25.5, 0)), _mat("flare"))


static func _ship(a: PropKit.Accum) -> void:
	a.add(PropKit.box(Vector3(9, 4, 52)), T(Vector3(0, 1, 0)), _mat("hull"))
	a.add(ShapeKit.cone(4.5, 0.2, 9.0, 4), Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, PI * 0.25), Vector3(0, 1, 30)), _mat("hull"))
	a.add(PropKit.box(Vector3(9.2, 1.0, 52)), T(Vector3(0, -0.6, 0)), _mat("hull_red"))
	a.add(PropKit.box(Vector3(8, 7, 8)), T(Vector3(0, 6.5, -18)), _mat("deck_white"))
	a.add(ShapeKit.cylinder(1.4, 5.0, 8), T(Vector3(0, 11.5, -21)), _mat("tv_red"))
	for i in 4:
		a.add(PropKit.box(Vector3(7, 3, 6)), T(Vector3(0, 4.5, -6 + i * 7)), PropKit.m(["orange", "blue", "turquoise", "red"][i]))


## Boulevard lamp: dark cast-iron column on a fluted base, scrolled arms
## and three warm globes (Dənizkənarı bulvar style).
static func _lamp_baku(a: PropKit.Accum) -> void:
	a.add(ShapeKit.cylinder(0.32, 0.5, 8), T(Vector3(0, 0.25, 0)), _mat("iron"))
	a.add(ShapeKit.cone(0.24, 0.12, 1.2, 8), T(Vector3(0, 1.1, 0)), _mat("iron"))
	a.add(ShapeKit.cylinder(0.09, 3.6, 8), T(Vector3(0, 3.4, 0)), _mat("iron"))
	a.add(ShapeKit.torus(0.08, 0.16, 10, 6), T(Vector3(0, 1.75, 0), Vector3(PI * 0.5, 0, 0)), PropKit.m("gold"))
	for i in 2:
		var x := -0.6 if i == 0 else 0.6
		a.add(PropKit.box(Vector3(1.2, 0.07, 0.07)), T(Vector3(x * 0.5, 4.9, 0)), _mat("iron"))
		a.add(ShapeKit.torus(0.16, 0.24, 10, 6), T(Vector3(x * 0.6, 4.65, 0), Vector3(PI * 0.5, 0, 0)), _mat("iron"))
		a.add(ShapeKit.sphere(0.26, 10, 6), T(Vector3(x, 4.65, 0)), _mat("globe"))
	a.add(ShapeKit.sphere(0.3, 10, 6), T(Vector3(0, 5.45, 0)), _mat("globe"))
	a.add(ShapeKit.cone(0.1, 0.0, 0.4, 6), T(Vector3(0, 5.9, 0)), PropKit.m("gold"))


static func _flag_pole(a: PropKit.Accum) -> void:
	a.add(ShapeKit.cylinder(0.3, 0.4, 8), T(Vector3(0, 0.2, 0)), PropKit.m("concrete"))
	a.add(ShapeKit.cylinder(0.07, 8.0, 8), T(Vector3(0, 4.0, 0)), PropKit.m("metal_grey"))
	a.add(ShapeKit.sphere(0.13, 8, 5), T(Vector3(0, 8.05, 0)), PropKit.m("gold"))


static func _street_sign(a: PropKit.Accum) -> void:
	a.add(ShapeKit.cylinder(0.06, 3.4, 6), T(Vector3(0, 1.7, 0)), PropKit.m("metal_grey"))
	a.add(PropKit.box(Vector3(2.6, 0.62, 0.06)), T(Vector3(0, 3.1, 0)), _mat("sign_blue"))
