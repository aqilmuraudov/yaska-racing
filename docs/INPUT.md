# Input mappings

All devices drive the same InputMap actions (`scripts/input/input_actions.gd`).
Keyboard and controller bindings keep their saved overrides in
`user://settings.json`; the child-facing Settings no longer shows a remapping
screen (developer tab only, debug builds).

| Action | Keyboard | Controller (Xbox / PlayStation labels) | Touch |
|---|---|---|---|
| Accelerate | W, ↑ | A / ✕, RT | GAS button, or auto-accelerate (default on touch) |
| Brake / reverse | S, ↓ | X / □, LT | BRAKE button |
| Steer | A/D, ←/→ | Left stick, D-pad | ◀ ▶ buttons (slide between them) **or** tilt (Control Type) |
| Hop / drift | Space, K | RB / R1 | DRIFT |
| Drift boost | Shift, J | LB / L1 | BOOST |
| Use item | E, L | B / ○ | ITEM (shows the held item) |
| Look behind | Q, I | Y / △ | ↺ button |
| Recover kart | hold R 0.5 s | hold View / Share 0.5 s | hold ↻ button 0.5 s |
| Pause | Esc, P | Menu / Options | II button (top right) |

Menus: arrows / D-pad / left stick to move, Enter / A to confirm,
Esc / B to go back. Selector rows change with left/right.

## Steering sensitivity and tilt (0.5.0)

Settings → Controls: **Control Type** (Buttons / Tilt), **Button Size**
(Small / Medium / Large), **Automatic Acceleration**, **Steering
Sensitivity** (Low / Normal / High) and, with Tilt, **Calibrate**.

- Full lock is always exactly ±1 at every level (no saturation tricks).
- Buttons / keys: the level sets the time from centre to full lock
  (Low 0.28 s, Normal 0.12 s, High instant); returning is twice as fast.
- Tilt: the level sets the phone rotation for full lock (Low 30°, Normal
  22°, High 15°) after a 1.8° dead zone, linear in between.
- Tilt is exclusive: in Tilt mode the steer buttons are hidden and no
  button/key can overwrite the tilt value; drift, boost, item, brake, look
  back and recover stay on screen. Switching modes clears stale steering.
- Signal path (`scripts/input/tilt_steering.gd`, `player_input.gd`):
  `Input.get_gravity()` (Android's fused gravity sensor) or, if absent, the
  accelerometer with bump rejection → frame-rate-independent low-pass on
  the fixed 60 Hz physics tick → angle (rotation in the screen plane when
  held upright, lean of the horizontal axis when held flat) → minus the
  calibrated neutral → dead zone and curve → `KartInput.steer`.
- Godot already rotates sensor axes into the current display orientation,
  so steering is the screen **x** axis in either landscape orientation; a
  stale cached rotation (180° flip) is detected from the gravity direction.
- Sensors must be enabled in `project.godot`
  (`input_devices/sensors/enable_gravity`, `enable_accelerometer`); Godot
  4.4 defaults them to off.
- No sensor data for 1.2 s → buttons come back with a short localized
  notice; tilt resumes automatically if data appears.
- Pause, app backgrounding and restarts reset the filter and steering.
- Debug builds: Settings → long-press the title → Developer → "Tilt sensor
  debug overlay" shows source, raw / filtered samples, neutral, angle and
  the final steering value during a race.

Touch notes: every finger is tracked separately so steering, gas, drift,
boost and items can be held together. Focus loss, pause, app suspension and
controller disconnects release all virtual buttons. Size, opacity, mirrored
layout and insets remain as developer options (Button Size is the player option). With auto-accelerate,
a start boost is triggered by pressing DRIFT in the final moment before GO.
Controller prompts use the connected pad's family (Xbox, PlayStation,
Nintendo) in the remapping screen and tutorial.
