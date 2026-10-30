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
## Player's driving income changed (qəpik): running total, this gain, kind.
signal money_earned(total: int, gain: int, kind: String)
## The player crossed the finish line (fires on the crossing frame).
signal player_crossed_finish(place: int)

enum RaceState { INTRO, COUNTDOWN, RACING, FINISHING, RESULTS }

const INTRO_TIME := 1.6
const COUNTDOWN_TIME := 3.0
const START_BOOST_WINDOW := GameFeel.START_WINDOW
const START_PERFECT_WINDOW := GameFeel.START_PERFECT
## Near miss pop (0.9.1): kart that was passed close, for HUD/camera.
signal near_miss(rival: Node)
const FINISH_WINDOW := 18.0 ## (legacy) longest wait for the field
## Results open this long after the PLAYER crosses the line: the race is
## over for them at the crossing; the delay is only the finish celebration.
const RESULTS_DELAY := 3.4
const SAFE_MARK_INTERVAL := 0.25
## Soft-contact footprint of a kart body (metres between centres): the
## visual karts are 1.74 m wide and 2.35-2.7 m long (measured), larger than the
## shared collision capsule, so side-by-side and nose-to-tail contact uses an
## oriented ellipse; karts are eased apart before their bodies overlap.
const CONTACT_SIDE := 1.8
const OOB_TIME := 1.5
const OOB_LATERAL_MARGIN := 1.6
const OOB_BELOW := 2.5
const WALL_PIN_SPEED := 9.0
const CONTACT_LONG := 2.55


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
	var oob_timer := 0.0
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
var night_lights: Array[Node3D] = []
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
## Player's driving income this race (Economy.Tally) and nitro add-on.
var earn := Economy.Tally.new()
var nitro: NitroAddon
var _best_place_seen := 99
var near_misses := 0
var _near_prev := {} ## rival index → previous relative distance
var _near_cool := 0.0
## Post-race goals for this race (RaceGoals, quick races only) and which
## of them already ticked in the HUD.
var goals: Array = []
var goals_ticked := {}
var _hard_hits_at_lap := 0
var _audio_director_timer := 0.0
var paused := false
var headless_test := false ## set by tests to skip UI
var auto_pause_on_focus_loss := true
var tutorial: TutorialDirector
var ghosts: GhostSystem
var skid_marks: SkidMarks
var stars: StarField
## Set by the loading screen before adding the scene: build over several frames.
var staged_build := false
var build_timings: Array = [] ## [step name, ms] from build_world_staged


func _ready() -> void:
	config = Game.race_config.duplicate(true)
	if config.is_empty():
		config = Game.default_race_config()
	if not config.has("kids_auto"):
		config.kids_auto = bool(Settings.get_value("controls", "kids_auto", false))
	if Game.debug_race:
		auto_pause_on_focus_loss = false # unattended debug/soak runs
	if staged_build:
		# The loading screen drives build_world_staged() and then begin().
		set_physics_process(false)
		return
	build_world()
	begin()


## Starts the race once the world exists (immediately, or after a staged build).
func begin() -> void:
	_load_goals()
	set_physics_process(true)
	if hud:
		hud.visible = true
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	start_intro()


func build_world() -> void:
	for step in build_steps():
		(step[1] as Callable).call()


## Builds the world one step per frame so the loading screen stays animated and
## its bar reports real work. `progress` receives (fraction, step name).
## Step durations are recorded in build_timings (ms) for profiling.
func build_world_staged(progress: Callable) -> void:
	var steps := build_steps()
	var total := 0.0
	for s in steps:
		total += float(s[0])
	var done := 0.0
	for s in steps:
		var t0 := Time.get_ticks_usec()
		(s[1] as Callable).call()
		build_timings.append([String(s[2]), (Time.get_ticks_usec() - t0) / 1000.0])
		done += float(s[0])
		progress.call(done / total, String(s[2]))
		await get_tree().process_frame


## Relative cost of each build step in ms (desktop, 2026-10-24, LOAD_TIMINGS
## from --via-loading --stats). They only shape the bar; every step runs.
const TRACK_STEP_MS := [26.0, 36.0, 129.0, 2.0, 267.0, 1.0]
## 0.11.0: the 13th step (_finish: carpets + scenery distance hook) was never
## run since 0.10.0 added a step; the list now follows decor.build_steps().
const DECOR_STEP_MS := [1.0, 2.0, 17.0, 72.0, 131.0, 93.0, 8.0, 78.0, 88.0, 147.0, 85.0, 4.0, 3.0]


## [relative weight, step, name].
func build_steps() -> Array:
	var steps: Array = []
	steps.append([12.0, func():
		environment = RaceEnvironment.new()
		environment.name = "Environment"
		add_child(environment)
		environment.build(String(config.get("time_of_day", TimeOfDay.DEFAULT)))
		track = TrackData.load_from_file("res://data/tracks/%s.json" % config.track_id)
		builder = TrackBuilder.new()
		builder.name = "Track"
		add_child(builder), "environment"])
	var track_steps := func() -> Array: return builder.build_steps(track)
	# Builder steps are created lazily (the builder exists only after step 1).
	for i in 6:
		var idx := i
		steps.append([TRACK_STEP_MS[i], func(): (track_steps.call()[idx] as Callable).call(), "track_%d" % i])
	steps.append([1.0, func():
		for area in builder.boost_pad_areas:
			area.body_entered.connect(_on_boost_pad)
		# 0.11.0: each track picks its scenery builder.
		decor = DowntownDecor.new() if track.decor_kind == "downtown" else TrackDecor.new()
		decor.name = "Decor"
		add_child(decor)
		countdown_tick.connect(decor.set_countdown_lights), "decor_begin"])
	for i in DECOR_STEP_MS.size():
		var idx := i
		steps.append([DECOR_STEP_MS[i], func(): (decor.build_steps(track, environment)[idx] as Callable).call(), "decor_%d" % i])
	steps.append([330.0, _build_racers, "racers"])
	return steps


func _build_racers() -> void:
	items = ItemSystem.new()
	items.name = "Items"
	add_child(items)
	var seed_value := int(config.get("active_seed", config.get("seed", 1)))
	items.setup(track, bool(config.items) and config.mode != "time_trial", seed_value)
	items.racers_provider = _racer_place_info
	_spawn_racers(seed_value)
	stars = StarField.new()
	stars.name = "Stars"
	add_child(stars)
	stars.build(track, player.kart, config.mode != "tutorial")
	stars.collected.connect(func(_t): _earn("star"))
	# 0.10.1: night/sunset lights (Government House floodlight, player headlight).
	var marks: Dictionary = decor.landmarks if decor and "landmarks" in decor else {}
	night_lights = TimeOfDay.add_lights(self, environment.time_of_day if environment else TimeOfDay.DEFAULT, marks, player.kart)
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
	if decor and "landmarks" in decor:
		for id in ["flame_towers", "heydar_aliyev", "crescent", "maiden_tower", "mall_bridge", "tower_avenue", "sea_mall"]:
			var lm = decor.landmarks.get(id)
			if lm is Node3D and is_instance_valid(lm):
				camera.landmarks.append((lm as Node3D).global_position if lm.is_inside_tree() else (lm as Node3D).position)
	if decor and decor.has_method("segment_hit"):
		camera.occluder = decor.segment_hit
	camera.others = all_karts
	camera.mode_changed.connect(func(m: int):
		if hud and is_instance_valid(hud):
			hud.caption(tr("HUD_CAMERA_VIEW") % tr(ChaseCamera.MODE_KEYS[m])))
	if not headless_test:
		var hud_script: Script = load("res://scripts/ui/race_hud.gd")
		hud = hud_script.new()
		hud.name = "HUD"
		add_child(hud)
		hud.setup(self)
		hud.visible = not staged_build # shown by begin(), above the loading screen otherwise
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
	# Bakı Kuboku (0.10.0): the same rivals all cup, and a grid by standings.
	var fixed: Array = config.get("roster", [])
	if fixed.size() == ai_count and not (player_racer in fixed):
		ai_racers.clear()
		for id in fixed:
			ai_racers.append(String(id))
	var slot_ids := grid_slots(player_racer, ai_racers, config.get("grid_order", []))
	player_slot = slot_ids.find(player_racer)
	for slot in total:
		var r := Racer.new()
		r.index = slot
		r.is_player = slot == player_slot
		var racer_id: String = slot_ids[slot]
		var def := RacerRoster.get_def(racer_id)
		r.name = def.display_name
		if r.is_player:
			r.name = "%s %s" % [def.display_name, tr("RACER_YOU_SUFFIX")]
		var paint := int(config.get("paint", 0)) if r.is_player else 0
		var tuning := _tuning_for(r.is_player, String(player_racer))
		var kart := KartFactory.create(racer_id, r.is_player, density if r.is_player else density * 0.7, paint, tuning)
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
		kart.drift_boost.connect(func(_t, perfect):
			r.stats.drift_boosts += 1
			if r.is_player:
				_earn("drift")
				if perfect:
					_earn("perfect")
				if nitro:
					nitro.on_drift_boost())
		if r.is_player:
			kart.boost_started.connect(func(src: StringName):
				if src == &"pad" or src == &"item":
					_earn("boost"))
			var nl := int(tuning.get("nitro", 0))
			if nl > 0 and config.mode != "tutorial":
				nitro = NitroAddon.new(nl)
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
		r.ai.setup(kart, r.tracker, track, _ai_difficulty(r.is_player), seed_value + slot * 7919)
		r.ai.item_system = items
		if r.is_player:
			r.ai.set_physics_process(auto_drive())
			if r.player_input and auto_drive():
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


## Racer ids by grid slot (slot 0 = pole). Default: the player starts in
## slot 3 (or last with fewer racers). A valid `order` (every racer once)
## replaces it (cup races 2 and 3: reverse standings).
static func grid_slots(player_id: String, ai_ids: Array, order: Array) -> Array:
	var all: Array = [player_id] + ai_ids
	if order.size() == all.size():
		var ok := true
		for id in all:
			if not (id in order):
				ok = false
		if ok:
			var out: Array = []
			for id in order:
				out.append(String(id))
			return out
	var out2: Array = ai_ids.duplicate()
	var ps := mini(3, ai_ids.size())
	out2.insert(ps, player_id)
	return out2


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
			r.player_input.enabled = not auto_drive()
		if r.is_player:
			r.ai.set_physics_process(auto_drive())
			r.ai.autopilot = true
		r.kart.speed_scale = 1.0 if (r.is_player or bool(config.get("balance_test", false))) else float(r.ai.profile.speed_factor)
		if r.is_player and kids_mode():
			r.kart.speed_scale = KIDS_PLAYER_SPEED


# --- Lifecycle ----------------------------------------------------------------

func start_intro() -> void:
	_set_state(RaceState.INTRO)
	camera.orbit = true
	camera.snap()
	AudioManager.play_music("race", 1.5)
	AudioManager.play_ambience("ambience_sea")


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
	earn = Economy.Tally.new()
	goals_ticked = {}
	_best_place_seen = 99
	near_misses = 0
	_near_prev = {}
	_near_cool = 0.0
	_hard_hits_at_lap = 0
	if nitro:
		nitro = NitroAddon.new(nitro.level)
	_player_throttle_press_time = -1.0
	_countdown_last = 4
	config.event_instance_id = String(config.get("fixed_event_id", "%d-%d" % [Time.get_ticks_usec(), randi()]))
	items.reset()
	if decor:
		decor.reset_lights()
	if skid_marks:
		skid_marks.clear()
	if stars:
		stars.reset()
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
			_tick_goals()
			_tick_near_miss(delta)
			if state == RaceState.RACING and nitro:
				nitro.tick(delta)
				if Input.is_action_just_pressed(InputActions.NITRO) and player.player_input and (player.player_input.enabled or kids_mode()):
					fire_nitro()
			if state == RaceState.FINISHING and state_time >= RESULTS_DELAY:
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
			var holding := Input.is_action_pressed(InputActions.ACCELERATE) or Input.is_action_pressed(InputActions.DRIFT) or auto_drive()
			var res := GameFeel.start_result(t, holding)
			if res == "perfect" or res == "good":
				r.kart.apply_start_boost(GameFeel.start_quality(res))
				player_message.emit("HUD_START_BOOST", "good")
			elif res == "stall":
				r.kart.speed = 0.0
				r.kart.hit_timer = 0.0
				player_message.emit("HUD_START_STALL", "bad")
				r.kart.controls_locked = true
				# Small wheel-spin wobble so "too early" reads as a stall.
				if r.kart.has_node("Visual"):
					var vis: Node3D = r.kart.get_node("Visual")
					var tw := vis.create_tween()
					tw.tween_property(vis, "rotation:y", 0.22, 0.12)
					tw.tween_property(vis, "rotation:y", -0.16, 0.14)
					tw.tween_property(vis, "rotation:y", 0.0, 0.14)
				get_tree().create_timer(0.5, false).timeout.connect(func(): r.kart.controls_locked = false)
		elif r.ai.wants_start_boost():
			r.kart.apply_start_boost(r.ai.rng.randf_range(0.65, 1.0))


func _tick_racers(delta: float) -> void:
	for r in racers:
		var k := r.kart
		var pos := k.global_position
		# Pinned or grinding against a barrier at low speed is not driving the
		# wrong way: the slide jitters the velocity direction.
		var ww_vel := k.velocity
		if k.is_touching_wall() and Vector2(k.velocity.x, k.velocity.z).length() < WALL_PIN_SPEED:
			ww_vel = Vector3.ZERO
		var events := r.tracker.update(r.prev_pos, pos, race_time, ww_vel, delta)
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
		# Sustained: off the drivable corridor (beyond the barrier line) or
		# below the track surface for OOB_TIME -> respawn at the last safe spot.
		var off_track := r.tracker.off_route_distance > track.offroad_width + OOB_LATERAL_MARGIN \
				or pos.y < ground_y - OOB_BELOW
		if off_track and k.state != KartController.State.RECOVER:
			r.oob_timer += delta
		else:
			r.oob_timer = 0.0
		if k.state != KartController.State.RECOVER and (pos.y < ground_y - 6.0 or r.tracker.off_route_distance > track.offroad_width + 9.0 or r.oob_timer >= OOB_TIME):
			r.oob_timer = 0.0
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
				if int(r.stats.hard_hits) == _hard_hits_at_lap:
					_earn("clean_lap")
				_hard_hits_at_lap = int(r.stats.hard_hits)
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
	_update_ranking()
	player_crossed_finish.emit(player.finish_place)
	# The FinishCelebration overlay replaces the old "FİNİŞ!" banner.
	AudioManager.play("finish", 0.0)
	# Short victory jingle on the Music bus (obeys the Music switch), then the
	# calm menu theme returns under the results.
	AudioManager.play_jingle("victory")
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
		var est := 0.0
		if not r.tracker.finished and r.tracker.race_distance > 1.0:
			# The race ends for the player at the line: unfinished racers get
			# a projected time from their average pace so far.
			var total := track.lap_length() * int(config.laps)
			est = race_time * total / r.tracker.race_distance
		rows.append({
			"estimated": est,
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


## (0.7 coin table, replaced by Economy.PLACE_PAY in qəpik.)


func _apply_rewards(res: Dictionary) -> void:
	res.stars = stars.count if stars else 0
	res.stars_total = SaveManager.get_stars()
	var p: Dictionary = res.player
	# Autopilot (debug/demo) races never touch the player's profile.
	if p.is_empty() or headless_test or bool(config.get("debug_autopilot", false)):
		return
	var improved := {"lap": false, "race": false}
	# Kids controls in Rekord: the kart drove itself, so no record is kept.
	res.records_skipped = kids_mode() and res.mode == "time_trial"
	if p.finished and not res.records_skipped:
		improved = SaveManager.submit_times(res.track_id, int(round(p.time * 1000.0)), int(round(p.best_lap * 1000.0)), p.kart, res.laps)
	if res.mode == "tutorial":
		var tp := SaveManager.apply_progression(res.event_instance_id, {"mode": "tutorial", "finished": true,
			"tutorial_done": SaveManager.get_tutorial_flag("drift_done"), "place": 1,
			"drift_boosts": int(player.stats.drift_boosts) if player != null and player.stats != null else 0, "stars": 0, "coins": 0, "track_id": res.track_id})
		res.unlocks = tp.unlocks
		res.unlock_cards = tp.get("cards", [])
		return
	var pay := Economy.payout(res.mode, int(p.place), bool(p.finished), earn.total, improved.lap or improved.race)
	res.payout = pay
	var amount: int = int(pay.total)
	res.stars_added = SaveManager.add_stars(res.event_instance_id, int(res.get("stars", 0)))
	var granted := 0
	res.earn_counts = earn.counts.duplicate()
	if not SaveManager.has_rewarded(res.event_instance_id):
		granted = SaveManager.grant_reward(res.event_instance_id, amount)
		SaveManager.record_race_stats(int(p.place) if p.finished else 0)
	SaveManager.save_profile()
	var prog := SaveManager.apply_progression(res.event_instance_id, {"mode": res.mode, "finished": bool(p.finished),
		"place": int(p.place), "drift_boosts": int(player.stats.drift_boosts) if player != null and player.stats != null else 0, "stars": int(res.stars_added),
		"coins": granted, "track_id": res.track_id, "record": improved.lap or improved.race})
	res.unlocks = prog.unlocks
	res.unlock_cards = prog.get("cards", [])
	res.bonus_coins = int(prog.coins)
	if granted > 0:
		_settle_goals(res)
		granted += int(res.get("goals_pay", 0))
		SaveManager.save_profile()
	granted += apply_series(res, SaveManager.data, SaveManager.grant_reward)
	SaveManager.save_profile()
	res.reward = granted
	res.already_rewarded = granted == 0 and amount > 0
	res.improved = improved


## Cup points / prize and the daily challenge (0.10.0). Separate from
## _apply_rewards so tests can drive it with a plain profile dictionary.
## Returns the extra qəpik granted; fills res.cup / res.daily.
func apply_series(res: Dictionary, data: Dictionary, grant: Callable) -> int:
	var extra := 0
	var p: Dictionary = res.get("player", {})
	match String(config.get("series", "")):
		"cup":
			var idx := int(config.get("cup_race", 0))
			var rec := BakuCup.record_race(data, idx, res.get("rows", []))
			var cup := BakuCup.current(data)
			res.cup = {"race": idx, "ok": rec.ok, "gained": int(rec.gained.get(String(config.kart_id), 0)),
				"complete": BakuCup.is_complete(cup)}
			if BakuCup.is_complete(cup):
				var paid := BakuCup.pay_prize(cup, grant)
				data.cup_progress = cup
				res.cup.prize = paid
				res.cup.final_place = int(cup.get("final_place", 0))
				extra += paid
			if rec.ok:
				res.unlock_cards = [{"icon": "trophy", "text": tr("CUP_POINTS_GAINED") % int(res.cup.gained)}] + res.get("unlock_cards", [])
		"daily":
			var ch := DailyChallenge.effective(config.get("daily", {}), kids_mode())
			if ch.is_empty() or not ch.has("type"):
				return 0
			var snap := {"finished": bool(p.get("finished", false)), "place": int(p.get("place", 99)), "kart": String(p.get("kart", "")),
				"stars": int(res.get("stars", 0)), "hard_hits": int(player.stats.hard_hits) if player != null else 1,
				"time": float(p.get("time", 9999.0))}
			var done := DailyChallenge.is_done(ch, snap)
			var already := DailyChallenge.done_today(data, String(ch.date))
			var paid := 0
			if done and not already:
				paid = DailyChallenge.complete(data, ch, grant)
			res.daily = {"done": done, "already": already, "paid": paid, "text": DailyChallenge.text(ch)}
			extra += paid
			var line := ("✓ " if done else "✗ ") + DailyChallenge.text(ch)
			res.unlock_cards = [{"icon": DailyChallenge.icon(ch), "text": line}] + res.get("unlock_cards", [])
	if bool(res.get("records_skipped", false)):
		res.unlock_cards = [{"icon": "kids_auto", "text": tr("TT_KIDS_NO_RECORD")}] + res.get("unlock_cards", [])
	return extra


func _load_goals() -> void:
	goals = []
	goals_ticked = {}
	if config.mode == "quick" and String(config.get("series", "")) == "" and SaveManager.data.size() > 0:
		goals = RaceGoals.current(SaveManager.data).duplicate(true)
		if kids_mode():
			goals = RaceGoals.kids_safe(goals)


## Live goal progress of the player.
func goal_snapshot() -> Dictionary:
	return {"drift": int(earn.counts.get("drift", 0)), "stars": int(earn.counts.get("star", 0)),
		"overtake": int(earn.counts.get("overtake", 0)), "clean_lap": int(earn.counts.get("clean_lap", 0)),
		"place": player.place if player else 99,
		"finished": player != null and player.tracker != null and player.tracker.finished}


## Near miss / close overtake (0.9.1): passing a rival side by side at speed
## without touching. Pays Economy.NEAR_MISS (inside the driving cap).
func _tick_near_miss(delta: float) -> void:
	_near_cool = maxf(_near_cool - delta, 0.0)
	if player == null or state != RaceState.RACING or race_time < 2.0 or player.tracker.finished:
		return
	var pk := player.kart
	var ratio := absf(pk.speed) / maxf(pk.stats.top_speed, 0.1)
	for i in racers.size():
		var r: Racer = racers[i]
		if r == player:
			continue
		var rel := player.tracker.race_distance - r.tracker.race_distance
		var prev: float = _near_prev.get(i, rel)
		_near_prev[i] = rel
		if _near_cool > 0.0:
			continue
		var gap := player.tracker.lateral - r.tracker.lateral
		var touched := pk.global_position.distance_to(r.kart.global_position) < 1.1
		if GameFeel.is_near_miss(prev, rel, gap, ratio, touched):
			_near_cool = GameFeel.NEAR_COOLDOWN
			near_misses += 1
			_earn("near_miss")
			if camera:
				camera.add_shake(0.22)
			near_miss.emit(r.kart)
			return


func _tick_goals() -> void:
	if goals.is_empty() or player == null:
		return
	var snap := goal_snapshot()
	for i in goals.size():
		if goals_ticked.has(i) or not RaceGoals.is_done(goals[i], snap):
			continue
		goals_ticked[i] = true
		if hud and hud.has_method("goal_tick"):
			hud.goal_tick(RaceGoals.text(goals[i]))


## Pays this race's goals and draws three new ones (once per event).
func _settle_goals(res: Dictionary) -> void:
	if goals.is_empty():
		return
	var st := RaceGoals.settle(goals, goal_snapshot())
	res.goals = goals.duplicate(true)
	res.goals_done = st.done
	res.goals_pay = int(st.pay)
	SaveManager.add_money(int(st.pay))
	SaveManager.data.race_goals = RaceGoals.generate(hash(String(res.event_instance_id)))
	res.next_goals = SaveManager.data.race_goals.duplicate(true)
	for g in st.done:
		res.unlock_cards = [{"icon": "star", "text": "✓ " + RaceGoals.text(g)}] + res.get("unlock_cards", [])


func _update_ranking() -> void:
	var order := racers.duplicate()
	order.sort_custom(func(a, b): return RaceTracker.compare(a.tracker, b.tracker))
	for i in order.size():
		order[i].place = i + 1
	# Overtakes pay only for a new best position (no farming by swapping
	# places back and forth); the first 2 s of the start do not count.
	if player and state == RaceState.RACING and race_time > 2.0 and config.mode == "quick":
		if _best_place_seen == 99:
			_best_place_seen = player.place
		elif player.place < _best_place_seen:
			_earn("overtake", _best_place_seen - player.place)
			_best_place_seen = player.place


func _earn(kind: String, n := 1) -> void:
	if state == RaceState.RESULTS or (player and player.tracker.finished and kind != "clean_lap"):
		return
	if config.mode == "tutorial":
		return
	var gain := earn.add(kind, n)
	if gain > 0:
		money_earned.emit(earn.total, gain, kind)


## Garage levels for a kart in this race: the player's own upgrades, AI a
## share of the player's average (KartTuning.ai_levels). Balance tests and
## Drift School use stock karts.
func _tuning_for(is_player: bool, player_racer: String) -> Dictionary:
	if bool(config.get("balance_test", false)) or config.mode == "tutorial":
		return {}
	var pl: Dictionary = config.get("tuning", SaveManager.tuning_levels(player_racer))
	if is_player:
		return pl
	if config.mode == "time_trial":
		return {}
	return KartTuning.ai_levels(pl, _ai_difficulty(false))


## Kids mode balance: the auto-driven kart is a little slower than a human
## top speed so easy rivals still race it (podium often, wins sometimes).
const KIDS_PLAYER_SPEED := 0.9


## Kids controls (0.9.5): the player's kart is driven by its AIDriver.
func kids_mode() -> bool:
	return bool(config.get("kids_auto", false))


## The player's kart drives itself (Kids controls or debug autopilot).
func auto_drive() -> bool:
	return kids_mode() or bool(config.get("debug_autopilot", false))


## Kids controls: gentler rivals; the auto-driver uses the same easy skill.
func _ai_difficulty(is_player: bool) -> String:
	if not kids_mode():
		return String(config.difficulty)
	return "easy"


func fire_nitro() -> bool:
	if nitro and state == RaceState.RACING and nitro.fire(player.kart):
		player_message.emit("HUD_NITRO", "good")
		return true
	return false


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
			if dist >= CONTACT_LONG or dist < 0.001 or absf(a.global_position.y - b.global_position.y) > 1.5:
				continue
			var nrm := d / dist
			# Required centre distance along this direction from the average
			# heading of the pair (ellipse: CONTACT_SIDE across, CONTACT_LONG along).
			var fwd := (a.forward_dir() + b.forward_dir())
			fwd = fwd.normalized() if fwd.length_squared() > 0.01 else a.forward_dir()
			var along := nrm.dot(fwd)
			var across := sqrt(maxf(1.0 - along * along, 0.0))
			var need := 1.0 / sqrt(pow(across / CONTACT_SIDE, 2.0) + pow(along / CONTACT_LONG, 2.0))
			if dist >= need:
				continue
			var rel := (a.velocity - b.velocity).dot(nrm)
			var overlap := need - dist
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


## Steering help for the player: Vector2(centre pull, edge correction).
## Positive lateral = right of centre → steer left (negative).
func _steer_assist_for(r: Racer) -> Vector2:
	var hw := maxf(track.main.half_width_at(r.tracker.s), 1.0)
	var l := clampf(r.tracker.lateral / hw, -1.5, 1.5)
	var centre := clampf(-l, -1.0, 1.0)
	return Vector2(centre, edge_assist(l, r.kart.forward_dir().dot(track.main.right_at(r.tracker.s))))


const EDGE_ASSIST_START := 0.55 ## fraction of the half width where help begins
const EDGE_ASSIST_MAX := 0.6


## Edge help from the lateral position (−1..1 = left..right edge) and how fast
## the heading points sideways (+ = towards the right). Zero in the middle of
## the road or when already heading away from the edge.
static func edge_assist(l: float, heading_right: float) -> float:
	var near := clampf((absf(l) - EDGE_ASSIST_START) / (1.0 - EDGE_ASSIST_START), 0.0, 1.0)
	var towards := heading_right * signf(l)
	if near <= 0.0 or towards <= 0.02:
		return 0.0
	return -signf(l) * clampf(near * (0.4 + towards * 3.0), 0.0, EDGE_ASSIST_MAX)


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
	AudioManager.stop_ambience()
	AudioManager.play_music("menu", 1.0)
	Game.goto(Game.State.MODE_SELECT)


func quit_to_menu() -> void:
	get_tree().paused = false
	AudioManager.stop_ambience()
	AudioManager.play_music("menu", 1.0)
	Game.goto(Game.State.MAIN_MENU)
