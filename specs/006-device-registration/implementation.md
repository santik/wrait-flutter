# Implementation: Device Registration

> **Feature number:** 006
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-10

---

## Summary

US-016 is implemented as a non-blocking app-launch side effect started from
the bootstrapped `ProviderContainer` in `lib/main.dart`. The implementation
adds one dedicated launch-registration use case, one Riverpod-backed in-memory
quota state owner, and backend-compatible hashing for newly resolved device
IDs while preserving preexisting stored values unchanged.

## Implemented changes

### Launch orchestration

- Added `createAppContainer(...)` and `startAppLaunchWork(...)` in
  `lib/main.dart` so startup work can be triggered once per launch without
  waiting for UI render.
- Added
  `lib/domain/usecase/register_device_on_launch_use_case.dart` to centralize:
  - calling `WraitBackendClient.register()`
  - replacing session quota only when valid quota is returned
  - preserving existing in-memory quota on silent partial success
  - logging and swallowing registration failures or unexpected exceptions

### Session quota and logging

- Added `registrationQuotaStateProvider` in
  `lib/data/api/backend_providers.dart` as the in-memory session quota owner.
- Added `registrationWarningLoggerProvider` so warning logging stays injectable
  and testable without introducing a larger logging framework.
- Added `registerDeviceOnLaunchUseCaseProvider` to wire the use case to the
  existing backend client and preferences repository.

### Device-ID compatibility

- Added a direct `crypto` dependency in `pubspec.yaml`.
- Updated `PreferencesRepositoryImpl` to:
  - keep returning any already-stored device ID unchanged
  - hash newly resolved platform-backed IDs into a 64-character lowercase
    SHA-256 hex form using the app-scoped salt `wrait-v1`
  - hash newly generated fallback IDs before first persistence

## Validation

### Static analysis and unit-level validation

- `flutter analyze --no-pub`
- `flutter test --no-pub test/data/preferences/preferences_repository_impl_test.dart test/data/api/register_device_on_launch_use_case_test.dart test/data/api/backend_client_test.dart test/data/api/backend_providers_test.dart`

### Integration coverage

- Added `integration_test/device_registration_launch_flow_test.dart` covering:
  - non-blocking launch rendering while registration is still in flight
  - session quota update on successful registration
  - relaunch reuse of the stored device ID with fresh in-memory quota state
  - non-blocking transient failure that preserves quota

### Device/runtime verification

- iOS simulator:
  - Device: `iPhone 17`
  - Command:
    `flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/device_registration_launch_flow_test.dart`
  - Result: passed
- Android emulator:
  - Emulator: `Pixel_8_emulator` / device `emulator-5554`
  - Launch command:
    `emulator -avd Pixel_8_emulator -no-snapshot-load -no-boot-anim`
  - Test command:
    `flutter test --no-pub -d emulator-5554 integration_test/device_registration_launch_flow_test.dart`
  - Result: passed

## Notes

- The environment required `flutter analyze --no-pub` after `flutter pub get`
  because a plain analyze invocation tried to mutate
  `ios/Flutter/ephemeral/Packages/.packages`.
- Android emulator launch through `flutter emulators --launch ...` did not
  surface a connected device in time, so the verification used the Android SDK
  emulator binary directly to satisfy the planned Android runtime check.
- External review was explicitly skipped by the user, so no `review.md`
  artifact or remediation pass was performed for this story.
