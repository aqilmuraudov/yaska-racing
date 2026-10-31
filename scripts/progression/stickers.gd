class_name Stickers
extends RefCounted
## 0.13.0 Baku sticker album: 12 free stickers of the city's landmarks (the
## game's own 3D models, tools/gen_stickers.*). A sticker is unlocked by the
## player's total collected stars - nothing to buy, nothing random. The only
## saved value is how many the player has already seen ("Yeni!" badge).

const LIST := [
	{"id": "flame_towers", "stars": 3},
	{"id": "maiden_tower", "stars": 8},
	{"id": "baku_eye", "stars": 15},
	{"id": "heydar_aliyev", "stars": 25},
	{"id": "palm", "stars": 40},
	{"id": "boat", "stars": 55},
	{"id": "flag_square", "stars": 75},
	{"id": "fountain", "stars": 100},
	{"id": "crescent", "stars": 130},
	{"id": "qosa_qala", "stars": 165},
	{"id": "government_house", "stars": 205},
	{"id": "carpet_museum", "stars": 250},
]
const DIR := "res://assets/stickers/"
const SEEN_KEY := "stickers_seen"


static func name_key(id: String) -> String:
	return "STK_" + id.to_upper()


static func texture(id: String, locked := false) -> Texture2D:
	var p := DIR + id + ("_locked" if locked else "") + ".png"
	return load(p) if ResourceLoader.exists(p) else null


static func unlocked_count(stars: int) -> int:
	var n := 0
	for s in LIST:
		if stars >= int(s.stars):
			n += 1
	return n


static func is_unlocked(index: int, stars: int) -> bool:
	return stars >= int(LIST[index].stars)


## Stickers that became available between two star totals (results cards).
static func unlocked_between(before: int, after: int) -> Array:
	var out: Array = []
	for s in LIST:
		if before < int(s.stars) and after >= int(s.stars):
			out.append(String(s.id))
	return out


## Stars still needed for the next sticker (0 when all are open).
static func next_goal(stars: int) -> int:
	for s in LIST:
		if stars < int(s.stars):
			return int(s.stars)
	return 0


static func new_count(data: Dictionary, stars: int) -> int:
	return maxi(unlocked_count(stars) - int(data.get(SEEN_KEY, 0)), 0)


static func mark_seen(data: Dictionary, stars: int) -> void:
	data[SEEN_KEY] = unlocked_count(stars)
