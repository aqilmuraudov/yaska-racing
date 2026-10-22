class_name MenuStage
extends Node3D
## Lightweight 3D backdrop shared by the menus: a kart on a turntable on the
## Boulevard promenade, palms, balustrade, sea and the distant skyline.
## Cheap enough to run behind every menu screen on a phone.

var camera: Camera3D
var turntable: Node3D
var kart_holder: Node3D
var kart_model: KartModel
var auto_rotate := true
var rotation_speed := 0.35
var _drag_velocity := 0.0
var _cam_angle := 0.0
var _wheel: Node3D


func build() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.52, 0.86)
	sky_mat.sky_horizon_color = Color(0.85, 0.82, 0.86)
	sky_mat.ground_horizon_color = Color(0.74, 0.84, 0.9)
	sky_mat.ground_bottom_color = Color(0.2, 0.35, 0.45)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_density = 0.004
	e.fog_light_color = Color(0.85, 0.85, 0.9)
	e.fog_aerial_perspective = 0.4
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.12
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.light_energy = 1.3
	sun.rotation = Vector3(deg_to_rad(-30.0), deg_to_rad(-120.0), 0)
	sun.shadow_enabled = int(Settings.get_value("graphics", "shadows", 1)) > 0
	sun.directional_shadow_max_distance = 30.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)

	# Promenade floor and sea
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 26)
	floor_mi.mesh = plane
	floor_mi.material_override = ShapeKit.mat(Color("e4d6b8"), 0.9)
	floor_mi.position = Vector3(0, 0, -2)
	add_child(floor_mi)
	var sea := MeshInstance3D.new()
	var sea_plane := PlaneMesh.new()
	sea_plane.size = Vector2(1200, 600)
	sea_plane.subdivide_width = 20
	sea_plane.subdivide_depth = 10
	sea.mesh = sea_plane
	var water := ShaderMaterial.new()
	water.shader = preload("res://assets/materials/water.gdshader")
	sea.material_override = water
	sea.position = Vector3(0, -1.4, -310)
	add_child(sea)
	# Balustrade along the sea edge (behind the kart)
	var bal := PropKit.get_mesh("baluster")
	for i in 30:
		var mi := MeshInstance3D.new()
		mi.mesh = bal
		mi.position = Vector3(-30 + i * 2.0, 0, -12)
		add_child(mi)
	for x in [-9.0, 9.5, -17.0, 18.0]:
		var palm := MeshInstance3D.new()
		palm.mesh = PropKit.get_mesh("palm" if int(x) % 2 == 0 else "palm_b")
		palm.position = Vector3(x, 0, -9.5 + absf(x) * 0.1)
		palm.rotation.y = x
		add_child(palm)
	for x in [-5.0, 5.0]:
		var lamp := MeshInstance3D.new()
		lamp.mesh = PropKit.get_mesh("lamp")
		lamp.position = Vector3(x, 0, -10.5)
		add_child(lamp)
	# Skyline across the bay
	var towers := [["flame_a", Vector3(-120, 10, -420)], ["flame_b", Vector3(-150, 10, -440)], ["flame_c", Vector3(-95, 10, -455)],
		["tower_a", Vector3(120, 0, -430)], ["tower_c", Vector3(160, 0, -470)], ["maiden_tower", Vector3(30, 2, -380)]]
	for t in towers:
		var mi2 := MeshInstance3D.new()
		mi2.mesh = PropKit.get_mesh(t[0])
		mi2.position = t[1]
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi2)
	var hills := MeshInstance3D.new()
	hills.mesh = ShapeKit.superellipsoid(Vector3(900, 50, 120), 1.0, 1.0, Vector2.ONE, Vector2.ONE, 8, 16)
	hills.material_override = ShapeKit.mat(Color("8fb07a"), 0.95)
	hills.position = Vector3(0, -12, -500)
	add_child(hills)
	_wheel = MeshInstance3D.new()
	(_wheel as MeshInstance3D).mesh = PropKit.get_mesh("wheel_ring")
	_wheel.position = Vector3(60, 34, -150)
	_wheel.rotation.y = 0.4
	add_child(_wheel)

	# Turntable
	turntable = Node3D.new()
	add_child(turntable)
	var disc := MeshInstance3D.new()
	disc.mesh = ShapeKit.cylinder(2.6, 0.25, 40)
	disc.material_override = ShapeKit.mat(Color("1b2a4a"), 0.4, 0.3)
	disc.position = Vector3(0, 0.12, 0)
	turntable.add_child(disc)
	var ring := MeshInstance3D.new()
	ring.mesh = ShapeKit.torus(2.55, 2.75, 48, 6)
	ring.material_override = ShapeKit.mat(Color("ffc93c"), 0.3, 0.6, 0.4)
	ring.position = Vector3(0, 0.25, 0)
	turntable.add_child(ring)
	kart_holder = Node3D.new()
	kart_holder.position = Vector3(0, 0.25, 0)
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
	if auto_rotate:
		turntable.rotation.y += rotation_speed * delta
	_drag_velocity = lerpf(_drag_velocity, 0.0, 1.0 - exp(-4.0 * delta))
	var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(stick) > 0.25:
		turntable.rotation.y += stick * 2.5 * delta
	if _wheel:
		_wheel.rotate_object_local(Vector3.BACK, delta * 0.05)
	if kart_model:
		kart_model.update_driver(0.0, KartController.State.NORMAL, false, delta)
