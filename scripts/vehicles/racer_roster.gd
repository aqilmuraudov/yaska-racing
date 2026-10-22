class_name RacerRoster
extends RefCounted
## The six racer packages in display order (data/racers/*.tres).

const IDS := ["posi", "bicok", "leloyun", "mestan", "havhav", "cepis"]
const DEFAULT_ID := "havhav"

static var _cache := {}


static func get_def(id: String) -> RacerDefinition:
	if not IDS.has(id):
		id = DEFAULT_ID
	if not _cache.has(id):
		_cache[id] = load("res://data/racers/%s.tres" % id)
	return _cache[id]


static func all() -> Array[RacerDefinition]:
	var out: Array[RacerDefinition] = []
	for id in IDS:
		out.append(get_def(id))
	return out


static func is_valid(id: String) -> bool:
	return IDS.has(id)


## AI opponents: every other racer first (shuffled by seed), then repeats.
static func opponents(player_id: String, count: int, seed_value: int) -> Array[String]:
	var pool: Array[String] = []
	for id in IDS:
		if id != player_id:
			pool.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array[String] = []
	for i in count:
		out.append(pool[i % pool.size()])
	return out
