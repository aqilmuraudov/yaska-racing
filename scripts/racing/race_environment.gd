class_name RaceEnvironment
extends Node3D
## Sky, sun and post-processing for a race, plus the world-level part of the
## graphics presets (shadows, bloom, AO, decor distance, blob shadows).
## Presets only change presentation – never collision, physics or items.

signal decor_distance_changed(meters: float)

const DECOR_DISTANCES := [140.0, 260.0, 520.0]
const SHADOW_DISTANCES := [0.0, 45.0, 100.0, 150.0] ## 0.10.2: Medium 60 -> 45 m (phones)
## 0.9.6 soft shadows per preset level (0 = off): PCF filter quality.
const SHADOW_FILTER := [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
	RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM]

var env: Environment
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var blob_shadows_enabled := false
## 0.10.1: "day" / "sunset" / "night" (TimeOfDay).
var time_of_day := TimeOfDay.DEFAULT
var tod: Dictionary = {}


func build(tod_id := TimeOfDay.DEFAULT) -> void:
	time_of_day = TimeOfDay.valid(tod_id)
	tod = TimeOfDay.params(time_of_day)
	world_env = WorldEnvironment.new()
	env = Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	# Clear Caspian afternoon: saturated zenith, warm pale horizon.
	sky_mat.sky_top_color = tod.sky_top
	sky_mat.sky_horizon_color = tod.sky_horizon
	sky_mat.sky_energy_multiplier = tod.sky_energy
	sky_mat.sky_curve = 0.18 # 0.9.7: longer, softer gradient to a hazy horizon
	sky_mat.ground_bottom_color = tod.ground_bottom
	sky_mat.ground_horizon_color = tod.ground_horizon
	sky_mat.sun_angle_max = tod.sun_angle_max
	sky_mat.sun_curve = tod.sun_curve
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY if Settings.rendering_method() == "forward_plus" else Sky.PROCESS_MODE_AUTOMATIC
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = tod.ambient_source
	# Ambient a little lower than the sun so forms keep light and shade.
	# 0.9.6: a bit less fill so the sun's shadows read clearly.
	env.ambient_light_energy = tod.ambient_energy
	env.ambient_light_sky_contribution = 0.8
	env.ambient_light_color = tod.ambient_color
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# 0.9.6: ACES keeps bright limestone and sky highlights from clipping.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = tod.exposure
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = tod.fog # day: blue haze, never grey
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.15
	env.fog_aerial_perspective = 0.5
	env.glow_intensity = tod.glow
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = Palette.ENV_SATURATION * float(tod.get("saturation", 1.0))
	env.adjustment_contrast = Palette.ENV_CONTRAST
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	# Golden hour (0.9.2): lower, warmer sun; softer shadows.
	sun.light_color = tod.sun_color
	sun.light_energy = tod.sun_energy
	# Afternoon sun from the south-west so the seafront faces are lit.
	sun.rotation = Vector3(deg_to_rad(tod.sun_pitch), deg_to_rad(tod.sun_yaw), 0.0)
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	sun.shadow_blur = 1.2
	sun.shadow_opacity = 1.0
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.light_angular_distance = 0.6
	add_child(sun)
	if time_of_day != "night":
		_add_gulls()
	TimeOfDay.apply_materials(time_of_day)
	apply_graphics()
	if not Settings.graphics_changed.is_connected(apply_graphics):
		Settings.graphics_changed.connect(apply_graphics)


func _exit_tree() -> void:
	TimeOfDay.apply_materials("day") # shared materials back to daylight (menus)
	if Settings.graphics_changed.is_connected(apply_graphics):
		Settings.graphics_changed.disconnect(apply_graphics)


func apply_graphics() -> void:
	if env == null:
		return
	var g: Dictionary = Settings.values.graphics
	var shadows := int(g.shadows)
	sun.shadow_enabled = shadows > 0
	blob_shadows_enabled = shadows == 0
	if shadows > 0:
		sun.directional_shadow_max_distance = SHADOW_DISTANCES[shadows]
		# Two splits on Medium so the near shadows under karts stay crisp;
		# four on High/Ultra.
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if shadows == 1 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_split_1 = 0.18 if shadows == 1 else 0.08
		sun.directional_shadow_split_2 = 0.22
		sun.directional_shadow_split_3 = 0.5
		var atlas: int = [1024, 2048, 2048, 4096][shadows]
		RenderingServer.directional_shadow_atlas_set_size(atlas, true)
		RenderingServer.directional_soft_shadow_filter_set_quality(SHADOW_FILTER[shadows])
	env.glow_enabled = bool(g.bloom)
	# Flame Towers LED flames on the richer presets.
	# 0.9.7: daytime race – the real towers show plain blue glass by day
	# (LED flames are a night show), so the LED skin stays off.
	# 0.10.1: the LED show runs at sunset and at night.
	LandmarkKit.set_flame_led(float(tod.get("led", 0.0)))
	env.ssao_enabled = bool(g.ssao) and Settings.unsupported_reason("ssao") == ""
	env.adjustment_brightness = float(g.brightness)
	# Distant fog hides the decor cut-off on shorter draw distances.
	var decor: float = DECOR_DISTANCES[int(g.decor_distance)]
	env.fog_density = [0.0022, 0.0011, 0.0007][int(g.decor_distance)]
	decor_distance_changed.emit(decor)
	for v in get_tree().get_nodes_in_group("blob_shadow"):
		var kv := v.get_parent()
		if kv and kv.has_method("set_blob_strength"):
			kv.set_blob_strength(blob_shadows_enabled)
	get_tree().call_group("kart_effects_density", "set_density", float(g.effects_density))


func decor_distance() -> float:
	return DECOR_DISTANCES[int(Settings.values.graphics.decor_distance)]


## A few gulls circling over the seafront (0.9.2): 4 tiny V meshes moved on
## the CPU, no physics; hidden on the Low preset (decor_distance 0).
var gulls: Array[Node3D] = []
var _gull_t := 0.0


func _add_gulls() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.97, 0.97, 0.95)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(0, 0, 0.15), Vector3(-0.9, 0.25, -0.1), Vector3(0, 0.05, -0.15),
			Vector3(0, 0, 0.15), Vector3(0, 0.05, -0.15), Vector3(0.9, 0.25, -0.1)]:
		st.add_vertex(v)
	var mesh := st.commit()
	for i in 4:
		var g := MeshInstance3D.new()
		g.name = "Gull%d" % i
		g.mesh = mesh
		g.material_override = mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)
		gulls.append(g)


func _process(delta: float) -> void:
	if gulls.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var on := int(Settings.values.graphics.get("decor_distance", 1)) > 0 and cam != null
	_gull_t += delta
	for i in gulls.size():
		var g := gulls[i]
		g.visible = on
		if not on:
			continue
		# Circle ahead of the camera, high up, so they read without being in the way.
		var a := _gull_t * (0.25 + 0.05 * i) + i * 1.7
		var c := cam.global_position - cam.global_transform.basis.z * 45.0
		g.global_position = Vector3(c.x + cos(a) * (14.0 + i * 3.0), cam.global_position.y + 16.0 + sin(_gull_t + i) * 1.5, c.z + sin(a) * (14.0 + i * 3.0))
		g.rotation = Vector3(0, -a, 0)
		g.scale = Vector3(1.0, 1.0 + 0.6 * sin(_gull_t * 8.0 + i), 1.0) * 0.9
