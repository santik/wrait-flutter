# Tasks: Fix Device Registration Launch Integration Tests

> **Feature number:** 028
> **Story:** [`../../plan/us_028.md`](../../plan/us_028.md)
> **Spec:** Skipped by explicit user direction on 2026-06-16.
> **Plan:** Skipped by explicit user direction on 2026-06-16.
> **Author:** Codex
> **Date:** 2026-06-16

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Failure Characterization

Confirm exactly what fails on the physical Android launch-registration path
before changing assertions.

- [x] Review the current launch-registration integration tests and preserve
      their behavioral intent —
      `integration_test/device_registration_launch_flow_test.dart`
- [x] Inspect the launch work/provider wiring and current root-screen
      rendering expectations before deciding whether this is test-only or
      production behavior —
      `lib/main.dart`, `lib/app.dart`, `lib/data/api/backend_providers.dart`,
      `lib/presentation/main/main_screen.dart`
- [x] Re-run or inspect the focused failing integration test on the connected
      Android phone to capture the real failure message, failing finder, timing,
      request count, and quota state at failure time —
      `integration_test/device_registration_launch_flow_test.dart`
- [x] Confirm the old native `com.wrait.app` package is present or absent before
      deploy validation so post-fix coexistence can be checked accurately

### Group 2: Focused Test/Flow Fix

Update only the failing launch-registration coverage unless Group 1 proves the
production launch flow is wrong.

- [x] Replace stale root-screen text expectations with stable current UI
      expectations, preferring keys or semantics that verify the main launch UI
      is visible without depending on obsolete copy —
      `integration_test/device_registration_launch_flow_test.dart`
- [x] Make asynchronous registration synchronization deterministic for the
      success case so the test proves launch remains non-blocking before the
      backend response is released —
      `integration_test/device_registration_launch_flow_test.dart`
- [x] Make transient-failure synchronization deterministic so the test waits for
      the intended retry/failure behavior instead of relying on fragile fixed
      sleeps —
      `integration_test/device_registration_launch_flow_test.dart`
- [x] Preserve strong assertions that successful registration writes a hashed
      stored device ID, sends that same device ID to the backend, and updates
      `sessionRecordQuotaStateProvider` with the returned quota —
      `integration_test/device_registration_launch_flow_test.dart`
- [x] Preserve strong assertions that transient registration failure does not
      block launch and does not clear or replace the existing in-memory quota —
      `integration_test/device_registration_launch_flow_test.dart`
- [x] Preserve stored-device-ID reuse coverage across launches, adjusting only
      synchronization if needed —
      `integration_test/device_registration_launch_flow_test.dart`
- [x] If investigation proves production launch behavior is wrong, make the
      smallest production fix needed while preserving `startAppLaunchWork` as
      non-blocking —
      `lib/main.dart`, `lib/data/api/backend_providers.dart`,
      `lib/domain/usecase/register_device_on_launch_use_case.dart`
      Note: production startup now renders through a bootstrap gate and the
      encrypted database open path no longer uses the stalled background-open
      variant on the real Android phone.

### Group 3: Local Automated Validation

Run focused checks before the full deploy path.

- [x] Run Dart formatting for modified Dart files —
      `/opt/homebrew/bin/flutter format` or `dart format`
- [x] Run Flutter static analysis —
      `/opt/homebrew/bin/flutter analyze`
- [x] Run the existing Flutter test suite —
      `/opt/homebrew/bin/flutter test`
- [x] Run the focused launch-registration integration test on the connected
      Android phone —
      `/opt/homebrew/bin/flutter test --no-pub -d <phone-serial> integration_test/device_registration_launch_flow_test.dart`

### Group 4: Deploy Path Validation

Validate through the exact real-device path from US-027.

- [x] Confirm exactly one authorized physical Android phone is available and
      emulator entries are ignored as expected —
      `adb devices`
- [x] Run `./deploy_debug.sh` and confirm it completes the real-device
      integration-test phase without the two US-028 failures
- [x] Confirm `./deploy_debug.sh` installs `com.wrait.flutter` only after the
      integration tests pass
- [x] Confirm the old native `com.wrait.app` installation remains untouched
      after deploy validation when it was present before validation
- [x] Launch `com.wrait.flutter` on the Android phone and confirm the app opens

### Group 5: Validation Scope Decisions

Handle validation expectations that were not covered by the skipped plan phase.

- [x] Record Android real-phone validation evidence because it is the in-scope
      acceptance path for US-028
- [ ] Run Android emulator validation if required for final approval, or record
      an explicit user-approved exception because US-028 targets a real-phone
      deploy integration failure
- [ ] Run iOS simulator validation if required for final approval, or record an
      explicit user-approved exception because US-028 targets Android-only
      integration-test/deploy behavior

### Group 6: Implementation Record

Capture what changed and what evidence proves the fix.

- [x] Create `implementation.md` with the failure cause, changed assertions or
      production fix, validation evidence, package-coexistence evidence, and any
      approved validation exceptions —
      `specs/028-fix-device-registration-launch-integration-tests/implementation.md`
- [x] Update this task list with completed statuses and validation evidence —
      `specs/028-fix-device-registration-launch-integration-tests/tasks.md`

### Group 7: Review and Fix

Handle external review after implementation unless the user explicitly skips
review for US-028.

- [x] Stop and wait for external `review.md`, unless the user explicitly skips
      review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any
      changes
- [x] Implement approved review fixes and update `tasks.md`,
      `implementation.md`, code, and tests when review changes scope,
      approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 8: Finalization

Handle durable documentation follow-up and closeout.

- [ ] Decide whether the fix produced durable learnings or long-lived
      product/architecture changes worth preserving
- [ ] Propose any needed updates to `AGENTS.md`,
      `docs/application-description.md`, and `docs/agent-findings.md`
- [ ] Wait for explicit approval before editing those long-lived guidance
      documents
- [ ] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision

## Completion criteria

All tasks checked, validation evidence documented, `./deploy_debug.sh`
completed through the real-device integration-test phase and final install,
the native `com.wrait.app` package remained untouched during validation, review
handled or explicitly skipped, and final knowledge-capture gate handled.

## Validation evidence

Record test results, command output, Android phone verification, approved
exceptions, or review-related notes here when complete.

```text
$ dart format integration_test/device_registration_launch_flow_test.dart
Formatted 1 file (0 changed) in 0.01 seconds.

$ /opt/homebrew/bin/flutter analyze
No issues found! (ran in 2.8s)
Note: the first sandboxed attempt failed while touching ios/Flutter/ephemeral;
the successful result came from an unrestricted rerun.

$ /opt/homebrew/bin/flutter test
All tests passed! (192 tests)

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
04:03 +28: integration_test/device_registration_launch_flow_test.dart: (tearDownAll)
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

$ /opt/homebrew/bin/flutter test
All tests passed! (195 tests)

$ /opt/homebrew/bin/flutter build apk --debug

$ bash test/deploy_debug_script_test.sh
deploy_debug_script_test.sh: all tests passed

$ PROXY_SECRET=SECRET_WRAIT_VALUE ./deploy_debug.sh
Building Flutter debug APK...
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Running Flutter integration tests on 4A181FDJH0030G...
...
Installed com.wrait.flutter on 4A181FDJH0030G.
Note: the integration runner later stalled during `entry_list_flow_test.dart`
while the final installed app remained on-device. Manual follow-up logs from
the installed build showed Android `keystore2` `KEY_USER_NOT_AUTHENTICATED`
errors during launch, so the remaining black-screen verification appears tied
to device-auth state rather than the old missing `X-Proxy-Secret` header.
Built build/app/outputs/flutter-apk/app-debug.apk

$ adb -s 4A181FDJH0030G install -r build/app/outputs/flutter-apk/app-debug.apk
Performing Streamed Install
Success

$ adb -s 4A181FDJH0030G shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity
Status: ok
Activity: com.wrait.flutter/.MainActivity

Manual Android phone verification:
- Device was awake and unlocked
- `com.wrait.flutter` was foregrounded
- Main screen rendered with the `wrait` action button,
  `tap button to write`, and `0 entries - 0 days`

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

Manual Android phone verification after the microphone-permission fix:
- With `RECORD_AUDIO` revoked, tapping the main `wrait` button no longer fell
  into the old generic error path
- The app requested/obtained microphone access on device and the permission
  state flipped to granted
- `cmd appops get com.wrait.flutter RECORD_AUDIO` then reported foreground
  allow activity for the recording session
- The app advanced into active recording/transcription UI instead of
  `something went wrong`

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

$ adb -s 4A181FDJH0030G shell dumpsys package com.wrait.flutter
...
requested permissions:
  android.permission.RECORD_AUDIO
...
runtime permissions:
  android.permission.RECORD_AUDIO: granted=true, flags=[ USER_SET|USER_SENSITIVE_WHEN_GRANTED|USER_SENSITIVE_WHEN_DENIED]
```

## Notes

- Root cause: the launch integration tests still looked for the removed
  `Capture` copy and used passive waits that were brittle on the physical
  Android device path.
- Follow-up runtime finding: the deployed app also needed a real startup
  bootstrap fix because blocking dependency initialization before `runApp`
  kept the first frame hidden, and the encrypted database background-open path
  appeared to stall on the real Android install.
- The production launch path should stay non-blocking: `startAppLaunchWork`
  intentionally starts registration without awaiting it.
- Do not weaken the quota, stored-device-ID, request-count, or native package
  coexistence assertions into false positives.
