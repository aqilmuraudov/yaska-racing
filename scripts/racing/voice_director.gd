class_name VoiceDirector
extends Node
## 0.15.1 character voice lines in Azerbaijani (ElevenLabs, tools/voice/).
## Short lines at race moments: GO, a rival close behind / ahead, overtakes,
## item hits, the finish. One speaker at a time with a quiet gap, never the same
## line twice in a row. Plays on the SFX bus (project rule) and obeys the
## Settings → Səs "Personaj səsləri" switch (audio.voices_on).

const PATH := "res://assets/voice/%s/%s_%d.ogg"
const COUNTS := {"start": 2, "approach": 3, "pass": 3, "passed": 2, "hit": 2, "win": 2, "lose": 1}
const GAP := 3.0 ## seconds of quiet after a line ends
const NEAR := 7.0 ## metres of race distance that count as "right behind"
const NEAR_TIME := 1.5 ## seconds a rival must stay that close
const NEAR_REST := 8.0 ## the same pair waits this long before another "approach"
const APPROACH_REST := 10.0 ## any "approach" line waits this long after the last one
const TICK := 0.2

var race: RaceManager
var out: AudioStreamPlayer
var quiet := 0.0
var spoken: Array[String] = [] ## "racer/category_n" log (tests)
var _last := {} # racer id -> last line index per category
var _near := {} # racer index -> seconds close (negative = resting)
var _prev_place := 0
var _tick := 0.0
var _approach_rest := 0.0


static func enabled() -> bool:
	return bool(Settings.get_value("audio", "voices_on", true)) and bool(Settings.get_value("audio", "master_on", true))


func setup(p_race: RaceManager) -> void:
	race = p_race
	process_mode = Node.PROCESS_MODE_PAUSABLE
	out = AudioStreamPlayer.new()
	out.name = "Voice"
	out.bus = "SFX"
	out.volume_db = 2.0
	add_child(out)
	race.countdown_tick.connect(func(v): if v == 0: say(race.player, "start"))
	race.player_crossed_finish.connect(_on_finish)
	race.state_changed.connect(func(s): if s == RaceManager.RaceState.COUNTDOWN: reset())
	race.player.kart.got_hit.connect(func(_k): say(race.player, "hit"))


func reset() -> void:
	quiet = 0.0
	_near.clear()
	_approach_rest = 0.0
	_prev_place = 0
	if out:
		out.stop()


func _process(delta: float) -> void:
	quiet = maxf(quiet - delta, 0.0)
	_approach_rest = maxf(_approach_rest - delta, 0.0)
	_tick += delta
	if _tick < TICK:
		return
	var dt := _tick
	_tick = 0.0
	if race == null or race.state != RaceManager.RaceState.RACING or race.player == null:
		return
	_check_places()
	_check_near(dt)


## Place changes of the player: who overtook whom.
func _check_places() -> void:
	var p := race.player
	if race.race_time < 2.0 or p.place <= 0:
		return
	if _prev_place == 0:
		_prev_place = p.place
		return
	if p.place < _prev_place:
		var behind := _racer_at(p.place + 1)
		if behind != null and randf() < 0.4:
			say(behind, "passed")
		else:
			say(p, "pass")
	elif p.place > _prev_place:
		var ahead := _racer_at(p.place - 1)
		if ahead != null and randf() < 0.6:
			say(ahead, "pass")
		else:
			say(p, "passed")
	_prev_place = p.place


## A rival right behind the player teases; the player, right behind a
## rival, calls out.
func _check_near(dt: float) -> void:
	var p := race.player
	for r in race.racers:
		if r == p or r.tracker.finished:
			continue
		var gap := p.tracker.race_distance - r.tracker.race_distance
		var t: float = _near.get(r.index, 0.0)
		if t < 0.0:
			_near[r.index] = minf(t + dt, 0.0)
			continue
		if absf(gap) > NEAR or absf(gap) < 0.5:
			_near[r.index] = 0.0
			continue
		t += dt
		_near[r.index] = t
		if t >= NEAR_TIME and quiet <= 0.0 and _approach_rest <= 0.0:
			if say(r if gap > 0.0 else p, "approach"):
				_near[r.index] = -NEAR_REST
				_approach_rest = APPROACH_REST


func _on_finish(place: int) -> void:
	say(race.player, "win" if place == 1 else "lose", true)


func _racer_at(place: int) -> RaceManager.Racer:
	for r in race.racers:
		if r.place == place:
			return r
	return null


## Plays one line of the racer's category. force: the finish line interrupts.
func say(r: RaceManager.Racer, cat: String, force := false) -> bool:
	if r == null or r.racer_id == "" or not COUNTS.has(cat) or not enabled():
		return false
	if not force and (quiet > 0.0 or out.playing):
		return false
	var n: int = COUNTS[cat]
	var key := "%s/%s" % [r.racer_id, cat]
	var i := randi() % n
	if n > 1 and i == int(_last.get(key, -1)):
		i = (i + 1) % n
	var path := PATH % [r.racer_id, cat, i]
	if not ResourceLoader.exists(path):
		return false
	var stream: AudioStream = load(path)
	_last[key] = i
	out.stream = stream
	out.play()
	quiet = stream.get_length() + GAP
	spoken.append("%s/%s_%d" % [r.racer_id, cat, i])
	return true
