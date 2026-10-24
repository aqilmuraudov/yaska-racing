class_name KartVisual
extends Node3D
## Presentation for one kart: body lean, drift angle, ground alignment,
## suspension, wheels, driver poses and effects. Reads KartController state;
## never writes back, so visuals cannot affect the simulation.
## Updated on the physics tick so physics interpolation keeps it smooth.

const WHEEL_RADIUS := 0.34

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
	model.build(def, kart.is_player)
	effects = KartEffects.new()
	effects.name = "Effects"
	body_pivot.add_child(effects)
	effects.setup(kart, model, density)
	_make_blob_shadow()
	kart.landed.connect(_on_landed)
	kart.wall_hit.connect(func(s): _susp_vel -= 2.0 * s)
	kart.hopped.connect(func(): _susp_vel += 3.0)


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
	(blob.material_override as StandardMaterial3D).albedo_color = Color(0, 0, 0, 0.55 if full else 0.3)
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

	# Drift angle: nose points into the turn while the body slides.
	var target_drift := 0.0
	if drifting:
		var inward := kart.input.steer * kart.drift_dir
		target_drift = -kart.drift_dir * deg_to_rad(kart.stats.drift_visual_angle + inward * 8.0)
	_drift_yaw = lerpf(_drift_yaw, target_drift, 1.0 - exp(-(kart.stats.drift_correction if not drifting else 10.0) * delta))

	# Body roll (outward lean) and pitch (throttle / brake squat).
	var target_roll := -steer * absf(speed_ratio) * deg_to_rad(5.0)
	if drifting:
		target_roll = -kart.drift_dir * deg_to_rad(7.0)
	_roll = lerpf(_roll, target_roll, 1.0 - exp(-8.0 * delta))
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
	var target_align := Basis(Quaternion(Vector3.UP, local_n))
	_align = _align.slerp(target_align, 1.0 - exp(-10.0 * delta))

	var b := _align * Basis(Vector3.UP, _drift_yaw + _spin) * Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.FORWARD, _roll)
	body_pivot.transform = Transform3D(b, Vector3.UP * _susp * 0.5)
	if blob.visible:
		blob.transform = Transform3D(_align, Vector3(0, 0.05 - (0.0 if kart.grounded else 0.0), 0.05))

	# Wheels.
	_wheel_angle -= kart.speed * delta / WHEEL_RADIUS
	var steer_vis := steer * deg_to_rad(24.0)
	if drifting:
		steer_vis = -kart.drift_dir * deg_to_rad(10.0) + steer * deg_to_rad(10.0)
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


func _set_transparency(n: Node, t: float) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).transparency = t
	for c in n.get_children():
		_set_transparency(c, t)
