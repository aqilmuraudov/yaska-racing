extends Node
## Offline player profile: selections, currency, unlocks, records and the
## reward ledger. Saved as versioned JSON through SafeFile.

signal profile_changed

const SAVE_VERSION := 7
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
		"currency": 0, ## qəpik (1 ₼ = 100 qəpik) since v3; see Money
		"tuning": {}, ## kart id -> KartTuning levels
		"bought_paints": {}, ## kart id -> paint indices bought with manat
		"ad_claims": [], ## event ids whose rewarded-ad bonus was claimed
		"stars": 0, ## collected on the track, unlock kart paints (KartPaints)
		"selected_kart": RacerRoster.DEFAULT_ID,
		## Karts the player owns (0.8.3, save v4). A fresh profile starts
		## with the standard kart; older saves own every kart. Nothing is
		## locked by this yet; kart buying will use it.
		"owned_karts": [RacerRoster.DEFAULT_ID],
		"login": {}, ## DailyLogin: {"last": "YYYY-MM-DD", "streak": 1..7}
		"race_goals": [], ## RaceGoals for the next quick race
		"paints": {},
		"unlocks": [],
		"reward_ledger": [],
		"records": {},
		"ghosts": {},
		# 0.14.3: every tutorial flag must have a default here - _merge_into only
		# keeps known keys, so "lesson_done" was dropped on each load (owner: the
		# lesson opened on every start since 0.13.0).
		"tutorial": {"drift_done": false, "lesson_done": false},
		"cup_progress": {}, ## BakuCup state (0.10.0), {} when no cup runs
		"cup_history": {}, ## {"played", "won", "best"} finished cups
		"daily_challenge": {}, ## {"done": "YYYY-MM-DD", "count"}
		"stats": {"races": 0, "wins": 0, "podiums": 0},
	}.merged(Progression.default_state())


func load_profile() -> void:
	var result := SafeFile.read_json(save_path, _validate)
	last_load_source = result.source
	data = default_profile()
	if result.source != "none":
		_merge_into(data, _migrate(result.data))
		Progression.seed_from_old(data) # v1 saves: lifetime counters from totals
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
	if d.has("stars") and typeof(d.stars) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if d.has("records") and typeof(d.records) != TYPE_DICTIONARY:
		return false
	return true


func _migrate(d: Dictionary) -> Dictionary:
	# v1 → v2 (0.7.0): progression keys (lifetime, trophies, daily, parts)
	# are added with defaults by _merge_into; the lifetime counters are seeded
	# from the old totals in load_profile. Nothing is removed or renamed.
	# v2 → v3 (0.8.0): coins become manat. Amounts are stored in qəpik; one
	# old coin is worth Money.COINS_TO_QEPIK qəpik (balance and the lifetime
	# total that unlocks kart parts are converted alike).
	if int(d.get("version", 1)) < 3:
		if typeof(d.get("currency")) in [TYPE_INT, TYPE_FLOAT]:
			d.currency = Money.from_old_coins(int(d.currency))
		if typeof(d.get("lifetime")) == TYPE_DICTIONARY and typeof(d.lifetime.get("coins")) in [TYPE_INT, TYPE_FLOAT]:
			d.lifetime.coins = Money.from_old_coins(int(d.lifetime.coins))
		d.version = 3
	# v3 → v4 (0.8.3): owned_karts. Players from older builds keep every kart.
	if int(d.get("version", 1)) < 4:
		d.owned_karts = RacerRoster.IDS.duplicate()
		d.version = 4
	# v4 → v5 (0.10.0): cup / daily challenge state. New keys get defaults;
	# a cup_progress that is not a valid BakuCup state is dropped.
	if int(d.get("version", 1)) < 5:
		if d.has("cup_progress"):
			d.cup_progress = BakuCup.sanitize(d.cup_progress)
		d.version = 5
	# v5 → v6 (0.14.2): the v4 migration gave old profiles every kart for free,
	# so any kart could be raced without buying it. Owner's rule: one kart to
	# start, the rest bought with manat in the garage. A profile owning (nearly)
	# the whole roster keeps the starter kart and the one it races with.
	if int(d.get("version", 1)) < 6:
		var owned: Array = d.get("owned_karts", []) if typeof(d.get("owned_karts")) == TYPE_ARRAY else []
		if owned.size() >= RacerRoster.IDS.size() - 1:
			var keep: Array = [RacerRoster.DEFAULT_ID]
			var sel := String(d.get("selected_kart", RacerRoster.DEFAULT_ID))
			if RacerRoster.is_valid(sel) and not (sel in keep):
				keep.append(sel)
			d.owned_karts = keep
		d.version = 6
	# v6 → v7 (0.14.3): "lesson_done" never survived a reload (see the default
	# above), so players who already raced saw the lesson again and again.
	# Anyone with a finished race has seen it: mark it done.
	if int(d.get("version", 1)) < 7:
		var races := 0
		if typeof(d.get("stats")) == TYPE_DICTIONARY:
			races = int(d.stats.get("races", 0))
		if typeof(d.get("tutorial")) != TYPE_DICTIONARY:
			d.tutorial = {}
		if races > 0:
			d.tutorial["lesson_done"] = true
		d.version = 7
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


# --- Owned karts ----------------------------------------------------------

func owned_karts() -> Array:
	var out: Array = []
	for id in data.get("owned_karts", []):
		if RacerRoster.is_valid(String(id)) and not (String(id) in out):
			out.append(String(id))
	if not (RacerRoster.DEFAULT_ID in out):
		out.push_front(RacerRoster.DEFAULT_ID)
	return out


func is_kart_owned(racer_id: String) -> bool:
	return racer_id in owned_karts()


## Buys a kart with manat: "ok", "owned", "funds" or "invalid".
func buy_kart(racer_id: String) -> String:
	if not RacerRoster.is_valid(racer_id):
		return "invalid"
	if is_kart_owned(racer_id):
		return "owned"
	var cost := KartShop.price(racer_id)
	if get_money() < cost:
		return "funds"
	data.currency = get_money() - cost
	own_kart(racer_id)
	profile_changed.emit()
	return "ok"


## Adds money (qəpik) earned outside a race payout (login bonus, goals).
func add_money(amount: int) -> void:
	data.currency = get_money() + maxi(amount, 0)
	if typeof(data.get("lifetime")) == TYPE_DICTIONARY:
		data.lifetime.coins = int(data.lifetime.get("coins", 0)) + maxi(amount, 0)


## Adds a kart to the owned list (no payment; buy_kart charges).
func own_kart(racer_id: String) -> bool:
	if not RacerRoster.is_valid(racer_id) or is_kart_owned(racer_id):
		return false
	data.owned_karts = owned_karts()
	data.owned_karts.append(racer_id)
	save_profile()
	return true


# --- Selections -----------------------------------------------------------

## Last selected racer package (animal + its kart). Ids from the first
## version (balanced/agile/fast) map to the default racer.
func get_selected_kart() -> String:
	var id := String(data.selected_kart)
	return id if RacerRoster.is_valid(id) and is_kart_owned(id) else RacerRoster.DEFAULT_ID


func set_selected_kart(racer_id: String, _paint_index: int = 0) -> void:
	data.selected_kart = racer_id
	save_profile()


func get_paint(kart_id: String) -> int:
	var p := int(data.paints.get(kart_id, 0))
	return p if is_paint_unlocked(kart_id, p) else 0


## Unlocked by stars (all karts) or bought for this kart in the garage.
func is_paint_unlocked(kart_id: String, index: int) -> bool:
	if KartPaints.is_unlocked(index, get_stars()):
		return true
	return index in data.get("bought_paints", {}).get(kart_id, [])


func set_paint(kart_id: String, index: int) -> void:
	if not is_paint_unlocked(kart_id, index):
		return
	data.paints[kart_id] = index
	save_profile()


func get_stars() -> int:
	return int(data.get("stars", 0))


## Adds the stars collected in one race exactly once (same ledger as rewards,
## separate key). Returns the number actually added.
func add_stars(event_instance_id: String, count: int) -> int:
	var key := "stars:" + event_instance_id
	if event_instance_id.is_empty() or count <= 0 or has_rewarded(key):
		return 0
	data.reward_ledger.append(key)
	while data.reward_ledger.size() > LEDGER_LIMIT:
		data.reward_ledger.pop_front()
	data.stars = get_stars() + count
	save_profile()
	return count


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


## Progression for one event, exactly once (ledger key "prog:<id>").
## Returns {"coins", "unlocks"} (empty when already applied).
func apply_progression(event_instance_id: String, ev: Dictionary) -> Dictionary:
	var key := "prog:" + event_instance_id
	if event_instance_id.is_empty() or has_rewarded(key):
		return {"coins": 0, "unlocks": []}
	data.reward_ledger.append(key)
	while data.reward_ledger.size() > LEDGER_LIMIT:
		data.reward_ledger.pop_front()
	var out := Progression.on_event(data, ev)
	save_profile()
	return out


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


# --- Money & garage (0.8.0) ---------------------------------------------------

## Balance in qəpik.
func get_money() -> int:
	return int(data.get("currency", 0))


func tuning_levels(kart_id: String) -> Dictionary:
	var out := KartTuning.empty()
	if not is_kart_owned(kart_id):
		return out # tuning applies to owned karts only
	var saved: Dictionary = data.tuning.get(kart_id, {})
	for k in out.keys():
		out[k] = clampi(int(saved.get(k, 0)), 0, KartTuning.max_for(k))
	return out


## Buys the next level of `cat` for a kart. Returns true when bought.
func buy_upgrade(kart_id: String, cat: String) -> bool:
	if not is_kart_owned(kart_id):
		return false
	var lv := tuning_levels(kart_id)
	if not lv.has(cat):
		return false
	var cost := KartTuning.next_cost(cat, int(lv[cat]))
	if cost < 0 or get_money() < cost:
		return false
	data.currency = get_money() - cost
	lv[cat] = int(lv[cat]) + 1
	data.tuning[kart_id] = lv
	save_profile()
	profile_changed.emit()
	return true


func buy_paint(kart_id: String, index: int) -> bool:
	if is_paint_unlocked(kart_id, index) or index < 0 or index >= KartPaints.count():
		return false
	if get_money() < KartTuning.PAINT_COST:
		return false
	data.currency = get_money() - KartTuning.PAINT_COST
	var arr: Array = data.bought_paints.get(kart_id, [])
	arr.append(index)
	data.bought_paints[kart_id] = arr
	data.paints[kart_id] = index
	save_profile()
	profile_changed.emit()
	return true


## Rewarded-ad hook: grants `amount` qəpik once per race event (the caller
## passes the race's earnings × (Economy.AD_MULTIPLIER - 1)). Returns the
## amount granted, 0 when already claimed.
func claim_ad_bonus(event_instance_id: String, amount: int) -> int:
	if event_instance_id.is_empty() or amount <= 0 or event_instance_id in data.ad_claims:
		return 0
	data.ad_claims.append(event_instance_id)
	while data.ad_claims.size() > LEDGER_LIMIT:
		data.ad_claims.pop_front()
	data.currency = get_money() + amount
	data.lifetime.coins = int(data.lifetime.get("coins", 0)) + amount
	save_profile()
	profile_changed.emit()
	return amount
