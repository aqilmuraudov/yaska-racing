class_name Palette
## 0.8.1 "more colourful" grade. All world colours pass through here so the
## look is tuned in one place. Pure CPU-side colour tweaks and shader uniform
## values: no extra passes, so no mobile cost.

## Vertex-colour world geometry (buildings, props, terrain).
const WORLD_SAT := 1.38
## Kart bodies and drivers (glossy vertex colours).
const KART_SAT := 1.26
const DRIVER_SAT := 1.14
## Screen-space grade (WorldEnvironment adjustments).
const ENV_SATURATION := 1.3
const ENV_CONTRAST := 1.13
const ENV_EXPOSURE := 1.04
const SKY_TOP := Color(0.03, 0.36, 0.96)
const SKY_HORIZON := Color(0.5, 0.8, 1.0)
const FOG := Color(0.62, 0.82, 1.0)


## Richer saturation for coloured materials; greys (asphalt, concrete,
## white stone) stay neutral so the road and text stay readable.
static func vivid(c: Color) -> Color:
	if c.s < 0.12:
		return c
	var out := Color.from_hsv(c.h, clampf(c.s * 1.3 + 0.04, 0.0, 1.0), clampf(c.v * 1.03, 0.0, 1.0), c.a)
	return out
