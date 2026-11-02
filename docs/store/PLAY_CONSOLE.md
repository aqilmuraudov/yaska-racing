# Google Play Console — answers and checklist (draft, 0.15.x)

Everything here follows from the code as of 0.15.4: no network code, no ads SDK, no purchases, no analytics, only the VIBRATE permission (`export_presets.cfg`). Re-check this file whenever a release adds a library or permission.

## Data safety
- Does your app collect or share any of the required user data types? **No.**
- Is all user data encrypted in transit? **Not applicable (no data leaves the device).**
- Do you provide a way for users to request that their data is deleted? **Not applicable (no data collected); local progress is removed by uninstalling.**
- Data types collected: **none**. Data types shared: **none**.

## App content
- Privacy policy URL: publish `docs/store/PRIVACY_POLICY.md` as a web page (for example GitHub Pages of a public repo, or Google Sites) and paste the URL.
- Ads: **No, my app does not contain ads.**
- App access: **All functionality is available without special access.**
- Target audience: **ages 5 and under, 6-8, 9-12** (the game is made for Yaska; pick the bands you want). Selecting children's ages puts the app in the **Families** programme: no ads SDKs, no data collection - already true.
- Teacher Approved: optional, can be requested later.
- Content rating (IARC questionnaire): category **Game**; violence: **cartoon/fantasy, no harm** (karts bump, gift items like turbo/shield/trap); no blood, fear, sex, drugs, gambling, user interaction, location sharing, purchases. Expected result: **PEGI 3 / ESRB Everyone**.
- News app: No. COVID-19: No. Government app: No. Financial features: None. Health: No.

## Store listing (drafts in `LISTING.md`)
- App name: **Yaska Racing** (30 chars max).
- Graphics: icon 512x512 (from `assets/icons/launcher_192.png` source art - export at 512), feature graphic 1024x500, at least 2 phone screenshots (16:9 landscape, from `docs/screenshots/`).
- Category: **Games > Racing**. Tags: Kids, Kart, Casual.
- Contact email: aqilmuraudov@gmail.com.

## Release build - decisions still open (owner)
1. **Release signing key.** The debug key (`_setup/yaska-debug.keystore`) must not be used for Play. Use **Play App Signing**: create an upload key once, keep it with the debug key backup, Google holds the app key. A Play build will not install over the sideloaded debug build (different signature) - uninstall the debug one first; progress is lost on that phone unless copied.
2. **Size.** The APK is 248 MB: 39 baked 2048² texture sets (ETC2, 5.6 MB each) + 23 MB engine. Play's base module limit is 200 MB. Options: (a) background sets (blocks, malls, plaza, gate) at 1024² - about 60 MB less, only distant detail changes; (b) Play Asset Delivery through a Godot Android plugin (more work). Owner asked to keep graphics high, so (b) unless he chooses (a).
3. **AAB.** Godot needs the Android build template (Project > Install Android Build Template), `gradle_build/use_gradle_build=true`, `gradle_build/export_format=1`; then `--export-release "Android" yaska.aab`. Target API 34+ (Play requirement), versionCode keeps increasing.
4. **Phone test.** No FPS has been measured on a real phone yet (Mi 12 Lite). Do it before the first Play upload.
