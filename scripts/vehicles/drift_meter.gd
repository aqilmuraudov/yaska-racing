class_name DriftMeter
extends RefCounted
## Timing logic for drift boosts.
##
## While drifting, the meter fills over `charge_time`. Pressing boost while
## the meter is inside [window_start, 1] awards a boost of the next chain tier
## (max 3 per drift); presses in the perfect zone earn extra. Pressing early,
## or holding at full for longer than `overheat_time`, is a miss: the meter
## restarts after a short cooldown but the chain is kept (light penalty).

const MAX_CHAIN := 3
const MISS_COOLDOWN := 0.3

enum Result { NONE, BOOST, MISS }

var charge_time := 0.85
var window_start := 0.72
var perfect_start := 0.92
var overheat_time := 0.22

var active := false
var meter := 0.0
var chain := 0
var misses := 0
var _full_timer := 0.0
var _cooldown := 0.0
## Most recent result for presentation (HUD, sounds).
var last_result: Result = Result.NONE
var last_perfect := false


func configure(stats: KartStats) -> void:
	charge_time = stats.drift_charge_time
	window_start = stats.drift_window_start
	perfect_start = stats.drift_perfect_start
	overheat_time = stats.drift_overheat_time


func start() -> void:
	active = true
	meter = 0.0
	chain = 0
	misses = 0
	_full_timer = 0.0
	_cooldown = 0.0
	last_result = Result.NONE


func stop() -> void:
	active = false
	meter = 0.0
	_full_timer = 0.0


func in_window() -> bool:
	return active and chain < MAX_CHAIN and _cooldown <= 0.0 and meter >= window_start


func in_perfect() -> bool:
	return in_window() and meter >= perfect_start


func can_charge() -> bool:
	return active and chain < MAX_CHAIN


## Returns Result.MISS when the meter overheats this tick.
func tick(delta: float) -> Result:
	if not can_charge():
		return Result.NONE
	if _cooldown > 0.0:
		_cooldown -= delta
		return Result.NONE
	meter = minf(meter + delta / charge_time, 1.0)
	if meter >= 1.0:
		_full_timer += delta
		if _full_timer >= overheat_time:
			_miss()
			return Result.MISS
	return Result.NONE


## Returns {result, tier, perfect}.
func press() -> Dictionary:
	if not can_charge() or _cooldown > 0.0:
		return {"result": Result.NONE, "tier": chain, "perfect": false}
	if meter >= window_start:
		chain += 1
		var perfect := meter >= perfect_start
		last_result = Result.BOOST
		last_perfect = perfect
		meter = 0.0
		_full_timer = 0.0
		return {"result": Result.BOOST, "tier": chain, "perfect": perfect}
	_miss()
	return {"result": Result.MISS, "tier": chain, "perfect": false}


func _miss() -> void:
	misses += 1
	meter = 0.0
	_full_timer = 0.0
	_cooldown = MISS_COOLDOWN
	last_result = Result.MISS
	last_perfect = false
