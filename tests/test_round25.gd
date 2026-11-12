extends TestCase
## Round 25 (0.14.0): Blender pilot - Yaska Star kart + Yaska driver as a
## baked glTF model (tools/blender/yaska_star.py) on the procedural rig.

const GLB := "res://assets/models/yaska/yaska_star.glb"
const GLB_FAR := "res://assets/models/yaska/yaska_star_far.glb"
const PARTS := ["Body", "WheelFL", "WheelFR", "WheelRear", "SteeringWheel", "Torso", "Head", "Eyes",
	"BraidL", "BraidR", "ArmL", "ArmR"]


func after_each() -> void:
	KartModel.gltf_enabled = true
	ShapeKit.detail = 1.0


func _model(id: String, far := false, def: RacerDefinition = null) -> KartModel:
	var m := KartModel.new()
	m.lod_far = far
	tree.root.add_child(m)
	m.build(def if def != null else RacerRoster.get_def(id), false)
	return m


func _stats(m: KartModel) -> Dictionary:
	var tris := 0
	var draws := 0
	var names := {}
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		names[String(mi.name)] = mi
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			tris += (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] != null else a[Mesh.ARRAY_VERTEX].size()) / 3
			draws += 1
	return {"tris": tris, "draws": draws, "names": names}


func _aabb_in_kart(m: KartModel, mi: MeshInstance3D) -> AABB:
	var xf := m.global_transform.affine_inverse() * mi.global_transform
	return xf * mi.mesh.get_aabb()


func test_files_and_textures() -> void:
	check(ResourceLoader.exists(GLB) and ResourceLoader.exists(GLB_FAR), "near and far glTF imported")
	for t in ["albedo", "normal", "orm"]:
		var tex: Texture2D = load("res://assets/models/yaska/%s.png" % t)
		check(tex != null, "%s texture loads" % t)
		if tex:
			check(tex.get_width() == 2048 and tex.get_height() == 2048, "%s is 2048x2048 (0.21: sharper kart textures, 14 MB per kart in VRAM)" % t)


func test_yaska_uses_gltf_on_the_rig() -> void:
	var m := _model("yaska")
	check(m.from_gltf, "Yaska Star builds from the glTF")
	var st := _stats(m)
	for p in PARTS:
		check(st.names.has("Gltf" + p), "part %s attached to its rig node" % p)
	check(st.draws == PARTS.size(), "one draw per rig part (%d)" % st.draws)
	check(st.tris <= 15000, "near model within 15k triangles (%d)" % st.tris)
	# No procedural meshes left on the rig (only the glTF parts).
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		check(String(mi.name).begins_with("Gltf"), "no procedural mesh %s" % mi.name)
	# Parts ride on the animated pivots.
	check(m.wheel_spinners[0].is_ancestor_of(st.names["GltfWheelFL"]), "front-left tyre spins with its pivot")
	check(m.steering_spin.is_ancestor_of(st.names["GltfSteeringWheel"]), "steering wheel turns with the column")
	check(m.driver.head.is_ancestor_of(st.names["GltfHead"]), "head turns with the head pivot")
	check(m.driver.eyes[0].is_ancestor_of(st.names["GltfEyes"]), "eyes blink with the eye pivot")
	check(m.driver.ears[0].is_ancestor_of(st.names["GltfBraidL"]), "left braid swings on the pigtail pivot")
	check(m.driver.arms[1].is_ancestor_of(st.names["GltfArmR"]), "right arm reaches with the shoulder")
	var mat := (st.names["GltfBody"] as MeshInstance3D).material_override as ShaderMaterial
	check(mat != null and mat.shader == KartModel.BAKED_SHADER, "baked kart shader")
	m.free()


func test_parts_sit_where_the_rig_expects() -> void:
	var m := _model("yaska")
	var st := _stats(m)
	var body := _aabb_in_kart(m, st.names["GltfBody"])
	check(body.position.y > -0.02 and body.end.y < 1.3, "body between ground and roll hoop (%s)" % body)
	check(absf(body.get_center().x) < 0.02, "body centred (%s)" % body.get_center())
	check(body.position.z > -1.35 and body.end.z < 1.35, "body length inside bumpers (%s)" % body)
	var fl := _aabb_in_kart(m, st.names["GltfWheelFL"])
	check(fl.get_center().distance_to(Vector3(-0.62, 0.30, -0.72)) < 0.05, "front-left tyre centred on its pivot")
	check(absf(fl.position.y) < 0.02, "tyre touches the ground")
	var head := _aabb_in_kart(m, st.names["GltfHead"])
	check(head.get_center().distance_to(Vector3(0, 1.21, 0.16)) < 0.08, "head above the torso (%s)" % head.get_center())
	var eyes := _aabb_in_kart(m, st.names["GltfEyes"])
	check(absf(eyes.get_center().y - 1.22) < 0.03 and eyes.position.z < head.position.z + 0.06, "eyes on the face")
	# Arms authored along -Z from the shoulder: the hand ends about one arm length ahead.
	var arm := (st.names["GltfArmR"] as MeshInstance3D)
	var local := arm.transform * arm.mesh.get_aabb()
	check(local.position.z < -0.4, "arm reaches forward (%s)" % local)
	m.free()


func test_animation_runs_on_gltf_parts() -> void:
	var m := _model("yaska")
	var eyes: Node3D = m.driver.eyes[0]
	for i in 30:
		m.update_wheels(i * 0.2, 0.3, 0.0)
		m.update_driver(0.8, 0, false, 1.0 / 60.0, i > 15, false, 0.0)
	check_near(m.wheels[0].rotation.y, 0.3, 0.001, "front wheel steers")
	check_near(m.wheel_spinners[2].rotation.x, 29 * 0.2, 0.001, "rear tyres spin")
	check(absf(m.steering_spin.rotation.y) > 0.5, "steering wheel turned")
	check(absf(m.driver.head.rotation.y) > 0.05, "head looks into the turn")
	check(eyes.scale.y > 0.0, "eyes scale stays valid")
	check(m.driver.arms[0].get_child(0).basis.z.length() > 0.5, "arm aimed at the rim")
	# Tread strobing fix: fast spin blurs the tyres, slow / stopped keeps the detail.
	var tyre: MeshInstance3D = m.find_child("GltfWheelFL", true, false)
	check(float(tyre.get_instance_shader_parameter(&"spin_blur")) > 0.9, "fast spin -> tread blurred")
	for i in 3:
		m.update_wheels(29 * 0.2 + i * 0.01, 0.0, 0.0)
	check(float(tyre.get_instance_shader_parameter(&"spin_blur")) < 0.05, "slow spin -> sharp tread")
	check_near(KartModel.spin_blur_for(0.0), 0.0, 0.001, "no blur when stopped")
	check_near(KartModel.spin_blur_for(-1.5), 1.0, 0.001, "full blur at race speed (either direction)")
	m.free()


func test_far_lod_and_visual() -> void:
	var far := _model("yaska", true)
	check(far.from_gltf, "far copy uses the far glTF")
	var st := _stats(far)
	check(st.tris <= 2200, "far model about 1.5-2k triangles (%d)" % st.tris)
	far.free()
	# KartVisual wires near + far exactly as for procedural karts.
	var kart := KartController.new()
	tree.root.add_child(kart)
	var vis := KartVisual.new()
	kart.add_child(vis)
	vis.setup(kart, RacerRoster.get_def("yaska"), 0.7)
	check(vis.model.from_gltf and vis.model_lo.from_gltf and vis.model_lo.lod_far, "visual near + far from glTF")
	check(vis.shadow_proxies > 0, "far meshes cast the shadows for the near model")
	var near_body: MeshInstance3D = vis.model.find_child("GltfBody", true, false)
	check(near_body.visibility_range_end > 0.0, "near body stops at the LOD distance")
	check(near_body in vis.outlined, "body gets the cartoon outline")
	kart.free()


func test_exhaust_and_paint() -> void:
	var m := _model("yaska")
	check(m.exhaust_points.size() == 2 and m.exhaust_points[0].y > 0.9, "smoke/flames start at the tall exhaust tips")
	var body: MeshInstance3D = m.find_child("GltfBody", true, false)
	check(body.get_instance_shader_parameter(&"paint") == null or (body.get_instance_shader_parameter(&"paint") as Color).a == 0.0,
		"own colour: no paint override")
	m.free()
	var painted := KartPaints.painted(RacerRoster.get_def("yaska"), 2)
	var m2 := _model("yaska", false, painted)
	var body2: MeshInstance3D = m2.find_child("GltfBody", true, false)
	var p = body2.get_instance_shader_parameter(&"paint")
	check(p is Color and (p as Color).is_equal_approx(KartPaints.color_of(RacerRoster.get_def("yaska"), 2)), "garage paint reaches the shader")
	m2.free()


func test_fallback_and_other_racers() -> void:
	KartModel.gltf_enabled = false
	var m := _model("yaska")
	check(not m.from_gltf, "switch off -> procedural Yaska Star")
	check(_stats(m).tris > 5000, "procedural model still complete")
	m.free()
	KartModel.gltf_enabled = true
	for id in RacerRoster.IDS:
		var o := _model(id)
		var want := KartModel.GLTF_MODELS.has(RacerRoster.get_def(id).kart_style)
		check(o.from_gltf == want, "%s uses glTF only when it has a model" % id)
		o.free()
