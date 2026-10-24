class_name StarField
extends Node3D
## Collectible stars along the racing line (children love collecting). Only
## the player collects them; rivals drive through. Rows of stars curve gently
## across the lane so following them teaches a good line. A collected star
## comes back after RESPAWN seconds, so every lap has stars again.
##
## Cost: one MultiMesh (one draw call) for all stars, a small pool of one-shot
## sparkle bursts, distance checks against the player only.

signal collected(total: int)

const GROUPS := 8 ## rows per lap
const PER_GROUP := 4
const SPACING := 7.0 ## metres between stars in a row
const HEIGHT := 1.0
const PICK_RADIUS := 1.9
const RESPAWN := 12.0
const BURST_POOL := 3

var count := 0 ## stars collected this race
var player: KartController
var _positions: Array[Vector3] = []
var _respawn: Array[float] = []
var _mm: MultiMesh
var _spin := 0.0
var _bursts: Array[CPUParticles3D] = []
var _burst_i := 0
var _streak := 0
var _streak_timer := 0.0


func build(track: TrackData, p_player: KartController, enabled: bool) -> void:
	player = p_player
	if not enabled:
		return
	var path := track.main
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for g in GROUPS:
		# Skip the start straight so the grid start stays clean.
		var s0 := path.length * (float(g) + 0.55) / GROUPS
		var side := rng.randf_range(-0.45, 0.45)
		var drift := rng.randf_range(-0.12, 0.12)
		for i in PER_GROUP:
			var s := fposmod(s0 + i * SPACING, path.length)
			var hw := path.half_width_at(s)
			var lat := clampf(side + drift * i, -0.6, 0.6) * hw
			_positions.append(path.position_at(s) + path.right_at(s) * lat + Vector3.UP * HEIGHT)
			_respawn.append(0.0)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = _star_mesh()
	_mm.instance_count = _positions.size()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	for i in BURST_POOL:
		_bursts.append(_make_burst())
	_update_transforms()


func reset() -> void:
	count = 0
	_streak = 0
	for i in _respawn.size():
		_respawn[i] = 0.0
	_update_transforms()


func _physics_process(delta: float) -> void:
	if player == null or _positions.is_empty():
		return
	_streak_timer = maxf(_streak_timer - delta, 0.0)
	if _streak_timer <= 0.0:
		_streak = 0
	var p := player.global_position + Vector3.UP * 0.6
	var can_pick := player.state != KartController.State.RECOVER and not player.controls_locked
	for i in _positions.size():
		if _respawn[i] > 0.0:
			_respawn[i] -= delta
			continue
		if can_pick and p.distance_squared_to(_positions[i]) < PICK_RADIUS * PICK_RADIUS:
			_pick(i)


func _process(delta: float) -> void:
	if _mm == null:
		return
	_spin += delta * 2.6
	_update_transforms()


func _pick(i: int) -> void:
	_respawn[i] = RESPAWN
	count += 1
	_streak += 1
	_streak_timer = 1.2
	# Rising chime along a row: each star in a quick streak plays higher.
	AudioManager.play("pickup", -6.0, 1.0 + 0.08 * mini(_streak - 1, 6))
	var b := _bursts[_burst_i]
	_burst_i = (_burst_i + 1) % _bursts.size()
	b.global_position = _positions[i]
	b.restart()
	if bool(Settings.get_value("controls", "vibration", true)):
		Input.vibrate_handheld(8)
	collected.emit(count)


func _update_transforms() -> void:
	var bob := sin(_spin * 1.3) * 0.12
	for i in _positions.size():
		var hidden := _respawn[i] > 0.0
		var scale := 0.0 if hidden else 1.0
		var basis := Basis(Vector3.UP, _spin + i * 0.4).scaled(Vector3.ONE * scale)
		_mm.set_instance_transform(i, Transform3D(basis, _positions[i] + Vector3.UP * bob))


static func _star_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for k in 10:
		var r := 0.55 if k % 2 == 0 else 0.24
		var a := PI * 0.5 + TAU * k / 10.0
		pts.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	var depth := 0.13
	for side in [1.0, -1.0]:
		var n := Vector3(0, 0, side)
		for k in 10:
			var a: Vector3 = pts[k]
			var b: Vector3 = pts[(k + 1) % 10]
			st.set_normal(n)
			st.add_vertex(Vector3(0, 0, depth * side))
			if side > 0.0:
				st.add_vertex(a)
				st.add_vertex(b)
			else:
				st.add_vertex(b)
				st.add_vertex(a)
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ffd23f")
	m.emission_enabled = true
	m.emission = Color("ff9f1a")
	m.emission_energy_multiplier = 0.6
	m.roughness = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, m)
	return mesh


func _make_burst() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.amount = 10
	p.lifetime = 0.45
	p.spread = 180.0
	p.direction = Vector3.UP
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -4, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.22
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = ShapeKit.soft_dot_texture()
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	p.color = Color("ffe066")
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	add_child(p)
	return p
