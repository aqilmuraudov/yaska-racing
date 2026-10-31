extends TestCase
## Round 26 (0.14.1): every racer's kart + driver and the Old City houses /
## Maiden Tower as baked Blender models (tools/blender/*.py).

const OLD_CITY := ["house_a", "house_b", "house_c", "house_d", "maiden_tower"]


func after_each() -> void:
	KartModel.gltf_enabled = true
	PropKit.gltf_enabled = true
	PropKit.set_window_glow(0.0)


func _tris(mesh: Mesh) -> int:
	var t := 0
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		t += (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] != null else a[Mesh.ARRAY_VERTEX].size()) / 3
	return t


func _model_tris(m: KartModel) -> int:
	var t := 0
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		t += _tris((mi as MeshInstance3D).mesh)
	return t


func test_every_racer_is_a_blender_model() -> void:
	for id in RacerRoster.IDS:
		var def := RacerRoster.get_def(id)
		check(KartModel.GLTF_MODELS.has(def.kart_style), "%s has a glTF model" % id)
		var m := KartModel.new()
		tree.root.add_child(m)
		m.build(def, false)
		check(m.from_gltf, "%s builds from glTF" % id)
		var t := _model_tris(m)
		check(t <= 13000, "%s near model <= 13k triangles (%d)" % [id, t])
		var names := {}
		for mi in m.find_children("Gltf*", "MeshInstance3D", true, false):
			names[String(mi.name)] = true
		for p in ["GltfBody", "GltfWheelFL", "GltfWheelFR", "GltfWheelRear", "GltfSteeringWheel", "GltfTorso",
				"GltfHead", "GltfEyes", "GltfArmL", "GltfArmR"]:
			check(names.has(p), "%s has %s" % [id, p])
		var tips: Array = KartModel.GLTF_EXHAUST[def.kart_style]
		check(m.exhaust_points.size() == tips.size() and m.exhaust_points[0].is_equal_approx(tips[0]),
			"%s smoke starts at its glTF exhaust" % id)
		m.free()
		var far := KartModel.new()
		far.lod_far = true
		tree.root.add_child(far)
		far.build(def, false)
		check(far.from_gltf and _model_tris(far) <= 2200, "%s far model <= 2.2k triangles" % id)
		far.free()


func test_animal_ears_and_tails_ride_their_pivots() -> void:
	for id in ["havhav", "bicok", "mestan", "posi", "leloyun", "cepis"]:
		var m := KartModel.new()
		tree.root.add_child(m)
		m.build(RacerRoster.get_def(id), false)
		var ear: Node = m.find_child("GltfEarL", true, false)
		check(ear != null and m.driver.ears[0].is_ancestor_of(ear), "%s left ear on its pivot" % id)
		var tail: Node = m.find_child("GltfTail", true, false)
		if id in ["havhav", "bicok", "mestan"]:
			check(tail != null and m.driver.tail.is_ancestor_of(tail), "%s tail on the tail pivot" % id)
		else:
			check(tail == null, "%s tail hidden behind the seat has no mesh" % id)
		m.free()


func test_old_city_props_are_baked() -> void:
	PropKit._meshes.clear()
	for id in OLD_CITY:
		var mesh := PropKit.get_mesh(id)
		check(mesh != null and mesh.get_surface_count() == 1, "%s: one surface (one draw per MultiMesh)" % id)
		var mat := mesh.surface_get_material(0) as ShaderMaterial
		check(mat != null and mat.shader == PropKit.PROP_BAKED_SHADER, "%s uses the baked prop shader" % id)
		var lo := PropKit.get_mesh(id + PropKit.LO_SUFFIX)
		check(lo != mesh and _tris(lo) < _tris(mesh), "%s far LOD is lighter" % id)
		var box := mesh.get_aabb()
		check(absf(box.position.y) < 0.4, "%s stands on the ground" % id)
	var house := PropKit.get_mesh("house_a").get_aabb()
	check(absf(house.size.x - 9.3) < 0.6 and house.end.z > 3.9, "house_a keeps its footprint and +Z facade")
	check(_tris(PropKit.get_mesh("maiden_tower")) < 4368, "Maiden Tower lighter than the procedural one")


func test_window_glow_follows_time_of_day() -> void:
	var mat := PropKit.get_mesh("house_b").surface_get_material(0) as ShaderMaterial
	TimeOfDay.apply_materials("night")
	check(float(mat.get_shader_parameter("window_glow")) > 0.5, "windows glow at night")
	TimeOfDay.apply_materials("day")
	check(float(mat.get_shader_parameter("window_glow")) < 0.01, "no glow by day")


func test_procedural_fallback() -> void:
	PropKit._meshes.clear()
	PropKit.gltf_enabled = false
	var mesh := PropKit.get_mesh("house_a")
	check(mesh.get_surface_count() > 1, "switch off -> procedural house (several materials)")
	PropKit._meshes.clear()
	PropKit.gltf_enabled = true
	check(PropKit.get_mesh("house_a").get_surface_count() == 1, "back on -> baked house")
