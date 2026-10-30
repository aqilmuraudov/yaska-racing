class_name BakuCup
extends RefCounted
## Bakı Kuboku (0.10.0): a three-race championship on the one track.
##
## The cup lives in SaveManager.data.cup_progress and is saved after every
## race, so closing the app mid-cup resumes at the race that was not
## finished (an unfinished race scores nothing and is simply raced again).
## A damaged or unknown cup state is dropped (clean reset).
##
## What changes from race to race (honest, all real gameplay settings):
##   Race 1: 2 laps, normal grid (you start 4th), items on.
##   Race 2: 3 laps, reverse grid by points (the leader starts last).
##   Race 3 (final): 2 laps, reverse grid by points, no items: pure racing.
## Points per place 10/8/6/4/2/1; the podium after race 3 pays a prize once
## (ledger id "cup:<seed>:final").

const RACES := 3
const POINTS := [10, 8, 6, 4, 2, 1]
const PRIZE := [400, 250, 150] ## qəpik for cup places 1..3
const PRIZE_OTHER := 60 ## finishing the cup outside the podium
const OPPONENTS := 5
const STAGES := [
	{"laps": 2, "grid": "normal", "items": true, "tod": "day", "track": "seafront_sprint"},
	{"laps": 3, "grid": "reverse", "items": true, "tod": "day", "track": "downtown_towers"}, # 0.11.0 race 2 downtown
	{"laps": 2, "grid": "reverse", "items": false, "tod": "sunset", "track": "seafront_sprint"}, # 0.10.1 final at sunset
]


static func points_for(place: int) -> int:
	return int(POINTS[place - 1]) if place >= 1 and place <= POINTS.size() else 0


static func prize_for(place: int) -> int:
	return int(PRIZE[place - 1]) if place >= 1 and place <= PRIZE.size() else PRIZE_OTHER


## Fresh cup state for `kart_id` with a seed (the same rivals all cup).
static func new_cup(kart_id: String, seed_value: int) -> Dictionary:
	var roster: Array = []
	for id in RacerRoster.opponents(kart_id, OPPONENTS, seed_value):
		roster.append(String(id))
	var pts := {kart_id: 0}
	for id in roster:
		pts[id] = 0
	return {"seed": seed_value, "race": 0, "kart_id": kart_id, "roster": roster,
		"points": pts, "prev_points": pts.duplicate(), "last": [], "prize": 0, "prize_paid": false}


static func start(data: Dictionary, kart_id: String, seed_value: int) -> Dictionary:
	data.cup_progress = new_cup(kart_id, seed_value)
	return data.cup_progress


## Valid cup state or {} (clean reset of anything damaged or foreign).
static func sanitize(cup) -> Dictionary:
	if typeof(cup) != TYPE_DICTIONARY or (cup as Dictionary).is_empty():
		return {}
	var c: Dictionary = cup
	if not c.has("seed") or typeof(c.get("roster")) != TYPE_ARRAY or typeof(c.get("points")) != TYPE_DICTIONARY:
		return {}
	if not RacerRoster.is_valid(String(c.get("kart_id", ""))):
		return {}
	var race := int(c.get("race", -1))
	if race < 0 or race > RACES or (c.roster as Array).size() != OPPONENTS:
		return {}
	for id in c.roster:
		if not RacerRoster.is_valid(String(id)) or not (c.points as Dictionary).has(String(id)):
			return {}
	if not (c.points as Dictionary).has(String(c.kart_id)):
		return {}
	if typeof(c.get("prev_points")) != TYPE_DICTIONARY:
		c.prev_points = (c.points as Dictionary).duplicate()
	if typeof(c.get("last")) != TYPE_ARRAY:
		c.last = []
	return c


static func current(data: Dictionary) -> Dictionary:
	var c := sanitize(data.get("cup_progress", {}))
	if c.is_empty() and not (data.get("cup_progress", {}) as Dictionary).is_empty():
		data.cup_progress = {}
	return c


static func is_active(data: Dictionary) -> bool:
	return not current(data).is_empty()


static func is_complete(cup: Dictionary) -> bool:
	return not cup.is_empty() and int(cup.race) >= RACES


static func event_id(cup: Dictionary, race_index: int) -> String:
	return "cup:%d:%d" % [int(cup.seed), race_index]


## Standings: [{"id", "points", "is_player", "place"}], best first. Ties go
## to the better place in the latest race, then roster order.
static func standings(cup: Dictionary, use_prev := false) -> Array:
	var pts: Dictionary = cup.prev_points if use_prev else cup.points
	var last_place := {}
	for row in cup.get("last", []):
		last_place[String(row.id)] = int(row.place)
	var ids: Array = [String(cup.kart_id)] + Array(cup.roster)
	var rows: Array = []
	for i in ids.size():
		var id: String = ids[i]
		rows.append({"id": id, "points": int(pts.get(id, 0)), "is_player": id == String(cup.kart_id),
			"order": i, "lp": int(last_place.get(id, 99)) if not use_prev else 99})
	rows.sort_custom(func(a, b):
		if a.points != b.points:
			return a.points > b.points
		if a.lp != b.lp:
			return a.lp < b.lp
		return a.order < b.order)
	for i in rows.size():
		rows[i].place = i + 1
	return rows


static func player_place(cup: Dictionary) -> int:
	for r in standings(cup):
		if r.is_player:
			return int(r.place)
	return 0


## Race settings for the next race of the cup, merged into a race config.
static func apply_config(cfg: Dictionary, cup: Dictionary) -> Dictionary:
	var idx := clampi(int(cup.race), 0, RACES - 1)
	var st: Dictionary = STAGES[idx]
	cfg.mode = "quick"
	cfg.series = "cup"
	cfg.cup_race = idx
	cfg.kart_id = String(cup.kart_id)
	cfg.laps = int(st.laps)
	cfg.items = bool(st.items)
	cfg.time_of_day = String(st.get("tod", "day"))
	cfg.track_id = TrackList.valid(String(st.get("track", ""))) # 0.11.0
	cfg.ai_count = OPPONENTS
	cfg.roster = Array(cup.roster).duplicate()
	cfg.seed = int(cup.seed) + idx * 101 + 1
	cfg.fixed_event_id = event_id(cup, idx)
	cfg.grid_order = grid_order(cup, idx)
	return cfg


## Racer ids in grid-slot order (slot 0 = pole). Race 1 keeps the normal
## grid (player in slot 3); later races reverse the standings.
static func grid_order(cup: Dictionary, race_index: int) -> Array:
	var ids: Array = Array(cup.roster).duplicate()
	if String(STAGES[clampi(race_index, 0, RACES - 1)].grid) == "normal":
		ids.insert(mini(3, ids.size()), String(cup.kart_id))
		return ids
	var out: Array = []
	var st := standings(cup)
	for i in range(st.size() - 1, -1, -1):
		out.append(String(st[i].id))
	return out


## Scores one finished race from result rows ({"place", "kart"}). Only the
## race the cup is waiting for counts, once. Returns {"ok", "gained": {id: pts}}.
static func record_race(data: Dictionary, race_index: int, rows: Array) -> Dictionary:
	var cup := current(data)
	if cup.is_empty() or int(cup.race) != race_index or race_index >= RACES:
		return {"ok": false, "gained": {}}
	cup.prev_points = (cup.points as Dictionary).duplicate()
	var gained := {}
	var last: Array = []
	for row in rows:
		var id := String(row.get("kart", ""))
		if not (cup.points as Dictionary).has(id):
			continue
		var p := points_for(int(row.place))
		gained[id] = p
		cup.points[id] = int(cup.points[id]) + p
		last.append({"id": id, "place": int(row.place), "points": p})
	cup.last = last
	cup.race = race_index + 1
	if int(cup.race) >= RACES:
		var place := player_place(cup)
		cup.final_place = place
		cup.prize = prize_for(place)
	data.cup_progress = cup
	return {"ok": true, "gained": gained}


## Pays the cup prize once (after race 3). Returns the qəpik granted.
static func pay_prize(cup: Dictionary, grant: Callable) -> int:
	if not is_complete(cup) or bool(cup.get("prize_paid", false)):
		return 0
	var paid: int = grant.call("cup:%d:final" % int(cup.seed), int(cup.prize))
	cup.prize_paid = true
	return paid


## Leaves the cup (after the podium, or abandoning). Completed cups are
## counted in cup_history.
static func close(data: Dictionary) -> void:
	var cup := current(data)
	if is_complete(cup):
		var h: Dictionary = data.get("cup_history", {})
		h.played = int(h.get("played", 0)) + 1
		var place := int(cup.get("final_place", player_place(cup)))
		if place == 1:
			h.won = int(h.get("won", 0)) + 1
		if int(h.get("best", 0)) == 0 or place < int(h.best):
			h.best = place
		data.cup_history = h
	data.cup_progress = {}


static func stage_text(race_index: int) -> Array:
	## Short chip texts for a race: ["2 dövrə", "Lider arxadan", "Əşyasız"]
	var st: Dictionary = STAGES[clampi(race_index, 0, RACES - 1)]
	var out: Array = [TranslationServer.translate("CUP_LAPS") % int(st.laps)]
	out.append(TranslationServer.translate("CUP_GRID_NORMAL" if st.grid == "normal" else "CUP_GRID_REVERSE"))
	out.append(TranslationServer.translate("CUP_ITEMS_ON" if st.items else "CUP_ITEMS_OFF"))
	if String(st.get("tod", "day")) != "day":
		out.append(TranslationServer.translate(TimeOfDay.NAME_KEYS[String(st.tod)]))
	return out
