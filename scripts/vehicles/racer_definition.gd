class_name RacerDefinition
extends Resource
## One selectable racer package: animal driver + its unique kart + handling.
## Single source of truth for the selection UI (name, colours, stat bars,
## speciality) and for the simulation (KartStats built via RacerTuning).

@export var id := "havhav"
@export var display_name := "HavHav" ## Proper name, shown as-is in every language
@export var kart_name := "Buddy Rally"
@export_enum("panda", "fox", "rabbit", "cat", "dog", "lamb", "girl") var species := "dog"
@export var kart_style := "buddy" ## bamboo | amber | hop | velvet | buddy | cloud | star
@export var personality_key := ""
@export var specialty_key := ""

@export_group("Colours")
@export var accent := Color("2f74c9") ## UI theme colour for this racer
@export var kart_primary := Color("2f74c9")
@export var kart_secondary := Color("ffc93c")
@export var kart_trim := Color("1b2a4a")
@export var fur_main := Color("a0683a")
@export var fur_light := Color("f3e2c4")
@export var fur_dark := Color("4a2c1a")
@export var detail := Color("e0344b") ## accessory / inner-ear colour

@export_group("Ratings (1-10)")
@export_range(1, 10) var top_speed := 7
@export_range(1, 10) var acceleration := 7
@export_range(1, 10) var handling := 7
@export_range(1, 10) var drift := 7
@export_range(1, 10) var boost := 7

var _stats_cache: KartStats


func ratings() -> Dictionary:
	return {"top_speed": top_speed, "acceleration": acceleration, "handling": handling, "drift": drift, "boost": boost}


## Handling parameters derived from the ratings (cached; same object for the
## UI preview and the race).
func make_stats() -> KartStats:
	if _stats_cache == null:
		_stats_cache = RacerTuning.build_stats(self)
	return _stats_cache
