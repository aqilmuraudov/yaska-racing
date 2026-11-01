# Yaska Racing — Claude üçün iş qaydaları

Uşaqlar üçün (Aqilin qızı Yaska üçün) Bakıda keçən 3D kart yarışı. Keçmiş adı BAKU TURBO.
Həmişə Azərbaycan dilində cavab ver.

## Texnika
- Godot **4.4.1-stable**, GDScript, Jolt fizikası, Android üçün **Mobile renderer**.
- Package `az.bakuturbo.game` — DƏYİŞMƏ. Pul vahidi manat/qəpik (₼).
- Google Play **Families** qaydalarına uyğun olmalıdır (reklam/alış yoxdur, şəxsi məlumat yoxdur).
- Hər şey kodla qurulur (ShapeKit/PropKit/LandmarkKit/CityKit) — xarici 3D asset yoxdur (hələlik).
- Əsas sənədlər: `docs/STATUS.md` (versiya tarixçəsi, vəziyyət, zəif yerlər), `docs/TUNING.md` (parametrlər),
  `docs/BUILD.md`. İşə başlamazdan əvvəl STATUS.md-nin ən üst hissəsini və TUNING.md-ni oxu.

## Qəti qaydalar
1. Səslərə və səsləndirməyə (`assets/audio`, `scripts/audio`) toxunma. Yeni səs yalnız SFX bus ilə.
2. UI oyun stilində, sadə, vizual, az mətnli — kiçik uşaq üçün.
3. Əvvəl test et, ekran görüntülərini tənqidi yoxla, yalnız sonra APK çıxar.
4. Hər buraxılışda `export_presets.cfg`-də versionCode-u 1 artır; STATUS.md və TUNING.md-ni yenilə;
   yeni test faylı `tests/test_roundN.gd` (sonuncu: round 29).
5. Dəyişiklikdən əvvəl backup (git commit və ya zip).
6. Zəif yerləri dürüst de; ölçülməyəni ölçülmüş kimi göstərmə.
7. Aqil bir neçə xüsusiyyəti **bir APK-da** almağı üstün tutur (hər addıma ayrı APK yox).

## Testlər və build
- Strict testlər: `GODOT="<godot console exe>" python tools/run_tests.py` — skript xətası olan testi də uğursuz sayır.
  Əvvəlki tam qaçış: 221 metod, 5756 yoxlama, 0 uğursuz (0.14.3).
- Debug runner bayraqları `docs/BUILD.md`-də (`--race --autopilot --track=old_city --tod=night --capture=DIR ...`).
- Android export: `--export-debug "Android" <apk>`. JDK 17 PATH-da olmalıdır, yoxsa APK imzasız çıxır.
- İmza açarı: `_setup/yaska-debug.keystore` (alias `androiddebugkey`, şifrə `android`).
  Bu PC-də: `%USERPROFILE%\.android\yaska-debug.keystore` (oradakı `debug.keystore` başqa açardır, toxunma),
  Godot Editor Settings > Export > Android > Debug Keystore ona yönəlib.
  Yoxlama: `apksigner verify --print-certs` → SHA-256 `726cd3535a49ffa4e7d8562fea1a2868e01194afa460ee38a0c0f2866d6e25d9`.
  Yeni açar YARATMA — yoxsa telefonda köhnə oyunun üstünə quraşdırılmaz.
- `_builds/` və `_setup/` git-ə düşmür.

## Vəziyyət (0.15.2, versionCode 37)
Hazır: menyu, mağaza, uşaq avto-idarəsi, Bakı Kuboku, Rekord+ghost, gündəlik tapşırıq, gündüz/gün batımı/gecə,
3 şəhər (Dəniz sahili, Göydələnlər, İçərişəhər), finiş replay-i, ilk dərs, stiker albomu, rəqib portretləri,
gecə işıqları (saxta, real işıq yox), kontakt kölgə xəritəsi (AoMap), kart konturu,
7 maşın + sürücünün hamısı və İçərişəhər evləri / Qız Qalası Blender modelidir (`tools/blender/`, ümumi `kart_common.py`).
Əvvəlki iş GPU-suz bulud mühitində aparılıb — **heç bir rəqəm real telefonda ölçülməyib.**

## İndiki plan (Aqil ilə razılaşdırılıb)
1. Bu kompüterdə alətləri yoxla/qur: Godot 4.4.1 (+export templates), JDK 17, Android SDK (build-tools 34,
   platform 34), adb. Proyekti bir dəfə import et, strict testləri keçir, ekran görüntüləri əsl GPU-da.
2. Telefonu USB ilə (Xiaomi Mi 12 Lite, USB debugging) qoş, APK-nı quraşdır, hər 3 şəhərdə gündüz/gecə
   real FPS ölç (Developer → Performance overlay `user://logs/perf_*.csv`, `adb shell run-as az.bakuturbo.game ...`).
   İçərişəhər ən ağır ola bilər (çox ev). Lazım olsa optimizasiya.
3. Blender pilotu: Yaska-nın maşını + sürücüsü Blender-də (bpy skripti ilə, `blender --background`),
   telefon büdcəsi: maşın+sürücü ~5–8k üçbucaq, uzaq LOD, 512–1024 px tekstura (baked AO/işıq),
   glTF → Godot. Köhnə vs yeni ekran görüntüsü + FPS müqayisəsi; yaxşıdırsa digər maşınlar və landmarklar.
   Aqil qrafik dizaynerdir: rəng/üslub qərarlarını onunla razılaşdır.
4. Sonra 1.0: release imzası, AAB, Play Store materialları (privacy policy, Data Safety, IARC, Families).
