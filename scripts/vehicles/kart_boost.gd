class_name KartBoost
extends RefCounted
## Boost stacking rules, identical for players and AI.
##
## - Each boost adds its duration to a bank capped at `max_stored` seconds.
## - The speed bonus is the strongest active source, never the sum, and is
##   capped at `max_bonus` above top speed. Speed therefore cannot grow
##   without bound no matter how boosts are chained.
## - cancel() empties the bank (hits, hard wall impacts, recovery).
## - Off-road surfaces keep the bank but halve the bonus (see KartController).

signal started(source: StringName)
signal ended

var max_stored := 2.6
var max_bonus := 10.0
var time_left := 0.0
var bonus := 0.0
var last_source: StringName = &""


func configure(stats: KartStats) -> void:
	max_stored = stats.boost_max_stored
	max_bonus = stats.boost_max_bonus


func add(strength: float, duration: float, source: StringName) -> void:
	if duration <= 0.0 or strength <= 0.0:
		return
	var was_active := is_active()
	time_left = minf(time_left + duration, max_stored)
	bonus = minf(maxf(bonus, strength), max_bonus)
	last_source = source
	if not was_active:
		started.emit(source)


func tick(delta: float) -> void:
	if time_left <= 0.0:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		bonus = 0.0
		ended.emit()


func cancel() -> void:
	if time_left > 0.0:
		time_left = 0.0
		bonus = 0.0
		ended.emit()


func is_active() -> bool:
	return time_left > 0.0


## Speed bonus currently applied on top of the kart's (surface-adjusted) cap.
func effective_bonus(offroad: bool) -> float:
	if not is_active():
		return 0.0
	return bonus * (0.5 if offroad else 1.0)
