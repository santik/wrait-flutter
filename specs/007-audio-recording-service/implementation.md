# Implementation: Audio Recording Service

> **Feature number:** 007
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-10

---

## Summary

US-006 is implemented as a reusable app-facing recording service layered over
the existing `record` dependency. The implementation adds a monotonic
deadline/time abstraction, a plugin-backed service with typed failure handling
for concurrent starts, inactive stops, and too-short recordings, plus
Riverpod wiring so later orchestration stories can depend on a single capture
surface instead of calling the plugin directly.

## Implemented changes

### Time and service contracts

- Added `lib/core/time/monotonic_clock.dart` with:
  - `MonotonicClock`
  - `StopwatchMonotonicClock`
- Added `lib/data/audio/audio_recording_service.dart` with:
  - `AudioRecordingService`
  - `minimumRecordingDuration`
  - `RecordingAlreadyInProgressFailure`
  - `NoActiveRecordingFailure`
  - `RecordingTooShortFailure`

### Plugin-backed recording implementation

- Added `lib/data/audio/record_audio_recording_service.dart`.
- The concrete implementation:
  - configures AAC/M4A recording at 16 kHz mono
  - tracks the active output path, start elapsed time, and hard-cap deadline
  - rejects competing `startRecording(...)` calls
  - rejects `stopRecording()` when no session is active
  - deletes too-short files before throwing `RecordingTooShortFailure`
  - leaves successful file lifecycle ownership to later transcription/draft
    consumers
  - serializes start/stop/dispose transitions to avoid overlapping recorder
    operations

### Provider wiring

- Added `lib/data/audio/audio_recording_providers.dart`.
- The provider layer now exposes:
  - `monotonicClockProvider`
  - `recorderAdapterProvider`
  - `audioRecordingServiceProvider`

## Automated validation

### Unit tests

- Added `test/test_doubles/fake_monotonic_clock.dart`.
- Added `test/data/audio/audio_recording_service_test.dart` covering:
  - blank-path rejection
  - serialized concurrent-start rejection
  - mono/16 kHz/AAC config requests
  - valid stop success
  - too-short cleanup and failure
  - no-active-session stop failure
  - hard-cap deadline derivation

### Integration tests

- Added `integration_test/audio_recording_service_flow_test.dart` covering:
  - provider-graph start/stop success
  - orchestrator-style hard-cap stop using the exposed deadline
  - provider-graph too-short rejection

## Validation

### Static analysis and full regression suite

- `flutter analyze`
- `flutter test --no-pub`

Both completed successfully in this session.

### Mobile integration coverage

- Android emulator:
  - Device: `emulator-5554`
  - Command:
    `flutter test --no-pub -d emulator-5554 integration_test/audio_recording_service_flow_test.dart`
  - Result: passed
- iOS simulator:
  - Device: `491CD949-D3C0-4C4C-A6B9-15BAB1859156` (`iPhone 17`)
  - Command:
    `flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/audio_recording_service_flow_test.dart`
  - Result: passed

### Real runtime recording probes

Temporary runtime-only probe tests were used during this session and removed
after validation so they do not remain in the repo.

- Android emulator:
  - Preinstalled command:
    `adb -s emulator-5554 install -r -g build/app/outputs/flutter-apk/app-debug.apk`
  - Probe command:
    `flutter test --no-pub -d emulator-5554 integration_test/audio_recording_runtime_probe_test.dart`
  - Result: passed
  - Observed file:
    `/data/user/0/com.wrait.app/cache/runtime-probe-1781092815274.m4a`
  - Observed live cache entry:
    `-rw------- ... 76960 ... runtime-probe-1781092815274.m4a`
- iOS simulator:
  - Probe command:
    `flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/audio_recording_runtime_probe_test.dart`
  - Result: passed
  - Observed file:
    `/Users/alexander/Library/Developer/CoreSimulator/Devices/491CD949-D3C0-4C4C-A6B9-15BAB1859156/data/Containers/Data/Application/.../Library/Caches/runtime-probe-1781092664546.m4a`

## Notes

- `flutter test --no-pub` was required in this environment because a plain
  `flutter test` attempted to refresh `ios/Flutter/ephemeral/Packages` and
  failed while mutating that generated area.
- The Android and iOS runtime probes confirmed that the real plugin-backed
  service can start, record for more than 5 seconds, stop cleanly, and produce
  non-empty `.m4a` output files on both platforms.
- A follow-up attempt to inspect the iOS simulator file with a host-side media
  tool after the probe ended was not reliable because `flutter test` teardown
  removed the app container before post-run inspection could complete.

## Review remediation

The first external review pass requested stronger lifecycle and failure-path
handling around the recorder implementation. The approved remediation updated
the service as follows:

- `dispose()` now cancels an in-progress recording and deletes the partial file
  before disposing the underlying recorder.
- `startRecording()` now:
  - validates the output parent path
  - creates the parent directory when needed
  - verifies the target location is writable
  - cancels and cleans up if the underlying recorder throws during start
- `stopRecording()` now:
  - cleans up consistently if `recorder.stop()` throws
  - validates that the resolved output file exists and is non-empty before
    returning it
  - throws `RecordingOutputUnavailableFailure` when a usable output file is
    not produced
- Temporary-file cleanup failures are now logged through `dart:developer`
  instead of being swallowed silently.

Additional regression coverage added in the remediation pass:

- dispose during active recording
- recorder start failure
- missing or unusable stop output
- invalid output parent path handling

### Remediation validation refresh

- `flutter analyze` passed again after the remediation changes.
- `flutter test --no-pub` passed again after the remediation changes.
- `integration_test/audio_recording_service_flow_test.dart` passed again on:
  - Android emulator `emulator-5554`
  - iOS simulator `491CD949-D3C0-4C4C-A6B9-15BAB1859156`
- Temporary runtime probes were rerun and passed again on both platforms, then
  removed from the repo after validation:
  - Android output:
    `/data/user/0/com.wrait.app/cache/runtime-probe-1781120490839.m4a`
  - iOS output:
    `/Users/alexander/Library/Developer/CoreSimulator/Devices/491CD949-D3C0-4C4C-A6B9-15BAB1859156/data/Containers/Data/Application/D78EBFFC-07E0-4F61-B297-C785AB26015B/Library/Caches/runtime-probe-1781120502542.m4a`
