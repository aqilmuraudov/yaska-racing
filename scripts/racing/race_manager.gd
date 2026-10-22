class_name RaceManager
extends Node3D
## Race scene root: builds the world from Game.race_config and runs the race
## lifecycle  INTRO → COUNTDOWN → RACING → FINISHING → RESULTS, with pause and
## in-place restart that resets every race-specific object and timer.

signal state_changed(state: RaceState)
signal countdown_tick(value: int) # 3, 2, 1, 0 = GO
signal racer_finished(racer: Racer)
signal lap_completed(racer: Racer, lap: int, lap_time: float)
signal player_message(key: String, kind: String)
signal results_ready(results: Dictionary)

enum RaceState { INTRO, COUNTDOWN, RACING, FINISHING, RESULTS }

const INTRO_TIME := 1.6
const COUNTDOWN_TIME := 3.0
const START_BOOST_WINDOW := 0.45
const START_PERFECT_WINDOW := 0.25
const FINISH_WINDOW := 18.0
const SAFE_MARK_INTERVAL := 0.25
const CONTACT_DIST := 1.75


class Racer:
	extends RefCounted
	var index := 0
	var name := ""
	var kart: KartController
	var tracker: RaceTracker
	var player_input: PlayerInput
	var ai: AIDriver
	var is_player := false
	var place := 0
	var finish_place := 0
	var prev_pos := Vector3.ZERO
	var safe_timer := 0.0
	var grid_xform := Transform3D.IDENTITY
	var paint := Color.WHITE
	## Debug / balancing counters (not saved).
	var stats := {"recovers": 0, "shortcut_uses": 0, "hard_hits": 0, "items_used": 0, "drift_boosts": 0,
		"offroad_s": 0.0, "drift_s": 0.0, "boost_s": 0.0, "speed_sum": 0.0, "ticks": 0}
	var was_on_shortcut := false


var config: Dictionary
var track: TrackData
var builder: TrackBuilder
var decor: Node3D
var environment: RaceEnvironment
var items: ItemSystem
var camera: ChaseCamera
var hud: Node
var racers: Array[Racer] = []
var player: Racer
var state: RaceState = RaceState.INTRO
var race_time := 0.0
var state_time := 0.0
var finish_counter := 0
var _countdown_last := 4
var _player_throttle_press_time := -1.0
var _results: Dictionary = {}
var _audio_director_timer := 0.0
var paused := false
var headless_test := false ## set by tests to skip UI
var auto_pause_on_focus_loss := true
var tutorial: TutorialDirector
var ghosts: GhostSystem
var skid_marks: SkidMarks


func _ready() -> void:
	config = Game.race_config.duplicate(true)
	if config.is_empty():
		config = Game.default_race_config()
	if Game.debug_race:
		auto_pause_on_focus_loss = false # unattended debug/soak runs
	build_world()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	start_intro()


func build_world() -> void:
	environment = RaceEnvironment.new()
	environment.name = "Environment"
	add_child(environment)
	environment.build()
	track = TrackData.load_from_file("res://data/tracks/%s.json" % config.track_id)
	builder = TrackBuilder.new()
	builder.name = "Track"
	add_child(builder)
	builder.build(track)
	for area in builder.boost_pad_areas:
		area.body_entered.connect(_on_boost_pad)
	if ClassDB.class_exists("TrackDecor") or ResourceLoader.exists("res://scripts/track/track_decor.gd"):
		var decor_script: Script = load("res://scripts/track/track_decor.gd")
		if decor_script:
			decor = decor_script.new()
			decor.name = "Decor"
			add_child(decor)
			decor.build(track, environment)
			countdown_tick.connect(decor.set_countdown_lights)
	items = ItemSystem.new()
	items.name = "Items"
	add_child(items)
	var seed_value := int(config.get("active_seed", config.get("seed", 1)))
	items.setup(track, bool(config.items) and config.mode != "time_trial", seed_value)
	items.racers_provider = _racer_place_info
	_spawn_racers(seed_value)
	skid_marks = SkidMarks.new()
	skid_marks.name = "SkidMarks"
	add_child(skid_marks)
	var all_karts: Array = []
	for r in racers:
		all_karts.append(r.kart)
	skid_marks.setup(all_karts)
	if config.mode == "time_trial":
		ghosts = GhostSystem.new()
		ghosts.name = "Ghosts"
		add_child(ghosts)
		ghosts.setup(self, player.kart, track.id, int(track.raw.get("version", 1)))
	camera = ChaseCamera.new()
	camera.name = "Camera"
	add_child(camera)
	camera.follow(player.kart)
	camera.current = true
	if not headless_test:
		var hud_script: Script = load("res://scripts/ui/race_hud.gd")
		hud = hud_script.new()
		hud.name = "HUD"
		add_child(hud)
		hud.setup(self)
		if config.mode == "tutorial":
			tutorial = TutorialDirector.new()
			tutorial.name = "Tutorial"
			add_child(tutorial)
			tutorial.setup(self)


func _spawn_racers(seed_value: int) -> void:
	var ai_count := clampi(int(config.ai_count), 0, 7)
	if config.mode == "time_trial":
		ai_count = 0
	var total := ai_count + 1
	var player_slot := mini(3, total - 1) if total > 1 else 0
	var density: float = Settings.get_value("graphics", "effects_density", 1.0)
	var player_racer: String = config.kart_id if RacerRoster.is_valid(String(config.kart_id)) else RacerRoster.DEFAULT_ID
	var ai_racers := RacerRoster.opponents(player_racer, ai_count, seed_value)
	var ai_index := 0
	for slot in total:
		var r := Racer.new()
		r.index = slot
		r.is_player = slot == player_slot
		var racer_id: String
		if r.is_player:
			racer_id = player_racer
		else:
			racer_id = ai_racers[ai_index]
			ai_index += 1
		var def := RacerRoster.get_def(racer_id)
		r.name = def.display_name
		if r.is_player:
			r.name = "%s %s" % [def.display_name, tr("RACER_YOU_SUFFIX")]
		var kart := KartFactory.create(racer_id, r.is_player, density if r.is_player else density * 0.7)
		kart.racer_index = slot
		kart.display_name = r.name
		kart.name = "Kart_%d" % slot
		add_child(kart)
		r.kart = kart
		r.paint = kart.get_meta("paint")
		r.grid_xform = grid_transform(slot)
		kart.respawn_provider = _respawn_transform
		kart.respawn_started.connect(func(): r.stats.recovers += 1)
		# A respawn is a teleport: never evaluate it as a gate crossing.
		kart.respawned.connect(func(): r.prev_pos = kart.global_position)
		kart.wall_hit.connect(func(strength):
			if strength >= 0.6:
				r.stats.hard_hits += 1
				if OS.has_feature("editor") and DebugRunner.parse_args().has("log-hits"):
					print("HARDHIT %s s=%.0f lat=%.1f speed=%.1f state=%d sc=%d %s" % [r.name, r.tracker.s, r.tracker.lateral, kart.speed, kart.state, r.tracker.on_shortcut, kart.last_wall_info]))
		kart.drift_boost.connect(func(_t, _p): r.stats.drift_boosts += 1)
		# Drift School never "finishes": the tutorial ends when its steps do.
		r.tracker = RaceTracker.new(track, 99 if config.mode == "tutorial" else int(config.laps))
		if r.is_player:
			r.player_input = PlayerInput.new()
			r.player_input.name = "PlayerInput"
			add_child(r.player_input)
			r.player_input.setup(kart, _steer_assist_for.bind(r))
			player = r
		r.ai = AIDriver.new()
		r.ai.name = "AI_%d" % slot
		r.ai.autopilot = r.is_player
		add_child(r.ai)
		r.ai.setup(kart, r.tracker, track, config.difficulty, seed_value + slot * 7919)
		r.ai.item_system = items
		if r.is_player:
			r.ai.set_physics_process(bool(config.get("debug_autopilot", false)))
			if r.player_input and bool(config.get("debug_autopilot", false)):
				r.player_input.enabled = false
		racers.append(r)
	var karts: Array = []
	for r in racers:
		karts.append(r.kart)
	for r in racers:
		r.ai.racers = karts
		if not r.is_player:
			r.ai.set_catchup_reference(player.tracker)
			r.ai.catchup_enabled = config.mode != "time_trial"
	_reset_racers()
	if bool(config.get("balance_test", false)):
		# Balance runs: identical AI skill for everyone, no catch-up, so only
		# each racer's handling differs.
		for r in racers:
			r.ai.autopilot = true
			r.ai.catchup_enabled = false
			r.ai.set_physics_process(true)
			if r.player_input:
				r.player_input.enabled = false


func grid_transform(slot: int) -> Transform3D:
	var row := slot / 2
	var col := slot % 2
	var s := track.finish_s - 5.0 - row * 6.5 - col * 2.0
	var p := track.main.position_at(s)
	var t := track.main.tangent_at(s)
	var lat := (-3.6 if col == 0 else 3.6)
	p += track.main.right_at(s) * lat + Vector3.UP * 0.25
	var basis := Basis.looking_at(Vector3(t.x, 0, t.z).normalized(), Vector3.UP)
	return Transform3D(basis, p)


func _reset_racers() -> void:
	for r in racers:
		r.kart.reset_for_race(r.grid_xform)
		r.tracker.reset(r.grid_xform.origin)
		r.prev_pos = r.grid_xform.origin
		r.place = r.index + 1
		r.finish_place = 0
		r.safe_timer = 0.0
		r.was_on_shortcut = false
		for key in r.stats.keys():
			r.stats[key] = 0.0 if typeof(r.stats[key]) == TYPE_FLOAT else 0
		r.ai.reset()
		r.kart.get_meta("visual").set_victory(false)
		if r.player_input:
			r.player_input.release_all()
			r.player_input.enabled = not bool(config.get("debug_autopilot", false))
		if r.is_player:
			r.ai.set_physics_process(bool(config.get("debug_autopilot", false)))
			r.ai.autopilot = true
		r.kart.speed_scale = 1.0 if (r.is_player or bool(config.get("balance_test", false))) else float(r.ai.profile.speed_factor)


# --- Lifecycle ----------------------------------------------------------------

func start_intro() -> void:
	_set_state(RaceState.INTRO)
	camera.orbit = true
	camera.snap()
	AudioManager.play_music("race", 1.5)


func _set_state(s: RaceState) -> void:
	state = s
	state_time = 0.0
	state_changed.emit(s)


func restart() -> void:
	get_tree().paused = false
	paused = false
	race_time = 0.0
	finish_counter = 0
	_results = {}
	_player_throttle_press_time = -1.0
	_countdown_last = 4
	config.event_instance_id = "%d-%d" % [Time.get_ticks_usec(), randi()]
	items.reset()
	if decor:
		decor.reset_lights()
	if skid_marks:
		skid_marks.clear()
	if tutorial:
		tutorial.reset()
	if ghosts:
		ghosts.reset()
	_reset_racers()
	camera.follow(player.kart)
	camera.snap()
	if hud and hud.has_method("reset"):
		hud.reset()
	start_intro()


func _physics_process(delta: float) -> void:
	state_time += delta
	match state:
		RaceState.INTRO:
			if state_time >= INTRO_TIME or headless_test:
				camera.orbit = false
				camera.snap()
				_set_state(RaceState.COUNTDOWN)
		RaceState.COUNTDOWN:
			_tick_countdown()
		RaceState.RESULTS:
			# Karts keep cruising behind the results screen; trackers must
			# stay current so the AI keeps a sensible line.
			_tick_racers(delta)
			_resolve_contacts()
		RaceState.RACING, RaceState.FINISHING:
			race_time += delta
			_tick_racers(delta)
			_resolve_contacts()
			_update_ranking()
			if state == RaceState.FINISHING:
				var all_done := true
				for r in racers:
					if not r.tracker.finished:
						all_done = false
				if all_done or state_time >= FINISH_WINDOW:
					_finish_race()
	_audio_director_timer -= delta
	if _audio_director_timer <= 0.0:
		_audio_director_timer = 0.25
		_update_audio_voices()


func _tick_countdown() -> void:
	var remaining := COUNTDOWN_TIME - state_time
	var shown := int(ceil(remaining))
	if shown != _countdown_last and shown >= 0:
		_countdown_last = shown
		countdown_tick.emit(shown)
		if shown > 0:
			AudioManager.play("count_beep", -2.0)
	# Start boost timing: remember the latest throttle press.
	if player and Input.is_action_just_pressed(InputActions.ACCELERATE):
		_player_throttle_press_time = remaining
	if player and player.player_input and player.player_input.touch_active and Settings.get_value("controls", "touch_auto_accelerate", true):
		# Auto-accelerate users press "GAS"/drift for the start boost instead.
		if Input.is_action_just_pressed(InputActions.DRIFT):
			_player_throttle_press_time = remaining
	if remaining <= 0.0:
		_go()


func _go() -> void:
	countdown_tick.emit(0)
	AudioManager.play("count_go", 0.0)
	_set_state(RaceState.RACING)
	race_time = 0.0
	for r in racers:
		r.kart.controls_locked = false
		if r.is_player:
			var t := _player_throttle_press_time
			var holding := Input.is_action_pressed(InputActions.ACCELERATE) or Input.is_action_pressed(InputActions.DRIFT) or bool(config.get("debug_autopilot", false))
			if t >= 0.0 and t <= START_BOOST_WINDOW and holding:
				r.kart.apply_start_boost(1.0 if t <= START_PERFECT_WINDOW else 0.65)
				player_message.emit("HUD_START_BOOST", "good")
			elif t > START_BOOST_WINDOW and holding:
				r.kart.speed = 0.0
				r.kart.hit_timer = 0.0
				player_message.emit("HUD_START_STALL", "bad")
				r.kart.controls_locked = true
				get_tree().create_timer(0.5, false).timeout.connect(func(): r.kart.controls_locked = false)
		elif r.ai.wants_start_boost():
			r.kart.apply_start_boost(r.ai.rng.randf_range(0.65, 1.0))


func _tick_racers(delta: float) -> void:
	for r in racers:
		var k := r.kart
		var pos := k.global_position
		var events := r.tracker.update(r.prev_pos, pos, race_time, k.velocity, delta)
		r.prev_pos = pos
		var rt := track.route_tangent(pos, {"s": r.tracker.s, "on_shortcut": r.tracker.on_shortcut})
		k.route_forward = Vector3(rt.x, 0.0, rt.z).normalized()
		for e in events:
			_handle_event(r, e)
		# Items
		if k.input.item_pressed and k.can_use_item():
			items.use_item(k)
			r.stats.items_used += 1
		if state != RaceState.RESULTS and not r.tracker.finished:
			if k.surface == &"offroad" or k.surface == &"rough":
				r.stats.offroad_s += delta
			if k.is_drifting():
				r.stats.drift_s += delta
			if k.boost.is_active():
				r.stats.boost_s += delta
			r.stats.speed_sum += k.speed
			r.stats.ticks += 1
		var on_sc := r.tracker.on_shortcut >= 0
		if on_sc and not r.was_on_shortcut:
			r.stats.shortcut_uses += 1
		r.was_on_shortcut = on_sc
		# Safe recovery points
		r.safe_timer -= delta
		if r.safe_timer <= 0.0:
			r.safe_timer = SAFE_MARK_INTERVAL
			if k.grounded and k.surface == &"road" and not r.tracker.wrong_way and k.state in [KartController.State.NORMAL, KartController.State.DRIFT] \
					and absf(r.tracker.lateral) < track.main.half_width_at(r.tracker.s) - 1.5 and r.tracker.on_shortcut < 0:
				r.tracker.mark_safe()
		# Out of bounds: fell below the course or escaped the corridor.
		var ground_y := track.main.position_at(r.tracker.s).y
		if k.state != KartController.State.RECOVER and (pos.y < ground_y - 6.0 or r.tracker.off_route_distance > track.offroad_width + 9.0):
			if OS.has_feature("editor") and DebugRunner.parse_args().has("log-hits"):
				print("OOB %s pos=%s ground_y=%.1f s=%.0f off=%.1f sc=%d" % [r.name, pos, ground_y, r.tracker.s, r.tracker.off_route_distance, r.tracker.on_shortcut])
			k.start_recover()


func _handle_event(r: Racer, e: Array) -> void:
	if state == RaceState.RESULTS:
		return # results are final
	match e[0]:
		"lap":
			lap_completed.emit(r, int(e[1]), float(e[2]))
			if r.is_player:
				if int(e[1]) == int(config.laps) - 1:
					player_message.emit("HUD_FINAL_LAP", "info")
					AudioManager.play("final_lap", -1.0)
				else:
					AudioManager.play("lap", -2.0)
		"finish":
			finish_counter += 1
			r.finish_place = finish_counter
			r.kart.finished = true
			racer_finished.emit(r)
			if r.is_player:
				_on_player_finished()
			else:
				r.ai.set_physics_process(true)


func _on_player_finished() -> void:
	player_message.emit("HUD_FINISH", "good")
	AudioManager.play("finish", 0.0)
	player.player_input.enabled = false
	player.player_input.release_all()
	player.ai.autopilot = true
	player.ai.set_physics_process(true)
	player.kart.get_meta("visual").set_victory(player.finish_place <= 3)
	_set_state(RaceState.FINISHING)


func _finish_race() -> void:
	_set_state(RaceState.RESULTS)
	camera.orbit = true
	_update_ranking()
	# Unfinished racers keep their running order and are marked DNF.
	_results = build_results()
	_apply_rewards(_results)
	results_ready.emit(_results)


func build_results() -> Dictionary:
	var order := racers.duplicate()
	order.sort_custom(func(a, b): return RaceTracker.compare(a.tracker, b.tracker))
	var rows: Array = []
	for i in order.size():
		var r: Racer = order[i]
		rows.append({
			"place": i + 1,
			"name": r.name,
			"is_player": r.is_player,
			"finished": r.tracker.finished,
			"time": r.tracker.finish_time,
			"best_lap": r.tracker.best_lap,
			"paint": r.paint,
			"kart": r.kart.stats.id,
		})
	var player_row: Dictionary = {}
	for row in rows:
		if row.is_player:
			player_row = row
	return {"rows": rows, "player": player_row, "laps": int(config.laps), "track_id": config.track_id,
		"mode": config.mode, "event_instance_id": config.get("event_instance_id", "")}


const REWARDS := [100, 75, 60, 45, 35, 25, 20, 15]


func _apply_rewards(res: Dictionary) -> void:
	var p: Dictionary = res.player
	# Autopilot (debug/demo) races never touch the player's profile.
	if p.is_empty() or headless_test or bool(config.get("debug_autopilot", false)):
		return
	var improved := {"lap": false, "race": false}
	if p.finished:
		improved = SaveManager.submit_times(res.track_id, int(round(p.time * 1000.0)), int(round(p.best_lap * 1000.0)), p.kart, res.laps)
	if res.mode == "tutorial":
		return
	var amount: int = REWARDS[clampi(int(p.place) - 1, 0, REWARDS.size() - 1)] if p.finished else 10
	if res.mode == "time_trial":
		amount = 15 if p.finished else 0
	if improved.lap or improved.race:
		amount += 20
	var granted := 0
	if not SaveManager.has_rewarded(res.event_instance_id):
		granted = SaveManager.grant_reward(res.event_instance_id, amount)
		SaveManager.record_race_stats(int(p.place) if p.finished else 0)
	SaveManager.save_profile()
	res.reward = granted
	res.already_rewarded = granted == 0 and amount > 0
	res.improved = improved


func _update_ranking() -> void:
	var order := racers.duplicate()
	order.sort_custom(func(a, b): return RaceTracker.compare(a.tracker, b.tracker))
	for i in order.size():
		order[i].place = i + 1


func _racer_place_info(kart: KartController) -> Dictionary:
	for r in racers:
		if r.kart == kart:
			return {"place": r.place, "count": racers.size()}
	return {"place": 1, "count": racers.size()}


## Symmetric kart-vs-kart bumps: CharacterBody3D sliding stops overlap; this
## adds a controlled sideways exchange so contact feels physical but never
## launches karts or removes control.
func _resolve_contacts() -> void:
	var n := racers.size()
	for i in n:
		var a := racers[i].kart
		if a.state == KartController.State.RECOVER:
			continue
		for j in range(i + 1, n):
			var b := racers[j].kart
			if b.state == KartController.State.RECOVER:
				continue
			var d := b.global_position - a.global_position
			d.y = 0.0
			var dist := d.length()
			if dist >= CONTACT_DIST or dist < 0.001 or absf(a.global_position.y - b.global_position.y) > 1.5:
				continue
			var nrm := d / dist
			var rel := (a.velocity - b.velocity).dot(nrm)
			var overlap := CONTACT_DIST - dist
			var bump := minf(a.stats.kart_bump, b.stats.kart_bump)
			var impulse := maxf(rel, 0.0) * 0.5 + overlap * 4.0
			impulse = minf(impulse, bump)
			var ma := a.stats.mass
			var mb := b.stats.mass
			a.add_push(-nrm * impulse * (mb / (ma + mb)) * 2.0)
			b.add_push(nrm * impulse * (ma / (ma + mb)) * 2.0)
			if rel > 4.0:
				AudioManager.play_at("bump", (a.global_position + b.global_position) * 0.5, -6.0, randf_range(0.9, 1.1))


## Safe respawn point: last recorded safe spot, nudged so it never overlaps
## another kart.
func _respawn_transform(kart: KartController) -> Transform3D:
	var r := _racer_for(kart)
	var s := r.tracker.last_safe_s if r else 0.0
	var lat := clampf(r.tracker.last_safe_lateral if r else 0.0, -2.5, 2.5)
	for attempt in 8:
		var p := track.main.position_at(s) + track.main.right_at(s) * lat + Vector3.UP * 0.6
		var free := true
		for other in racers:
			if other.kart != kart and other.kart.global_position.distance_to(p) < 3.2:
				free = false
				break
		if free:
			var t := track.main.tangent_at(s)
			return Transform3D(Basis.looking_at(Vector3(t.x, 0, t.z).normalized(), Vector3.UP), p)
		lat = -lat if attempt % 2 == 0 else lat + 2.5 * signf(lat + 0.01)
		lat = clampf(lat, -track.main.half_width_at(s) + 1.5, track.main.half_width_at(s) - 1.5)
		if attempt % 2 == 1:
			s -= 4.0
	var t2 := track.main.tangent_at(s)
	return Transform3D(Basis.looking_at(Vector3(t2.x, 0, t2.z).normalized(), Vector3.UP), track.main.position_at(s) + Vector3.UP * 0.6)


func _racer_for(kart: KartController) -> Racer:
	for r in racers:
		if r.kart == kart:
			return r
	return null


func _steer_assist_for(r: Racer) -> float:
	# Positive lateral = right of centre → steer left (negative).
	var hw := track.main.half_width_at(r.tracker.s)
	return clampf(-r.tracker.lateral / maxf(hw, 1.0), -1.0, 1.0)


func _on_boost_pad(body: Node) -> void:
	if body is KartController and body.state != KartController.State.RECOVER:
		body.apply_boost_pad()


## Voice budget: player engine + the 3 nearest AI engines.
func _update_audio_voices() -> void:
	if camera == null:
		return
	var cam_pos := camera.global_position
	var others: Array = []
	for r in racers:
		var audio: KartAudio = r.kart.get_meta("audio")
		if r.is_player:
			audio.set_audible(true)
		else:
			others.append([r.kart.global_position.distance_squared_to(cam_pos), audio])
	others.sort_custom(func(a, b): return a[0] < b[0])
	for i in others.size():
		others[i][1].set_audible(i < 3 and others[i][0] < 70.0 * 70.0)


# --- Pause & focus --------------------------------------------------------------

func set_paused(on: bool) -> void:
	if state == RaceState.RESULTS and on:
		return
	paused = on
	get_tree().paused = on
	if on and player and player.player_input:
		player.player_input.release_all()
	if hud and hud.has_method("show_pause"):
		hud.show_pause(on)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.PAUSE) and not paused and state != RaceState.RESULTS:
		set_paused(true)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if state in [RaceState.COUNTDOWN, RaceState.RACING, RaceState.FINISHING] and not paused and auto_pause_on_focus_loss:
				set_paused(true)
			if player and player.player_input:
				player.player_input.release_all()
			if hud and hud.has_method("release_touches"):
				hud.release_touches()


## A controller dropping out mid-race pauses instead of leaving the kart
## running with stale input.
func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected or not auto_pause_on_focus_loss:
		return
	if state in [RaceState.COUNTDOWN, RaceState.RACING, RaceState.FINISHING] and not paused:
		set_paused(true)


func quit_to_mode_select() -> void:
	get_tree().paused = false
	AudioManager.play_music("menu", 1.0)
	Game.goto(Game.State.MODE_SELECT)


func quit_to_menu() -> void:
	get_tree().paused = false
	AudioManager.play_music("menu", 1.0)
	Game.goto(Game.State.MAIN_MENU)
