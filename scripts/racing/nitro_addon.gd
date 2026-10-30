class_name NitroAddon
extends RefCounted
## Garage Nitro add-on (0.8.0): one charge that refills over time (faster
## with drift boosts). Fired by the NITRO touch button / N key.

var level := 0
var charge := 0.0 ## 0..1; ready at 1
var spec := {}


func _init(p_level: int) -> void:
	level = p_level
	spec = KartTuning.nitro_spec(p_level)
	charge = 0.5 # half full at the start: first use after ~10 s


func tick(delta: float) -> void:
	charge = minf(charge + delta / float(spec.recharge), 1.0)


func on_drift_boost() -> void:
	charge = minf(charge + 0.12, 1.0)


func ready() -> bool:
	return charge >= 1.0


## Fires the nitro on `kart` when charged. Returns true when fired.
func fire(kart: KartController) -> bool:
	if not ready() or kart.controls_locked:
		return false
	charge = 0.0
	kart.boost.add(float(spec.strength), float(spec.duration), &"item")
	return true
