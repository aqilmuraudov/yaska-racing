class_name OldCityDecor
extends TrackDecor
## 0.13.0 İçərişəhər (old_city): narrow cobbled streets of the Old City.
## Reuses the generic TrackDecor pieces - Old City houses with carpets along
## every THEME_OLDCITY street, Qoşa Qala with its walls where the Boulevard
## start straight enters the Old City, the finish gantry, corner signs,
## bunting, distant hills - and adds its own: the Maiden Tower in the middle
## of the block, a short Boulevard (palms, lamps, balustrade) along the sea,
## a few market umbrellas and kiosks, the Flame Towers on the far hill.
## Exactly 13 build steps (the loading screen weights them).

const MAIDEN_SITE := Vector3(-30.0, 0.0, -28.0)
const FLAME_SITE := Vector3(-470.0, 0.0, -430.0)
const SEA_SIDE := 1.0 ## +z is the sea


func build_steps(td: TrackData, env: RaceEnvironment) -> Array[Callable]:
	return [
		func(): _begin(td),
		_place_wall_props,
		_place_oc_boulevard,
		_place_old_city,
		_place_oc_landmarks,
		_place_corner_signs,
		_place_bunting,
		_place_backdrop,
		_place_oc_market,
		_place_oc_fill,
		func(): pass,
		_flush_instances,
		func(): _finish(env),
	]


## Houses keep 46 m from the tower (TrackDecor._place_old_city).
func _tower_position() -> Vector3:
	return Vector3(MAIDEN_SITE.x, ground_y(MAIDEN_SITE), MAIDEN_SITE.z)


func _place_oc_landmarks() -> void:
	var tp := _tower_position()
	var tower := _landmark(PropKit.get_mesh("maiden_tower"),
		Transform3D(Basis(Vector3.UP, -PI * 0.5).scaled(Vector3.ONE * 1.3), Vector3(tp.x, tp.y - 0.05, tp.z)), "MaidenTower")
	tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	landmarks["maiden_tower"] = tower
	_build_gate()
	_build_gantry()
	var ft := _landmark(LandmarkKit.get_mesh("flame_towers_far"),
		Transform3D(Basis(Vector3.UP, 0.7), Vector3(FLAME_SITE.x, ground_y(FLAME_SITE) - 1.0, FLAME_SITE.z)), "FlameTowers")
	ft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	landmarks["flame_towers"] = ft


## The Boulevard start straight: palms and lamps on the sea side, a
## balustrade along the sea wall.
func _place_oc_boulevard() -> void:
	var path := data.main
	var s := 0.0
	var k := 0
	while s < path.length:
		if path.theme_at(s) != TrackData.THEME_BOULEVARD:
			s += 4.0
			continue
		var p := path.position_at(s)
		var r := path.right_at(s)
		var side := SEA_SIDE if r.z * SEA_SIDE > 0.0 else -SEA_SIDE
		var off := path.half_width_at(s) + data.offroad_width + 3.0
		var q := p + r * side * off
		if clear_of_track(q, 1.2, 0.5):
			if k % 2 == 0:
				add_instance("palm" if k % 4 == 0 else "palm_b", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q.x, -0.05, q.z)))
			else:
				add_instance("lamp", _face(Vector3(q.x, -0.05, q.z), -r * side))
		# Inland side: benches and flower beds in front of the Old City wall.
		var qi := p - r * side * (path.half_width_at(s) + data.offroad_width + 2.2)
		if k % 3 == 1 and clear_of_track(qi, 1.4, 0.4):
			add_instance("flower_bed" if k % 2 == 0 else "bench", _face(Vector3(qi.x, -0.05, qi.z), r * side))
		var qb := p + r * side * (off + 5.0)
		if clear_of_track(qb, 1.0, 0.3):
			var along := path.tangent_at(s)
			add_instance("baluster", Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)).orthonormalized(), Vector3(qb.x, 0.17, qb.z)))
		s += 2.0 if k % 2 == 0 else 9.0
		k += 1


## A few market umbrellas and kiosks in the open corners of the block.
func _place_oc_market() -> void:
	var path := data.main
	var placed := 0
	var s := 20.0
	while s < path.length and placed < 14:
		if path.theme_at(s) == TrackData.THEME_OLDCITY and absf(path.curvature_at(s, 8.0)) > 0.02:
			var p := path.position_at(s)
			var r := path.right_at(s)
			var inside := -1.0 if path.curvature_at(s, 8.0) > 0.0 else 1.0 # away from the turn
			var q := p + r * inside * (path.half_width_at(s) + data.offroad_width + 3.5)
			if clear_of_track(q, 2.2, 0.8):
				add_instance("umbrella" if placed % 3 else "kiosk", _face(Vector3(q.x, -0.05, q.z), -r * inside))
				placed += 1
				s += 18.0
				continue
		s += 6.0


## The Old City is dense: fill the block inside the loop and a band outside
## it with houses on a 12 m grid (facing the nearest street), leaving some
## courtyards with a tree, a clear ring round the Maiden Tower and the sea
## side free.
const FILL_STEP := 12.0
const FILL_BAND := 70.0


func _place_oc_fill() -> void:
	var houses := ["house_a", "house_b", "house_c", "house_d"]
	var b := AABB(data.main.points[0], Vector3.ZERO)
	for q in data.main.points:
		b = b.expand(q)
	b = b.grow(FILL_BAND)
	var tp := _tower_position()
	var x := b.position.x
	while x < b.end.x:
		var z := b.position.z
		while z < b.end.z:
			var c := Vector3(x + rng.randf_range(-1.5, 1.5), 0.0, z + rng.randf_range(-1.5, 1.5))
			z += FILL_STEP
			if c.z > data.sea_z - 30.0:
				continue # the Boulevard and the sea stay open
			if Vector2(c.x - tp.x, c.z - tp.z).length() < 34.0:
				continue
			if not clear_of_track(c, 7.0, 1.5):
				continue
			var cl := data.main.closest(c)
			var t: Vector3 = data.main.tangent_at(cl.s)
			var to_road: Vector3 = (data.main.position_at(cl.s) - c)
			to_road.y = 0.0
			var face := to_road.normalized() if to_road.length() > 0.1 else t
			# Snap to the street direction so rows line up.
			var along := absf(face.dot(t)) > 0.7
			if along:
				face = t * signf(face.dot(t))
			var roll := rng.randf()
			if roll < 0.12:
				add_instance("tree" if roll < 0.08 else "cypress", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(c.x, -0.05, c.z)))
				continue
			add_instance(houses[rng.randi() % houses.size()], _face(Vector3(c.x, -0.05, c.z), face))
		x += FILL_STEP

