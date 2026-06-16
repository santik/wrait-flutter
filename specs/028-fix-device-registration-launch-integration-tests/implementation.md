# Implementation: Fix Device Registration Launch Integration Tests

> **Feature number:** 028
> **Story:** [`../../plan/us_028.md`](../../plan/us_028.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Spec:** Skipped by explicit user direction on 2026-06-16.
> **Plan:** Skipped by explicit user direction on 2026-06-16.
> **Author:** Codex
> **Date:** 2026-06-16

---

## Summary

US-028 is implemented with both the scoped integration-test fix and the
smallest production launch correction that real-device validation proved
necessary.

Investigation started with the failing
`integration_test/device_registration_launch_flow_test.dart` coverage, then
continued into a deployed-app runtime issue on the same Android phone: the app
stayed behind the launch screen or a blank first frame instead of showing the
main screen.

The final fix has two parts:

- the launch-registration integration tests now use stable launch-UI checks and
  deterministic synchronization
- app startup now renders immediately through a bootstrap gate, and the
  encrypted local database no longer opens through the stalled background-open
  path on the real Android install

Follow-up real-device validation uncovered one more deploy-path gap:

- `deploy_debug.sh` built and installed a debug APK without passing
  `PROXY_SECRET`, so launch registration and recording requests from the
  installed app could reach the backend with an empty `X-Proxy-Secret` header
- the installed app also lacked an explicit microphone-permission request flow,
  so denied `RECORD_AUDIO` access surfaced later as a generic recording
  failure instead of the existing `mic blocked` state

## Root cause

Two separate issues were involved on the real-device path:

1. The launch integration tests still asserted `find.text('Capture')`, but the
   current idle main-screen button label is `wrait`, not `Capture`.
2. The tests relied on passive waits (`Future.delayed(...)` and one plain
   future wait) around asynchronous registration work and stub-server response
   release, which made the device run fragile.
3. During manual phone validation, the deployed app itself also revealed a
   startup problem: bootstrapping the encrypted local store before `runApp`
   kept the first Flutter frame hidden, and the encrypted database open path
   using `NativeDatabase.createInBackground(...)` appeared to stall on the real
   Android install after secure-storage initialization.

The test fix solved the original US-028 failures. The startup fix addressed the
production issue discovered during that same real-device validation.
Later follow-up validation identified and fixed the missing microphone
permission handling on the installed Android app.

## Code changes

### `integration_test/device_registration_launch_flow_test.dart`

- Replaced stale launch-screen text expectations with a stable launch UI check
  based on dedicated stable test anchors from
  `lib/presentation/main/main_screen_test_keys.dart`.
- Added `_pumpUntil(...)` so the tests actively drive the widget/event loop
  while waiting for:
  - request dispatch in the success case
  - quota propagation after a successful registration response
  - second-launch quota hydration
  - retry completion in the transient-failure case
- Replaced the transient-failure hardcoded request count `3` with
  `WraitBackendClient.maxRegisterAttempts` so the test tracks the real retry
  contract.
- Hardened stub-server teardown so the success-case response gate is released
  before closing the server, preventing cleanup from getting stuck if a failure
  happens before the explicit response release point.

### `lib/main.dart`

- Replaced the fully blocking startup sequence with `BootstrapApp`, which
  renders immediately and asynchronously loads app dependencies.
- Added a visible loading state and retry state so the app no longer sits
  behind the Flutter launch screen without feedback.
- Added startup logging around the bootstrap flow.
- Added single-flight bootstrap/retry coordination so rapid retry taps cannot
  start overlapping bootstrap runs or stale runtime assignment.
- Preserved non-blocking launch registration by starting
  `startAppLaunchWork(...)` only after the provider container is ready.

### `lib/data/entries/local_entry_database.dart`

- Replaced `NativeDatabase.createInBackground(...)` with direct
  `NativeDatabase(...)` opening for the encrypted database bootstrap path.
- Added database-open timing logs for both the normal open path and the
  recovery path so startup performance is visible in logs.
- Kept the existing cipher verification and `PRAGMA key` behavior unchanged.

### `test/bootstrap_app_test.dart`

- Added widget coverage for bootstrap loading, success, and retryable error
  states.

### `deploy_debug.sh`

- The debug deploy command now requires a non-empty `PROXY_SECRET`
  environment variable.
- Added `PROXY_SECRET` sanity validation: no whitespace and a minimum length of
  8 characters.
- The APK build step now passes
  `--dart-define=PROXY_SECRET=...` so the installed debug app sends the real
  proxy-auth header instead of the empty default.
- The script now removes any stale APK before build, verifies the built APK
  exists and is non-empty, and re-checks that the phone is still connected
  before installation.

### `test/deploy_debug_script_test.sh`

- Added coverage that `deploy_debug.sh` fails fast when `PROXY_SECRET` is
  missing.
- Added coverage for short/whitespace `PROXY_SECRET` values, stale/missing APK
  prevention, empty APK rejection, and phone disconnects before install.
- Updated the successful one-phone path to assert the build command includes
  the `PROXY_SECRET` Dart define and that the script revalidates device state.

### `README.md`

- Documented the required `PROXY_SECRET=... ./deploy_debug.sh` invocation and
  the new deploy-script validation checks.

### `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`

- Wrapped Android device-ID lookup in `try/catch` and now return a structured
  platform-channel error instead of letting Android exceptions escape through
  the method channel.

### `lib/data/audio/microphone_permission_service.dart`

- Added a permission-handler-backed microphone permission service for explicit,
  testable runtime permission handling.
- Expanded permission handling to distinguish granted, denied,
  permanently denied, and restricted microphone access states.

### `lib/data/audio/record_audio_recording_service.dart`

- Recording start now ensures microphone access before touching the recorder or
  preparing an output path.
- Added a typed `RecordingPermissionDeniedFailure` when microphone access is
  denied.

### `lib/data/transcription/cloud_transcription_service.dart`

- Mapped `RecordingPermissionDeniedFailure` into
  `MicBlockedTranscriptionServiceFailure` so the UI shows the intended
  microphone-blocked state instead of a generic error.

### `test/data/audio/audio_recording_service_test.dart`

- Added coverage that denied microphone access fails recording start cleanly
  without touching the recorder.
- Added coverage that permanently denied microphone access preserves the richer
  denied state in the thrown recording failure.

### `test/data/transcription/cloud_transcription_service_test.dart`

- Added coverage that denied microphone access surfaces a typed start failure.

### `test/presentation/main/main_recording_controller_test.dart`

- Added controller coverage that blocked microphone access publishes the
  `insufficientPermissions` state.

### `test/bootstrap_app_test.dart`

- Added coverage that rapid retry taps do not start overlapping bootstrap
  attempts.

### `test/data/entries/entry_database_test.dart`

- Added a host-side seeded reopen check with 1000 persisted entries and timing
  output to document the current direct-open startup cost.

## Production impact

- `startAppLaunchWork(...)` remains non-blocking.
- Launch registration still:
  - updates session quota on successful registration
  - preserves the existing session quota on transient failure
  - reuses the stored device ID across launches
- The app now reaches a visible first frame immediately instead of waiting for
  all startup dependencies to finish before `runApp`.

## Validation evidence

```text
$ dart format integration_test/device_registration_launch_flow_test.dart
Formatted 1 file (0 changed) in 0.01 seconds.

$ /opt/homebrew/bin/flutter analyze
No issues found! (ran in 2.8s)
Note: the first sandboxed attempt failed while touching ios/Flutter/ephemeral;
the successful result came from an unrestricted rerun.

$ /opt/homebrew/bin/flutter test
All tests passed! (195 tests)

$ adb devices
List of devices attached
4A181FDJH0030G	device
emulator-5554	device

$ adb -s 4A181FDJH0030G shell pm path com.wrait.app
package:/data/app/.../com.wrait.app.../base.apk

$ adb -s 4A181FDJH0030G shell pm path com.wrait.flutter
not installed before deploy validation (command exited 1)

$ /opt/homebrew/bin/flutter test --no-pub -d 4A181FDJH0030G integration_test/device_registration_launch_flow_test.dart
All tests passed! (3 tests)

$ ./deploy_debug.sh
...
03:58 +25: integration_test/device_registration_launch_flow_test.dart: launch registration is non-blocking and updates session quota on success
03:59 +26: integration_test/device_registration_launch_flow_test.dart: a new launch reuses the stored device id but starts with fresh in-memory quota state
04:00 +27: integration_test/device_registration_launch_flow_test.dart: transient launch registration failure is non-blocking and preserves quota
...
04:55 +34: All tests passed!
Detected existing native Wrait app (com.wrait.app); it will be left installed.
Installing debug APK on 4A181FDJH0030G...
Success
Verified com.wrait.app remains installed.
Installed com.wrait.flutter on 4A181FDJH0030G.

$ adb -s 4A181FDJH0030G shell pm path com.wrait.flutter
package:/data/app/.../com.wrait.flutter.../base.apk

$ adb -s 4A181FDJH0030G shell monkey -p com.wrait.flutter -c android.intent.category.LAUNCHER 1
Events injected: 1

$ /opt/homebrew/bin/flutter build apk --debug
Built build/app/outputs/flutter-apk/app-debug.apk

$ adb -s 4A181FDJH0030G install -r build/app/outputs/flutter-apk/app-debug.apk
Performing Streamed Install
Success

$ adb -s 4A181FDJH0030G shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity
Status: ok
Activity: com.wrait.flutter/.MainActivity

Manual Android phone verification after the runtime fix:
- device awake and unlocked
- `com.wrait.flutter` foregrounded
- main screen visible with the `wrait` action button
- status line visible with `tap button to write`
- stats line visible with `0 entries - 0 days`

$ bash test/deploy_debug_script_test.sh
deploy_debug_script_test.sh: all tests passed

$ PROXY_SECRET=SECRET_WRAIT_VALUE ./deploy_debug.sh
Building Flutter debug APK...
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Running Flutter integration tests on 4A181FDJH0030G...
...
Installed com.wrait.flutter on 4A181FDJH0030G.

Manual Android phone follow-up after the deploy-script proxy-secret fix:
- the installed debug APK was rebuilt and installed with
  `PROXY_SECRET=SECRET_WRAIT_VALUE`
- Android logcat no longer supports the earlier conclusion that the installed
  app sent the empty default proxy secret
- subsequent launch attempts on the phone hit Android `keystore2`
  `KEY_USER_NOT_AUTHENTICATED` errors and stayed on a black frame, which now
  looks like a device-auth/secure-storage state issue rather than the old
  missing proxy-secret header

$ /opt/homebrew/bin/flutter test test/data/audio/audio_recording_service_test.dart test/data/transcription/cloud_transcription_service_test.dart test/presentation/main/main_recording_controller_test.dart
All tests passed! (49 tests)

$ /opt/homebrew/bin/flutter build apk --debug --dart-define=PROXY_SECRET=SECRET_WRAIT_VALUE
Built build/app/outputs/flutter-apk/app-debug.apk

$ adb -s 4A181FDJH0030G install -r build/app/outputs/flutter-apk/app-debug.apk
Performing Streamed Install
Success

$ adb -s 4A181FDJH0030G shell dumpsys package com.wrait.flutter
...
runtime permissions:
  android.permission.RECORD_AUDIO: granted=false, flags=[ USER_SENSITIVE_WHEN_GRANTED|USER_SENSITIVE_WHEN_DENIED]

$ adb -s 4A181FDJH0030G shell cmd appops get com.wrait.flutter RECORD_AUDIO
Uid mode: RECORD_AUDIO: ignore

Manual Android phone follow-up after the microphone-permission fix:
- before tapping the main button, the installed app had
  `android.permission.RECORD_AUDIO: granted=false`
- after tapping `wrait`, Android granted foreground microphone access and
  `cmd appops get com.wrait.flutter RECORD_AUDIO` reported active allow usage
- the old `AudioRecord` initialization failure no longer reproduced through the
  normal start path
- the on-device UI advanced into recording/transcription flow instead of the
  generic `something went wrong` state

$ bash test/deploy_debug_script_test.sh
deploy_debug_script_test.sh: all tests passed

$ /opt/homebrew/bin/flutter test test/bootstrap_app_test.dart test/data/audio/audio_recording_service_test.dart test/data/transcription/cloud_transcription_service_test.dart test/presentation/main/main_recording_controller_test.dart test/data/entries/entry_database_test.dart
All tests passed! (60 tests)
LocalEntryDatabase reopen with 1000 entries took 20ms.

$ /opt/homebrew/bin/flutter analyze
No issues found! (ran in 2.5s)

$ /opt/homebrew/bin/flutter build apk --debug --dart-define=PROXY_SECRET=SECRET_WRAIT_VALUE
Built build/app/outputs/flutter-apk/app-debug.apk

$ adb -s 4A181FDJH0030G install -r build/app/outputs/flutter-apk/app-debug.apk
Performing Streamed Install
Success

$ adb -s 4A181FDJH0030G shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity
Status: ok
LaunchState: COLD
Activity: com.wrait.flutter/.MainActivity
TotalTime: 2133
```

## Validation scope notes

- Real-phone Android validation is complete and covers the in-scope US-028
  acceptance path.
- Android emulator validation has not been run yet for this story artifact.
- iOS simulator validation has not been run yet for this story artifact.
- Because spec/plan were skipped by explicit user direction, no pre-approved
  validation exception was recorded for those two remaining gates.

## Review status

- External `review.md` was provided at
  `specs/028-fix-device-registration-launch-integration-tests/review.md`.
- The approved remediation was implemented for:
  - deploy-script input/APK/device hardening
  - `MainActivity` platform-channel error handling
  - single-flight bootstrap retry handling
  - richer microphone permission-state handling
  - explicit stable main-screen test anchors
  - database-open timing instrumentation and seeded reopen measurement
- Remaining unaddressed review items are lower-priority follow-up work or
  broader scope decisions rather than blockers for this remediation pass.
