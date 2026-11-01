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
	var t: Transform3D = race.decor.landmarks["flame_towers"].global_transform
	var kp: Vector3 = race.player.kart.global_position
	var views := {"sea": kp + Vector3(0, 6, 0), "near": t.origin + Vector3(-120, 40, 220), "boul": Vector3(300, 8, 40)}
	for k in views:
		cam.global_position = views[k]
		cam.look_at(t.origin + Vector3.UP * 60.0)
		cam.current = true
		for i in 10:
			await process_frame
		root.get_texture().get_image().save_png("%s/flame_%s.png" % [out, k])
		print("SAVED ", k)
	quit()
