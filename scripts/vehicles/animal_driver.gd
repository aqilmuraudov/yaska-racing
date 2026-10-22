class_name AnimalDriver
extends Node3D
## Stylised animal driver (panda, fox, rabbit, cat, dog, lamb) built from a
## few rounded meshes, with a shared lightweight procedural animation set:
## breathing, blinking, steering with paws held on the wheel rim, leaning,
## jump/landing, boost excitement, hit wobble, victory, and cheap secondary
## motion on ears and tail. Parts are merged per animated node so a driver
## costs only a handful of draw calls.

const HEAD_Y := 0.40

var def: RacerDefinition
var torso: Node3D
var head: Node3D
var eyes: Array[Node3D] = []
var ears: Array[Node3D] = []
var tail: Node3D
var arms: Array[Node3D] = [] # shoulder pivots (L, R)
var steering_wheel: Node3D # set by KartModel
var arm_length := 0.40
var _accums := {}
var _time := 0.0
var _blink_t := 2.0
var _blink := 0.0
var _greet := 0.0
var _ear_rest: Array[Vector3] = []
var _tail_rest := Vector3.ZERO
var _land := 0.0
static var _vcolor: ShaderMaterial
static var _eye_mat: StandardMaterial3D


func build(p_def: RacerDefinition) -> void:
	def = p_def
	name = "Driver"
	torso = _node(self, Vector3(0, 0.66, 0))
	head = _node(torso, Vector3(0, HEAD_Y, -0.02))
	_body()
	_head_shape()
	_face()
	_ears()
	_tail()
	_arms()
	_accessory()
	_flush()
	for e in ears:
		_ear_rest.append(e.rotation)
	if tail:
		_tail_rest = tail.rotation


func _node(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _add(parent: Node3D, mesh: Mesh, color: Color, xform: Transform3D, rough := 0.75) -> void:
	if not _accums.has(parent):
		_accums[parent] = PropKit.Accum.new()
	_accums[parent].add(mesh, xform, ShapeKit.mat(color, rough))


func _flush() -> void:
	if _vcolor == null:
		_vcolor = ShaderMaterial.new()
		_vcolor.shader = preload("res://assets/materials/vcolor.gdshader")
		_vcolor.set_shader_parameter("rim_amount", 0.35)
	for n in _accums.keys():
		var mi := MeshInstance3D.new()
		mi.mesh = _accums[n].commit(_vcolor)
		# Small detail (eyes, ears, tail, arms) is invisible at distance:
		# skip drawing it far away; silhouettes come from head and body.
		if n != torso and n != head:
			mi.visibility_range_end = 45.0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	_accums.clear()


static func blob(size: Vector3, round_v := 0.9, round_h := 0.9) -> Mesh:
	return ShapeKit.superellipsoid(size, round_v, round_h, Vector2.ONE, Vector2.ONE, 8, 12)


static func T(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scl), pos)


# --- Body ---------------------------------------------------------------------

func _body() -> void:
	var main := def.fur_main
	var light := def.fur_light
	match def.species:
		"panda":
			_add(torso, blob(Vector3(0.46, 0.44, 0.36)), def.fur_dark, T(Vector3(0, 0.2, 0)))
			_add(torso, blob(Vector3(0.38, 0.32, 0.2)), main, T(Vector3(0, 0.2, -0.1)))
		"lamb":
			# Wool body: a few overlapping puffs read as fleece without fur cost.
			for p in [Vector3(0, 0.2, 0), Vector3(-0.14, 0.26, -0.02), Vector3(0.14, 0.26, -0.02), Vector3(0, 0.33, 0.05), Vector3(-0.1, 0.12, -0.06), Vector3(0.1, 0.12, -0.06)]:
				_add(torso, blob(Vector3(0.24, 0.22, 0.24)), main, T(p))
		_:
			_add(torso, blob(Vector3(0.42, 0.44, 0.34)), main, T(Vector3(0, 0.2, 0)))
			_add(torso, blob(Vector3(0.28, 0.3, 0.12)), light, T(Vector3(0, 0.18, -0.13)))
	# Neck scarf / collar in the racer's detail colour
	_add(torso, ShapeKit.torus(0.13, 0.21, 16, 6), def.detail if def.species != "panda" else Color("6fd6a8"), T(Vector3(0, 0.39, 0), Vector3.ZERO, Vector3(1, 1.2, 1)))


func _head_shape() -> void:
	var main := def.fur_main
	match def.species:
		"fox":
			_add(head, blob(Vector3(0.56, 0.48, 0.5), 0.8, 0.8), main, T(Vector3(0, 0.12, 0)))
			# Cheek ruffs
			for sx in [-1.0, 1.0]:
				_add(head, ShapeKit.cone(0.1, 0.0, 0.2, 6), def.fur_light, T(Vector3(sx * 0.27, 0.02, 0.02), Vector3(0, 0, sx * 1.9)))
		"rabbit":
			_add(head, blob(Vector3(0.52, 0.5, 0.48), 0.85, 0.85), main, T(Vector3(0, 0.12, 0)))
		"lamb":
			_add(head, blob(Vector3(0.46, 0.46, 0.44), 0.9, 0.9), def.fur_light, T(Vector3(0, 0.1, 0)))
			# Wool cap
			for p in [Vector3(0, 0.32, 0.02), Vector3(-0.14, 0.27, 0.04), Vector3(0.14, 0.27, 0.04), Vector3(0, 0.27, -0.12), Vector3(-0.1, 0.22, 0.17), Vector3(0.1, 0.22, 0.17), Vector3(0, 0.16, 0.22)]:
				_add(head, blob(Vector3(0.2, 0.18, 0.2)), def.fur_main, T(p))
		"panda":
			_add(head, blob(Vector3(0.6, 0.54, 0.54), 0.9, 0.9), main, T(Vector3(0, 0.12, 0)))
		"cat":
			_add(head, blob(Vector3(0.6, 0.5, 0.52), 0.8, 0.85), main, T(Vector3(0, 0.12, 0)))
			# Forehead and back-of-head stripes (visible from the chase camera)
			for i in 3:
				_add(head, blob(Vector3(0.05, 0.03, 0.2), 0.5, 0.5), def.fur_dark, T(Vector3((i - 1) * 0.08, 0.37, -0.02 + absf(i - 1) * 0.02), Vector3(0.2, 0, 0)))
			for i in 3:
				_add(head, blob(Vector3(0.36, 0.035, 0.06), 0.5, 0.5), def.fur_dark, T(Vector3(0, 0.2 + i * 0.07, 0.25), Vector3(-0.3, 0, 0)))
		_: # dog
			_add(head, blob(Vector3(0.58, 0.52, 0.52), 0.85, 0.9), main, T(Vector3(0, 0.12, 0)))


func _face() -> void:
	var front := -0.25
	var light := def.fur_light
	var nose_col := Color("2b1d1a")
	# Muzzles / face patches
	match def.species:
		"fox":
			_add(head, ShapeKit.superellipsoid(Vector3(0.24, 0.16, 0.26), 0.7, 0.7, Vector2(0.45, 0.6), Vector2.ONE, 8, 10), light, T(Vector3(0, 0.02, front - 0.06)))
			_add(head, blob(Vector3(0.3, 0.14, 0.08)), light, T(Vector3(0, -0.02, front + 0.02)))
		"dog":
			_add(head, blob(Vector3(0.26, 0.18, 0.18)), light, T(Vector3(0, 0.02, front - 0.02)))
		"cat":
			for sx in [-1.0, 1.0]:
				_add(head, blob(Vector3(0.12, 0.1, 0.1)), light, T(Vector3(sx * 0.055, 0.02, front - 0.01)))
			nose_col = Color("ff8fa3")
		"panda":
			_add(head, blob(Vector3(0.24, 0.16, 0.14)), Color.WHITE, T(Vector3(0, 0.03, front)))
			# Eye patches
			for sx in [-1.0, 1.0]:
				_add(head, blob(Vector3(0.15, 0.18, 0.06), 0.9, 0.9), def.fur_dark, T(Vector3(sx * 0.12, 0.16, front + 0.02), Vector3(0, 0, sx * -0.4)))
		"rabbit":
			for sx in [-1.0, 1.0]:
				_add(head, blob(Vector3(0.1, 0.09, 0.08)), light, T(Vector3(sx * 0.05, 0.03, front)))
			nose_col = Color("ff8fa3")
		"lamb":
			_add(head, blob(Vector3(0.24, 0.16, 0.12)), light.lightened(0.15), T(Vector3(0, 0.02, front + 0.03)))
			nose_col = Color("6b4a3a")
	var nose_z := front - (0.17 if def.species == "fox" else 0.09)
	_add(head, blob(Vector3(0.07, 0.05, 0.05)), nose_col, T(Vector3(0, 0.08 if def.species == "fox" else 0.07, nose_z)), 0.3)
	# Smile
	_add(head, blob(Vector3(0.07, 0.02, 0.02), 0.5, 0.5), Color("3a2420"), T(Vector3(0, -0.01, nose_z + 0.03), Vector3(0, 0, 0)))
	# Blush
	for sx in [-1.0, 1.0]:
		_add(head, blob(Vector3(0.08, 0.04, 0.03)), Color("ff9eb0"), T(Vector3(sx * 0.17, 0.05, front + 0.05)))
	# Eyes: separate nodes so they can blink.
	if _eye_mat == null:
		_eye_mat = StandardMaterial3D.new()
	# Both eyes share one node: one draw, blinking scales them together.
	var e := _node(head, Vector3(0, 0.16, front))
	for sx in [-1.0, 1.0]:
		var c := Vector3(sx * 0.115, 0, 0)
		_add(e, blob(Vector3(0.11, 0.13, 0.05)), Color.WHITE, T(c), 0.2)
		_add(e, blob(Vector3(0.075, 0.095, 0.04)), Color("1d1a22"), T(c + Vector3(sx * -0.008, -0.008, -0.018)), 0.15)
		_add(e, blob(Vector3(0.028, 0.032, 0.02)), Color.WHITE, T(c + Vector3(sx * -0.02, 0.022, -0.04)), 0.1)
	eyes.append(e)


func _ears() -> void:
	var main := def.fur_main
	match def.species:
		"panda":
			for sx in [-1.0, 1.0]:
				var e := _node(head, Vector3(sx * 0.22, 0.34, 0.02))
				_add(e, ShapeKit.superellipsoid(Vector3(0.15, 0.15, 0.08), 0.9, 0.9), def.fur_dark, T(Vector3.ZERO))
				ears.append(e)
		"fox":
			for sx in [-1.0, 1.0]:
				var e := _node(head, Vector3(sx * 0.16, 0.33, 0.02))
				e.rotation = Vector3(0, 0, sx * -0.3)
				_add(e, ShapeKit.cone(0.1, 0.0, 0.28, 4), main, T(Vector3(0, 0.12, 0), Vector3(0, PI * 0.25, 0), Vector3(1, 1, 0.6)))
				_add(e, ShapeKit.cone(0.045, 0.0, 0.1, 4), def.fur_dark, T(Vector3(0, 0.23, 0), Vector3(0, PI * 0.25, 0), Vector3(1, 1, 0.65)))
				_add(e, ShapeKit.cone(0.06, 0.0, 0.16, 4), def.fur_light, T(Vector3(0, 0.1, -0.025), Vector3(0, PI * 0.25, 0), Vector3(1, 1, 0.3)))
				ears.append(e)
		"rabbit":
			for sx in [-1.0, 1.0]:
				var e := _node(head, Vector3(sx * 0.1, 0.34, 0.04))
				e.rotation = Vector3(-0.15, 0, sx * -0.18)
				_add(e, ShapeKit.superellipsoid(Vector3(0.12, 0.42, 0.07), 0.8, 0.9), main, T(Vector3(0, 0.2, 0)))
				_add(e, ShapeKit.superellipsoid(Vector3(0.065, 0.32, 0.03), 0.8, 0.9), def.detail, T(Vector3(0, 0.19, -0.03)))
				ears.append(e)
		"cat":
			for sx in [-1.0, 1.0]:
				var e := _node(head, Vector3(sx * 0.18, 0.31, 0.02))
				e.rotation = Vector3(0, 0, sx * -0.25)
				_add(e, ShapeKit.cone(0.1, 0.0, 0.18, 4), main, T(Vector3(0, 0.08, 0), Vector3(0, PI * 0.25, 0), Vector3(1, 1, 0.6)))
				_add(e, ShapeKit.cone(0.055, 0.0, 0.11, 4), def.detail, T(Vector3(0, 0.07, -0.025), Vector3(0, PI * 0.25, 0), Vector3(1, 1, 0.3)))
				ears.append(e)
		"dog":
			for sx in [-1.0, 1.0]:
				var e := _node(head, Vector3(sx * 0.27, 0.26, 0.03))
				e.rotation = Vector3(0, 0, sx * 0.35)
				_add(e, ShapeKit.superellipsoid(Vector3(0.13, 0.3, 0.07), 0.85, 0.9), def.fur_dark, T(Vector3(0, -0.12, 0)))
				ears.append(e)
		"lamb":
			for sx in [-1.0, 1.0]:
				var e := _node(head, Vector3(sx * 0.24, 0.16, 0.02))
				e.rotation = Vector3(0, 0, sx * 1.1)
				_add(e, ShapeKit.superellipsoid(Vector3(0.08, 0.17, 0.05), 0.85, 0.9), def.fur_light, T(Vector3(0, -0.07, 0)))
				_add(e, ShapeKit.superellipsoid(Vector3(0.045, 0.11, 0.02), 0.85, 0.9), def.detail, T(Vector3(0, -0.07, -0.02)))
				ears.append(e)


func _tail() -> void:
	# Tails sit above the seat back so they read from the chase camera.
	tail = _node(torso, Vector3(0, 0.1, 0.2))
	match def.species:
		"fox":
			tail.rotation = Vector3(-0.9, 0.35, 0)
			_add(tail, ShapeKit.superellipsoid(Vector3(0.2, 0.2, 0.5), 0.9, 0.9, Vector2(0.7, 0.7), Vector2(1, 1)), def.fur_main, T(Vector3(0, 0, 0.25)))
			_add(tail, ShapeKit.superellipsoid(Vector3(0.16, 0.16, 0.16), 0.9, 0.9), def.fur_light, T(Vector3(0, 0, 0.52)))
		"cat":
			tail.rotation = Vector3(-1.1, 0, 0)
			_add(tail, ShapeKit.cone(0.045, 0.04, 0.42, 8), def.fur_main, T(Vector3(0, 0.21, 0)))
			_add(tail, ShapeKit.cone(0.04, 0.035, 0.2, 8), def.fur_main, T(Vector3(0.05, 0.47, 0.05), Vector3(0.6, 0, -0.5)))
			_add(tail, blob(Vector3(0.09, 0.07, 0.09)), def.fur_dark, T(Vector3(0.1, 0.56, 0.1)))
		"dog":
			tail.rotation = Vector3(-0.7, 0, 0)
			_add(tail, ShapeKit.cone(0.05, 0.03, 0.3, 8), def.fur_main, T(Vector3(0, 0.15, 0)))
			_add(tail, blob(Vector3(0.08, 0.08, 0.08)), def.fur_light, T(Vector3(0, 0.3, 0)))
		"rabbit":
			_add(tail, blob(Vector3(0.16, 0.16, 0.14)), Color.WHITE, T(Vector3(0, -0.02, 0.02)))
		"lamb":
			_add(tail, blob(Vector3(0.14, 0.14, 0.12)), def.fur_main, T(Vector3(0, -0.02, 0.02)))
		"panda":
			_add(tail, blob(Vector3(0.12, 0.12, 0.1)), def.fur_main, T(Vector3(0, -0.04, 0.0)))


func _arms() -> void:
	var col := def.fur_dark if def.species == "panda" else def.fur_main
	var paw := def.fur_dark if def.species in ["panda"] else def.fur_light
	if def.species == "lamb":
		col = def.fur_main
		paw = def.fur_dark
	for sx in [-1.0, 1.0]:
		var sh := _node(torso, Vector3(sx * 0.2, 0.32, -0.03))
		var arm := _node(sh, Vector3.ZERO)
		arm.name = "Arm"
		_add(arm, ShapeKit.superellipsoid(Vector3(0.12, 0.12, arm_length), 0.85, 0.85), col, T(Vector3(0, 0, -arm_length * 0.5)))
		_add(arm, blob(Vector3(0.11, 0.1, 0.11)), paw, T(Vector3(0, 0, -arm_length)))
		arms.append(sh)


func _accessory() -> void:
	match def.species:
		"panda":
			# Bamboo sprig with mint leaves tucked behind the ear
			_add(head, ShapeKit.cylinder(0.025, 0.26, 6), Color("7bb661"), T(Vector3(0.2, 0.38, 0.1), Vector3(0.3, 0, -0.5)))
			for i in 2:
				_add(head, ShapeKit.superellipsoid(Vector3(0.05, 0.015, 0.14), 0.6, 0.6), Color("5fd3a8"), T(Vector3(0.26 + i * 0.03, 0.5, 0.12), Vector3(0.4, i * 1.2, 0.2)))
		"fox":
			_add(torso, ShapeKit.superellipsoid(Vector3(0.12, 0.2, 0.06), 0.7, 0.7), def.detail, T(Vector3(0.06, 0.28, 0.17), Vector3(0.3, 0, 0.2)))
		"rabbit":
			# Goggles band
			_add(head, ShapeKit.torus(0.255, 0.285, 20, 4), Color("ffd23f"), T(Vector3(0, 0.24, 0.0), Vector3(0.18, 0, 0), Vector3(1.0, 1.0, 0.95)))
		"cat":
			_add(head, blob(Vector3(0.14, 0.08, 0.06)), def.detail, T(Vector3(0.17, 0.36, 0.06), Vector3(0, 0, -0.4)))
		"dog":
			_add(torso, ShapeKit.cylinder(0.04, 0.015, 10), Color("ffc93c"), T(Vector3(0, 0.33, -0.17), Vector3(PI * 0.5, 0, 0)), 0.3)
		"lamb":
			_add(head, blob(Vector3(0.12, 0.07, 0.06)), def.detail, T(Vector3(-0.13, 0.36, 0.0), Vector3(0, 0, 0.5)))
			_add(head, blob(Vector3(0.12, 0.07, 0.06)), def.detail, T(Vector3(-0.03, 0.36, 0.0), Vector3(0, 0, -0.5)))


# --- Animation ------------------------------------------------------------------

func greet() -> void:
	_greet = 1.2


func land(strength: float) -> void:
	_land = clampf(strength, 0.0, 1.0)


## steer -1..1, state = KartController.State, flags for boost / air / victory.
func animate(delta: float, steer: float, state: int, victory: bool, boosting: bool, airborne: bool, lean: float) -> void:
	_time += delta
	# Blink
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink = 0.14
		_blink_t = randf_range(2.0, 4.5)
	if _blink > 0.0:
		_blink -= delta
	var lid := 0.12 if _blink > 0.0 else 1.0
	for e in eyes:
		e.scale.y = lerpf(e.scale.y, lid, 1.0 - exp(-40.0 * delta))
	# Breathing and lean
	var breathe := 1.0 + sin(_time * 2.4) * 0.025
	var bounce := 0.0
	var hit := state == KartController.State.HIT
	_greet = maxf(_greet - delta, 0.0)
	_land = maxf(_land - delta * 3.0, 0.0)
	if victory:
		bounce = absf(sin(_time * 6.0)) * 0.06
	torso.scale = Vector3(1.0 / sqrt(breathe), breathe, 1.0 / sqrt(breathe)) * (1.0 - _land * 0.08)
	torso.position.y = 0.66 + bounce - _land * 0.04
	var target_roll := -steer * 0.12 + lean
	if hit:
		target_roll = sin(_time * 22.0) * 0.25
	torso.rotation.z = lerp_angle(torso.rotation.z, target_roll, 1.0 - exp(-10.0 * delta))
	# Head looks into turns; greeting nod; boost tilts back with excitement
	var head_yaw := -steer * 0.35
	var head_pitch := 0.0
	if boosting:
		head_pitch = -0.12
	if _greet > 0.0:
		head_pitch += sin(_greet * 10.0) * 0.18
		head_yaw += sin(_greet * 5.0) * 0.2
	if hit:
		head_yaw = sin(_time * 18.0) * 0.5
	if victory:
		head_yaw = sin(_time * 3.0) * 0.4
		head_pitch = -0.15
	head.rotation = Vector3(lerp_angle(head.rotation.x, head_pitch, 1.0 - exp(-8.0 * delta)), lerp_angle(head.rotation.y, head_yaw, 1.0 - exp(-8.0 * delta)), 0.0)
	# Ears: subtle wobble, swept back while boosting, perk up on greet
	for i in ears.size():
		var rest: Vector3 = _ear_rest[i]
		var side := -1.0 if i == 0 else 1.0
		var wob := sin(_time * 3.1 + i) * 0.05
		var back := 0.35 if boosting else 0.0
		if airborne:
			back = -0.2
		if _greet > 0.0:
			wob += sin(_greet * 14.0) * 0.25
		ears[i].rotation = Vector3(rest.x + back + wob, rest.y, rest.z + side * wob * 0.5)
	# Tail sway / wag (dog wags harder)
	if tail:
		var amp := 0.5 if def.species == "dog" else 0.18
		var spd := 9.0 if def.species == "dog" else 2.5
		if victory or _greet > 0.0:
			amp *= 1.8
		tail.rotation = _tail_rest + Vector3(0, sin(_time * spd) * amp, steer * 0.2)
	_animate_arms(steer, victory, hit, airborne)


## Paws track grip points on the steering-wheel rim (no clipping through it);
## celebrations raise them instead.
func _animate_arms(steer: float, victory: bool, hit: bool, airborne: bool) -> void:
	for i in arms.size():
		var sh := arms[i]
		var side := -1.0 if i == 0 else 1.0
		var target_global: Vector3
		if victory or hit:
			var up_local := Vector3(side * 0.35, 0.9 + (sin(_time * 8.0 + i * PI) * 0.1 if victory else 0.0), -0.1)
			target_global = torso.global_transform * up_local
		elif steering_wheel:
			# Grip points on the rim in the wheel's own plane.
			var grip := Vector3(side * 0.13, 0.03, 0.0) # on the rim, turns with the wheel
			target_global = steering_wheel.global_transform * grip
			if airborne:
				target_global += Vector3.UP * 0.05
		else:
			continue
		var arm: Node3D = sh.get_child(0)
		var local_target := sh.global_transform.affine_inverse() * target_global
		if local_target.length() < 0.01:
			continue
		var dir := local_target.normalized()
		arm.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.BACK)
		# Reach: arms never stretch beyond their length; slight bend if close.
		arm.scale = Vector3.ONE * clampf(local_target.length() / arm_length, 0.75, 1.05)
