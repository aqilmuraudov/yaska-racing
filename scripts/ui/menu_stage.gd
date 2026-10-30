class_name MenuStage
extends Node3D
## Lightweight 3D backdrop shared by the menus: the selected racer and kart
## on a turntable on a Boulevard plaza, with the Baku skyline across the bay
## (Flame Towers, Maiden Tower, Crescent, observation wheel, waving flag).
## Subtle ambient motion (wheel, clouds, flag, idle bob) and short idle
## reactions from the driver. Cheap enough to run behind every menu on a phone.

var camera: Camera3D
var turntable: Node3D
var kart_holder: Node3D
var kart_model: KartModel
var auto_rotate := true
var rotation_speed := 0.35
## When set (not NAN) and auto_rotate is off, the turntable eases back to this
## yaw after a drag: PI faces the camera; PI - 0.6 is a 3/4 front view.
var face_angle := NAN
var _face_hold := 0.0
var _drag_velocity := 0.0
var _cam_angle := 0.0
var _wheel: Node3D
var _clouds: Node3D
var _idle_timer := 4.0
var _react := ""
var _react_t := 0.0
var _time := 0.0
var _hop := 0.0
var turntable_mat: ShaderMaterial
const KART_Y := 0.36
var showcase := false
var _env: Environment
var _floor_mat: StandardMaterial3D
var _balloons: Array[Node3D] = []
var _boats: Array[Node3D] = []


const WARM_FLOOR := Color(0.8, 0.6, 0.5)


func build() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Palette.SKY_TOP
	sky_mat.sky_horizon_color = Palette.SKY_HORIZON
	sky_mat.ground_horizon_color = Color(0.74, 0.86, 0.94)
	sky_mat.ground_bottom_color = Color(0.2, 0.35, 0.45)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_density = 0.0012
	e.fog_light_color = Palette.FOG
	e.fog_aerial_perspective = 0.3
	e.glow_enabled = bool(Settings.get_value("graphics", "bloom", true))
	e.glow_intensity = 0.4
	e.glow_hdr_threshold = 1.1
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.adjustment_enabled = true
	e.adjustment_saturation = Palette.ENV_SATURATION
	e.adjustment_contrast = Palette.ENV_CONTRAST
	env.environment = e
	_env = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.74)
	sun.light_energy = 1.55
	sun.rotation = Vector3(deg_to_rad(-34.0), deg_to_rad(-130.0), 0)
	sun.shadow_enabled = int(Settings.get_value("graphics", "shadows", 1)) > 0
	sun.directional_shadow_max_distance = 30.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)

	# Boulevard plaza: textured paving, sea, balustrade, palms and flowers.
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 30)
	floor_mi.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.uv1_scale = Vector3(90.0 / 4.0, 30.0 / 4.0, 1.0)
	floor_mat.roughness = 0.85
	floor_mat.albedo_color = WARM_FLOOR # 0.11.0: warm on every menu screen
	TextureLibrary.bind(floor_mat, "albedo_texture", "paving")
	floor_mi.material_override = floor_mat
	_floor_mat = floor_mat
	floor_mi.position = Vector3(0, 0, -2)
	add_child(floor_mi)
	var sea := MeshInstance3D.new()
	var sea_plane := PlaneMesh.new()
	sea_plane.size = Vector2(1400, 700)
	sea_plane.subdivide_width = 20
	sea_plane.subdivide_depth = 10
	sea.mesh = sea_plane
	var water := ShaderMaterial.new()
	water.shader = preload("res://assets/materials/water.gdshader")
	sea.material_override = water
	sea.position = Vector3(0, -1.4, -360)
	add_child(sea)
	var bal := PropKit.get_mesh("baluster")
	for i in 40:
		var mi := MeshInstance3D.new()
		mi.mesh = bal
		mi.position = Vector3(-40 + i * 2.0, 0, -15)
		add_child(mi)
	for x: float in [-8.5, 9.0, -16.0, 17.0, -24.0, 25.0]:
		var palm := MeshInstance3D.new()
		palm.mesh = PropKit.get_mesh("palm" if int(absf(x)) % 2 == 0 else "palm_b")
		palm.position = Vector3(x, 0, -11.0 + absf(x) * 0.08)
		palm.rotation.y = x
		add_child(palm)
	for x: float in [-4.6, 4.6, -12.5, 13.0]:
		var bed := MeshInstance3D.new()
		bed.mesh = PropKit.get_mesh("flower_bed" if x < 0.0 else "flower_bed_b")
		bed.position = Vector3(x, 0, -7.5)
		bed.add_to_group("menu_bed")
		add_child(bed)
	for x: float in [-20.0, 20.0]:
		var lamp := MeshInstance3D.new()
		lamp.mesh = PropKit.get_mesh("lamp")
		lamp.position = Vector3(x, 0, -12.5)
		add_child(lamp)
	# Skyline across the bay; the national flag waves on its square.
	var sky_items := [
		[LandmarkKit.get_mesh("flame_towers_far"), Transform3D(Basis(Vector3.UP, 0.3), Vector3(-150, 6, -430))],
		[LandmarkKit.get_mesh("crescent_far"), Transform3D(Basis(Vector3.UP, 0.2), Vector3(170, -1.4, -380))],
		[PropKit.get_mesh("maiden_tower"), Transform3D(Basis(Vector3.UP, 0.8), Vector3(-40, 1, -300))],
	]
	for item in sky_items:
		var lm := MeshInstance3D.new()
		lm.mesh = item[0]
		lm.transform = item[1]
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lm)
	var flag_root := Node3D.new()
	flag_root.name = "FlagRoot"
	flag_root.position = Vector3(70, 0, -150)
	add_child(flag_root)
	var square := MeshInstance3D.new()
	square.mesh = LandmarkKit.get_mesh("flag_square")
	square.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flag_root.add_child(square)
	LandmarkKit.attach_flag(flag_root)
	var hills := MeshInstance3D.new()
	hills.mesh = ShapeKit.superellipsoid(Vector3(900, 50, 120), 1.0, 1.0, Vector2.ONE, Vector2.ONE, 8, 16)
	hills.material_override = ShapeKit.mat(Color("7fc25a"), 0.95)
	hills.position = Vector3(0, -14, -520)
	add_child(hills)
	_wheel = MeshInstance3D.new()
	(_wheel as MeshInstance3D).mesh = PropKit.get_mesh("wheel_ring")
	_wheel.position = Vector3(-70, 34, -120)
	add_child(_wheel)
	var wheel_frame := MeshInstance3D.new()
	wheel_frame.name = "WheelFrame"
	wheel_frame.mesh = PropKit.get_mesh("wheel_frame")
	wheel_frame.position = Vector3(-70, 0, -120)
	add_child(wheel_frame)
	_clouds = Node3D.new()
	add_child(_clouds)
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(1, 1, 1)
	cloud_mat.emission_enabled = true
	cloud_mat.emission = Color(0.86, 0.9, 1.0)
	cloud_mat.emission_energy_multiplier = 0.4
	for i in 7:
		var c := MeshInstance3D.new()
		c.mesh = ShapeKit.superellipsoid(Vector3(60, 16, 30), 0.9, 0.9, Vector2.ONE, Vector2.ONE, 5, 8)
		c.material_override = cloud_mat
		c.position = Vector3(-300 + i * 100, 95 + (i % 3) * 18, -420 - (i % 2) * 80)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_clouds.add_child(c)

	# 0.10.2 showroom turntable: glowing blue checker disc, cyan neon ring,
	# a ring of bulbs and four floor spotlights aimed at the kart.
	turntable = Node3D.new()
	add_child(turntable)
	var base := MeshInstance3D.new()
	base.name = "Plinth"
	base.mesh = ShapeKit.cylinder(3.05, 0.16, 48)
	base.material_override = ShapeKit.mat(Color("16306e"), 0.4)
	base.position = Vector3(0, 0.08, 0)
	add_child(base) # the plinth stays still; only the disc turns
	var disc := MeshInstance3D.new()
	disc.name = "Disc"
	disc.mesh = ShapeKit.cylinder(2.7, 0.2, 48)
	turntable_mat = ShaderMaterial.new()
	turntable_mat.shader = preload("res://assets/materials/turntable.gdshader")
	disc.material_override = turntable_mat
	disc.position = Vector3(0, 0.26, 0)
	turntable.add_child(disc)
	var ring := MeshInstance3D.new()
	ring.name = "NeonRing"
	ring.mesh = ShapeKit.torus(2.98, 3.12, 48, 6)
	var neon := StandardMaterial3D.new()
	neon.albedo_color = Color(0.3, 0.85, 1.0)
	neon.emission_enabled = true
	neon.emission = Color(0.3, 0.85, 1.0)
	neon.emission_energy_multiplier = 3.0
	ring.material_override = neon
	ring.position = Vector3(0, 0.17, 0)
	add_child(ring)
	for i in 16:
		var bulb := MeshInstance3D.new()
		bulb.mesh = ShapeKit.sphere(0.07, 8, 6)
		bulb.material_override = PropKit.m("lantern")
		var a := TAU * i / 16.0
		bulb.position = Vector3(cos(a) * 2.9, 0.2, sin(a) * 2.9)
		add_child(bulb)
	_spot_fixtures()
	kart_holder = Node3D.new()
	kart_holder.position = Vector3(0, KART_Y, 0)
	turntable.add_child(kart_holder)
	# Start with a front three-quarter view towards the camera.
	turntable.rotation.y = PI + 0.7

	camera = Camera3D.new()
	camera.fov = 42.0
	camera.position = Vector3(0, 2.2, 7.5)
	camera.look_at_from_position(camera.position, Vector3(0, 0.8, 0))
	add_child(camera)
	camera.current = true


## Four small floor spotlights around the plinth, aimed at the kart, and one
## real (shadowless) spot from above-front so the kart pops.
func _spot_fixtures() -> void:
	var housing := ShapeKit.mat(Color("5a6b8f"), 0.4, 0.6)
	var lens := StandardMaterial3D.new()
	lens.albedo_color = Color(1, 0.96, 0.8)
	lens.emission_enabled = true
	lens.emission = Color(1, 0.92, 0.7)
	lens.emission_energy_multiplier = 4.0
	var beam := StandardMaterial3D.new()
	beam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.albedo_color = Color(0.55, 0.8, 1.0, 0.07)
	for a: float in [0.6, 2.2, 3.9, 5.5]:
		var f := Node3D.new()
		f.name = "SpotFixture"
		f.position = Vector3(cos(a) * 3.45, 0.0, sin(a) * 3.45)
		add_child(f)
		f.look_at(Vector3.ZERO, Vector3.UP)
		var box := MeshInstance3D.new()
		box.mesh = PropKit.rbox(Vector3(0.36, 0.3, 0.3), 0.3)
		box.material_override = housing
		box.position = Vector3(0, 0.18, 0)
		f.add_child(box)
		var l := MeshInstance3D.new()
		l.mesh = ShapeKit.cylinder(0.12, 0.04, 12)
		l.material_override = lens
		l.rotation.x = PI * 0.5
		l.position = Vector3(0, 0.2, -0.16)
		f.add_child(l)
		var cone := MeshInstance3D.new()
		cone.mesh = ShapeKit.cone(0.12, 0.7, 2.0, 16) # stops short of the kart
		cone.material_override = beam
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.rotation.x = -PI * 0.5 + 0.28
		cone.position = Vector3(0, 0.45, -1.0)
		f.add_child(cone)
	var spot := SpotLight3D.new()
	spot.name = "KartSpot"
	spot.light_color = Color(1.0, 0.95, 0.85)
	spot.light_energy = 2.2
	spot.spot_range = 14.0
	spot.spot_angle = 30.0
	spot.shadow_enabled = false
	add_child(spot)
	spot.look_at_from_position(Vector3(1.5, 6.5, 5.0), Vector3(0, 0.6, 0))


static func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadows(c)


## 0.10.2 main-menu backdrop: a busier Baku boulevard close to the camera
## (benches, ornate lamps, balloons, flower beds, a bigger Baku Eye, flag,
## sailboats). Only the main menu calls this.
func build_showcase() -> void:
	if showcase:
		return
	showcase = true
	var sc := Node3D.new()
	sc.name = "Showcase"
	add_child(sc)
	var props := [
		["bench", Vector3(-6.8, 0, -7.6), 0.0], ["bench", Vector3(4.2, 0, -10.6), 0.0],
		["lamp", Vector3(-9.6, 0, -7.0), 0.0], ["lamp", Vector3(6.8, 0, -9.0), 0.0],
		["lamp", Vector3(-3.0, 0, -12.6), 0.0], ["lamp", Vector3(14.0, 0, -12.0), 0.0],
		# 0.11.0: beds only at the near left/right edges (low in the frame),
		# so the sea and the skyline stay open behind the kart.
		["flower_bed", Vector3(-8.6, 0, 0.6), 0.4], ["flower_bed_b", Vector3(7.4, 0, 1.4), -0.5],
		["palm", Vector3(-12.5, 0, -5.0), 1.0], ["palm_b", Vector3(10.5, 0, -6.5), 2.0],
		["palm", Vector3(16.0, 0, -9.0), 0.5],
	]
	for p in props:
		var mi := MeshInstance3D.new()
		mi.mesh = PropKit.get_mesh(p[0])
		mi.position = p[1]
		mi.rotation.y = p[2]
		sc.add_child(mi)
	# Baku Eye: closer and bigger, top-left behind the logo.
	if _wheel:
		_wheel.position = Vector3(-46, 27, -70)
		_wheel.scale = Vector3.ONE * 0.8
		var fr := get_node_or_null("WheelFrame") as Node3D
		if fr:
			fr.position = Vector3(-46, 0, -70)
			fr.scale = Vector3.ONE * 0.8
	for bed in get_tree().get_nodes_in_group("menu_bed"):
		bed.visible = false # the back row hid the sea (0.10.2 weak spot)
	_add_menu_clouds(sc)
	_add_menu_skyline(sc)
	var flag := get_node_or_null("FlagRoot") as Node3D
	if flag:
		flag.position = Vector3(26, 0, -95)
	# Big props close to the camera would throw the whole plaza into shade.
	for n in [sc, _wheel, get_node_or_null("WheelFrame")]:
		if n:
			_no_shadows(n)
	# Balloon bunches (left and right edges).
	var cols := [Color("ff5f6d"), Color("ffd23f"), Color("8b5cf6"), Color("17b9c9"), Color("ff8a1f"), Color("6fcf3c"), Color("ff7ad9")]
	var k := 0
	for site: Vector3 in [Vector3(8.2, 0, -5.4), Vector3(-11.2, 0, -8.6)]:
		for j in 6:
			var b := Node3D.new()
			var off := Vector3(randf_range(-0.6, 0.6), 3.0 + randf_range(0.0, 1.2), randf_range(-0.4, 0.4))
			b.position = site + off
			b.set_meta("y0", b.position.y)
			sc.add_child(b)
			var ball := MeshInstance3D.new()
			ball.mesh = ShapeKit.superellipsoid(Vector3(0.62, 0.74, 0.62), 1.0, 1.0, Vector2.ONE, Vector2.ONE, 8, 12)
			ball.material_override = ShapeKit.mat(cols[k % cols.size()], 0.2)
			ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			b.add_child(ball)
			var string := MeshInstance3D.new()
			string.mesh = ShapeKit.cylinder(0.012, off.y - 0.4, 4)
			string.material_override = ShapeKit.mat(Color(0.95, 0.95, 0.95), 0.8)
			string.position = Vector3(-off.x * 0.5, -(off.y - 0.4) * 0.5 - 0.35, -off.z * 0.5)
			string.rotation = Vector3(-off.z * 0.15, 0, off.x * 0.15)
			b.add_child(string)
			_balloons.append(b)
			k += 1
	# Sailboats on the bay.
	for bp: Vector3 in [Vector3(14, -1.25, -70), Vector3(-6, -1.25, -110), Vector3(38, -1.25, -140)]:
		var boat := MeshInstance3D.new()
		boat.mesh = PropKit.get_mesh("boat")
		boat.position = bp
		boat.scale = Vector3.ONE * 1.6
		boat.rotation.y = bp.x * 0.05
		boat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sc.add_child(boat)
		_boats.append(boat)


## 0.11.0: puffy cartoon clouds low over the bay (each is 3-4 blobs), so the
## sky above the skyline is not empty like in 0.10.2.
func _add_menu_clouds(parent: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.94, 1.0)
	mat.emission_energy_multiplier = 0.55
	mat.roughness = 1.0
	var blob := ShapeKit.superellipsoid(Vector3(1, 1, 1), 1.0, 1.0, Vector2.ONE, Vector2.ONE, 8, 12)
	var sites := [Vector3(-130, 92, -360), Vector3(-25, 112, -400), Vector3(75, 96, -350), Vector3(170, 118, -380), Vector3(-215, 120, -400), Vector3(250, 88, -330)]
	for i in sites.size():
		var root := Node3D.new()
		root.name = "MenuCloud%d" % i
		root.position = sites[i]
		parent.add_child(root)
		var sz := 1.0 + float(i % 3) * 0.25
		for b: Array in [[Vector3(-14, 0, 0), 12.0], [Vector3(0, 5, 2), 16.0], [Vector3(15, 1, 0), 11.0], [Vector3(6, -3, 6), 10.0]]:
			var mi := MeshInstance3D.new()
			mi.mesh = blob
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = b[0] * sz
			mi.scale = Vector3(b[1] * 1.25, b[1] * 0.7, b[1]) * sz
			root.add_child(mi)


## 0.11.0: a row of glass towers across the bay (the downtown skyline seen
## in the mockup), well behind the sea so the water stays visible.
func _add_menu_skyline(parent: Node3D) -> void:
	var ids := ["tower_a", "tower_b", "tower_c"]
	var xs := [-95.0, -70.0, -20.0, 5.0, 30.0, 95.0, 120.0, 215.0, 240.0]
	for i in xs.size():
		var mi := MeshInstance3D.new()
		mi.name = "MenuTower%d" % i
		mi.mesh = PropKit.get_mesh(ids[i % 3])
		mi.position = Vector3(xs[i] * 1.1, -1.4, -480.0 - float(i % 2) * 30.0)
		mi.scale = Vector3.ONE * (0.62 + float(i % 3) * 0.1)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## Shows one racer package. Only the current preview exists; the previous
## one is freed, so the selection screen never holds six animated models.
func show_racer(racer_id: String, greet := true, paint := -1) -> void:
	for c in kart_holder.get_children():
		c.queue_free()
	kart_model = KartModel.new()
	kart_model.parts = Progression.equipped_parts(SaveManager.data)
	var p := SaveManager.get_paint(racer_id) if paint < 0 else paint
	kart_model.build(KartPaints.painted(RacerRoster.get_def(racer_id), p), true)
	kart_holder.add_child(kart_model)
	if greet and kart_model.driver:
		kart_model.driver.greet()
	kart_holder.scale = Vector3.ONE * 0.85
	var tw := create_tween()
	kart_holder.scale = Vector3.ONE * 0.6
	tw.tween_property(kart_holder, "scale", Vector3.ONE * 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_idle_timer = randf_range(4.0, 6.0)
	if not is_nan(face_angle) and not auto_rotate:
		turntable.rotation.y = face_angle # every racer starts in the same 3/4 front view
		_face_hold = 0.0


## Drag-to-rotate support (mouse, touch, right stick). While `held` the
## finger drives the turntable directly; on release the last speed carries
## on as inertia and decays (then the view eases back to `face_angle`).
var held := false
var idle_motion := false ## gentle continuous sway (racer select hero)


## Flick inertia cap (rad/s): a flick adds at most ~1 turn-third after release.
const MAX_SPIN := 5.0


func drag(amount: float) -> void:
	var dt := maxf(get_process_delta_time(), 1.0 / 120.0)
	_drag_velocity = clampf(lerpf(_drag_velocity, amount / dt, 0.5), -MAX_SPIN, MAX_SPIN)
	_face_hold = 2.5
	turntable.rotation.y += amount


func release_drag() -> void:
	held = false


## Main-menu framing: the kart sits right of centre and a little low, the
## boulevard and sea fill the left behind the logo.
func frame_showcase() -> void:
	if _env:
		# Punchier, sunnier colours for the title screen (the mockup's look).
		_env.adjustment_saturation = Palette.ENV_SATURATION * 1.25
		_env.adjustment_contrast = Palette.ENV_CONTRAST * 1.1
		_env.fog_density = 0.0004
		_env.fog_aerial_perspective = 0.1
	if _floor_mat:
		_floor_mat.albedo_color = WARM_FLOOR # warm sandstone paving
	# Open on a side view that turns into a front three-quarter within a few
	# seconds (the camera sits left of the kart).
	if turntable:
		turntable.rotation.y = PI - 1.25
	_fit_aspect()
	if not get_viewport().size_changed.is_connected(_fit_aspect):
		get_viewport().size_changed.connect(_fit_aspect)
	camera.position = Vector3(-2.5, 2.0, 6.7)
	# 0.11.0: flatter look (1.05 -> 1.4) lifts the horizon to ~42 % like
	# the mockup, so more bay and sky show above the kart.
	camera.look_at_from_position(camera.position, Vector3(-2.15, 1.4, 0))


## Narrow screens (4:3 tablets) keep the 16:9 horizontal view so the kart on
## the right is never cut off; wide phones keep the height.
func _fit_aspect() -> void:
	if camera == null or not is_inside_tree():
		return
	var vs := get_viewport().get_visible_rect().size
	var aspect := vs.x / maxf(vs.y, 1.0)
	if aspect < 16.0 / 9.0 - 0.01:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(22.0)) * 16.0 / 9.0))
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 44.0


func set_camera_offset(x: float) -> void:
	# Shift the framing so the kart sits beside a side panel.
	camera.position.x = x
	camera.look_at_from_position(camera.position, Vector3(x * 0.55, 0.8, 0))


func _process(delta: float) -> void:
	if turntable == null:
		return
	_time += delta
	if auto_rotate:
		turntable.rotation.y += rotation_speed * delta
	elif not is_nan(face_angle):
		_face_hold = maxf(_face_hold - delta, 0.0)
		if _face_hold <= 0.0:
			turntable.rotation.y = lerp_angle(turntable.rotation.y, face_angle, 1.0 - exp(-3.0 * delta))
	if not held and absf(_drag_velocity) > 0.01:
		turntable.rotation.y += _drag_velocity * delta # inertia after a flick
		_face_hold = maxf(_face_hold, 1.5)
	_drag_velocity = lerpf(_drag_velocity, 0.0, 1.0 - exp(-(3.0 if not held else 6.0) * delta))
	var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(stick) > 0.25:
		turntable.rotation.y += stick * 2.5 * delta
	if _wheel:
		_wheel.rotate_object_local(Vector3.BACK, delta * 0.05)
	if turntable_mat:
		turntable_mat.set_shader_parameter("pulse", 0.6 + sin(_time * 2.2) * 0.6)
	for i in _balloons.size():
		var b := _balloons[i]
		b.position.y = b.get_meta("y0") + sin(_time * 1.1 + i * 1.7) * 0.12
		b.rotation.z = sin(_time * 0.9 + i) * 0.06
	for i in _boats.size():
		_boats[i].rotation.z = sin(_time * 0.8 + i * 2.0) * 0.03
	if _clouds:
		_clouds.position.x = fmod(_time * 1.5, 100.0)
	if kart_holder:
		# Gentle idle bob so the kart feels alive on its podium.
		kart_holder.position.y = KART_Y + _hop + sin(_time * 2.0) * (0.035 if idle_motion else 0.015)
		if idle_motion:
			# Breathing sway: a slow lean and yaw wobble so the hero never
			# looks frozen (no effect on the drag / face angle).
			kart_holder.rotation.z = sin(_time * 1.3) * 0.035
			kart_holder.rotation.y = sin(_time * 0.7) * 0.08
	_update_idle_reactions(delta)


## Short idle reactions every few seconds: a wave, a playful steering wiggle,
## a little cheer or an excited lean. Never continuous.
func _update_idle_reactions(delta: float) -> void:
	if kart_model == null:
		return
	var steer := 0.0
	var cheer := false
	var boost := false
	if _react != "":
		_react_t -= delta
		match _react:
			"wiggle":
				steer = sin(_react_t * 14.0) * 0.8
			"cheer":
				cheer = true
			"boost":
				boost = true
		if _react_t <= 0.0:
			_react = ""
	else:
		_idle_timer -= delta
		if _idle_timer <= 0.0 and absf(_drag_velocity) < 0.01:
			_idle_timer = randf_range(2.5, 4.5) if idle_motion else randf_range(5.5, 8.5)
			var pick: String = ["wiggle", "cheer", "greet", "boost"][randi() % 4]
			if pick == "greet":
				if kart_model.driver:
					kart_model.driver.greet()
			else:
				_react = pick
				_react_t = 1.3
	kart_model.update_driver(steer, KartController.State.NORMAL, cheer, delta, boost)


## A quick celebratory hop and cheer (used when a racer is chosen).
func celebrate() -> void:
	_react = "cheer"
	_react_t = 1.2
	var tw := create_tween()
	tw.tween_property(self, "_hop", 0.6, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_hop", 0.0, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
