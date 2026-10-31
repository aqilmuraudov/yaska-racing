class_name RivalStrip
extends HBoxContainer
## 0.13.0: who is just ahead of and just behind the player, as pictures
## (racer portraits with a green ▲ / red ▼ marker) instead of names - small
## children recognise the animals, not the text. Hidden outside quick races
## and in the results.

const PX := 48.0
const REFRESH := 0.25

var race: RaceManager
var ahead_id := ""
var behind_id := ""
var _timer := 0.0
var _ahead: Control
var _behind: Control


func setup(p_race: RaceManager) -> void:
	race = p_race
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	_ahead = _slot(true)
	_behind = _slot(false)
	add_child(_ahead)
	add_child(_behind)
	refresh()


func _slot(up: bool) -> Control:
	var box := Control.new()
	box.name = "Ahead" if up else "Behind"
	box.custom_minimum_size = Vector2(PX + 8, PX + 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := Label.new()
	mark.name = "Mark"
	mark.text = "▲" if up else "▼"
	mark.add_theme_font_size_override("font_size", 22)
	mark.add_theme_color_override("font_color", Color("5cf08a") if up else Color("ff7070"))
	mark.add_theme_color_override("font_outline_color", UITheme.INK)
	mark.add_theme_constant_override("outline_size", 8)
	mark.position = Vector2(PX - 12, PX - 22)
	mark.z_index = 1
	box.add_child(mark)
	return box


## The racers right before/after the player in the current order ("" = none).
static func neighbours(racers: Array, player_place: int) -> Array:
	var ahead := ""
	var behind := ""
	for r in racers:
		if int(r.place) == player_place - 1:
			ahead = String(r.kart.stats.id)
		elif int(r.place) == player_place + 1:
			behind = String(r.kart.stats.id)
	return [ahead, behind]


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		refresh()


func refresh() -> void:
	if race == null or race.player == null:
		return
	var n := neighbours(race.racers, race.player.place)
	_set_portrait(_ahead, String(n[0]), true)
	_set_portrait(_behind, String(n[1]), false)


func _set_portrait(slot: Control, id: String, up: bool) -> void:
	if up and id == ahead_id and slot.has_node("Portrait") == (id != ""):
		return
	if not up and id == behind_id and slot.has_node("Portrait") == (id != ""):
		return
	if up:
		ahead_id = id
	else:
		behind_id = id
	var old := slot.get_node_or_null("Portrait")
	if old:
		slot.remove_child(old)
		old.queue_free()
	slot.visible = id != ""
	if id == "":
		return
	var p := GameUI.portrait(id, PX, Color("5cf08a") if up else Color("ff7070"))
	p.name = "Portrait"
	p.position = Vector2(0, 4)
	slot.add_child(p)
	slot.move_child(p, 0)
	# Little pop so a change of rival is noticed.
	p.pivot_offset = Vector2(PX, PX) * 0.5
	p.scale = Vector2.ONE * 1.25
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.2)
