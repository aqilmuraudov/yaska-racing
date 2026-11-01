class_name TrackBuilder
extends Node3D
## Generates road, kerbs, off-road strips, barriers, collision, terrain and
## water from TrackData. Collision is always built from the same path data
## as the visuals and never depends on graphics quality.

const ROAD_SHADER := preload("res://assets/materials/road.gdshader")
const CURB_SHADER := preload("res://assets/materials/curb.gdshader")
const GROUND_SHADER := preload("res://assets/materials/ground.gdshader")
const WATER_SHADER := preload("res://assets/materials/water.gdshader")

const CURB_WIDTH := 0.9
const CURB_CURVATURE := 0.010 ## |rad/m| above which kerbs are placed
const WALL_HEIGHT_COLLISION := 6.0
const WALL_COLLISION_THICKNESS := 2.0
const WALL_SEAM_OVERLAP := 0.35
const WALL_FACE_INSET := 0.3
const OFFROAD_DROP := 0.04

# Palette (warm, readable)
const C_SAND := Color("d9c393")
const C_GRASS := Color("74b85a")
const C_GRASS_DARK := Color("5f9c4c")
const C_PAVING := Color("e4d6b8")
const C_COBBLE_OFF := Color("b49f80")
const C_LIMESTONE := Color("ead9b5")
const C_CONCRETE := Color("d8d4cc")
const C_STRIPE_RED := Color("d9343f")
const C_STRIPE_BLUE := Color("2f74c9")
const C_SEABED := Color("6d8f86")
const C_CITY_SIDEWALK := Color("b9b4ac") ## 0.11.0 downtown kerbside paving
const C_CITY_PLAZA := Color("d6cfc2")
const C_CITY_PARK := Color("6fb35a")

var data: TrackData
var road_body: StaticBody3D
var wall_body: StaticBody3D
var boost_pad_areas: Array[Area3D] = []
## Barrier line segments for decor: {a, b, out, theme, path, side, s}
var wall_segments: Array[Dictionary] = []
var materials := {}
## Visual-only nodes that graphics presets may hide or cull.
var decor_root: Node3D


func build(td: TrackData) -> void:
	for step in build_steps(td):
		step.call()


## The build as separate steps (see TrackDecor.build_steps).
func build_steps(td: TrackData) -> Array[Callable]:
	return [
		func(): _begin(td),
		_build_surfaces,
		_build_walls,
		_build_details,
		_build_terrain,
		_build_water,
	]


func _begin(td: TrackData) -> void:
	data = td
	for c in get_children():
		c.queue_free()
	_make_materials()
	decor_root = Node3D.new()
	decor_root.name = "Decor"
	add_child(decor_root)


func _build_details() -> void:
	_build_ramps()
	_build_boost_pads()
	_build_finish_line()


func _make_materials() -> void:
	var road := ShaderMaterial.new()
	road.shader = ROAD_SHADER
	TextureLibrary.bind(road, "asphalt_tex", "road")
	TextureLibrary.bind(road, "cobble_tex", "cobbles")
	materials.road = road
	var curb := ShaderMaterial.new()
	curb.shader = CURB_SHADER
	materials.curb = curb
	var ground := ShaderMaterial.new()
	ground.shader = GROUND_SHADER
	TextureLibrary.bind(ground, "grass_tex", "grass")
	TextureLibrary.bind(ground, "paving_tex", "paving")
	materials.ground = ground
	var water := ShaderMaterial.new()
	water.shader = WATER_SHADER
	materials.water = water
	var wall := StandardMaterial3D.new()
	wall.vertex_color_use_as_albedo = true
	wall.vertex_color_is_srgb = true
	wall.roughness = 0.85
	materials.wall = wall
	var stone := ShaderMaterial.new()
	stone.shader = preload("res://assets/materials/limestone.gdshader")
	TextureLibrary.bind(stone, "stone_tex", "limestone")
	materials.stone = stone
	var pad := StandardMaterial3D.new()
	pad.vertex_color_use_as_albedo = true
	pad.vertex_color_is_srgb = true
	pad.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materials.pad = pad


# --- Surfaces -----------------------------------------------------------------

func _all_paths() -> Array:
	var list: Array = [{"path": data.main, "surface": &"road", "index": -1}]
	for i in data.shortcuts.size():
		list.append({"path": data.shortcuts[i].path, "surface": data.shortcuts[i].surface, "index": i})
	return list


func _build_surfaces() -> void:
	road_body = _static_body("RoadBody", &"road")
	var offroad_body := _static_body("OffroadBody", &"offroad")
	var rough_body := _static_body("RoughBody", &"rough")
	var road_mb := MeshBuilder.new(true, true)
	var rough_mb := MeshBuilder.new(true, true)
	var curb_mb := MeshBuilder.new(true)
	var off_mb := MeshBuilder.new(true, true)
	for entry in _all_paths():
		var path: TrackPath = entry.path
		var is_main: bool = entry.index < 0
		var y_bias := 0.0 if is_main else -0.025
		var target_mb: MeshBuilder = road_mb if entry.surface == &"road" else rough_mb
		var count := path.sample_count()
		var seg_count := count if path.closed else count - 1
		for i in seg_count:
			var j := (i + 1) % count
			var s0 := path.cum[i]
			var s1 := s0 + path.points[i].distance_to(path.points[j])
			var p0 := path.points[i] + Vector3.UP * y_bias
			var p1 := path.points[j] + Vector3.UP * y_bias
			var r0 := path.right_at(path.cum[i])
			var r1 := path.right_at(path.cum[j])
			var hw0 := path.half_widths[i]
			var hw1 := path.half_widths[j]
			var t0 := path.tangent_at(path.cum[i])
			var t1 := path.tangent_at(path.cum[j])
			var n0 := r0.cross(t0).normalized()
			var n1 := r1.cross(t1).normalized()
			var cob0 := 1.0 if path.themes[i] == TrackData.THEME_OLDCITY else 0.0
			var cob1 := 1.0 if path.themes[j] == TrackData.THEME_OLDCITY else 0.0
			var col := Color(maxf(cob0, cob1) if cob0 != cob1 else cob0, 0, 0)
			# Road ribbon (two strips so the crown can be lit smoothly).
			var l0 := p0 - r0 * hw0
			var rr0 := p0 + r0 * hw0
			var l1 := p1 - r1 * hw1
			var rr1 := p1 + r1 * hw1
			target_mb.quad_n(l0, p0, p1, l1, n0, n0, n1, n1,
				Vector2(0, s0), Vector2(0.5, s0), Vector2(0.5, s1), Vector2(0, s1), col,
				Vector2(-hw0, hw0), Vector2(0, hw0), Vector2(0, hw1), Vector2(-hw1, hw1))
			target_mb.quad_n(p0, rr0, rr1, p1, n0, n0, n1, n1,
				Vector2(0.5, s0), Vector2(1, s0), Vector2(1, s1), Vector2(0.5, s1), col,
				Vector2(0, hw0), Vector2(hw0, hw0), Vector2(hw1, hw1), Vector2(0, hw1))
			# Kerbs on corners (main route only).
			var curv := path.curvature_at(s0)
			var curb_here := is_main and absf(curv) > CURB_CURVATURE
			var off_start0 := hw0
			var off_start1 := hw1
			if curb_here:
				for side: float in [-1.0, 1.0]:
					var a := p0 + r0 * side * hw0 + Vector3.UP * 0.03
					var b := p0 + r0 * side * (hw0 + CURB_WIDTH) + Vector3.UP * 0.015
					var c := p1 + r1 * side * (hw1 + CURB_WIDTH) + Vector3.UP * 0.015
					var d := p1 + r1 * side * hw1 + Vector3.UP * 0.03
					if side > 0:
						curb_mb.quad(a, b, c, d, Vector2(0, s0), Vector2(1, s0), Vector2(1, s1), Vector2(0, s1))
					else:
						curb_mb.quad(b, a, d, c, Vector2(1, s0), Vector2(0, s0), Vector2(0, s1), Vector2(1, s1))
				off_start0 += CURB_WIDTH
				off_start1 += CURB_WIDTH
			# Off-road strips out to the barrier.
			var ow := data.offroad_width if is_main else 1.2
			for side: float in [-1.0, 1.0]:
				var a := p0 + r0 * side * (hw0 if not curb_here else off_start0) + Vector3.DOWN * OFFROAD_DROP
				var b := p0 + r0 * side * (hw0 + ow + 0.6) + Vector3.DOWN * OFFROAD_DROP
				var c := p1 + r1 * side * (hw1 + ow + 0.6) + Vector3.DOWN * OFFROAD_DROP
				var d := p1 + r1 * side * (hw1 if not curb_here else off_start1) + Vector3.DOWN * OFFROAD_DROP
				var oc := _offroad_color(path.themes[i], p0, side, r0)
				if side > 0:
					off_mb.quad(a, b, c, d, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, oc)
				else:
					off_mb.quad(b, a, d, c, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, oc)
	_add_mesh("Road", road_mb.commit(materials.road), false)
	_add_mesh("RoughRoad", rough_mb.commit(materials.road), false)
	_add_mesh("Curbs", curb_mb.commit(materials.curb), false)
	_add_mesh("Offroad", off_mb.commit(materials.ground), false)
	_attach_shape(road_body, road_mb)
	_attach_shape(road_body, curb_mb)
	_attach_shape(rough_body, rough_mb)
	_attach_shape(offroad_body, off_mb)


func _offroad_color(theme: int, p: Vector3, side: float, right: Vector3) -> Color:
	match theme:
		TrackData.THEME_BOULEVARD:
			# Sea side gets sand, inland gets park grass.
			return C_SAND if (right * side).z > 0.3 else C_GRASS
		TrackData.THEME_OLDCITY:
			return C_COBBLE_OFF
		TrackData.THEME_DOWNTOWN:
			return C_CITY_SIDEWALK
	return C_GRASS


# --- Walls --------------------------------------------------------------------

func _inside_other_corridor(p: Vector3, self_index: int, margin: float) -> bool:
	for entry in _all_paths():
		if entry.index == self_index:
			continue
		var path: TrackPath = entry.path
		var c := path.closest(p)
		var ow := data.offroad_width if entry.index < 0 else 1.2
		if c.distance < path.half_width_at(c.s) + ow + margin and absf(path.position_at(c.s).y - p.y) < 3.0:
			return true
	return false


func _build_walls() -> void:
	wall_body = _static_body("WallBody", &"wall")
	var wall_mb := MeshBuilder.new(false)
	var stone_mb := MeshBuilder.new(false)
	var col_mb := MeshBuilder.new(true)
	for entry in _all_paths():
		var path: TrackPath = entry.path
		var is_main: bool = entry.index < 0
		var ow := data.offroad_width if is_main else 1.2
		var count := path.sample_count()
		var seg_count := count if path.closed else count - 1
		for side: float in [-1.0, 1.0]:
			for i in seg_count:
				var j := (i + 1) % count
				var off0 := path.half_widths[i] + ow + 0.6
				var off1 := path.half_widths[j] + ow + 0.6
				var r0 := path.right_at(path.cum[i])
				var r1 := path.right_at(path.cum[j])
				var a := path.points[i] + r0 * side * off0
				var b := path.points[j] + r1 * side * off1
				var mid := (a + b) * 0.5
				if _inside_other_corridor(mid, entry.index, 0.4):
					continue
				var theme := path.themes[i]
				var style := _wall_style(theme, r0 * side)
				_wall_visual(stone_mb if style.get("kind", "") == "oldcity" else wall_mb, a, b, r0 * side, r1 * side, style)
				wall_segments.append({"a": a, "b": b, "out": r0 * side, "theme": theme,
					"path": entry.index, "side": side, "s": path.cum[i], "style": style.get("kind", "")})
				var lo := Vector3.DOWN * 1.0
				var hi := Vector3.UP * WALL_HEIGHT_COLLISION
				# Thick closed block behind the face (WALL_COLLISION_THICKNESS),
				# overlapping its neighbours, so a fast drifting kart can never
				# tunnel through a seam or a thin plane.
				var along := (b - a)
				along.y = 0.0
				along = along.normalized() * WALL_SEAM_OVERLAP if along.length_squared() > 1e-6 else Vector3.ZERO
				# The kart capsule (r=0.6) is narrower than the body (0.87 half
				# width), so the collision face sits WALL_FACE_INSET inside the
				# visual face: wheels stop at the barrier instead of inside it.
				var ia := a - along - r0 * side * WALL_FACE_INSET
				var ib := b + along - r1 * side * WALL_FACE_INSET
				var oa := ia + r0 * side * (WALL_COLLISION_THICKNESS + WALL_FACE_INSET)
				var ob := ib + r1 * side * (WALL_COLLISION_THICKNESS + WALL_FACE_INSET)
				col_mb.quad(ia + lo, ib + lo, ib + hi, ia + hi)
				col_mb.quad(ob + lo, oa + lo, oa + hi, ob + hi)
				col_mb.quad(ia + hi, ib + hi, ob + hi, oa + hi)
				col_mb.quad(oa + lo, ob + lo, ib + lo, ia + lo)
				col_mb.quad(oa + lo, ia + lo, ia + hi, oa + hi)
				col_mb.quad(ib + lo, ob + lo, ob + hi, ib + hi)
	_add_mesh("Barriers", wall_mb.commit(materials.wall), false)
	_add_mesh("StoneBarriers", stone_mb.commit(materials.stone), false)
	_attach_shape(wall_body, col_mb)


func _wall_style(theme: int, outward: Vector3) -> Dictionary:
	match theme:
		TrackData.THEME_BOULEVARD:
			if outward.z > 0.3:
				# Low plinth; the balustrade on top is placed by TrackDecor.
				return {"h": 0.22, "body": Color("e8dcc0"), "cap": Color("f4ecd8"), "stripe": Color.TRANSPARENT, "kind": "balustrade"}
			return {"h": 0.9, "body": C_CONCRETE, "cap": C_STRIPE_RED, "stripe": Color.WHITE}
		TrackData.THEME_DOWNTOWN:
			# City street barrier: light grey with a yellow cap and white stripe.
			return {"h": 0.95, "body": Color("c4cad3"), "cap": Color("ffb21f"), "stripe": Color.WHITE}
		TrackData.THEME_OLDCITY:
			# Tints for the limestone shader (near white keeps the stone colour).
			return {"h": 1.2, "body": Color(1.0, 0.97, 0.93), "cap": Color(1.0, 1.0, 1.0), "stripe": Color.TRANSPARENT, "kind": "oldcity"}
	return {"h": 0.95, "body": C_CONCRETE, "cap": C_STRIPE_BLUE, "stripe": Color.WHITE}


func _wall_visual(mb: MeshBuilder, a: Vector3, b: Vector3, out_a: Vector3, out_b: Vector3, st: Dictionary) -> void:
	var th := 0.45
	var h: float = st.h
	var body: Color = st.body
	var cap: Color = st.cap
	var out := (out_a + out_b).normalized()
	var oa := a + out_a * th
	var ob := b + out_b * th
	var down := Vector3.DOWN * 0.6
	var up := Vector3.UP * h
	var cap_up := Vector3.UP * (h + 0.12)
	var ia_c := a - out_a * 0.06
	var ib_c := b - out_b * 0.06
	var oa_c := oa + out_a * 0.06
	var ob_c := ob + out_b * 0.06
	mb.quad_facing(a + down, b + down, b + up, a + up, -out, body)
	mb.quad_facing(oa + down, ob + down, ob + up, oa + up, out, body.darkened(0.08))
	# Cap with small overhang and bevels for a rounded read.
	mb.quad_facing(ia_c + up, ib_c + up, ib_c + cap_up - (ib_c - b) * 0.7, ia_c + cap_up - (ia_c - a) * 0.7, -out + Vector3.UP, cap.darkened(0.06))
	var cap_col := cap
	if st.stripe.a > 0.0:
		# Racing kerb-style cap: alternate red and white every 2 m.
		cap_col = cap if int(floor((a.x + a.z) / 2.0)) % 2 == 0 else Color("f4f2ec")
	mb.quad_facing(a + cap_up, b + cap_up, ob + cap_up, oa + cap_up, Vector3.UP, cap_col)
	mb.quad_facing(oa_c + up, ob_c + up, ob + cap_up, oa + cap_up, out + Vector3.UP, cap.darkened(0.1))
	mb.quad_facing(ia_c + up, ib_c + up, b + up, a + up, Vector3.DOWN, cap.darkened(0.2))
	if st.stripe.a > 0.0:
		var y0 := Vector3.UP * (h * 0.42)
		var y1 := Vector3.UP * (h * 0.66)
		var inset := -out * 0.012
		var phase := int(floor((a.x + a.z) / 3.0)) % 2 == 0
		mb.quad_facing(a + y0 + inset, b + y0 + inset, b + y1 + inset, a + y1 + inset, -out, st.stripe if phase else cap)


# --- Ramps, pads, finish ------------------------------------------------------

func _build_ramps() -> void:
	var mb := MeshBuilder.new(false)
	for r in data.ramps:
		var s0: float = r.s - r.length * 0.5
		var s1: float = r.s + r.length * 0.5
		var hw := data.main.half_width_at(r.s) + 0.3
		var steps := 6
		var verts_top: Array = []
		for k in steps + 1:
			var f := float(k) / steps
			var s := lerpf(s0, s1, f)
			var p := data.main.position_at(s)
			var rgt := data.main.right_at(s)
			# Slightly concave ramp face for a smooth launch.
			var h: float = r.height * f * f * 0.35 + r.height * f * 0.65
			verts_top.append([p - rgt * hw + Vector3.UP * h, p + rgt * hw + Vector3.UP * h, p - rgt * hw, p + rgt * hw])
		var faces := PackedVector3Array()
		for k in steps:
			var a: Array = verts_top[k]
			var b: Array = verts_top[k + 1]
			var stripe := Color("ffc93c") if k % 2 == 0 else Color("2b2f3a")
			mb.quad(a[0], a[1], b[1], b[0], Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, stripe)
			# sides
			mb.quad(a[2], a[0], b[0], b[2], Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color("c9c2b4"))
			mb.quad(a[1], a[3], b[3], b[1], Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color("c9c2b4"))
		var last: Array = verts_top[steps]
		mb.quad(last[3], last[2], last[0], last[1], Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color("9b9384"))
		# Convex collision for the wedge.
		var pts := PackedVector3Array()
		for v in verts_top:
			for q in v:
				pts.append(q)
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		var cs := CollisionShape3D.new()
		cs.shape = shape
		road_body.add_child(cs)
	_add_mesh("Ramps", mb.commit(materials.wall), false)


func _build_boost_pads() -> void:
	var mb := MeshBuilder.new(false)
	for pad in data.boost_pads:
		var s0: float = pad.s - pad.length * 0.5
		var hw: float = pad.width * 0.5
		var lat: float = pad.lateral
		var chevrons := int(pad.length / 1.6)
		for k in chevrons:
			var sa := s0 + k * 1.6
			var sb := sa + 1.0
			var pa := data.main.position_at(sa) + Vector3.UP * 0.03
			var pb := data.main.position_at(sb) + Vector3.UP * 0.03
			var ra := data.main.right_at(sa)
			var rb := data.main.right_at(sb)
			var tip := pb + rb * lat
			var col := Color("ffb21f") if k % 2 == 0 else Color("ff6a1f")
			# Chevron as two quads meeting at the tip.
			var lift := Vector3.UP * 0.01
			mb.quad_facing(pa + ra * (lat - hw) + lift, pa + ra * (lat - hw + 0.9) + lift, tip + rb * 0.45 + lift, tip - rb * 0.45 + lift, Vector3.UP, col)
			mb.quad_facing(pa + ra * (lat + hw - 0.9) + lift, pa + ra * (lat + hw) + lift, tip + rb * 0.45 + lift, tip - rb * 0.45 + lift, Vector3.UP, col)
		# Base plate
		var b0 := data.main.position_at(s0) + Vector3.UP * 0.02
		var b1 := data.main.position_at(s0 + pad.length) + Vector3.UP * 0.02
		var r0 := data.main.right_at(s0)
		var r1 := data.main.right_at(s0 + pad.length)
		mb.quad(b0 + r0 * (lat - hw), b0 + r0 * (lat + hw), b1 + r1 * (lat + hw), b1 + r1 * (lat - hw), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color("3a2a5a"))
		# Trigger
		var area := Area3D.new()
		area.name = "BoostPad"
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitorable = false
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(pad.width, 2.0, pad.length)
		cs.shape = box
		area.add_child(cs)
		var mid := data.main.position_at(pad.s)
		var t := data.main.tangent_at(pad.s)
		var basis := Basis.looking_at(Vector3(t.x, 0, t.z).normalized(), Vector3.UP)
		area.transform = Transform3D(basis, mid + data.main.right_at(pad.s) * lat + Vector3.UP * 1.0)
		add_child(area)
		boost_pad_areas.append(area)
	_add_mesh("BoostPads", mb.commit(materials.pad), false)


func _build_finish_line() -> void:
	var mb := MeshBuilder.new(false)
	var s := data.finish_s
	var hw := data.main.half_width_at(s)
	var cells_across := 16
	var rows := 3
	var depth := 0.7
	for row in rows:
		for k in cells_across:
			var sa := s - depth * rows * 0.5 + row * depth
			var sb := sa + depth
			var fa := -hw + (2.0 * hw) * k / cells_across
			var fb := -hw + (2.0 * hw) * (k + 1) / cells_across
			var pa := data.main.position_at(sa) + Vector3.UP * 0.025
			var pb := data.main.position_at(sb) + Vector3.UP * 0.025
			var ra := data.main.right_at(sa)
			var rb := data.main.right_at(sb)
			var col := Color.WHITE if (row + k) % 2 == 0 else Color("1d1f27")
			mb.quad(pa + ra * fa, pa + ra * fb, pb + rb * fb, pb + rb * fa, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, col)
	_add_mesh("FinishLine", mb.commit(materials.wall), false)


# --- Terrain & water ----------------------------------------------------------

func _build_terrain() -> void:
	var bounds := AABB(data.main.points[0], Vector3.ZERO)
	for p in data.main.points:
		bounds = bounds.expand(p)
	var margin := 140.0
	var x0 := floorf(bounds.position.x - margin)
	var z0 := floorf(bounds.position.z - margin)
	var x1 := ceilf(bounds.end.x + margin)
	var z1 := minf(ceilf(bounds.end.z + margin), data.sea_z + 40.0)
	var cell := 6.0
	var nx := int((x1 - x0) / cell) + 1
	var nz := int((z1 - z0) / cell) + 1
	# Spatial hash of path samples for fast nearest queries.
	var hash := {}
	var hcell := 24.0
	for entry in _all_paths():
		var path: TrackPath = entry.path
		var ow := data.offroad_width if entry.index < 0 else 1.2
		for i in path.sample_count():
			var p := path.points[i]
			var key := Vector2i(int(floor(p.x / hcell)), int(floor(p.z / hcell)))
			if not hash.has(key):
				hash[key] = []
			hash[key].append([p, path.half_widths[i] + ow + 0.6])
	_terrain_hash = hash
	var heights := PackedFloat32Array()
	var cols := PackedColorArray()
	heights.resize(nx * nz)
	cols.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var wx := x0 + ix * cell
			var wz := z0 + iz * cell
			var info := _terrain_sample(hash, hcell, wx, wz)
			heights[iz * nx + ix] = info[0]
			cols[iz * nx + ix] = info[1]
	var mb := MeshBuilder.new(false)
	for iz in nz - 1:
		for ix in nx - 1:
			var i00 := iz * nx + ix
			var i10 := i00 + 1
			var i01 := i00 + nx
			var i11 := i01 + 1
			var p00 := Vector3(x0 + ix * cell, heights[i00], z0 + iz * cell)
			var p10 := Vector3(x0 + (ix + 1) * cell, heights[i10], z0 + iz * cell)
			var p01 := Vector3(x0 + ix * cell, heights[i01], z0 + (iz + 1) * cell)
			var p11 := Vector3(x0 + (ix + 1) * cell, heights[i11], z0 + (iz + 1) * cell)
			mb.tri_colored(p00, p01, p11, cols[i00], cols[i01], cols[i11])
			mb.tri_colored(p00, p11, p10, cols[i00], cols[i11], cols[i10])
	var mi := _add_mesh("Terrain", mb.commit(materials.ground), false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Safety floor far below: anything reaching it is recovered by RaceManager.


## 0.15.3: height of the grass terrain at a world point (same rule as the
## mesh, without the 6 m grid), for set pieces standing on it.
var _terrain_hash := {}


func terrain_height(wx: float, wz: float) -> float:
	if _terrain_hash.is_empty():
		return 0.0
	return float(_terrain_sample(_terrain_hash, 24.0, wx, wz)[0])


func _terrain_sample(hash: Dictionary, hcell: float, wx: float, wz: float) -> Array:
	var key := Vector2i(int(floor(wx / hcell)), int(floor(wz / hcell)))
	var best_d := INF
	var best_y := 0.0
	var best_edge := 10.0
	var wsum := 0.0
	var ysum := 0.0
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var k := Vector2i(key.x + dx, key.y + dz)
			if not hash.has(k):
				continue
			for e in hash[k]:
				var p: Vector3 = e[0]
				var d := Vector2(p.x - wx, p.z - wz).length()
				if d < best_d:
					best_d = d
					best_y = p.y
					best_edge = e[1]
				var w := 1.0 / maxf(d * d, 1.0)
				wsum += w
				ysum += w * p.y
	if best_d == INF:
		best_d = 200.0 # far from every track sample
	var y := best_y
	if wsum > 0.0:
		y = ysum / wsum
	var col := C_GRASS
	var city := data.ground == "city"
	if city:
		# Downtown: paved blocks, with a few round park lawns.
		col = C_CITY_PLAZA
		if sin(wx * 0.021 + 1.3) * cos(wz * 0.026) > 0.55 and best_d > 24.0:
			col = C_CITY_PARK
	var inside := best_d < best_edge + 1.0
	if inside:
		y = best_y - 0.7
	else:
		y = minf(y, best_y) - 0.1 if best_d < best_edge + 8.0 else y - 0.1
	# Paved promenade between the boulevard and the sea.
	if wz > data.sea_z - 16.0 and wz <= data.sea_z:
		col = C_PAVING
		if not inside:
			y = maxf(y, -0.06)
	elif wz > data.sea_z:
		col = C_SEABED
		y = data.sea_level - 3.0
	elif city:
		pass
	elif best_y > 4.5 and best_d < 60.0:
		col = C_COBBLE_OFF.lightened(0.15)
	elif best_d > 70.0:
		col = C_GRASS_DARK
	var n := sin(wx * 0.05) * cos(wz * 0.043)
	if city:
		# Flat blocks (towers stand on them); hills only far outside town.
		if best_d > 170.0 and wz < data.sea_z - 16.0:
			y += minf((best_d - 170.0) * 0.08, 8.0) + n * 1.5
	elif best_d > 60.0 and wz < data.sea_z - 16.0:
		y += minf(maxf(0.0, (best_d - 60.0) * 0.06), 6.0) + n * 1.5 # gentle hills away from the course
	return [y, col]


func _build_water() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2600, 1400)
	mesh.subdivide_width = 40
	mesh.subdivide_depth = 20
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = mesh
	mi.material_override = materials.water
	mi.position = Vector3(0, data.sea_level, data.sea_z + 700.0 - 6.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Seawall face along the promenade edge.
	var mb := MeshBuilder.new(false)
	var y_top := -0.05
	var y_bot := data.sea_level - 1.5
	var z := data.sea_z
	var xa := -1300.0
	var xb := 1300.0
	mb.quad(Vector3(xa, y_bot, z), Vector3(xb, y_bot, z), Vector3(xb, y_top, z), Vector3(xa, y_top, z), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color("cbbd9c"))
	mb.quad(Vector3(xa, y_top, z), Vector3(xb, y_top, z), Vector3(xb, y_top + 0.05, z - 0.8), Vector3(xa, y_top + 0.05, z - 0.8), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color("efe6d2"))
	_add_mesh("Seawall", mb.commit(materials.wall), false)


# --- Helpers ------------------------------------------------------------------

func _static_body(body_name: String, surface: StringName) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", surface)
	add_child(body)
	return body


func _attach_shape(body: StaticBody3D, mb: MeshBuilder) -> void:
	if mb.collision.is_empty():
		return
	var cs := CollisionShape3D.new()
	cs.shape = mb.make_shape()
	body.add_child(cs)


func _add_mesh(mesh_name: String, mesh: ArrayMesh, decor: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	if decor:
		decor_root.add_child(mi)
	else:
		add_child(mi)
	return mi
