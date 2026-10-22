class_name DebugRunner
extends Node
## Development harness driven by command-line user args (after "--"):
##   --race                 skip menus and load the race directly
##   --autopilot            the player kart is driven by the AI
##   --seed=N --difficulty=easy|medium|hard --kart=ID --laps=N --ai=N
##   --graphics=low|medium|high
##   --capture=DIR          save screenshots to DIR
##   --capture-times=a,b,c  race-clock seconds to capture (default 3,10,25)
##   --overview             one extra top-down screenshot of the layout
##   --views=s1,s2,...      screenshots from fixed cameras at track distances
##   --screens=main,mode,kart,track,settings,credits,loading  capture menus
##   --quit-after=SECONDS   quit after this many real seconds
##   --stats                print per-second FPS / frame time / memory
##   --timescale=X          Engine.time_scale for fast soak runs
##   --probe=T              print every kart's position once race time >= T
##   --quit-on-results      print the race summary and quit when results show
## Used for screenshots, soak tests and reproducible AI races.

var args := {}
var _capture_dir := ""
var _capture_times: Array[float] = []
var _captured := {}
var _elapsed := 0.0
var _quit_after := -1.0
var _stats := false
var _stat_timer := 0.0
var _frame_times: Array[float] = []
var _overview_done := false
var _views_done := false
var _probe_done := false


static func parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return out


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	args = parse_args()
	_capture_dir = args.get("capture", "")
	if _capture_dir != "":
		DirAccess.make_dir_recursive_absolute(_capture_dir)
		for t in String(args.get("capture-times", "3,10,25")).split(","):
			_capture_times.append(float(t))
	_quit_after = float(args.get("quit-after", "-1"))
	_stats = args.has("stats")
	if args.has("timescale"):
		Engine.time_scale = float(args.timescale)
	if args.has("graphics"):
		Settings.apply_preset(args.graphics, false)
	if args.has("screens"):
		call_deferred("_capture_screens")
	if args.has("race"):
		var cfg := Game.default_race_config()
		cfg.debug_autopilot = args.has("autopilot")
		cfg.seed = int(args.get("seed", "1234"))
		cfg.active_seed = cfg.seed
		cfg.difficulty = args.get("difficulty", "medium")
		cfg.kart_id = args.get("kart", "balanced")
		cfg.laps = int(args.get("laps", "3"))
		cfg.ai_count = int(args.get("ai", "5"))
		cfg.mode = args.get("mode", "quick")
		cfg.event_instance_id = "debug-%d" % Time.get_ticks_usec()
		Game.race_config = cfg
		call_deferred("_enter_race")


func _capture_screens() -> void:
	var map := {"main": Game.State.MAIN_MENU, "mode": Game.State.MODE_SELECT, "kart": Game.State.KART_SELECT,
		"track": Game.State.TRACK_SELECT, "settings": Game.State.SETTINGS, "credits": Game.State.CREDITS}
	await get_tree().create_timer(1.0).timeout
	for name in String(args.screens).split(","):
		if name.begins_with("settings"):
			Game.goto(Game.State.SETTINGS)
			await get_tree().create_timer(1.2).timeout
			var tab := int(name.substr(8)) if name.length() > 8 else 0
			var scr = get_tree().current_scene
			if scr and scr.has_method("_show_tab"):
				scr._show_tab(tab)
			await get_tree().create_timer(0.4).timeout
		elif map.has(name):
			Game.goto(map[name])
			await get_tree().create_timer(1.6).timeout
		else:
			continue
		if _capture_dir != "":
			await _save_shot("screen_%s.png" % name)
	get_tree().quit()


func _enter_race() -> void:
	Game.enter_race(load(Game.RACE_SCENE))


func _process(delta: float) -> void:
	_elapsed += delta / maxf(Engine.time_scale, 0.001)
	var race := get_tree().current_scene as RaceManager
	if race != null and _capture_dir != "":
		if args.has("overview") and not _overview_done and _elapsed > 1.0:
			_overview_done = true
			_capture_overview(race)
		if args.has("views") and not _views_done and _elapsed > 1.5 and _overview_done == args.has("overview"):
			_views_done = true
			_capture_views(race)
		for t in _capture_times:
			if not _captured.has(t) and race.race_time >= t and race.state >= RaceManager.RaceState.RACING:
				_captured[t] = true
				_save_shot("race_%05.1fs.png" % t)
	if _stats:
		_frame_times.append(delta)
		_stat_timer += delta
		if _stat_timer >= 1.0:
			_print_stats(race)
			_stat_timer = 0.0
			_frame_times.clear()
	var results_now := args.has("quit-on-results") and race != null and race.state == RaceManager.RaceState.RESULTS
	if (_quit_after > 0.0 and _elapsed >= _quit_after) or results_now:
		if race != null:
			print("RACE_STATE state=%d time=%.2f" % [race.state, race.race_time])
			for r in race.racers:
				print("RACER %-6s %-8s place=%d lap=%d finished=%s time=%.2f best=%.2f dist=%.0f scale=%.3f diff=%s %s" % [r.name, r.kart.stats.id, r.place, r.tracker.current_lap(), r.tracker.finished, r.tracker.finish_time, r.tracker.best_lap, r.tracker.race_distance, r.kart.speed_scale, str(r.ai.profile.get("speed_factor")), "off=%.1fs drift=%.1fs boost=%.1fs avg=%.1f sc=%d it=%d db=%d hh=%d rec=%d" % [r.stats.offroad_s, r.stats.drift_s, r.stats.boost_s, r.stats.speed_sum / maxf(r.stats.ticks, 1), r.stats.shortcut_uses, r.stats.items_used, r.stats.drift_boosts, r.stats.hard_hits, r.stats.recovers]])
		get_tree().quit()


## Probe on the physics tick so runs at different render rates compare the
## exact same simulation step.
func _physics_process(_delta: float) -> void:
	var race := get_tree().current_scene as RaceManager
	if race != null and args.has("probe") and not _probe_done and race.race_time >= float(args.probe):
		_probe_done = true
		for r in race.racers:
			var p := r.kart.global_position
			print("PROBE %s t=%.4f pos=(%.4f, %.4f, %.4f) yaw=%.4f speed=%.4f" % [r.name, race.race_time, p.x, p.y, p.z, r.kart.yaw, r.kart.speed])


func _print_stats(race: RaceManager) -> void:
	var worst := 0.0
	var total := 0.0
	for f in _frame_times:
		worst = maxf(worst, f)
		total += f
	var avg := total / maxf(_frame_times.size(), 1)
	print("STATS t=%.0f fps=%d avg_ms=%.2f worst_ms=%.2f mem_mb=%.1f objects=%d draw_calls=%d prims=%d race_t=%.1f" % [
		_elapsed, Engine.get_frames_per_second(), avg * 1000.0, worst * 1000.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		race.race_time if race else 0.0])


func _save_shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _capture_dir.path_join(file_name)
	img.save_png(path)
	print("CAPTURED ", path)


func _capture_views(race: RaceManager) -> void:
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 1500.0
	race.add_child(cam)
	cam.current = true
	for v in String(args.views).split(","):
		var s := float(v)
		var tp := race.track.main
		var p := tp.position_at(s)
		var t := tp.tangent_at(s)
		cam.global_position = p - Vector3(t.x, 0, t.z).normalized() * 6.0 + Vector3.UP * 2.6
		cam.look_at(tp.position_at(s + 22.0) + Vector3.UP * 1.2, Vector3.UP)
		for i in 4:
			await get_tree().process_frame
		await _save_shot("view_%04d.png" % int(s))
	cam.current = false
	race.camera.current = true
	cam.queue_free()


func _capture_overview(race: RaceManager) -> void:
	var cam := Camera3D.new()
	race.add_child(cam)
	var b := AABB(race.track.main.points[0], Vector3.ZERO)
	for p in race.track.main.points:
		b = b.expand(p)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(b.size.x, b.size.z) * 1.1
	cam.far = 2000.0
	cam.global_position = b.get_center() + Vector3(0, 400, 0)
	cam.rotation = Vector3(-PI * 0.5, 0, 0)
	cam.current = true
	var env := race.environment.env
	var fog_was := env.fog_enabled
	env.fog_enabled = false
	await get_tree().process_frame
	await get_tree().process_frame
	await _save_shot("overview.png")
	env.fog_enabled = fog_was
	cam.current = false
	race.camera.current = true
	cam.queue_free()
