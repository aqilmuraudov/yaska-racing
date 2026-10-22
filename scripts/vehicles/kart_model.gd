class_name KartModel
extends Node3D
## Procedural stylised kart + driver built from rounded primitives.
## Three silhouettes share one wheel/driver rig so animation code is common:
##   balanced ("Bulvar")  – rounded tub, mid wing
##   agile    ("Nar")     – short, tall, round, pomegranate crown
##   fast     ("Külək")   – long, low wedge, big rear wing
## Forward is -Z, origin at ground level.

var wheels: Array[Node3D] = [] # FL, FR, RL, RR (pivot nodes)
var wheel_spinners: Array[Node3D] = []
var exhaust_points: Array[Vector3] = []
var rear_contact_points: Array[Vector3] = []
var shield_radius := 1.45
var driver_root: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var torso: Node3D
var steering_wheel: Node3D
var _base_wheel_y: Array[float] = []
var _time := 0.0

const C_DARK := Color("2a2d36")
const C_METAL := Color("8a8f99")
const C_CHROME := Color("d9dde3")
const C_TIRE := Color("1d1e22")
const C_SKIN := Color("e0ac83")


func build(style: String, paint: Color, is_player: bool) -> void:
	var paint_mat := _paint_material(paint)
	var accent := paint.lightened(0.55) if paint.get_luminance() < 0.6 else paint.darkened(0.45)
	var accent_mat := _paint_material(accent)
	var dark := ShapeKit.mat(C_DARK, 0.55, 0.2)
	var metal := ShapeKit.mat(C_METAL, 0.35, 0.7)
	var chrome := ShapeKit.mat(C_CHROME, 0.2, 0.9)
	var rim_mat := ShapeKit.mat(Color("ffc93c") if style != "fast" else Color("f2f2f2"), 0.3, 0.6)

	var wb_front := -0.72
	var wb_rear := 0.68
	var track_f := 0.62
	var track_r := 0.66
	var r_front := 0.29
	var r_rear := 0.34
	match style:
		"agile":
			wb_front = -0.62
			wb_rear = 0.6
			track_f = 0.6
			track_r = 0.64
			r_rear = 0.33
		"fast":
			wb_front = -0.85
			wb_rear = 0.72
			track_f = 0.6
			track_r = 0.68
			r_front = 0.27
			r_rear = 0.35

	# Floor pan (shared)
	var floor_len := (wb_rear - wb_front) + 0.5
	ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(1.05, 0.14, floor_len), 0.2, 0.25), dark,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.27, (wb_front + wb_rear) * 0.5)))

	match style:
		"agile":
			_build_agile(paint_mat, accent_mat, dark, metal, chrome)
		"fast":
			_build_fast(paint_mat, accent_mat, dark, metal, chrome)
		_:
			_build_balanced(paint_mat, accent_mat, dark, metal, chrome)

	# Wheels
	var tire_mat := ShapeKit.mat(C_TIRE, 0.85)
	var wheel_defs := [
		[Vector3(-track_f, r_front, wb_front), r_front, 0.26],
		[Vector3(track_f, r_front, wb_front), r_front, 0.26],
		[Vector3(-track_r, r_rear, wb_rear), r_rear, 0.34],
		[Vector3(track_r, r_rear, wb_rear), r_rear, 0.34],
	]
	for i in wheel_defs.size():
		var d: Array = wheel_defs[i]
		var pivot := Node3D.new()
		pivot.name = "Wheel%d" % i
		pivot.position = d[0]
		add_child(pivot)
		var spinner := Node3D.new()
		pivot.add_child(spinner)
		var radius: float = d[1]
		var width: float = d[2]
		var tire := ShapeKit.superellipsoid(Vector3(radius * 2.0, width, radius * 2.0), 0.3, 1.0, Vector2.ONE, Vector2.ONE, 6, 18)
		ShapeKit.add_mesh(spinner, tire, tire_mat, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO))
		var side := signf(d[0].x)
		ShapeKit.add_mesh(spinner, ShapeKit.cylinder(radius * 0.55, width + 0.02, 12), rim_mat,
			Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(side * 0.005, 0, 0)))
		ShapeKit.add_mesh(spinner, ShapeKit.cylinder(radius * 0.2, width + 0.06, 8), chrome,
			Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(side * 0.01, 0, 0)))
		# Spoke bar so rotation is visible.
		ShapeKit.add_mesh(spinner, ShapeKit.superellipsoid(Vector3(0.03, radius * 0.95, 0.07), 0.3, 0.3), dark,
			Transform3D(Basis.IDENTITY, Vector3(side * (width * 0.5 + 0.012), 0, 0)))
		wheels.append(pivot)
		wheel_spinners.append(spinner)
		_base_wheel_y.append(d[0].y)
	rear_contact_points = [Vector3(-track_r, 0.05, wb_rear + 0.1), Vector3(track_r, 0.05, wb_rear + 0.1)]

	_build_driver(paint, is_player)


func _paint_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.32
	m.metallic = 0.15
	m.metallic_specular = 0.6
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	return m


func _build_balanced(paint: Material, accent: Material, dark: Material, metal: Material, chrome: Material) -> void:
	ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(0.98, 0.42, 1.55), 0.45, 0.45, Vector2(0.62, 0.62), Vector2(1, 1), 10, 20, -0.04), paint,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.5, -0.05)))
	ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(0.86, 0.2, 0.5), 0.4, 0.5, Vector2(0.75, 0.8)), accent,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.36, -0.95)))
	ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(1.3, 0.1, 0.16), 0.3, 0.3), dark,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.27, -1.12)))
	for x in [-0.56, 0.56]:
		ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(0.26, 0.26, 0.85), 0.4, 0.4, Vector2(0.7, 0.8)), paint,
			Transform3D(Basis.IDENTITY, Vector3(x, 0.42, 0.12)))
	_engine_and_wing(paint, dark, metal, chrome, 0.85, 1.0, 1.12, 0.95)
	_seat_and_wheel(dark, -0.3, 0.86)


func _build_agile(paint: Material, accent: Material, dark: Material, metal: Material, chrome: Material) -> void:
	ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(1.0, 0.5, 1.32), 0.7, 0.6, Vector2(0.72, 0.75), Vector2(1, 1), 12, 20, 0.02), paint,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.55, -0.05)))
	ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(0.7, 0.26, 0.42), 0.6, 0.6), accent,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.42, -0.78)))
	ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(1.2, 0.1, 0.14), 0.3, 0.3), dark,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.28, -0.95)))
	_engine_and_wing(paint, dark, metal, chrome, 0.72, 0.9, 0.95, 0.85)
	# Pomegranate crown on the engine cover: the kart's signature silhouette.
	var crown_mat := ShapeKit.mat(Color("ffc93c"), 0.35, 0.5)
	for i in 5:
		var a := TAU * i / 5.0
		var p := Vector3(cos(a) * 0.17, 0.98, 0.72 + sin(a) * 0.12)
		ShapeKit.add_mesh(self, ShapeKit.cone(0.07, 0.0, 0.2, 6), crown_mat, Transform3D(Basis.IDENTITY, p))
	_seat_and_wheel(dark, -0.26, 0.9)


func _build_fast(paint: Material, accent: Material, dark: Material, metal: Material, chrome: Material) -> void:
	ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(0.92, 0.34, 1.95), 0.4, 0.45, Vector2(0.42, 0.5), Vector2(1, 1), 10, 22, -0.06), paint,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.45, -0.12)))
	ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(1.32, 0.07, 0.4), 0.25, 0.35, Vector2(0.9, 1.0)), accent,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.26, -1.18)))
	for x in [-0.55, 0.55]:
		ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(0.3, 0.3, 1.05), 0.35, 0.4, Vector2(0.55, 0.6)), accent,
			Transform3D(Basis.IDENTITY, Vector3(x, 0.4, 0.15)))
	_engine_and_wing(paint, dark, metal, chrome, 0.92, 1.18, 1.36, 1.05)
	_seat_and_wheel(dark, -0.36, 0.82)


func _engine_and_wing(paint: Material, dark: Material, metal: Material, chrome: Material, engine_z: float, wing_y: float, wing_w: float, wing_z: float) -> void:
	ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(0.72, 0.34, 0.46), 0.35, 0.35), metal,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.58, engine_z)))
	for x in [-0.18, 0.18]:
		var p := Vector3(x, 0.62, engine_z + 0.3)
		ShapeKit.add_mesh(self, ShapeKit.cylinder(0.065, 0.32, 10), chrome, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p))
		exhaust_points.append(p + Vector3(0, 0, 0.18))
	# Wing struts and plate
	for x in [-wing_w * 0.32, wing_w * 0.32]:
		ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(0.05, wing_y - 0.55, 0.1), 0.3, 0.3), dark,
			Transform3D(Basis.IDENTITY, Vector3(x, (wing_y + 0.55) * 0.5, wing_z)))
	ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(wing_w, 0.07, 0.3), 0.25, 0.3, Vector2(1.0, 0.7)), paint,
		Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, wing_y, wing_z)))
	for x in [-wing_w * 0.5, wing_w * 0.5]:
		ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(0.04, 0.22, 0.34), 0.3, 0.3), dark,
			Transform3D(Basis.IDENTITY, Vector3(x, wing_y, wing_z)))


func _seat_and_wheel(dark: Material, wheel_z: float, wheel_y: float) -> void:
	ShapeKit.add_mesh(self, ShapeKit.superellipsoid(Vector3(0.52, 0.55, 0.16), 0.4, 0.4), dark,
		Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 0.82, 0.42)))
	steering_wheel = Node3D.new()
	steering_wheel.position = Vector3(0, wheel_y, wheel_z)
	steering_wheel.rotation = Vector3(deg_to_rad(-55.0), 0, 0)
	add_child(steering_wheel)
	ShapeKit.add_mesh(steering_wheel, ShapeKit.torus(0.11, 0.15, 16, 6), dark, Transform3D.IDENTITY)
	ShapeKit.add_mesh(steering_wheel, ShapeKit.superellipsoid(Vector3(0.26, 0.03, 0.05), 0.3, 0.3), ShapeKit.mat(Color("ffc93c"), 0.4), Transform3D.IDENTITY)


func _build_driver(paint: Color, is_player: bool) -> void:
	var suit := Color("f6ead0") if paint.get_luminance() < 0.5 else Color("1b2a4a")
	var suit_mat := ShapeKit.mat(suit, 0.7)
	var helmet_mat := _paint_material(paint.lightened(0.15))
	var visor_mat := ShapeKit.mat(Color("162238"), 0.1, 0.4)
	var glove_mat := ShapeKit.mat(Color("2a2d36"), 0.6)
	var stripe_mat := ShapeKit.mat(Color("ffc93c") if is_player else Color("ffffff"), 0.4)
	driver_root = Node3D.new()
	driver_root.name = "Driver"
	driver_root.position = Vector3(0, 0.0, 0.18)
	add_child(driver_root)
	torso = Node3D.new()
	torso.position = Vector3(0, 0.78, 0.0)
	driver_root.add_child(torso)
	ShapeKit.add_mesh(torso, ShapeKit.superellipsoid(Vector3(0.48, 0.5, 0.34), 0.6, 0.6, Vector2(1.0, 1.0), Vector2(1.0, 1.0)), suit_mat,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.22, 0)))
	ShapeKit.add_mesh(torso, ShapeKit.superellipsoid(Vector3(0.5, 0.07, 0.36), 0.4, 0.6), stripe_mat,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)))
	head = Node3D.new()
	head.position = Vector3(0, 0.56, -0.02)
	torso.add_child(head)
	ShapeKit.add_mesh(head, ShapeKit.superellipsoid(Vector3(0.44, 0.42, 0.46), 0.85, 0.85, Vector2(1, 1), Vector2(1, 1), 12, 18), helmet_mat,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 0)))
	ShapeKit.add_mesh(head, ShapeKit.superellipsoid(Vector3(0.36, 0.15, 0.2), 0.7, 0.7), visor_mat,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.08, -0.16)))
	ShapeKit.add_mesh(head, ShapeKit.superellipsoid(Vector3(0.08, 0.42, 0.44), 0.85, 0.85), stripe_mat,
		Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0.01)))
	arm_l = _make_arm(suit_mat, glove_mat, -1.0)
	arm_r = _make_arm(suit_mat, glove_mat, 1.0)


func _make_arm(suit_mat: Material, glove_mat: Material, side: float) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.position = Vector3(side * 0.24, 0.38, -0.02)
	torso.add_child(shoulder)
	var arm := Node3D.new()
	shoulder.add_child(arm)
	# Arm reaches forward/down towards the wheel.
	arm.rotation = Vector3(deg_to_rad(-38.0), side * deg_to_rad(-8.0), 0)
	ShapeKit.add_mesh(arm, ShapeKit.superellipsoid(Vector3(0.13, 0.13, 0.44), 0.8, 0.8), suit_mat,
		Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.2)))
	ShapeKit.add_mesh(arm, ShapeKit.sphere(0.075, 10, 6), glove_mat,
		Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.44)))
	return shoulder


func update_wheels(spin_angle: float, steer_yaw: float, susp: float) -> void:
	for i in wheels.size():
		var w := wheels[i]
		if i < 2:
			w.rotation.y = steer_yaw
		w.position.y = _base_wheel_y[i] - susp * 0.35
		wheel_spinners[i].rotation.x = spin_angle


func update_driver(steer: float, state: int, victory: bool, delta: float) -> void:
	_time += delta
	if steering_wheel:
		steering_wheel.rotation.z = -steer * 0.9
	if torso == null:
		return
	var lean := -steer * 0.18
	var arm_raise := 0.0
	var head_turn := -steer * 0.35
	if state == KartController.State.HIT:
		lean = sin(_time * 25.0) * 0.25
		arm_raise = 1.2
	elif state == KartController.State.HOP or state == KartController.State.AIR:
		arm_raise = 0.35
	if victory:
		arm_raise = 2.4 + sin(_time * 9.0) * 0.3
		lean = sin(_time * 4.0) * 0.12
		head_turn = sin(_time * 3.0) * 0.4
	torso.rotation.z = lerp_angle(torso.rotation.z, lean, 1.0 - exp(-10.0 * delta))
	head.rotation.y = lerp_angle(head.rotation.y, head_turn, 1.0 - exp(-8.0 * delta))
	arm_l.rotation.x = lerp_angle(arm_l.rotation.x, arm_raise + steer * 0.25, 1.0 - exp(-12.0 * delta))
	arm_r.rotation.x = lerp_angle(arm_r.rotation.x, arm_raise - steer * 0.25, 1.0 - exp(-12.0 * delta))
