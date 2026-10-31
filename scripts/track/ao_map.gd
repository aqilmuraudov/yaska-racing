class_name AoMap
extends RefCounted
## 0.13.0 Soft contact shadows ("ambient occlusion") under buildings, trees
## and landmarks without a single extra draw call: while the race loads, a
## top-down darkening map of the whole terrain is painted on the CPU (one soft
## ellipse per footprint) and handed to the ground and road shaders through
## the global uniforms `yaska_ao` (texture) and `yaska_ao_rect`
## (x0, z0, 1/width, 1/depth; z = 0 switches it off).

const RES := 1024 ## texels per side (~1 m per texel on the seafront)
const BRUSH := 64
const LEVELS := 6 ## strength steps: level L darkens the centre to 1 - L/LEVELS * MAX_DARK
const MAX_DARK := 0.6
const MIN_H := 1.6 ## m: lower props get no contact shadow
const MIN_AREA := 2.5 ## m² footprint
const SPREAD := 1.05 ## ellipse half-size / footprint half-size
const PAD := 5.0 ## m the soft edge reaches beyond the footprint
const PLATEAU := 0.62 ## fully dark inside this fraction of the radius

static var last_blob_count := 0
static var last_build_ms := 0.0
static var _bases := {}
static var _cache := {}


## Strength of the darkening for a prop of height `h` (0..1 at the centre).
static func strength_for(h: float) -> float:
	return clampf(0.24 + h * 0.018, 0.24, 0.5)


## A contact-shadow ellipse for a world AABB, or {} when the thing is too
## small or too flat to need one.
static func blob_for(world: AABB) -> Dictionary:
	var h := world.size.y
	var area := world.size.x * world.size.z
	if h < MIN_H or area < MIN_AREA:
		return {}
	return {
		"c": Vector2(world.get_center().x, world.get_center().z),
		"r": Vector2(world.size.x, world.size.z) * 0.5 * SPREAD + Vector2(PAD, PAD),
		"s": strength_for(h),
	}


## Brushes are grey (1 - strength) with a soft round alpha, so overlapping
## footprints never stack below their own grey (no black patches). Alpha
## blending would LIGHTEN a darker spot under a weaker brush, so build()
## paints weak blobs first and strong ones last.
static func _level_base(level: int) -> Image:
	if _bases.has(level):
		return _bases[level]
	var g := 1.0 - float(level) / float(LEVELS) * MAX_DARK
	var img := Image.create(BRUSH, BRUSH, false, Image.FORMAT_RGBA8)
	for y in BRUSH:
		for x in BRUSH:
			var d := Vector2((x + 0.5) / BRUSH * 2.0 - 1.0, (y + 0.5) / BRUSH * 2.0 - 1.0).length()
			# Dark plateau over the footprint, soft fall-off just outside it, so
			# the visible ground at the foot of a wall is shaded too.
			var a := 1.0 - smoothstep(PLATEAU, 1.0, d)
			img.set_pixel(x, y, Color(g, g, g, a))
	_bases[level] = img
	return img


static func _brush(w: int, h: int, level: int) -> Image:
	var key := Vector3i(w, h, level)
	if _cache.has(key):
		return _cache[key]
	var img := _level_base(level).duplicate() as Image
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	if _cache.size() > 400:
		_cache.clear()
	_cache[key] = img
	return img


## Paints the map for `rect` (world x/z) and returns it as a mipmapped
## single-channel texture (1 = no shadow).
static func build(rect: Rect2, blobs: Array) -> ImageTexture:
	var t0 := Time.get_ticks_usec()
	var img := Image.create(RES, RES, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var texel := Vector2(rect.size.x / RES, rect.size.y / RES)
	var n := 0
	var sorted := blobs.duplicate()
	sorted.sort_custom(func(a, b): return float(a.s) < float(b.s))
	for b in sorted:
		var c: Vector2 = b.c
		var r: Vector2 = b.r
		var w := clampi(int(ceil(r.x * 2.0 / texel.x / 2.0)) * 2, 2, 512)
		var h := clampi(int(ceil(r.y * 2.0 / texel.y / 2.0)) * 2, 2, 512)
		var px := Vector2i(int((c.x - rect.position.x) / texel.x) - w / 2, int((c.y - rect.position.y) / texel.y) - h / 2)
		if px.x + w < 0 or px.y + h < 0 or px.x >= RES or px.y >= RES:
			continue
		var level := clampi(int(round(float(b.s) / MAX_DARK * LEVELS)), 1, LEVELS)
		img.blend_rect(_brush(w, h, level), Rect2i(0, 0, w, h), px)
		n += 1
	img.convert(Image.FORMAT_L8)
	img.generate_mipmaps()
	last_blob_count = n
	last_build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	return ImageTexture.create_from_image(img)


static func apply(rect: Rect2, tex: Texture2D) -> void:
	RenderingServer.global_shader_parameter_set("yaska_ao", tex)
	RenderingServer.global_shader_parameter_set("yaska_ao_rect",
		Vector4(rect.position.x, rect.position.y, 1.0 / rect.size.x, 1.0 / rect.size.y))
	active = true


static var active := false


## World rectangle covered by the map: the track bounds plus the same 140 m
## margin as the terrain grid.
static func rect_for(points: PackedVector3Array, margin := 140.0) -> Rect2:
	var r := Rect2(Vector2(points[0].x, points[0].z), Vector2.ZERO)
	for p in points:
		r = r.expand(Vector2(p.x, p.z))
	return r.grow(margin)


static func clear() -> void:
	RenderingServer.global_shader_parameter_set("yaska_ao_rect", Vector4.ZERO)
	active = false
