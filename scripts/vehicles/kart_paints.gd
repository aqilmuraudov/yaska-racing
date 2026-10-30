class_name KartPaints
extends RefCounted
## Cosmetic kart paints unlocked with collected stars. Paint 0 is each
## racer's own colour; the others are shared bright colours. Purely visual:
## handling and collision never change.

## Indices 1..4 keep their 0.6 meaning (saved choices stay valid); 0.7.0
## adds seven more for longer-term progression. Costs only went down, so no
## paint a player already had becomes locked.
const COLORS := [Color("ffc21a"), Color("2fd39b"), Color("ff6fb5"), Color("8b5cf6"),
	Color("1e88e5"), Color("ff7a1a"), Color("c62845"), Color("d9b46a"), Color("eef2f7"), Color("27304a"), Color("b8c2cc")]
const NAME_KEYS := ["PAINT_SUN", "PAINT_MINT", "PAINT_CANDY", "PAINT_GRAPE",
	"PAINT_CASPIAN", "PAINT_FLAME", "PAINT_POMEGRANATE", "PAINT_SAND", "PAINT_PEARL", "PAINT_NIGHT", "PAINT_CHROME"]
## Total stars needed for paints 1..11 (paint 0 is always available). The
## first comes after a race or two; the last needs many.
const COSTS := [5, 15, 35, 60, 90, 130, 180, 240, 310, 400, 520]


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
