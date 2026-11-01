extends TestCase
## Round 30 (0.15.3): the remaining set pieces in Blender - Heydar Aliyev
## Center glass front + plaza, State Flag Square, start / finish gantry,
## hanging carpets, bunting poles (tools/blender/plaza_props.py).

const IDS := ["hac_base", "flag_square", "gantry_pillar", "gantry_seg", "gantry_lights", "carpet_hang", "bunting_pole"]


func test_plaza_modules_exist() -> void:
	for id in IDS:
		check(ResourceLoader.exists(String(PropKit.GLTF_PROPS[id]) + ".glb"), "glb " + id)
		check(PropKit.get_mesh(id) != null, "mesh " + id)
		check(PropKit.get_mesh(id + PropKit.LO_SUFFIX) != null, "far mesh " + id)


func test_hac_keeps_white_shell() -> void:
	var m := LandmarkKit.get_mesh("heydar_aliyev")
	var white := false
	for i in m.get_surface_count():
		if m.surface_get_material(i) == LandmarkKit.hac_white():
			white = true
	check(white, "self-lit white shell kept")
	check(m.get_aabb().size.x > LandmarkKit.HAC_L, "shell + plaza")


func test_flag_square_mast_height() -> void:
	var m := LandmarkKit.get_mesh("flag_square")
	var top := m.get_aabb().end.y
	check(absf(top - (2.6 + LandmarkKit.FLAG_POLE_H + 1.7)) < 1.0, "mast top matches the flag (%.1f)" % top)


func test_carpet_uvs_cover_cloth() -> void:
	var m: Mesh = TrackDecor._carpet_mesh()
	var arrays := m.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var lo := Vector2(9, 9)
	var hi := Vector2(-9, -9)
	for uv in uvs:
		lo = Vector2(minf(lo.x, uv.x), minf(lo.y, uv.y))
		hi = Vector2(maxf(hi.x, uv.x), maxf(hi.y, uv.y))
	check(lo.x <= 0.01 and hi.x >= 0.99, "u spans the cloth")
	check(lo.y <= 0.01 and hi.y >= 0.99, "v spans the cloth")


func test_terrain_height_helper() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/track/track_decor.gd")
	check(src.find("builder.terrain_height") > 0, "flag square stands on the terrain")
