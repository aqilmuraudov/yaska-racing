class_name KartEffects
extends Node3D
## Particles and glow for one kart: tyre smoke, drift sparks (colour AND
## size/rate change per tier so they are not colour-only), exhaust puffs,
## boost flames, off-road dust and the shield bubble.
## Particle counts scale with the "effects density" graphics setting.

const SPARK_COLORS := [Color("8fd3ff"), Color("ffb21f"), Color("ff4fa3"), Color("c58bff")]
const BOOST_COLORS := {&"drift": Color("ffb21f"), &"pad": Color("ff7a1f"), &"item": Color("4fd8ff"),
	&"start": Color("ffe14f"), &"landing": Color("ffd24f")}

var kart: KartController
var model: KartModel
var density := 1.0
var smoke: Array[CPUParticles3D] = []
var sparks: Array[CPUParticles3D] = []
var dust: CPUParticles3D
var exhaust: Array[CPUParticles3D] = []
var flames: Array[MeshInstance3D] = []
var flame_mat: StandardMaterial3D
var shield: MeshInstance3D
var shield_mat: ShaderMaterial
var _flame_t := 0.0
var landing_puff: CPUParticles3D
var boost_burst: CPUParticles3D


func setup(p_kart: KartController, p_model: KartModel, p_density: float) -> void:
	kart = p_kart
	model = p_model
	density = clampf(p_density, 0.0, 1.0)
	add_to_group("kart_effects_density")
	var dot := ShapeKit.soft_dot_texture()
	for p in model.rear_contact_points:
		# Restrained: thin, short-lived, so the kart and the line stay visible.
		var s := _particles(dot, 14, 0.45, Color(0.95, 0.95, 0.95, 0.24), 0.25, 0.6)
		s.position = p
		s.direction = Vector3(0, 0.6, 1)
		s.spread = 35.0
		s.initial_velocity_min = 1.0
		s.initial_velocity_max = 2.5
		s.gravity = Vector3(0, 0.6, 0)
		smoke.append(s)
		var sp := _spark_particles()
		sp.position = p + Vector3(0, 0.1, 0.05)
		sparks.append(sp)
	dust = _particles(dot, 18, 0.6, Color("c9a96e"), 0.45, 1.1)
	dust.position = Vector3(0, 0.15, 0.8)
	dust.direction = Vector3(0, 0.8, 1)
	dust.spread = 50.0
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 3.0
	dust.gravity = Vector3(0, -2.0, 0)
	for p in model.exhaust_points:
		var e := _particles(dot, 5, 0.35, Color(0.6, 0.6, 0.65, 0.22), 0.06, 0.14)
		e.local_coords = true
		e.position = p
		e.direction = Vector3(0, 0.4, 1)
		e.spread = 12.0
		e.initial_velocity_min = 1.0
		e.initial_velocity_max = 2.0
		e.gravity = Vector3(0, 1.0, 0)
		exhaust.append(e)
	flame_mat = StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_mat.albedo_color = Color(1, 0.7, 0.2, 0.9)
	flame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for p in model.exhaust_points:
		var f := MeshInstance3D.new()
		f.mesh = ShapeKit.cone(0.1, 0.0, 0.7, 10)
		f.material_override = flame_mat
		f.position = p + Vector3(0, 0, 0.35)
		f.rotation = Vector3(PI * 0.5, 0, 0)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.visible = false
		add_child(f)
		flames.append(f)
	# One-shot landing dust and boost burst (readable feedback, pooled per kart).
	landing_puff = _particles(dot, 16, 0.6, Color("e6d3ad"), 0.5, 1.1)
	landing_puff.one_shot = true
	landing_puff.explosiveness = 1.0
	landing_puff.position = Vector3(0, 0.1, 0.2)
	landing_puff.direction = Vector3(0, 0.3, 0)
	landing_puff.spread = 180.0
	landing_puff.flatness = 0.8
	landing_puff.initial_velocity_min = 2.5
	landing_puff.initial_velocity_max = 4.5
	landing_puff.gravity = Vector3(0, -1.0, 0)
	boost_burst = _spark_particles()
	boost_burst.one_shot = true
	boost_burst.explosiveness = 0.9
	boost_burst.amount = maxi(6, int(16 * density))
	boost_burst.lifetime = 0.45
	boost_burst.position = Vector3(0, 0.6, 1.1)
	boost_burst.direction = Vector3(0, 0.2, 1)
	boost_burst.spread = 55.0
	boost_burst.initial_velocity_min = 5.0
	boost_burst.initial_velocity_max = 9.0
	boost_burst.scale_amount_min = 0.9
	boost_burst.scale_amount_max = 1.3
	kart.landed.connect(func(t):
		if t > 0.35 and density > 0.05:
			landing_puff.restart())
	kart.boost_started.connect(func(src):
		if density > 0.05:
			boost_burst.color = BOOST_COLORS.get(src, Color("ffb21f"))
			boost_burst.restart())
	shield = MeshInstance3D.new()
	shield.mesh = ShapeKit.sphere(1.0, 24, 14)
	shield_mat = ShaderMaterial.new()
	shield_mat.shader = preload("res://assets/materials/shield.gdshader")
	shield.material_override = shield_mat
	shield.scale = Vector3(1.0, 0.75, 1.25) * model.shield_radius
	shield.position = Vector3(0, 0.65, 0)
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield.visible = false
	add_child(shield)


func set_density(d: float) -> void:
	density = clampf(d, 0.0, 1.0)
	for s in smoke:
		s.amount = maxi(2, int(14 * density))
	for sp in sparks:
		sp.amount = maxi(4, int(26 * density))
	dust.amount = maxi(2, int(18 * density))
	for e in exhaust:
		e.amount = maxi(2, int(8 * density))


func _particles(tex: Texture2D, amount: int, lifetime: float, color: Color, size_min: float, size_max: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(2, int(amount * density))
	p.lifetime = lifetime
	p.local_coords = false
	p.emitting = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	quad.material = m
	p.mesh = quad
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	add_child(p)
	return p


func _spark_particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(4, int(26 * density))
	p.lifetime = 0.35
	p.local_coords = false
	p.emitting = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.18)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# Soft-edged streak (an untextured quad read as a white bar on the road).
	m.albedo_texture = ShapeKit.soft_dot_texture()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	p.particle_flag_align_y = true
	p.direction = Vector3(0, 0.7, 1)
	p.spread = 40.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -12, 0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	add_child(p)
	return p


func update(delta: float) -> void:
	if kart == null:
		return
	var drifting := kart.is_drifting()
	var grounded := kart.grounded
	var fast := absf(kart.speed) > 8.0
	for s in smoke:
		s.emitting = drifting and grounded and density > 0.05
	# Sparks: colour/size = charge level (Easy Drift) or completed boosts
	# (timing mode); bigger and faster once charged ("let go now").
	var tier := clampi(kart.drift.level(), 0, 3)
	var ready := kart.drift.is_charged()
	for sp in sparks:
		sp.emitting = drifting and grounded and (kart.drift.meter > 0.3 or ready)
		sp.color = SPARK_COLORS[tier] if ready else Color(SPARK_COLORS[0], 0.8)
		sp.scale_amount_min = 1.1 if ready else 0.7
		sp.scale_amount_max = 1.5 if ready else 1.0
		sp.speed_scale = 1.6 if ready else 1.0
	dust.emitting = grounded and fast and (kart.surface == &"offroad" or kart.surface == &"rough") and density > 0.05
	for e in exhaust:
		# Puffs only while pulling away; at speed they would veil the kart.
		e.emitting = kart.input.throttle > 0.1 and absf(kart.speed) < 7.0 and not kart.boost.is_active() and density > 0.3
	# Boost flames follow the real speed above top speed, so they
	# grow and fade with the actual acceleration, not with a timer.
	var boosting := kart.boost.is_active()
	var over := clampf((absf(kart.speed) / kart.stats.top_speed - 1.0) / 0.35, 0.0, 1.0)
	_flame_t += delta
	for f in flames:
		f.visible = boosting
		if boosting:
			var flick := 0.85 + 0.25 * sin(_flame_t * 50.0 + f.position.x * 10.0)
			var power := 0.7 + over * 0.9
			f.scale = Vector3(1.0 + 0.3 * power, flick * power * 1.5, 1.0 + 0.3 * power)
	var c: Color = BOOST_COLORS.get(kart.boost.last_source, Color("ffb21f"))
	if boosting:
		flame_mat.albedo_color = Color(c, 0.85)
	# Shield
	var shielded := kart.has_shield()
	# Player recovery window after a hit or respawn: a faint bubble says
	# "you are protected" for exactly as long as immunity lasts.
	var protected := kart.is_player and kart.immunity_timer > 0.0 and kart.state != KartController.State.RECOVER
	shield.visible = shielded or protected
	if shielded:
		shield_mat.set_shader_parameter("fade", clampf(kart.shield_timer / 1.5, 0.25, 1.0))
	elif protected:
		shield_mat.set_shader_parameter("fade", clampf(kart.immunity_timer, 0.1, 0.3))
