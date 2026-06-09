# Tasks: Flutter Project Foundation

> **Feature number:** 002
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-03

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

_Tasks are organized into sequential groups.
Tasks within the same group marked `[P]` can be worked on in parallel._

### Group 1: Scaffold the Flutter baseline

_Generate the project and establish the repository-level Flutter foundation._

- [x] Generate the Flutter app at the repository root with Android and iOS targets only — repo root scaffold, `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, `.metadata`, `README.md`, `android/`, `ios/`, `lib/`, `test/`
- [x] Update project identity and platform baselines to align with the plan — `pubspec.yaml`, `android/app/build.gradle.kts`, `android/app/src/main/kotlin/com/wrait/app/MainActivity.kt`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/Podfile`
- [x] Add the approved dependency set and dev tooling baseline without introducing feature implementations — `pubspec.yaml`, `analysis_options.yaml`

### Group 2: Build the app shell and configuration layer

_Replace the default sample app with the minimal production-shaped structure required by US-001._

- [x] Create the top-level source structure for `core`, `data`, `domain`, and `presentation` while keeping empty layers minimal — `lib/core/`, `lib/data/`, `lib/domain/`, `lib/presentation/`
  - Depends on: Group 1
- [x] Implement typed runtime configuration loading and validation for backend URL, proxy secret, and recording hard cap — `lib/core/config/app_config.dart`
  - Depends on: Group 1
- [x] Replace the default Flutter sample entrypoint with a Riverpod-bootstrapped app root that loads validated `AppConfig` and makes it available to the app shell — `lib/main.dart`, `lib/app.dart`
  - Depends on: Group 1
- [x] Add a minimal GoRouter setup with a single placeholder route and screen that can safely reflect non-sensitive runtime configuration for manual verification — `lib/core/router/app_router.dart`, `lib/presentation/home/home_placeholder_screen.dart`
  - Depends on: Group 1

### Group 3: Apply platform-specific capability configuration

_Patch the generated mobile targets so later recording features can request the right permissions._

- [x] Configure Android for the required product minimum and recording permission declaration — `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`
  - Depends on: Group 1
- [x] Configure iOS for the required deployment target and microphone/speech usage descriptions — `ios/Podfile`, `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj`
  - Depends on: Group 1

### Group 4: Add validation coverage

_Prove bootstrap correctness and keep the foundation safe to extend._

- [x] Write unit tests for `AppConfig` defaults, overrides, and invalid hard-cap handling — `test/core/config/app_config_test.dart`
  - Depends on: Group 2
- [x] Write a widget smoke test that verifies the placeholder app shell renders — `test/app_smoke_test.dart`
  - Depends on: Group 2

### Group 5: Verify the foundation end to end

_Collect the validation evidence required by the constitution and spec._

- [x] Run dependency resolution and record whether all declared packages resolve cleanly — `flutter pub get`
  - Depends on: Groups 1, 2, 3
- [x] Run static analysis and record zero-warning evidence — `flutter analyze`
  - Depends on: Groups 2, 3, 4
- [x] Run the automated test suite and record results — `flutter test`
  - Depends on: Group 4
- [x] Launch on Android with `--dart-define` values and verify the placeholder screen appears with the expected non-sensitive config-derived state — `flutter run -d <android-device> --dart-define=...`
  - Depends on: Groups 2, 3
- [x] Launch on iOS with `--dart-define` values and verify the placeholder screen appears with the expected non-sensitive config-derived state — `flutter run -d <ios-simulator> --dart-define=...`
  - Depends on: Groups 2, 3
- [x] Record validation evidence and any deviations directly in this file — `specs/002-flutter-project-foundation/tasks.md`
  - Depends on: Groups 1, 2, 3, 4, 5

## Completion criteria

All tasks checked, Flutter dependency resolution clean, `flutter analyze` warning-free,
`flutter test` passing, Android and iOS launch verification completed, and
validation evidence documented in this file.

## Validation evidence

_Record test results, screenshots, or curl output here when complete._

```text
$ flutter pub get
Changed 1 dependency!
The following plugins do not support Swift Package Manager for ios:
  - sqflite_sqlcipher

$ flutter analyze
No issues found! (ran in 4.6s)

$ flutter test
00:00 +4: All tests passed!

$ flutter build apk --debug --dart-define=BACKEND_URL=https://wrait-backend.vercel.app --dart-define=PROXY_SECRET=placeholder-secret --dart-define=RECORDING_HARD_CAP_MS=120000
✓ Built build/app/outputs/flutter-apk/app-debug.apk

$ flutter devices
Found 2 connected devices:
  macOS (desktop)
  Chrome (web)

$ flutter emulators
No emulators available.

$ xcrun simctl list devices available
xcrun: error: unable to find utility "simctl", not a developer tool or in PATH

$ flutter build ios --simulator --no-codesign --dart-define=BACKEND_URL=https://wrait-backend.vercel.app --dart-define=PROXY_SECRET=placeholder-secret --dart-define=RECORDING_HARD_CAP_MS=120000
Application not configured for iOS

$ flutter run -d emulator-5554 --dart-define=BACKEND_URL=https://wrait-backend.vercel.app --dart-define=PROXY_SECRET=placeholder-secret --dart-define=RECORDING_HARD_CAP_MS=120000
Launched on Android emulator and verified rendered values via UI dump:
- Foundation ready
- wrait-backend.vercel.app
- 120 seconds
- Configured

$ flutter run -d 0140EF83-0B3E-4517-B669-FDBE5E3B0BBA --dart-define=BACKEND_URL=https://wrait-backend.vercel.app --dart-define=PROXY_SECRET=placeholder-secret --dart-define=RECORDING_HARD_CAP_MS=120000
Launched on iPhone 17 Pro simulator and verified rendered values in simulator screenshot:
- Foundation ready
- wrait-backend.vercel.app
- 120 seconds
- Configured
```

## Notes

- Flutter 3.44 generated a Swift Package Manager-first iOS project without a Podfile, so a root `ios/Podfile` was added to keep a CocoaPods path available for plugins like `sqflite_sqlcipher` that do not yet support Swift Package Manager.
- Several plugins emit a Kotlin Gradle Plugin migration warning during Android builds (`package_info_plus`, `share_plus`, `speech_to_text`, `wakelock_plus`). The build still succeeds, but these warnings should be revisited during dependency maintenance.
- Android build validation succeeded after Flutter installed missing local SDK components (NDK 28.2.13676358 and CMake 3.22.1) on first build.
- CocoaPods 1.16.2 initially crashed against the generated Podfile shape; removing the explicit Xcode configuration mapping and test-target nesting from `ios/Podfile` allowed `pod install` and the iOS simulator launch to succeed.
