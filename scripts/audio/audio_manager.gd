extends Node
## Audio buses, pooled one-shot voices and music. Missing clips are tolerated
## so gameplay never depends on audio assets being present.

const BUSES := ["Music", "Engine", "SFX", "UI"]
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_2D := 8
const POOL_3D := 14

var _cache: Dictionary = {}
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current := ""
var _focus_muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	# Gentle limiter on master keeps stacked effects from clipping.
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(master, lim)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool_2d.append(p)
	for i in POOL_3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 8.0
		p3.max_distance = 90.0
		p3.attenuation_filter_cutoff_hz = 6000.0
		add_child(p3)
		_pool_3d.append(p3)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
	apply_volumes()


func apply_volumes() -> void:
	if not is_inside_tree():
		return
	var a: Dictionary = Settings.values.get("audio", {})
	if a.is_empty():
		return
	# Three player switches: Master mutes everything but leaves the Music and
	# Sound Effects choices untouched, so switching it back on restores them.
	var muted: bool = not bool(a.get("master_on", true)) or bool(a.mute) or _focus_muted
	var music_on: bool = a.get("music_on", true)
	var sfx_on: bool = a.get("sfx_on", true)
	_set_bus("Master", 0.0 if muted else float(a.master))
	_set_bus("Music", float(a.music) if music_on else 0.0)
	_set_bus("Engine", float(a.engine) if sfx_on else 0.0)
	_set_bus("SFX", float(a.sfx) if sfx_on else 0.0)
	_set_bus("UI", float(a.ui) if sfx_on else 0.0)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


func get_stream(clip: String, dir: String = SFX_DIR) -> AudioStream:
	var key := dir + clip
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStream = null
	for ext in [".wav", ".ogg"]:
		var path: String = key + ext
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	_cache[key] = stream
	return stream


## Non-positional one-shot (UI, HUD cues, player-centric feedback).
func play(clip: String, volume_db: float = 0.0, pitch: float = 1.0, bus: String = "SFX") -> void:
	var stream := get_stream(clip)
	if stream == null:
		return
	var player: AudioStreamPlayer = null
	for p in _pool_2d:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _pool_2d[0] # steal the oldest-allocated voice
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.bus = bus
	player.play()


func play_ui(clip: String) -> void:
	play(clip, -2.0, 1.0, "UI")


## Positional one-shot. Lower priority sounds are dropped when the pool is full.
func play_at(clip: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0, priority: int = 1) -> void:
	var stream := get_stream(clip)
	if stream == null:
		return
	var player: AudioStreamPlayer3D = null
	for p in _pool_3d:
		if not p.playing:
			player = p
			break
	if player == null:
		if priority < 2:
			return
		player = _pool_3d[randi() % _pool_3d.size()]
	player.stream = stream
	player.global_position = pos
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func play_music(track: String, fade_time: float = 1.0) -> void:
	if track == _music_current:
		return
	var stream := get_stream(track, MUSIC_DIR)
	_music_current = track
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	if stream == null and not outgoing.playing:
		return
	var tw := create_tween().set_parallel(true)
	if stream != null:
		incoming.stream = stream
		incoming.volume_db = -40.0
		incoming.play()
		tw.tween_property(incoming, "volume_db", 0.0, fade_time)
	if outgoing.playing:
		tw.tween_property(outgoing, "volume_db", -60.0, fade_time)
		tw.chain().tween_callback(outgoing.stop)


func stop_music(fade_time: float = 0.6) -> void:
	_music_current = ""
	if not _music_a.playing and not _music_b.playing:
		return
	var tw := create_tween().set_parallel(true)
	for m in [_music_a, _music_b]:
		if m.playing:
			tw.tween_property(m, "volume_db", -60.0, fade_time)
	tw.chain().tween_callback(func():
		_music_a.stop()
		_music_b.stop())


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if not bool(Settings.get_value("audio", "background_audio", false)):
				_focus_muted = true
				apply_volumes()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			if _focus_muted:
				_focus_muted = false
				apply_volumes()
