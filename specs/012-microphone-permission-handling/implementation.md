# Implementation: Microphone Permission Handling

> **Feature number:** 012
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-19

---

## Summary

US-012 now distinguishes retryable microphone denial from blocked microphone
access throughout the recording stack, opens system settings for blocked
states from both the status line and the main button, refreshes permission
state on foreground resume, and cancels active recording safely when
microphone access disappears mid-session.

The implementation stayed within the existing recording architecture:

- extended the existing microphone permission service instead of adding a new
  platform abstraction
- threaded resolved microphone access state through audio and transcription
  failures so the controller can render the correct UX
- added explicit cancel paths to recording/transcription services so revoked
  permission does not upload or save unusable audio
- kept startup non-blocking by observing lifecycle resume from `MainScreen`
  instead of moving permission work into bootstrap

## Review remediation

After the external `review.md` pass, the implementation was tightened in five
review-approved areas:

- `lib/data/audio/microphone_permission_service.dart`
  - added a small permission-client seam for targeted tests
  - kept pre-prompt iOS `denied` retryable
  - mapped iOS `denied` to blocked after a prompt attempt in the current app
    session so the UI does not offer a fake retry loop
- `lib/presentation/main/main_recording_controller.dart`
  - serialized `onAppResumed()` permission refreshes
  - added a bounded timeout and warning log for hung resume permission checks
- `lib/data/transcription/cloud_transcription_service.dart`
  - made no-op cancel a true no-op
  - logged cancel failures explicitly
  - preserved service state based on whether the recorder still reports an
    active session after a failed cancel attempt
- `lib/presentation/main/main_screen_status.dart`
  - added permission-specific screen-reader labels and hints for retryable and
    blocked permission states
- `lib/presentation/main/main_screen.dart`
  - applied those semantics through the tappable status-line UI

## Implemented changes

### Data and service layer

- `lib/data/audio/microphone_permission_service.dart`
  - added prompt, status-check, and settings-opening operations
- `lib/data/audio/audio_recording_service.dart`
  - added active recording cancellation
- `lib/data/audio/record_audio_recording_service.dart`
  - requests permission before recording
  - cancels recorder sessions and deletes partial files on cancel
- `lib/data/transcription/transcription_service.dart`
  - added cancellation for active live transcription
  - preserved microphone access state in start failures
- `lib/data/transcription/cloud_transcription_service.dart`
  - maps audio permission failures into access-aware transcription failures
  - cancels live recording without upload/save on permission loss

### Presentation and controller layer

- `lib/presentation/main/recording_state.dart`
  - replaced broad permission error with:
    - `RecordingError.microphoneDenied`
    - `RecordingError.microphoneBlocked`
- `lib/presentation/main/main_recording_controller.dart`
  - maps `denied` to retryable UX
  - maps `permanentlyDenied` and `restricted` to blocked-settings UX
  - opens settings from blocked main-button taps
  - re-checks permission on app resume
  - clears blocked state after grant
  - cancels active recording and emits permission error after revocation
- `lib/presentation/main/main_screen_status.dart`
  - added `openMicrophoneSettings` action
  - added:
    - `mic needed · tap again`
    - `mic blocked · tap settings`
- `lib/presentation/main/main_screen.dart`
  - observes app resume via `WidgetsBindingObserver`
  - routes blocked status taps to controller settings opening

### Tests

- updated unit/widget suites for the new contracts and UI states
- added `integration_test/main_screen_permission_flow_test.dart`
  - provider-graph permission flow coverage for retryable denial, blocked
    settings routing, settings recovery, and mid-recording revocation
- updated existing integration fakes and expectations for the expanded
  recording/transcription contracts

## Validation

### Focused unit and widget tests

Passed:

```text
/opt/homebrew/bin/flutter test \
  test/data/audio/audio_recording_service_test.dart \
  test/data/transcription/cloud_transcription_service_test.dart \
  test/presentation/main/main_recording_controller_test.dart \
  test/presentation/main/main_screen_status_test.dart \
  test/presentation/main/main_screen_test.dart
```

Review remediation additions passed:

```text
/opt/homebrew/bin/flutter test --no-pub test/data/audio/microphone_permission_service_test.dart
/opt/homebrew/bin/flutter test --no-pub test/presentation/main/main_recording_controller_test.dart
/opt/homebrew/bin/flutter test --no-pub test/data/transcription/cloud_transcription_service_test.dart
/opt/homebrew/bin/flutter test --no-pub test/presentation/main/main_screen_status_test.dart
/opt/homebrew/bin/flutter test --no-pub test/presentation/main/main_screen_test.dart
```

### Focused permission integration coverage

Passed on all planned target classes:

```text
/opt/homebrew/bin/flutter test -d 4A181FDJH0030G integration_test/main_screen_permission_flow_test.dart
/opt/homebrew/bin/flutter test -d emulator-5554 integration_test/main_screen_permission_flow_test.dart
/opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_permission_flow_test.dart
```

Review remediation reruns passed on the iOS simulator and the real Android
phone:

```text
/opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_permission_flow_test.dart
/opt/homebrew/bin/flutter test --no-pub -d 4A181FDJH0030G integration_test/main_screen_permission_flow_test.dart
```

### Broader changed-contract integration coverage

Passed on Android phone:

```text
/opt/homebrew/bin/flutter test -d 4A181FDJH0030G \
  integration_test/main_screen_flow_test.dart \
  integration_test/main_recording_controller_flow_test.dart \
  integration_test/cloud_transcription_service_flow_test.dart
```

Passed on Android emulator:

```text
/opt/homebrew/bin/flutter test -d emulator-5554 integration_test/main_screen_flow_test.dart
```

Focused note:

- `integration_test/main_screen_flow_test.dart` originally hung on the locked
  physical phone because it mixed behavioral assertions with
  `convertFlutterSurfaceToImage()` and `takeScreenshot(...)`.
- The fix was to remove screenshot capture from that behavioral suite while
  preserving all test assertions.
- After the change, the same suite passed on the real Android phone and the
  Android emulator.

Passed on Android phone for the remaining changed-contract suites:

```text
/opt/homebrew/bin/flutter test -d 4A181FDJH0030G \
  integration_test/main_recording_controller_flow_test.dart \
  integration_test/cloud_transcription_service_flow_test.dart
```

### Static analysis

Passed:

```text
/opt/homebrew/bin/flutter analyze
```

Review remediation recheck also passed:

```text
/opt/homebrew/bin/flutter analyze
```

## Runtime verification

### Android emulator

Validated by running the focused permission integration suite on
`emulator-5554`, which passed all four US-012 permission flows.

### Real Android device

Validated on physical Android phone `4A181FDJH0030G` targeting package
`com.wrait.flutter`.

Observed with adb-driven launch, permission state changes, screenshots, and
task inspection:

1. Cold launch succeeded with:
   `adb -s 4A181FDJH0030G shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity`
2. First recording tap surfaced the Android microphone prompt.
3. Blocked permission state produced visible
   `mic blocked · tap settings`.
4. Tapping the blocked status line opened Android settings for Wrait.
5. Tapping the blocked main button also opened Android settings for Wrait.
6. Granting microphone permission and bringing Wrait back to the foreground
   cleared the blocked state back to idle copy.
7. Starting recording with permission granted reached visible
   `listening...` on device.
8. The locked-screen real-device behavioral suite
   `integration_test/main_screen_flow_test.dart` passed after removing its
   screenshot capture path.

Additional notes:

- `com.wrait.app` remained installed.
- Validation used `com.wrait.flutter` as the Flutter Android target.
- Because backend-backed upload was not required for the permission-specific
  runtime checks, `deploy_debug.sh` was not necessary for this pass and
  `PROXY_SECRET` was not required.

### iOS simulator

Validated by running the focused permission integration suite on simulator
`491CD949-D3C0-4C4C-A6B9-15BAB1859156`, then rerunning it after the review
fixes. The suite passed all five US-012 permission flows, including the
explicit `restricted` path.

## Files changed

- `lib/data/audio/audio_recording_service.dart`
- `lib/data/audio/microphone_permission_service.dart`
- `lib/data/audio/record_audio_recording_service.dart`
- `lib/data/transcription/cloud_transcription_service.dart`
- `lib/data/transcription/transcription_service.dart`
- `lib/presentation/main/main_recording_controller.dart`
- `lib/presentation/main/main_screen.dart`
- `lib/presentation/main/main_screen_status.dart`
- `lib/presentation/main/recording_state.dart`
- `test/data/audio/audio_recording_service_test.dart`
- `test/data/audio/microphone_permission_service_test.dart`
- `test/data/transcription/cloud_transcription_service_test.dart`
- `test/presentation/main/main_recording_controller_test.dart`
- `test/presentation/main/main_screen_status_test.dart`
- `test/presentation/main/main_screen_test.dart`
- `integration_test/cloud_transcription_service_flow_test.dart`
- `integration_test/entry_detail_flow_test.dart`
- `integration_test/main_recording_controller_flow_test.dart`
- `integration_test/main_screen_flow_test.dart`
- `integration_test/main_screen_permission_flow_test.dart`
- `specs/012-microphone-permission-handling/plan.md`
- `specs/012-microphone-permission-handling/implementation.md`
- `specs/012-microphone-permission-handling/tasks.md`

## Review gate

Implementation is complete for the current approved scope.

Per the spec-driven workflow, the next step is to wait for an externally
provided `review.md` before making any further changes, unless the user
explicitly skips review.
