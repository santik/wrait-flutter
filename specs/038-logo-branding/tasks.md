# Tasks: Logo Branding

> **Feature number:** 038
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-29

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

### Group 1: Foundation

Prepare repeatable branding sources and pin the platform asset contract before
replacing generated assets.

- [x] Create deterministic Wrait branding source assets and generation script
      for release and debug wordmark PNGs — `tool/branding/`
- [x] Define the generated icon size matrix for Android launcher densities,
      iOS app icons, iOS debug app icons, and iOS launch images —
      `tool/branding/`
- [x] [P] Add source/config tests for Android release icon resources and
      debug/profile icon overlays — `test/platform/branding_assets_test.dart`
- [x] [P] Add source/config tests for iOS release/debug app icon catalogs and
      Debug/Profile `ASSETCATALOG_COMPILER_APPICON_NAME` wiring —
      `test/platform/branding_assets_test.dart`
- [x] [P] Extend iOS privacy source tests to assert the native privacy cover
      keeps generic `Private` copy and does not introduce Flutter branding —
      `test/platform/ios_capture_privacy_test.dart`

### Group 2: Core implementation

Generate and wire the release and dev branding assets while preserving neutral
protected surfaces.

- [x] Implement release Android adaptive launcher resources using only the
      button-treatment background color plus the `wrait` wordmark —
      `android/app/src/main/res/mipmap-anydpi/`, `android/app/src/main/res/drawable/`
  - Depends on: Group 1
- [x] Implement red debug Android adaptive launcher resource overlays using
      only the background color plus the `wrait` wordmark —
      `android/app/src/debug/res/drawable/`
  - Depends on: Group 1
- [x] Implement red profile Android adaptive launcher resource overlays for
      the dev deploy artifact — `android/app/src/profile/res/drawable/`
  - Depends on: Group 1
- [x] Generate release iOS app icon PNGs using the Wrait button-treatment
      wordmark — `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
  - Depends on: Group 1
- [x] Create and generate red iOS debug/profile app icon catalog —
      `ios/Runner/Assets.xcassets/AppIconDebug.appiconset/`
  - Depends on: Group 1
- [x] Wire iOS Debug and Profile build configurations to `AppIconDebug` while
      keeping Release on `AppIcon` — `ios/Runner.xcodeproj/project.pbxproj`
  - Depends on: Group 1
- [x] Replace iOS launch placeholder images with Wrait-safe launch images and
      keep launch storyboard behavior stable —
      `ios/Runner/Assets.xcassets/LaunchImage.imageset/`
  - Depends on: Group 1
- [x] Remove or account for repo-root leftover Flutter/branding evidence if it
      is not an intentional artifact — `flutter_01.png`
  - Depends on: Group 1
- [x] Verify app lock and iOS native privacy-cover UI remain neutral and do
      not introduce a logo or sensitive content — `lib/presentation/app_lock/app_lock_screen.dart`,
      `ios/Runner/SceneDelegate.swift`
  - Depends on: Group 1

### Group 3: Validation

Add automated coverage and collect runtime visual evidence. Approved planning
exceptions: native launcher icons, OS splash icons, and app-switcher thumbnails
may be validated by source/config tests plus emulator/simulator visual
evidence instead of pure `integration_test`; iOS Release runtime may be
validated by source/generated-asset checks unless a release-capable path is
available; Android release runtime may be skipped if release signing inputs
are unavailable.

- [x] Update startup widget tests to assert loading/retry surfaces show Wrait
      copy and no `FlutterLogo` widgets — `test/bootstrap_app_test.dart`
- [x] Add focused app-lock widget test coverage for Wrait/neutral lock copy and
      absence of `FlutterLogo` — `test/presentation/app_lock/app_lock_screen_test.dart`
- [x] Update app-lock integration coverage for locked-after-resume neutral
      branding and absence of `FlutterLogo` —
      `integration_test/app_lock_flow_test.dart`
- [x] Add Flutter-controlled branding smoke integration coverage —
      `integration_test/branding_surfaces_flow_test.dart`
- [x] Run the focused automated test set for branding, bootstrap, app lock, and
      platform asset wiring; record output in Validation evidence
- [x] Run `flutter analyze`; record output in Validation evidence
- [x] Build/install the Android debug/dev app on an emulator; verify launcher,
      startup, app-switcher, and lock/protected-state surfaces show red Wrait
      or neutral protected state with no Flutter logo
- [x] Run launcher-style Android cold start with
      `adb shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity`;
      record timing and screenshot evidence
- [x] If release signing inputs are available, build/install Android release
      and verify release launcher branding; otherwise record the approved
      release-runtime exception and source/generated-asset evidence
- [x] Build/run Debug on an iOS simulator; verify red Wrait app icon, startup
      surface, app surface, and protected-state behavior
- [x] Inspect iOS app-switcher/SplashBoard snapshot evidence where direct
      app-switcher automation is unavailable
- [x] Record iOS Release runtime exception or release-capable runtime evidence,
      depending on available build path
- [x] Verify the project build succeeds with no errors

### Group 4: Review and fix

Handle external review after implementation.

- [x] Create `implementation.md` with implementation notes and validation evidence
- [x] Stop and wait for external `review.md`, unless the user explicitly skips review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`, `tasks.md`, `implementation.md`, code, and tests when review changes scope, approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for another pass

### Group 5: Finalization

Handle durable documentation follow-up and closeout.

- [ ] Decide whether the feature produced durable learnings or long-lived product/architecture changes worth preserving
- [ ] If needed, propose updates to `AGENTS.md`, `docs/application-description.md`, and `docs/agent-findings.md`
- [ ] Wait for explicit approval before editing those long-lived guidance documents
- [ ] Record whether the knowledge-capture gate resulted in updates or an explicit no-update decision

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

_Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete._

```text
/opt/homebrew/bin/flutter test test/bootstrap_app_test.dart test/platform/ios_capture_privacy_test.dart test/platform/branding_assets_test.dart test/presentation/app_lock/app_lock_screen_test.dart
All tests passed.

/opt/homebrew/bin/flutter test integration_test/app_lock_flow_test.dart integration_test/branding_surfaces_flow_test.dart
All tests passed.

flutter analyze
No issues found.

Android emulator:
- Rebuilt and reinstalled build/app/outputs/flutter-apk/app-debug.apk
- Verified APK package id with aapt: com.wrait.flutter.dev
- Cold start via adb shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity
  TotalTime: 2806
  WaitTime: 2811
- Foreground capture: /private/tmp/wrait_branding_foreground.png
  Result: full black capture, consistent with FLAG_SECURE preservation
- Recents capture: /private/tmp/wrait_branding_recents.png
  Result: black protected preview with red Wrait debug icon visible in recents chip
- dumpsys window confirmed com.wrait.flutter.dev/com.wrait.flutter.MainActivity
  window attrs include SECURE

iOS simulator:
- Booted iPhone 17 simulator (491CD949-D3C0-4C4C-A6B9-15BAB1859156)
- Ran debug app with flutter run -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --debug --no-pub
- Foreground/system prompt capture: /private/tmp/wrait_ios_foreground.png
  Result: iOS secure-storage passcode prompt references Wrait and shows no Flutter logo
- SplashBoard snapshot thumbnail:
  /private/tmp/9220483E-678F-47D7-BDA0-475E1F5E307E@3x.ktx.png
  Result: branded dark snapshot with cream Wrait mark

Approved validation exceptions used:
- Android release runtime verification skipped because release signing inputs were not provided
- iOS release runtime verification skipped because no release-capable simulator/device path was available
- Native launcher/app-switcher/icon surfaces were validated by source/config tests plus runtime screenshots where available

Review remediation rerun:
- tool/branding/generate_assets.sh
  Result: regenerated assets successfully with PNG/dimension validation enabled
- /opt/homebrew/bin/flutter test test/bootstrap_app_test.dart test/platform/ios_capture_privacy_test.dart test/platform/branding_assets_test.dart test/presentation/app_lock/app_lock_screen_test.dart
  Result: all tests passed after test hardening and icon-source changes
- flutter analyze
  Result: No issues found. (ran in 4.7s)
- /opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/app_lock_flow_test.dart integration_test/branding_surfaces_flow_test.dart
  Result: all tests passed on the iPhone 17 simulator
- /opt/homebrew/bin/flutter build apk --debug
  Result: built build/app/outputs/flutter-apk/app-debug.apk successfully
- Android adaptive launcher XML reference:
  wrait-android/src/main/res
  Result: Flutter Android launcher resources were updated to the same
  background-plus-wordmark structure instead of generated PNG launcher art
- adb -s 4A181FDJH0030G install -r build/app/outputs/flutter-apk/app-debug.apk
  Result: Success
- adb -s 4A181FDJH0030G shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity
  Result:
    TotalTime: 1999
    WaitTime: 2015
- Android release adaptive icon resources:
  android/app/src/main/res/mipmap-anydpi/ic_launcher.xml
  android/app/src/main/res/drawable/ic_launcher_background.xml
  android/app/src/main/res/drawable/ic_launcher_foreground.xml
  Result: release launcher now uses only the button-color background and dark `wrait` wordmark
- Android debug adaptive icon resources:
  android/app/src/debug/res/drawable/ic_launcher_background.xml
  android/app/src/debug/res/drawable/ic_launcher_foreground.xml
  Result: debug launcher now uses only the red background and white `wrait` wordmark
- Physical-device recents screenshot:
  /private/tmp/wrait_branding_review_recents.png
  Result: secure recents capture remained black on the validation phone, so the launcher-icon fix was verified from the packaged adaptive-icon XML resources rather than the protected overview screenshot

User-directed Android adaptive-icon follow-up:
- /opt/homebrew/bin/flutter test test/platform/branding_assets_test.dart
  Result: all tests passed with the new adaptive-icon resource assertions
- flutter analyze
  Result: No issues found. (ran in 5.8s)
- /opt/homebrew/bin/flutter build apk --debug
  Result: built build/app/outputs/flutter-apk/app-debug.apk successfully
- /Users/alexander/Library/Android/sdk/build-tools/36.1.0/aapt dump badging build/app/outputs/flutter-apk/app-debug.apk
  Result: package name remained com.wrait.flutter.dev
- unzip -l build/app/outputs/flutter-apk/app-debug.apk | rg 'ic_launcher|mipmap-anydpi|drawable.*/ic_launcher'
  Result: packaged APK now contains:
    res/drawable/ic_launcher_background.xml
    res/drawable/ic_launcher_foreground.xml
    res/mipmap-anydpi-v21/ic_launcher.xml
    res/mipmap-anydpi-v21/ic_launcher_round.xml
- adb devices
  Result: no Android device was attached during the final adaptive-icon pass, so a fresh on-device install was not repeated in this pass

User-directed iPhone icon follow-up:
- tool/branding/generate_assets.sh
  Result: regenerated iOS app-icon assets successfully after switching the icon sources to full background plus `wrait`
- /opt/homebrew/bin/flutter test test/platform/branding_assets_test.dart
  Result: all tests passed with the updated iOS icon assets
- iOS release icon preview:
  ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
  Result: full cream background with dark `wrait`, no inner circle
- iOS debug icon preview:
  ios/Runner/Assets.xcassets/AppIconDebug.appiconset/Icon-App-1024x1024@1x.png
  Result: full red background with white `wrait`, no inner circle
```

## Notes

- Plan approved with validation exceptions for native launcher/app-switcher
  surfaces and release-runtime limitations.
- Release logo treatment is based on the current Wrait main button look: cream
  field with charcoal `wrait`.
- Debug/profile/dev logo treatment must be red and visually distinct.
- Modern Android launcher branding now follows the `wrait-android`
  adaptive-icon XML reference and no longer relies on generated launcher PNGs.
- `flutter_01.png` was treated as a pre-existing reference screenshot outside
  the platform asset pipeline and left untouched.
