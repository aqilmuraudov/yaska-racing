class_name Progression
extends RefCounted
## Long-term rewards (0.7.0): kart paints (stars), kart parts (lifetime
## coins), titles (lifetime stars), trophies (one-off achievements, global and
## per track / per mode, each pays coins) and optional daily goals.
## Early rewards come fast (first paint at 5 stars, first trophy after one
## race); later ones need many races. All state lives in the profile under
## "lifetime", "trophies", "parts_off" and "daily"; old saves get defaults
## and their lifetime counters are seeded from the existing totals.

## Kart parts, unlocked by lifetime money earned (qəpik; spending never
## re-locks). All "coins" amounts in this file are qəpik since 0.8.0.
const PARTS := [
	{"id": "rims_gold", "name": "PART_RIMS_GOLD", "coins": 240},
	{"id": "spoiler", "name": "PART_SPOILER", "coins": 700},
	{"id": "twin_exhaust", "name": "PART_TWIN_EXHAUST", "coins": 1400},
	{"id": "flag", "name": "PART_FLAG", "coins": 2400},
	{"id": "neon", "name": "PART_NEON", "coins": 4000},
	{"id": "crown", "name": "PART_CROWN", "coins": 7000},
]

## Titles by lifetime stars collected.
const TITLES := [
	{"id": "rookie", "name": "TITLE_ROOKIE", "stars": 0},
	{"id": "boulevard", "name": "TITLE_BOULEVARD", "stars": 10},
	{"id": "breeze", "name": "TITLE_BREEZE", "stars": 35},
	{"id": "flame", "name": "TITLE_FLAME", "stars": 80},
	{"id": "maiden", "name": "TITLE_MAIDEN", "stars": 160},
	{"id": "caspian", "name": "TITLE_CASPIAN", "stars": 280},
	{"id": "legend", "name": "TITLE_LEGEND", "stars": 450},
	{"id": "turbo", "name": "TITLE_TURBO", "stars": 700},
]

const TRACKS := TrackList.IDS ## 0.11.0: per-track trophies for every track
## 0.13.0: string prefix per track (was "not the first track = Göydələnlər").
const TROPHY_PREFIX := {"seafront_sprint": "TROPHY_", "downtown_towers": "TROPHY_DT_", "old_city": "TROPHY_OC_", "karabakh": "TROPHY_KB_", "karabakh_shusha": "TROPHY_KS_", "karabakh_lachin": "TROPHY_KL_", "karabakh_khankendi": "TROPHY_KX_"}

## Daily goals (optional): three per day, chosen from the date.
const DAILY_POOL := [
	{"id": "races2", "stat": "races", "target": 2},
	{"id": "podium1", "stat": "podiums", "target": 1},
	{"id": "stars12", "stat": "stars", "target": 12},
	{"id": "boosts6", "stat": "drift_boosts", "target": 6},
	{"id": "tt1", "stat": "tt_runs", "target": 1},
	{"id": "win1", "stat": "wins", "target": 1},
]
const DAILY_COINS := 60


## Every trophy: id, text key (+ format arg), stat, target, coins.
static func trophies() -> Array:
	var t: Array = []
	for n in [1, 5, 25, 60, 120]:
		t.append({"id": "races_%d" % n, "name": "TROPHY_RACES", "arg": n, "stat": "races", "target": n, "coins": 10 + n})
	for n in [1, 3, 10, 30]:
		t.append({"id": "podiums_%d" % n, "name": "TROPHY_PODIUMS", "arg": n, "stat": "podiums", "target": n, "coins": 15 + n * 2})
	for n in [1, 5, 20, 50]:
		t.append({"id": "wins_%d" % n, "name": "TROPHY_WINS", "arg": n, "stat": "wins", "target": n, "coins": 25 + n * 3})
	for n in [1, 10, 50, 150, 400]:
		t.append({"id": "boosts_%d" % n, "name": "TROPHY_BOOSTS", "arg": n, "stat": "drift_boosts", "target": n, "coins": 10 + n / 4})
	for n in [10, 50, 150, 350, 700]:
		t.append({"id": "stars_%d" % n, "name": "TROPHY_STARS", "arg": n, "stat": "stars", "target": n, "coins": 10 + n / 5})
	for n in [3, 15]:
		t.append({"id": "daily_%d" % n, "name": "TROPHY_DAILY", "arg": n, "stat": "daily_done", "target": n, "coins": 40 + n * 2})
	t.append({"id": "school", "name": "TROPHY_SCHOOL", "arg": 0, "stat": "tutorial_done", "target": 1, "coins": 25})
	for track in TRACKS:
		for m in [["quick_finish", 1, 15], ["quick_podium", 1, 25], ["quick_win", 1, 40], ["quick_win", 5, 80],
				["tt_finish", 1, 15], ["tt_finish", 5, 40], ["tt_record", 3, 50]]:
			var key := "%s:%s" % [track, m[0]]
			t.append({"id": "%s_%d" % [key, m[1]], "name": String(TROPHY_PREFIX.get(track, "TROPHY_")) + String(m[0]).to_upper(), "arg": m[1],
				"track": track, "stat": key, "target": m[1], "coins": m[2]})
	for e in t: # amounts above were coins (0.7); one coin = 2 qəpik
		e.coins = int(e.coins) * Money.COINS_TO_QEPIK
	return t


# --- Profile state ---------------------------------------------------------

static func default_state() -> Dictionary:
	return {
		"lifetime": {"stars": 0, "coins": 0, "races": 0, "wins": 0, "podiums": 0, "drift_boosts": 0,
			"tt_runs": 0, "daily_done": 0, "tutorial_done": 0, "seeded": false},
		"track_stats": {}, ## "track:mode_stat" -> count (per-track trophies)
		"trophies": [],
		"parts_off": [],
		"daily": {"day": "", "goals": [], "progress": {}, "done": []},
	}


## Old profiles: lifetime counters start from the totals they already have,
## so nobody loses progress (and early trophies unlock on the next race).
static func seed_from_old(data: Dictionary) -> void:
	var lt: Dictionary = data.lifetime
	if bool(lt.get("seeded", false)):
		return
	lt.stars = maxi(int(lt.stars), int(data.get("stars", 0)))
	lt.coins = maxi(int(lt.coins), int(data.get("currency", 0)))
	var st: Dictionary = data.get("stats", {})
	lt.races = maxi(int(lt.races), int(st.get("races", 0)))
	lt.wins = maxi(int(lt.wins), int(st.get("wins", 0)))
	lt.podiums = maxi(int(lt.podiums), int(st.get("podiums", 0)))
	if bool(data.get("tutorial", {}).get("drift_done", false)):
		lt.tutorial_done = 1
	lt.seeded = true


static func stat(data: Dictionary, key: String) -> int:
	if key.contains(":"):
		return int(data.get("track_stats", {}).get(key, 0))
	return int(data.lifetime.get(key, 0))


static func title_for(stars: int) -> Dictionary:
	var best: Dictionary = TITLES[0]
	for t in TITLES:
		if stars >= int(t.stars):
			best = t
	return best


static func next_title(stars: int) -> Dictionary:
	for t in TITLES:
		if stars < int(t.stars):
			return t
	return {}


static func part_unlocked(data: Dictionary, index: int) -> bool:
	return stat(data, "coins") >= int(PARTS[index].coins)


## Parts shown on the kart: unlocked and not switched off by the player.
static func equipped_parts(data: Dictionary) -> Array:
	var out: Array = []
	for i in PARTS.size():
		if part_unlocked(data, i) and not (PARTS[i].id in data.parts_off):
			out.append(PARTS[i].id)
	return out


# --- Daily goals -------------------------------------------------------------

static func today() -> String:
	return Time.get_date_string_from_system()


static func ensure_daily(data: Dictionary, day := "") -> void:
	if day == "":
		day = today()
	var d: Dictionary = data.daily
	if String(d.get("day", "")) == day:
		return
	var h := absi(hash(day))
	var ids: Array = []
	var pool := DAILY_POOL.duplicate()
	for k in 3:
		var g: Dictionary = pool[(h >> (k * 4)) % pool.size()]
		pool.erase(g)
		ids.append(g.id)
	data.daily = {"day": day, "goals": ids, "progress": {}, "done": []}


static func daily_goal(id: String) -> Dictionary:
	for g in DAILY_POOL:
		if g.id == id:
			return g
	return {}


# --- Race evaluation -----------------------------------------------------------

## Applies one finished event to the lifetime counters, daily goals and
## trophies. Call once per event (the caller guards with the ledger).
## Returns {"coins": int, "unlocks": Array[String] (translated lines)}.
static func on_event(data: Dictionary, ev: Dictionary) -> Dictionary:
	seed_from_old(data)
	ensure_daily(data, String(ev.get("day", "")))
	var before_stars := stat(data, "stars")
	var before_coins := stat(data, "coins")
	var delta := {
		"races": 1 if ev.get("finished", false) and ev.mode != "tutorial" else 0,
		"wins": 1 if ev.get("finished", false) and ev.mode == "quick" and int(ev.place) == 1 else 0,
		"podiums": 1 if ev.get("finished", false) and ev.mode == "quick" and int(ev.place) <= 3 else 0,
		"drift_boosts": int(ev.get("drift_boosts", 0)),
		"stars": int(ev.get("stars", 0)),
		"tt_runs": 1 if ev.get("finished", false) and ev.mode == "time_trial" else 0,
	}
	var lt: Dictionary = data.lifetime
	for k in delta.keys():
		lt[k] = int(lt.get(k, 0)) + int(delta[k])
	if ev.mode == "tutorial" and bool(ev.get("tutorial_done", false)):
		lt.tutorial_done = 1
	var track := String(ev.get("track_id", ""))
	if track != "" and ev.get("finished", false):
		var per := []
		if ev.mode == "quick":
			per.append("quick_finish")
			if int(ev.place) <= 3:
				per.append("quick_podium")
			if int(ev.place) == 1:
				per.append("quick_win")
		elif ev.mode == "time_trial":
			per.append("tt_finish")
			if ev.get("record", false):
				per.append("tt_record")
		for p in per:
			var key := "%s:%s" % [track, p]
			if not data.has("track_stats"):
				data.track_stats = {}
			data.track_stats[key] = int(data.track_stats.get(key, 0)) + 1
	var coins := int(ev.get("coins", 0))
	var lines: Array[String] = []
	var cards: Array = [] ## 0.8.3: {icon, text} for the results unlock cards
	# Daily goals
	var d: Dictionary = data.daily
	for id in d.goals:
		var g := daily_goal(id)
		if g.is_empty() or id in d.done:
			continue
		d.progress[id] = int(d.progress.get(id, 0)) + int(delta.get(g.stat, 0))
		if int(d.progress[id]) >= int(g.target):
			d.done.append(id)
			lt.daily_done = int(lt.get("daily_done", 0)) + 1
			coins += DAILY_COINS
			lines.append(TranslationServer.translate("REWARD_DAILY_DONE") % [goal_text(g), Money.format_delta(DAILY_COINS)])
			cards.append({"icon": "star", "text": goal_text(g)})
	# Trophies (may chain: their coins count towards parts)
	for t in trophies():
		if t.id in data.trophies:
			continue
		if stat(data, t.stat) >= int(t.target):
			data.trophies.append(t.id)
			coins += int(t.coins)
			lines.append(TranslationServer.translate("REWARD_TROPHY") % [trophy_text(t), Money.format_delta(int(t.coins))])
			cards.append({"icon": "trophy", "text": trophy_text(t)})
	lt.coins = int(lt.coins) + coins
	data.currency = int(data.get("currency", 0)) + (coins - int(ev.get("coins", 0)))
	# Titles and parts crossed by this event
	var t_before := title_for(before_stars)
	var t_after := title_for(stat(data, "stars"))
	if t_after.id != t_before.id:
		lines.append(TranslationServer.translate("REWARD_TITLE") % TranslationServer.translate(t_after.name))
		cards.append({"icon": "star", "text": TranslationServer.translate(t_after.name)})
	for i in PARTS.size():
		if before_coins < int(PARTS[i].coins) and stat(data, "coins") >= int(PARTS[i].coins):
			lines.append(TranslationServer.translate("REWARD_PART") % TranslationServer.translate(PARTS[i].name))
			cards.append({"icon": "garage", "text": TranslationServer.translate(PARTS[i].name)})
	return {"coins": coins - int(ev.get("coins", 0)), "unlocks": lines, "cards": cards}


static func trophy_text(t: Dictionary) -> String:
	var s := TranslationServer.translate(t.name)
	return s % int(t.arg) if s.contains("%d") else s


static func goal_text(g: Dictionary) -> String:
	return TranslationServer.translate("DAILY_" + String(g.id).to_upper())


static func trophy_progress(data: Dictionary) -> Vector2i:
	return Vector2i(data.trophies.size(), trophies().size())
