class_name FinishCelebration
extends Control
## Finish-line moment (0.8.0), shown on the frame the player crosses:
##   1st  -> "1-ci yer! QALİB!" + confetti rain + fireworks + celebration SFX
##   else -> a big animated "N-ci yer!" that pops in and settles.
## The celebration sounds are synthesised here (no new files) and play on the
## existing "SFX" bus, so the Settings SFX volume / mute control them.

const COLORS := [Color("ffd23f"), Color("ff5f6d"), Color("6fcf3c"), Color("17b9c9"), Color("8b5cf6"), Color("ff8a1f"), Color.WHITE]

var place := 0
var place_label: Label
var sub_label: Label
var _sparks: Array = [] ## firework sparks: [pos, vel, color, life, max_life]
var _confetti: Array = [] ## [pos, vel, color, rot, spin, size]
var _rockets: Array = [] ## [pos, vel, fuse, color]
var _launch_timer := 0.0
var _rockets_left := 0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	place_label = Label.new()
	place_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	place_label.add_theme_font_override("font", UITheme.heading_font())
	place_label.add_theme_font_size_override("font_size", 118)
	place_label.add_theme_constant_override("outline_size", 26)
	place_label.add_theme_color_override("font_outline_color", UITheme.INK)
	place_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(place_label)
	sub_label = Label.new()
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_override("font", UITheme.heading_font())
	sub_label.add_theme_font_size_override("font_size", 54)
	sub_label.add_theme_constant_override("outline_size", 16)
	sub_label.add_theme_color_override("font_outline_color", UITheme.INK)
	sub_label.add_theme_color_override("font_color", UITheme.YELLOW)
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub_label)
	resized.connect(_layout)


func _layout() -> void:
	place_label.size = Vector2(size.x, 170)
	place_label.position = Vector2(0, size.y * 0.30 - 85)
	place_label.pivot_offset = place_label.size * 0.5
	sub_label.size = Vector2(size.x, 80)
	sub_label.position = Vector2(0, size.y * 0.30 + 80)
	sub_label.pivot_offset = sub_label.size * 0.5


var _tweens: Array[Tween] = []
func _tw() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t


func play(p_place: int) -> void:
	place = p_place
	for t in _tweens:
		if t.is_valid():
			t.kill()
	_tweens.clear()
	place_label.rotation = 0.0
	sub_label.scale = Vector2.ONE
	visible = true
	modulate.a = 1.0
	_t = 0.0
	_sparks.clear()
	_confetti.clear()
	_rockets.clear()
	_layout()
	place_label.text = tr("FINISH_PLACE_%d" % clampi(place, 1, 8))
	var col: Color = [UITheme.YELLOW, Color("dfe7f2"), Color("ffae5c")][place - 1] if place <= 3 else Color.WHITE
	place_label.add_theme_color_override("font_color", col)
	sub_label.text = tr("FINISH_WINNER") if place == 1 else ""
	place_label.scale = Vector2.ONE * 0.2
	var tw := _tw()
	tw.tween_property(place_label, "scale", Vector2.ONE * 1.18, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(place_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)
	if place == 1:
		sub_label.scale = Vector2.ZERO
		var t2 := _tw()
		t2.tween_interval(0.25)
		t2.tween_property(sub_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_rockets_left = 7
		_launch_timer = 0.0
		for i in 90:
			_spawn_confetti(true)
		_play_sfx(celebration_stream())
	else:
		# Gentle wobble so the number stays lively until the results.
		var t3 := _tw().set_loops(3)
		t3.tween_property(place_label, "rotation", 0.05, 0.35).set_trans(Tween.TRANS_SINE)
		t3.tween_property(place_label, "rotation", -0.05, 0.35).set_trans(Tween.TRANS_SINE)
		t3.finished.connect(func(): place_label.rotation = 0.0)
		_play_sfx(place_stream())


## Fades out (results take over).
func dismiss() -> void:
	if not visible:
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): visible = false)


func is_celebrating() -> bool:
	return visible and place == 1


func _spawn_confetti(initial: bool) -> void:
	var w := maxf(size.x, 1.0)
	var pos := Vector2(_rng.randf() * w, (-_rng.randf() * size.y * 0.6) if initial else -20.0)
	_confetti.append([pos, Vector2(_rng.randf_range(-40, 40), _rng.randf_range(120, 260)),
		COLORS[_rng.randi() % COLORS.size()], _rng.randf() * TAU, _rng.randf_range(-6, 6), _rng.randf_range(8, 15)])


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if place == 1:
		if _t < 3.0 and _confetti.size() < 160:
			_spawn_confetti(false)
		_launch_timer -= delta
		if _rockets_left > 0 and _launch_timer <= 0.0:
			_rockets_left -= 1
			_launch_timer = 0.32
			_rockets.append([Vector2(_rng.randf_range(0.15, 0.85) * size.x, size.y + 10),
				Vector2(_rng.randf_range(-60, 60), -_rng.randf_range(620, 820)), _rng.randf_range(0.55, 0.8),
				COLORS[_rng.randi() % (COLORS.size() - 1)]])
	for r in _rockets:
		r[0] += r[1] * delta
		r[1].y += 380.0 * delta
		r[2] -= delta
	for i in range(_rockets.size() - 1, -1, -1):
		if _rockets[i][2] <= 0.0:
			_explode(_rockets[i][0], _rockets[i][3])
			_rockets.remove_at(i)
	for s in _sparks:
		s[0] += s[1] * delta
		s[1] *= 1.0 - 1.6 * delta
		s[1].y += 160.0 * delta
		s[3] -= delta
	_sparks = _sparks.filter(func(s): return s[3] > 0.0)
	for c in _confetti:
		c[0] += c[1] * delta
		c[0].x += sin(_t * 3.0 + c[3]) * 30.0 * delta
		c[3] += c[4] * delta
	_confetti = _confetti.filter(func(c): return c[0].y < size.y + 30.0)
	queue_redraw()


func _explode(pos: Vector2, col: Color) -> void:
	for i in 46:
		var a := TAU * i / 46.0 + _rng.randf() * 0.1
		var sp := _rng.randf_range(170, 330)
		var c: Color = col if i % 3 else col.lightened(0.5)
		_sparks.append([pos, Vector2(cos(a), sin(a)) * sp, c, _rng.randf_range(0.8, 1.3), 1.3])
	_play_sfx(pop_stream(_rng.randf_range(0.8, 1.2)), -6.0)


func _draw() -> void:
	for r in _rockets:
		draw_circle(r[0], 5.0, r[3])
		draw_line(r[0], r[0] - r[1] * 0.05, Color(r[3], 0.6), 3.0)
	for s in _sparks:
		var a: float = clampf(s[3] / 0.9, 0.0, 1.0)
		var c: Color = s[2]
		draw_line(s[0], s[0] - s[1] * 0.04, Color(c, a), 4.0)
	for c in _confetti:
		var xf := Transform2D(c[3], c[0])
		draw_set_transform_matrix(xf)
		var sz: float = c[5]
		draw_rect(Rect2(-sz * 0.5, -sz * 0.25, sz, sz * 0.5 * (0.4 + 0.6 * absf(sin(c[3] * 2.0)))), c[2])
	draw_set_transform_matrix(Transform2D.IDENTITY)


# --- Synthesised celebration sounds (16-bit mono, 22 050 Hz) ------------------

const RATE := 22050


func _play_sfx(stream: AudioStreamWAV, db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = stream
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


## Rising major arpeggio fanfare (C-E-G-C') with a shimmer tail: the 1st-place
## celebration.
static func celebration_stream() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 783.99, 1046.5, 1318.5]
	var step := 0.11
	var total := step * notes.size() + 0.9
	var n := int(total * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for k in notes.size():
		var start := int(k * step * RATE)
		var dur := 0.9 if k == notes.size() - 1 else 0.35
		for i in int(dur * RATE):
			var j := start + i
			if j >= n:
				break
			var t := float(i) / RATE
			var env := minf(t / 0.01, 1.0) * exp(-t * (3.0 if k == notes.size() - 1 else 7.0))
			var f: float = notes[k]
			var v := sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.18 + sin(TAU * f * 3.0 * t) * 0.07
			buf[j] += v * env * 0.45
	# shimmer
	var seed_v := 12345
	for i in int(0.8 * RATE):
		var j := int(step * 3 * RATE) + i
		if j >= n:
			break
		var t := float(i) / RATE
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var noise := float(seed_v) / 0x7fffffff * 2.0 - 1.0
		buf[j] += noise * 0.05 * exp(-t * 4.0) * (0.5 + 0.5 * sin(TAU * 18.0 * t))
	return _to_wav(buf)


## Firework pop: a short filtered noise burst with a falling tone.
static func pop_stream(pitch := 1.0) -> AudioStreamWAV:
	var n := int(0.35 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var seed_v := int(pitch * 9999)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var noise := float(seed_v) / 0x7fffffff * 2.0 - 1.0
		lp += (noise - lp) * 0.35
		var tone := sin(TAU * (700.0 * pitch - 900.0 * t) * t) * 0.3
		buf[i] = (lp * 0.8 + tone) * exp(-t * 11.0) * 0.6
	return _to_wav(buf)


## Other places: a short two-note "ta-da".
static func place_stream() -> AudioStreamWAV:
	var n := int(0.55 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 587.33 if t < 0.14 else 880.0
		var lt := t if t < 0.14 else t - 0.14
		var env := minf(lt / 0.008, 1.0) * exp(-lt * 6.0)
		buf[i] = (sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.15) * env * 0.4
	return _to_wav(buf)
