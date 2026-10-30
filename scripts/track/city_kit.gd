class_name CityKit
extends RefCounted
## 0.11.0 downtown props for "Göydələnlər şəhəri": 16-storey glass
## skyscrapers (four shapes), shopping malls with glass fronts, entrances and
## a sign band, parking lots, parked cars and billboards. Built through
## PropKit (PropKit.get_mesh("sky_a") etc.) so TrackDecor instances them in
## MultiMesh chunks with the 0.10.2 far LOD. Floors and windows come from
## skyscraper.gdshader (no window geometry), so a tower is ~40 triangles.

const SKY_SHADER := preload("res://assets/materials/skyscraper.gdshader")
const FLOORS := 16
const FLOOR_H := 3.6
const TOWER_H := FLOORS * FLOOR_H ## 57.6 m
const IDS := ["sky_a", "sky_b", "sky_c", "sky_d", "mall_a", "mall_b", "parking", "car_a", "car_b", "car_c", "billboard", "planter"]
const TOWERS := ["sky_a", "sky_b", "sky_c", "sky_d"]
## Glass colours per tower look: [low, high, band].
const GLASS := [
	[Color(0.10, 0.36, 0.72), Color(0.45, 0.76, 0.98), Color(0.94, 0.96, 0.99)], # blue
	[Color(0.05, 0.42, 0.45), Color(0.35, 0.82, 0.80), Color(0.95, 0.97, 0.95)], # teal
	[Color(0.62, 0.40, 0.12), Color(0.98, 0.80, 0.42), Color(0.98, 0.95, 0.88)], # gold
	[Color(0.30, 0.22, 0.62), Color(0.70, 0.62, 0.98), Color(0.95, 0.94, 0.99)], # violet
	[Color(0.12, 0.40, 0.55), Color(0.55, 0.85, 0.95), Color(1.0, 1.0, 1.0)], # mall glass
]

static var _glass := {}
static var _window_glow := 0.0


static func has(id: String) -> bool:
	return id in IDS


## Shared skyscraper glass material for look `v` (see GLASS).
static func glass(v: int, floor_h := FLOOR_H, height := TOWER_H) -> ShaderMaterial:
	var key := "%d|%s|%s" % [v, floor_h, height]
	if _glass.has(key):
		return _glass[key]
	var sm := ShaderMaterial.new()
	sm.shader = SKY_SHADER
	sm.set_shader_parameter("glass_low", GLASS[v][0])
	sm.set_shader_parameter("glass_high", GLASS[v][1])
	sm.set_shader_parameter("band_color", GLASS[v][2])
	sm.set_shader_parameter("floor_h", floor_h)
	sm.set_shader_parameter("height", height)
	sm.set_shader_parameter("window_glow", _window_glow)
	_glass[key] = sm
	return sm


## Lit windows (0 day .. 1 night), called by TimeOfDay.apply_materials.
static func set_window_glow(w: float) -> void:
	_window_glow = w
	for k in _glass:
		(_glass[k] as ShaderMaterial).set_shader_parameter("window_glow", w)


static func build(a: PropKit.Accum, id: String) -> void:
	match id:
		"sky_a": _sky_square(a)
		"sky_b": _sky_setback(a)
		"sky_c": _sky_round(a)
		"sky_d": _sky_slab(a)
		"mall_a": _mall(a, 0)
		"mall_b": _mall(a, 1)
		"parking": _parking(a)
		"car_a": _car(a, "red")
		"car_b": _car(a, "blue")
		"car_c": _car(a, "white")
		"billboard": _billboard(a)
		"planter": _planter(a)


static func _box(a: PropKit.Accum, size: Vector3, pos: Vector3, mat: Material) -> void:
	a.add(PropKit.box(size), PropKit.T(pos), mat)


static func _lobby(a: PropKit.Accum, w: float, front_z: float) -> void:
	# Entrance canopy and dark doors on the +Z face.
	_box(a, Vector3(w * 0.45, 0.45, 3.2), Vector3(0, 4.3, front_z + 1.6), PropKit.m("navy"))
	_box(a, Vector3(w * 0.3, 3.6, 0.3), Vector3(0, 1.8, front_z + 0.1), PropKit.m("window_dark"))


static func _roof(a: PropKit.Accum, w: float, d: float, y: float, antenna: bool) -> void:
	_box(a, Vector3(w + 0.6, 1.4, d + 0.6), Vector3(0, y + 0.7, 0), PropKit.m("plaster_white"))
	_box(a, Vector3(w * 0.45, 3.0, d * 0.4), Vector3(0, y + 2.4, 0), PropKit.m("concrete"))
	if antenna:
		a.add(ShapeKit.cylinder(0.3, 12.0, 6), PropKit.T(Vector3(0, y + 9.0, 0)), PropKit.m("steel"))
		a.add(ShapeKit.sphere(0.6, 8, 6), PropKit.T(Vector3(0, y + 15.2, 0)), PropKit.m("red"))


## Square glass tower, 22 x 22 m, rooftop antenna.
static func _sky_square(a: PropKit.Accum) -> void:
	var w := 22.0
	_box(a, Vector3(w, TOWER_H, w), Vector3(0, TOWER_H * 0.5, 0), glass(0))
	_roof(a, w, w, TOWER_H, true)
	_lobby(a, w, w * 0.5)


## Teal tower with a setback after floor 12 and a roof garden.
static func _sky_setback(a: PropKit.Accum) -> void:
	var low_h := 12 * FLOOR_H
	_box(a, Vector3(26, low_h, 20), Vector3(0, low_h * 0.5, 0), glass(1))
	_box(a, Vector3(26.6, 0.7, 20.6), Vector3(0, low_h + 0.35, 0), PropKit.m("plaster_white"))
	_box(a, Vector3(22, 0.8, 4), Vector3(0, low_h + 1.1, 7.0), PropKit.m("hedge"))
	var up_h := TOWER_H - low_h
	var up := PropKit.box(Vector3(17, up_h, 13))
	a.add(up, PropKit.T(Vector3(0, low_h + up_h * 0.5, -2.5)), glass(1))
	_box(a, Vector3(17.6, 1.4, 13.6), Vector3(0, TOWER_H + 0.7, -2.5), PropKit.m("plaster_white"))
	_lobby(a, 26.0, 10.0)


## Round golden tower with a crown ring and spire.
static func _sky_round(a: PropKit.Accum) -> void:
	a.add(ShapeKit.cylinder(12.0, TOWER_H, 20), PropKit.T(Vector3(0, TOWER_H * 0.5, 0)), glass(2))
	a.add(ShapeKit.cylinder(12.6, 1.4, 20), PropKit.T(Vector3(0, TOWER_H + 0.7, 0)), PropKit.m("plaster_white"))
	a.add(ShapeKit.cone(9.0, 2.0, 7.0, 16), PropKit.T(Vector3(0, TOWER_H + 4.9, 0)), PropKit.m("gold_flat"))
	a.add(ShapeKit.cone(0.5, 0.05, 10.0, 6), PropKit.T(Vector3(0, TOWER_H + 13.4, 0)), PropKit.m("steel"))
	_lobby(a, 22.0, 12.0)


## Violet slab tower with white vertical fins on the long faces.
static func _sky_slab(a: PropKit.Accum) -> void:
	var w := 34.0
	var d := 15.0
	_box(a, Vector3(w, TOWER_H, d), Vector3(0, TOWER_H * 0.5, 0), glass(3))
	for i in 5:
		var x := -w * 0.5 + 3.0 + i * (w - 6.0) / 4.0
		for side: float in [-1.0, 1.0]:
			_box(a, Vector3(0.6, TOWER_H + 1.0, 1.0), Vector3(x, (TOWER_H + 1.0) * 0.5, side * (d * 0.5 + 0.4)), PropKit.m("plaster_white"))
	_roof(a, w, d, TOWER_H, false)
	# Rooftop sign frame (a "YR" crown-like frame, plain shapes)
	_box(a, Vector3(12, 3.5, 0.6), Vector3(0, TOWER_H + 4.6, 0), PropKit.m("orange"))
	_lobby(a, w, d * 0.5 + 0.9)


## Shopping mall: 64 x 36 m, 16 m tall. Glass front (+Z) over three levels,
## dark entrance with a canopy, a coloured sign band (the "MALL" letters are
## Label3D added by DowntownDecor), side stripes and roof units.
static func _mall(a: PropKit.Accum, v: int) -> void:
	var w := 64.0
	var d := 36.0
	var h := 16.0
	var body := "plaster_white" if v == 0 else "pastel_yellow"
	var accent := "red" if v == 0 else "purple"
	_box(a, Vector3(w, h, d), Vector3(0, h * 0.5, 0), PropKit.m(body))
	# Glass front: three tall shop levels (5 m floors).
	_box(a, Vector3(w - 10.0, 11.0, 0.6), Vector3(0, 6.0, d * 0.5 + 0.2), glass(4, 5.0, 16.0))
	# Sign band along the top of the front.
	_box(a, Vector3(w * 0.62, 3.6, 0.8), Vector3(0, h - 0.6, d * 0.5 + 0.5), PropKit.m(accent))
	# Entrance: dark doors, canopy and two pillars.
	_box(a, Vector3(12.0, 5.0, 0.4), Vector3(0, 2.5, d * 0.5 + 0.6), PropKit.m("window_dark"))
	_box(a, Vector3(16.0, 0.6, 6.0), Vector3(0, 5.6, d * 0.5 + 3.2), PropKit.m(accent))
	for side: float in [-1.0, 1.0]:
		a.add(ShapeKit.cylinder(0.35, 5.4, 8), PropKit.T(Vector3(side * 7.2, 2.7, d * 0.5 + 5.8)), PropKit.m("plaster_white"))
		# Coloured side stripes.
		_box(a, Vector3(0.6, h, d * 0.8), Vector3(side * (w * 0.5 + 0.25), h * 0.5, 0), PropKit.m(accent))
	if v == 1:
		# Glass rotunda on the front corner.
		a.add(ShapeKit.cylinder(8.0, h + 3.0, 16), PropKit.T(Vector3(w * 0.5 - 6.0, (h + 3.0) * 0.5, d * 0.5 - 2.0)), glass(4, 5.0, 19.0))
		a.add(ShapeKit.cylinder(8.6, 0.8, 16), PropKit.T(Vector3(w * 0.5 - 6.0, h + 3.2, d * 0.5 - 2.0)), PropKit.m("white"))
	# Roof units.
	for i in 3:
		_box(a, Vector3(5, 2.2, 4), Vector3(-16 + i * 16, h + 1.1, -6), PropKit.m("steel"))


## Parking lot 40 x 24 m with painted bays (two rows of 10) and a lamp.
static func _parking(a: PropKit.Accum) -> void:
	_box(a, Vector3(40, 0.14, 24), Vector3(0, 0.07, 0), PropKit.m("asphalt"))
	for row: float in [-1.0, 1.0]:
		for i in 11:
			_box(a, Vector3(0.18, 0.03, 5.2), Vector3(-17.5 + i * 3.5, 0.155, row * 8.6), PropKit.m("white"))
	_box(a, Vector3(36, 0.03, 0.2), Vector3(0, 0.155, 0), PropKit.m("flower_yellow"))
	a.add_committed(PropKit.get_mesh("lamp"), PropKit.T(Vector3(0, 0, 0)))


## Small parked car (body colour + dark cabin + wheels), 4.2 m long on Z.
static func _car(a: PropKit.Accum, col: String) -> void:
	a.add(PropKit.rbox(Vector3(1.9, 0.75, 4.2), 0.3), PropKit.T(Vector3(0, 0.62, 0)), PropKit.m(col))
	a.add(PropKit.rbox(Vector3(1.6, 0.62, 2.2), 0.3), PropKit.T(Vector3(0, 1.22, -0.2)), PropKit.m("window_dark"))
	for x: float in [-0.88, 0.88]:
		for z: float in [-1.35, 1.35]:
			a.add(ShapeKit.cylinder(0.36, 0.3, 10), PropKit.T(Vector3(x, 0.36, z), Vector3(0, 0, PI * 0.5)), PropKit.m("tire"))


## Roadside billboard: two posts and a bright 9 x 4 m board.
static func _billboard(a: PropKit.Accum) -> void:
	for x: float in [-3.0, 3.0]:
		a.add(ShapeKit.cylinder(0.22, 6.0, 8), PropKit.T(Vector3(x, 3.0, 0)), PropKit.m("steel"))
	_box(a, Vector3(9.4, 4.4, 0.4), Vector3(0, 7.6, 0), PropKit.m("white"))
	_box(a, Vector3(8.8, 3.8, 0.2), Vector3(0, 7.6, 0.18), PropKit.m("turquoise"))
	_box(a, Vector3(8.8, 1.1, 0.22), Vector3(0, 6.3, 0.2), PropKit.m("flower_yellow"))
	a.add(ShapeKit.sphere(1.0, 10, 8), PropKit.T(Vector3(-2.6, 8.2, 0.35)), PropKit.m("red"))
	_box(a, Vector3(4.0, 0.7, 0.24), Vector3(1.2, 8.4, 0.25), PropKit.m("white"))
	_box(a, Vector3(3.0, 0.5, 0.24), Vector3(0.7, 7.5, 0.25), PropKit.m("white"))


## Square stone planter with a small round tree (sidewalk greenery).
static func _planter(a: PropKit.Accum) -> void:
	_box(a, Vector3(2.4, 0.6, 2.4), Vector3(0, 0.3, 0), PropKit.m("concrete"))
	a.add(ShapeKit.cylinder(0.16, 2.4, 6), PropKit.T(Vector3(0, 1.6, 0)), PropKit.m("trunk"))
	a.add(ShapeKit.sphere(1.3, 10, 8), PropKit.T(Vector3(0, 3.3, 0)), PropKit.m("leaf"))
