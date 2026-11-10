class_name GhostSystem
extends Node3D
## Time Trial ghosts: records the player's laps at 20 Hz and replays the
## stored best lap as a translucent kart (no collision, no interaction).
##
## Ghost files are versioned. A ghost is only replayed when its format,
## track version and physics version match the running game; otherwise it is
## ignored (and replaced the next time a lap is completed).

## 2 (0.10.0): each sample also stores the lap distance (m) for the live
## +/- delta. Format 1 ghosts still replay (no live delta).
const FORMAT := 2
const OLDEST_FORMAT := 1
const INTERVAL := 0.05
const DIR := "user://ghosts"

var race: RaceManager
var kart: KartController
var track_id := ""
var track_version := 1
var _recording: Array = []
var _rec_timer := 0.0
var _lap_start_time := 0.0
var _best: Dictionary = {}
var _ghost_model: Node3D
var _play_time := 0.0
var status := "none" ## none | loaded | incompatible
var ghost_dir_override := ""
## Last completed lap minus the best lap before it (s), NAN without a best.
var last_lap_delta := NAN


func setup(p_race: RaceManager, p_kart: KartController, p_track_id: String, p_track_version: int) -> void:
	race = p_race
	kart = p_kart
	track_id = p_track_id
	track_version = p_track_version
	_best = load_ghost()
	_build_ghost_model()
	race.lap_completed.connect(_on_lap)
	reset()


func reset() -> void:
	_recording.clear()
	_rec_timer = 0.0
	_lap_start_time = 0.0
	_play_time = 0.0
	if _ghost_model:
		_ghost_model.visible = false


func ghost_path() -> String:
	var dir := ghost_dir_override if ghost_dir_override != "" else DIR
	return dir.path_join("%s.json" % track_id)


static func is_compatible(d: Dictionary, p_track_id: String, p_track_version: int) -> bool:
	return int(d.get("format", 0)) >= OLDEST_FORMAT and int(d.get("format", 0)) <= FORMAT and String(d.get("track_id", "")) == p_track_id \
		and int(d.get("track_version", -1)) == p_track_version \
		and int(d.get("physics_version", -1)) == KartController.PHYSICS_VERSION \
		and typeof(d.get("samples")) == TYPE_ARRAY and (d.samples as Array).size() > 2


func load_ghost() -> Dictionary:
	var res := SafeFile.read_json(ghost_path())
	if res.source == "none":
		status = "none"
		return {}
	if not is_compatible(res.data, track_id, track_version):
		status = "incompatible"
		return {}
	status = "loaded"
	return res.data


func save_ghost(samples: Array, lap_time: float) -> bool:
	DirAccess.make_dir_recursive_absolute(ghost_path().get_base_dir())
	var d := {
		"format": FORMAT,
		"track_id": track_id,
		"track_version": track_version,
		"physics_version": KartController.PHYSICS_VERSION,
		"kart_id": kart.stats.id,
		"paint": kart.get_meta("paint", Color.WHITE).to_html(),
		"lap_ms": int(round(lap_time * 1000.0)),
		"interval": INTERVAL,
		"samples": samples,
	}
	var ok := SafeFile.write_json(ghost_path(), d)
	if ok:
		_best = d
		status = "loaded"
		_build_ghost_model()
		SaveManager.data.ghosts[track_id] = {"lap_ms": d.lap_ms, "kart_id": d.kart_id,
			"track_version": track_version, "physics_version": KartController.PHYSICS_VERSION}
		SaveManager.save_profile()
	return ok


func _build_ghost_model() -> void:
	if _ghost_model:
		_ghost_model.queue_free()
		_ghost_model = null
	if _best.is_empty():
		return
	var model := KartModel.new()
	model.build(RacerRoster.get_def(String(_best.get("kart_id", RacerRoster.DEFAULT_ID))), false)
	_ghost_model = Node3D.new()
	_ghost_model.name = "Ghost"
	_ghost_model.add_child(model)
	add_child(_ghost_model)
	_ghost_model.visible = false
	# Translucent, unshaded-ish look applied to every mesh in the model.
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.55, 0.9, 1.0, 0.38)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.7, 1.0)
	mat.emission_energy_multiplier = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	_apply_material(_ghost_model, mat)


func _apply_material(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		n.material_override = mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_apply_material(c, mat)


func _on_lap(r, _lap: int, lap_time: float) -> void:
	if not r.is_player:
		return
	# Autopilot (debug/demo) and Kids controls laps are not the player's
	# driving and are never saved as a record ghost.
	if (race.kids_used() or bool(race.config.get("debug_autopilot", false))) and not DebugRunner.parse_args().has("keep-ghost"):
		last_lap_delta = (lap_time - float(best_lap_ms()) / 1000.0) if best_lap_ms() > 0 else NAN
		_recording.clear()
		_play_time = 0.0
		_lap_start_time = race.race_time
		return
	var best_ms := int(_best.get("lap_ms", 0)) if not _best.is_empty() else 0
	last_lap_delta = (lap_time - best_ms / 1000.0) if best_ms > 0 else NAN
	if best_ms <= 0 or int(round(lap_time * 1000.0)) < best_ms:
		save_ghost(_recording.duplicate(), lap_time)
	_recording.clear()
	_rec_timer = 0.0
	_play_time = 0.0
	_lap_start_time = race.race_time


func _physics_process(delta: float) -> void:
	if race == null or race.state != RaceManager.RaceState.RACING:
		return
	# Lap 1 is timed from GO, so recording and playback also start at GO.
	_rec_timer -= delta
	if _rec_timer <= 0.0:
		_rec_timer += INTERVAL
		var p := kart.global_position
		_recording.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01), snappedf(kart.yaw, 0.001), snappedf(lap_distance(), 0.1)])
	_play_time += delta


func _process(_delta: float) -> void:
	if _ghost_model == null or _best.is_empty() or race == null:
		return
	var samples: Array = _best.samples
	var interval := float(_best.get("interval", INTERVAL))
	var playing := race.state == RaceManager.RaceState.RACING
	var f := _play_time / interval
	var i := int(f)
	if not playing or i >= samples.size() - 1:
		_ghost_model.visible = false
		return
	var a: Array = samples[i]
	var b: Array = samples[i + 1]
	var t := f - i
	var pos := Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), t)
	var yaw := lerp_angle(float(a[3]), float(b[3]), t)
	_ghost_model.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	_ghost_model.visible = true


func best_lap_ms() -> int:
	return int(_best.get("lap_ms", 0)) if not _best.is_empty() else 0


## Player's distance into the current lap (m); slightly negative on the
## grid before the first crossing.
func lap_distance() -> float:
	if race == null or race.player == null or race.player.tracker == null:
		return 0.0
	var t: RaceTracker = race.player.tracker
	return t.race_distance - t.laps_completed() * race.track.lap_length()


## True when the stored ghost has lap distances (format 2).
func has_splits() -> bool:
	if _best.is_empty():
		return false
	var smp: Array = _best.samples
	return smp.size() > 2 and (smp[0] as Array).size() >= 5


## Ghost lap time (s) at lap distance `d`, NAN when unknown.
func ghost_time_at(d: float) -> float:
	if not has_splits():
		return NAN
	var smp: Array = _best.samples
	var interval := float(_best.get("interval", INTERVAL))
	if d <= float(smp[0][4]):
		return 0.0
	var last := smp.size() - 1
	if d >= float(smp[last][4]):
		return NAN
	var lo := 0
	var hi := last
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if float(smp[mid][4]) < d:
			lo = mid
		else:
			hi = mid
	var d0 := float(smp[lo][4])
	var d1 := float(smp[hi][4])
	var f := 0.0 if d1 <= d0 else (d - d0) / (d1 - d0)
	return (lo + f) * interval


## Live delta against the best lap at the same point of the lap (s):
## negative = ahead of the record. NAN when there is nothing to compare.
func live_delta() -> float:
	if race == null or race.state != RaceManager.RaceState.RACING:
		return NAN
	var d := lap_distance()
	if d < 20.0:
		return NAN # the first metres of a lap say nothing yet
	var g := ghost_time_at(d)
	if is_nan(g):
		return NAN
	return (race.race_time - _lap_start_time) - g
