# Yaska Racing

A 3D kart racer for young children, set in a colourful "mini Baku".
Godot 4.4.1, GDScript, Jolt physics, Android-first (landscape, Mobile
renderer) with Windows builds for development. Formerly called BAKU TURBO.

Package: `az.yaskaracing.game` (since 0.20.3, owner's choice; builds up to
0.20.2 were `az.bakuturbo.game` and install as a separate app). Never change it
after the Play Store release. Currency: manat / qəpik (₼). No ads, no purchases, no
personal data, no internet (Google Play Families).

Current state, version history and known issues: [docs/STATUS.md](docs/STATUS.md).

## In the game

- **Three Baku cities**: Dəniz sahili (the Boulevard: Flame Towers, Heydar
  Aliyev Center, Government House, Crescent, Carpet Museum, Crystal Hall,
  Flag Square, TV tower, Baku Eye, Port Baku), Göydələnlər (Philharmonic,
  City Hall, Ismailiyya, Fountain Square, Nizami street) and İçərişəhər
  (Maiden Tower, Shirvanshahs' Palace, Juma Mosque, Sınıqqala, caravanserai,
  Qoşa Qala gate). Day, sunset and night.
- **Seven racers, each with its own kart** (Blender models): Yaska, Posi,
  Biçok, Ləlöyün, Məstan, HavHav, Çəpiş. One starter kart; the others are
  bought with the manat earned in races.
- **Modes**: quick race, Rekord (time trial with ghost), Bakı Kuboku
  (three-race cup), the daily challenge and the guided "Öyrən" tour.
- **Child-friendly driving**: auto-gas, Easy Drift (release to boost), big
  touch buttons, optional Kids controls (the kart drives itself), tilt.
- **Garage**: upgrades, paints, parts, the nitro add-on; sticker album,
  trophies, daily login strip, race goals.
- **Azerbaijani** (default) and English; the player's racer speaks
  Azerbaijani lines.

## Quick start

```bash
G="C:/Tools/Godot/Godot_v4.4.1-stable_win64_console.exe"
"$G" --path . -e                                   # editor
GODOT="$G" python tools/run_tests.py               # strict test suite (headless)
"$G" --headless --path . --export-debug "Android" builds/android/YaskaRacing-debug.apk
```

Full build, test and debug-runner reference: [docs/BUILD.md](docs/BUILD.md).

Controls (desktop): WASD/arrows drive, **Space** hop/drift, **Shift** drift
boost, **E** item, **Q** look back, hold **R** recover, **Esc** pause.
Full table: [docs/INPUT.md](docs/INPUT.md).

## Documentation

- [docs/STATUS.md](docs/STATUS.md) — version history, verification evidence, known issues
- [docs/TUNING.md](docs/TUNING.md) — handling, boost rules, AI, items, economy, presets
- [docs/BUILD.md](docs/BUILD.md) — versions, build, run, test, debug flags
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — systems and data flow
- [docs/INPUT.md](docs/INPUT.md) — input mappings
- [docs/ASSETS.md](docs/ASSETS.md) — asset inventory, sources, licences
- [docs/store/](docs/store/) — Play Store drafts (privacy policy, data safety, listing)
