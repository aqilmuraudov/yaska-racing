class_name CityCards
extends RefCounted
## 0.11.1: shared bits for the "choose a city" step — thumbnails, track
## length, "played once" (for the Yeni! badge), per-city trophies and a small
## thumbnail + name chip used on kart select and the daily card.

const THUMB_DIR := "res://assets/ui/cities/"
const PLAYED_KEY := "played_tracks"

static var _len_cache := {}


static func thumb(id: String) -> Texture2D:
	var p := THUMB_DIR + TrackList.valid(id) + ".jpg"
	return load(p) if ResourceLoader.exists(p) else null


static func track_data(id: String) -> TrackData:
	return TrackData.load_from_file(TrackList.path(id))


## Lap length in metres (main path), cached.
static func length_m(id: String) -> float:
	id = TrackList.valid(id)
	if not _len_cache.has(id):
		var td := track_data(id)
		_len_cache[id] = td.main.length if td and td.main else 0.0
	return float(_len_cache[id])


## "1,1 km" (Azerbaijani decimal comma).
static func length_text(id: String) -> String:
	return ("%.1f km" % (length_m(id) / 1000.0)).replace(".", ",")


static func is_played(data: Dictionary, id: String) -> bool:
	if id in data.get(PLAYED_KEY, []):
		return true
	if not data.get("records", {}).get(id, {}).is_empty():
		return true
	var ts: Dictionary = data.get("track_stats", {})
	return int(ts.get(id + ":quick_finish", 0)) > 0 or int(ts.get(id + ":tt_finish", 0)) > 0


## Shows the "Yeni!" badge on every city but the first until it is raced.
static func is_new(data: Dictionary, id: String) -> bool:
	return id != TrackList.IDS[0] and not is_played(data, id)


static func mark_played(data: Dictionary, id: String) -> bool:
	if not TrackList.is_valid(id):
		return false
	var arr: Array = data.get(PLAYED_KEY, [])
	if id in arr:
		return false
	arr.append(id)
	data[PLAYED_KEY] = arr
	return true


## Vector2i(won, total) for the trophies tied to one city.
static func trophies(data: Dictionary, id: String) -> Vector2i:
	var won: Array = data.get("trophies", [])
	var r := Vector2i.ZERO
	for t in Progression.trophies():
		if String(t.get("track", "")) == id:
			r.y += 1
			if String(t.id) in won:
				r.x += 1
	return r


static func best_lap_text(data: Dictionary, id: String) -> String:
	var rec: Dictionary = data.get("records", {}).get(id, {})
	return RaceHUD.format_time(float(rec.best_lap_ms) / 1000.0) if rec.has("best_lap_ms") else ""


## Rounded thumbnail + city name, e.g. on kart select ("which city loads").
static func mini_chip(id: String, h := 56.0, font := 24) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "CityChip"
	p.add_theme_stylebox_override("panel", UITheme.rounded(Color(UITheme.INK, 0.72), 18, 3, Color(UITheme.GOLD, 0.8), 5))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var tr_ := TextureRect.new()
	tr_.name = "Thumb"
	tr_.texture = thumb(id)
	tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr_.custom_minimum_size = Vector2(h * 1.6, h)
	tr_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tr_)
	var l := GameUI.label(TranslationServer.translate(TrackList.city_key(id)), font, UITheme.GOLD, 6)
	l.name = "Name"
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	p.set_meta("value", l)
	return p
