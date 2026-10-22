extends MenuScreen
## Race setup: track card with records and layout preview, plus the rules
## that apply to the chosen mode.

const TRACKS := ["seafront_sprint"]
const DIFFS := ["easy", "medium", "hard"]

var start_btn: Button
var diff_sel: OptionSelector
var laps_sel: OptionSelector
var ai_sel: OptionSelector
var items_sel: OptionSelector
var record_label: Label


func _init() -> void:
	back_state = Game.State.KART_SELECT
	screen_title_key = "TRACK_TITLE"


func build() -> void:
	stage.show_racer(String(Game.race_config.kart_id))
	stage.set_camera_offset(2.6)
	var mode: String = Game.race_config.mode
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(row)
	# Track card
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(470, 0)
	row.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	var td := TrackData.load_from_file("res://data/tracks/%s.json" % TRACKS[0])
	var tname := Label.new()
	tname.text = tr(td.name_key)
	tname.theme_type_variation = &"Heading"
	tname.add_theme_font_size_override("font_size", 34)
	tname.add_theme_color_override("font_color", UITheme.GOLD)
	tname.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(tname)
	var preview := TrackPreview.new()
	preview.custom_minimum_size = Vector2(430, 220)
	preview.track = td
	cv.add_child(preview)
	var desc := Label.new()
	desc.text = tr("TRACK_SEAFRONT_DESC")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 20)
	cv.add_child(desc)
	record_label = Label.new()
	record_label.theme_type_variation = &"Dim"
	record_label.add_theme_font_size_override("font_size", 20)
	cv.add_child(record_label)
	# Options
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 12)
	ov.custom_minimum_size = Vector2(560, 0)
	row.add_child(ov)
	var cfg: Dictionary = Game.race_config
	if mode == "quick":
		diff_sel = OptionSelector.new().setup(tr("OPT_DIFFICULTY"), [tr("DIFF_EASY"), tr("DIFF_MEDIUM"), tr("DIFF_HARD")], DIFFS.find(String(Settings.get_value("gameplay", "difficulty", "medium"))))
		ov.add_child(diff_sel)
	laps_sel = OptionSelector.new().setup(tr("OPT_LAPS"), ["1", "2", "3", "4", "5"], clampi(int(cfg.get("laps", 3)), 1, 5) - 1)
	laps_sel.value_changed.connect(func(_i): _update_records())
	ov.add_child(laps_sel)
	if mode == "quick":
		var ai_opts := []
		for i in range(1, 8):
			ai_opts.append(str(i))
		ai_sel = OptionSelector.new().setup(tr("OPT_OPPONENTS"), ai_opts, clampi(int(cfg.get("ai_count", 5)), 1, 7) - 1)
		ov.add_child(ai_sel)
		items_sel = OptionSelector.new().setup(tr("OPT_ITEMS"), [tr("OPT_ON"), tr("OPT_OFF")], 0 if bool(cfg.get("items", true)) else 1)
		ov.add_child(items_sel)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ov.add_child(sp)
	start_btn = make_button(tr("MENU_START_RACE"), _start, true)
	start_btn.custom_minimum_size = Vector2(560, 84)
	ov.add_child(start_btn)
	_update_records()


func _update_records() -> void:
	var rec := SaveManager.get_record(TRACKS[0])
	var laps := laps_sel.index + 1
	var lines: Array[String] = []
	if rec.has("best_lap_ms"):
		lines.append("%s: %s" % [tr("BEST_LAP"), RaceHUD.format_time(float(rec.best_lap_ms) / 1000.0)])
	var key := "best_race_ms_%d" % laps
	if rec.has(key):
		lines.append("%s (%d): %s" % [tr("BEST_RACE"), laps, RaceHUD.format_time(float(rec[key]) / 1000.0)])
	record_label.text = "\n".join(lines) if not lines.is_empty() else tr("NO_RECORD")


func _start() -> void:
	var cfg: Dictionary = Game.race_config
	cfg.track_id = TRACKS[0]
	cfg.laps = laps_sel.index + 1
	if cfg.mode == "quick":
		cfg.difficulty = DIFFS[diff_sel.index]
		cfg.ai_count = ai_sel.index + 1
		cfg.items = items_sel.index == 0
	else:
		cfg.ai_count = 0
		cfg.items = false
	Game.start_loading_race()


func first_focus() -> Control:
	return start_btn


class TrackPreview:
	extends Control
	var track: TrackData

	func _draw() -> void:
		if track == null:
			return
		var pts := PackedVector2Array()
		var b := Rect2(Vector2(track.main.points[0].x, track.main.points[0].z), Vector2.ZERO)
		for p in track.main.points:
			b = b.expand(Vector2(p.x, p.z))
		var pad := 16.0
		var sc := minf((size.x - pad * 2) / b.size.x, (size.y - pad * 2) / b.size.y)
		var off := Vector2(pad, pad) + (size - Vector2(pad, pad) * 2 - b.size * sc) * 0.5 - b.position * sc
		for p in track.main.points:
			pts.append(Vector2(p.x, p.z) * sc + off)
		pts.append(pts[0])
		draw_style_box(UITheme.rounded(Color(UITheme.TURQUOISE, 0.25), 18, 0, Color.TRANSPARENT, 0), Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(Vector2(0, (track.sea_z * sc + off.y)), Vector2(size.x, size.y - (track.sea_z * sc + off.y))).intersection(Rect2(Vector2.ZERO, size)), Color(0.15, 0.6, 0.75, 0.5))
		draw_polyline(pts, Color(0, 0, 0, 0.4), 10.0, true)
		draw_polyline(pts, Color.WHITE, 6.0, true)
		for sc_d in track.shortcuts:
			var sp := PackedVector2Array()
			for p in sc_d.path.points:
				sp.append(Vector2(p.x, p.z) * sc + off)
			draw_polyline(sp, UITheme.GOLD, 4.0, true)
		var f: Vector3 = track.main.position_at(track.finish_s)
		draw_circle(Vector2(f.x, f.z) * sc + off, 7.0, UITheme.POMEGRANATE)
