class_name KartFactory
extends RefCounted
## Assembles a racer: physics controller + collision + visual + audio.
## All handling classes share the same collision footprint (fairness).

const KART_IDS := RacerRoster.IDS
const COLLISION_RADIUS := 0.6
const COLLISION_LENGTH := 2.0

static var _stats_cache := {}


## Handling for a racer package (derived from its ratings).
static func load_stats(racer_id: String) -> KartStats:
	return RacerRoster.get_def(racer_id).make_stats()


static func create(racer_id: String, is_player: bool, effects_density: float, paint := 0) -> KartController:
	var def := RacerRoster.get_def(racer_id)
	var stats := def.make_stats()
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
	visual.setup(kart, KartPaints.painted(def, paint), effects_density)
	var audio := KartAudio.new()
	audio.name = "Audio"
	kart.add_child(audio)
	audio.setup(kart)
	kart.set_meta("visual", visual)
	kart.set_meta("audio", audio)
	kart.set_meta("paint", def.accent)
	kart.set_meta("racer", def)
	return kart
