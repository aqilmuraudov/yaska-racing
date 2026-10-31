extends SceneTree
## Triangle / draw counts of one racer's kart model (near and far LOD).
##   godot --headless --path . -s tools/kart_stats.gd -- yaska [procedural]
## Draws = mesh surfaces (one draw call each when visible).

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "yaska"
	var roster = load("res://scripts/vehicles/racer_roster.gd")
	var def = roster.get_def(id)
	if "procedural" in args:
		load("res://scripts/vehicles/kart_model.gd").gltf_enabled = false
	for lod in [["near", 1.0], ["far", 0.4]]:
		var shape_kit = load("res://scripts/effects/shape_kit.gd")
		shape_kit.detail = lod[1]
		var model = load("res://scripts/vehicles/kart_model.gd").new()
		model.lod_far = lod[0] == "far"
		root.add_child(model)
		model.build(def, false)
		shape_kit.detail = 1.0
		var tris := 0
		var draws := 0
		var driver_tris := 0
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			if not (mi as MeshInstance3D).visible or mi.name == "ShadowProxy":
				continue
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var a := mesh.surface_get_arrays(s)
				var n: int = (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] != null else a[Mesh.ARRAY_VERTEX].size()) / 3
				tris += n
				draws += 1
				if model.driver != null and model.driver.is_ancestor_of(mi):
					driver_tris += n
		print("KART_STATS id=%s lod=%s tris=%d driver_tris=%d draws=%d gltf=%s" % [id, lod[0], tris, driver_tris, draws, str(model.from_gltf)])
		model.free()
	quit()
