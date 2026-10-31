class_name KartVisual
extends Node3D
## Presentation for one kart: body lean, drift angle, ground alignment,
## suspension, wheels, driver poses and effects. Reads KartController state;
## never writes back, so visuals cannot affect the simulation.
## Updated on the physics tick so physics interpolation keeps it smooth.

const MAX_ALIGN_TILT := deg_to_rad(28.0)
const MAX_ROLL := deg_to_rad(20.0)
const WHEEL_RADIUS := 0.34
const VCOLOR_GLOSS := preload("res://assets/materials/vcolor_gloss.gdshader")

var kart: KartController
var body_pivot: Node3D
var model: KartModel
var effects: KartEffects

var _roll := 0.0
var _pitch := 0.0
var _drift_yaw := 0.0
var _spin := 0.0
var _susp := 0.0
var _susp_vel := 0.0
var _align := Basis.IDENTITY
var _wheel_angle := 0.0
var _victory := false
var blob: MeshInstance3D


func setup(p_kart: KartController, def: RacerDefinition, density: float) -> void:
	kart = p_kart
	body_pivot = Node3D.new()
	body_pivot.name = "BodyPivot"
	add_child(body_pivot)
	model = KartModel.new()
	model.name = "Model"
	body_pivot.add_child(model)
	if kart.is_player:
		model.parts = Progression.equipped_parts(SaveManager.data)
	model.build(def, kart.is_player)
	_build_far_lod(def)
	effects = KartEffects.new()
	effects.name = "Effects"
	body_pivot.add_child(effects)
	effects.setup(kart, model, density)
	_make_blob_shadow()
	kart.landed.connect(_on_landed)
	kart.wall_hit.connect(func(s): _susp_vel -= 2.0 * s)
	kart.hopped.connect(func(): _susp_vel += 3.0)


## 0.10.2 kart LOD: a second, low-segment copy of the kart and driver drawn
## beyond KART_LOD metres (no wheel / driver animation needed that far away);
## the full model stops drawing there. Roughly 3x fewer triangles per far kart.
const KART_LOD := 28.0
var model_lo: KartModel
var shadow_proxies := 0 ## 0.11.2 shadows-only low-detail copies (tests)
## 0.13.0 cartoon outline (inverted hull overlay) on the big near parts.
var outlined: Array = []
static var _outline_mat: ShaderMaterial


static func outline_material() -> ShaderMaterial:
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = preload("res://assets/materials/outline.gdshader")
	return _outline_mat


## Off on the Low preset (effects density < 0.5): it redraws the outlined parts.
static func outline_wanted() -> bool:
	return float(Settings.get_value("graphics", "effects_density", 0.7)) >= 0.5


func set_outline(on: bool) -> void:
	for g in outlined:
		if is_instance_valid(g):
			(g as GeometryInstance3D).material_overlay = outline_material() if on else null


func _build_far_lod(def: RacerDefinition) -> void:
	model_lo = KartModel.new()
	model_lo.name = "ModelLo"
	model_lo.parts = model.parts
	ShapeKit.detail = 0.4
	model_lo.build(def, false)
	ShapeKit.detail = 1.0
	body_pivot.add_child(model_lo)
	model_lo.set_process(false)
	# 0.13.0: the big near parts (body, driver head and torso: no range limit
	# and casting shadows) get the cartoon outline overlay.
	outlined.clear()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var g0 := mi as GeometryInstance3D
		if g0.visibility_range_end <= 0.0 and g0.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			outlined.append(g0)
	set_outline(outline_wanted())
	add_to_group("kart_outline")
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var g := mi as GeometryInstance3D
		g.visibility_range_end = KART_LOD if g.visibility_range_end <= 0.0 else minf(g.visibility_range_end, KART_LOD)
		g.visibility_range_end_margin = 2.0
	# 0.11.2: the near model no longer casts shadows itself; a shadows-only
	# copy of the low-detail mesh (ShapeKit.detail 0.4, same pivots, so it
	# steers and leans with the kart) casts them instead: same silhouette in
	# the shadow map, about a third of the triangles in the shadow pass.
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow_proxies = 0
	for mi in model_lo.find_children("*", "MeshInstance3D", true, false):
		var g := mi as GeometryInstance3D
		var small := g.visibility_range_end > 0.0
		var casts := g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not small
		g.visibility_range_begin = KART_LOD
		g.visibility_range_begin_margin = 2.0
		g.visibility_range_end = 0.0
		# Beyond 28 m a kart's real shadow is a few pixels; the blob grounds it.
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if small:
			g.visible = false # eyes / ears / arms are invisible that far away
		elif casts:
			var proxy := MeshInstance3D.new()
			proxy.name = "ShadowProxy"
			proxy.mesh = (mi as MeshInstance3D).mesh
			proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			proxy.visibility_range_end = KART_LOD
			proxy.visibility_range_end_margin = 2.0
			proxy.transform = (mi as Node3D).transform
			mi.get_parent().add_child(proxy)
			shadow_proxies += 1


## Cheap contact shadow used when real-time shadows are off (Low preset).
func _make_blob_shadow() -> void:
	blob = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.9, 2.7)
	blob.mesh = plane
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, 0.55)
	m.albedo_texture = ShapeKit.soft_dot_texture()
	m.render_priority = -1
	blob.material_override = m
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.position = Vector3(0, 0.05, 0.05)
	blob.add_to_group("blob_shadow")
	set_blob_strength(int(Settings.get_value("graphics", "shadows", 1)) == 0)
	add_child(blob)


## Grounding shadow on every preset: full strength when real-time shadows
## are off (Low), a soft contact darkening otherwise.
func set_blob_strength(full: bool) -> void:
	(blob.material_override as StandardMaterial3D).albedo_color = Color(0, 0, 0, 0.6 if full else 0.42)
	blob.visible = true


func set_victory(on: bool) -> void:
	_victory = on


func _on_landed(airtime: float) -> void:
	_susp_vel -= clampf(airtime * 9.0, 1.0, 7.0)
	if model.driver:
		model.driver.land(airtime * 1.5)


func _physics_process(delta: float) -> void:
	if kart == null:
		return
	var speed_ratio := clampf(kart.speed / kart.stats.top_speed, -1.0, 1.5)
	var steer := kart.steer_smoothed
	var drifting := kart.is_drifting()

	# Drift angle: the body follows the controller's slip angle (one smooth
	# source, so the kart never swings side to side).
	_drift_yaw = lerpf(_drift_yaw, kart.drift_slip, 1.0 - exp(-14.0 * delta))

	# Body roll: a subtle outward lean, proportional to the slide in a drift
	# and to steering otherwise; slow enough that it never wobbles.
	var target_roll := -steer * absf(speed_ratio) * deg_to_rad(3.0)
	if drifting:
		var slip_n := clampf(absf(kart.drift_slip) / maxf(deg_to_rad(kart.stats.drift_visual_angle), 0.01), 0.0, 1.2)
		target_roll = -kart.drift_dir * deg_to_rad(3.5) * slip_n
	_roll = lerpf(_roll, target_roll, 1.0 - exp(-5.0 * delta))
	var target_pitch := 0.0
	if kart.input.brake > 0.1 and kart.speed > 1.0:
		target_pitch = deg_to_rad(-3.0)
	elif kart.input.throttle > 0.1 and kart.speed < kart.stats.top_speed * 0.5:
		target_pitch = deg_to_rad(2.5)
	if kart.boost.is_active():
		target_pitch = deg_to_rad(3.5)
	if not kart.grounded:
		target_pitch = clampf(kart.vertical * 0.025, -0.35, 0.25)
	_pitch = lerpf(_pitch, target_pitch, 1.0 - exp(-6.0 * delta))

	# Hit spin-out.
	if kart.state == KartController.State.HIT:
		_spin += delta * TAU * 2.2
	else:
		_spin = lerp_angle(_spin, 0.0, 1.0 - exp(-12.0 * delta))
		if absf(_spin) < 0.01:
			_spin = 0.0

	# Suspension spring.
	_susp_vel += (-_susp * 160.0 - _susp_vel * 14.0) * delta
	_susp += _susp_vel * delta
	_susp = clampf(_susp, -0.25, 0.25)

	# Align to the ground normal (yaw-free) when grounded.
	var n := kart.get_floor_normal() if kart.grounded else Vector3.UP
	var local_n := (Basis(Vector3.UP, kart.yaw).inverse() * n).normalized()
	# Never tilt the body more than MAX_ALIGN_TILT, whatever the contact normal.
	var tilt := acos(clampf(local_n.y, -1.0, 1.0))
	if tilt > MAX_ALIGN_TILT:
		var axis := Vector3.UP.cross(local_n)
		local_n = Vector3.UP.rotated(axis.normalized(), MAX_ALIGN_TILT) if axis.length_squared() > 1e-6 else Vector3.UP
	var target_align := Basis(Quaternion(Vector3.UP, local_n))
	_align = _align.slerp(target_align, 1.0 - exp(-10.0 * delta))

	_roll = clampf(_roll, -MAX_ROLL, MAX_ROLL)
	_pitch = clampf(_pitch, -MAX_ROLL, MAX_ROLL)
	var b := _align * Basis(Vector3.UP, _drift_yaw + _spin) * Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.FORWARD, _roll)
	body_pivot.transform = Transform3D(b, Vector3.UP * _susp * 0.5)
	if blob.visible:
		blob.transform = Transform3D(_align, Vector3(0, 0.05 - (0.0 if kart.grounded else 0.0), 0.05))

	# Wheels.
	_wheel_angle -= kart.speed * delta / WHEEL_RADIUS
	var steer_vis := steer * deg_to_rad(24.0)
	if drifting or absf(kart.drift_slip) > 0.05:
		# Front wheels counter-steer: they point along the travel direction
		# while the body slides, plus a little of the player's input.
		steer_vis = kart.drift_slip * 0.7 + steer * deg_to_rad(6.0)
	model.update_wheels(_wheel_angle, -steer_vis, _susp)
	model.update_driver(steer, kart.state, _victory, delta, kart.boost.is_active(), not kart.grounded, -_roll * 0.6)
	effects.update(delta)

	# Recovery fade (scale pop) and protection blink.
	var vis := true
	if kart.state == KartController.State.RECOVER:
		var p := kart.recover_progress()
		vis = p > 0.55 or fmod(p * 10.0, 1.0) < 0.5
	elif not kart.is_player and kart.immunity_timer > 0.0 and not Settings.get_value("accessibility", "reduced_flashing", false):
		# Rivals blink; the player's own kart stays solid (its protection is
		# shown by a soft bubble, see KartEffects) so it is always readable.
		vis = fmod(kart.immunity_timer * 8.0, 1.0) < 0.7
	model.visible = vis
	if model_lo:
		model_lo.visible = vis
	_update_camera_fade(delta)


var _fade := 0.0


## Rival karts that come between the camera and the player fade out so the
## player's kart and the road stay visible. Collision is unaffected.
## Two cases: a rival very close to the lens, and a rival on the line of
## sight to the player (closer to the camera than the player is).
func _update_camera_fade(delta: float) -> void:
	if kart.is_player:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var me := global_position + Vector3.UP * 0.6
	var c := cam.global_position
	var d := c.distance_to(me)
	var target := clampf((3.6 - d) / 1.6, 0.0, 0.9)
	var chase := cam as ChaseCamera
	if chase and chase.target and not chase.orbit:
		var p := chase.target.global_position + Vector3.UP * 0.6
		var seg := p - c
		var len2 := seg.length_squared()
		if len2 > 0.01:
			var t := clampf((me - c).dot(seg) / len2, 0.0, 1.0)
			if t < 0.97:
				var off := me.distance_to(c + seg * t)
				target = maxf(target, clampf((1.6 - off) / 0.8, 0.0, 0.8))
	var nf := lerpf(_fade, target, 1.0 - exp(-12.0 * delta))
	if absf(nf - _fade) > 0.01 or (nf == 0.0 and _fade != 0.0):
		_fade = nf if nf > 0.01 else 0.0
		_set_transparency(body_pivot, _fade)


## Kart body and driver use vcolor_gloss.gdshader: its `occlusion_fade`
## instance uniform dithers them out (GeometryInstance3D.transparency has no
## visible effect on that opaque shader). Effects keep their own materials.
func _set_transparency(n: Node, t: float) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var m := mi.get_active_material(0) if mi.mesh else null
		if m is ShaderMaterial and (m as ShaderMaterial).shader == VCOLOR_GLOSS:
			mi.set_instance_shader_parameter(&"occlusion_fade", t)
		elif m is StandardMaterial3D:
			mi.transparency = t # standard materials honour instance transparency
	for c in n.get_children():
		_set_transparency(c, t)
