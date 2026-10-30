class_name DailyLogin
extends RefCounted
## 7-day login bonus (0.9.0). The first open of each local day offers the
## next day of the strip; missing a whole day restarts at day 1. Lenient:
## days are compared as local calendar dates (noon based, so DST / timezone
## shifts never skip or repeat a day) and a clock set backwards never
## resets the streak or pays twice.

## Day 1..7 rewards in qəpik. Day 7 is the big prize.
const REWARDS := [50, 70, 90, 110, 130, 160, 400]
## Hook for a future rewarded ad ("double it"); hidden while false.
const AD_DOUBLE_ENABLED := false


static func day_number(date: String) -> int:
	if date.length() < 10:
		return -1
	return int(round(Time.get_unix_time_from_datetime_string(date.substr(0, 10) + "T12:00:00") / 86400.0))


## {"day": 1..7 (the day to claim, or the one claimed today), "can_claim"}
static func status(data: Dictionary, today: String) -> Dictionary:
	var lg: Dictionary = data.get("login", {})
	var last := String(lg.get("last", ""))
	var streak := int(lg.get("streak", 0))
	if last == "":
		return {"day": 1, "can_claim": true}
	var gap := day_number(today) - day_number(last)
	if gap <= 0:
		return {"day": clampi(streak, 1, 7), "can_claim": false}
	if gap == 1:
		return {"day": streak % 7 + 1, "can_claim": true}
	return {"day": 1, "can_claim": true} # a day was missed


static func reward(day: int) -> int:
	return int(REWARDS[clampi(day, 1, 7) - 1])


## Claims today's bonus once. Returns the qəpik paid (0 if not claimable).
static func claim(data: Dictionary, today: String) -> int:
	var st := status(data, today)
	if not st.can_claim:
		return 0
	var amount := reward(int(st.day))
	data.login = {"last": today, "streak": int(st.day)}
	data.currency = int(data.get("currency", 0)) + amount
	if typeof(data.get("lifetime")) == TYPE_DICTIONARY:
		data.lifetime.coins = int(data.lifetime.get("coins", 0)) + amount
	return amount
