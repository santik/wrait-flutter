# Tasks: Microphone Permission Handling

> **Feature number:** 012
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-18

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Permission and Recording Contracts

Set up the service contracts needed for prompt/status/settings handling and
safe cancellation.

- [x] Extend microphone access operations for prompt, status check, and app
      settings launch — `lib/data/audio/microphone_permission_service.dart`
- [x] Add active-recording cancellation to the audio recording contract —
      `lib/data/audio/audio_recording_service.dart`
- [x] Implement recorder cancellation with active session clearing and partial
      file deletion — `lib/data/audio/record_audio_recording_service.dart`
  - Depends on: audio recording contract update
- [x] Add live-transcription cancellation and access-state carrying failures —
      `lib/data/transcription/transcription_service.dart`
- [x] Implement cloud live-transcription cancellation without upload/save and
      preserve microphone access state on start failure —
      `lib/data/transcription/cloud_transcription_service.dart`
  - Depends on: audio cancellation contract, transcription contract update

### Group 2: Controller Permission State

Map platform permission states into user-visible recording behavior.

- [x] Replace the broad insufficient-permissions error with retryable
      `microphoneDenied` and blocked `microphoneBlocked` recording errors —
      `lib/presentation/main/recording_state.dart`
  - Depends on: Group 1 failure-state contracts
- [x] Map retryable denial to non-blocked retry behavior in the main recording
      controller — `lib/presentation/main/main_recording_controller.dart`
  - Depends on: recording error split
- [x] Map permanently denied and restricted access to blocked-settings behavior
      in the main recording controller —
      `lib/presentation/main/main_recording_controller.dart`
  - Depends on: recording error split
- [x] Route blocked primary-button taps to app settings without starting
      recording — `lib/presentation/main/main_recording_controller.dart`
  - Depends on: microphone settings launch operation
- [x] Add foreground/resume permission refresh that clears blocked state after
      grant and preserves blocked state while still blocked —
      `lib/presentation/main/main_recording_controller.dart`
  - Depends on: microphone status check operation
- [x] Cancel active recording on foreground/resume when microphone access is no
      longer granted, then publish a permission error —
      `lib/presentation/main/main_recording_controller.dart`
  - Depends on: transcription cancellation contract
- [x] Log settings-launch failures without crashing or clearing the blocked
      affordance — `lib/presentation/main/main_recording_controller.dart`

### Group 3: Main Screen UX

Wire controller states into the existing main-screen presentation.

- [x] Add blocked-settings status action and `mic blocked · tap settings`
      status text — `lib/presentation/main/main_screen_status.dart`
- [x] Add retryable microphone-denied status text without settings action —
      `lib/presentation/main/main_screen_status.dart`
- [x] Route blocked status-line taps to the controller settings action —
      `lib/presentation/main/main_screen.dart`
  - Depends on: blocked-settings status action
- [x] Observe app lifecycle resume and notify the controller to refresh
      microphone permission state — `lib/presentation/main/main_screen.dart`
  - Depends on: controller foreground/resume handler
- [x] Preserve existing saved, deleted, quota, stats, countdown, and
      non-permission error behavior while adding the permission states —
      `lib/presentation/main/main_screen.dart`,
      `lib/presentation/main/main_screen_status.dart`

### Group 4: Lower-Level Automated Tests

Cover service and controller behavior before broad widget/integration checks.

- [x] Update audio recording service fakes and cover retryable denied,
      permanently denied, restricted, and cancel behavior —
      `test/data/audio/audio_recording_service_test.dart`
- [x] Update cloud transcription service fakes and cover permission-state
      propagation plus cancel-without-upload —
      `test/data/transcription/cloud_transcription_service_test.dart`
- [x] Update main recording controller fakes for expanded service contracts —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] Cover retryable denied, blocked, restricted, blocked primary-button
      settings launch, settings-launch failure logging, resume recovery, and
      revocation cancellation —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] Cover blocked and retryable permission status presentations —
      `test/presentation/main/main_screen_status_test.dart`
- [x] Cover blocked status text, settings tap wiring, blocked primary-button
      behavior where widget-level accessible, and lifecycle observer calls —
      `test/presentation/main/main_screen_test.dart`

### Group 5: Integration Tests

Cover every in-scope user flow with provider-level integration tests and keep
existing integration flows current.

- [x] Create a main-screen permission-flow integration harness with fakes for
      permission status, settings launch, transcription start/stop/cancel, and
      stored entries — `integration_test/main_screen_permission_flow_test.dart`
- [x] Cover first recording tap requesting permission and retryable denial
      remaining retryable —
      `integration_test/main_screen_permission_flow_test.dart`
- [x] Cover blocked status line and primary button both opening settings —
      `integration_test/main_screen_permission_flow_test.dart`
- [x] Cover granting permission from settings and resuming clearing blocked
      status — `integration_test/main_screen_permission_flow_test.dart`
- [x] Cover permission revocation during active recording canceling capture
      without upload/save success —
      `integration_test/main_screen_permission_flow_test.dart`
- [x] Update existing fake audio/transcription services for the expanded
      contracts — `integration_test/audio_recording_service_flow_test.dart`,
      `integration_test/main_recording_controller_flow_test.dart`,
      `integration_test/main_screen_flow_test.dart`
- [x] Update existing microphone-blocked expectations to
      `mic blocked · tap settings` — `integration_test/main_screen_flow_test.dart`

### Group 6: Static Validation and Runtime Verification

Run planned automated checks and verify the feature on the required devices.

- [x] Run focused unit/widget tests for audio, transcription, controller, and
      main-screen status/UI permission behavior
- [x] Run focused `integration_test` coverage for US-012 permission flows
- [x] Run broader project validation needed by the changed contracts, including
      existing main-screen and recording integration flows
- [x] Run `flutter analyze` or the project-equivalent static analysis command
- [x] Verify Android emulator behavior from the plan, including cold launch,
      prompt, retryable denial, blocked settings, settings recovery, and
      active-recording revocation
- [x] Verify real Android device behavior from the plan, preserving
      `com.wrait.app`, targeting `com.wrait.flutter`, and using
      `./deploy_debug.sh` with `PROXY_SECRET` when backend-backed recording
      validation is part of the run
- [x] Verify iOS simulator behavior from the plan, including prompt, blocked
      settings recovery, and active-recording revocation

### Group 7: Review and Fix

Handle the external review gate after implementation.

- [x] Create `implementation.md` with implementation notes, validation
      commands, Android emulator evidence, real Android device evidence, and
      iOS simulator evidence —
      `specs/012-microphone-permission-handling/implementation.md`
- [x] Stop and wait for external `review.md`, unless the user explicitly skips
      review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any
      changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 8: Finalization

Handle durable documentation follow-up and closeout.

- [ ] Decide whether the feature produced durable learnings or long-lived
      product/architecture changes worth preserving
- [ ] If needed, propose updates to `AGENTS.md`,
      `docs/application-description.md`, and `docs/agent-findings.md`
- [ ] Wait for explicit approval before editing those long-lived guidance
      documents
- [ ] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

_Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete._

```text
- Focused unit/widget suite passed:
  /opt/homebrew/bin/flutter test test/data/audio/audio_recording_service_test.dart test/data/transcription/cloud_transcription_service_test.dart test/presentation/main/main_recording_controller_test.dart test/presentation/main/main_screen_status_test.dart test/presentation/main/main_screen_test.dart
- Focused permission integration suite passed on Android phone, Android emulator, and iOS simulator:
  /opt/homebrew/bin/flutter test -d 4A181FDJH0030G integration_test/main_screen_permission_flow_test.dart
  /opt/homebrew/bin/flutter test -d emulator-5554 integration_test/main_screen_permission_flow_test.dart
  /opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_permission_flow_test.dart
- Existing recording/transcription integration suites passed on Android phone:
  /opt/homebrew/bin/flutter test -d 4A181FDJH0030G integration_test/main_recording_controller_flow_test.dart integration_test/cloud_transcription_service_flow_test.dart
- Existing main-screen integration suite passed on Android phone and Android emulator:
  /opt/homebrew/bin/flutter test -d 4A181FDJH0030G integration_test/main_screen_flow_test.dart
  /opt/homebrew/bin/flutter test -d emulator-5554 integration_test/main_screen_flow_test.dart
- Static analysis passed:
  /opt/homebrew/bin/flutter analyze
- Review remediation validation passed:
  /opt/homebrew/bin/flutter test --no-pub test/data/audio/microphone_permission_service_test.dart
  /opt/homebrew/bin/flutter test --no-pub test/presentation/main/main_recording_controller_test.dart
  /opt/homebrew/bin/flutter test --no-pub test/data/transcription/cloud_transcription_service_test.dart
  /opt/homebrew/bin/flutter test --no-pub test/presentation/main/main_screen_status_test.dart
  /opt/homebrew/bin/flutter test --no-pub test/presentation/main/main_screen_test.dart
  /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_permission_flow_test.dart
  /opt/homebrew/bin/flutter test --no-pub -d 4A181FDJH0030G integration_test/main_screen_permission_flow_test.dart
- Real Android runtime verification completed with adb-driven launch, permission-state changes, screenshots, and task inspection for:
  first prompt, blocked status, settings routing from status line and main button, and blocked-state recovery after granting permission.
- Locked-screen real-device hang in main_screen_flow_test.dart was fixed by removing screenshot capture from that behavioral suite; the suite now passes on the physical phone.
- Review remediation added explicit coverage for iOS denied-after-prompt mapping, serialized/timed resume refresh, cancel-failure recovery, blocked/retryable semantics, and the restricted settings path.
```

## Notes

- Analytics and offline-mode speech-recognition permission prompting are out of
  scope for US-012.
- The planned runtime validation includes Android emulator, real Android
  device, and iOS simulator verification.
