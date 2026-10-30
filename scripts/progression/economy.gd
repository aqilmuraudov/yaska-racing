class_name Economy
extends RefCounted
## Race income in qəpik (see docs/TUNING.md "Economy"). A race pays its
## finishing position plus what the player earned while driving; driving
## income is capped so grinding one trick never beats racing well.

const PLACE_PAY := [200, 160, 130, 100, 85, 70, 60, 50] ## quick race, by place (1st = 2× 4th)
const DNF_PAY := 30
const TIME_TRIAL_PAY := 90
const RECORD_BONUS := 40

## Driving income (qəpik per event).
const DRIFT_BOOST := 4
const PERFECT_BONUS := 2 ## extra for a perfect-timed drift boost
const BOOST_PICKUP := 1 ## boost pad / item boost
const OVERTAKE := 5
const STAR := 2
const CLEAN_LAP := 15
const NEAR_MISS := 3 ## close pass at speed (0.9.1) ## a lap without a hard wall hit
const DRIVING_CAP := 150 ## per race

## Rewarded-ad hook (no SDK yet): one "double the race" claim per event.
const AD_MULTIPLIER := 2


## Live tally of one race's driving income. The race manager feeds events;
## the HUD reads `total` for its small counter.
class Tally:
	extends RefCounted
	var total := 0
	var counts := {"drift": 0, "perfect": 0, "boost": 0, "overtake": 0, "star": 0, "clean_lap": 0, "near_miss": 0}

	## Returns the qəpik actually added (0 once the cap is reached).
	func add(kind: String, n := 1) -> int:
		var per := Economy.rate(kind)
		var gain := mini(per * n, maxi(Economy.DRIVING_CAP - total, 0))
		counts[kind] = int(counts.get(kind, 0)) + n
		total += gain
		return gain


static func rate(kind: String) -> int:
	match kind:
		"drift": return DRIFT_BOOST
		"perfect": return PERFECT_BONUS
		"boost": return BOOST_PICKUP
		"overtake": return OVERTAKE
		"star": return STAR
		"clean_lap": return CLEAN_LAP
		"near_miss": return NEAR_MISS
	return 0


## Finish-position pay for a mode.
static func place_pay(mode: String, place: int, finished: bool) -> int:
	if mode == "time_trial":
		return TIME_TRIAL_PAY if finished else 0
	if mode == "tutorial":
		return 30 if finished else 0
	if not finished:
		return DNF_PAY
	return PLACE_PAY[clampi(place - 1, 0, PLACE_PAY.size() - 1)]


## Full race payout breakdown: {"place", "driving", "record", "total"}.
static func payout(mode: String, place: int, finished: bool, driving: int, record: bool) -> Dictionary:
	var p := place_pay(mode, place, finished)
	var d := clampi(driving, 0, DRIVING_CAP)
	var r := RECORD_BONUS if record else 0
	return {"place": p, "driving": d, "record": r, "total": p + d + r}


## One simulated quick race for balancing: random place 1..6 and typical
## driving (6-14 drift boosts, 0-5 overtakes, 3-10 stars, 0-3 clean laps).
static func simulate_race(rng: RandomNumberGenerator) -> Dictionary:
	var t := Tally.new()
	t.add("drift", rng.randi_range(6, 14))
	t.add("overtake", rng.randi_range(0, 5))
	t.add("star", rng.randi_range(3, 10))
	t.add("clean_lap", rng.randi_range(0, 3))
	var place := rng.randi_range(1, 6)
	var p := payout("quick", place, true, t.total, false)
	p.place_n = place
	return p


## Races needed (cumulative earnings, no daily/trophy bonus) to afford:
## first level-1 upgrade, a level-3 upgrade, nitro fit, one stat maxed and
## a fully tuned kart. Averaged over `runs` careers.
static func simulate(runs := 200, seed_value := 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var stat_full := 0
	for c in KartTuning.COSTS:
		stat_full += int(c)
	var goals := {"level1": int(KartTuning.COSTS[0]), "paint": KartTuning.PAINT_COST,
		"level3_total": int(KartTuning.COSTS[0]) + int(KartTuning.COSTS[1]) + int(KartTuning.COSTS[2]),
		"nitro": int(KartTuning.NITRO_COSTS[0]), "stat_max": stat_full, "kart_full": KartTuning.total_cost_full()}
	var sums := {}
	for k in goals:
		sums[k] = 0.0
	var pay_sum := 0.0
	var by_place := {}
	var n_races := 0
	for run in runs:
		var cum := 0
		var hit := {}
		var i := 0
		while hit.size() < goals.size():
			i += 1
			var r := simulate_race(rng)
			cum += int(r.total)
			pay_sum += int(r.total)
			n_races += 1
			by_place[r.place_n] = by_place.get(r.place_n, []) + [int(r.total)]
			for k in goals:
				if not hit.has(k) and cum >= int(goals[k]):
					hit[k] = i
					sums[k] += i
	var out := {"avg_race": pay_sum / n_races, "goals": goals}
	for k in goals:
		out[k] = sums[k] / runs
	var avg_place := {}
	for p in by_place:
		var s := 0
		for v in by_place[p]:
			s += v
		avg_place[p] = float(s) / by_place[p].size()
	out.by_place = avg_place
	return out


## Kart shop ladder (0.9.0): average races until the cumulative earnings
## (race pay only, no tuning spend) buy each kart in KartShop.ORDER, and the
## same with a typical post-race goal income (`goal_avg` qəpik per race).
static func simulate_karts(runs := 300, seed_value := 1, goal_avg := 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var targets: Array = []
	var cum_price := 0
	for id in KartShop.ORDER:
		cum_price += KartShop.price(id)
		targets.append(cum_price)
	var sums: Array = []
	sums.resize(targets.size())
	sums.fill(0.0)
	for run in runs:
		var cum := 0
		var i := 0
		var k := 0
		while k < targets.size():
			i += 1
			cum += int(simulate_race(rng).total) + goal_avg
			while k < targets.size() and cum >= int(targets[k]):
				sums[k] += i
				k += 1
	var out := {}
	for j in targets.size():
		out[KartShop.ORDER[j]] = {"cumulative": targets[j], "races": sums[j] / runs}
	return out
