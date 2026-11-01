extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = root.get_node("Game")
	var out: String = OS.get_cmdline_user_args()[0]
	var cfg: Dictionary = game.default_race_config()
	cfg.track_id = "seafront_sprint"
	game.race_config = cfg
	var race = load("res://scenes/race/race.tscn").instantiate()
	root.add_child(race)
	for i in 30:
		await process_frame
	race.hud.visible = false
	var cam := Camera3D.new()
	cam.far = 4000.0
	race.add_child(cam)
	var lid: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "flame_towers"
	var t: Transform3D = race.decor.landmarks[lid].global_transform
	var kp: Vector3 = race.player.kart.global_position
	var views := {"sea": kp + Vector3(0, 6, 0), "near": t.origin + Vector3(-120, 40, 220), "boul": Vector3(300, 8, 40)}
	if lid != "flame_towers":
		var bz := t.basis.z.normalized()
		var bx := t.basis.x.normalized()
		views = {"front": t.origin + bz * 230.0 + Vector3.UP * 12.0, "angle": t.origin + bz * 170.0 + bx * 150.0 + Vector3.UP * 20.0, "side": t.origin - bx * 220.0 + bz * 60.0 + Vector3.UP * 15.0}
	for k in views:
		cam.global_position = views[k]
		cam.look_at(t.origin + Vector3.UP * (60.0 if lid == "flame_towers" else 18.0))
		cam.current = true
		for i in 10:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, lid, k])
		print("SAVED ", k)
	quit()
