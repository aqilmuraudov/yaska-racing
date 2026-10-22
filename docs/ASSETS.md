# Asset inventory, sources and licences

Conventions: 1 unit = 1 metre, Y up. Karts face **−Z** (Godot forward);
props/buildings face **+Z** ("front"), origin at ground level. Generated
content is deterministic (fixed seeds) and rebuilt from source; nothing in
this table is a downloaded third-party 3D model, texture or sound.

| Category | Items | Source (generator) | Licence |
|---|---|---|---|
| Karts | Bamboo Sprint, Amber Dash, Hop Rocket, Velvet Slide, Buddy Rally, Cloud Booster — six distinct bodies | `scripts/vehicles/kart_model.gd` (rounded parts merged per animated node) | Original, project |
| Animal drivers | Posi (panda), Bicok (fox), Ləlöyün (rabbit), Məstan (cat), HavHav (dog), Çəpiş (lamb); procedural animation | `scripts/vehicles/animal_driver.gd`; portraits `scripts/ui/racer_icon.gd` | Original, project |
| Track surfaces | asphalt / cobbles with markings, kerbs, off-road strips, barriers, ramp, boost pads, finish line, terrain, seawall, sea | `scripts/track/track_builder.gd` + shaders `assets/materials/*.gdshader` | Original, project |
| Environment kit | palms, lamps, benches, balustrades, bollards, tyre stacks, chevron signs, trees, cypresses, 4 Old City houses (enclosed wooden balconies), 3 modern blocks, tower inspired by the Old City keep, observation wheel, flame-like and glass towers, grandstand, umbrellas, kiosk, fountain, boats, bunting, city gate, start gantry with countdown lights, hills, city blocks | `scripts/track/prop_kit.gd`, `track_decor.gd` | Original, project |
| Carpets | procedural Caucasian-style rug patterns (4 palettes) | `assets/materials/carpet.gdshader` | Original, project |
| Items | item box, road trap, shield bubble, boost flames | `item_system.gd`, `kart_effects.gd`, `shield.gdshader` | Original, project |
| VFX | tyre smoke, tiered drift sparks, dust, exhaust puffs, speed blur | `kart_effects.gd`, `speed_blur.gdshader` | Original, project |
| UI | theme, icons (item icons drawn in code), switch/slider graphics, app icon | `scripts/ui/*`, `assets/icons/icon.svg` | Original, project |
| SFX (26) + loops (engine, drift) | hop, land, boosts, miss, hits, shield, pickup, trap, bump, countdown, lap, finish, UI | `tools/audio/generate_audio.py` (numpy synthesis, 32 kHz mono) | Original, project |
| Music (2 loops) | menu (104 BPM, 37 s), race (132 BPM, 44 s); mode with augmented second for a Caucasian colour | `generate_audio.py` | Original, project |
| Fonts | Baloo 2 (headings), Nunito (body) – full Azerbaijani coverage verified (ə ı İ ö ü ş ç ğ ₼) | Google Fonts repository | SIL OFL 1.1 (`assets/fonts/OFL-*.txt`) |
| Engine | Godot Engine 4.4.1 | godotengine.org | MIT |

## Import settings

- WAV: Godot default import, **QOA compression**, loop points read from the
  RIFF `smpl` chunk written by the generator (engine, drift, music loop).
- Fonts: dynamic, variable `wght` axis via `FontVariation`
  (`assets/fonts/body_font.tres`, `UITheme`).
- No bitmap textures are imported; surfaces are procedural shaders, which
  keeps APK size and texture bandwidth low. VRAM ETC2/ASTC import is
  enabled for any future textures.

## Budgets (initial, from profiling the first track)

Desktop measurements (see `docs/TUNING.md`): Medium ≈ 300–400 draw calls and
≈ 0.4 M primitives per frame. Target for the phone after on-device
profiling: Medium ≤ 300 draws, ≤ 0.35 M primitives; Low ≤ 230 draws.
These budgets must be confirmed on the Xiaomi Mi 12 Lite.

## Concept / reference policy

Landmarks are original stylised interpretations (no logos, brands or
trademarked designs reproduced). Real place names appear only as the
track's setting.
