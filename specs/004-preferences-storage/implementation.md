# Implementation: Preferences Storage

> **Feature number:** 004
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-09

## Summary

US-004 is implemented as a small infrastructure slice:

- `hasEverRecorded` is persisted through `shared_preferences`
- device ID retrieval is centralized behind a Dart contract and resolves to
  one stored opaque app device ID
- first resolution prefers Android `Settings.Secure.ANDROID_ID` or iOS
  `UIDevice.current.identifierForVendor` when available
- when no platform ID is available, a generated fallback ID is created,
  stored, and reused

## Key files

- `lib/domain/repository/preferences_repository.dart`
- `lib/data/preferences/platform_device_id_provider.dart`
- `lib/data/preferences/preferences_repository_impl.dart`
- `lib/data/preferences/preferences_providers.dart`
- `lib/main.dart`
- `android/app/src/main/kotlin/com/wrait/app/MainActivity.kt`
- `ios/Runner/AppDelegate.swift`
- `test/data/preferences/platform_device_id_provider_test.dart`
- `test/data/preferences/preferences_repository_impl_test.dart`

## Notable implementation details

- The platform provider is best-effort only and returns `null` when the method
  channel is unavailable or the platform value is blank.
- The repository owns resolution order:
  - stored device ID
  - platform device ID
  - generated fallback device ID
- The first resolved app device ID is persisted in shared preferences and
  cached in memory for subsequent reads.
- The rest of the application receives only the resolved stored device ID and
  is not told whether it came from the platform or fallback generation.
- `setHasEverRecorded` still reports failed writes explicitly.
- Startup injection uses a `SharedPreferences` provider override so future
  feature code can read the repository from Riverpod without extra bootstrap
  plumbing.

## Validation

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `flutter build ios --simulator --debug --no-codesign`

## Environment notes

Live device/simulator launches were not available during this implementation
pass:

- `adb devices` did not yield a usable attached Android device list
- `simctl` could not connect to CoreSimulatorService

Platform builds were used to validate native integration in place of live
launch verification.
