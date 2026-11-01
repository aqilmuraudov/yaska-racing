# Status, verification evidence and known issues

Date: 2026-11-01 · Build: 0.15.3 · Engine: Godot 4.4.1-stable

## Update 0.15.3 (versionCode 38) — "mini Baku": landmarks from real photos, real malls, real layout, 9-storey city, track relief
- **Owner's goal (2026-11-02):** a mini model of Baku - famous places look like the real ones (silhouette, facade, colour; game-fitted heights), sit in their real relative positions, ordinary buildings are new 9-storey blocks. References: Wikimedia Commons photos (downloaded for study only, not shipped) and the architects' descriptions.
- **Flame Towers:** straight slightly bellied columns with a teardrop plan; only the top half curls in to a tip over the back edge; tips point outward (was reversed), wider triangle so all three read from the Boulevard, terraced podium with a garden top.
- **Heydar Aliyev Center:** low glazed arch on the left, dip, tall round-topped portal with a steep right side, long low wing to the right, broad "horn" behind (was two soft humps). Glass front re-baked to the new curve.
- **Maiden Tower:** dense ribbed coursing on the upper 45 %, plain rough masonry below, buttress at ~85 % height (was 14 even rings).
- **Government House:** square towers with two storeys of arched loggias, toothed parapets and needle pinnacles (corner, centre, middle towers) and roof-edge teeth (was a stepped "wedding cake" tower with a gold spire).
- **Baku Crescent:** the real asymmetric glass arch (thick left leg, round top, thin right leg, tall opening) on a banded round podium (was an upright crescent moon).
- **Real malls** (`tools/blender/malls_props.py`, downtown): 28 Mall (stone block, glowing "28" tower, V-column glass top), Port Baku (disc roof on Y columns, stepped towers), Park Bulvar (silver vaults, glass dome, stone sails), Ganjlik Mall (interlocking sandstone + glass, limestone bookends; from the architect's description - no free photo). Port Baku also stands at the east end of the seafront.
- **Layout (seafront, +x = east, sea = +z):** Flag Square + Crystal Hall moved to the west (Bayil), TV tower to the western hill, Crescent to the east; west-to-east order now follows the real bay.
- **Ordinary city:** new 9-storey Baku blocks (`tools/blender/blocks_props.py`, 3 variants: cream with glazed balconies, sandstone with bay windows, grey with a blue glass corner), placed unscaled (the old stretched blocks distorted the windows).
- **Track surfaces:** asphalt grain and sunken cobble mortar relief, kerb rumble ridges, new barrier shader (concrete grain, panel joints, relief) - bump through screen-space derivatives, no tangents needed.
- **Test flake fixed:** `test_touch_scroll` (full-run only) - leftover root Controls ate the tap; the test list now sits on its own top canvas layer. Full strict run: 240 methods, 6046 checks, **0 failures**.
- Build: `_builds/YaskaRacing-0.15.3-v38-debug.apk`, **247.9 MB** (0.15.2: 196.9 MB; three new 2048² texture sets - plaza, malls, 9-storey blocks - in both VRAM formats). Signed with the usual key (SHA-256 726cd353…6e25d9). Not tested on a phone; no phone FPS measured. For Google Play this size needs AAB + Play Asset Delivery.

### Earlier in 0.15.3 — remaining set pieces in Blender
- `tools/blender/plaza_props.py` → `assets/models/plaza/` (one 2048² set, near LOD 6664 tris for all seven modules):
  - **Heydar Aliyev Center**: curved glass front under the shell lip (glass mask → world-space grid, sky tint, lit windows at night), entrance doors + canopies, plaza with a wide stair, terraced lawns with white edges and hedge bands, three round pools with rims. The white shell stays LandmarkKit's self-lit mesh (its night glow is the building's identity); `_heydar_aliyev` merges both.
  - **State Flag Square**: radial paving with joints, flag-colour rings, three-step podium, granite drum, tapered 64 m mast with collars and gold ball, four eight-point star plaques, eight lamps with glowing globes, a 4 m skirt. It now stands on the real grass height (`TrackBuilder.terrain_height`, same rule as the terrain mesh); before, `ground_y` (road height) left half the plaza under the grass.
  - **Start / finish gantry**: legs with "YASKA" side panels, 2 m checkered beam pieces repeated across the road, countdown light box on top of the beam (the lamps are seen from both sides; before, the box hid the "YASKA RACING" sign).
  - **Hanging carpets**: rod with gold knobs, soft folds, fringe; UVs rebuilt in Godot from the cloth position so the carpet shader pattern is unchanged.
  - **Bunting poles**: base, collar, gold finial.
- Not converted (and why): the track surface, kerbs and barriers are continuous meshes built along the spline (`TrackBuilder`), not props; a Blender module cannot follow every curve. They can get better textures / normal maps instead.
- Strict suite: 238 methods, 6024 checks, 1 failure (the known `test_touch_scroll` full-run flake). Round 30 tests: modules, HAC white shell kept, mast height, carpet UVs, terrain height.

## Update 0.15.2 (versionCode 37) — owner fixes: Rekord HUD, garage tabs, time of day, "Öyrən", Qoşa Qala in Blender
- **Rekord HUD overlap** (owner screenshot): the camera switch sat on the ghost delta pill / best-lap line. In time trial it now sits below that column (`TouchControls.camera_low`, y 290 vs 150 at scale 1).
- **Garage split into two big tabs**: "Maşınlar" (3-column grid of big kart cards: portrait, name, "✓ Sürürəm" / "Seç" / price; tap = race with it or buy) and "Tüninq" (paint, upgrades, parts). Tab is remembered (`GarageScreen.tab`). The old "Yeni maşın" strip is gone (only the "all karts" message remains).
- **City select: time of day every time**: three big buttons (Gündüz / Gün batımı / Gecə, 96 px high, icons) under the city cards; saved to `gameplay.time_of_day` and the next race config.
- **No automatic lesson**: the first "Oyna" (after the starter kart) goes to mode select. Under the modes one big "Öyrən" button opens the guided tour (`TutorialDirector` rewritten): 8 steps on the seafront - gas (auto-gas explained), steer (both sides), brake, drift, drift boost, gift (a turbo is handed over), camera, pause - each with a big card (icon, title, text) and a pulsing ring + arrow on the real touch button; a step moves on when the button is used, "Davam" appears on look-only steps and after 12 s; Kids controls are switched off for the tour. Keyboard / controller players see key names. The old Drift School and the "Dərs" button are replaced by it; the 0.13.0 LessonDirector code stays but is no longer started by the menus.
- **Qoşa Qala gate + İçərişəhər walls in Blender** (`tools/blender/gate_props.py`, `assets/models/gate/`): pointed-arch gate wall (built for 22 m, stretched to the real span), two battered round towers with corbels, rounded merlons, arrow slits and the blind second gate with iron-strapped wooden leaf; 4 m wall modules (thin rounded merlons on the outer edge, putlog holes), half-round wall towers, end tower. Near LOD 3920 tris for all five modules, one 2048² set. `LandmarkKit.qosa_qala / city_wall` assemble them into one mesh; procedural fallback kept.
- Strict suite: 233 methods, ~5990 checks, 1 failure (the known `test_touch_scroll` full-run flake). Round 29: camera position, garage tabs, time of day picker, no auto lesson + Öyrən button, tour steps, gate modules.

## Update 0.15.1 (versionCode 36) — character voices in Azerbaijani, Göydələnlər in Blender
- **Character voices** (owner request): 7 racers × 15 short Azerbaijani lines (start, approach, pass, passed, hit, win, lose) in `data/voice_lines.json`, made with ElevenLabs `eleven_v3` (language `az`) by `tools/voice/gen_voices.py` (key in `_setup/`, never committed; raw mp3 cached in `tools/voice/out/raw`, so a rerun spends nothing). Voices: Gökçe (Yaska, owner's pick; Leloyun pitched higher), Natiq Alasgar (HavHav), Abbas (Posi), Ibrahim Mammadli (Biçok), Deniz (Mestan, Çepiş); ffmpeg pitch shift + trim + loudnorm, mono OGG, 105 files, 2.5 MB. 3116 characters used (account 2298/40000 after).
- `VoiceDirector` (`scripts/racing/voice_director.gd`): **only the player's own racer speaks** (owner: rival lines would mix). GO → start line; player within 7 m behind a rival for 1.5 s → "approach", 10 s rest between such lines; overtakes → pass / passed; item hit → "hit"; finish → win/lose (interrupts). One speaker at a time, 3 s quiet gap, no line twice in a row. Plays on the SFX bus (project rule: `scripts/audio` untouched), so it also follows the "Səs effektləri" switch.
- Settings → Səs: new "Personaj səsləri" switch (`audio.voices_on`, default on, speech-bubble icon); with effects off its row says why nothing is heard.
- Autopilot check (desktop, 2 laps, 106 s): 12 lines before the approach rest; now fewer. Not listened to on a phone yet; Azerbaijani pronunciation of the v3 model was judged by the owner on the sample page only.
- Strict suite: 227 methods, 5953 checks, 1 failure (the known `test_touch_scroll` full-run flake; passes alone). Round 28 tests: line files, switch, settings row, SFX bus, one speaker, no repeat.
- Build: `_builds/YaskaRacing-0.15.1-v36-debug.apk`, **180.0 MB** (0.15.0: 160.6 MB; Göydələnlər Blender textures ~17 MB, voices 2.5 MB). Signed with the usual key (SHA-256 726cd353…6e25d9). Not tested on a phone.

## Update 0.15.0 (versionCode 35) — kart ownership flow, Dəniz sahili fully in Blender, landmarks
- **Kart flow (owner):** the first "Oyna" on a new profile opens "İlk maşınını seç": every racer, one free pick ("Bu mənimdir!"), then the lesson once. Races never ask for a kart again: city select / Bakı Kuboku / new cup start with the garage kart (`Game.start_race_with_selected`; time trial still alone). Garage → "Maşınlarım": all karts in a row, owned = tap to race with it (gold ring + ✓), locked = price, tap to buy with manat (the bought kart becomes active). Main menu shows the selected kart. Save v8 (`starter_chosen`; existing profiles are never asked); the owned list no longer forces HavHav in.
- **Landmarks in Blender** (`tools/blender/landmarks.py`, LandmarkKit / BakuExtras overrides): Government House (pointed arcade, double-height windows, stepped wings, giant portal with paired columns, four-tier tower with loggias, gilded spire), Carpet Museum (carpet lying on the halls and rolling up at one end, borders / medallions / diamonds), Crystal Hall (faceted glass shell with frame lines), TV tower (ribbed shaft, glazed pod, banded antenna), Crescent (proper crescent-moon outline, floor lines). Heydar Aliyev Center (self-lit smooth shell), Flame Towers (LED shader, re-shaped) and Flag Square (waving flag) keep their own shaders.
- Strict suite: 223 methods, 5770 checks, 1 failure - `test_touch_scroll` "tap still presses a row" fails only inside the full run (passes alone every time, before and after this release); a leftover state from an earlier test is suspected, not found yet. Waiting on the glide state did not fix it.
- Build: `_builds/YaskaRacing-0.15.0-v35-debug.apk`, **160.6 MB** (0.14.3: 92.5 MB): the new 2048² texture sets (city, seafront, skyline, landmarks) are the growth. Fine for sideloading; for Google Play this needs an AAB with Play Asset Delivery (or smaller sets) - Play's base download limit is lower. Signed with the usual key (SHA-256 726cd353…6e25d9). Not tested on a phone.

## 0.14.4 part (merged into 0.15.0) — Dəniz sahili in Blender
- Kids controls: holding the yellow "Avto" badge 1 s switches to manual driving (the setting hid every button with no way back).
- New baked sets: `city_props.py` (modern_a/b/c as Neftçilər-avenue sandstone blocks with rustication, arched shop fronts, awnings, framed windows, iron balconies, cornices, domes; the grandstand with varied cheering spectators, flags and a canopy), `seafront_props.py` (chevrons, tyre stacks, kiosk, umbrellas, boats, second flower bed, Baku Eye frame and ring), `skyline_props.py` after the owner's Baku photos (SOCAR-like twisted glass tower, crown tower with flared top / lattice pyramid / spire, stacked-cube tower, sloped glass slab, sandstone block with white-domed turrets, residential tower). The 180 box "CityBlocks" are now baked sandstone blocks / residential towers merged into one mesh; the six procedural glass towers are the new skyline. Flame Towers re-shaped fuller (stronger convex face, belly at a third of the height), LED skin shader kept. Bake cage / ray / AO distance are now per set (`K.CAGE`, `K.RAY`, `K.AO_DIST`).
- Every PropKit prop placed on the seafront is now a Blender model except the landmarks (Heydar Aliyev Center, Government House, Crescent, Carpet Museum, Flag Square, Crystal Hall, TV tower keep their procedural / shader models - already detailed; Flame Towers improved in place), the city wall / gate and the track meshes (road, barriers, terrain, sea).
- Measured (High, desktop GPU, Mobile renderer, autopilot seed 5, 40 s; procedural → current): primitives mean 504k → 357k by day (max 701k → 438k), 498k → 353k at night; draw calls mean 337 → 341. Screenshots `docs/screenshots/0.14.0/seafront_old_vs_new_{day,night}.jpg`.
- Strict suite: 222 methods, 5760 checks, 0 failures, 0 script errors. Not on a phone yet.

## Update 0.14.3 (versionCode 34) — lesson really shown once; lighter Baku Eye and clouds
- **Root cause of the repeating lesson (owner saw it again in 0.14.2):** `SaveManager._merge_into` keeps only keys that exist in the default profile, and the default `tutorial` dictionary only had `drift_done`, so `lesson_done` was dropped on every load since 0.13.0 — 0.14.2 wrote it at the start of the lesson but lost it on the next launch. Fixed by adding `lesson_done` to the defaults; save v7 marks it done for every profile that has finished a race. New regression test reloads the profile from disk (the old tests never did).
- Baku Eye cabins 10 × 18 → 6 × 12 segments (WheelRing 10,752 → 5,568 triangles, shadow caster); far clouds 12,880 → 8,120 triangles. Seafront High day primitives mean 374k → 362k, max 461k → 440k.
- **Buttons gone in a race (owner screenshot, yellow "Avto" chip):** Settings → "Uşaqlar üçün idarəetmə (Avto sürmə)" was on: the kart drives itself and every touch button is hidden; the hint says "tap NITRO" but NITRO only exists after buying the garage add-on, so the screen was empty with no way back from the race. Nothing turns it on automatically (only that switch). Now holding the yellow "Avto" badge for 1 s switches to manual driving for the race and turns the setting off (a short tap does nothing, so a small child cannot do it by accident); the settings hint says so.
- Tests: `tests/test_round27.gd` +2 methods. Full strict suite (before the badge change): 221 methods, 5756 checks, 0 failures, 0 script errors.

## Update 0.14.2 (versionCode 33) — owner fixes + mobile optimisation of the street props
Owner reports after playing 0.14.1:
- **Wheels spun far too fast (most visible on Yaska, the player's kart):** the true rate at race speed is ~106 rad/s, more than 90° per frame, which reads as frantic / backwards spinning (chrome dish, lug nuts and sidewall text strobe even with the 0.14.0 tread blur). `KartVisual.MAX_WHEEL_RATE` caps the visible spin at 19 rad/s (~3 turns/s); above ~6.5 m/s the tread blur is full.
- **The first lesson came back every time:** `lesson_done` was only written when all three steps were completed, so leaving the lesson (pause → menu) or a lap ending first brought it back on the next "Oyna". It is now remembered when the lesson starts (and still when it completes). After it: mode select → city select, as designed.
- **Any kart could be raced without buying it:** the v3→v4 save migration (0.8.3) gave every old profile the whole roster for free. Save v6 takes that back: a profile owning (nearly) every kart keeps the starter kart (HavHav) and the kart it races with; profiles with real purchases are untouched, balance untouched. Kart select now lists **only owned karts** plus a green "+" card that opens the garage, where the "Yeni maşın" card sells the next kart for manat.
- **Mobile optimisation (High stays High):** profiling showed the seaside balustrade (372 triangles × hundreds) and the Baku lamp (978 triangles, 3 materials, shadow caster) dominating; they, the palms, plane tree, pine, cypress, flower beds, bollards and benches are now baked single-material Blender models (`tools/blender/street_props.py`, `flora_props.py`): baluster 372 → 128, lamp 978 → 584, palm 1,154 → 660 (3 → 1 material), flower bed 788 → 312, bollard 420 → 112, bench 280 → 72. Lamp globes glow from the orm mask driven by TimeOfDay's lamp level. Measured (High, day, desktop GPU, Mobile renderer, autopilot seed 5; procedural → baked karts + props, primitives mean): seafront 543k → 374k, downtown 373k → 247k, old_city 679k → 308k; draw calls unchanged.
- Tests: `tests/test_round27.gd` (3 methods, 11 checks); updated the old ownership tests (round 7, 8, 17) to the new rule. Full strict suite: 220 methods, 5753 checks, 0 failures, 0 script errors.
- Build: `_builds/YaskaRacing-0.14.2-v33-debug.apk`, apksigner verified (SHA-256 726cd353…6e25d9).
- Known: an existing phone profile loses the karts it got for free (keeps HavHav + the selected kart); `test_touch_scroll` failed once in a full run but passes alone (timing flake, also before this change); no phone FPS yet.

## Update 0.14.1 (versionCode 32) — all seven karts + Old City houses / Maiden Tower as Blender models
- **Old City props** (`tools/blender/oldcity_props.py`, 4096² bake → one 2048² set in `assets/models/oldcity/`): house_a..d and maiden_tower keep PropKit's footprints, heights and +Z facade (placement, occluders, AoMap unchanged). Houses: bevelled stone block, plinth, cornice and parapet, arched door / shop / windows with stone surrounds and sills, a window on each side wall per floor, the wooden şüşəbənd balcony with mullions, side posts and carved diamonds, domes / roof kiosks. Stone relief = Cycles Voronoi bump baked into the normal map (no dense geometry). Tower: tapering body, 14 masonry courses, beak buttress, parapet, slits, door, rock base (4,368 → 1,811 triangles).
- `PropKit.GLTF_PROPS` overrides those ids (one surface = one draw per MultiMesh chunk instead of three; `@lo` from the far glTF); `prop_baked.gdshader` multiplies the world-space limestone texture back in on stone (albedo alpha mask, relative to its mean colour E3CEA4, faded beyond 60 m) and lights window glass at night (orm alpha, `PropKit.set_window_glow` from `TimeOfDay`). `--no-gltf` turns props off too.
- Low houses: house_a 580 → 1,084, house_b 1,360 → 1,576, house_c 676 → 784, house_d 1,120 → 1,424 triangles (more detail, but 1 draw instead of 3).
- **Measured** (old_city, Mobile renderer, desktop GPU, autopilot seed 5, `--perf-every=2`, procedural → glTF karts + props): primitives mean 358k → 216k by day, 347k → 213k at night; draw calls mean 306 → 306 / 305 → 303. Screenshots `docs/screenshots/0.14.0/oldcity_old_vs_new.jpg`.
- Tests: `tests/test_round26.gd` (5 methods, 143 checks). Full strict suite: 217 methods, 5762 checks, 0 failures, 0 script errors.
- Build: `_builds/YaskaRacing-0.14.1-v32-debug.apk`, **84.0 MB** (0.14.0: 43.6 MB; +39 MB are the baked ETC2 texture sets: 7 karts × 1024² + Old City 2048²), apksigner verified, SHA-256 726cd353…6e25d9. Size could be cut later (e.g. 512² rival sets, RG-only ORM for karts).
- Known: houses read a little paler than the procedural ones in strong sun; the tower's shaded side looks bluish under the sky; seafront / downtown props are still procedural; no phone FPS.

## 0.14.1 part 1 — all seven karts as Blender models
Owner: convert every kart + driver like Yaska, part by part. Shared pipeline `tools/blender/kart_common.py` (helpers, wheels, steering, eyes, legs, bake, export) + one short script per racer (`yaska_star.py`, `havhav_buddy.py`, `posi_bamboo.py`, `bicok_amber.py`, `leloyun_hop.py`, `mestan_velvet.py`, `cepis_cloud.py`); `tools/blender/fix_imports.py` sets the phone import options; `tools/kart_stats.gd -- <id> [procedural]` counts triangles. `KartModel` now also maps `EarL/EarR` (animal ears) and `Tail` to the AnimalDriver pivots.
| racer | kart | near tris procedural → glTF | far tris | draws |
|---|---|---|---|---|
| Yaska | Yaska Star | 14,804 → 11,038 | 4,772 → 1,846 | 12 |
| HavHav | Buddy Rally | 12,684 → 10,766 | 3,890 → 1,785 | 13 |
| Posi | Bamboo Sprint | 12,436 → 10,882 | 3,534 → 1,751 | 12 (13) |
| Bicok | Amber Dash | 11,876 → 8,670 | 3,384 → 1,534 | 13 |
| Ləlöyün | Hop Rocket | 12,728 → 9,268 | 3,370 → 1,560 | 12 (13) |
| Məstan | Velvet Slide | 12,064 → 8,442 | 3,568 → 1,474 | 13 |
| Çəpiş | Cloud Booster | 15,024 → 11,826 | 4,120 → 1,793 | 12 (13) |
Each racer adds one 1024² texture set (ETC2 in the APK, ~3.5 MB per racer incl. mipmaps; 7 sets ≈ 24 MB of VRAM if all are on screen). Panda, rabbit and lamb tails hide behind the seat, so they have no mesh (one draw less). Screenshots: `docs/screenshots/0.14.0/all_racers_new.jpg`, `blender_<racer>_front.jpg`. Strict suite: 212 methods, 5619 checks, 0 failures.
Known / not verified: designs are the scripted first pass (owner has not reviewed HavHav→Çəpiş yet); eyes share one style (lashes on every racer); small AO smudges where ears touch heads (Posi); APK not rebuilt; no phone FPS.

## Update 0.14.0 (versionCode 31) — Blender pilot: Yaska Star + Yaska
Plan step 1 + 3 on the owner's Windows PC (RTX 3070). Owner's art calls: CTR-Nitro-Fueled-like quality (own design), 12-15k triangle budget + normal map, two brown side braids, brighter pink/purple metallic kart.
- **Local toolchain checked:** Godot 4.4.1 + templates, Temurin 17, SDK 34 / build-tools 34.0.0, adb 37. Godot's debug keystore now points to `%USERPROFILE%/.android/yaska-debug.keystore` (copy of `_setup/`; the old `debug.keystore` files there are other keys and were left alone). Strict suite on real GPU before any change: 205 methods, 5542 checks, 0 failures. `_builds/YaskaRacing-0.13.0-v30-local-debug.apk` signed with SHA-256 726cd353…6e25d9 (apksigner v1/v2/v3 verified).
- **Model:** `tools/blender/yaska_star.py` builds a high model (143k triangles: tyre tread, sidewall "YASKA", hair strands, face decals) and the game model from the same parametric surfaces, one 1024² colour/normal/ORM bake (Cycles OptiX, ~90 s). Game model 11,038 triangles / 12 draws (procedural Yaska Star 14,804 / 12), far LOD 1,846 (was 4,772). Parts are named after the procedural rig pivots, so wheels, steering, head, eyes (blink), braids (swing), arms (grip) use the existing animation code unchanged (`KartModel._attach_gltf`, `AnimalDriver.rig_only`). New shader `kart_baked.gdshader` keeps the painted-toy look (saturation, rim, clear-coat, camera dither) and supports garage paints through a baked mask. Missing glTF -> procedural fallback; `--no-gltf` for A/B.
- **Tyre strobing fix (owner spotted it in the test windows):** the new chevron tread turned more than one block per frame at speed and looked like shaking. Confirmed with 8 consecutive 60 Hz frames; tyres now blur their tread with spin speed (`spin_blur`), and the atlas is dilated so the blur / far mipmaps never pick up the background. `docs/screenshots/0.14.0/tyre_burst_*.jpg`.
- **Measured (Mobile renderer, desktop GPU, seafront, autopilot seed 5, `--perf-every=2`):** draw calls mean 291 -> 291 (day), 289 -> 290 (night); primitives mean 346k -> 335k (day), 342k -> 331k (night). Phone FPS: not measured (no phone attached).
- Screenshots: `docs/screenshots/0.14.0/` (old vs new close-ups and race, Blender previews). Yaska colours in `yaska.tres` follow the new body (primary `E8409E`, trim `8B3FD9`).
- Build: `_builds/YaskaRacing-0.14.0-v31-debug.apk` (43.6 MB), apksigner verified, SHA-256 726cd353…6e25d9, package az.bakuturbo.game 31 / 0.14.0; model textures packed as ETC2; reference images not in the APK. Not installed on a phone yet.
- Tests: `tests/test_round25.gd` (7 methods, 76 checks). Full strict suite: 212 methods, 5618 checks, 0 failures, 0 script errors.
- Known / not verified: scripted, not sculpted — the face is clean but simpler than CTR's hand-made characters; eyes read bluish under the blue menu lighting (the old procedural eyes do the same: clear-coat reflects the sky); text decals are small at 1024² ("YASKA" on the pods is barely legible up close); cosmetic garage parts (spoiler, crown, …) are still procedural and placed for the old body; gold rims part does not change the glTF rims; Godot's auto mesh LODs for 0-28 m not inspected visually; no phone check. Other six karts unchanged until the owner approves this look.

## Update 0.13.0 (versionCode 30) — one release with the rest of the approved list
Owner asked for one combined APK instead of one per step. Contents:
- **Wordless hints:** steering = a hand tapping ◀ and ▶ in turn; drift = a hand holding DRIFT while a ring fills, then letting go with a burst (`TapHint` modes "alternate" / "hold"); near the bottom edge the hand comes from above. Keyboard/controller keep the sentences.
- **Rival portraits** (`RivalStrip`) under the star pill: the racer just ahead (green ▲) and just behind (red ▼) as animal portraits, quick races only.
- **Contact shadows** (`AoMap`): while the race loads, a 1024² top-down darkening map is painted from every instanced prop / landmark footprint (seafront 439 blobs, 26 ms; downtown 201, 21 ms) and read by the ground, road, prop (`vcolor`) and tower shaders through global uniforms - zero extra draw calls. Honest note: the effect is subtle at race-camera distance; it shows mostly at the foot of walls and trees.
- **Wet road at night:** road roughness ×0.42 and 14 % darker at night, plus warm lamp reflection streaks on the asphalt (one MultiMesh aimed at the camera in the vertex shader).
- **Cartoon outline** on the kart body and driver (inverted hull `material_overlay`, near LOD only, off on Low). Same draw-call count measured (222 → 222 in the mobile renderer); it does add vertex work for those parts.
- **First lesson** (`LessonDirector`, ~30 s): the first "Oyna" on a new profile starts a short seafront race with 2 easy rivals: steer → drift → use a nitro, each shown with the hand; each step also ends by itself after 9-11 s so nobody gets stuck; three dots fill; "Əla!" then mode select. Replayable from mode select ("Dərs"). Remembered (`lesson_done`).
- **Sticker album:** 12 free Baku stickers rendered from the game's own models (`tools/gen_stickers.gd` + `.py`), unlocked by total stars (3 → 250), new tab "Albom" in Mükafatlar with "Yeni!" badges, new stickers shown with their picture on the results. No purchases, no randomness.
- **New city İçərişəhər** (`old_city`, 757 m, 2 laps): Boulevard start straight by the sea through Qoşa Qala into narrow 15 m cobbled streets, an S-bend, the Maiden Tower in the middle of a dense block of Old City houses with carpets, market umbrellas, the Flame Towers on the far hill. 6 checkpoints, 2 boost pads, 4 item rows, 7 trophies, city card, works in Yarış / Rekord / daily. Autopilot: all 6 karts finish a lap in 25-28 s with 0 respawns (2 seeds). Not in Bakı Kuboku yet.
- Fixes: `Progression` per-track trophy names no longer assume "second track = downtown".
- Tests: `tests/test_round24.gd` (8 methods, 148 checks). Full suite (strict runner): 205 methods, 5542 checks, 0 script errors; the first run had 7 failed checks, all old tests that hard-coded "2 cities" / "2 reward tabs" (round 20, round 7) - updated to 3 and re-run: 0 failures.
- Known / not verified: no phone - all of the above is checked in the Mobile renderer on software Vulkan only. The Old City has no night-specific extras beyond the shared ones. Sticker art is generated from low-poly models (matches the game, not hand-drawn). The lesson uses existing SFX only (audio untouched).

## Update 0.12.0 (versionCode 29) — finish replay, wordless item hint, strict tests
First batch of the owner-approved list (replay, less text in the HUD, test runner).
- **Winner's finish replay** (`FinishReplay`): after the 3.4 s celebration the camera shows the winner crossing the line (3.6 s before → 1.4 s after, slow motion near the line, ~6 s), cinema bars, "⟲ TƏKRAR" chip and a big "Keç" (skip) button; then the results. If the winner crossed too long ago (> buffer), the player's own finish is shown. Karts are moved from a 15 s recording with their physics paused and restored exactly afterwards. Off in the tutorial. This was "deferred" since 0.10.1.
- **Less text in the HUD:** the new item appears as its picture + name in a pill (no "[Əşya: …]" brackets); on touch screens the first "use the item" hint is a pulsing ring and a tapping hand on the ITEM button instead of a sentence (keyboard keeps the sentence).
- **Strict tests:** `tools/run_tests.py` runs the suite and fails any test method that printed a SCRIPT ERROR (Godot 4.4's runner reported such aborted methods as PASS). Checked on the 0.11.1 copy: it flags `test_round9` (5 errors) with exit 1; on 0.12.0 it exits 0.
- Tests: `tests/test_round23.gd` (7 methods, 64 checks: buffer cap and span, target choice, slow motion, play → skip → restore, play to the end, restart during the replay, off in tests/tutorial, tap hint, item pill, strings). Full suite (strict runner): 197 methods, 5377 checks, 0 failures, 0 script errors.
- Screenshots (Mobile renderer, lavapipe): `docs/screenshots/0.12.0/` (replay, results after it, item pill + tap hint).
- Known / not verified: no phone — replay smoothness and the tap hand on a real screen need a device check. The replay uses the trackside/cinematic shots, which can still be briefly blocked by small decor without collision (known since 0.10.2). Rival karts' driver animations keep their last pose during the replay (only transforms and wheel speed are replayed). Steering/drift first-race hints are still sentences (next batch).

## Update 0.11.2 (versionCode 28) — phone optimisation, night polish
Owner request: "super-optimise for Android, raise graphics quality". New build box (Linux): Godot 4.4.1 official + templates, OpenJDK 17, debug keystore copied from the owner (SHA-256 726cd353…6e25d9). Android SDK pieces come from Ubuntu packages (apksigner 31.0.2, zipalign, adb) laid out as build-tools/34.0.0 — Google's servers are unreachable here, so no sdkmanager / Android Studio / emulator (no KVM either). Screenshots now use the **Mobile renderer** on software Vulkan (lavapipe) under Xvfb — closer to the phone than the old Compatibility shots, but still not a phone.
- **Shaders:** road, ground and water no longer compute hash value noise per pixel; one mipmapped tileable texture (`assets/textures/noise_value.png`, `tools/gen_noise.py`, global uniform `yaska_noise`) replaces it (road ~16 hashes/pixel → 4 fetches; ground ~8 → 2; water ~8 → 2). Mipmaps also remove far-distance shimmer. Ground: vertex colour sRGB→linear per vertex (was 2 `pow`/pixel). **Not measurable here:** lavapipe runs on the CPU where texture fetches are dear and ALU is cheap, so the frozen-frame A/B was within noise (269–281 ms vs 270–275 ms). The gain is an estimate until measured on the phone.
- **Kart shadows:** shadows-only low-detail proxy (`ShadowProxy`, far-LOD mesh) instead of the full model; no kart shadows beyond 28 m (blob stays). Kart shadow-pass primitives at the start grid 58k → 9.5k; whole frame 441k → 401k (−9 %), draw calls unchanged (225).
- **Render height cap** on phones (`render_height` Low 648 / Medium 864 / High 1080): 1080p phones unchanged, 1440p phones render 31–44 % fewer 3D pixels. FSR stays Forward+-only (engine error on Mobile — the old comment was right; tried and reverted).
- **Tried and rejected:** MSAA 2× instead of FXAA on Medium looked more jagged in Mobile-renderer screenshots (`docs/screenshots/0.11.2/aa_compare.png`); Medium stays FXAA.
- **Night (NightGlow):** warm light pools under every street lamp (one MultiMesh: seafront 24, downtown 105), head + tail lamps on every kart (one merged mesh each), soft headlight cones in front of rivals (fade near the camera), darker navy sea with moon glints (global `yaska_night`), night ambient 0.6 → 0.42, player headlight 4 → 6.5 / 34 → 38 m. No extra real lights (the Mobile renderer limits lights per mesh). Sunset gets a faint version.
- **Settings v5:** fills `render_height` from the stored preset; all other stored values kept.
- **Fix:** `ResultsScreen.show_results` crashed when the screen had no race (UI tests r5/r7/r8/r9): 24 script errors per suite run, and the retry button text/icon/focus lines were never reached in tests. Now guarded and tested.
- **Measured** (`--perf-every=2`, autopilot seed 5, 40 s, Mobile renderer, mean / max; before → after):
  | track | preset | draw calls mean/max | primitives mean/max (Δ mean / Δ max) |
  |---|---|---|---|
  | seafront_sprint | low | 197/268 → 197/268 | 180k/266k → 180k/266k (+0 % / +0 %) |
  | seafront_sprint | medium | 253/325 → 253/325 | 323k/464k → 310k/424k (-4 % / -9 %) |
  | seafront_sprint | high | 316/428 → 316/428 | 537k/774k → 509k/689k (-5 % / -11 %) |
  | downtown_towers | low | 203/253 → 203/253 | 106k/150k → 106k/150k (+0 % / +0 %) |
  | downtown_towers | medium | 263/345 → 262/345 | 226k/329k → 208k/281k (-8 % / -15 %) |
  | downtown_towers | high | 305/437 → 304/425 | 412k/619k → 376k/519k (-9 % / -16 %) |
  Low is unchanged (no real-time shadows there). Draw calls unchanged everywhere; the savings are shadow-pass triangles.
- Tests: `tests/test_round22.gd` (9 methods); full suite 190 methods, 5313 checks, 0 failures, 0 script errors (0.11.1: 24 script errors per run). `test_round18` night-fill threshold 0.6 → 0.4 (deliberate darker night; readability now from headlight/pools/cones, see sheet). Screenshots: `docs/screenshots/0.11.2/sheet.jpg` (0.11.1 vs 0.11.2).
- Known / not verified: no phone was attached — real FPS, thermals and the shader gain need the Mi 12 Lite (Developer → Performance overlay writes `perf_*.csv`). Lamp pools are flat quads 0.32 m above the lamp base (no collision under the promenade to ray-cast), so on a slope edge one may float or clip slightly. Rival cones are flat on the kart plane and can poke through a crest for a moment. Git history before this round was uncommitted since 0.6.0; committed now as one 0.7–0.11.1 commit. The test runner still reports a method as PASS when it aborts on a script error (seen here, worked around in r22) — worth a runner fix.

## Update 0.11.1 (versionCode 27) — "Şəhəri seç": city choice in the normal flow
- Owner feedback: the normal Oyna flow always loaded the seafront; the new city was only reachable via Race Setup. Now Oyna → Rejim seç → Yarış / Rekord → **Şəhəri seç** → kart select → race.
- Şəhəri seç (`scripts/ui/city_select.gd`, `scenes/menus/city_select.tscn`, `Game.State.CITY_SELECT`): two big picture cards (in-game renders `assets/ui/cities/<id>.jpg`, made with the new debug flag `--no-hud`), city name, chips for lap length (new `lap_flag` icon), best lap and city trophies (x/7), a mini map in the corner and a "Sür!" pill. Pulsing red "Yeni!" badge on Göydələnlər şəhəri until a race there starts (profile `played_tracks`; 0.11.0 saves with a downtown record/finish count as played). One tap picks + continues; the last city is pre-selected and focused.
- Kart select header shows the city about to load (thumbnail + name, tap to change). Back from kart select returns to Şəhəri seç (cup still goes back to modes).
- Daily card on Rejim seç shows today's city (thumbnail + name). Cup keeps its fixed 3-race sequence; Drift məktəbi is always on the seafront.
- Sync: Settings `gameplay.track` is the single source; Race Setup tabs (now using the same city names) and the city cards read/write it; `Game.reset_series()` restores it after cup/daily races (the cause of "always seafront" after a daily/cup).
- Shared helpers: `CityCards` (`scripts/ui/city_cards.gd`), `TrackList.CITY_KEYS` / `city_key()`; strings CITY_TITLE, CITY_NEW, CITY_SEAFRONT, CITY_GO.
- Tests: `tests/test_round21.gd` (8 methods, 59 checks); full suite 181 methods, 5184 checks, 0 failures. Screenshots: `ui_audit_round21/sheet.jpg`.
- Known: at 4:3 the city cards have some empty space under the chips; card art is a static render (not live 3D); with only two cities the screen has no scroll/paging yet (needed if more cities are added).

## Update 0.11.0 (versionCode 26) — new map "Göydələnlər şəhəri", buying karts with manat, polish
- New track `downtown_towers` (~1053 m, 6 checkpoints, 2 boost pads, 1 ramp, 4 item rows) in the same Baku city: Tower Avenue lined with 16-floor (57.6 m) glass skyscrapers in 4 shapes (square + antenna, setback + roof garden, round + gold crown, slab + fins), shader facades (floor bands, mullions, fresnel, random lit windows at night), 4 malls (ŞƏHƏR, GÜNƏŞ, DƏNİZ, BAKI MALL) with signs, glass fronts, entrances, canopies and parking lots with cars, and a drive-under mall bridge (8 m clearance, glowing ceiling strips). `DowntownDecor` (`scripts/track/downtown_decor.gd`), `CityKit` (`scripts/track/city_kit.gd`), `assets/materials/skyscraper.gdshader`, `data/tracks/downtown_towers.json`, `TrackList` (`scripts/track/track_list.gd`).
- Works in all modes: track picker tabs + mini preview in race setup (saved as `gameplay.track`); Bakı Kuboku race 2 is downtown (3 laps), race 3 seafront at sunset; daily challenge picks the track per date (time goal × `LAP_SCALE`); separate records, ghosts and 5 "Göydələnlər:" trophies.
- Buying karts: Qaraj has a "Yeni maşın" card at the top with an "Al  X ₼" button (next locked kart), confirm / not-enough dialog (`KartBuyDialog`), sparkle + "Sənindir!" after buying; kart select shows "Al X ₼" on locked karts. End-to-end tested (balance drops, kart owned, saved).
- Fixes: main menu sea/skyline/clouds visible again, bigger glossy gear; warm kart-select floor; cinematic camera cuts when a prop occludes the kart (TrackDecor occluder boxes + `segment_hit`), the t≈15 s blob is gone.
- Perf (autopilot, `--perf-every=2`, 1280×720, software GL; mean / max): downtown High 534/739 dc, 436k/548k prims (seafront 563/762, 583k/750k); Medium 380/500, 251k/298k (seafront 377/458, 351k/428k); Low 270/373, 122k/145k (seafront 270/354, 198k/254k).
- Tests: `tests/test_round20.gd` (9 methods, 317 checks); full suite 173 methods, 5125 checks, 0 failures. Screenshots: `ui_audit_round20/sheet.jpg`.
- Known: Medium/Low peak draw calls on downtown slightly above seafront; malls have no interiors; no road traffic; the daily card does not name the track; kart select still uses its own buy dialog code; mall bridge side blocks are plain glass.

## Update 0.10.2 (versionCode 25) — new main menu, mobile performance, cinematic camera
- Main menu rebuilt after the owner's mockup: busier Boulevard backdrop (benches, ornate lamps, flower beds, palms, balloons, sailboats, bigger Baku Eye), warm paving, punchier colours; kart on a glowing blue checker turntable (shader `assets/materials/turntable.gdshader`, neon ring, bulbs, 4 floor spotlights + a shadowless SpotLight); logo with a bobbing crown and a wooden-plank subtitle; round gear (Ayarlar) top-left; purple title pill (`Progression.title_for`) + balance pill with a green "+" (opens the garage) top-right; 4 chunky buttons along the bottom with icons above the labels: Oyna (→ mode select), Qaraj, Mükafatlar, Ayarlar. Staggered pop-in (scale), Play "breathes", icon bounce on press. 4:3 keeps the 16:9 horizontal view (camera KEEP_WIDTH) so the kart is never cut off. Sensor-landscape only, so portrait does not apply.
- Credits moved into Settings → Dil ("Müəlliflər" button); Credits' back returns to Settings.
- Performance: decor chunks 140 → 70 m plus a far LOD (low-segment meshes, no shadows) beyond `TrackDecor.lod_for(decor distance)` (~109 m on Medium); far kart LOD (`KartVisual.KART_LOD` 28 m, ~3× fewer triangles); cheaper clouds; Medium shadow distance 60 → 45 m; dynamic resolution on Low/Medium; "Avto" picks the tier from GPU name + core count on mobile and steps down one tier for good (`graphics.auto_cap`) when a race cannot hold its frame rate. 60 fps cap with 30 via the battery saver (unchanged). Profiling: `--perf-report=T`, `--perf-top`, `--hide=Node[:mm|single|name]`.
- Measured (race t=12 s, 1280×720, compatibility renderer on software GL — fps not meaningful): Low 308 dc / 380,070 prims → 328 / 287,690; Medium 397 / 578,036 → 417 / 432,880; High 527 / 818,530 → 540 / 616,688 (≈ −25 % primitives; draw calls +2–6 % from the smaller chunks and LOD copies). Shadow casters, particles unchanged.
- Cinematic camera ("Sinematik", 5th view in the camera cycle / Settings): TV shots that cut every 3–5 s — low trackside (fixed, zooms as the kart passes), eased helicopter orbit, front chase facing the kart, fly-by framing the Flame Towers / Heydar Aliyev Center / Crescent / Old Tower behind the kart. Ray-checked against collision geometry, camera kept within 36 m of the kart. Look-back still shows the normal chase view.
- Tests: `tests/test_round19.gd`; full suite 164 methods, 4803 checks (the 16 failures of the first run were the old menu-fit test catching the slide-in animation, fixed by animating scale; re-run of the affected files 0 failures). Screenshots: `ui_audit_round19/sheet.jpg`.
- Known: decor without collision (small props, billboards) can still pass in front of the cinematic camera for a moment; the menu skyline/sea is less visible than in the mockup (the flower beds hide most of it); real-device fps not measured.

## Update 0.10.1 (versionCode 24) — time of day
- Race setup has three big buttons: Gündüz / Gün batımı / Gecə (default day, saved in settings `gameplay.time_of_day`).
- Sunset: low warm sun, purple-pink sky, long shadows. Night: dark blue sky, moonlight, glowing lamps and windows, player headlight (SpotLight, no shadows, plus emissive bulbs).
- Flame Towers LED show (flames + Azerbaijani flag, cross-fade) at sunset/night only; HAC soft glow; Government House warm floodlight.
- Baku Cup race 3 is at sunset; cup races 1-2 and the daily are always day.
- Deferred: skipping the winner finish replay. Known: night ambient is flat colour, lamps glow but don't light the ground, sea stays bright.

## Update 0.10.0 (versionCode 23) — game modes
- Mode select: 4 big cards (Sərbəst yarış, Bakı Kuboku, Rekord, Gündəlik tapşırıq) with status chips (cup prize / "Yarış 2/3 · davam", best lap, daily reward / ✓ done); Drift məktəbi as a small button.
- Bakı Kuboku: 3 races, points 10/8/6/4/2/1, animated standings screen (bars + counters grow, rows slide to new places), podium with trophy and prize. Resume after restart; damaged state resets cleanly. See TUNING.md.
- Rekord: ghost + live delta (ghost format 2), lap delta, record bonus once; kids mode does not save records.
- Daily challenge: deterministic per date, 1,50 ₼ once per day.
- Fix: steering hint waits until START!/TURBO START text is gone (`RaceHUD.steer_hint_ready`) — never overlaps.
- Fix: ghost recording start time was not reset on autopilot/kids laps.
- Save version 5 (adds `cup_history`, `daily_challenge`; v4 saves migrate).
- Tests: `tests/test_round17.gd`. Screenshots: `ui_audit_round17/`.
- Known limits: ghost is the best single lap, not a full race; cup has no reverse-direction/time-of-day variation (none exists in the game); quitting an unfinished cup race lets the player re-run it (scores only on finish); daily time target is tuned from autopilot laps.

## Update 0.9.8 (versionCode 22) — big landmarks remodelled
- Heydar Aliyev Center (`LandmarkKit.hac_point/hac_height`): one smooth lofted white shell (104×30 grid, smooth normals), 196 m long, 54 m peak: rises from the plaza on the left into a tall forward-curling peak, dips, rolls into a lower second crest and sweeps back into the plaza on the right. Dark curved glass wall recessed ~10 m under the overhanging lip. White skin has a little emission so it stays white on the shaded side. Plaza with terraced lawns and pools (kept clear of the road).
- Flame Towers: three separate teardrop-plan flames (120/109/106 m = 182/165/161 × 0.66), widest low, long taper to a sharp tip leaning over the inner side, convex faces turned outwards, ~30 m gaps; triangle of 34 m circumradius; floor lines + mullions in the glass shader; group moved 45 m back (site −175, −435) so the tips show from the Old City approach. Podium is a low stone cone (no pale disc).
- Government House: 176 m sand/beige symmetric block — ground-floor pointed-arch arcade, two-storey tall windows with sills, projecting side wings with stepped arched tops, projecting centre with a giant pointed portal between paired columns, 4-tier stepped tower with arched loggias, spire and flag (~85 m), crenellated parapets. New plain colours `sand`, `sand_light`, `sand_shade`, `window_dark` (merged into the vertex-colour surface).
- Baku Eye: 60 m wheel was already right; cabins now pastel and ~2.5 m.
- Debug: `--landmark-closeups` captures front three-quarter shots of the three landmarks and the wheel.
- Tests: `tests/test_round16.gd` (HAC wave profile and size, flame ratios/gaps/taper/tip, Government House size/symmetry/far LOD, wheel size); road clearance (round 4) passes with the larger models. Full suite: 141 methods, 4261 checks, 0 failures.
- Screenshots: `ui_audit_round16/sheet.jpg` (round 15 vs 0.9.8 per landmark), `ui_audit_round16/final/`. Compatibility renderer only.

## Update 0.9.7 (versionCode 21)
- Flame Towers: daytime LED skin off, plain blue glass by day.
- Old City walls: base course, rounded merlons, half-round towers every ~24 m; warmer sandstone limestone with block variation/grime (less overexposed).
- Shadows: opacity 1.0, ambient 0.4, sun 1.75, blur 1.2. Softer sky gradient/sun halo, softer clouds.
- Plane trees and stone pines mixed into tree placements.
- Caspian horizon glance view added to landmark views (ships/platforms visible, faint).

## Update 0.9.6 (versionCode 20) — shadows, Baku ambiance, rendering
- Game modes work (planned 0.10.0) is paused; nothing of it ships here. Parked notes in `/workspace/game/wip_modes_r13/`.
- Shadows: soft PCF filter per preset (`RaceEnvironment.SHADOW_FILTER`: Medium very-low, High low, Ultra medium; project mobile default now soft-very-low), Medium uses 2 PSSM splits at 60 m (was orthogonal 55 m), High 4 splits at 100 m, tuned bias (0.06 / normal 1.5) against acne; kart blob contact shadow stronger on every preset (0.42, 0.6 on Low); less ambient fill (0.5) so shadows read.
- Rendering: ACES tonemap (exposure tuned), stronger aerial perspective; road shader gets roughness variation, polished racing line, worn paint and repair patches.
- Baku ambiance (`scripts/track/baku_extras.gd`): Baku TV Tower on the northern hills, Crystal Hall (faceted glass ring) on the bay, oil platforms with flare and freighters on the Caspian, boulevard triple-globe cast-iron lamps (replace the old lamp everywhere), Azerbaijani flag poles along the promenade, blue street signs in Azerbaijani (Neftçilər prospekti, Dənizkənarı bulvar, İçərişəhər, Azadlıq meydanı, Üzeyir Hacıbəyov küç.).
- Tests: `tests/test_round14.gd` (extras present, signs carry AZ names, shadow modes per preset, ACES); road-clearance check of round 4 covers the new pieces. Screenshots (before/after, landmark views): `ui_audit_round14/sheet.jpg`.
- Limits: screenshots come from the GL Compatibility renderer (no Vulkan on the build box), so the Mobile-renderer look on phones (soft filter, ACES) is not visually verified; existing landmark meshes (Flame Towers, Heydar Aliyev Center, Maiden Tower, Government House, Old City walls) were not remodelled; no reflection probes, SSAO stays High-only.

## Update 0.9.5 (versionCode 19)
- Kids controls ("Uşaqlar üçün idarəetmə (Avto sürmə)"): first, highlighted row in Settings → İdarəetmə (opens first from the main menu). Saved as `controls.kids_auto` (default off; old settings files load as off).
- When on, the player's kart is driven by its AIDriver (racing line, avoidance, stuck recovery/respawn), normal start (no stall), steering/gas/brake/drift buttons hidden and player input ignored; NITRO button still works. Steering tutorial hints are skipped.
- Balance: rivals use the easy profile, auto-driver uses easy skill at 0.9 speed scale (6-seed probe: places 1,1,1,2,2,4).
- Goals: drift / overtake / clean-lap goals swap to finish / stars / top 3 (`RaceGoals.kids_safe`). Money and goals pay normally.
- HUD: yellow "Avto" badge with child icon under the place badge. Debug flag `--kids`.
- Tests: `tests/test_round12.gd` (persistence, race picks setting, auto vs manual, touch ignored, full 3-lap auto race without long off-track or stalls, goal swap). Screenshots: `ui_audit_round12/sheet.jpg`.

## Update 0.9.4 (versionCode 18)
- Minimap readability fix: zoomed, player-centred radar view (~110 m ahead, ~160 m total), player at lower-centre, heading-up, tilted; clipped to the panel with a rounded border; thick track ribbon.
- Rival markers: 15 px coloured dots with white outline and place number, decluttered so packed karts don't stack; rivals out of view clamp to the panel edge as coloured arrows with their number.
- Tests in `tests/test_round11.gd` adapted (anchor, zoom, edge arrows, declutter); overlap tests unchanged. Sheet: `ui_audit_round11/sheet.jpg` (0.9.3 vs 0.9.4).

## Update 0.9.3 (versionCode 17)
- Minimap redesign (`scripts/ui/minimap_widget.gd`): tilted perspective "3D" look (2D projected, cheap on mobile), heading-up with smoothed stable rotation, fixed scale (no zoom while turning).
- Track drawn with drop shadow, white edge, asphalt, centre line, shortcuts, finish checker.
- Kart markers: shadow + white ring + paint colour, depth sorted; place numbers on 2 nearest rivals; player = gold arrow with white outline and pulse ring.
- Minimap larger (250x180), placed by `RaceHUD.place_minimap()` clear of controls at 1100–1600x720 and 1280x960.
- Tests: `tests/test_round11.gd` (marker mapping, player marker, no overlap with controls). Screenshots: `ui_audit_round11/`.

## Update 0.9.2 (versionCode 16)
- Fix: "TURBO START!" pop now shows below the START gantry/countdown.
- Golden hour: lower (30°) warmer sun, softer shadow blur, warmer horizon/ambient, glow threshold 1.0 (glow follows the Bloom/quality preset).
- Caspian water: golden sky-reflection tint at grazing angles + emissive sun glints (existing wave shader kept).
- Boost flames emissive (HDR) so glow picks them up.
- 4 gulls circling over the route (CPU-moved meshes, no collision), hidden on Low (decor distance 0).
- UI: dialog pop-in (kart shop, login popup), press bounce on every styled button.
- Already present (unchanged): kart gloss shader, driver steer/lean animation, offroad dust, flag vertex sway, grandstand crowd.
- Trimmed (cost/risk): shore foam line, palm sway (palms are batched into merged meshes), pedestrians, crowd cheering animation.
- Tests: tests/test_round10.gd.

## Update 0.9.1 (versionCode 15)
- Game feel (`scripts/racing/game_feel.gd`): turbo start (gas within 0.45 s of GO; ≤0.25 s full) with yellow flash + "TURBO START!", too early = stall wobble; AI sometimes does it.
- Drift sparks coloured by tier (blue → orange → pink), release burst in the tier colour.
- Speed lines also near top speed and during boosts, bigger boost FOV kick; new Settings → Graphics "Sürət effekti" switch (also off at effects density 0).
- Near miss: close fast pass without contact → "Yaxından!", small shake, +0.03 ₼ (driving cap).
- Barrier sparks on hit/scrape; landing squash/puff, boost flames, star bursts kept.
- Kart prices now rise with shop order (9 → 13 ₼, same total). Results "Növbəti yarış" is one compact chip row (shrinks on narrow screens), unlock chips single-line.
- aapt "android:required ... not an integer" is harmless: Godot writes the Vulkan uses-feature attributes as strings; aapt2 and Android parse them fine.

## Update 0.9.0 (versionCode 14)
- Kart shop: new profiles start with HavHav only; locked cards show price, "Al" button, confirm and "Pul çatmır" dialogs. Prices in `kart_shop.gd`; ladder in TUNING.md. Old saves keep all karts.
- 7-day daily login popup (day 7 big prize, streak resets on skip, hidden ad "double" hook).
- 3 race goals per race: live HUD tick, paid at race end, next goals shown on results.
- Save version 4. Tests: 116 methods, 0 failures.

## Update 0.8.3 (versionCode 13)

Game-style UI pass (owner feedback: windows looked like "code windows").
- Results: big place medal ("1-ci yer!"), podium rows with racer portraits
  (top 3 + player), time only for the player, animated manat count-up,
  star chip, NEW RECORD badge, at most 3 unlock cards (last "+N").
- Rewards: two big tabs — "Günlük tapşırıqlar" (3 task cards: icon, bar,
  reward chip, "Alındı") and "Kuboklar" (badge grid, silhouette when locked,
  next goal + bar, tap for tiers). Title is a header badge with one bar.
  Kart parts moved to the Garage (tap to fit/remove). Progression unchanged.
- Main menu: Oyna, Qaraj (new, opens the garage for the selected racer and
  returns to the menu), Mükafatlar, Ayarlar, Müəlliflər — equal-height
  stack; money chip + title badge top-right; tiny faint version.
- Garage: no description lines; paint price chip; parts row.
- Racer select: personality/“Xüsusiyyət” labels dropped. Settings: hint lines
  under rows removed (tooltips only). Mode cards: one short line. Credits:
  logo + short lines.
- Save v4: `owned_karts` (new profile: standard kart; old saves own every
  kart). Helpers `owned_karts()`, `is_kart_owned()`, `own_kart()`. Nothing
  is locked yet.
- Tests: tests/test_round7_ui.gd (results fit 16:9/19.5:9/20:9/4:3 + 1100x720,
  pick_rows/cards/count-up, daily claim single credit, trophy groups,
  rewards tabs, main menu order/fit/garage navigation, owned_karts
  migration). Full suite: 104 test methods, 3222 checks, 0 failures.
- Screenshots: ui_audit_round7/before and /after (1560x720).
- Audio untouched (diff against backup_before_round7).

## Update 0.8.2 (versionCode 12)

- New app icon: the colourful stacked "Yaska Racing" lettering (face/flag omitted so the text stays large) inside the adaptive safe zone, on a vivid pink→purple radial gradient with sunburst rays and speed streaks. Files: `assets/icons/adaptive_fg_432.png`, `adaptive_bg_432.png`, `launcher_192.png`. No other changes.

## Update 0.8.1 (versionCode 11) — "Yaska Racing"

- **Touch orbit fixed (root cause):** the 0.8.0 racer-select/garage orbit lived in `_unhandled_input` and reacted only to the touch-emulated mouse; the full-rect menu root Control (mouse_filter STOP) consumed those events in the GUI pass, so they never became "unhandled"; pinch never saw two tracked fingers (ScreenTouch never reaches `_gui_input`). New `scripts/ui/orbit_pad.gd` (topmost pad, `_input` for real touches, `_gui_input` for mouse/wheel/magnify, no double counting) gives 1:1 finger follow (`ORBIT_RAD_PER_PX = 0.0052`) and pinch zoom on both screens. Test: `tests/test_round6_touch.gd` (fails against 0.8.0, passes now).
- **More vivid colours:** central `scripts/effects/palette.gd` (material/kart/driver saturation, bluer sky, env saturation 1.3 / contrast 1.13), ground shader saturation, richer water. No extra render passes.
- Garage stat bars clipped to their track; menu stage spin inertia clamped.
- Azerbaijani strings proofread (tutorial steer hint and 9 others fixed).
- Verified not bugs: ₼ glyph renders correctly, balance has ₼, HUD position shows "4/6", red icon = brake button.
- **Rebrand to Yaska Racing:** new logo (main menu, boot splash), adaptive launcher icon, app name; `package/unique_name` unchanged so it updates in place. Start gantry sign reads "YASKA RACING".

## Update 0.8.0 (round 5: garage, manat economy, finish celebration) (2026-10-30)

- Racer select: the hero kart idles (bob/sway); drag x orbits, drag y tilts (clamped), pinch/wheel zooms (0,7–1,35), inertia then ease back after 2,5 s. Right panel input is untouched. New buttons under Start: "Qaraj" and "Yarış ayarları" (icon + text, H_BTN).
- Finish: the race ends for the player on the line crossing; the results open 3,4 s later (no longer waiting up to 18 s for the AI; unfinished AI get a projected "~" time). 1st place: "1-ci yer! QALİB!", confetti, fireworks, synthesized fanfare on the SFX bus. Other places: big wobbling "N-cü yer!".
- Results: compact 540 px panel docked right, 3 columns (no best lap), money row with breakdown, rewards collapsed into "+N mükafat", buttons outside the scroll and always visible (tested 16:9, 19.5:9, 20:9, 4:3).
- Garage (from racer select): paint, speed, engine, brakes, steering, tyres (5 levels), Nitro (fit + 3 levels) with preview bars. In-race Nitro touch button with a charge ring (keys N/H).
- Currency is now manat/qəpik (integer qəpik, save v3, 1 old coin = 2 qəpik). Driving income: drifts, boosts, overtakes, stars, clean laps. See TUNING.md for the tables and simulation. Rewarded-ad hook (`RewardedAds.provider`), no SDK.
- Audio: no existing file or behaviour changed; the new celebration sounds are generated at runtime.
- Known/simplified: AI does not use nitro; overtake pay counts only new best places; the main-menu balance has no icon.

## Update 0.7.2 (round 4: crash/collision bugs from the phone video) (2026-10-29)

- Kart-kart bump flip: karts no longer collide physically (capsule tops were treated as floor, launching and tilting the kart). Contact is RaceManager's flat push only; pushes are forced horizontal; KartVisual ground-align tilt is capped at 28 deg and roll/pitch at 20 deg.
- Grey slab / karts driving through the Heydar Aliyev Center: the 0.7.1 enlargement made the shell hang over the road (s ~700). HAC moved to (175, -285). New test checks every landmark and decor mesh/multimesh against the road corridor + barrier line.
- Barriers: collision is now a closed 2 m thick, 6 m tall block per segment, overlapping its neighbours by 0.35 m (no seams), with closed end caps, and the face sits 0.3 m inside the visual face so wheels stop at the barrier instead of inside it.
- Out of bounds: a kart (player or AI) beyond the barrier line or 2.5 m below the road for 1.5 s respawns at the last safe point facing forward (plus the existing instant rules).
- Wrong way: not raised while pinned/grinding a wall below 9 m/s.
- Sky streaks at the start: kart particle emitters and the Ferris wheel ring no longer use physics interpolation (they are updated per frame).
- Tests: tests/test_round4_bugs.gd (barrier max-speed drift probes, OOB respawn, kart contact tilt, wall grind wrong-way, barrier ends/corners, landmark/decor road clearance).

## Update 0.7.1 (landmarks closer to the real ones) (2026-10-29)

- Maiden Tower: 29.5 m × 16.5 m smooth tapering limestone cylinder (1.3× scale in game), subtle masonry courses, wedge buttress almost full height, flat top with a low parapet (no crenellations), few slit windows, small door; Old City houses kept 46 m away so it reads from the road.
- Flame Towers: three flame-shaped glass towers in the real 182/165/161 height ratio (120/109/106 m), the tallest at the back, convex faces outwards, blue glass with mullions; animated orange/red LED flames (glass shader `flame_led`, on when bloom or high shadows are enabled).
- Heydar Aliyev Center: white continuous shell with three waves, the highest lifted at one end, a curling lip over dark curved glass, on stepped terraces.
- Landmark screenshots hide the tutorial hint. Version code 8 / 0.7.1. Tests 78 methods / 2892 checks / 0 failures. Audio untouched.

## Update 0.7.0 (round 3: menus, controls bug, rewards, drift, landmarks) (2026-10-29)

Version code 7 / 0.7.0. Signed debug APK `/workspace/game/out/BakuTurbo-0.7.0-debug.apk`
(apksigner v1+v2+v3 verified, cert SHA-256 726cd353…6e25d9). Tests: 78 methods,
2892 checks, 0 failures. Audio assets and audio scripts are byte-identical to the
pre-round-3 backup (74 files). Desktop screenshots only, in `/workspace/game/ui_audit_round3/`.

- **Main menu**: four equal stacked buttons (Oyna / Mükafatlar / Ayarlar / Müəlliflər), player badge removed, coins + title + trophies + version bottom-left, desktop Quit is small at the top right.
- **Mode select**: three big centred cards side by side, no kart behind them, sized from the available space (checked at 2400x1080, 1920x1080, 1440x1080).
- **Auto-steer bug (root cause)**: the hidden "steer assist" was on by default and was forced on by the v3 settings migration. Its centre pull and edge correction steered the kart with no input, most visibly after a bump. Fix: default off, settings v4 migration turns it off, and the assist no longer pulls on its own. Touch: releases are processed while the controls are hidden, and a repeated press on the same finger releases the old button (no latched steering). Test: `tests/test_player_control.gd`.
- **Rewards**: `scripts/progression/progression.gd`: 12 paints (5…520 stars), 6 kart parts (by lifetime coins), 8 titles (by stars), 33 trophies (races, podiums, wins, drift boosts, stars, daily, driving school, per track and mode), 3 daily goals per day. New Rewards screen and unlock lines on results. Old saves are seeded from their stats (SAVE_VERSION 2, backward compatible). Test: `tests/test_progression.gd`.
- **Drift**: a subtle hop (3.0 m/s), a real slip angle that counter-steer reduces, speed mostly kept, smoke and skid marks while sliding, the camera follows the slide, subtle roll with no wobble, mini-turbo unchanged. See TUNING.md "Drift feel". Test: `tests/test_drift_feel.gd`.
- **Racer select**: every racer is shown in a 3/4 front view (drag rotates it, then it eases back).
- **Baku landmarks** (procedural, visible from the track): Flame Towers, Maiden Tower, Heydar Aliyev Center (existing, kept); new Government House (symmetric limestone block, stepped central tower, colonnade, arched loggias) in the infield facing the Boulevard straight; new Carpet Museum (half-rolled carpet building) in the west infield; Icherisheher entrance rebuilt as Qoşa Qala (two crenellated semicircular towers, a pointed arch over the road, blind side arches) with crenellated city walls and end towers. Screenshots: `ui_audit_round3/landmarks/`.
- Fixed: a nil-player script error in the tutorial reward path.

## Update 0.6.2 (UI round 2 + Yaska)

- Racer select redesigned: big hero 3D preview of the selected racer on the left (name + kart overlay); one right panel with a 7-portrait picker on top and the chosen kart's paints, stat bars, speciality and Start/setup below. No scroll chevron, nothing clipped (2400x1080, 1920x1080, 1440x1080).
- Touch scrolling fixed everywhere (TouchScroll): reads native ScreenTouch/ScreenDrag, ignores emulated mouse; the internal "cancel press" events are tagged by device id (their position was stretch-transformed on phones, which ended every drag at once). Momentum friction 2.6/s, clamped bounds. New test tests/test_touch_scroll.gd.
- Settings simplified: Picture = one quality choice (Auto/Low/Medium/High) + Battery saver (30 FPS); Controls = control type (+calibrate for tilt), auto-accelerate, camera view, button size. Hidden items keep their saved values/defaults; saves stay compatible (new keys graphics.quality, graphics.battery_saver). Sound and Language unchanged.
- New racer Yaska (species "girl", kart "Yaska Star", ratings 10/9/10/9/8 — fastest and most stable), code-built driver (chestnut pigtails, flower clip, denim dress with lace sleeves), pink star kart, procedural portrait + assets/icons/ui/racer_yaska.svg, AZ+EN strings, in AI pool, unlocked by default.
- No audio changes.

## Update 0.6.1 — UI scale, racer preview, camera views (2026-10-29)

Desktop only (box, Compatibility renderer screenshots at 2400×1080, 1920×1080,
2048×1536; no device). Audio untouched.

- **UI scale / hierarchy**: one type scale and touch metrics in `UITheme`
  (`FS_DISPLAY/TITLE/H1/H2/BODY/CAPTION`, `FS_BTN*`, `H_PRIMARY` 84,
  `H_BTN` 72, `H_BTN_SMALL` 64, `GAP_*`) used by the theme defaults and by
  main menu, mode select, racer select, race setup, option selector,
  settings, segmented choices, pause and the shared back button.
- **Settings** less bloated: rail tabs 100→72, row icons 60→44, row titles
  32→25, hints 21→17, language cards 300×220→250×160.
- **Racer select**: preview camera framed by aspect (4.7 m on 20:9 up to
  8.6 m on 4:3) and centred in the free space between grid and panel.
- **Camera views**: Chase (re-framed: 5.4 m / 2.35 m, aims 7 m ahead),
  Drone, Right, Left. Switch in race with the new HUD camera button, **C**
  or controller R3 (`camera_cycle` action, remappable); choice in Settings →
  Controls → Camera View; saved as `gameplay.camera_mode`; 0.7 s blended
  transitions; wall-avoidance ray kept for chase/side views. AZ + EN strings.
- **Fix**: speedometer readout showed −9223372036854775808 after long frames
  (explicit Euler spring diverged to NaN); now an exact critically damped step.
- Debug: `--camera=0..3`.
- Tests: 67 methods, 2818 checks, 0 failures (new camera button is covered by
  the existing touch-layout overlap/on-screen checks).

## Update 0.6.0 — child-friendly polish from the phone recording review

**No Android device was attached** (`adb devices` empty) and the recording
itself was not available on this PC, so the review worked from the written
timestamp notes. Everything below is verified on desktop (Mobile renderer,
1600×720 = 20:9 phone ratio, 1280×720 and 1280×960 = 16:9 / 4:3, injected
touches, headless tests). Real FPS, input latency, thermals, frame pacing on
the 90 Hz panel and the black portrait borders (likely the screen recorder)
are **not** established and need a device check.

### Root causes and fixes

| Recording note | Root cause (evidence) | Fix |
|---|---|---|
| 00:02–00:09 fragmented startup | No launcher icons → Android 12 system splash showed the rounded-square `icon.svg` masked to a circle on the template background; no boot splash set → Godot's default; `boot.gd` drew a second, different title card for 0.6 s; then `Game.goto` faded to dark while the menu built its 3D stage. Startup trace of the old build: title card lum 0.145 → dip to 0.094 → menu | One picture everywhere: `tools/gen_splash.py` writes the splash and adaptive icon (fg/bg on the same navy `#123f9a`, edges verified equal to `boot_splash/bg_color`); `boot.gd` shows the same image with a progress bar while the menu loads on a thread; `Game.leave_splash` keeps it on top for the first rendered menu frames, then dissolves. New trace: splash lum 0.28 continuous → crossfade → menu, no dark frame (`--startup-trace`) |
| 00:16, 00:40–00:56 cut-off cards / Start Race | Fixed-size content: mode cards 150 px with wrapping text; racer info panel stacked name, stats, specialty **and** two buttons in one column taller than the body (setup button touched y = 720 at 20:9) | Mode cards share the measured available height inside a scroll fallback; racer details scroll inside the panel while Start (+ race-setup gear) is pinned; bottom safe margin 26 px; checked at 20:9, 21:9 and 4:3 |
| 00:20–00:33 dense Settings | All options in one level with small hints | Controls tab first, Graphics last as "For grown-ups"; 32 px titles, fewer hints; `ScrollHint` (thick yellow scrollbar, edge fade, bouncing chevron) on every scroll list; new rows: Easy Drift, Steering Help, Camera Shake, Vibration, Steady 30 FPS |
| 00:57–01:03 loading stall near the end | The bar stopped at 90 % and the whole world (track, decor, 6 karts, HUD) was built synchronously in the race scene's `_ready`, then shaders compiled on the first race frames | Staged build: 21 steps, one per frame, bar weighted by measured step cost (`LOAD_TIMINGS`, desktop total ≈ 1.6 s; heaviest: racers 329 ms, terrain 267 ms), 4 warm-up frames rendered under the loading screen, stage text ("Building the road…") |
| 01:09–01:16 kart small, camera far | The camera smoothed its **world** position at 14/s, so it trailed by speed/14: ≈ 2 m extra at 97 km/h, 2.6 m on nitro, on top of 5.0 m + 0.6 m distance and FOV up to 82° | Smooths a kart-relative offset; 3.9 m / 1.65 m, FOV 64 (+5 to top speed); only real overspeed widens FOV / stretches slightly |
| 01:18–01:20 SÜRƏT does nothing | `BOOST` only acted as the drift-timing press **during** a drift; outside a drift it did nothing, and with auto-acceleration it looked like a gas pedal | Easy Drift (default): letting go of DRIFT while charged boosts; charge level 1→3 with hold time, no overheat. The TURBO timing button is shown only when Easy Drift is off, GAS only when auto-acceleration is off. Nitro is the item, shown on the ITEM button |
| 01:22–01:44 drift looks like normal driving | A drift started only if steer ≥ 0.3 at the moment of the hop; otherwise just a hop. Unexplained to the player | Threshold 0.2 and a 0.35 s late-steer grace after landing; `drift_denied(steer/speed)` shows "Turn while holding DRIFT!" / "Go faster to drift!" and greys/shakes the button; charge ring on DRIFT, soft textured sparks coloured by level (the old untextured quads looked like white bars), "LET GO!" label, restrained smoke |
| 01:27, 01:36 rivals cover the player | The fade for rivals set `GeometryInstance3D.transparency`, which has no visible effect on the karts' opaque custom shader (`vcolor_gloss`) — the fade never worked | Ordered-dither fade (`occlusion_fade` instance uniform, opaque pass) for rivals near the lens or on the line of sight; oriented soft contact footprint from measured kart size (1.74 × 2.35–2.7 m → 1.8 × 2.55) instead of a 1.75 m circle; player no longer blinks after hits — a soft bubble shows the protection window, "Safe for a moment!" after recovery |
| 01:32–01:52 wall scraping | Glancing contact removed `glance_loss × ratio` of the speed **every tick** (~50 %/s) and steering into the wall fought the alignment | First-touch loss, then 4 m/s², sideways nudge, steering into the barrier damped while scraping; grass slowdown 1.6× instead of 2.5×; heading-aware edge help (on by default, capped at 0.6 of full lock). Test (steering into the wall 1.5 s): old 27.3 → 16.7 m/s and stays; new min 19.3, recovers to 25.8 m/s |
| 01:54–02:24 item UI split, notices over the minimap | Separate item slot + ITEM button; captions grew upward from y≈376 over the minimap | The ITEM button is the slot: real icon (nitro/shield/trap), roll, dimmed "?" when empty, glow when ready, pop on use; captions top-centre (max 2) |
| 02:01–02:24 nitro does not feel fast | Real speed did rise (measured below) but feedback was a 6° FOV step, small flames and +0.15 pitch while the trailing camera hid the gain | FOV/stretch, flames, speed lines (2D, edges only), engine pitch all follow **real overspeed**. Measured on a flat test: **27.3 m/s cruising → 36.7 m/s on nitro (×1.34 ground covered per second)**, readout 98 → 132 km/h |
| Text speedometer | — | `SpeedGauge`: coloured semicircle (red zone = above top speed), critically damped needle, small readout pill, boost-time ring; driven by `KartController.speed` |

### Child appeal added
Collectible stars on the racing line (player only, one MultiMesh, pooled
sparkles, rising chime, respawn each lap, HUD counter), saved once per race;
four kart paints unlock at 15/40/80/140 stars (racer-select swatches, results
announce unlocks; cosmetic only); first quick race shows three prompts (steer,
drift, item); races default to 2 laps (~1:50); Drift School text follows Easy
Drift; illustrated icons for modes and HUD buttons; camera shake 0.6 by
default with Off/Low/Normal in Controls.

### Performance
- `PerfMonitor`: steady-30 fallback (if > 25 % of race frames exceed 20 ms
  over 4 s at the 60 cap → even 30 FPS for the session; setting, on by
  default). Simulated weak device (`--fake-load-ms=19`): 41–45 FPS jittery →
  30.0 FPS, 33.33 ms avg; normal run stays at 60 with no fallback.
- Developer → Performance overlay is now implemented (FPS, 1 % low, CPU/GPU
  ms, slow-frame share, refresh rate, cap, draws, memory) and writes
  `user://logs/perf_<time>.csv` once per second for 10–15 min soak/thermal
  sessions on the phone (`adb shell run-as az.bakuturbo.game cat files/logs/perf_….csv`).
- Back-to-back desktop proxy (RTX 3070, Mobile renderer, Medium, 1600×720,
  seed 5, 60 s): old 0.5.0 GPU 2.66 ms / 184 draws / CPU proc 1.83 ms →
  0.6.0 GPU 2.65 ms / 185 draws / CPU proc 2.12 ms; both 60 FPS, 0 slow frames.
- Frame pacing: the project found no Android frame-pacing (Swappy) setting
  in Godot 4.4.1 to enable; whether a newer engine version adds one was not
  checked here, and the engine was not upgraded. The Mi 12 Lite panel is
  90 Hz: a 60 FPS cap may pace unevenly there — check with the overlay.

### Verified (desktop)
- Tests: **67 methods, 2386 checks, 0 failures** (new `test_kid_driving.gd`:
  nitro ground speed, Easy Drift charge/release, late-steer drift and denial,
  edge help, wall scrape, star field; v2→v3 settings migration; stars ledger
  and paints; touch layout across 12 option combinations × 4 screens incl.
  speedometer clearance — this caught and fixed real overlaps on 16:9/4:3).
- `--ui-flow` 0 failures; chaos fuzz: max stuck 1.1–1.2 s (old 1.1 s);
  full 2-lap AI race: all six finish, 0 recoveries, 0 hard hits.
- Screenshots: `docs/screenshots/0.6.0/`.

### Not verified / needs the phone
Real FPS and thermals over 10+ minutes, 90 Hz pacing, touch feel of the new
layout and Easy Drift, safe area with the punch-hole camera, the Android 12
system splash with the new adaptive icon, audio balance, whether the black
portrait borders are an app or recorder issue (immersive mode is on).

Settings v3 migrates v1/v2 files (steering help on and camera shake 0.6 were
developer-only values, so they move to the new defaults; player choices are
kept). `PHYSICS_VERSION` 2 rejects 0.5.0 ghosts.

## Update 0.5.0 — Android interaction fixes, compact Settings, cheerful Baku

**No Android device was attached** (`adb devices` empty). Everything below is
verified on desktop (Mobile renderer, injected touch events, unit tests) or
by reading the Godot 4.4.1 Android sources. Physical tilt, finger feel and
phone performance are **pending a device check**.

### Root causes and fixes

| Problem | Root cause (evidence) | Fix |
|---|---|---|
| Scrolling heavy, delayed, stepped on the phone | (1) `TouchScroll` truncated each drag delta with `int()`; with the 1280×720 canvas stretched ×1.5 on a 2400×1080 phone, slow drags (< 1 viewport px per event) moved 0 px and faster ones lost the fraction; (2) fling speed came from millisecond timestamps (0 ms gaps → spikes); (3) the ScrollContainer's own touch drag only switches on when a touchscreen exists, so on phones two drag/inertia systems fought (desktop tests never saw it); (4) the cancel-release sent when a drag started still fired/toggled the control, because `BaseButton` decides from `pressing_inside`, which only motion events update (reproduced: a drag over a switch toggled Bloom) | One shared `TouchScroll` (`scripts/ui/touch_scroll.gd`) for every scroll view: float offsets, 100 ms µs-sampled release velocity, exponential frame-rate-independent glide, built-in drag disabled (`MOUSE_FILTER_IGNORE`), off-control motion + release on drag start, a touch on a gliding list stops it and activates nothing, one mouse-only input stream (emulated from the first finger), wheel/trackpad support, `PROCESS_MODE_ALWAYS` for pause. `SafeSlider` for the developer list (changes only on tap or sideways drag) |
| Tilt does nothing | (1) Godot 4.4 registers Android sensors only if `input_devices/sensors/enable_*` is true; the defaults are **false** (`core/input/input.cpp`, `Godot.kt` registerSensorsIfNeeded) and project.godot did not set them, so `get_accelerometer()` returned zero; (2) the code read `acc.y`, but Godot already rotates samples into the display orientation (`GodotInputHandler.onSensorChanged`) and negates them, so steering is screen **x**; `y` is pitch and would have pinned the kart to full lock | Sensors enabled; `TiltSteering` uses `get_gravity()` (fused) with accelerometer fallback and bump rejection, screen-x axis, stale-180°-rotation correction, wheel-angle/lean blend, 1.8° dead zone, three levels (30°/22°/15° full lock), 40/110 ms low-pass on the fixed tick, calibration, reset on pause/background/mode switch, buttons fallback with a notice, debug overlay (debug builds) |

Also fixed: the racer preview rotated twice per finger movement (handled both
`ScreenDrag` and the emulated mouse motion); scenery textures were imported
lossless without mipmaps (now VRAM-compressed ETC2/ASTC with mipmaps).

### Implemented
- **Settings** replaced by four tabs — Graphics (Texture Quality, Frame Rate
  30/60/90/120 gated by the display refresh rate, Shadows Off/Low/Normal/High),
  Audio (Master / Music / Sound Effects switches; Master keeps the other two
  choices), Controls (Control Type, Button Size, Automatic Acceleration,
  Steering Sensitivity, Calibrate with a live tilt bar), Language (flag icons
  plus names) — and Back and Restore Defaults with confirmation. Renderer and
  tuning options moved to a debug-build-only developer tab (long-press the
  title; English only). Settings v2 with migration from v1 (no resets).
- Texture Quality changes real assets: 256 / 512 / 1024 px texture tiers
  swapped in place (`TextureLibrary`), plus mip bias and anisotropy.
- One cheerful theme: generated glossy 9-patch buttons/panels, 20 SVG icons,
  outlined Baloo headings, bounce and sparkle micro-animations; main menu
  (Baku plaza stage, idle reactions), racer select, loading, pause, results,
  HUD and touch buttons restyled; all text localized and re-labelled live.
- Track: painted textures (asphalt, setts, limestone, paving, grass), lighter
  blue haze, warm sun, glossy kart paint, flower planters; **six landmarks**:
  National Flag Square (waving flag, correct blue/red/green, crescent and
  eight-pointed star) dead ahead on the Boulevard straight, Heydar Aliyev
  Center beside the modern connector, Flame Towers above the Old City walls,
  Maiden Tower in the Old City, Baku Crescent in the bay on the return leg,
  improved Boulevard (planters, palms, benches, balustrade, wheel facing the
  road). Footprints are reserved so scatter never overlaps them; nothing was
  added on the driving corridor; far LODs beyond 380 m.
- Audio: major-key menu (112 BPM) and race (138 BPM) loops, victory jingle on
  the Music bus, marimba UI, bell countdown, overtake cue, sea ambience
  (pauses with the race). All original (numpy synthesis).

### Verified (desktop)
- Tests: **59 test methods, 761 checks, 0 failures** (new
  `test_controls_settings.gd`: tilt axis/direction incl. flat hold and stale
  rotation, dead zone/bounds/monotonic curve per level, 30 vs 120 Hz filter
  equality, bump rejection, calibration, tilt reaching `KartInput.steer` and
  turning the kart right/left while LEFT is held, buttons fallback after no
  data, button ramp levels with exact full lock, v1→v2 migration, audio
  switches, texture tiers, FPS options).
- `--ui-flow` with injected touches, 0 failures at 1600×720 (touch) and
  1280×720: a slow sub-pixel drag follows the finger (30.0 of 30 px),
  direction reversal, drags starting over rows change nothing, a flick
  glides, a touch stops the glide and taps nothing — in the main-menu
  Settings **and** in the paused race; Settings opens from menu and pause;
  a live language switch in the paused race keeps race time and pause.
- Frame-rate independence: `--probe=12` output identical at `--fixed-fps 30`
  and `144` (steering ramp and tilt filter run on the 60 Hz physics tick).
- Landmark gameplay views: `--landmark-views` (chase camera on the racing
  line) — `docs/screenshots/0.5.0/landmark_*.jpg`; Boulevard in
  `after_race_return.jpg`.
- Azerbaijani and English screenshots reviewed for clipping.
- APK exported and signed (`builds/android/BakuTurbo-debug.apk`, 35.6 MB,
  `apksigner verify` OK; sensor settings present in `project.binary`);
  Windows exe rebuilt.

### Performance (desktop proxy, back-to-back A/B, `docs/perf/ab_back_to_back.txt`)
RTX 3070, Mobile renderer, 1600×720, seed 5, 75 s autopilot, both builds run
in the same machine state. (A single earlier baseline read 1.25 ms GPU on
Medium because of GPU clocking, so only back-to-back pairs are compared.)

| Preset | Draws med/p95 before → after | Prims | GPU ms med (p95) before → after | VRAM | Frames >20 ms |
|---|---|---|---|---|---|
| Low | 124/168 → 126/172 | 172k → 173k | 1.22 (1.38) → 1.22 (1.67) | 75 → 79 MB | 0 |
| Medium | 170/216 → 175/223 | 303k → 316k | 2.58 (3.02) → 2.59 (3.23) | 92 → 97 MB | 0 |
| High | 207/272 → 213/284 | 478k → 482k | 4.03 (5.86) → 4.01 (5.52) | 144 → 151 MB | 0 |

Static memory 168–171 → 155–158 MB; objects 3935 → 4072. Before the
texture-import fix Medium measured 2.86 ms (p95 4.78): uncompressed,
mip-less textures were the cost, not the landmarks.

### Pending (needs the Xiaomi Mi 12 Lite)
- Tilt direction, comfort, calibration and the Low/Normal/High feel on the
  real sensor; behaviour after a 180° flip; the buttons-fallback notice.
- Finger feel of scrolling and flings; accidental-tap check by hand.
- Which FPS caps the phone reports as supported (Godot reports the current
  display mode; Android may keep the app at 60 Hz), frame pacing, thermals,
  memory over a 15-minute session.
- Music and effects by ear on the phone speaker; backgrounding with audio.

### Remaining limitations
- The developer tab is English-only (debug builds, hidden).
- Landmarks are stylised low-poly interpretations scaled to the circuit.
- Low p95 GPU rose slightly (1.38 → 1.67 ms) when glass landmarks are in view.
- Keyboard/controller remapping is no longer exposed to players.

---

## Previous release (0.4.0)

## Update 0.4.0 — Settings fix, animal racers, UI/graphics/perf pass

### Fixes
| Problem | Root cause | Fix | Evidence |
|---|---|---|---|
| Settings inaccessible during a race | Pause→Settings assigned the settings root (a `Node`) to a `Control`-typed variable → script error, overlay never opened | Typed as `Node` | `--ui-flow` (injected touch taps): Race→Pause→Settings→Back→Resume passes; race clock frozen in Settings; still paused after Back |
| Settings unusable on a phone | Rows (buttons/sliders/selectors) swallowed touches, so the list could not be scrolled with a finger | `TouchScroll`: vertical drag past 14 px scrolls with inertia and cancels the tap underneath | `--ui-flow`: drag scrolls 0→~495 px and changes no setting |
| Settings showing options with no effect | Unsupported options were shown disabled | Hidden per platform: 30/60 FPS on phones; VSync/window/SSAO hidden where unsupported; touch options only with touch | code + screenshots |
| Full-screen panels sized 0×0 (results drawn off-screen when docked) | `set_anchors_preset` does not resize existing controls | `set_anchors_and_offsets_preset` everywhere | results/pause screenshots |
| Karts pinned nose-first on barriers | Steering authority scaled with speed, which a wall holds at 0 | Wall-contact pivot authority + low-speed alignment along the barrier toward the race direction | chaos driver: stuck >1 s 21–30/run → 0–1/run (max 1.6 s incl. deliberate braking) |
| Respawn could be read as a gate crossing | Teleport segment evaluated by the gate test | Respawn resets the previous position | code; lap/gate tests pass |

### New content
- Six racer packages (data resources): Posi/panda/Bamboo Sprint, Bicok/fox/Amber Dash,
  Ləlöyün/rabbit/Hop Rocket, Məstan/cat/Velvet Slide, HavHav/dog/Buddy Rally,
  Çəpiş/lamb/Cloud Booster — exact names, rating table as specified, ratings mapped
  through bounded curves (see TUNING.md); balance spread 1.8 %.
- Procedural animal drivers (shared rig, species ears/muzzles/markings/tails,
  accessories) with blink, breathing, steering with paws on the rim, lean, jump/land,
  boost, hit, victory, ear/tail motion; six distinct kart bodies; identical collision.
- Racer selection (6 cards with drawn portraits, one live preview, 5 stat bars,
  specialty, Start Race, race-setup button); the separate kart/paint picker is gone;
  AI uses the other five racers; last racer saved.
- HUD: position badge with up/down change cue, lap and timer pills + pause (upper
  right), minimap lower-left (above steering buttons on touch), item slot by the
  driving controls, trap-ahead warning; results docked right so the winner
  celebrates on screen.
- Graphics: contact shadows on all presets, deeper sky and warmer grade, red/white
  barrier caps, "BAKU TURBO" gantry and "İÇƏRİŞƏHƏR" gate signage, landing dust and
  boost bursts, closer chase camera.

### Performance (desktop proxy: RTX 3070, **Mobile renderer**, 1600×720, one full race lap, `--stats`)
| | Draw calls med / p95 | Primitives med | GPU ms med | CPU process+physics ms | Frames >20 ms | Static mem |
|---|---|---|---|---|---|---|
| Medium before | 223 / 298 | 319k | 2.41 | 2.21 + 2.79 | 1 | 131–134 MB |
| Medium after | 254 / 299 | 340k | 2.73 | 2.10 + 2.66 | 0 | 153–156 MB |
| Low before | 166 / 211 | 160k | 0.53 | 2.18 + 2.88 | 0 | 130–132 MB |
| Low after | 200 / 241 | 188k | 1.30 | 1.94 + 2.42 | 0 | 153–155 MB |
| High after | 286 / 371 | 522k | 1.78 | 2.42 + 3.02 | 0 | 154–156 MB |

Six animated animal drivers first raised Medium to 310 draws; merging kart surfaces,
one node per rear axle, a shared eye node, no wheel shadows and a 45 m draw distance
for small driver parts brought it to 254. Repeated races (9 consecutive, headless):
memory 109.0–109.3 MB, objects ~4155 — no growth.

### Verification
- Tests: **48 test methods, 683 checks, 0 failures** (adds `test_racers.gd`: names,
  ratings, rating→handling direction and bounds, identical collision, selected racer
  loads with five distinct rivals, selection persists and old ids migrate).
- `--ui-flow` passes at 1280×720 and at 1600×720 with touch controls (uses a temporary
  profile, never the player's).
- AI races at easy/medium/hard complete with 0 recoveries; chaos driver 16 runs:
  1 automatic recovery (valid respawn; trigger not reproduced since).
- APK rebuilt and signed (`builds/android/BakuTurbo-debug.apk`, 30.1 MB); Windows exe rebuilt.

### Still unverified (no Android device attached — `adb devices` empty)
Frame rate / frame-time / thermals on the Xiaomi Mi 12 Lite, sustained play on the
phone, real notch insets, touch feel of the new layout, vibration, OS suspend/resume.

### Remaining issues
- Animals are procedural low-poly forms (no sculpted fur, no skeletal rigs); expressions
  are limited to blinking, head/ear/tail motion and poses.
- Memory rose ~23 MB (unique meshes per racer); acceptable on 8 GB, but meshes could be
  shared between duplicate AI racers when more than six race.
- Balance measured with AI on one track only; human playtests needed.
- One unexplained automatic recovery in chaos testing.

---

## Previous release (0.3.0)

Legend: **Implemented** = code exists and runs; **Verified** = checked by an
automated test, a measured run or a reviewed screenshot (evidence named);
**Unverified / blocked** = not checked, with the reason.

## Completed (implemented and verified on desktop)

| Area | Evidence |
|---|---|
| Fresh start reaches main menu (boot → menu) | menu screenshots via `--screens`, profile deleted beforehand |
| 3 selectable karts, paints, rotatable preview | kart-select screenshot; `KartFactory` used for all three in seeded races |
| Six racers complete a valid 3-lap race | `test_full_race_completes_with_results`; seeded headless races (all 6 finished, 0 recoveries) |
| Checkpoint skipping cannot award laps; line rocking cannot fake laps | `test_skipping_checkpoints_awards_nothing`, `test_backward_over_finish_cannot_fake_a_lap`, `test_backward_crossing_undoes_and_no_duplicate_events` |
| Shortcut merges into checkpoint route; no gate inside the skipped section or reachable from the alley | `test_seafront_checkpoint_layout_is_valid` (309 checks); AI uses the alley 0–2× per race without recoveries |
| Ranking (finish time, then clamped race distance) | `test_ranking_by_progress_and_finish`, `test_distance_clamped_to_next_gate`, `test_race_runs_and_ranks_six_racers` |
| Drift / boost chain, caps, cancellation (same rules for AI) | `test_boost_drift.gd` (8 tests) |
| Three items, ownership, arming, shield, hit immunity, single slot, disabled in Time Trial | `test_items.gd` (7 tests) |
| Save/load, backup recovery, version guard, type validation, records | `test_persistence.gd` |
| Rewards applied once; reloading results does not duplicate | `test_reward_granted_once_per_event`, `test_results_reapplied_do_not_duplicate` |
| Settings persist and sanitize; presets differ measurably | `test_settings_persist_and_sanitize`, `test_presets_change_settings_measurably`; draw calls/primitives per preset in `docs/TUNING.md` |
| Restart clears all race state (items, traps, boosts, timers, AI, inputs, trackers), no node leaks | `test_restart_clears_race_state` (60 checks) |
| Repeated races: object count stable | `test_repeated_restarts_do_not_grow_memory`; soak below |
| Simulation independent of render frame rate | `test_simulation_independent_of_render_frames`; **identical** probe output at `--fixed-fps 30` vs `144` |
| Simultaneous touch, slide steering, release on interruption; layout fits 16:9 and 20:9 | `test_simultaneous_touches`, `test_touch_layout_fits_wide_and_16_9_screens`; touch screenshots 1280×720 and 1600×720 |
| App suspension: race pauses, inputs released, profile/settings saved | `test_focus_loss_pauses_and_releases_input`; code paths in `Game._notification` |
| Azerbaijani UI renders (ə ı İ ö ü ş ç ğ) and fits | font coverage check; screenshots of every menu and HUD in `az` |
| AI difficulty differs by skill, not teleporting | seeded races: easy/medium/hard AI median best lap 60.9 / 54.9 / 53.0 s; speed factors ≤ 1.0 + ≤ 3 % capped catch-up |
| Android APK builds and is signed (arm64-v8a, debug keystore) | `builds/android/BakuTurbo-debug.apk` (≈ 30 MB), data/translations present in package |
| Windows release builds and runs a race | `builds/windows/BakuTurbo.exe`, smoke race via log |
| Pause → Settings overlay, results, Drift School, Time Trial ghost playback, shortcut fork/alley | screenshots reviewed; ghost shows stored best lap and drives ahead |
| Mobile renderer compatibility | game run with `--rendering-method mobile` at 1600×720, screenshots reviewed |

Test suite: **42 test methods, 626 checks, 0 failures** (`tests/run_tests.gd`).

## Implemented, verified only partially

| Item | What is missing |
|---|---|
| Drift boosts "consistent" with keyboard / controller / touch | All three feed the same actions (tested for touch and InputMap); not hand-played on a physical controller or phone |
| Audio | Generated and analysed numerically (levels, loop seams, loop metadata imported); **not listened to by a human** in this session |
| Controller button prompts | Xbox/PlayStation/Nintendo naming implemented; no physical pad was connected |
| Tilt steering | Implemented from the accelerometer; needs a phone |
| Visual quality | Reviewed in screenshots; not reviewed on a phone screen |

## Blocked (needs the physical device)

- **On-device performance** on the Xiaomi Mi 12 Lite (60 FPS target, 15-min
  sustained session, thermal behaviour, memory): no Android device was
  attached (`adb devices` empty). Desktop soak results are a proxy only.
- Touch feel, safe-area insets on the real notch, Android suspend/resume
  with the OS, audio focus, vibration.
- Install and first-launch test of the APK.

## Desktop soak (proxy)

20-minute real-time session, Mobile renderer, Medium preset, 1600×720
(20:9), autopilot, continuous 3-lap races (`--soak --stats`), RTX 3070 desktop.

| Window | Result |
|---|---|
| First 15.4 min, unattended (5 complete races, auto-restarts) | 60 FPS every second; **0 frames over 20 ms**; static memory 120.6–124.6 MB (124.1 → 124.4 MB at each race end); objects 3505–3643; draw calls median 161, p95 243, max 309; primitives median 0.30 M, max 0.54 M |
| Remaining minutes | someone interacted with the window (pause, settings, menu, new race); this exposed a bug — opening Settings from the pause menu failed (typed variable) — now fixed and covered by `test_pause_settings_overlay_opens_and_closes` |

This is a **desktop proxy**. It does not demonstrate the phone target.

## Known issues / limitations

- Track scenery is procedural and stylised; buildings are instanced from a
  small kit (4 Old City houses, 3 modern blocks), so repetition is visible
  up close.
- Drivers are not yet separate characters (one helmeted driver style; the
  driver/kart/handling split is planned for Milestone 4).
- Only items in the first set exist; the "incoming attack" warning is not
  needed until projectiles are added.
- The chase camera is kept inside the barrier corridor by a collision ray
  (barriers have 4.5 m invisible collision), so it never enters buildings;
  rival karts that come between camera and player fade out.
- Ghost lap 1 includes the standing start; later laps are flying laps.
- AI uses the shortcut with fixed probabilities per difficulty.
- Desktop measurements only; budgets must be re-set after phone profiling.

## Not implemented (future milestones)

Cup Championship, Adventure, Battle mode/arenas, additional tracks/drivers/
bodies, cosmetics shop, split-screen, online multiplayer (not started, and
not to be described as implemented until tested across devices/networks).
