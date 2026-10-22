extends SceneTree

func _init() -> void:
	var td := TrackData.load_from_file("res://data/tracks/seafront_sprint.json")
	print("main length: ", td.main.length, " samples: ", td.main.sample_count())
	print("finish_s: ", td.finish_s)
	print("checkpoints: ", td.checkpoint_s)
	for sc in td.shortcuts:
		print("shortcut len ", sc.path.length, " from ", sc.s_from, " to ", sc.s_to, " side ", sc.side, " main span ", td.main.forward_delta(sc.s_from, sc.s_to))
	print("pads: ", td.boost_pads)
	print("ramps: ", td.ramps)
	var min_r := INF
	var at := 0.0
	var s := 0.0
	while s < td.main.length:
		var c := absf(td.main.curvature_at(s))
		if c > 0.0001 and 1.0 / c < min_r:
			min_r = 1.0 / c
			at = s
		s += 2.0
	print("min radius ", min_r, " at s=", at, " pos ", td.main.position_at(at))
	quit()
