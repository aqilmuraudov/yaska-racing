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
##   --racer-shots          front / rear / side / face shots of every racer
##   --quit-after=SECONDS   quit after this many real seconds
##   --stats                print per-second FPS / frame time / memory
##   --timescale=X          Engine.time_scale for fast soak runs
##   --probe=T              print every kart's position once race time >= T
##   --quit-on-results      print the race summary and quit when results show
##   --soak                 restart the race 3 s after every results screen
##   --ui-shots             capture pause, pause→settings and results screens
##   --via-loading          with --race: go through the loading screen (staged build)
##   --nitro-at=T           fire the player's nitro at race time T (captures);
##   --give-item=ID         give the player an item when the race starts
##   --fake-load-ms=N       add N ms of CPU work per frame (weak-device simulation)
##   --startup-trace        print scene + frame brightness every 0.1 s (black-frame check)
##   --chaos                player kart driven erratically (wall rams, reversing,
##                          drift spam) to expose snags, falls and stuck states
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
var _soak_timer := -1.0
var _soak_races := 0
var _ui_stage := 0
var _gpu_measure := false
var _chaos_t := 0.0
var _chaos_steer := 0.0
var _chaos_stuck := 0.0
var _chaos_stuck_events := 0
var _chaos_max_stuck := 0.0


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
	if args.has("set"):
		# --set=graphics.texture_detail=0;graphics.bloom=false (this run only)
		for item in String(args.set).split(";"):
			var kv := item.split("=")
			var sk := kv[0].split(".")
			if kv.size() == 2 and sk.size() == 2:
				var cur = Settings.get_value(sk[0], sk[1])
				var v: Variant = kv[1]
				if cur is bool: v = kv[1] == "true"
				elif cur is int: v = int(kv[1])
				elif cur is float: v = float(kv[1])
				Settings.set_value(sk[0], sk[1], v, false)
	if args.has("lang"):
		Settings.set_value("gameplay", "language", String(args.lang), false) # this run only
	if args.has("ui-flow"):
		var flow := UIFlowCheck.new()
		add_child(flow)
		flow.call_deferred("run")
	if args.has("screens"):
		call_deferred("_capture_screens")
	if args.has("racer-shots"):
		call_deferred("_capture_racers")
	if args.has("race"):
		var cfg := Game.default_race_config()
		cfg.debug_autopilot = args.has("autopilot")
		cfg.seed = int(args.get("seed", "1234"))
		cfg.active_seed = cfg.seed
		cfg.difficulty = args.get("difficulty", "medium")
		cfg.kart_id = args.get("kart", RacerRoster.DEFAULT_ID)
		cfg.laps = int(args.get("laps", "3"))
		cfg.ai_count = int(args.get("ai", "5"))
		cfg.mode = args.get("mode", "quick")
		cfg.balance_test = args.has("balance")
		if args.has("items"):
			cfg.items = args.items == "on"
		cfg.event_instance_id = "debug-%d" % Time.get_ticks_usec()
		Game.race_config = cfg
		call_deferred("_enter_race")


func _ui_shots(race: RaceManager) -> void:
	if _ui_stage == 0 and race.race_time > 6.0:
		_ui_stage = 1
		race.set_paused(true)
		await get_tree().create_timer(0.5).timeout
		await _save_shot("ui_pause.png")
		race.hud.pause_menu._open_settings()
		await get_tree().create_timer(0.8).timeout
		await _save_shot("ui_pause_settings.png")
		race.hud.pause_menu.settings_overlay.go_back()
		await get_tree().create_timer(0.3).timeout
		race.set_paused(false)
		_ui_stage = 2
	elif _ui_stage == 2 and race.state == RaceManager.RaceState.RESULTS:
		_ui_stage = 3
		await get_tree().create_timer(1.2).timeout
		await _save_shot("ui_results.png")


func _capture_racers() -> void:
	await get_tree().create_timer(1.0).timeout
	Game.goto(Game.State.KART_SELECT)
	await get_tree().create_timer(1.5).timeout
	var scr = get_tree().current_scene
	var stage: MenuStage = scr.stage
	scr.get("ui_layer").visible = false
	stage.auto_rotate = false
	var views := {"front": [PI + 0.55, Vector3(0, 1.6, 5.2), Vector3(0, 0.8, 0)], "rear": [0.35, Vector3(0, 2.0, 5.0), Vector3(0, 0.9, 0)],
		"side": [PI * 0.5, Vector3(0, 1.3, 5.0), Vector3(0, 0.75, 0)], "face": [PI + 0.25, Vector3(0, 1.75, 2.4), Vector3(0, 1.2, 0)]}
	for i in RacerRoster.IDS.size():
		scr._select(i, true)
		await get_tree().create_timer(1.4).timeout
		for v in views.keys():
			var cfg: Array = views[v]
			stage.turntable.rotation.y = cfg[0]
			stage.camera.look_at_from_position(cfg[1], cfg[2])
			await get_tree().process_frame
			await get_tree().process_frame
			await _save_shot("racer_%s_%s.png" % [RacerRoster.IDS[i], v])
	get_tree().quit()


func _capture_screens() -> void:
	var map := {"main": Game.State.MAIN_MENU, "mode": Game.State.MODE_SELECT, "kart": Game.State.KART_SELECT, "racer": Game.State.KART_SELECT,
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
	if args.has("via-loading"):
		Game.start_loading_race() # the player's path: loading screen + staged build
	else:
		Game.enter_race(load(Game.RACE_SCENE))


## --startup-trace: every 0.1 s for the first seconds, print the current scene
## and the mean brightness of the rendered frame (a black frame shows as ~0),
## and save the frames when --capture is given.
var _nitro_done := false
var _item_given := false
var _trace_t := 0.0
var _trace_n := 0


func _startup_trace(delta: float) -> void:
	_trace_t += delta
	if _trace_t < 0.1 or _elapsed > float(args.get("trace-secs", "6")):
		return
	_trace_t = 0.0
	_trace_n += 1
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if _capture_dir != "" and _trace_n % 3 == 0:
		img.save_png(_capture_dir.path_join("trace_%03d.png" % _trace_n))
	img.resize(32, 18, Image.INTERPOLATE_BILINEAR)
	var lum := 0.0
	for y in 18:
		for x in 32:
			lum += img.get_pixel(x, y).get_luminance()
	var scn := get_tree().current_scene
	print("TRACE t=%.2f scene=%s lum=%.3f fps=%d" % [_elapsed, scn.name if scn else "-", lum / 576.0, Engine.get_frames_per_second()])


func _process(delta: float) -> void:
	_elapsed += delta / maxf(Engine.time_scale, 0.001)
	if args.has("startup-trace"):
		_startup_trace(delta)
	if args.has("fake-load-ms"):
		OS.delay_msec(int(args["fake-load-ms"])) # simulate a weaker device (fallback checks)
	var race := get_tree().current_scene as RaceManager
	if race != null and _capture_dir != "":
		if args.has("overview") and not _overview_done and _elapsed > 1.0:
			_overview_done = true
			_capture_overview(race)
		if args.has("landmark-views") and not _landmarks_done and _elapsed > 1.5:
			_landmarks_done = true
			_capture_landmarks(race)
		if args.has("views") and not _views_done and _elapsed > 1.5 and _overview_done == args.has("overview"):
			_views_done = true
			_capture_views(race)
		if args.has("nitro-at") and not _nitro_done and race.race_time >= float(args["nitro-at"]):
			_nitro_done = true
			race.player.kart.apply_item_boost()
		if args.has("give-item") and not _item_given and race.state == RaceManager.RaceState.RACING:
			_item_given = true
			race.player.kart.give_item(StringName(args["give-item"]), 0.8)
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
	if args.has("soak") and race != null:
		if race.state == RaceManager.RaceState.RESULTS:
			if _soak_timer < 0.0:
				_soak_timer = 3.0
				_soak_races += 1
				print("SOAK race %d finished at %.0f s real, mem=%.1f MB objects=%d" % [_soak_races, _elapsed, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.OBJECT_COUNT)])
			_soak_timer -= delta
			if _soak_timer <= 0.0:
				_soak_timer = -1.0
				race.restart()
	if args.has("ui-shots") and race != null and _capture_dir != "":
		_ui_shots(race)
	var results_now := args.has("quit-on-results") and race != null and race.state == RaceManager.RaceState.RESULTS
	if (_quit_after > 0.0 and _elapsed >= _quit_after) or results_now:
		if race != null:
			print("RACE_STATE state=%d time=%.2f" % [race.state, race.race_time])
			if args.has("chaos"):
				print("CHAOS stuck_events(>1s)=%d max_stuck=%.1fs player_recovers=%d" % [_chaos_stuck_events, maxf(_chaos_max_stuck, _chaos_stuck), race.player.stats.recovers])
			for r in race.racers:
				print("RACER %-6s %-8s place=%d lap=%d finished=%s time=%.2f best=%.2f dist=%.0f scale=%.3f diff=%s %s" % [r.name, r.kart.stats.id, r.place, r.tracker.current_lap(), r.tracker.finished, r.tracker.finish_time, r.tracker.best_lap, r.tracker.race_distance, r.kart.speed_scale, str(r.ai.profile.get("speed_factor")), "off=%.1fs drift=%.1fs boost=%.1fs avg=%.1f sc=%d it=%d db=%d hh=%d rec=%d" % [r.stats.offroad_s, r.stats.drift_s, r.stats.boost_s, r.stats.speed_sum / maxf(r.stats.ticks, 1), r.stats.shortcut_uses, r.stats.items_used, r.stats.drift_boosts, r.stats.hard_hits, r.stats.recovers]])
		get_tree().quit()


func _chaos_drive(race: RaceManager, delta: float) -> void:
	var k := race.player.kart
	race.player.player_input.enabled = false
	race.player.ai.set_physics_process(false)
	_chaos_t -= delta
	if _chaos_t <= 0.0:
		_chaos_t = randf_range(0.3, 1.5)
		_chaos_steer = [-1.0, 1.0, 0.0, randf_range(-1, 1)][randi() % 4]
	var inp := k.input
	inp.steer = _chaos_steer
	inp.throttle = 0.0 if randf() < 0.1 else 1.0
	inp.brake = 1.0 if (int(race.race_time) % 9 == 0) else 0.0
	inp.drift_pressed = randf() < 0.03
	inp.drift_held = inp.drift_pressed or (inp.drift_held and randf() < 0.97)
	inp.boost_pressed = randf() < 0.05
	inp.item_pressed = randf() < 0.01
	inp.recover_held = false
	if absf(k.speed) < 1.0 and k.state == KartController.State.NORMAL:
		_chaos_stuck += delta
	else:
		if _chaos_stuck > 1.0:
			_chaos_stuck_events += 1
		_chaos_max_stuck = maxf(_chaos_max_stuck, _chaos_stuck)
		_chaos_stuck = 0.0


## Probe on the physics tick so runs at different render rates compare the
## exact same simulation step.
func _physics_process(delta: float) -> void:
	var race := get_tree().current_scene as RaceManager
	if race != null and args.has("chaos") and race.player and race.state == RaceManager.RaceState.RACING:
		_chaos_drive(race, delta)
	if race != null and args.has("probe") and not _probe_done and race.race_time >= float(args.probe):
		_probe_done = true
		for r in race.racers:
			var p := r.kart.global_position
			print("PROBE %s t=%.4f pos=(%.4f, %.4f, %.4f) yaw=%.4f speed=%.4f" % [r.name, race.race_time, p.x, p.y, p.z, r.kart.yaw, r.kart.speed])


func _print_stats(race: RaceManager) -> void:
	var vp_rid := get_viewport().get_viewport_rid()
	if not _gpu_measure:
		RenderingServer.viewport_set_measure_render_time(vp_rid, true)
		_gpu_measure = true
	var worst := 0.0
	var total := 0.0
	for f in _frame_times:
		worst = maxf(worst, f)
		total += f
	var avg := total / maxf(_frame_times.size(), 1)
	print("STATS t=%.0f fps=%d avg_ms=%.2f worst_ms=%.2f cpu_proc_ms=%.2f cpu_phys_ms=%.2f gpu_ms=%.2f mem_mb=%.1f vmem_mb=%.1f objects=%d draw_calls=%d prims=%d race_t=%.1f" % [
		_elapsed, Engine.get_frames_per_second(), avg * 1000.0, worst * 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_gpu(vp_rid),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
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


var _landmarks_done := false


## For each Baku landmark, finds the main-route distance where it sits most
## squarely ahead of the normal chase camera (40–450 m away) and captures
## that gameplay view: proof each landmark reads from the racing line.
func _capture_landmarks(race: RaceManager) -> void:
	var decor: TrackDecor = race.decor as TrackDecor
	if decor == null:
		print("LANDMARKS no decor")
		return
	var tp: TrackPath = race.track.main
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 1500.0
	race.add_child(cam)
	cam.current = true
	for id in decor.landmarks.keys():
		var node: Node3D = decor.landmarks[id]
		if node == null:
			continue
		var target := node.global_position + Vector3.UP * (12.0 if id != "maiden_tower" else 10.0)
		var best_s := 0.0
		var best := INF
		var s := 0.0
		while s < tp.length:
			var p := tp.position_at(s)
			var t := tp.tangent_at(s)
			var d := target - p
			var dist := Vector2(d.x, d.z).length()
			var ang := Vector2(t.x, t.z).normalized().angle_to(Vector2(d.x, d.z).normalized())
			var score := absf(ang) + (0.0 if dist > 40.0 and dist < 450.0 else 10.0) + dist * 0.0004
			if score < best:
				best = score
				best_s = s
			s += 4.0
		var p2 := tp.position_at(best_s)
		var t2 := tp.tangent_at(best_s)
		cam.global_position = p2 - Vector3(t2.x, 0, t2.z).normalized() * 6.0 + Vector3.UP * 2.6
		cam.look_at(tp.position_at(best_s + 22.0) + Vector3.UP * 1.2, Vector3.UP)
		for i in 6:
			await get_tree().process_frame
		print("LANDMARK %s s=%.0f dist=%.0f" % [id, best_s, p2.distance_to(target)])
		await _save_shot("landmark_%s.png" % id)
	cam.current = false
	race.camera.current = true
	cam.queue_free()


func _capture_views(race: RaceManager) -> void:
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 1500.0
	race.add_child(cam)
	cam.current = true
	for v in String(args.views).split(","):
		# "sc:20" = 20 m into shortcut 0; plain numbers are main-route distances.
		var tp: TrackPath = race.track.main
		if v.begins_with("sc:"):
			tp = race.track.shortcuts[0].path
			v = v.substr(3)
		var s := float(v)
		var p := tp.position_at(s)
		var t := tp.tangent_at(s)
		cam.global_position = p - Vector3(t.x, 0, t.z).normalized() * 6.0 + Vector3.UP * 2.6
		cam.look_at(tp.position_at(s + 22.0) + Vector3.UP * 1.2, Vector3.UP)
		for i in 4:
			await get_tree().process_frame
		await _save_shot("view_%s%04d.png" % ["sc_" if tp != race.track.main else "", int(s)])
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
