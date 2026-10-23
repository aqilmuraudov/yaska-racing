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
var _drag_velocity := 0.0
var _cam_angle := 0.0
var _wheel: Node3D
var _clouds: Node3D
var _idle_timer := 4.0
var _react := ""
var _react_t := 0.0
var _time := 0.0
var _hop := 0.0


func build() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.42, 0.88)
	sky_mat.sky_horizon_color = Color(0.74, 0.87, 0.98)
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
	e.fog_light_color = Color(0.72, 0.85, 0.98)
	e.fog_aerial_perspective = 0.3
	e.glow_enabled = bool(Settings.get_value("graphics", "bloom", true))
	e.glow_intensity = 0.4
	e.glow_hdr_threshold = 1.1
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.14
	e.adjustment_contrast = 1.06
	env.environment = e
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
	floor_mat.albedo_color = Color(0.86, 0.84, 0.82)
	TextureLibrary.bind(floor_mat, "albedo_texture", "paving")
	floor_mi.material_override = floor_mat
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

	# Turntable: cheerful turquoise disc, gold rim, a ring of warm bulbs.
	turntable = Node3D.new()
	add_child(turntable)
	var disc := MeshInstance3D.new()
	disc.mesh = ShapeKit.cylinder(2.7, 0.28, 48)
	disc.material_override = ShapeKit.mat(Color("17b9c9"), 0.3)
	disc.position = Vector3(0, 0.14, 0)
	turntable.add_child(disc)
	var ring := MeshInstance3D.new()
	ring.mesh = ShapeKit.torus(2.6, 2.85, 48, 8)
	ring.material_override = ShapeKit.mat(Color("ffd23f"), 0.25, 0.4)
	ring.position = Vector3(0, 0.28, 0)
	turntable.add_child(ring)
	for i in 12:
		var bulb := MeshInstance3D.new()
		bulb.mesh = ShapeKit.sphere(0.09, 8, 6)
		bulb.material_override = PropKit.m("lantern")
		var a := TAU * i / 12.0
		bulb.position = Vector3(cos(a) * 2.73, 0.42, sin(a) * 2.73)
		turntable.add_child(bulb)
	kart_holder = Node3D.new()
	kart_holder.position = Vector3(0, 0.28, 0)
	turntable.add_child(kart_holder)
	# Start with a front three-quarter view towards the camera.
	turntable.rotation.y = PI + 0.7

	camera = Camera3D.new()
	camera.fov = 42.0
	camera.position = Vector3(0, 2.2, 7.5)
	camera.look_at_from_position(camera.position, Vector3(0, 0.8, 0))
	add_child(camera)
	camera.current = true


## Shows one racer package. Only the current preview exists; the previous
## one is freed, so the selection screen never holds six animated models.
func show_racer(racer_id: String, greet := true) -> void:
	for c in kart_holder.get_children():
		c.queue_free()
	kart_model = KartModel.new()
	kart_model.build(RacerRoster.get_def(racer_id), true)
	kart_holder.add_child(kart_model)
	if greet and kart_model.driver:
		kart_model.driver.greet()
	kart_holder.scale = Vector3.ONE * 0.85
	var tw := create_tween()
	kart_holder.scale = Vector3.ONE * 0.6
	tw.tween_property(kart_holder, "scale", Vector3.ONE * 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_idle_timer = randf_range(4.0, 6.0)


## Drag-to-rotate support (mouse, touch, right stick).
func drag(amount: float) -> void:
	_drag_velocity = amount
	turntable.rotation.y += amount


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
	_drag_velocity = lerpf(_drag_velocity, 0.0, 1.0 - exp(-4.0 * delta))
	var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(stick) > 0.25:
		turntable.rotation.y += stick * 2.5 * delta
	if _wheel:
		_wheel.rotate_object_local(Vector3.BACK, delta * 0.05)
	if _clouds:
		_clouds.position.x = fmod(_time * 1.5, 100.0)
	if kart_holder:
		# Gentle idle bob so the kart feels alive on its podium.
		kart_holder.position.y = 0.28 + _hop + sin(_time * 2.0) * 0.015
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
			_idle_timer = randf_range(5.5, 8.5)
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
