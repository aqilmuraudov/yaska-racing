class_name DailyChallenge
extends RefCounted
## Gündəlik tapşırıq (0.10.0): one challenge per local calendar day, the
## same for the whole day (seeded by the date). Paid once per day (ledger id
## "dailych:<date>"); data.daily_challenge.done holds the last date done.
##
## Types: win (finish 1st), win_kart (finish 1st with a kart you own),
## stars (collect N stars and finish), time (finish under T seconds),
## clean (finish top 3 without a hard wall hit).
## Kids controls (the kart drives itself) soften the goal: "win" types
## become "finish top 3" and the time limit gets KIDS_TIME_SLACK more.

const REWARD := 150 ## qəpik, once per day
const LAPS := 2
const TYPES := ["win", "win_kart", "stars", "time", "clean"]
## Seconds per lap for the "time" goal (medium rivals lap in about 40 s,
## a clean human lap is 37-39 s; see docs/TUNING.md).
const TIME_PER_LAP := [49.0, 52.0, 55.0] # autopilot best lap 50.3 s (0.10.0 measurement)
const STAR_GOALS := [5, 6, 7, 8]
const KIDS_TIME_SLACK := 1.15


static func seed_for(date: String) -> int:
	return absi(hash("dailych:" + date.substr(0, 10)))


## Today's challenge. `owned` (kart ids) picks the kart for win_kart; the
## result only depends on the date and the owned list.
static func generate(date: String, owned: Array = []) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(date)
	var type: String = TYPES[rng.randi_range(0, TYPES.size() - 1)]
	var ch := {"date": date.substr(0, 10), "type": type, "laps": LAPS, "seed": seed_for(date) % 1000000 + 7, "kart": "", "n": 0}
	var karts: Array = []
	for id in owned:
		if RacerRoster.is_valid(String(id)):
			karts.append(String(id))
	karts.sort()
	var pick := rng.randi_range(0, 1 << 20)
	# 0.11.0: the day's track (drawn after the older picks so they stay the same).
	ch.track = String(TrackList.IDS[rng.randi_range(0, TrackList.IDS.size() - 1)])
	ch.laps = TrackList.clamp_laps(ch.track, LAPS) # 0.19.0
	var scale := TrackList.lap_scale(ch.track)
	match type:
		"win_kart":
			if karts.size() <= 1:
				ch.type = "win"
			else:
				ch.kart = karts[pick % karts.size()]
		"stars":
			ch.n = int(round(float(STAR_GOALS[pick % STAR_GOALS.size()]) * (1.0 if scale >= 1.0 else 0.85)))
		"time":
			ch.n = int(round(float(TIME_PER_LAP[pick % TIME_PER_LAP.size()]) * scale * int(ch.laps)))
	return ch


## The goal as played: kids controls soften it.
static func effective(ch: Dictionary, kids: bool) -> Dictionary:
	var e := ch.duplicate()
	if not kids:
		return e
	match String(ch.type):
		"win", "win_kart":
			e.type = "podium" if ch.type == "win" else "podium_kart"
		"time":
			e.n = int(ceil(float(ch.n) * KIDS_TIME_SLACK))
	return e


## snap: {"finished", "place", "kart", "stars", "hard_hits", "time"}
static func is_done(ch: Dictionary, snap: Dictionary) -> bool:
	if not bool(snap.get("finished", false)):
		return false
	var place := int(snap.get("place", 99))
	match String(ch.type):
		"win": return place == 1
		"win_kart": return place == 1 and String(snap.get("kart", "")) == String(ch.kart)
		"podium": return place <= 3
		"podium_kart": return place <= 3 and String(snap.get("kart", "")) == String(ch.kart)
		"stars": return int(snap.get("stars", 0)) >= int(ch.n)
		"time": return float(snap.get("time", 9999.0)) < float(ch.n)
		"clean": return place <= 3 and int(snap.get("hard_hits", 1)) == 0
	return false


static func done_today(data: Dictionary, date: String) -> bool:
	var d = data.get("daily_challenge", {})
	return typeof(d) == TYPE_DICTIONARY and String(d.get("done", "")) == date.substr(0, 10)


## Marks the day done and pays once. Returns the qəpik granted.
static func complete(data: Dictionary, ch: Dictionary, grant: Callable) -> int:
	if done_today(data, String(ch.date)):
		return 0
	var dc: Dictionary = data.get("daily_challenge", {})
	dc.done = String(ch.date)
	dc.count = int(dc.get("count", 0)) + 1
	data.daily_challenge = dc
	return int(grant.call("dailych:" + String(ch.date), REWARD))


## Race settings for the challenge (same rivals all day).
static func apply_config(cfg: Dictionary, ch: Dictionary, selected_kart: String) -> Dictionary:
	cfg.mode = "quick"
	cfg.series = "daily"
	cfg.daily = ch.duplicate()
	cfg.laps = int(ch.laps)
	cfg.ai_count = 5
	cfg.items = true
	cfg.time_of_day = "day"
	cfg.track_id = TrackList.valid(String(ch.get("track", ""))) # 0.11.0
	cfg.seed = int(ch.seed)
	cfg.kart_id = String(ch.kart) if String(ch.kart) != "" else selected_kart
	return cfg


static func text(ch: Dictionary) -> String:
	var tr := func(k): return TranslationServer.translate(k)
	match String(ch.type):
		"win": return tr.call("DAILY_WIN")
		"podium": return tr.call("DAILY_PODIUM")
		"win_kart": return tr.call("DAILY_WIN_KART") % RacerRoster.get_def(String(ch.kart)).display_name
		"podium_kart": return tr.call("DAILY_PODIUM_KART") % RacerRoster.get_def(String(ch.kart)).display_name
		"stars": return tr.call("DAILY_STARS") % int(ch.n)
		"time": return tr.call("DAILY_TIME") % ("%d:%02d" % [int(ch.n) / 60, int(ch.n) % 60])
		"clean": return tr.call("DAILY_CLEAN")
	return ""


static func icon(ch: Dictionary) -> String:
	match String(ch.type):
		"stars": return "star"
		"time": return "mode_time"
		"clean": return "steer_help"
	return "trophy"
