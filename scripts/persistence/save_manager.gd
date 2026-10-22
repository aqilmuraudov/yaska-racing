extends Node
## Offline player profile: selections, currency, unlocks, records and the
## reward ledger. Saved as versioned JSON through SafeFile.

signal profile_changed

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://profile.json"
const LEDGER_LIMIT := 200

var save_path := DEFAULT_PATH
var data: Dictionary = {}
var last_load_source := "none"


func _ready() -> void:
	load_profile()


static func default_profile() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"profile_name": "Player",
		"currency": 0,
		"selected_kart": RacerRoster.DEFAULT_ID,
		"paints": {},
		"unlocks": [],
		"reward_ledger": [],
		"records": {},
		"ghosts": {},
		"tutorial": {"drift_done": false},
		"cup_progress": {},
		"stats": {"races": 0, "wins": 0, "podiums": 0},
	}


func load_profile() -> void:
	var result := SafeFile.read_json(save_path, _validate)
	last_load_source = result.source
	data = default_profile()
	if result.source != "none":
		_merge_into(data, _migrate(result.data))
	if result.source == "backup":
		push_warning("SaveManager: primary profile unusable, restored from backup")
		save_profile()
	profile_changed.emit()


func save_profile() -> bool:
	data.version = SAVE_VERSION
	return SafeFile.write_json(save_path, data)


func reset_profile() -> void:
	SafeFile.delete_all(save_path)
	data = default_profile()
	save_profile()
	profile_changed.emit()


func _validate(d: Dictionary) -> bool:
	if not d.has("version") or typeof(d.version) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if int(d.version) > SAVE_VERSION:
		return false # written by a newer build; never downgrade it silently
	if d.has("currency") and typeof(d.currency) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if d.has("records") and typeof(d.records) != TYPE_DICTIONARY:
		return false
	return true


func _migrate(d: Dictionary) -> Dictionary:
	# Version 1 is the first format. Future migrations chain here:
	# if int(d.version) < 2: d = _migrate_1_to_2(d)
	return d


## Copies keys from `src` into `dst`, keeping defaults for missing keys and
## refusing values whose type does not match the default.
func _merge_into(dst: Dictionary, src: Dictionary) -> void:
	for key in src.keys():
		if not dst.has(key):
			continue
		var dv = dst[key]
		var sv = src[key]
		if typeof(dv) == TYPE_DICTIONARY and typeof(sv) == TYPE_DICTIONARY:
			if dv.is_empty():
				dst[key] = sv
			else:
				_merge_into(dv, sv)
		elif typeof(dv) == typeof(sv) or (typeof(dv) in [TYPE_INT, TYPE_FLOAT] and typeof(sv) in [TYPE_INT, TYPE_FLOAT]):
			dst[key] = int(sv) if typeof(dv) == TYPE_INT else sv


# --- Selections -----------------------------------------------------------

## Last selected racer package (animal + its kart). Ids from the first
## version (balanced/agile/fast) map to the default racer.
func get_selected_kart() -> String:
	var id := String(data.selected_kart)
	return id if RacerRoster.is_valid(id) else RacerRoster.DEFAULT_ID


func set_selected_kart(racer_id: String, _paint_index: int = 0) -> void:
	data.selected_kart = racer_id
	save_profile()


func get_paint(kart_id: String) -> int:
	return int(data.paints.get(kart_id, 0))


# --- Records --------------------------------------------------------------

func get_record(track_id: String) -> Dictionary:
	return data.records.get(track_id, {})


## Stores best lap / best race times (milliseconds). Returns which improved.
func submit_times(track_id: String, race_ms: int, best_lap_ms: int, kart_id: String, laps: int) -> Dictionary:
	var rec: Dictionary = data.records.get(track_id, {})
	var improved := {"lap": false, "race": false}
	if best_lap_ms > 0 and (not rec.has("best_lap_ms") or best_lap_ms < int(rec.best_lap_ms)):
		rec.best_lap_ms = best_lap_ms
		rec.best_lap_kart = kart_id
		improved.lap = true
	# Race totals are only comparable at the same lap count.
	var race_key := "best_race_ms_%d" % laps
	if race_ms > 0 and (not rec.has(race_key) or race_ms < int(rec[race_key])):
		rec[race_key] = race_ms
		rec.best_race_kart = kart_id
		improved.race = true
	data.records[track_id] = rec
	return improved


# --- Rewards --------------------------------------------------------------

func has_rewarded(event_instance_id: String) -> bool:
	return event_instance_id in data.reward_ledger


## Applies a reward exactly once per event instance. Returns the amount
## actually granted (0 when this instance was already rewarded).
func grant_reward(event_instance_id: String, amount: int) -> int:
	if event_instance_id.is_empty() or has_rewarded(event_instance_id):
		return 0
	data.reward_ledger.append(event_instance_id)
	while data.reward_ledger.size() > LEDGER_LIMIT:
		data.reward_ledger.pop_front()
	data.currency = int(data.currency) + maxi(amount, 0)
	return amount


func record_race_stats(placement: int) -> void:
	data.stats.races = int(data.stats.races) + 1
	if placement == 1:
		data.stats.wins = int(data.stats.wins) + 1
	if placement >= 1 and placement <= 3:
		data.stats.podiums = int(data.stats.podiums) + 1


func set_tutorial_flag(flag: String, value: bool) -> void:
	data.tutorial[flag] = value
	save_profile()


func get_tutorial_flag(flag: String) -> bool:
	return bool(data.tutorial.get(flag, false))
