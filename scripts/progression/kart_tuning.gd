class_name KartTuning
extends RefCounted
## Garage upgrades (0.8.0): per-kart levels bought with manat. Five handling
## upgrades (0..MAX_LEVEL) and the Nitro add-on (0 = not fitted, 1 = fitted,
## up to NITRO_MAX). Effects are capped so a fully tuned kart is clearly
## better but never breaks the race (docs/TUNING.md "Garage").

const MAX_LEVEL := 5
const NITRO_MAX := 4
const CATEGORIES := ["speed", "engine", "brakes", "steering", "tyres"]
## Price of the NEXT level in qəpik, index = current level.
const COSTS := [130, 220, 340, 520, 800]
const NITRO_COSTS := [600, 300, 450, 600] ## fit, then levels 2..4
const PAINT_COST := 150 ## buy a star-locked paint early
## Relative gain per level.
const PER_LEVEL := {"speed": 0.024, "engine": 0.05, "brakes": 0.08, "steering": 0.035, "tyres": 0.05}
## AI karts get this share of the player's average level, by difficulty.
const AI_SHARE := {"easy": 0.5, "medium": 0.8, "hard": 1.0}


static func empty() -> Dictionary:
	return {"speed": 0, "engine": 0, "brakes": 0, "steering": 0, "tyres": 0, "nitro": 0}


static func max_for(cat: String) -> int:
	return NITRO_MAX if cat == "nitro" else MAX_LEVEL


## Cost of the next level, or -1 when maxed.
static func next_cost(cat: String, level: int) -> int:
	var table: Array = NITRO_COSTS if cat == "nitro" else COSTS
	return int(table[level]) if level >= 0 and level < table.size() else -1


static func total_cost_full() -> int:
	var t := 0
	for c in COSTS:
		t += int(c)
	t *= CATEGORIES.size()
	for c in NITRO_COSTS:
		t += int(c)
	return t


## Applies upgrade levels to a fresh KartStats (in place).
static func apply(stats: KartStats, levels: Dictionary) -> void:
	var lv := func(c: String) -> int: return clampi(int(levels.get(c, 0)), 0, MAX_LEVEL)
	stats.top_speed *= 1.0 + PER_LEVEL.speed * lv.call("speed")
	stats.acceleration *= 1.0 + PER_LEVEL.engine * lv.call("engine")
	stats.brake_decel *= 1.0 + PER_LEVEL.brakes * lv.call("brakes")
	var st: float = 1.0 + PER_LEVEL.steering * lv.call("steering")
	stats.steer_rate_low *= st
	stats.steer_rate_high *= st
	stats.lateral_grip *= 1.0 + PER_LEVEL.tyres * lv.call("tyres")
	stats.offroad_grip_factor = minf(stats.offroad_grip_factor + 0.02 * lv.call("tyres"), 0.9)


## AI tuning: a share of the player's average level (rounded) in every
## handling category, so the field keeps up as the player upgrades.
static func ai_levels(player_levels: Dictionary, difficulty: String) -> Dictionary:
	var sum := 0.0
	for c in CATEGORIES:
		sum += clampi(int(player_levels.get(c, 0)), 0, MAX_LEVEL)
	var avg := sum / CATEGORIES.size()
	var l := int(round(avg * float(AI_SHARE.get(difficulty, 0.8))))
	var out := empty()
	for c in CATEGORIES:
		out[c] = l
	return out


## Nitro add-on figures for a fitted level (1..4).
static func nitro_spec(level: int) -> Dictionary:
	var l := clampi(level, 1, NITRO_MAX) - 1
	return {"strength": 7.0 + 0.8 * l, "duration": 1.2 + 0.15 * l, "recharge": 20.0 - 2.5 * l}


## Display rating 0..10 for the stat preview bars: base rating (0..5 scale
## doubled) plus up to +2 from upgrades.
static func preview(base10: int, level: int) -> float:
	return clampf(base10 + 2.0 * float(level) / MAX_LEVEL, 0.0, 10.0)
