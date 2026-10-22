# Status, verification evidence and known issues

Date: 2026-10-22 · Build: 0.3.0 · Engine: Godot 4.4.1-stable

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
| Mobile renderer compatibility | game run with `--rendering-method mobile` at 1600×720, screenshots reviewed |

Test suite: **40 test methods, 615 checks, 0 failures** (`tests/run_tests.gd`).

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

SOAK_RESULTS_PLACEHOLDER

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
