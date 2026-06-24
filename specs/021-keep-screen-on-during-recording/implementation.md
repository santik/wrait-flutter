# Implementation: Keep Screen On During Recording

> **Feature number:** 021
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-24

---

## Summary

US-021 now keeps the display awake only while Wrait is actively listening in
the foreground. Uploading, processing, saved, error, deleted, background, and
app-lock states all release display-awake behavior, and cleanup also happens
when the main recording surface is disposed.

The implementation keeps the platform call behind an app-owned service,
preserves the current recording controller responsibilities, and leaves
recording, transcription, cleanup, drafts, quota, navigation, capture
prevention, and app-lock behavior otherwise unchanged.

## What changed

### Display-awake service

- Added `lib/data/display/display_awake_service.dart`
  - defines `DisplayAwakeService`
  - wraps `WakelockPlus.toggle(enable: ...)` behind an injectable
    `WakelockClient`
  - logs platform failures instead of surfacing user-visible errors
  - reports success/failure back to the coordinator so failed platform calls do
    not get mistaken for applied state

### Main-screen coordinator

- Added `lib/presentation/main/recording_display_awake_coordinator.dart`
  - computes the desired keep-awake state from:
    - `RecordingState`
    - `AppLifecycleState`
    - `AppLockState`
  - enables keep-awake only for `RecordingListening` while resumed and
    unlocked
  - tracks desired state separately from applied state
  - serializes async platform calls so rapid transitions do not overlap
  - retries same-state updates after failed platform applies
  - releases keep-awake on disposal, including when disposal races an in-flight
    enable request

### Main-screen wiring

- Updated `lib/presentation/main/main_screen.dart`
  - creates the coordinator from the existing provider graph
  - feeds recording-state transitions from `mainRecordingControllerProvider`
  - feeds lifecycle changes from `WidgetsBindingObserver`
  - feeds app-lock changes from `appLockControllerProvider`
  - preserves the existing microphone-permission resume check and countdown
    behavior
  - defaults an unknown initial lifecycle state to inactive until Flutter emits
    a definitive lifecycle callback
  - treats app lock as inactive only when app lock is actually enabled

### Test coverage

- Added `test/data/display/display_awake_service_test.dart`
  - verifies wakelock delegation
  - verifies failure logging
- Added `test/presentation/main/recording_display_awake_coordinator_test.dart`
  - verifies listening enablement
  - verifies release on upload, processing, idle, saved, error, deleted
  - verifies lifecycle release/reacquire
  - verifies app-lock release/reacquire
  - verifies duplicate-transition idempotency
  - verifies rapid-transition coalescing
  - verifies disposal cleanup, including in-flight enable disposal
  - verifies retry after failed enable and no-op behavior after disposal
- Updated `test/presentation/main/main_screen_test.dart`
  - verifies `MainScreen` enables keep-awake while listening
  - verifies release on uploading, lifecycle exit, disposal, and app-lock
  - verifies conservative inactive startup behavior
  - verifies failed enable recovery does not break UI flow
- Added `integration_test/main_screen_display_awake_flow_test.dart`
  - verifies the app-level main-screen wiring with fake recording/app-lock
    state and a fake display-awake service on Android emulator and iOS
    simulator
  - verifies a failed enable is retried by later lifecycle-driven transitions

## Behavior notes

- The feature does not use `RecordingControllerState.isActive`, because that
  state includes uploading and processing and would violate the approved scope.
- App-lock remains a privacy feature only. It now also acts as an inactive
  signal for display-awake behavior.
- Manual device lock, power-button press, power off, and operating-system power
  behavior remain outside app control by spec.
- No persisted data model or preferences schema changed.

## Validation evidence

### Automated

- PASS `/opt/homebrew/bin/flutter test test/data/display/display_awake_service_test.dart test/presentation/main/recording_display_awake_coordinator_test.dart test/presentation/main/main_screen_test.dart`
- PASS `/opt/homebrew/bin/flutter test integration_test/main_screen_display_awake_flow_test.dart`
- PASS `/opt/homebrew/bin/flutter test -d emulator-5554 integration_test/main_screen_display_awake_flow_test.dart`
- PASS `/opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_display_awake_flow_test.dart`
- PASS `/opt/homebrew/bin/flutter analyze`
- PASS remediation rerun `/opt/homebrew/bin/flutter test test/data/display/display_awake_service_test.dart test/presentation/main/recording_display_awake_coordinator_test.dart test/presentation/main/main_screen_test.dart`
- PASS remediation rerun `/opt/homebrew/bin/flutter test -d emulator-5554 integration_test/main_screen_display_awake_flow_test.dart`
- PASS remediation rerun `/opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_display_awake_flow_test.dart`
- PASS remediation rerun `/opt/homebrew/bin/flutter analyze`
- INFO remediation host-desktop attempt `/opt/homebrew/bin/flutter test -d macos integration_test/main_screen_display_awake_flow_test.dart` was not applicable because the repo does not include a macOS desktop target

### Android emulator

- PASS direct AVD launch fallback:
  `/Users/alexander/Library/Android/sdk/emulator/emulator -avd Pixel_8_emulator -no-snapshot-load`
- PASS `adb -s emulator-5554 shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity`
  - `Status: ok`
  - `LaunchState: COLD`
  - `Activity: com.wrait.flutter/.MainActivity`
  - `TotalTime: 2806`
- PASS targeted emulator integration covered:
  - listening -> upload/saved release
  - listening -> error release
  - listening -> background/app-lock release
- PASS remediation launcher verification:
  `adb -s emulator-5554 shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity`
  - `Status: ok`
  - `LaunchState: WARM`
  - `Activity: com.wrait.flutter/.MainActivity`
  - `TotalTime: 1264`

### iOS simulator

- PASS targeted simulator integration on
  `491CD949-D3C0-4C4C-A6B9-15BAB1859156`
- PASS the integration test compiled and ran through the iPhone 17 simulator
  Xcode path
- PASS targeted simulator integration covered:
  - listening -> upload/saved release
  - listening -> error release
  - listening -> background/app-lock release

## Validation notes and limitations

- The approved validation exception was used for OS-level idle dim/lock
  behavior. Flutter integration tests verified the app contract through a fake
  display-awake service, while runtime evidence covered actual Android and iOS
  device-targeted execution.
- The Android emulator booted with `screen_off_timeout=2147483647`, so an
  ordinary idle-lock baseline was not reliable there without additional
  environment manipulation that would still not prove the absence-of-wakelock
  path cleanly.
- The Android runtime package present on the emulator validation path was
  `com.wrait.flutter`, confirmed via `adb shell pm list packages`.
- The generated backend API package was already present locally, so `npm run build`
  was not needed for this implementation pass.
- No dedicated keep-awake performance benchmark was added in this story. The
  runtime operation remains a serialized platform toggle outside the recording
  controller hot path, and validation found no functional regressions.

## Deviations from plan

One implementation-time artifact correction from Analyze carried into code:

- integration coverage lives in
  `integration_test/main_screen_display_awake_flow_test.dart`
  instead of extending `main_recording_controller_flow_test.dart`, because the
  approved architecture puts the keep-awake coordinator in `MainScreen`, not in
  the controller itself.

One remediation-time validation note was also recorded:

- the plan's "host or default test target" integration command is no longer
  reliable in this environment because multiple runtime targets are connected,
  and this repo has no macOS desktop target. The remediation pass therefore
  reran the device-targeted Android emulator and iOS simulator integration
  checks directly.

One second-review cleanup note was recorded:

- the shared `FakeDisplayAwakeService.flush()` helper still uses two zero-delay
  turns, but that behavior is now documented explicitly because the first turn
  drains the coordinator's queued sync callback and the second lets the fake
  platform completion propagate back into coordinator state.

## Review status

The first and second external review passes have been remediated. The remaining
second-pass notes were accepted as non-blocking within US-021 scope:

- no platform wakelock readback/reconciliation was added because the spec
  already allows OS and manual overrides outside app control
- no extra coordinator input assertions were added beyond disposed-state guards
  because the current callers are strongly typed and trusted
- no dedicated keep-awake benchmark was added for this story
- real-plugin end-to-end validation remains covered by the approved validation
  exception plus runtime evidence

Per the SDD workflow, the feature is now waiting for the next external review
pass or explicit user direction before any finalization-only documentation
changes.
