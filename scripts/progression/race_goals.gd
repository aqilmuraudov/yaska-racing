class_name RaceGoals
extends RefCounted
## Three short goals for the next quick race (0.9.0). Shown on the results
## screen, ticked live in the HUD, paid (small manat) when the race ends.

## kind -> [min target, max target, qəpik reward]. One table to edit.
const KINDS := {
	"drift": [2, 6, 30], ## "N dəfə drift turbo et"
	"stars": [3, 8, 30], ## "N ulduz topla"
	"overtake": [1, 3, 30], ## "N rəqibi keç"
	"clean_lap": [1, 2, 40], ## "N təmiz dövr sür"
	"top3": [1, 1, 40], ## "Top 3-də bitir"
	"win": [1, 1, 60], ## "Birinci gəl"
	"finish": [1, 1, 30], ## "Yarışı bitir" (kids mode only)
}
## Goals that need hands-on driving skill; swapped in Kids controls (0.9.5).
const SKILL_KINDS := ["drift", "overtake", "clean_lap"]


## Three different goals; `rng_seed` makes it repeatable.
static func generate(rng_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var kinds: Array = KINDS.keys()
	var out: Array = []
	while out.size() < 3:
		var k: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		if k == "finish":
			continue
		if k == "win" and out.any(func(g): return g.kind == "top3"):
			continue
		if k == "top3" and out.any(func(g): return g.kind == "win"):
			continue
		if out.any(func(g): return g.kind == k):
			continue
		var t: Array = KINDS[k]
		out.append({"kind": k, "target": rng.randi_range(int(t[0]), int(t[1])), "reward": int(t[2])})
	return out


## The saved goals, created when missing.
static func current(data: Dictionary) -> Array:
	var g = data.get("race_goals", [])
	if typeof(g) != TYPE_ARRAY or g.size() != 3:
		g = generate(randi())
		data.race_goals = g
	return g


## Progress of one goal from a race snapshot {"drift","stars","overtake",
## "clean_lap","place","finished"}.
static func value(goal: Dictionary, snap: Dictionary) -> int:
	match String(goal.kind):
		"top3":
			return 1 if bool(snap.get("finished", false)) and int(snap.get("place", 99)) <= 3 else 0
		"win":
			return 1 if bool(snap.get("finished", false)) and int(snap.get("place", 99)) == 1 else 0
		"finish":
			return 1 if bool(snap.get("finished", false)) else 0
	return int(snap.get(String(goal.kind), 0))


static func is_done(goal: Dictionary, snap: Dictionary) -> bool:
	return value(goal, snap) >= int(goal.target)


static func text(goal: Dictionary) -> String:
	return TranslationServer.translate("GOAL_" + String(goal.kind).to_upper()).replace("%d", str(int(goal.target)))


const ICONS := {"drift": "hud_drift", "stars": "star", "overtake": "mode_quick",
	"clean_lap": "steering", "top3": "trophy", "win": "trophy", "finish": "play"}


## Short chip text for the results screen ("5 drift", "Top 3").
static func short_text(goal: Dictionary) -> String:
	return TranslationServer.translate("GOALS_S_" + String(goal.kind).to_upper()).replace("%d", str(int(goal.target)))


static func icon(goal: Dictionary) -> String:
	return String(ICONS.get(String(goal.kind), "star"))


## Kids controls: skill goals become simple ones (finish, stars, top 3).
static func kids_safe(goals: Array) -> Array:
	var out: Array = []
	var kinds: Array = []
	for g in goals:
		if not String(g.kind) in SKILL_KINDS:
			out.append(g)
			kinds.append(String(g.kind))
	for g in goals:
		if String(g.kind) in SKILL_KINDS:
			for k in ["finish", "stars", "top3"]:
				if not k in kinds and not (k == "top3" and "win" in kinds):
					var t: Array = KINDS[k]
					out.append({"kind": k, "target": int(t[0]) if k != "stars" else 3, "reward": int(g.reward)})
					kinds.append(k)
					break
	return out


## Pays the goals done in this race; returns {"pay", "done": Array}.
static func settle(goals: Array, snap: Dictionary) -> Dictionary:
	var pay := 0
	var done: Array = []
	for g in goals:
		if is_done(g, snap):
			pay += int(g.reward)
			done.append(g)
	return {"pay": pay, "done": done}
