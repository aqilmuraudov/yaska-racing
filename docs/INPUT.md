# Input mappings

All devices drive the same InputMap actions (`scripts/input/input_actions.gd`).
Keyboard and controller bindings can be remapped in Settings → Controls
(saved in `user://settings.json`; "Reset controls" restores these defaults).

| Action | Keyboard | Controller (Xbox / PlayStation labels) | Touch |
|---|---|---|---|
| Accelerate | W, ↑ | A / ✕, RT | GAS button, or auto-accelerate (default on touch) |
| Brake / reverse | S, ↓ | X / □, LT | BRAKE button |
| Steer | A/D, ←/→ | Left stick, D-pad | ◀ ▶ buttons (slide between them) or tilt |
| Hop / drift | Space, K | RB / R1 | DRIFT |
| Drift boost | Shift, J | LB / L1 | BOOST |
| Use item | E, L | B / ○ | ITEM (shows the held item) |
| Look behind | Q, I | Y / △ | ↺ button |
| Recover kart | hold R 0.5 s | hold View / Share 0.5 s | hold ↻ button 0.5 s |
| Pause | Esc, P | Menu / Options | II button (top right) |

Menus: arrows / D-pad / left stick to move, Enter / A to confirm,
Esc / B to go back. Selector rows change with left/right.

Touch notes: every finger is tracked separately so steering, gas, drift,
boost and items can be held together. Focus loss, pause, app suspension and
controller disconnects release all virtual buttons. Size, opacity, mirrored
layout and horizontal/vertical insets are adjustable. With auto-accelerate,
a start boost is triggered by pressing DRIFT in the final moment before GO.
Controller prompts use the connected pad's family (Xbox, PlayStation,
Nintendo) in the remapping screen and tutorial.
