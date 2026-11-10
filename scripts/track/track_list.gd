class_name TrackList
extends RefCounted
## 0.11.0: every playable track (data/tracks/<id>.json) in menu order, with
## its name/description keys. Records, ghosts and trophies are per track id.

const IDS := ["seafront_sprint", "downtown_towers", "old_city", "karabakh"] # 0.13.0 old_city, 0.18.0 karabakh
const NAME_KEYS := {"seafront_sprint": "TRACK_SEAFRONT", "downtown_towers": "TRACK_DOWNTOWN", "old_city": "TRACK_OLDCITY", "karabakh": "TRACK_KARABAKH"}
const DESC_KEYS := {"seafront_sprint": "TRACK_SEAFRONT_DESC", "downtown_towers": "TRACK_DOWNTOWN_DESC", "old_city": "TRACK_OLDCITY_DESC", "karabakh": "TRACK_KARABAKH_DESC"}
## Lap time relative to the seafront lap (autopilot, 0.11.0 measurement);
## scales the daily "time" goal.
## 0.11.1: short city names for the big city cards.
const CITY_KEYS := {"seafront_sprint": "CITY_SEAFRONT", "downtown_towers": "TRACK_DOWNTOWN", "old_city": "TRACK_OLDCITY", "karabakh": "TRACK_KARABAKH"}
const LAP_SCALE := {"seafront_sprint": 1.0, "downtown_towers": 0.7, "old_city": 0.5, "karabakh": 3.4} # 0.13.0 autopilot lap ~26 s; 0.19.0 karabakh: one 4.9 km lap, autopilot 175 s vs 51 s

## 0.19.0: the most laps a race runs on a track (Qarabağ is one 4.9 km
## lap: ~3 minutes). Every mode goes through clamp_laps().
const MAX_LAPS := {"karabakh": 1}


static func max_laps(id: String) -> int:
	return int(MAX_LAPS.get(id, 5))


static func clamp_laps(id: String, laps: int) -> int:
	return clampi(laps, 1, max_laps(id))


static func is_valid(id: String) -> bool:
	return id in IDS


static func valid(id: String) -> String:
	return id if is_valid(id) else String(IDS[0])


static func name_key(id: String) -> String:
	return String(NAME_KEYS.get(id, NAME_KEYS[IDS[0]]))


static func desc_key(id: String) -> String:
	return String(DESC_KEYS.get(id, DESC_KEYS[IDS[0]]))


static func path(id: String) -> String:
	return "res://data/tracks/%s.json" % valid(id)


static func lap_scale(id: String) -> float:
	return float(LAP_SCALE.get(id, 1.0))


static func city_key(id: String) -> String:
	return String(CITY_KEYS.get(id, CITY_KEYS[IDS[0]]))
