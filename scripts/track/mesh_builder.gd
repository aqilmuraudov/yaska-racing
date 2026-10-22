class_name MeshBuilder
extends RefCounted
## Accumulates triangles for one ArrayMesh surface plus optional collision
## faces. Triangles are given counter-clockwise as seen from the front (the
## usual math convention) and converted to Godot's clockwise order here.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var colors := PackedColorArray()
var collision := PackedVector3Array()
var collect_collision := false
var use_uv2 := false


func _init(with_collision: bool = false, with_uv2: bool = false) -> void:
	collect_collision = with_collision
	use_uv2 = with_uv2


func is_empty() -> bool:
	return verts.is_empty()


func tri(a: Vector3, b: Vector3, c: Vector3,
		ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO,
		col := Color.WHITE, na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO,
		u2a := Vector2.ZERO, u2b := Vector2.ZERO, u2c := Vector2.ZERO) -> void:
	var face_n := (b - a).cross(c - a)
	if face_n.length_squared() < 1e-12:
		return
	face_n = face_n.normalized()
	if na == Vector3.ZERO:
		na = face_n
		nb = face_n
		nc = face_n
	# Godot front faces are clockwise: emit a, c, b.
	verts.append_array([a, c, b])
	normals.append_array([na, nc, nb])
	uvs.append_array([ua, uc, ub])
	colors.append_array([col, col, col])
	if use_uv2:
		uv2s.append_array([u2a, u2c, u2b])
	if collect_collision:
		collision.append_array([a, c, b])


## Quad a-b-c-d counter-clockwise from the front.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ua := Vector2(0, 0), ub := Vector2(1, 0), uc := Vector2(1, 1), ud := Vector2(0, 1),
		col := Color.WHITE) -> void:
	tri(a, b, c, ua, ub, uc, col)
	tri(a, c, d, ua, uc, ud, col)


## Quad whose winding is chosen so its face normal points along `want`.
func quad_facing(a: Vector3, b: Vector3, c: Vector3, d: Vector3, want: Vector3, col := Color.WHITE) -> void:
	var n := (b - a).cross(d - a)
	if n.dot(want) < 0.0:
		quad(b, a, d, c, Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), col)
	else:
		quad(a, b, c, d, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), col)


## Quad with explicit per-vertex normals (smooth surfaces).
func quad_n(a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, col := Color.WHITE,
		u2a := Vector2.ZERO, u2b := Vector2.ZERO, u2c := Vector2.ZERO, u2d := Vector2.ZERO) -> void:
	tri(a, b, c, ua, ub, uc, col, na, nb, nc, u2a, u2b, u2c)
	tri(a, c, d, ua, uc, ud, col, na, nc, nd, u2a, u2c, u2d)


## Axis-aligned-in-basis box. `xform` places the unit box (size given).
func box(xform: Transform3D, size: Vector3, col := Color.WHITE, uv_scale := 1.0) -> void:
	var h := size * 0.5
	var c := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var p: Array[Vector3] = []
	for v in c:
		p.append(xform * v)
	var sx := size.x * uv_scale
	var sy := size.y * uv_scale
	var sz := size.z * uv_scale
	quad(p[4], p[5], p[6], p[7], Vector2(0, sy), Vector2(sx, sy), Vector2(sx, 0), Vector2(0, 0), col) # +z
	quad(p[1], p[0], p[3], p[2], Vector2(0, sy), Vector2(sx, sy), Vector2(sx, 0), Vector2(0, 0), col) # -z
	quad(p[5], p[1], p[2], p[6], Vector2(0, sy), Vector2(sz, sy), Vector2(sz, 0), Vector2(0, 0), col) # +x
	quad(p[0], p[4], p[7], p[3], Vector2(0, sy), Vector2(sz, sy), Vector2(sz, 0), Vector2(0, 0), col) # -x
	quad(p[7], p[6], p[2], p[3], Vector2(0, 0), Vector2(sx, 0), Vector2(sx, sz), Vector2(0, sz), col) # +y
	quad(p[0], p[1], p[5], p[4], Vector2(0, 0), Vector2(sx, 0), Vector2(sx, sz), Vector2(0, sz), col) # -y


func commit(material: Material = null, mesh: ArrayMesh = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	if use_uv2:
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material != null:
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


func make_shape() -> ConcavePolygonShape3D:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(collision)
	shape.backface_collision = true
	return shape
