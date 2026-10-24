class_name KartAudio
extends Node3D
## Engine / tyre loops and kart event one-shots. Loops only run while the
## race's EngineAudioDirector marks this kart audible (voice budget).

var kart: KartController
var engine: AudioStreamPlayer3D
var tyres: AudioStreamPlayer3D
var audible := false
var _rpm := 0.0
var _tyre_target := -60.0


func setup(p_kart: KartController) -> void:
	kart = p_kart
	engine = _loop_player("engine_loop", "Engine")
	tyres = _loop_player("drift_loop", "SFX")
	kart.hopped.connect(func(): _shot("hop", -6.0, randf_range(0.95, 1.05)))
	kart.landed.connect(func(t): if t > 0.25: _shot("land", -4.0 + minf(t * 4.0, 4.0), randf_range(0.9, 1.05)))
	kart.drift_boost.connect(func(tier, perfect): _shot("boost_perfect" if perfect else "boost", 0.0, 1.0 + 0.08 * tier, 2))
	kart.drift_miss.connect(func(): _shot("miss", -3.0, 1.0))
	kart.boost_started.connect(func(src): if src != &"drift": _shot("boost", -1.0, 0.9 if src == &"pad" else 1.0, 2))
	kart.wall_hit.connect(func(s): _shot("wall_hit", -8.0 + s * 8.0, randf_range(0.9, 1.1)))
	kart.got_hit.connect(func(_k): _shot("hit", 0.0, 1.0, 2))
	kart.shield_blocked.connect(func(): _shot("shield_block", 0.0, 1.0, 2))
	kart.respawn_started.connect(func(): _shot("recover", -2.0, 1.0))


func _loop_player(clip: String, bus: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = bus
	p.unit_size = 10.0
	p.max_distance = 80.0
	p.attenuation_filter_cutoff_hz = 8000.0
	p.stream = AudioManager.get_stream(clip)
	p.volume_db = -80.0
	add_child(p)
	return p


func _shot(clip: String, vol: float, pitch: float, priority: int = 1) -> void:
	if not audible and not kart.is_player:
		priority = 0
	if kart.is_player:
		AudioManager.play(clip, vol, pitch)
	else:
		AudioManager.play_at(clip, kart.global_position, vol - 2.0, pitch, priority)


func set_audible(on: bool) -> void:
	audible = on
	for p in [engine, tyres]:
		if p.stream == null:
			continue
		if on and not p.playing:
			p.play(randf() * 0.5)
		elif not on and p.playing:
			p.stop()


func _process(delta: float) -> void:
	if not audible or kart == null:
		return
	var spd := absf(kart.speed) / kart.stats.top_speed
	var load := kart.input.throttle
	var target := 0.55 + spd * 1.1 + load * 0.12
	# Pitch rises with the real speed above top speed (boosts), so the engine
	# "pulls" exactly when the kart covers more ground per second.
	target += maxf(spd - 1.0, 0.0) * 0.9
	if kart.boost.is_active():
		target += 0.08
	if not kart.grounded:
		target += 0.1 * load
	_rpm = lerpf(_rpm, target, 1.0 - exp(-6.0 * delta))
	engine.pitch_scale = clampf(_rpm, 0.4, 2.2)
	engine.volume_db = lerpf(engine.volume_db, (-4.0 if kart.is_player else -6.0) + load * 2.0, 1.0 - exp(-8.0 * delta))
	var skid := kart.is_drifting() and kart.grounded
	_tyre_target = -8.0 if skid else -60.0
	tyres.volume_db = lerpf(tyres.volume_db, _tyre_target, 1.0 - exp(-12.0 * delta))
	tyres.pitch_scale = 0.9 + spd * 0.25
