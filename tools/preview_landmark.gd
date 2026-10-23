extends SceneTree
## Art preview: renders one LandmarkKit / PropKit mesh under the race sky.
##   godot --path . -s tools/preview_landmark.gd -- <id> <out.png> [distance] [yaw]
## ids: any LandmarkKit id, or "prop:<PropKit id>".

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "crescent"
	var out: String = args[1] if args.size() > 1 else "user://preview.png"
	var dist := float(args[2]) if args.size() > 2 else 200.0
	var yaw := float(args[3]) if args.size() > 3 else 0.0
	var world := Node3D.new()
	root.add_child(world)
	var LK: Script = load("res://scripts/track/landmark_kit.gd")
	var PK: Script = load("res://scripts/track/prop_kit.gd")
	var SK: Script = load("res://scripts/effects/shape_kit.gd")
	var env = load("res://scripts/racing/race_environment.gd").new()
	world.add_child(env)
	env.build()
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2000, 2000)
	ground.mesh = pm
	ground.material_override = SK.mat(Color("6fbf4a"), 0.9)
	world.add_child(ground)
	var mi := MeshInstance3D.new()
	mi.mesh = PK.get_mesh(id.substr(5)) if id.begins_with("prop:") else LK.get_mesh(id)
	world.add_child(mi)
	if id == "flag_square":
		LK.attach_flag(mi)
	var aabb := mi.get_aabb()
	var c := aabb.get_center()
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 3000.0
	world.add_child(cam)
	var dir := Vector3(sin(yaw), 0.0, cos(yaw))
	cam.position = c + dir * dist + Vector3.UP * (aabb.size.y * 0.15)
	cam.look_at(c, Vector3.UP)
	cam.current = true
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("PREVIEW ", id, " aabb=", aabb, " -> ", out)
	quit()
