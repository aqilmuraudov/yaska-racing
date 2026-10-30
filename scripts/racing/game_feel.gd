class_name GameFeel
extends RefCounted
## 0.9.1 "game feel" rules in one place (pure, unit tested): turbo start
## window, drift spark tier colours / boost mapping, near-miss detection and
## the speed-effects switch.

## Turbo start: seconds before GO of the last gas press.
const START_WINDOW := 0.45   ## press within this → turbo start
const START_PERFECT := 0.25  ## press within this → full strength
## Drift spark colours by charge tier: 0 charging, 1 blue, 2 orange, 3 pink/purple.
const TIER_COLORS := [Color("cfe9ff"), Color("4fb4ff"), Color("ff9a1f"), Color("e24fff")]
## Near miss: pass a rival this close (m, side to side) at this share of top speed.
const NEAR_LATERAL := 1.9
const NEAR_LONG := 2.5
const NEAR_SPEED := 0.7
const NEAR_COOLDOWN := 1.5


## "perfect" | "good" | "stall" | "none". press_remaining < 0 = never pressed.
static func start_result(press_remaining: float, holding: bool) -> String:
	if not holding or press_remaining < 0.0:
		return "none"
	if press_remaining <= START_PERFECT:
		return "perfect"
	if press_remaining <= START_WINDOW:
		return "good"
	return "stall"


static func start_quality(result: String) -> float:
	match result:
		"perfect": return 1.0
		"good": return 0.65
	return 0.0


## Spark colour while drifting: level 0 = not charged yet (pale).
static func tier_color(level: int) -> Color:
	return TIER_COLORS[clampi(level, 0, 3)]


## Boost strength / duration for a drift tier (same rule as the controller).
static func drift_boost(stats: KartStats, tier: int) -> Dictionary:
	var t := clampi(tier, 1, 3)
	return {"strength": stats.boost_strength + (t - 1) * stats.boost_tier_bonus,
		"duration": stats.boost_duration + (t - 1) * 0.12}


## Near miss: the player went from behind (rel < 0) to ahead (rel >= 0) of a
## rival this tick, side by side within NEAR_LATERAL, fast, without contact.
static func is_near_miss(rel_prev: float, rel_now: float, lateral_gap: float, speed_ratio: float, touched: bool) -> bool:
	if touched or speed_ratio < NEAR_SPEED:
		return false
	if not (rel_prev < 0.0 and rel_now >= 0.0 and rel_now < NEAR_LONG):
		return false
	return absf(lateral_gap) <= NEAR_LATERAL


static func speed_fx_enabled() -> bool:
	if not bool(Settings.get_value("graphics", "speed_effects", true)):
		return false
	return float(Settings.get_value("graphics", "effects_density", 0.7)) > 0.05
