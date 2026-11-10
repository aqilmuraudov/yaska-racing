extends SceneTree
## 0.18.0: writes a track's road samples for the Blender terrain scripts
## (TrackPath is the single source of truth for the road):
##   godot --headless --path . -s tools/export_road_samples.gd -- karabakh
## -> tools/blender/out/<id>_road.json
## {points: [[x,y,z]...] (Godot space), half_widths, offroad_width, length,
##  finish: [x,y,z], landmark_plots}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id := String(args[0]) if args.size() > 0 else "karabakh"
	var td_script: GDScript = load("res://scripts/track/track_data.gd")
	var td = td_script.load_from_file("res://data/tracks/%s.json" % id)
	var pts := []
	for p in td.main.points:
		pts.append([snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)])
	var hw := []
	for w in td.main.half_widths:
		hw.append(snappedf(w, 0.001))
	var f: Vector3 = td.main.position_at(td.finish_s)
	var out := {"id": id, "points": pts, "half_widths": hw, "offroad_width": td.offroad_width,
		"length": td.main.length, "finish": [f.x, f.y, f.z], "landmark_plots": td.raw.get("landmark_plots", [])}
	var path := ProjectSettings.globalize_path("res://tools/blender/out/%s_road.json" % id)
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_string(JSON.stringify(out))
	fa.close()
	print("WROTE %s (%d samples, %.0f m)" % [path, pts.size(), td.main.length])
	quit(0)
