class_name TrackList
extends RefCounted
## 0.11.0: every playable track (data/tracks/<id>.json) in menu order, with
## its name/description keys. Records, ghosts and trophies are per track id.

const IDS := ["seafront_sprint", "downtown_towers", "old_city", "karabakh", "karabakh_shusha", "karabakh_lachin", "karabakh_khankendi"] # 0.13.0 old_city, 0.18.0 karabakh, 0.20.1 Şuşa, Laçın, 0.20.2 Xankəndi
const NAME_KEYS := {"seafront_sprint": "TRACK_SEAFRONT", "downtown_towers": "TRACK_DOWNTOWN", "old_city": "TRACK_OLDCITY", "karabakh": "TRACK_KARABAKH", "karabakh_shusha": "TRACK_KB_SHUSHA", "karabakh_lachin": "TRACK_KB_LACHIN", "karabakh_khankendi": "TRACK_KB_KHANKENDI"}
const DESC_KEYS := {"seafront_sprint": "TRACK_SEAFRONT_DESC", "downtown_towers": "TRACK_DOWNTOWN_DESC", "old_city": "TRACK_OLDCITY_DESC", "karabakh": "TRACK_KARABAKH_DESC", "karabakh_shusha": "TRACK_KB_SHUSHA_DESC", "karabakh_lachin": "TRACK_KB_LACHIN_DESC", "karabakh_khankendi": "TRACK_KB_KHANKENDI_DESC"}
## Lap time relative to the seafront lap (autopilot, 0.11.0 measurement);
## scales the daily "time" goal.
## 0.11.1: short city names for the big city cards.
const CITY_KEYS := {"seafront_sprint": "CITY_SEAFRONT", "downtown_towers": "TRACK_DOWNTOWN", "old_city": "TRACK_OLDCITY", "karabakh": "MAP_KB_GRAND", "karabakh_shusha": "TRACK_KB_SHUSHA", "karabakh_lachin": "TRACK_KB_LACHIN", "karabakh_khankendi": "TRACK_KB_KHANKENDI"}
const LAP_SCALE := {"seafront_sprint": 1.0, "downtown_towers": 0.7, "old_city": 0.5, "karabakh": 3.4, "karabakh_shusha": 1.03, "karabakh_lachin": 1.12, "karabakh_khankendi": 1.19} # 0.13.0 autopilot lap ~26 s; 0.19.0 karabakh: one 4.9 km lap, autopilot 175 s vs 51 s; 0.20.1 Şuşa 52.6 s, Laçın 56.9 s; 0.20.2 Xankəndi 60.5 s

## 0.19.0: the most laps a race runs on a track (Qarabağ is one 4.9 km
## lap: ~3 minutes). Every mode goes through clamp_laps().
const MAX_LAPS := {"karabakh": 1}


static func max_laps(id: String) -> int:
	return int(MAX_LAPS.get(id, 5))


static func clamp_laps(id: String, laps: int) -> int:
	return clampi(laps, 1, max_laps(id))

## 0.20.0 (owner 2026-11-11): two-step choice - the city (region) first, then
## its maps. Bakı has three maps, Qarabağ the big map (its own short maps later).
const REGIONS := ["baku", "karabakh"]
const REGION_TRACKS := {"baku": ["seafront_sprint", "downtown_towers", "old_city"], "karabakh": ["karabakh", "karabakh_khankendi", "karabakh_shusha", "karabakh_lachin"]}
const REGION_KEYS := {"baku": "REGION_BAKU", "karabakh": "REGION_KARABAKH"}


static func region_of(id: String) -> String:
	for r in REGIONS:
		if id in REGION_TRACKS[r]:
			return String(r)
	return String(REGIONS[0])


static func region_tracks(region: String) -> Array:
	return REGION_TRACKS.get(region, REGION_TRACKS[REGIONS[0]])


static func region_key(region: String) -> String:
	return String(REGION_KEYS.get(region, REGION_KEYS[REGIONS[0]]))


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
