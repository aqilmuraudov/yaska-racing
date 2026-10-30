class_name PerfReport
extends RefCounted
## Scene-composition and render counters for profiling (0.10.2):
## draw calls, objects and primitives in the last frame plus counts of the
## nodes that cost the most on a phone (shadow casters, lights, particles).


static func counts(root: Node) -> Dictionary:
	var c := {"meshes": 0, "visible_meshes": 0, "shadow_casters": 0, "multimesh": 0,
		"multimesh_instances": 0, "omni": 0, "spot": 0, "dir_shadow": 0,
		"particles": 0, "particle_amount": 0, "vis_range": 0, "vertices": 0}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is MultiMeshInstance3D:
			c.multimesh += 1
			var mm := (n as MultiMeshInstance3D).multimesh
			if mm:
				c.multimesh_instances += mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		elif n is MeshInstance3D:
			var mi := n as MeshInstance3D
			c.meshes += 1
			if mi.is_visible_in_tree() and mi.mesh:
				c.visible_meshes += 1
				if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					c.shadow_casters += 1
				if mi.visibility_range_end > 0.0:
					c.vis_range += 1
				for s in mi.mesh.get_surface_count():
					var arr := mi.mesh.surface_get_arrays(s) if mi.mesh is ArrayMesh else []
					if not arr.is_empty() and arr[Mesh.ARRAY_VERTEX] != null:
						c.vertices += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		elif n is OmniLight3D and (n as Light3D).is_visible_in_tree():
			c.omni += 1
		elif n is SpotLight3D and (n as Light3D).is_visible_in_tree():
			c.spot += 1
		elif n is DirectionalLight3D and (n as Light3D).shadow_enabled:
			c.dir_shadow += 1
		elif (n is GPUParticles3D or n is CPUParticles3D) and (n as Node3D).is_visible_in_tree():
			c.particles += 1
			c.particle_amount += int(n.get("amount"))
	return c


static func render_info() -> Dictionary:
	return {
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	}


static func line(root: Node) -> String:
	var d := counts(root)
	d.merge(render_info())
	d["fps"] = Engine.get_frames_per_second()
	d["preset"] = Settings.values.graphics.get("preset", "?")
	var parts: Array[String] = []
	for k in d:
		parts.append("%s=%s" % [k, str(d[k])])
	return "PERF " + " ".join(parts)


## Heaviest geometry: triangles x instances grouped by node path pattern.
static func top(root: Node, n := 20) -> String:
	var agg := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
		var mesh: Mesh = null
		var inst := 1
		var shadow := false
		var vr := 0.0
		if nd is MultiMeshInstance3D and (nd as MultiMeshInstance3D).multimesh:
			var mm := (nd as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			inst = mm.instance_count
			shadow = (nd as GeometryInstance3D).cast_shadow != 0
			vr = (nd as GeometryInstance3D).visibility_range_end
		elif nd is MeshInstance3D and (nd as MeshInstance3D).is_visible_in_tree():
			mesh = (nd as MeshInstance3D).mesh
			shadow = (nd as GeometryInstance3D).cast_shadow != 0
			vr = (nd as GeometryInstance3D).visibility_range_end
		if mesh == null:
			continue
		var tris := 0
		for s in mesh.get_surface_count():
			if mesh is ArrayMesh:
				var a := mesh.surface_get_arrays(s)
				var idx = a[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		var key := "%s/%s [%s] sh=%s vr=%d" % [nd.get_parent().name, String(nd.name).rstrip("0123456789"), mesh.resource_name, shadow, vr]
		var e: Array = agg.get(key, [0, 0, 0])
		agg[key] = [e[0] + tris * inst, e[1] + inst, mesh.get_surface_count()]
	var keys := agg.keys()
	keys.sort_custom(func(a, b): return agg[a][0] > agg[b][0])
	var out := ""
	for k in keys.slice(0, n):
		out += "TOP tris=%d inst=%d surf=%d %s\n" % [agg[k][0], agg[k][1], agg[k][2], k]
	return out
