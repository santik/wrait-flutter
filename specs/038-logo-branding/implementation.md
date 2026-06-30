# Implementation: Logo Branding

> **Feature number:** 038
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-29

---

## Summary

Implemented Wrait release/debug branding across Android and iOS app icons and
iOS launch imagery, added deterministic checked-in branding sources plus a
local generation script, and expanded automated/runtime validation to pin the
no-Flutter-logo contract.

Release branding now uses the app's button-treatment look. On Android, the
launcher now follows the `wrait-android` adaptive-icon reference and renders
only the background color plus the `wrait` wordmark. Debug/profile branding
uses the same structure with a red background so the dev app is visually
distinct. Neutral privacy behavior was kept in place.

## Implementation details

- Added checked-in branding sources and generator under `tool/branding/`
- Added hand-authored Android adaptive launcher resources under:
  - `android/app/src/main/res/mipmap-anydpi/`
  - `android/app/src/main/res/drawable/`
  - `android/app/src/debug/res/drawable/`
  - `android/app/src/profile/res/drawable/`
- Regenerated:
  - iOS release app icons
  - iOS debug/profile app icons
  - iOS launch images
- Wired iOS Debug/Profile to `AppIconDebug` in
  `ios/Runner.xcodeproj/project.pbxproj`
- Updated `ios/Runner/Base.lproj/LaunchScreen.storyboard` background to match
  the dark launch surface used by the new launch mark
- Added/updated tests for:
  - bootstrap Wrait copy and no `FlutterLogo`
  - app-lock Wrait/neutral copy and no `FlutterLogo`
  - Android/iOS asset size and wiring contracts
  - iOS privacy-cover generic copy contract
  - integration coverage for app-lock branding and bootstrap/app branding

## Review remediation

The external review raised two issues that materially changed the feature work:

- the Android launcher icon still rendered as a dark square nested inside the
  launcher mask
- the branding tests and asset generator needed more robust validation

Applied fixes:

- changed the shared icon sources to use deterministic geometric vector
  wordmark shapes rather than font-dependent text rendering
- replaced the Android launcher implementation with adaptive-icon XML resources
  modeled on `wrait-android/src/main/res`, using only solid background color
  plus the `wrait` wordmark
- kept iOS app icon outputs opaque by rendering the same circle mark onto the
  dark brand background during generation
- hardened `tool/branding/generate_assets.sh` to validate every generated PNG
  for existence, format, and expected dimensions
- hardened `test/platform/branding_assets_test.dart` to:
  - validate PNG signatures and IHDR dimensions explicitly
  - resolve iOS Debug/Profile/Release icon wiring by configuration name rather
    than hardcoded Xcode UUIDs
  - validate the exact debug icon catalog entries instead of only counting them

## Validation

Automated:

- `/opt/homebrew/bin/flutter test test/bootstrap_app_test.dart test/platform/ios_capture_privacy_test.dart test/platform/branding_assets_test.dart test/presentation/app_lock/app_lock_screen_test.dart`
  - Passed
- `/opt/homebrew/bin/flutter test integration_test/app_lock_flow_test.dart integration_test/branding_surfaces_flow_test.dart`
  - Passed
- `flutter analyze`
  - Passed with no issues
- `tool/branding/generate_assets.sh`
  - Passed with built-in PNG/dimension validation
- `/opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/app_lock_flow_test.dart integration_test/branding_surfaces_flow_test.dart`
  - Passed on the iPhone 17 simulator after review remediation

Android emulator:

- Built `build/app/outputs/flutter-apk/app-debug.apk`
- Verified APK application id with `aapt`: `com.wrait.flutter.dev`
- Installed debug APK on emulator
- Cold-started with:
  - `adb -s emulator-5554 shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity`
  - `TotalTime: 2806`
  - `WaitTime: 2811`
- Captured `/private/tmp/wrait_branding_recents.png`
  - Observed black protected preview and red Wrait debug icon in recents chip
- Captured `/private/tmp/wrait_branding_foreground.png`
  - Observed full black capture, consistent with preserved `FLAG_SECURE`
- Verified `dumpsys window windows` for
  `com.wrait.flutter.dev/com.wrait.flutter.MainActivity` included `SECURE`

iOS simulator:

- Booted iPhone 17 simulator `491CD949-D3C0-4C4C-A6B9-15BAB1859156`
- Ran debug app with `flutter run -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --debug --no-pub`
- Captured `/private/tmp/wrait_ios_foreground.png`
  - Observed iOS secure-storage passcode prompt referencing `Wrait` and no
    Flutter logo
- Located SplashBoard snapshot files under the app container and rendered
  `/private/tmp/9220483E-678F-47D7-BDA0-475E1F5E307E@3x.ktx.png`
  - Observed dark branded snapshot with cream Wrait mark

Android device remediation check:

- Rebuilt `build/app/outputs/flutter-apk/app-debug.apk`
- Installed the debug APK on physical device `4A181FDJH0030G`
- Cold-started with:
  - `adb -s 4A181FDJH0030G shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity`
  - `TotalTime: 1999`
  - `WaitTime: 2015`
- Verified adaptive launcher resources directly:
  - release launcher resources now use only the cream background plus dark
    `wrait`
  - debug/profile launcher resources now use only the red background plus
    white `wrait`
- Captured `/private/tmp/wrait_branding_review_recents.png`
  - Physical-device recents capture remained fully black because secure
    overview protection also masked the screenshot, so the launcher-icon fix
    itself was verified from the packaged adaptive-icon XML resources

Final Android adaptive-icon follow-up:

- Ran `/opt/homebrew/bin/flutter test test/platform/branding_assets_test.dart`
  - Passed with adaptive-icon resource assertions
- Ran `flutter analyze`
  - Passed with no issues
- Rebuilt `build/app/outputs/flutter-apk/app-debug.apk`
- Verified the rebuilt APK with:
  - `/Users/alexander/Library/Android/sdk/build-tools/36.1.0/aapt dump badging build/app/outputs/flutter-apk/app-debug.apk`
  - package name remained `com.wrait.flutter.dev`
- Verified packaged launcher resources with:
  - `unzip -l build/app/outputs/flutter-apk/app-debug.apk | rg 'ic_launcher|mipmap-anydpi|drawable.*/ic_launcher'`
  - APK contains `res/drawable/ic_launcher_background.xml`,
    `res/drawable/ic_launcher_foreground.xml`,
    `res/mipmap-anydpi-v21/ic_launcher.xml`, and
    `res/mipmap-anydpi-v21/ic_launcher_round.xml`
- A fresh on-device install was not repeated in this final pass because
  `adb devices` showed no attached Android device at the time of validation

Final iPhone icon follow-up:

- Updated the shared iOS app-icon sources so they render only solid background
  color plus the `wrait` wordmark, with no inner circle
- Regenerated the iOS release and debug app icon catalogs with
  `tool/branding/generate_assets.sh`
- Ran `/opt/homebrew/bin/flutter test test/platform/branding_assets_test.dart`
  - Passed with the regenerated iOS icon assets
- Verified previews directly:
  - release icon now shows full cream background with dark `wrait`
  - debug icon now shows full red background with white `wrait`

## Approved exceptions used

- Android release runtime verification was skipped because release signing
  inputs were not provided in this session
- iOS release runtime verification was skipped because no release-capable
  simulator/device path was available
- Native launcher/icon/app-switcher surfaces relied on source/config tests plus
  runtime screenshots where available rather than pure `integration_test`

## Notes for review

- `flutter_01.png` was left untouched because it appears to be a pre-existing
  reference screenshot outside the feature-owned platform asset pipeline
- The iOS simulator still triggers the known secure-storage passcode prompt
  before normal app UI in this environment
