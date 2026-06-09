# Tasks: Preferences Storage

> **Feature number:** 004
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-09

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups.
Tasks within the same group marked `[P]` can be worked on in parallel.

### Group 1: Foundation

Reframe the existing implementation around repository-owned device-ID
resolution and persistence.

- [x] Preserve the public `PreferencesRepository` contract while updating the implementation semantics to repository-owned opaque device-ID resolution — `lib/domain/repository/preferences_repository.dart`
- [x] Update the platform device-ID provider so it reports best-effort platform availability instead of treating missing values as a fatal app-level error — `lib/data/preferences/platform_device_id_provider.dart`

### Group 2: Core implementation

Implement stored-value precedence, fallback generation, and encapsulation.

- [x] Modify `PreferencesRepositoryImpl` so `getDeviceId()` resolves in this order: stored value, platform value, generated fallback — `lib/data/preferences/preferences_repository_impl.dart`
  - Depends on: Group 1
- [x] Persist the first resolved device ID and cache it in memory so later calls do not re-query the platform or regenerate fallback values — `lib/data/preferences/preferences_repository_impl.dart`
  - Depends on: Group 2 device-ID resolution
- [x] Keep `hasEverRecorded` persistence behavior intact while adding explicit handling for write-failure reporting — `lib/data/preferences/preferences_repository_impl.dart`
  - Depends on: Group 1
- [x] Keep the provider surface stable while wiring the revised repository behavior — `lib/data/preferences/preferences_providers.dart`
  - Depends on: Group 1
- [x] Verify startup wiring remains compatible with the revised repository behavior and persisted opaque device ID — `lib/main.dart`
  - Depends on: Group 2 core repository and providers
- [x] Keep the Android `MethodChannel` implementation aligned with the best-effort platform ID contract — `android/app/src/main/kotlin/com/wrait/app/MainActivity.kt`
  - Depends on: Group 1 platform channel contract
- [x] Keep the iOS `MethodChannel` implementation aligned with the best-effort platform ID contract — `ios/Runner/AppDelegate.swift`
  - Depends on: Group 1 platform channel contract

### Group 3: Integration

Verify encapsulation and no-source-leak behavior.

- [x] Ensure the repository exposes one centralized opaque device-ID path and does not reveal whether the stored value came from the platform or fallback generation — `lib/data/preferences/preferences_repository_impl.dart`
  - Depends on: Group 2
- [x] Ensure missing or blank platform device-ID results trigger fallback generation and persistence instead of interrupting the user — `lib/data/preferences/preferences_repository_impl.dart`, `lib/data/preferences/platform_device_id_provider.dart`
  - Depends on: Group 2
- [x] Capture in implementation notes and validation evidence that the app stores one resolved opaque device ID whose origin is intentionally hidden from the rest of the application — `specs/004-preferences-storage/tasks.md`, `specs/004-preferences-storage/implementation.md`
  - Depends on: Group 2

### Group 4: Validation

Tests, manual verification, and evidence capture.

- [x] Update platform device-ID provider tests to cover successful platform reads plus unavailable bridge/value cases, including `MissingPluginException` — `test/data/preferences/platform_device_id_provider_test.dart`
- [x] Update repository tests to cover stored-value precedence, platform-value persistence, fallback generation persistence, in-memory caching, write-failure handling, and no source leakage — `test/data/preferences/preferences_repository_impl_test.dart`
- [x] Run `flutter analyze` and record the result in Validation evidence
- [x] Run `flutter test` and record the result in Validation evidence
- [x] Launch the app on Android and verify startup still succeeds after preferences bootstrap
- [x] Launch the app on iOS and verify startup still succeeds after preferences bootstrap

## Completion criteria

All tasks checked, `flutter analyze` clean, `flutter test` passing, and
validation evidence documented in this file.

## Validation evidence

Record test results and manual verification notes here when complete.

```
$ flutter analyze
Analyzing write-flutter...
No issues found! (ran in 4.8s)

$ flutter test
49 tests passed.

$ flutter build apk --debug
Built build/app/outputs/flutter-apk/app-debug.apk

$ flutter build ios --simulator --debug --no-codesign
Built build/ios/iphonesimulator/Runner.app

Note:
Live Android/iOS launches were not available in this environment because
`adb devices` did not produce a usable attached device list and
CoreSimulatorService was unavailable. Successful platform builds were used as
the startup-integration verification substitute for this revised implementation
pass.
```

## Notes

- The revised implementation pass replaced the old “platform failure propagates upward” behavior with repository-owned fallback generation and persistence.
- The implementation continues to use a Riverpod `sharedPreferencesProvider` override at startup.
- The stored app device ID is intentionally opaque to feature code; platform origin is used only during first resolution when no stored value exists yet.
