class_name GhostSystem
extends Node3D
## Time Trial ghosts: records the player's laps at 20 Hz and replays the
## stored best lap as a translucent kart (no collision, no interaction).
##
## Ghost files are versioned. A ghost is only replayed when its format,
## track version and physics version match the running game; otherwise it is
## ignored (and replaced the next time a lap is completed).

const FORMAT := 1
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
	return int(d.get("format", 0)) == FORMAT and String(d.get("track_id", "")) == p_track_id \
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
	var stats := KartFactory.load_stats(String(_best.get("kart_id", "balanced")))
	var model := KartModel.new()
	model.build(stats.model_style, Color(String(_best.get("paint", "ffffff"))), false)
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
	var best_ms := int(_best.get("lap_ms", 0)) if not _best.is_empty() else 0
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
		_recording.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01), snappedf(kart.yaw, 0.001)])
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
