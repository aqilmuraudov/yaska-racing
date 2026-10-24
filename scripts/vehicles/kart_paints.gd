class_name KartPaints
extends RefCounted
## Cosmetic kart paints unlocked with collected stars. Paint 0 is each
## racer's own colour; the others are shared bright colours. Purely visual:
## handling and collision never change.

const COLORS := [Color("ffc21a"), Color("2fd39b"), Color("ff6fb5"), Color("8b5cf6")]
const NAME_KEYS := ["PAINT_SUN", "PAINT_MINT", "PAINT_CANDY", "PAINT_GRAPE"]
## Total stars needed for paints 1..4 (paint 0 is always available).
const COSTS := [15, 40, 80, 140]


static func count() -> int:
	return COLORS.size() + 1


static func cost(index: int) -> int:
	return 0 if index <= 0 else int(COSTS[clampi(index - 1, 0, COSTS.size() - 1)])


static func is_unlocked(index: int, stars: int) -> bool:
	return stars >= cost(index)


static func color_of(def: RacerDefinition, index: int) -> Color:
	return def.kart_primary if index <= 0 else COLORS[clampi(index - 1, 0, COLORS.size() - 1)]


## A copy of the definition with the chosen body colour (visual use only).
static func painted(def: RacerDefinition, index: int) -> RacerDefinition:
	if index <= 0:
		return def
	var d: RacerDefinition = def.duplicate()
	d.kart_primary = color_of(def, index)
	return d
