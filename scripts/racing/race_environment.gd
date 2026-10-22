class_name RaceEnvironment
extends Node3D
## Sky, sun and post-processing for a race, plus the world-level part of the
## graphics presets (shadows, bloom, AO, decor distance, blob shadows).
## Presets only change presentation – never collision, physics or items.

signal decor_distance_changed(meters: float)

const DECOR_DISTANCES := [140.0, 260.0, 520.0]
const SHADOW_DISTANCES := [0.0, 55.0, 90.0, 140.0]

var env: Environment
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var blob_shadows_enabled := false


func build() -> void:
	world_env = WorldEnvironment.new()
	env = Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.52, 0.86)
	sky_mat.sky_horizon_color = Color(0.74, 0.86, 0.95)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.36, 0.42, 0.42)
	sky_mat.ground_horizon_color = Color(0.74, 0.84, 0.9)
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY if Settings.rendering_method() == "forward_plus" else Sky.PROCESS_MODE_AUTOMATIC
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.ambient_light_sky_contribution = 0.75
	env.ambient_light_color = Color(0.9, 0.88, 0.85)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.86, 0.94)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.15
	env.fog_aerial_perspective = 0.35
	env.glow_intensity = 0.45
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.35
	# Afternoon sun from the south-west so the seafront faces are lit.
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(-140.0), 0.0)
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.light_angular_distance = 0.6
	add_child(sun)
	apply_graphics()
	if not Settings.graphics_changed.is_connected(apply_graphics):
		Settings.graphics_changed.connect(apply_graphics)


func _exit_tree() -> void:
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
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if shadows == 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		var atlas: int = [1024, 1024, 2048, 4096][shadows]
		RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	env.glow_enabled = bool(g.bloom)
	env.ssao_enabled = bool(g.ssao) and Settings.unsupported_reason("ssao") == ""
	env.adjustment_brightness = float(g.brightness)
	# Distant fog hides the decor cut-off on shorter draw distances.
	var decor: float = DECOR_DISTANCES[int(g.decor_distance)]
	env.fog_density = [0.0032, 0.0018, 0.0011][int(g.decor_distance)]
	decor_distance_changed.emit(decor)
	get_tree().call_group("blob_shadow", "set_visible", blob_shadows_enabled)
	get_tree().call_group("kart_effects_density", "set_density", float(g.effects_density))


func decor_distance() -> float:
	return DECOR_DISTANCES[int(Settings.values.graphics.decor_distance)]
