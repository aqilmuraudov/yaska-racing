class_name KartModel
extends Node3D
## Procedural kart + animal driver for one RacerDefinition. Six karts with
## different silhouettes (not just colours) share one wheel/steering rig so
## animation and effects code is common. Forward is -Z, origin at ground.
## Cosmetic parts never affect collision (the capsule is the same for all).
##   bamboo  – Posi's Bamboo Sprint: rounded white/mint tub, bamboo bumpers, leaf wing
##   amber   – Bicok's Amber Dash: long pointed wedge, side fins, swept twin-tip wing
##   hop     – Ləlöyün's Hop Rocket: short tall body, carrot nose and carrot exhausts
##   velvet  – Məstan's Velvet Slide: low wide sports body, flowing pods, ear fins
##   buddy   – HavHav's Buddy Rally: boxy rally body, light bar, mud flaps, bone badge
##   star    – Yaska's Yaska Star: rounded pink bubble body, star nose, heart wing, flower
##   cloud   – Çəpiş's Cloud Booster: bubbly body with cloud puffs, twin big boosters

var def: RacerDefinition
var wheels: Array[Node3D] = []
var wheel_spinners: Array[Node3D] = []
var exhaust_points: Array[Vector3] = []
var rear_contact_points: Array[Vector3] = []
var shield_radius := 1.45
var driver: AnimalDriver
var steering_wheel: Node3D
var steering_spin: Node3D
var _base_wheel_y: Array[float] = []
var _accums := {}
## Cosmetic kart parts (Progression.PARTS ids) to add on build; set before
## build(). Purely visual, merged into the same batched meshes.
var parts: Array = []
static var _kart_vcolor: ShaderMaterial
## 0.14.0 Blender-made models (tools/blender/): kart_style -> glTF scene. Each
## part is a mesh named after the procedural rig pivot it rides on, authored in
## kart space; build() still makes the rig (wheels, steering, driver nodes) and
## only skips the procedural meshes, so all animation code is shared. Missing
## file -> the procedural model, as before.
const GLTF_MODELS := {"star": "res://assets/models/yaska/yaska_star.glb",
	"buddy": "res://assets/models/havhav/buddy_rally.glb",
	"bamboo": "res://assets/models/posi/bamboo_sprint.glb"}
const GLTF_FAR := {"star": "res://assets/models/yaska/yaska_star_far.glb",
	"buddy": "res://assets/models/havhav/buddy_rally_far.glb",
	"bamboo": "res://assets/models/posi/bamboo_sprint_far.glb"}
## Exhaust tips of the glTF models (smoke and boost flames start here).
const GLTF_EXHAUST := {"star": [Vector3(-0.235, 1.0, 1.11), Vector3(0.235, 1.0, 1.11)],
	"buddy": [Vector3(0.33, 0.525, 1.18)],
	"bamboo": [Vector3(-0.2, 0.6, 1.15), Vector3(0.2, 0.6, 1.15)]}
const BAKED_SHADER := preload("res://assets/materials/kart_baked.gdshader")
static var gltf_enabled := true
static var _baked_mats := {}
## Set by KartVisual on its far copy: use the far glTF instead of the near one.
var lod_far := false
var from_gltf := false
## While true, _add() records nothing: the rig is built without meshes.
var _rig_only := false

const C_TIRE := Color("1d1e22")
const C_CHROME := Color("d9dde3")


func build(p_def: RacerDefinition, _is_player: bool = false) -> void:
	def = p_def
	var src := _gltf_parts()
	from_gltf = not src.is_empty()
	_rig_only = from_gltf
	var p := def.kart_primary
	var s := def.kart_secondary
	var t := def.kart_trim
	var wheel_cfg := {"rf": 0.29, "rr": 0.34, "wf": 0.26, "wr": 0.34, "rim": s, "tread": false}
	# Shared floor pan
	_add(self, ShapeKit.superellipsoid(Vector3(1.05, 0.14, 1.85), 0.2, 0.25), t.darkened(0.3), _T(Vector3(0, 0.27, -0.02)))
	match def.kart_style:
		"bamboo": _bamboo(p, s, t, wheel_cfg)
		"amber": _amber(p, s, t, wheel_cfg)
		"hop": _hop(p, s, t, wheel_cfg)
		"velvet": _velvet(p, s, t, wheel_cfg)
		"cloud": _cloud(p, s, t, wheel_cfg)
		"star": _star(p, s, t, wheel_cfg)
		_: _buddy(p, s, t, wheel_cfg)
	_seat_and_wheel(t)
	_rig_only = false
	_parts(p, s, wheel_cfg)
	_rig_only = from_gltf
	_wheels(wheel_cfg)
	_rig_only = false
	rear_contact_points = [Vector3(-0.66, 0.05, 0.78), Vector3(0.66, 0.05, 0.78)]
	_flush()
	driver = AnimalDriver.new()
	driver.position = Vector3(0, 0, 0.2)
	add_child(driver)
	driver.rig_only = from_gltf
	driver.build(def)
	driver.steering_wheel = steering_spin
	if from_gltf:
		_attach_gltf(src)
		if GLTF_EXHAUST.has(def.kart_style):
			exhaust_points.assign(GLTF_EXHAUST[def.kart_style])


static func _T(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scl), pos)


static func _se(size: Vector3, r := 0.4, front := Vector2.ONE, back := Vector2.ONE, lift := 0.0) -> Mesh:
	return ShapeKit.superellipsoid(size, r, r, front, back, 8, 16, lift)


func _add(parent: Node3D, mesh: Mesh, color: Color, xform: Transform3D, rough := 0.35, _metal := 0.0) -> void:
	if _rig_only:
		return
	# Metallic looks are approximated with low roughness so every part merges
	# into the single vertex-coloured surface (one draw per animated node).
	if not _accums.has(parent):
		_accums[parent] = PropKit.Accum.new()
	_accums[parent].add(mesh, xform, ShapeKit.mat(color, rough, 0.0))


func _flush() -> void:
	if _kart_vcolor == null:
		_kart_vcolor = ShaderMaterial.new()
		_kart_vcolor.shader = preload("res://assets/materials/vcolor_gloss.gdshader")
		_kart_vcolor.set_shader_parameter("rim_amount", 0.25)
		_kart_vcolor.set_shader_parameter("gloss", 0.9)
		_kart_vcolor.set_shader_parameter("saturation", Palette.KART_SAT)
	for node in _accums.keys():
		var mi := MeshInstance3D.new()
		mi.mesh = _accums[node].commit(_kart_vcolor)
		if node in wheel_spinners or node == steering_spin:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # contact blob grounds them
		node.add_child(mi)
	_accums.clear()


# --- glTF models (0.14.0) ---------------------------------------------------------

## name -> [Mesh, Transform3D in kart space] from this style's glTF, or {}.
func _gltf_parts() -> Dictionary:
	var table := GLTF_FAR if lod_far else GLTF_MODELS
	if not gltf_enabled or not table.has(def.kart_style) or not ResourceLoader.exists(table[def.kart_style]):
		return {}
	var scene := load(table[def.kart_style]) as PackedScene
	if scene == null:
		return {}
	var inst := scene.instantiate()
	var out := {}
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != inst:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		out[String(mi.name)] = [(mi as MeshInstance3D).mesh, xf]
	inst.free()
	return out


## Shared material per texture folder: baked colour / normal / ORM maps.
static func baked_material(dir: String) -> ShaderMaterial:
	if not _baked_mats.has(dir):
		var m := ShaderMaterial.new()
		m.shader = BAKED_SHADER
		m.set_shader_parameter("albedo_tex", load(dir + "/albedo.png"))
		m.set_shader_parameter("normal_tex", load(dir + "/normal.png"))
		m.set_shader_parameter("orm_tex", load(dir + "/orm.png"))
		m.set_shader_parameter("saturation", Palette.KART_SAT * 0.9)
		_baked_mats[dir] = m
	return _baked_mats[dir]


## Rest transform of a rig node in kart space (works before entering the tree).
func _rest_xform(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n != null and n != self:
		xf = n.transform * xf
		n = n.get_parent() as Node3D
	return xf


func _attach_gltf(src: Dictionary) -> void:
	var table := GLTF_FAR if lod_far else GLTF_MODELS
	var mat := baked_material(String(table[def.kart_style]).get_base_dir())
	# Garage paint: KartPaints.painted() hands us a copy with another body colour.
	var own := RacerRoster.get_def(def.id).kart_primary
	var paint := Color(0, 0, 0, 0)
	if not def.kart_primary.is_equal_approx(own):
		paint = def.kart_primary
	var targets := {"Body": self, "WheelFL": wheel_spinners[0], "WheelFR": wheel_spinners[1],
		"WheelRear": wheel_spinners[2], "SteeringWheel": steering_spin,
		"Torso": driver.torso, "Head": driver.head}
	if not driver.eyes.is_empty():
		targets["Eyes"] = driver.eyes[0]
	if driver.ears.size() == 2:
		# Braids (girl) or ears (animals) ride on the same pivots.
		targets["BraidL"] = driver.ears[0]
		targets["BraidR"] = driver.ears[1]
		targets["EarL"] = driver.ears[0]
		targets["EarR"] = driver.ears[1]
	if driver.tail:
		targets["Tail"] = driver.tail
	if driver.arms.size() == 2:
		targets["ArmL"] = driver.arms[0].get_child(0)
		targets["ArmR"] = driver.arms[1].get_child(0)
	for key in src.keys():
		if not targets.has(key):
			push_warning("KartModel: glTF part '%s' has no rig node" % key)
			continue
		var node: Node3D = targets[key]
		var mi := MeshInstance3D.new()
		mi.name = "Gltf" + String(key)
		mi.mesh = src[key][0]
		mi.material_override = mat
		if key == "Body" and paint.a > 0.0:
			mi.set_instance_shader_parameter(&"paint", paint)
		mi.transform = _rest_xform(node).affine_inverse() * (src[key][1] as Transform3D)
		if String(key).begins_with("Wheel"):
			_tyres.append(mi)
		var big: bool = key in ["Body", "Torso", "Head"]
		if not big:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if driver.is_ancestor_of(node):
				mi.visibility_range_end = 45.0 # as AnimalDriver: small detail far away
		node.add_child(mi)


func _exhaust(pos: Vector3, radius: float, length: float, color: Color = C_CHROME) -> void:
	_add(self, ShapeKit.cylinder(radius, length, 10), color, _T(pos, Vector3(PI * 0.5, 0, 0)), 0.2, 0.9)
	_add(self, ShapeKit.cylinder(radius * 0.7, 0.02, 10), Color("2a2a2a"), _T(pos + Vector3(0, 0, length * 0.5), Vector3(PI * 0.5, 0, 0)))
	exhaust_points.append(pos + Vector3(0, 0, length * 0.5))


# --- Styles -----------------------------------------------------------------------

func _bamboo(p: Color, s: Color, t: Color, w: Dictionary) -> void:
	_add(self, _se(Vector3(1.0, 0.46, 1.5), 0.6, Vector2(0.7, 0.72), Vector2.ONE, -0.02), p, _T(Vector3(0, 0.52, -0.05)))
	for x in [-0.58, 0.58]:
		_add(self, _se(Vector3(0.3, 0.3, 0.9), 0.7, Vector2(0.8, 0.8)), s, _T(Vector3(x, 0.42, 0.1)))
	# Bamboo bumper bars (segmented poles) front and rear
	for z in [-1.08, 1.02]:
		_add(self, ShapeKit.cylinder(0.07, 1.36, 10), Color("8fc96a"), _T(Vector3(0, 0.33, z), Vector3(0, 0, PI * 0.5)))
		for k in 4:
			_add(self, ShapeKit.cylinder(0.08, 0.035, 10), Color("5f9c4c"), _T(Vector3(-0.5 + k * 0.34, 0.33, z), Vector3(0, 0, PI * 0.5)))
	# Charcoal nose accent and leaf-shaped rear wing
	_add(self, _se(Vector3(0.5, 0.18, 0.4), 0.6), t, _T(Vector3(0, 0.6, -0.72)))
	_add(self, _se(Vector3(0.62, 0.32, 0.42), 0.4), t.lightened(0.15), _T(Vector3(0, 0.58, 0.82)))
	for x in [-0.32, 0.32]:
		_add(self, ShapeKit.cylinder(0.035, 0.2, 6), t, _T(Vector3(x, 0.78, 1.0)))
	_add(self, ShapeKit.superellipsoid(Vector3(1.0, 0.06, 0.38), 0.5, 0.9, Vector2(0.4, 1.0), Vector2(0.4, 1.0)), s, _T(Vector3(0, 0.88, 1.02), Vector3(0.1, 0, 0)))
	_exhaust(Vector3(-0.2, 0.6, 1.08), 0.07, 0.28)
	_exhaust(Vector3(0.2, 0.6, 1.08), 0.07, 0.28)
	w.rf = 0.31
	w.rr = 0.36
	w.rim = s


func _amber(p: Color, s: Color, t: Color, w: Dictionary) -> void:
	_add(self, _se(Vector3(0.9, 0.34, 1.95), 0.45, Vector2(0.35, 0.45), Vector2.ONE, -0.06), p, _T(Vector3(0, 0.46, -0.12)))
	# Navy racing stripe along the spine
	_add(self, _se(Vector3(0.22, 0.36, 1.9), 0.45, Vector2(0.3, 0.45)), s, _T(Vector3(0, 0.48, -0.12)))
	# Side pods with pointed fins
	for x in [-0.56, 0.56]:
		_add(self, _se(Vector3(0.28, 0.28, 1.0), 0.45, Vector2(0.5, 0.6)), p.darkened(0.08), _T(Vector3(x, 0.4, 0.15)))
		_add(self, ShapeKit.cone(0.1, 0.0, 0.5, 4), s, _T(Vector3(x * 1.08, 0.5, 0.55), Vector3(PI * 0.5, PI * 0.25, 0), Vector3(1, 1, 0.5)))
	# Front splitter
	_add(self, _se(Vector3(1.3, 0.07, 0.36), 0.3, Vector2(0.9, 1.0)), s, _T(Vector3(0, 0.26, -1.2)))
	# Swept wing with pointed tips
	for x in [-0.4, 0.4]:
		_add(self, _se(Vector3(0.05, 0.3, 0.1), 0.3), t, _T(Vector3(x, 0.76, 1.04)))
	_add(self, _se(Vector3(1.3, 0.07, 0.32), 0.3, Vector2(1.0, 0.7)), s, _T(Vector3(0, 0.9, 1.06), Vector3(0.12, 0, 0)))
	for x in [-0.7, 0.7]:
		_add(self, ShapeKit.cone(0.08, 0.0, 0.3, 4), p, _T(Vector3(x, 0.92, 1.11), Vector3(PI * 0.5, PI * 0.25, 0), Vector3(1, 1, 0.4)))
	_add(self, _se(Vector3(0.7, 0.32, 0.45), 0.35), Color("8a8f99"), _T(Vector3(0, 0.56, 0.88)), 0.35, 0.7)
	_exhaust(Vector3(-0.17, 0.6, 1.15), 0.06, 0.32)
	_exhaust(Vector3(0.17, 0.6, 1.15), 0.06, 0.32)
	w.rf = 0.27
	w.rr = 0.35
	w.rim = t


func _hop(p: Color, s: Color, t: Color, w: Dictionary) -> void:
	_add(self, _se(Vector3(1.0, 0.54, 1.3), 0.75, Vector2(0.75, 0.78), Vector2.ONE, 0.03), p, _T(Vector3(0, 0.57, -0.02)))
	_add(self, _se(Vector3(1.04, 0.14, 1.34), 0.5), s, _T(Vector3(0, 0.36, -0.02)))
	# Carrot nose cone with leafy tuft
	_add(self, ShapeKit.cone(0.28, 0.02, 0.62, 12), t, _T(Vector3(0, 0.42, -1.0), Vector3(-PI * 0.5, 0, 0)))
	for k in 4:
		_add(self, ShapeKit.cone(0.012, 0.0, 0.02, 4), t.darkened(0.3), _T(Vector3(0, 0.42 + (k - 1.5) * 0.08, -0.85 - k * 0.04)))
	for k in 3:
		var a := (k - 1) * 0.5
		_add(self, ShapeKit.superellipsoid(Vector3(0.07, 0.24, 0.03), 0.6, 0.6), Color("5cc46a"), _T(Vector3(sin(a) * 0.1, 0.6, -0.68), Vector3(0.3, 0, a)))
	# Rounded little wing and carrot-shaped exhausts
	_add(self, _se(Vector3(0.9, 0.08, 0.3), 0.5), s, _T(Vector3(0, 0.86, 0.9), Vector3(0.1, 0, 0)))
	for x in [-0.34, 0.34]:
		_add(self, ShapeKit.cylinder(0.035, 0.16, 6), t.darkened(0.2), _T(Vector3(x, 0.78, 0.9)))
	for x in [-0.2, 0.2]:
		var ep := Vector3(x, 0.62, 0.95)
		_add(self, ShapeKit.cone(0.09, 0.03, 0.34, 10), t, _T(ep, Vector3(PI * 0.5, 0, 0)))
		_add(self, ShapeKit.superellipsoid(Vector3(0.05, 0.14, 0.03), 0.6, 0.6), Color("5cc46a"), _T(ep + Vector3(0, 0.1, -0.12), Vector3(0.4, 0, 0)))
		exhaust_points.append(ep + Vector3(0, 0, 0.18))
	w.rf = 0.28
	w.rr = 0.32
	w.rim = s


func _velvet(p: Color, s: Color, t: Color, w: Dictionary) -> void:
	_add(self, _se(Vector3(1.08, 0.3, 1.8), 0.5, Vector2(0.55, 0.55), Vector2(0.95, 1.0), -0.04), p, _T(Vector3(0, 0.42, -0.08)))
	# Flowing coral side sweeps
	for x in [-0.6, 0.6]:
		_add(self, _se(Vector3(0.24, 0.24, 1.25), 0.6, Vector2(0.45, 0.5), Vector2(0.8, 0.8)), s, _T(Vector3(x, 0.38, 0.05)))
	# Cat-ear fins behind the seat
	for x in [-0.28, 0.28]:
		_add(self, ShapeKit.cone(0.12, 0.0, 0.26, 4), s, _T(Vector3(x, 0.98, 0.62), Vector3(-0.25, PI * 0.25, 0), Vector3(1, 1, 0.45)))
	_add(self, _se(Vector3(1.2, 0.06, 0.26), 0.35), t, _T(Vector3(0, 0.27, -1.12)))
	_add(self, _se(Vector3(1.24, 0.06, 0.3), 0.35, Vector2(1.0, 0.7)), t, _T(Vector3(0, 0.82, 1.0), Vector3(0.08, 0, 0)))
	for x in [-0.4, 0.4]:
		_add(self, _se(Vector3(0.05, 0.3, 0.1), 0.3), t, _T(Vector3(x, 0.66, 1.0)))
	_add(self, _se(Vector3(0.66, 0.26, 0.42), 0.35), Color("8a8f99"), _T(Vector3(0, 0.5, 0.85)), 0.35, 0.7)
	_exhaust(Vector3(-0.24, 0.48, 1.1), 0.055, 0.26, s)
	_exhaust(Vector3(0.24, 0.48, 1.1), 0.055, 0.26, s)
	w.rf = 0.28
	w.rr = 0.34
	w.rim = s


func _buddy(p: Color, s: Color, t: Color, w: Dictionary) -> void:
	_add(self, _se(Vector3(1.04, 0.5, 1.6), 0.28, Vector2(0.85, 0.85), Vector2.ONE, 0.0), p, _T(Vector3(0, 0.55, -0.04)))
	# Yellow rally stripes
	for x in [-0.16, 0.16]:
		_add(self, _se(Vector3(0.12, 0.52, 1.62), 0.28, Vector2(0.85, 0.85)), s, _T(Vector3(x, 0.555, -0.04)))
	# Light bar with four round lamps
	_add(self, _se(Vector3(0.9, 0.08, 0.12), 0.3), t, _T(Vector3(0, 0.95, -0.42)))
	for x in [-0.32, 0.32]:
		_add(self, ShapeKit.cylinder(0.025, 0.2, 6), t, _T(Vector3(x, 0.86, -0.42)))
	for k in 4:
		_add(self, ShapeKit.cylinder(0.08, 0.06, 12), Color("fff3c0"), _T(Vector3(-0.3 + k * 0.2, 0.95, -0.49), Vector3(PI * 0.5, 0, 0)), 0.2)
	# Chunky bumper, bone badge, mud flaps
	_add(self, _se(Vector3(1.32, 0.16, 0.2), 0.3), t, _T(Vector3(0, 0.3, -1.06)))
	_add(self, _se(Vector3(0.26, 0.07, 0.04), 0.6), Color.WHITE, _T(Vector3(0, 0.55, -0.86)))
	for x in [-0.12, 0.12]:
		for y in [-0.03, 0.03]:
			_add(self, ShapeKit.sphere(0.04, 8, 5), Color.WHITE, _T(Vector3(x, 0.55 + y, -0.86)))
	for x in [-0.66, 0.66]:
		_add(self, ShapeKit.superellipsoid(Vector3(0.28, 0.24, 0.03), 0.3, 0.3), t, _T(Vector3(x, 0.22, 1.05)))
	_add(self, _se(Vector3(1.0, 0.07, 0.3), 0.3), s, _T(Vector3(0, 0.86, 0.95)))
	for x in [-0.36, 0.36]:
		_add(self, ShapeKit.cylinder(0.035, 0.1, 6), t, _T(Vector3(x, 0.8, 0.95)))
	_exhaust(Vector3(0.3, 0.42, 1.05), 0.07, 0.26)
	w.rf = 0.31
	w.rr = 0.36
	w.rim = s
	w.tread = true


func _cloud(p: Color, s: Color, t: Color, w: Dictionary) -> void:
	_add(self, _se(Vector3(1.02, 0.5, 1.5), 0.8, Vector2(0.75, 0.8), Vector2.ONE, 0.0), p, _T(Vector3(0, 0.54, -0.06)))
	# Cloud puffs along the sides and over the engine
	var puffs := [Vector3(-0.56, 0.42, -0.3), Vector3(-0.6, 0.48, 0.1), Vector3(-0.54, 0.44, 0.45), Vector3(0.56, 0.42, -0.3), Vector3(0.6, 0.48, 0.1), Vector3(0.54, 0.44, 0.45), Vector3(0, 0.72, 0.78), Vector3(-0.22, 0.68, 0.82), Vector3(0.22, 0.68, 0.82), Vector3(0, 0.5, -0.92)]
	for q in puffs:
		_add(self, ShapeKit.sphere(0.2, 12, 8), s, _T(q))
	# Twin stylised boosters
	for x in [-0.26, 0.26]:
		var bp := Vector3(x, 0.62, 1.02)
		_add(self, ShapeKit.cone(0.16, 0.12, 0.42, 14), C_CHROME, _T(bp, Vector3(PI * 0.5, 0, 0)), 0.2, 0.9)
		_add(self, ShapeKit.torus(0.12, 0.17, 14, 4), p.darkened(0.2), _T(bp + Vector3(0, 0, 0.2), Vector3(PI * 0.5, 0, 0)))
		exhaust_points.append(bp + Vector3(0, 0, 0.22))
	_add(self, _se(Vector3(1.2, 0.18, 0.2), 0.6), t, _T(Vector3(0, 0.3, -1.0)))
	w.rf = 0.3
	w.rr = 0.34
	w.rim = t


func _star(p: Color, s: Color, t: Color, w: Dictionary) -> void:
	# Smooth pink bubble body with a denim-blue belt line
	_add(self, _se(Vector3(1.06, 0.52, 1.62), 0.7, Vector2(0.7, 0.8), Vector2(0.95, 1.0), 0.03), p, _T(Vector3(0, 0.55, -0.04)))
	_add(self, _se(Vector3(1.1, 0.12, 1.66), 0.5), t, _T(Vector3(0, 0.4, -0.04)))
	# Golden five-point star on the nose
	var star_c := Vector3(0, 0.6, -0.9)
	for k in 5:
		var a := TAU * k / 5.0
		_add(self, ShapeKit.cone(0.07, 0.0, 0.2, 4), s, _T(star_c + Vector3(sin(a) * 0.09, cos(a) * 0.09, 0), Vector3(0, 0, -a), Vector3(1, 1, 0.5)))
	_add(self, ShapeKit.sphere(0.09, 10, 6), s, _T(star_c, Vector3.ZERO, Vector3(1, 1, 0.5)))
	# Rounded bumper with white "lace" dots
	_add(self, _se(Vector3(1.22, 0.16, 0.2), 0.7), t, _T(Vector3(0, 0.3, -1.04)))
	for k in 7:
		_add(self, ShapeKit.sphere(0.04, 8, 5), Color.WHITE, _T(Vector3(-0.48 + k * 0.16, 0.4, -1.0)))
	# Heart-shaped rear wing on two posts
	for x in [-0.12, 0.12]:
		_add(self, ShapeKit.sphere(0.16, 12, 8), s, _T(Vector3(x, 0.98, 0.95), Vector3.ZERO, Vector3(1, 0.85, 0.45)))
	_add(self, ShapeKit.cone(0.2, 0.0, 0.26, 4), s, _T(Vector3(0, 0.85, 0.95), Vector3(PI, PI * 0.25, 0), Vector3(1, 1, 0.45)))
	for x in [-0.3, 0.3]:
		_add(self, ShapeKit.cylinder(0.03, 0.18, 6), t, _T(Vector3(x, 0.82, 0.95)))
		_add(self, _se(Vector3(0.36, 0.06, 0.18), 0.6), p.darkened(0.08), _T(Vector3(x * 1.6, 0.9, 0.95)))
	# Side flowers (pink petals, yellow centre)
	for sx in [-1.0, 1.0]:
		var fc := Vector3(sx * 0.55, 0.6, 0.1)
		for k in 5:
			var a := TAU * k / 5.0
			_add(self, ShapeKit.sphere(0.06, 8, 5), Color("ff7fb2"), _T(fc + Vector3(0, sin(a) * 0.07, cos(a) * 0.07)))
		_add(self, ShapeKit.sphere(0.05, 8, 5), Color("ffd84d"), _T(fc + Vector3(sx * 0.02, 0, 0)))
	for x in [-0.22, 0.22]:
		var ep := Vector3(x, 0.5, 1.05)
		_add(self, ShapeKit.cone(0.07, 0.09, 0.24, 10), C_CHROME, _T(ep, Vector3(PI * 0.5, 0, 0)), 0.2, 0.9)
		exhaust_points.append(ep + Vector3(0, 0, 0.14))
	w.rf = 0.3
	w.rr = 0.35
	w.rim = Color.WHITE


func _seat_and_wheel(t: Color) -> void:
	_add(self, _se(Vector3(0.54, 0.56, 0.16), 0.4), t.darkened(0.2), _T(Vector3(0, 0.82, 0.48), Vector3(-0.25, 0, 0)))
	steering_wheel = Node3D.new()
	steering_wheel.name = "SteeringColumn"
	steering_wheel.position = Vector3(0, 0.88, -0.3)
	steering_wheel.rotation = Vector3(deg_to_rad(-55.0), 0, 0)
	add_child(steering_wheel)
	steering_spin = Node3D.new()
	steering_spin.name = "SteeringWheel"
	steering_wheel.add_child(steering_spin)
	_add(steering_spin, ShapeKit.torus(0.11, 0.15, 16, 6), Color("2a2d36"), Transform3D.IDENTITY, 0.5)
	_add(steering_spin, _se(Vector3(0.26, 0.03, 0.05), 0.3), def.accent, Transform3D.IDENTITY)


func _parts(p: Color, s: Color, w: Dictionary) -> void:
	if parts.is_empty():
		return
	var gold := Color("f2c14e")
	if "rims_gold" in parts:
		w.rim = gold
	if "spoiler" in parts:
		for x in [-0.42, 0.42]:
			_add(self, ShapeKit.cylinder(0.035, 0.34, 6), C_CHROME, _T(Vector3(x, 0.86, 1.02)), 0.2)
		_add(self, _se(Vector3(1.25, 0.06, 0.32), 0.5), s, _T(Vector3(0, 1.05, 1.06), Vector3(-0.12, 0, 0)))
		for x in [-0.64, 0.64]:
			_add(self, PropKit.box(Vector3(0.04, 0.18, 0.34)), p.darkened(0.2), _T(Vector3(x, 1.06, 1.06)))
	if "twin_exhaust" in parts:
		for x in [-0.42, 0.42]:
			var ep := Vector3(x, 0.38, 1.08)
			_add(self, ShapeKit.cone(0.06, 0.08, 0.26, 10), C_CHROME, _T(ep, Vector3(PI * 0.5, 0, 0)), 0.2, 0.9)
			exhaust_points.append(ep + Vector3(0, 0, 0.15))
	if "flag" in parts:
		# Antenna with a small Azerbaijani flag (blue / red / green).
		_add(self, ShapeKit.cylinder(0.015, 1.0, 5), Color("2a2d36"), _T(Vector3(0.5, 1.0, 0.85)))
		var cols := [Color("00b5e2"), Color("ef3340"), Color("509e2f")]
		for k in 3:
			_add(self, PropKit.box(Vector3(0.02, 0.07, 0.34)), cols[k], _T(Vector3(0.5, 1.44 - k * 0.07, 1.03)))
	if "neon" in parts:
		var neon := Color("3ef2ff")
		for x in [-0.56, 0.56]:
			_add(self, PropKit.box(Vector3(0.04, 0.03, 1.5)), neon, _T(Vector3(x, 0.19, 0.0)), 0.2)
	if "crown" in parts:
		var c := Vector3(0, 1.0, 1.06) if "spoiler" in parts else Vector3(0, 0.82, 0.98)
		_add(self, ShapeKit.cylinder(0.14, 0.08, 10), gold, _T(c + Vector3(0, 0.12, 0)), 0.25, 0.8)
		for k in 5:
			var a := TAU * k / 5.0
			_add(self, ShapeKit.cone(0.04, 0.0, 0.12, 4), gold, _T(c + Vector3(sin(a) * 0.12, 0.22, cos(a) * 0.12)), 0.25, 0.8)


func _wheels(w: Dictionary) -> void:
	# Front wheels: one pivot each (steering). Rear wheels share one axle node
	# because they always spin together (one draw instead of two).
	var axles := [
		[Vector3(-0.62, w.rf, -0.72), [0.0], w.rf, w.wf],
		[Vector3(0.62, w.rf, -0.72), [0.0], w.rf, w.wf],
		[Vector3(0.0, w.rr, 0.68), [-0.66, 0.66], w.rr, w.wr],
	]
	for i in axles.size():
		var d: Array = axles[i]
		var pivot := Node3D.new()
		pivot.position = d[0]
		add_child(pivot)
		var spinner := Node3D.new()
		pivot.add_child(spinner)
		var r: float = d[2]
		var width: float = d[3]
		for ox in d[1]:
			var x: float = ox
			var side := signf(x) if x != 0.0 else signf(d[0].x)
			var o := Vector3(x, 0, 0)
			var rot := Basis(Vector3.FORWARD, PI * 0.5)
			_add(spinner, ShapeKit.superellipsoid(Vector3(r * 2.0, width, r * 2.0), 0.3, 1.0, Vector2.ONE, Vector2.ONE, 6, 18), C_TIRE, Transform3D(rot, o), 0.85)
			if w.tread:
				for k in 8:
					var a := TAU * k / 8.0
					_add(spinner, PropKit.box(Vector3(width * 0.9, 0.05, 0.08)), C_TIRE.lightened(0.08), Transform3D(Basis(Vector3.RIGHT, a), o + Vector3(0, cos(a), sin(a)) * r), 0.9)
			_add(spinner, ShapeKit.cylinder(r * 0.55, width + 0.02, 12), w.rim, Transform3D(rot, o + Vector3(side * 0.005, 0, 0)), 0.3)
			_add(spinner, ShapeKit.cylinder(r * 0.2, width + 0.06, 8), C_CHROME, Transform3D(rot, o + Vector3(side * 0.01, 0, 0)), 0.15)
			_add(spinner, ShapeKit.superellipsoid(Vector3(0.03, r * 0.95, 0.07), 0.3, 0.3), Color("2a2d36"), Transform3D(Basis.IDENTITY, o + Vector3(side * (width * 0.5 + 0.012), 0, 0)))
		wheels.append(pivot)
		wheel_spinners.append(spinner)
		_base_wheel_y.append(d[0].y)


## 0.14.0 glTF tyres: tread blur from the spin per tick (see kart_baked.gdshader).
## The tread repeats every ~0.18 rad; past ~0.06 rad per tick it starts to strobe.
var _tyres: Array[GeometryInstance3D] = []
var _last_spin := 0.0
var _blur := -1.0


static func spin_blur_for(step: float) -> float:
	return smoothstep(0.04, 0.16, absf(step))


func update_wheels(spin_angle: float, steer_yaw: float, susp: float) -> void:
	if not _tyres.is_empty():
		var b := spin_blur_for(spin_angle - _last_spin)
		_last_spin = spin_angle
		if absf(b - _blur) > 0.02:
			_blur = b
			for t in _tyres:
				t.set_instance_shader_parameter(&"spin_blur", b)
	for i in wheels.size():
		var w := wheels[i]
		if i < 2:
			w.rotation.y = steer_yaw
		w.position.y = _base_wheel_y[i] - susp * 0.35
		wheel_spinners[i].rotation.x = spin_angle


func update_driver(steer: float, state: int, victory: bool, delta: float, boosting := false, airborne := false, lean := 0.0) -> void:
	if steering_spin:
		steering_spin.rotation.y = steer * 0.9
	if driver:
		driver.animate(delta, steer, state, victory, boosting, airborne, lean)
