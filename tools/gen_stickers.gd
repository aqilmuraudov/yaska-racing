extends SceneTree
## 0.13.0 sticker art: renders the game's own landmark / prop meshes on a
## transparent background (SubViewport), 3/4 view. tools/gen_stickers.py then
## adds the white sticker border and writes assets/stickers/<id>.png.
##   godot --path . --rendering-method mobile -s tools/gen_stickers.gd -- <out_dir>
## (needs a display / xvfb; not the headless dummy renderer)

const SIZE := 512
## id -> [mesh ids (LandmarkKit, or "prop:<PropKit id>"), yaw, pitch]
const STICKERS := {
	"flame_towers": [["flame_towers"], 0.6, 0.12],
	"heydar_aliyev": [["heydar_aliyev"], 0.25, 0.22],
	"maiden_tower": [["prop:maiden_tower"], 0.7, 0.15],
	"crescent": [["crescent"], 0.4, 0.12],
	"government_house": [["government_house"], 0.35, 0.18],
	"carpet_museum": [["carpet_museum"], 0.8, 0.2],
	"flag_square": [["flag_square"], 0.5, 0.1],
	"qosa_qala": [["qosa_qala"], 0.3, 0.15],
	"baku_eye": [["prop:wheel_frame", "prop:wheel_ring"], 0.5, 0.05],
	"boat": [["prop:boat"], 0.9, 0.3],
	"fountain": [["prop:fountain"], 0.6, 0.35],
	"palm": [["prop:palm"], 0.4, 0.12],
}


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _mesh(id: String) -> Mesh:
	var LK: Script = load("res://scripts/track/landmark_kit.gd")
	var PK: Script = load("res://scripts/track/prop_kit.gd")
	return PK.get_mesh(id.substr(5)) if id.begins_with("prop:") else LK.get_mesh(id)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://stickers"
	DirAccess.make_dir_recursive_absolute(out_dir)
	for sid in STICKERS.keys():
		var def: Array = STICKERS[sid]
		var vp := SubViewport.new()
		vp.size = Vector2i(SIZE, SIZE)
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var we := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.background_color = Color(0, 0, 0, 0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.85, 0.88, 1.0)
		env.ambient_light_energy = 0.75
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.25
		we.environment = env
		vp.add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-35), 0)
		sun.light_energy = 1.3
		vp.add_child(sun)
		var aabb := AABB()
		var first := true
		for mid in def[0]:
			var mi := MeshInstance3D.new()
			mi.mesh = _mesh(String(mid))
			if mi.mesh == null:
				continue
			vp.add_child(mi)
			if String(mid) == "flag_square":
				load("res://scripts/track/landmark_kit.gd").attach_flag(mi) # flag at the top of the pole
			var a: AABB = mi.transform * mi.mesh.get_aabb()
			aabb = a if first else aabb.merge(a)
			first = false
		var c := aabb.get_center()
		var r := aabb.size.length() * 0.5
		var cam := Camera3D.new()
		cam.fov = 34.0
		cam.far = 5000.0
		vp.add_child(cam)
		var yaw := float(def[1])
		var pitch := float(def[2])
		var dist := r / tan(deg_to_rad(cam.fov * 0.5)) * 1.02
		cam.position = c + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
		cam.look_at(c, Vector3.UP)
		cam.current = true
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(out_dir.path_join(sid + ".png"))
		print("STICKER ", sid, " -> ", out_dir.path_join(sid + ".png"))
		vp.queue_free()
		await process_frame
	quit()
