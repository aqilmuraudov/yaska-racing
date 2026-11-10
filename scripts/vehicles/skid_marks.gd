class_name SkidMarks
extends MeshInstance3D
## Tyre marks for every kart, drawn as one ImmediateMesh. Marks are laid
## while drifting on the ground, fade with age and are capped by a point
## budget that scales with the "effects density" graphics setting
## (Low ≈ none, Medium ≈ half, High = full).

const MAX_POINTS_FULL := 1400
const LIFETIME := 7.0
const SPACING := 0.45
const HALF_WIDTH := 0.13

var karts: Array = []
var _trails := {} # kart -> [left_strip, right_strip]; strip = Array of [pos, side, age]
var _strips: Array = [] # every strip (for ageing / budget)
var _budget := 0
var _dirty := false
var _imesh := ImmediateMesh.new()


func setup(p_karts: Array) -> void:
	karts = p_karts
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.render_priority = -2
	material_override = m
	add_to_group("kart_effects_density")
	set_density(float(Settings.get_value("graphics", "effects_density", 1.0)))
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func set_density(d: float) -> void:
	_budget = 0 if d < 0.2 else int(MAX_POINTS_FULL * clampf(d, 0.0, 1.0))
	if _budget == 0:
		clear()


func clear() -> void:
	_trails.clear()
	_strips.clear()
	_imesh.clear_surfaces()


func _physics_process(delta: float) -> void:
	if _budget <= 0:
		return
	var total := 0
	for strip in _strips:
		for p in strip:
			p[2] += delta
	# Drop expired points from the front of each strip.
	for i in range(_strips.size() - 1, -1, -1):
		var strip: Array = _strips[i]
		while not strip.is_empty() and strip[0][2] > LIFETIME:
			strip.pop_front()
			_dirty = true
		if strip.is_empty():
			_strips.remove_at(i)
		else:
			total += strip.size()
	for k in karts:
		if not is_instance_valid(k):
			continue
		var kart: KartController = k
		var marking := kart.is_drifting() and kart.grounded and absf(kart.speed) > 6.0
		if not marking:
			_trails.erase(kart)
			continue
		if not _trails.has(kart):
			var l: Array = []
			var r: Array = []
			_strips.append(l)
			_strips.append(r)
			_trails[kart] = [l, r]
		var pair: Array = _trails[kart]
		var right := kart.right_dir()
		var back := -kart.forward_dir() * 0.75
		var base := kart.global_position + back + Vector3.UP * 0.03
		for side_i in 2:
			var side := -1.0 if side_i == 0 else 1.0
			var p := base + right * side * 0.64
			var strip: Array = pair[side_i]
			if strip.is_empty() or (strip[strip.size() - 1][0] as Vector3).distance_to(p) >= SPACING:
				strip.append([p, right, 0.0])
				total += 1
				_dirty = true
	# Enforce the budget by trimming the oldest strips first.
	while total > _budget and not _strips.is_empty():
		var oldest: Array = _strips[0]
		oldest.pop_front()
		total -= 1
		if oldest.is_empty():
			_strips.remove_at(0)
		_dirty = true
	# 0.17.4: the mesh is rebuilt in _process, at most REBUILD_HZ times a
	# second (each rebuild re-sends every point: ~1 ms per tick on a phone).


const REBUILD_HZ := 30.0
var _since_rebuild := 0.0


func _process(delta: float) -> void:
	_since_rebuild += delta
	if _dirty and _since_rebuild >= 1.0 / REBUILD_HZ:
		_since_rebuild = 0.0
		_rebuild()
		_dirty = false


func _rebuild() -> void:
	_imesh.clear_surfaces()
	var any := false
	for strip in _strips:
		if strip.size() >= 2:
			any = true
			break
	if not any:
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for strip in _strips:
		for i in range(1, strip.size()):
			var a: Array = strip[i - 1]
			var b: Array = strip[i]
			var pa: Vector3 = a[0]
			var pb: Vector3 = b[0]
			var ra: Vector3 = a[1] * HALF_WIDTH
			var rb: Vector3 = b[1] * HALF_WIDTH
			var ca := Color(0.08, 0.08, 0.09, 0.42 * (1.0 - float(a[2]) / LIFETIME))
			var cb := Color(0.08, 0.08, 0.09, 0.42 * (1.0 - float(b[2]) / LIFETIME))
			# Two triangles, wound to face up.
			_imesh.surface_set_color(ca)
			_imesh.surface_add_vertex(pa - ra)
			_imesh.surface_set_color(cb)
			_imesh.surface_add_vertex(pb + rb)
			_imesh.surface_set_color(ca)
			_imesh.surface_add_vertex(pa + ra)
			_imesh.surface_set_color(ca)
			_imesh.surface_add_vertex(pa - ra)
			_imesh.surface_set_color(cb)
			_imesh.surface_add_vertex(pb - rb)
			_imesh.surface_set_color(cb)
			_imesh.surface_add_vertex(pb + rb)
	_imesh.surface_end()
