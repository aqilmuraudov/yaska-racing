class_name KarabakhDecor
extends TrackDecor
## 0.18.0 Qarabağ (karabakh): a two-lane mountain road through summer forest.
## West: Laçın - the start straight in the river valley. North-east: the
## climb to the Şuşa plateau. East / south: the descent towards Xankəndi and
## the forest valley road back to Laçın (north = -z, as on every map).
##
## Owner (2026-11-10): the whole map is modelled in Blender; the environment
## comes first, the landmarks follow one by one when the owner names them.
## Their plots are reserved now, next to the road, so the forest never has to
## be re-laid when they arrive (0.17.3 lesson: landmarks far from the road
## are never seen).
## Exactly 13 build steps (the loading screen weights them).

## Landmark plots kept free of trees: "landmark_plots" in the track JSON,
## [x, z, radius, zone] (the Blender terrain reads the same list). Each sits
## a few metres behind the run-off on the outside of the road.
func landmark_plots() -> Array:
	return data.raw.get("landmark_plots", [])


func build_steps(td: TrackData, env: RaceEnvironment) -> Array[Callable]:
	return [
		func(): _begin(td); _reserve_kb_plots(),
		_place_kb_roadside,
		_place_kb_lamps,
		_build_gantry,
		_place_kb_forest,
		_place_corner_signs,
		func(): pass,
		func(): pass,
		func(): pass,
		_place_kb_sky,
		func(): pass,
		_flush_instances,
		func(): _finish(env),
	]


func _reserve_kb_plots() -> void:
	for pl: Array in landmark_plots():
		_reserved.append([Vector3(float(pl[0]), 0.0, float(pl[1])), float(pl[2])])


## Height of the ground (terrain), not of the nearest road sample: on a
## mountain the hillside beside the road is far above / below it.
func kb_ground(x: float, z: float) -> float:
	if builder:
		return builder.terrain_height(x, z)
	return ground_y(Vector3(x, 0.0, z))


## Reflector posts on both verges (white with a red / white reflector, as on
## Azerbaijani mountain roads): they also keep the road readable at night.
func _place_kb_roadside() -> void:
	var path := data.main
	var s := 0.0
	while s < path.length:
		var p := path.position_at(s)
		var r := path.right_at(s)
		for side: float in [-1.0, 1.0]:
			var q := p + r * side * (path.half_width_at(s) + data.offroad_width + 0.9)
			if clear_of_track(q, 0.2, -0.6):
				add_instance("kb_post", _face(Vector3(q.x, p.y - 0.05, q.z), -r * side))
		s += 25.0


## Modern LED lamps (as on the new Karabakh roads) every LAMP_STEP m on
## alternating sides, the head over the verge; at night they glow and drop
## light pools (NightGlow reads instance_transforms("lamp")).
const LAMP_STEP := 46.0
const LAMP_REACH := 2.9 ## head offset from the pole towards the road (m)
var _lamp_heads: Array = []


func _place_kb_lamps() -> void:
	var path := data.main
	var s := 10.0
	var k := 0
	while s < path.length:
		var p := path.position_at(s)
		var r := path.right_at(s)
		var side := 1.0 if k % 2 == 0 else -1.0
		var off := path.half_width_at(s) + data.offroad_width + 1.4
		var q := p + r * side * off
		if clear_of_track(q, 0.3, -0.8) and _free_of_reserved(q):
			var xf := _face(Vector3(q.x, p.y - 0.05, q.z), -r * side)
			add_instance("kb_lamp", xf)
			_lamp_heads.append(Transform3D(Basis.IDENTITY, Vector3(q.x, p.y, q.z) - r * side * LAMP_REACH))
		s += LAMP_STEP
		k += 1


func instance_transforms(prop: String) -> Array:
	if prop == "lamp":
		return _lamp_heads.duplicate()
	return super.instance_transforms(prop)


## The forest laid out in Blender (tools/blender/karabakh_terrain.py ->
## trees.json): oriental beech, oak, Caucasian hornbeam, maple, a few Kochi
## pines on the rocky heights, hazel thickets and limestone boulders. A meadow
## strip along the road, the landmark plots open. Beyond ~80 m the hillsides
## carry the baked forest canopy instead of single trees.
func _place_kb_forest() -> void:
	var dir := String(data.raw.get("terrain_dir", ""))
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir + "/trees.json")) if dir != "" else null
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for t: Array in parsed.trees:
		var p := Vector3(float(t[1]), float(t[2]), float(t[3]))
		# Blender already kept every tree >= 5 m behind the run-off (the
		# road test in round 34 checks it); only the reserved plots here.
		if not _free_of_reserved(p):
			continue
		add_instance(String(t[0]), Transform3D(Basis(Vector3.UP, float(t[4])).scaled(Vector3.ONE * float(t[5])), p))


## Soft clouds only (the other maps' backdrop carries Baku's skyline).
func _place_kb_sky() -> void:
	var b := AABB(data.main.points[0], Vector3.ZERO)
	for p in data.main.points:
		b = b.expand(p)
	var center := b.get_center()
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(1, 1, 1)
	cloud_mat.roughness = 1.0
	cloud_mat.emission_enabled = true
	cloud_mat.emission = Color(0.85, 0.88, 0.95)
	cloud_mat.emission_energy_multiplier = 0.35
	cloud_mat.disable_receive_shadows = true
	var clouds := PropKit.Accum.new()
	for i in 14:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(450.0, 800.0)
		var cpos := center + Vector3(cos(ang) * dist, rng.randf_range(130.0, 200.0), sin(ang) * dist)
		for k in 5:
			var sz := Vector3(rng.randf_range(40, 80), rng.randf_range(14, 24), rng.randf_range(26, 48))
			var off := Vector3(rng.randf_range(-35, 35), rng.randf_range(-4, 6), rng.randf_range(-15, 15))
			clouds.add(ShapeKit.superellipsoid(sz, 1.0, 1.0, Vector2.ONE, Vector2.ONE, 5, 8), Transform3D(Basis.IDENTITY, cpos + off), cloud_mat)
	var cloud_mi := _landmark(clouds.commit(), Transform3D.IDENTITY, "Clouds")
	cloud_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
