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
| UI | glossy 9-patch buttons/panels/cards, patterned backdrop, sparkle, theme | `tools/gen_ui_art.py` → `assets/ui/*.png`, `scripts/ui/ui_theme.gd` | Original, project |
| Icons and flags | 20 illustrated SVG icons (tabs, settings rows, play, gear, trophy…), Azerbaijani and Union flags for the language choice | `tools/gen_icons.py` → `assets/icons/ui/*.svg` (imported at 1.5×) | Original, project |
| Painted textures (3 tiers) | asphalt, Old City setts, limestone wall, promenade paving, grass, Azerbaijani flag; 256 / 512 / 1024 px per Texture Quality | `tools/gen_textures.py` → `assets/textures/{low,normal,high}/` | Original, project |
| Baku landmarks | Flame Towers, Heydar Aliyev Center, Baku Crescent, National Flag Square (waving flag), Maiden Tower (Old City), Boulevard planters | `scripts/track/landmark_kit.gd`, `prop_kit.gd`; shaders `glass_tower.gdshader`, `flag.gdshader` | Original stylised interpretations, project |
| SFX (28) + loops (engine, drift, sea ambience) | hop, land, boosts, miss, hits, shield, pickup, trap, bump, bell countdown, lap, finish, overtake, marimba UI (move / select / confirm / back), waves + gulls | `tools/audio/generate_audio.py` (numpy synthesis, 32 kHz) | Original, project |
| Music (2 loops + jingle) | cheerful major-key menu (112 BPM, 34 s) and race (138 BPM, 42 s) themes with marimba, bouncy bass, whistle / bell melodies; 3.4 s victory jingle | `generate_audio.py` | Original, project |
| Fonts | Baloo 2 (headings), Nunito (body) – full Azerbaijani coverage verified (ə ı İ ö ü ş ç ğ ₼) | Google Fonts repository | SIL OFL 1.1 (`assets/fonts/OFL-*.txt`) |
| Engine | Godot Engine 4.4.1 | godotengine.org | MIT |

## Import settings

- WAV: Godot default import, **QOA compression**, loop points read from the
  RIFF `smpl` chunk written by the generator (engine, drift, music loop).
- Fonts: dynamic, variable `wght` axis via `FontVariation`
  (`assets/fonts/body_font.tres`, `UITheme`).
- Scenery textures are generated PNGs in three size tiers; Godot imports
  them VRAM-compressed (ETC2/ASTC on Android) with mipmaps. Only the tier
  chosen by Texture Quality is loaded (`TextureLibrary` swaps bound
  materials in place). Markings, kerbs and water stay procedural.
- UI PNGs are lossless 2D textures; SVG icons are rasterised at 1.5×.

## Budgets (initial, from profiling the first track)

Desktop measurements (see `docs/TUNING.md`): Medium ≈ 300–400 draw calls and
≈ 0.4 M primitives per frame. Target for the phone after on-device
profiling: Medium ≤ 300 draws, ≤ 0.35 M primitives; Low ≤ 230 draws.
These budgets must be confirmed on the Xiaomi Mi 12 Lite.

## Concept / reference policy

Landmarks are original stylised interpretations (no logos, brands or
trademarked designs reproduced). Real place names appear only as the
track's setting.
