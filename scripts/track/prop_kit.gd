class_name PropKit
extends RefCounted
## Procedural Baku-inspired props, each merged into one ArrayMesh with one
## surface per shared material so they can be MultiMesh-instanced cheaply.
## Origin of every prop is at ground level; "front" faces local +Z.

const LIMESTONE_SHADER := preload("res://assets/materials/limestone.gdshader")
const CARPET_SHADER := preload("res://assets/materials/carpet.gdshader")

static var _meshes := {}
static var _mats := {}


# --- Materials ---------------------------------------------------------------

static func m(id: String) -> Material:
	if _mats.has(id):
		return _mats[id]
	var mat: Material
	match id:
		"limestone":
			var sm := ShaderMaterial.new()
			sm.shader = LIMESTONE_SHADER
			mat = sm
		"limestone_warm":
			var sm2 := ShaderMaterial.new()
			sm2.shader = LIMESTONE_SHADER
			sm2.set_shader_parameter("stone", Color(0.95, 0.80, 0.62))
			mat = sm2
		"palm_leaf":
			var pl := _std(Color("4e9a3a"), 0.75)
			pl.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat = pl
		"palm_leaf_light":
			var pl2 := _std(Color("6fb648"), 0.75)
			pl2.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat = pl2
		"lantern":
			var ln := _std(Color("fff1c4"), 0.3)
			ln.emission_enabled = true
			ln.emission = Color("ffd98a")
			ln.emission_energy_multiplier = 1.2
			mat = ln
		"glass":
			var gl := _std(Color("2f5f86"), 0.08, 0.6)
			mat = gl
		"glass_tower":
			var gt := _std(Color("5d9ed1"), 0.1, 0.75)
			gt.rim_enabled = true
			gt.rim = 0.4
			mat = gt
		"glass_tower_warm":
			var gw := _std(Color("e0a85a"), 0.12, 0.7)
			mat = gw
		"fabric_white":
			var fw := _std(Color("f6f1e6"), 0.9)
			fw.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat = fw
		_:
			var colors := {
				"trunk": [Color("8a6a4a"), 0.9],
				"trunk_dark": [Color("6b4f36"), 0.9],
				"metal_dark": [Color("23413a"), 0.45, 0.6],
				"metal_grey": [Color("8a8f99"), 0.4, 0.7],
				"wood": [Color("7a4a2a"), 0.7],
				"wood_teal": [Color("2f7f78"), 0.6],
				"wood_green": [Color("3f6f3a"), 0.6],
				"plaster_cream": [Color("f2e2c2"), 0.85],
				"plaster_peach": [Color("efc9a0"), 0.85],
				"plaster_white": [Color("f4f1ea"), 0.85],
				"terracotta": [Color("c46a43"), 0.8],
				"red": [Color("e0344b"), 0.6],
				"white": [Color("f7f5ef"), 0.6],
				"gold": [Color("ffc93c"), 0.4, 0.5],
				"blue": [Color("2f74c9"), 0.6],
				"turquoise": [Color("25c2c2"), 0.6],
				"green": [Color("3cb371"), 0.6],
				"orange": [Color("ff8a3d"), 0.6],
				"purple": [Color("7a4fc9"), 0.6],
				"navy": [Color("1b2a4a"), 0.6],
				"tire": [Color("1d1e22"), 0.85],
				"leaf": [Color("5aa34a"), 0.85],
				"leaf_dark": [Color("3f8a3f"), 0.85],
				"concrete": [Color("d8d4cc"), 0.9],
				"stone_dark": [Color("b8a786"), 0.9],
				"water_fountain": [Color("6fd6e0"), 0.1, 0.2],
				"crowd_a": [Color("e0344b"), 0.8],
				"crowd_b": [Color("25c2c2"), 0.8],
				"crowd_c": [Color("ffc93c"), 0.8],
				"crowd_d": [Color("4b5bd6"), 0.8],
				"skin": [Color("e0ac83"), 0.8],
			}
			var def: Array = colors.get(id, [Color.MAGENTA, 0.5])
			mat = _std(def[0], def[1], def[2] if def.size() > 2 else 0.0)
	_mats[id] = mat
	return mat


static func _std(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = rough
	s.metallic = metal
	return s


static func is_plain(mat: Material) -> bool:
	if not (mat is StandardMaterial3D):
		return false
	var sm: StandardMaterial3D = mat
	return sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not sm.emission_enabled 		and sm.albedo_texture == null and sm.cull_mode == BaseMaterial3D.CULL_BACK and sm.metallic < 0.3


static func vcolor_material() -> ShaderMaterial:
	if _mats.has("__vcolor"):
		return _mats["__vcolor"]
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://assets/materials/vcolor.gdshader")
	_mats["__vcolor"] = sm
	return sm


static func carpet_material(variant: int) -> ShaderMaterial:
	var key := "carpet_%d" % variant
	if _mats.has(key):
		return _mats[key]
	var sm := ShaderMaterial.new()
	sm.shader = CARPET_SHADER
	var palettes := [
		[Color(0.62, 0.08, 0.12), Color(0.10, 0.16, 0.36), Color(0.95, 0.78, 0.36)],
		[Color(0.12, 0.2, 0.45), Color(0.6, 0.1, 0.14), Color(0.95, 0.85, 0.6)],
		[Color(0.7, 0.35, 0.1), Color(0.15, 0.3, 0.25), Color(0.95, 0.9, 0.75)],
		[Color(0.18, 0.42, 0.38), Color(0.55, 0.1, 0.15), Color(0.98, 0.8, 0.4)],
	]
	var p: Array = palettes[variant % palettes.size()]
	sm.set_shader_parameter("field", p[0])
	sm.set_shader_parameter("border", p[1])
	sm.set_shader_parameter("motif", p[2])
	sm.set_shader_parameter("seed", float(variant) * 1.7)
	_mats[key] = sm
	return sm


# --- Accumulator -------------------------------------------------------------

class Accum:
	extends RefCounted
	var tools := {} # material -> SurfaceTool
	var order: Array = []

	func add(mesh: Mesh, xform: Transform3D, mat: Material) -> void:
		if mesh == null:
			return
		if not tools.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[mat] = st
			order.append(mat)
		for i in mesh.get_surface_count():
			tools[mat].append_from(mesh, i, xform)

	## Adds an already-built multi-surface mesh, keeping its materials.
	func add_committed(mesh: ArrayMesh, xform: Transform3D) -> void:
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if not tools.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[mat] = st
				order.append(mat)
			tools[mat].append_from(mesh, i, xform)

	func add_builder(mb: MeshBuilder, mat: Material) -> void:
		if mb.is_empty():
			return
		add(mb.commit(), Transform3D.IDENTITY, mat)

	## Plain opaque colours are merged into one vertex-coloured surface
	## (albedo in RGB, roughness in A) so a prop costs as few draws as possible.
	func commit(vcolor_mat: Material = null) -> ArrayMesh:
		var out := ArrayMesh.new()
		var pv := PackedVector3Array()
		var pn := PackedVector3Array()
		var pu := PackedVector2Array()
		var pc := PackedColorArray()
		var pi := PackedInt32Array()
		for mat in order:
			var st: SurfaceTool = tools[mat]
			if PropKit.is_plain(mat):
				var arr := st.commit_to_arrays()
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var base := pv.size()
				var c: Color = mat.albedo_color
				c.a = mat.roughness
				pv.append_array(verts)
				pn.append_array(arr[Mesh.ARRAY_NORMAL])
				var uv = arr[Mesh.ARRAY_TEX_UV]
				if uv == null or (uv as PackedVector2Array).size() != verts.size():
					uv = PackedVector2Array()
					uv.resize(verts.size())
				pu.append_array(uv)
				var cols := PackedColorArray()
				cols.resize(verts.size())
				cols.fill(c)
				pc.append_array(cols)
				var idx = arr[Mesh.ARRAY_INDEX]
				if idx == null or (idx as PackedInt32Array).is_empty():
					for k in verts.size():
						pi.append(base + k)
				else:
					for k in (idx as PackedInt32Array):
						pi.append(base + k)
			else:
				st.commit(out)
				out.surface_set_material(out.get_surface_count() - 1, mat)
		if not pv.is_empty():
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = pv
			arrays[Mesh.ARRAY_NORMAL] = pn
			arrays[Mesh.ARRAY_TEX_UV] = pu
			arrays[Mesh.ARRAY_COLOR] = pc
			arrays[Mesh.ARRAY_INDEX] = pi
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, vcolor_mat if vcolor_mat != null else PropKit.vcolor_material())
		return out


static func T(pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot).scaled(scl)
	return Transform3D(b, pos)


static func box(size: Vector3) -> Mesh:
	var key := "box|%s" % size
	if _meshes.has(key):
		return _meshes[key]
	var b := BoxMesh.new()
	b.size = size
	_meshes[key] = b
	return b


static func rbox(size: Vector3, r: float = 0.3) -> Mesh:
	return ShapeKit.superellipsoid(size, r, r, Vector2.ONE, Vector2.ONE, 4, 8)


# --- Public ------------------------------------------------------------------

static func get_mesh(id: String) -> ArrayMesh:
	if _meshes.has(id):
		return _meshes[id]
	var a := Accum.new()
	match id:
		"palm": _palm(a, 7.5, 0)
		"palm_b": _palm(a, 6.2, 1)
		"lamp": _lamp(a)
		"bench": _bench(a)
		"baluster": _baluster_segment(a)
		"bollard": _bollard(a)
		"tire_stack": _tire_stack(a)
		"chevron_left": _chevron(a, -1.0)
		"chevron_right": _chevron(a, 1.0)
		"tree": _tree(a)
		"cypress": _cypress(a)
		"house_a": _house(a, 0)
		"house_b": _house(a, 1)
		"house_c": _house(a, 2)
		"house_d": _house(a, 3)
		"modern_a": _modern(a, 0)
		"modern_b": _modern(a, 1)
		"modern_c": _modern(a, 2)
		"maiden_tower": _maiden_tower(a)
		"flame_a": _flame_tower(a, 110.0, 0)
		"flame_b": _flame_tower(a, 128.0, 1)
		"flame_c": _flame_tower(a, 96.0, 2)
		"tower_a": _glass_tower(a, 70.0, 0)
		"tower_b": _glass_tower(a, 54.0, 1)
		"tower_c": _glass_tower(a, 84.0, 2)
		"grandstand": _grandstand(a)
		"umbrella": _umbrella(a)
		"boat": _boat(a)
		"banner_pole": _banner_pole(a)
		"fountain": _fountain(a)
		"wheel_frame": _wheel_frame(a)
		"wheel_ring": _wheel_ring(a)
		"kiosk": _kiosk(a)
	var mesh := a.commit()
	_meshes[id] = mesh
	return mesh


# --- Props ---------------------------------------------------------------------

static func _palm(a: Accum, height: float, variant: int) -> void:
	var segs := 7
	var lean := 0.6 + variant * 0.3
	var prev := Vector3.ZERO
	for i in segs:
		var t := float(i + 1) / segs
		var p := Vector3(sin(t * 1.4) * lean, height * t, 0)
		var mid := (prev + p) * 0.5
		var dir := (p - prev).normalized()
		var basis := Basis(Quaternion(Vector3.UP, dir))
		var r := lerpf(0.26, 0.17, t)
		a.add(ShapeKit.cone(r * 1.08, r * 0.92, prev.distance_to(p) + 0.05, 9), Transform3D(basis, mid), m("trunk" if i % 2 == 0 else "trunk_dark"))
		prev = p
	var top := prev
	a.add(ShapeKit.sphere(0.32, 10, 6), T(top), m("trunk_dark"))
	var fronds := 9
	for k in fronds:
		var ang := TAU * k / fronds + variant * 0.3
		var droop := 0.5 + 0.35 * float(k % 3) / 2.0
		a.add_builder(_frond(top, ang, 3.2 + 0.4 * float(k % 2), droop), m("palm_leaf" if k % 2 == 0 else "palm_leaf_light"))
	for k in 4:
		var ang2 := TAU * k / 4.0
		a.add(ShapeKit.sphere(0.13, 8, 5), T(top + Vector3(cos(ang2) * 0.3, -0.35, sin(ang2) * 0.3)), m("trunk_dark"))


static func _frond(origin: Vector3, ang: float, length: float, droop: float) -> MeshBuilder:
	var mb := MeshBuilder.new()
	var dir := Vector3(cos(ang), 0, sin(ang))
	var side := Vector3(-dir.z, 0, dir.x)
	var steps := 7
	var prev_c := origin
	var prev_w := 0.05
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var c := origin + dir * length * t + Vector3.UP * (0.6 * t - droop * 2.2 * t * t)
		var w := sin(t * PI) * 0.55 + 0.04
		var crease := Vector3.UP * 0.12 * w
		var a0 := prev_c - side * prev_w
		var b0 := prev_c + crease * 0.0
		var c0 := prev_c + side * prev_w
		var a1 := c - side * w
		var b1 := c + crease
		var c1 := c + side * w
		mb.quad(a0, b0, b1, a1)
		mb.quad(b0, c0, c1, b1)
		prev_c = c
		prev_w = w
	return mb


static func _lamp(a: Accum) -> void:
	a.add(ShapeKit.cylinder(0.22, 0.5, 10), T(Vector3(0, 0.25, 0)), m("metal_dark"))
	a.add(ShapeKit.cylinder(0.08, 4.6, 8), T(Vector3(0, 2.6, 0)), m("metal_dark"))
	a.add(ShapeKit.sphere(0.12, 8, 5), T(Vector3(0, 4.95, 0)), m("gold"))
	a.add(box(Vector3(1.6, 0.08, 0.08)), T(Vector3(0, 4.6, 0)), m("metal_dark"))
	for x in [-0.75, 0.75]:
		a.add(rbox(Vector3(0.36, 0.5, 0.36), 0.4), T(Vector3(x, 4.25, 0)), m("lantern"))
		a.add(ShapeKit.cone(0.28, 0.05, 0.22, 8), T(Vector3(x, 4.58, 0)), m("metal_dark"))


static func _bench(a: Accum) -> void:
	for z in [-0.18, 0.0, 0.18]:
		a.add(rbox(Vector3(1.8, 0.06, 0.14), 0.3), T(Vector3(0, 0.46, z)), m("wood"))
	a.add(rbox(Vector3(1.8, 0.3, 0.06), 0.3), T(Vector3(0, 0.75, 0.3), Vector3(-0.2, 0, 0)), m("wood"))
	for x in [-0.75, 0.75]:
		a.add(box(Vector3(0.08, 0.46, 0.5)), T(Vector3(x, 0.23, 0.05)), m("metal_dark"))


## 2 m seaside balustrade segment, front = +Z (towards the sea).
static func _baluster_segment(a: Accum) -> void:
	a.add(rbox(Vector3(2.0, 0.16, 0.36), 0.3), T(Vector3(0, 0.08, 0)), m("limestone"))
	a.add(rbox(Vector3(2.04, 0.12, 0.32), 0.4), T(Vector3(0, 0.98, 0)), m("plaster_white"))
	for i in 5:
		var x := -0.8 + i * 0.4
		a.add(ShapeKit.cone(0.07, 0.05, 0.74, 6), T(Vector3(x, 0.54, 0)), m("plaster_white"))
	a.add(rbox(Vector3(0.28, 1.1, 0.34), 0.2), T(Vector3(1.0, 0.55, 0)), m("limestone"))


static func _bollard(a: Accum) -> void:
	a.add(ShapeKit.superellipsoid(Vector3(0.3, 0.8, 0.3), 0.6, 1.0), T(Vector3(0, 0.4, 0)), m("metal_dark"))
	a.add(ShapeKit.cylinder(0.16, 0.06, 10), T(Vector3(0, 0.62, 0)), m("gold"))


static func _tire_stack(a: Accum) -> void:
	for i in 4:
		a.add(ShapeKit.torus(0.2, 0.45, 14, 8), T(Vector3(0, 0.13 + i * 0.25, 0)), m("tire"))
		a.add(ShapeKit.torus(0.38, 0.46, 14, 4), T(Vector3(0, 0.13 + i * 0.25, 0), Vector3.ZERO, Vector3(1.0, 0.6, 1.0)), m("red" if i % 2 == 0 else "white"))


## Corner direction sign: board faces +Z, arrows point to `dir` (local X).
static func _chevron(a: Accum, dir: float) -> void:
	for x in [-0.9, 0.9]:
		a.add(ShapeKit.cylinder(0.06, 1.6, 8), T(Vector3(x, 0.8, -0.05)), m("metal_grey"))
	a.add(rbox(Vector3(2.4, 0.9, 0.08), 0.2), T(Vector3(0, 1.55, 0)), m("red"))
	var mb := MeshBuilder.new()
	for k in 3:
		var cx := (-0.65 + k * 0.65) * dir
		var w := 0.16
		var h := 0.3
		var tip := Vector3(cx + dir * 0.22, 1.55, 0.045)
		var top := Vector3(cx - dir * 0.08, 1.55 + h, 0.045)
		var bot := Vector3(cx - dir * 0.08, 1.55 - h, 0.045)
		mb.quad_facing(top, top + Vector3(w * dir, 0, 0), tip + Vector3(w * dir, 0, 0), tip, Vector3.BACK)
		mb.quad_facing(tip, tip + Vector3(w * dir, 0, 0), bot + Vector3(w * dir, 0, 0), bot, Vector3.BACK)
	a.add_builder(mb, m("white"))


static func _tree(a: Accum) -> void:
	a.add(ShapeKit.cone(0.22, 0.16, 2.6, 8), T(Vector3(0, 1.3, 0)), m("trunk"))
	a.add(ShapeKit.superellipsoid(Vector3(3.2, 2.6, 3.2), 0.9, 0.9, Vector2.ONE, Vector2.ONE, 6, 10), T(Vector3(0, 3.4, 0)), m("leaf"))
	a.add(ShapeKit.superellipsoid(Vector3(2.2, 1.9, 2.2), 0.9, 0.9, Vector2.ONE, Vector2.ONE, 6, 10), T(Vector3(0.7, 4.3, 0.4)), m("leaf_dark"))


static func _cypress(a: Accum) -> void:
	a.add(ShapeKit.cylinder(0.12, 0.8, 6), T(Vector3(0, 0.4, 0)), m("trunk"))
	a.add(ShapeKit.superellipsoid(Vector3(1.3, 6.0, 1.3), 1.2, 1.0, Vector2.ONE, Vector2.ONE, 6, 8), T(Vector3(0, 3.6, 0)), m("leaf_dark"))


## Old City house, front facade at +Z. Width ~9 m, depth 8 m.
static func _house(a: Accum, v: int) -> void:
	var w: float = [9.0, 8.0, 10.0, 7.5][v]
	var h: float = [8.5, 10.5, 7.2, 11.5][v]
	var d := 8.0
	var stone := "limestone" if v % 2 == 0 else "limestone_warm"
	a.add(box(Vector3(w, h, d)), T(Vector3(0, h * 0.5, 0)), m(stone))
	# Cornice and parapet
	a.add(rbox(Vector3(w + 0.3, 0.3, d + 0.3), 0.3), T(Vector3(0, h + 0.05, 0)), m("plaster_cream"))
	a.add(box(Vector3(w, 0.6, 0.25)), T(Vector3(0, h + 0.45, d * 0.5 - 0.12)), m(stone))
	# Ground floor: arched doorway + shop window
	var fz := d * 0.5 + 0.02
	_arch_opening(a, Vector3(-w * 0.25, 0, fz), 1.5, 2.6, m("wood"))
	_arch_opening(a, Vector3(w * 0.22, 0.6, fz), 1.8, 1.9, m("glass"))
	# Upper floors: arched windows
	var floors := int((h - 3.6) / 3.0) + 1
	for f in floors:
		var y := 3.8 + f * 3.0
		if y + 2.0 > h:
			break
		var count := int(w / 2.6)
		for i in count:
			var x := -w * 0.5 + (i + 0.5) * (w / count)
			if f == 0 and v != 2 and i >= count / 2 - 1 and i <= count / 2:
				continue # leave room for the balcony
			_arch_opening(a, Vector3(x, y, fz), 1.0, 1.7, m("glass"))
			a.add(box(Vector3(1.3, 0.12, 0.3)), T(Vector3(x, y - 0.06, fz + 0.1)), m("plaster_cream"))
	# Enclosed wooden balcony (şüşəbənd) on the first upper floor.
	if v != 2:
		var bw := minf(w * 0.5, 4.6)
		var by := 3.5
		var wood := "wood_teal" if v % 2 == 0 else "wood"
		a.add(box(Vector3(bw, 0.25, 1.1)), T(Vector3(0, by, fz + 0.55)), m(wood))
		a.add(box(Vector3(bw, 0.9, 1.0)), T(Vector3(0, by + 0.55, fz + 0.55)), m(wood))
		a.add(box(Vector3(bw - 0.1, 1.2, 0.9)), T(Vector3(0, by + 1.6, fz + 0.5)), m("glass"))
		var mullions := int(bw / 0.7)
		for k in mullions + 1:
			var mx := -bw * 0.5 + k * (bw / mullions)
			a.add(box(Vector3(0.09, 1.25, 0.12)), T(Vector3(mx, by + 1.6, fz + 0.97)), m(wood))
		a.add(box(Vector3(bw + 0.2, 0.22, 1.2)), T(Vector3(0, by + 2.3, fz + 0.55)), m(wood))
		a.add(box(Vector3(bw + 0.4, 0.12, 1.4)), T(Vector3(0, by + 2.45, fz + 0.6)), m("terracotta"))
	# Rooftop details
	if v == 1 or v == 3:
		a.add(ShapeKit.superellipsoid(Vector3(2.6, 2.0, 2.6), 0.8, 1.0), T(Vector3(w * 0.2, h + 0.9, -1.0)), m("plaster_cream"))
		a.add(ShapeKit.cylinder(1.4, 0.4, 14), T(Vector3(w * 0.2, h + 0.2, -1.0)), m(stone))
	else:
		a.add(box(Vector3(1.2, 1.0, 1.2)), T(Vector3(-w * 0.3, h + 0.5, -2.0)), m("plaster_white"))


static func _arch_opening(a: Accum, base: Vector3, w: float, h: float, fill: Material) -> void:
	# Recessed panel with a rounded top and a stone surround.
	a.add(box(Vector3(w, h - w * 0.5, 0.12)), T(base + Vector3(0, (h - w * 0.5) * 0.5, 0)), fill)
	a.add(ShapeKit.cylinder(w * 0.5, 0.12, 8), T(base + Vector3(0, h - w * 0.5, 0), Vector3(PI * 0.5, 0, 0)), fill)
	a.add(ShapeKit.torus(w * 0.5, w * 0.5 + 0.16, 8, 3), T(base + Vector3(0, h - w * 0.5, 0.04), Vector3(PI * 0.5, 0, 0), Vector3(1, 0.5, 1)), m("plaster_cream"))


## Modern inland block (boulevard side), front +Z.
static func _modern(a: Accum, v: int) -> void:
	var w: float = [16.0, 12.0, 20.0][v]
	var h: float = [18.0, 26.0, 14.0][v]
	var d := 12.0
	var body: String = ["plaster_cream", "plaster_peach", "plaster_white"][v]
	a.add(box(Vector3(w, h, d)), T(Vector3(0, h * 0.5, 0)), m(body))
	var floors := int(h / 3.2)
	for f in range(1, floors):
		a.add(box(Vector3(w * 0.92, 1.5, 0.1)), T(Vector3(0, f * 3.2 + 0.6, d * 0.5 + 0.03)), m("glass"))
		a.add(box(Vector3(w + 0.2, 0.18, 0.6)), T(Vector3(0, f * 3.2 - 0.25, d * 0.5 + 0.2)), m("plaster_white"))
	a.add(box(Vector3(w + 0.4, 0.4, d + 0.4)), T(Vector3(0, h + 0.2, 0)), m("stone_dark"))
	a.add(box(Vector3(w * 0.6, 0.9, 0.2)), T(Vector3(0, 1.0, d * 0.5 + 0.05)), m(["red", "turquoise", "orange"][v]))


static func _maiden_tower(a: Accum) -> void:
	var r := 7.5
	var h := 27.0
	a.add(ShapeKit.cone(r * 1.04, r * 0.96, h, 32), T(Vector3(0, h * 0.5, 0)), m("limestone_warm"))
	# Buttress on the east side
	a.add(ShapeKit.superellipsoid(Vector3(6.0, h * 0.92, 9.0), 0.2, 0.6, Vector2(0.9, 1.0), Vector2(1.0, 1.0)), T(Vector3(r * 0.9, h * 0.46, 0)), m("limestone_warm"))
	# Stepped crown and crenellations
	a.add(ShapeKit.cylinder(r * 1.05, 0.6, 32), T(Vector3(0, h + 0.3, 0)), m("limestone"))
	for i in 20:
		var ang := TAU * i / 20.0
		a.add(box(Vector3(1.2, 1.1, 0.8)), T(Vector3(cos(ang) * r * 0.98, h + 1.15, sin(ang) * r * 0.98), Vector3(0, -ang, 0)), m("limestone"))
	# Narrow slit windows
	for k in 4:
		var ang2 := TAU * k / 4.0 + 0.4
		for f in 3:
			a.add(box(Vector3(0.5, 1.6, 0.3)), T(Vector3(cos(ang2) * r, 7.0 + f * 6.0, sin(ang2) * r), Vector3(0, -ang2 + PI * 0.5, 0)), m("navy"))
	# Flag on top
	a.add(ShapeKit.cylinder(0.08, 5.0, 6), T(Vector3(0, h + 3.5, 0)), m("metal_grey"))
	a.add(box(Vector3(2.0, 1.2, 0.05)), T(Vector3(1.0, h + 5.2, 0)), m("turquoise"))


static func _flame_tower(a: Accum, height: float, v: int) -> void:
	# A tall glass tower whose top curves into a flame-like point.
	var mesh := ShapeKit.superellipsoid(Vector3(26.0, 22.0, height), 0.55, 0.7, Vector2(0.18, 0.3), Vector2(1.0, 1.0), 14, 22, 9.0 + v * 2.0)
	# Built along Z with the taper at -Z; +90° about X turns -Z into +Y (top).
	a.add(mesh, T(Vector3(0, height * 0.5 - 2.0, 0), Vector3(PI * 0.5, 0, 0)), m("glass_tower" if v != 1 else "glass_tower_warm"))
	a.add(ShapeKit.cylinder(13.5, 4.0, 20), T(Vector3(0, 1.0, 0)), m("stone_dark"))


static func _glass_tower(a: Accum, height: float, v: int) -> void:
	var w: float = [18.0, 22.0, 16.0][v]
	a.add(rbox(Vector3(w, height, w * 0.8), 0.25), T(Vector3(0, height * 0.5, 0)), m("glass_tower"))
	a.add(rbox(Vector3(w * 0.7, 6.0, w * 0.55), 0.3), T(Vector3(0, height + 3.0, 0)), m("plaster_white"))
	if v == 2:
		a.add(ShapeKit.cone(w * 0.3, 0.3, 12.0, 12), T(Vector3(0, height + 12.0, 0)), m("metal_grey"))


static func _grandstand(a: Accum) -> void:
	var w := 30.0
	for i in 5:
		a.add(box(Vector3(w, 0.6, 1.4)), T(Vector3(0, 0.3 + i * 0.6, -i * 1.3)), m("concrete"))
		# Crowd: rows of seated spectators as rounded blobs.
		for k in 18:
			var x := -w * 0.5 + 1.0 + k * (w - 2.0) / 17.0 + (0.3 if i % 2 == 0 else 0.0)
			var crowd: String = ["crowd_a", "crowd_b", "crowd_c", "crowd_d"][(k * 7 + i * 3) % 4]
			a.add(ShapeKit.superellipsoid(Vector3(0.6, 0.8, 0.5), 0.6, 0.6, Vector2.ONE, Vector2.ONE, 3, 6), T(Vector3(x, 0.95 + i * 0.6, -i * 1.3 - 0.1)), m(crowd))
			a.add(ShapeKit.sphere(0.2, 6, 4), T(Vector3(x, 1.5 + i * 0.6, -i * 1.3 - 0.1)), m("skin"))
	for x in [-w * 0.5, 0.0, w * 0.5]:
		a.add(ShapeKit.cylinder(0.15, 6.5, 8), T(Vector3(x, 3.25, -6.0)), m("metal_grey"))
	a.add(rbox(Vector3(w + 2.0, 0.3, 8.0), 0.3), T(Vector3(0, 6.6, -3.0), Vector3(0.12, 0, 0)), m("red"))


static func _umbrella(a: Accum) -> void:
	a.add(ShapeKit.cylinder(0.05, 2.4, 6), T(Vector3(0, 1.2, 0)), m("wood"))
	a.add(ShapeKit.cone(1.6, 0.08, 0.6, 12), T(Vector3(0, 2.5, 0)), m("fabric_white"))
	a.add(ShapeKit.cylinder(0.5, 0.05, 12), T(Vector3(0, 0.75, 0)), m("white"))
	a.add(ShapeKit.cylinder(0.05, 0.75, 6), T(Vector3(0, 0.37, 0)), m("metal_dark"))


static func _boat(a: Accum) -> void:
	a.add(ShapeKit.superellipsoid(Vector3(2.4, 1.0, 7.0), 0.4, 0.7, Vector2(0.2, 0.8), Vector2(1.0, 1.0)), T(Vector3(0, 0.3, 0)), m("white"))
	a.add(rbox(Vector3(1.6, 0.9, 2.4), 0.3), T(Vector3(0, 1.1, 0.8)), m("plaster_white"))
	a.add(box(Vector3(1.5, 0.3, 2.2)), T(Vector3(0, 1.2, 0.8)), m("glass"))
	a.add(box(Vector3(2.45, 0.18, 6.0)), T(Vector3(0, 0.55, 0.3)), m("blue"))


static func _banner_pole(a: Accum) -> void:
	a.add(ShapeKit.cylinder(0.07, 6.0, 8), T(Vector3(0, 3.0, 0)), m("metal_grey"))
	a.add(box(Vector3(0.05, 2.8, 1.1)), T(Vector3(0, 4.2, 0.6)), m("fabric_white"))
	a.add(box(Vector3(0.06, 0.6, 1.1)), T(Vector3(0, 5.35, 0.6)), m("red"))
	a.add(box(Vector3(0.06, 0.4, 1.1)), T(Vector3(0, 3.0, 0.6)), m("turquoise"))


static func _fountain(a: Accum) -> void:
	a.add(ShapeKit.cylinder(3.0, 0.6, 24), T(Vector3(0, 0.3, 0)), m("limestone"))
	a.add(ShapeKit.cylinder(2.7, 0.1, 24), T(Vector3(0, 0.58, 0)), m("water_fountain"))
	a.add(ShapeKit.cylinder(0.5, 1.8, 12), T(Vector3(0, 1.2, 0)), m("limestone"))
	a.add(ShapeKit.cylinder(1.3, 0.25, 16), T(Vector3(0, 2.1, 0)), m("limestone"))
	a.add(ShapeKit.cone(0.4, 0.05, 1.4, 10), T(Vector3(0, 2.9, 0)), m("water_fountain"))


static func _wheel_frame(a: Accum) -> void:
	# A-frame supports for the observation wheel (wheel hub at 34 m).
	for z in [-3.0, 3.0]:
		for x in [-9.0, 9.0]:
			var top := Vector3(0, 34.0, z * 0.5)
			var bot := Vector3(x, 0.0, z)
			var mid := (top + bot) * 0.5
			var dir := (top - bot).normalized()
			a.add(ShapeKit.cylinder(0.45, top.distance_to(bot), 8), Transform3D(Basis(Quaternion(Vector3.UP, dir)), mid), m("white"))
	a.add(ShapeKit.cylinder(1.0, 4.5, 12), T(Vector3(0, 34.0, 0), Vector3(PI * 0.5, 0, 0)), m("metal_grey"))
	a.add(rbox(Vector3(14.0, 3.0, 8.0), 0.3), T(Vector3(0, 1.5, 0)), m("plaster_white"))


static func _wheel_ring(a: Accum) -> void:
	# Ring centred at origin in the XY plane (rotates around Z).
	var r := 30.0
	a.add(ShapeKit.torus(r - 0.5, r + 0.5, 64, 6), T(Vector3.ZERO, Vector3(PI * 0.5, 0, 0)), m("white"))
	a.add(ShapeKit.torus(r - 3.5, r - 2.7, 64, 6), T(Vector3.ZERO, Vector3(PI * 0.5, 0, 0)), m("white"))
	for i in 16:
		var ang := TAU * i / 16.0
		var p := Vector3(cos(ang), sin(ang), 0) * (r * 0.5)
		a.add(ShapeKit.cylinder(0.12, r, 6), T(p, Vector3(0, 0, ang - PI * 0.5)), m("metal_grey"))
	for i in 24:
		var ang2 := TAU * i / 24.0
		var p2 := Vector3(cos(ang2), sin(ang2), 0) * (r + 1.2)
		var col: String = ["red", "turquoise", "gold", "orange"][i % 4]
		a.add(ShapeKit.superellipsoid(Vector3(1.8, 2.0, 1.8), 0.7, 0.8), T(p2), m(col))


static func _kiosk(a: Accum) -> void:
	a.add(rbox(Vector3(3.0, 2.6, 2.4), 0.25), T(Vector3(0, 1.3, 0)), m("plaster_white"))
	a.add(box(Vector3(2.4, 1.0, 0.1)), T(Vector3(0, 1.5, 1.22)), m("glass"))
	a.add(ShapeKit.superellipsoid(Vector3(3.6, 0.6, 3.0), 0.5, 0.4), T(Vector3(0, 2.8, 0.2)), m("red"))
	a.add(box(Vector3(3.4, 0.3, 0.12)), T(Vector3(0, 2.45, 1.4)), m("white"))
