class_name KartFactory
extends RefCounted
## Assembles a racer: physics controller + collision + visual + audio.
## All handling classes share the same collision footprint (fairness).

const KART_IDS := ["balanced", "agile", "fast"]
const COLLISION_RADIUS := 0.6
const COLLISION_LENGTH := 2.0

static var _stats_cache := {}


static func load_stats(kart_id: String) -> KartStats:
	if _stats_cache.has(kart_id):
		return _stats_cache[kart_id]
	var path := "res://data/vehicles/%s.tres" % kart_id
	var st: KartStats = load(path) if ResourceLoader.exists(path) else null
	if st == null:
		push_warning("KartFactory: missing %s, using defaults" % path)
		st = KartStats.new()
	_stats_cache[kart_id] = st
	return st


static func create(kart_id: String, paint_index: int, is_player: bool, effects_density: float) -> KartController:
	var stats := load_stats(kart_id)
	var kart := KartController.new()
	kart.name = "Kart"
	kart.stats = stats
	kart.is_player = is_player
	var shape := CapsuleShape3D.new()
	shape.radius = COLLISION_RADIUS
	shape.height = COLLISION_LENGTH
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.rotation = Vector3(PI * 0.5, 0, 0) # lie along the kart's length
	cs.position = Vector3(0, COLLISION_RADIUS, 0)
	kart.add_child(cs)
	var visual := KartVisual.new()
	visual.name = "Visual"
	kart.add_child(visual)
	var paint: Color = stats.paints[posmod(paint_index, stats.paints.size())] if stats.paints.size() > 0 else Color.RED
	visual.setup(kart, paint, effects_density)
	var audio := KartAudio.new()
	audio.name = "Audio"
	kart.add_child(audio)
	audio.setup(kart)
	kart.set_meta("visual", visual)
	kart.set_meta("audio", audio)
	kart.set_meta("paint", paint)
	return kart
