class_name NightGlow
extends RefCounted
## 0.11.2 Night polish without real lights (phone-friendly).
## The Mobile renderer only applies a few lights per mesh, and every extra
## real light costs on every lit surface, so the night look is faked:
##  - a warm light pool on the ground under every street lamp: ONE MultiMesh
##    of additive, unshaded quads (one draw call for the whole track);
##  - head and tail lamps on every kart: one small vertex-coloured mesh per
##    kart, plus a soft additive headlight cone on the road ahead of the
##    rivals (the player keeps the real SpotLight from TimeOfDay);
##  - the sea darkens through the global shader parameter `yaska_night`.
## Purely visual: never touches physics, items, AI or collision.

const POOL_SIZE := 11.0 ## m, quad edge under a lamp
const POOL_Y := 0.07 ## cone height above the kart base
## Lamp pools sit higher: promenade paving and downtown sidewalks are above
## the lamp base (measured 0.11.2: no collision there to ray-cast against).
const POOL_LIFT := 0.32
const CONE_LEN := 11.0
const CONE_WIDTH := 6.5
const CONE_VIS := 70.0 ## m: rival cones are hidden beyond this
const POOL_COLOR := Color(1.0, 0.74, 0.42)
const CONE_COLOR := Color(1.0, 0.93, 0.78)

static var _pool_mat: ShaderMaterial
static var _cone_mat: ShaderMaterial
static var _lamp_mat: ShaderMaterial
static var _lamp_mesh: ArrayMesh


## Strength 0..1 of the fake lighting for a time of day.
static func strength(tod_id: String) -> float:
	match TimeOfDay.valid(tod_id):
		"night":
			return 1.0
		"sunset":
			return 0.35
	return 0.0


## Global shader parameter read by water.gdshader (0 day .. 1 night).
## The last value set (the headless dummy renderer cannot read globals back).
static var night_value := 0.0


static func set_global_night(tod_id: String) -> void:
	var v := 1.0 if TimeOfDay.valid(tod_id) == "night" else (0.3 if TimeOfDay.valid(tod_id) == "sunset" else 0.0)
	night_value = v
	RenderingServer.global_shader_parameter_set("yaska_night", v)


## Builds everything for one race; returns the nodes it added (the caller keeps
## them with the other night lights). Nothing is added by day.
static func build(root: Node3D, tod_id: String, lamp_xforms: Array, karts: Array, player_kart: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var k := strength(tod_id)
	if k <= 0.0:
		return out
	if not lamp_xforms.is_empty():
		var pools := _build_pools(lamp_xforms, k)
		root.add_child(pools)
		out.append(pools)
		if k >= 0.99: # 0.13.0 wet-road lamp reflections, night only
			var streaks := _build_streaks(lamp_xforms)
			root.add_child(streaks)
			out.append(streaks)
	for kart in karts:
		if not (kart is Node3D):
			continue
		var holder: Node3D = (kart as Node3D).get_node_or_null("Visual")
		if holder == null:
			holder = kart
		var lamps := MeshInstance3D.new()
		lamps.name = "KartLamps"
		lamps.mesh = lamp_mesh()
		lamps.material_override = lamp_material()
		lamps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamps.visibility_range_end = 160.0
		holder.add_child(lamps)
		out.append(lamps)
		if kart != player_kart: # the player has the real SpotLight
			var cone := MeshInstance3D.new()
			cone.name = "HeadGlow"
			var pm := PlaneMesh.new()
			pm.size = Vector2(CONE_WIDTH, CONE_LEN)
			cone.mesh = pm
			cone.material_override = cone_material(k)
			cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cone.position = Vector3(0, POOL_Y, -1.0 - CONE_LEN * 0.5)
			cone.visibility_range_end = CONE_VIS
			holder.add_child(cone)
			out.append(cone)
	return out


static func _build_pools(xforms: Array, k: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := PlaneMesh.new()
	pm.size = Vector2(POOL_SIZE, POOL_SIZE)
	mm.mesh = pm
	mm.instance_count = xforms.size()
	for i in xforms.size():
		var t: Transform3D = xforms[i]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, t.origin + Vector3(0, POOL_LIFT, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "LampPools"
	mmi.multimesh = mm
	mmi.material_override = pool_material(k)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## 0.13.0: a lamp's reflection on the wet road - a narrow warm streak from
## the foot of the lamp towards the camera, re-aimed every frame in the
## vertex shader (one MultiMesh, one draw call).
const STREAK_LEN := 12.0
const STREAK_W := 1.5
const STREAK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;
uniform vec3 tint : source_color = vec3(1.0, 0.72, 0.38);
uniform float strength = 0.46;
uniform float len = 12.0;
uniform float width = 1.5;
varying float vis;
void vertex() {
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 to_cam = CAMERA_POSITION_WORLD.xz - o.xz;
	float d = length(to_cam);
	vec2 dir = to_cam / max(d, 0.001);
	vec2 side = vec2(-dir.y, dir.x);
	float along = (VERTEX.z + 0.5) * min(len, d * 0.8);
	vec2 xz = o.xz + dir * along + side * VERTEX.x * width;
	vec3 w = vec3(xz.x, o.y, xz.y);
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vis = 1.0 - smoothstep(60.0, 110.0, d); // far lamps: no streak
}
void fragment() {
	float u = abs(UV.x * 2.0 - 1.0);
	float v = UV.y; // 0 at the camera end, 1 at the lamp (PlaneMesh UV)
	float a = pow(1.0 - u, 2.0) * smoothstep(0.0, 0.45, v) * smoothstep(1.0, 0.85, v);
	ALBEDO = tint * a * strength * vis;
}
"""


static func _build_streaks(xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	pm.subdivide_depth = 2
	mm.mesh = pm
	mm.instance_count = xforms.size()
	for i in xforms.size():
		var t: Transform3D = xforms[i]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, t.origin + Vector3(0, POOL_LIFT + 0.03, 0)))
	var sh := Shader.new()
	sh.code = STREAK_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("len", STREAK_LEN)
	m.set_shader_parameter("width", STREAK_W)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "LampStreaks"
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The vertex shader moves the quads up to 12 m: keep them from being culled.
	mmi.custom_aabb = AABB(Vector3(-2000, -50, -2000), Vector3(4000, 100, 4000))
	return mmi


const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(1.0, 0.74, 0.42);
uniform float strength = 1.0;
uniform int shape = 0; // 0 round pool, 1 headlight cone (UV.y 0 = far end)
void fragment() {
	float a;
	if (shape == 0) {
		float d = length(UV - 0.5) * 2.0;
		a = clamp(1.0 - d, 0.0, 1.0);
		a = a * a * (3.0 - 2.0 * a);
	} else {
		float v = 1.0 - UV.y; // 0 at the kart, 1 at the far end
		float w = mix(0.12, 0.48, v);
		float side = 1.0 - smoothstep(w * 0.45, w, abs(UV.x - 0.5));
		a = side * pow(1.0 - v, 1.4) * smoothstep(0.0, 0.1, v);
		// A rival right next to / behind the camera would wash the screen.
		a *= smoothstep(5.0, 13.0, length(VERTEX));
	}
	ALBEDO = tint * a * strength;
}
"""


static func _glow(k: float, tint: Color, shape: int, gain: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = GLOW_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("strength", k * gain)
	m.set_shader_parameter("shape", shape)
	return m


static func pool_material(k: float) -> ShaderMaterial:
	if _pool_mat == null:
		_pool_mat = _glow(k, POOL_COLOR, 0, 0.62)
	_pool_mat.set_shader_parameter("strength", k * 0.62)
	return _pool_mat


static func cone_material(k: float) -> ShaderMaterial:
	if _cone_mat == null:
		_cone_mat = _glow(k, CONE_COLOR, 1, 0.24)
	_cone_mat.set_shader_parameter("strength", k * 0.24)
	return _cone_mat


const LAMP_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;
uniform float boost = 2.6; // HDR so the glow (bloom) pass picks the lamps up
void fragment() {
	ALBEDO = COLOR.rgb * boost;
}
"""


static func lamp_material() -> ShaderMaterial:
	if _lamp_mat == null:
		var sh := Shader.new()
		sh.code = LAMP_SHADER
		_lamp_mat = ShaderMaterial.new()
		_lamp_mat.shader = sh
	return _lamp_mat


## Two white head lamps and two red tail lamps merged into one small mesh.
static func lamp_mesh() -> ArrayMesh:
	if _lamp_mesh != null:
		return _lamp_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-0.32, 0.32]:
		_sphere(st, Vector3(x, 0.45, -0.97), 0.1, Color(1.0, 0.96, 0.82))
		_sphere(st, Vector3(x * 0.95, 0.5, 1.12), 0.075, Color(1.0, 0.08, 0.06))
	_lamp_mesh = st.commit()
	return _lamp_mesh


static func _sphere(st: SurfaceTool, c: Vector3, r: float, col: Color) -> void:
	var rings := 4
	var segs := 8
	for i in rings:
		var a0 := PI * float(i) / rings
		var a1 := PI * float(i + 1) / rings
		for j in segs:
			var b0 := TAU * float(j) / segs
			var b1 := TAU * float(j + 1) / segs
			var p00 := c + r * Vector3(sin(a0) * cos(b0), cos(a0), sin(a0) * sin(b0))
			var p01 := c + r * Vector3(sin(a0) * cos(b1), cos(a0), sin(a0) * sin(b1))
			var p10 := c + r * Vector3(sin(a1) * cos(b0), cos(a1), sin(a1) * sin(b0))
			var p11 := c + r * Vector3(sin(a1) * cos(b1), cos(a1), sin(a1) * sin(b1))
			for p in [p00, p10, p11, p00, p11, p01]:
				st.set_color(col)
				st.add_vertex(p)
