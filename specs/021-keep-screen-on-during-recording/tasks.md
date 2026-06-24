# Tasks: Keep Screen On During Recording

> **Feature number:** 021
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-23

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Display-Awake Service Contract

Create the injectable display-awake boundary before wiring it to recording UI.

- [x] [P] Define `DisplayAwakeService`, a warning logger provider, and a
      production `WakelockDisplayAwakeService` backed by `wakelock_plus` —
      `lib/data/display/display_awake_service.dart`
- [x] [P] Add a small injectable wakelock client seam if needed so unit tests
      can verify `WakelockPlus.toggle(enable: ...)` delegation without static
      plugin calls — `lib/data/display/display_awake_service.dart`
- [x] [P] Add unit coverage that the production display-awake service enables
      and disables through the wakelock boundary —
      `test/data/display/display_awake_service_test.dart`
- [x] [P] Add unit coverage that display-awake service failures are logged and
      do not propagate as user-visible recording errors —
      `test/data/display/display_awake_service_test.dart`

### Group 2: Coordinator State Logic

Implement the idempotent desired-state computation independently of
`MainScreen` rendering.

- [x] Create `RecordingDisplayAwakeCoordinator` with inputs for
      `RecordingState`, `AppLifecycleState`, `AppLockState`, and disposal —
      `lib/presentation/main/recording_display_awake_coordinator.dart`
  - Depends on: Group 1
- [x] Implement desired keep-awake state as true only for
      `RecordingListening` while lifecycle is `resumed` and app-lock is not
      locked — `lib/presentation/main/recording_display_awake_coordinator.dart`
  - Depends on: coordinator creation
- [x] Implement idempotent service calls so repeated active or inactive updates
      do not call the display service redundantly —
      `lib/presentation/main/recording_display_awake_coordinator.dart`
  - Depends on: desired-state computation
- [x] Implement release-on-dispose behavior that clears keep-awake only when it
      had been requested, and is safe to call repeatedly —
      `lib/presentation/main/recording_display_awake_coordinator.dart`
  - Depends on: idempotent service calls
- [x] Add unit coverage for enabling while resumed/unlocked/listening —
      `test/presentation/main/recording_display_awake_coordinator_test.dart`
  - Depends on: coordinator behavior
- [x] Add unit coverage for release on upload, processing, idle, saved, error,
      deleted, and canceled-equivalent transitions —
      `test/presentation/main/recording_display_awake_coordinator_test.dart`
  - Depends on: coordinator behavior
- [x] Add unit coverage for lifecycle release and resume recomputation —
      `test/presentation/main/recording_display_awake_coordinator_test.dart`
  - Depends on: coordinator behavior
- [x] Add unit coverage for app-lock release and unlock recomputation —
      `test/presentation/main/recording_display_awake_coordinator_test.dart`
  - Depends on: coordinator behavior
- [x] Add unit coverage for duplicate active/inactive transition idempotency and
      disposal cleanup —
      `test/presentation/main/recording_display_awake_coordinator_test.dart`
  - Depends on: coordinator behavior

### Group 3: Main Screen Integration

Wire the coordinator into the real foreground recording surface while
preserving existing timer and permission-resume behavior.

- [x] Instantiate and dispose the recording display-awake coordinator from
      `_MainScreenState` — `lib/presentation/main/main_screen.dart`
  - Depends on: Group 2
- [x] Feed initial and subsequent `mainRecordingControllerProvider` recording
      states into the coordinator from the existing controller listener —
      `lib/presentation/main/main_screen.dart`
  - Depends on: coordinator instantiation
- [x] Feed lifecycle changes into the coordinator, releasing keep-awake on
      non-`resumed` states and recomputing on `resumed`, while preserving the
      existing microphone-permission resume check —
      `lib/presentation/main/main_screen.dart`
  - Depends on: coordinator instantiation
- [x] Watch `appLockControllerProvider` and feed lock/unlock state changes into
      the coordinator so app-lock releases keep-awake —
      `lib/presentation/main/main_screen.dart`
  - Depends on: coordinator instantiation
- [x] Add widget coverage that `MainScreen` enables keep-awake when its
      controller enters `RecordingListening` and keeps the countdown behavior
      intact — `test/presentation/main/main_screen_test.dart`
  - Depends on: main-screen wiring
- [x] Add widget coverage that `MainScreen` releases keep-awake on uploading,
      processing, saved/error/deleted, lifecycle exit, and disposal —
      `test/presentation/main/main_screen_test.dart`
  - Depends on: main-screen wiring
- [x] Add widget coverage that app-lock activation releases keep-awake without
      breaking the existing app-lock overlay behavior —
      `test/presentation/main/main_screen_test.dart`
  - Depends on: main-screen wiring
- [x] Confirm existing main-screen resume tests still verify microphone
      permission refresh behavior and are not weakened by keep-awake wiring —
      `test/presentation/main/main_screen_test.dart`
  - Depends on: main-screen wiring

### Group 4: Integration Coverage

Add main-screen integration coverage for the in-scope recording user flow with a
fake display-awake service.

- [x] Create a main-screen display-awake integration harness with fake
      recording/app-lock state and a fake display-awake service —
      `integration_test/main_screen_display_awake_flow_test.dart`
  - Depends on: Groups 1-3
- [x] Add integration coverage that main-screen recording state requests
      keep-awake during listening and releases when upload, processing, and
      saved states begin —
      `integration_test/main_screen_display_awake_flow_test.dart`
  - Depends on: fake display-awake harness
- [x] Add integration coverage that main-screen error flow requests keep-awake
      during listening and releases when upload or error begins —
      `integration_test/main_screen_display_awake_flow_test.dart`
  - Depends on: fake display-awake harness
- [x] Add integration coverage that lifecycle backgrounding and app-lock
      activation release keep-awake while listening —
      `integration_test/main_screen_display_awake_flow_test.dart`
  - Depends on: fake display-awake harness
- [x] Record the approved validation exception that OS idle dim/lock behavior is
      verified with runtime evidence rather than direct `integration_test`
      pixel/idle-lock assertions —
      `specs/021-keep-screen-on-during-recording/tasks.md`
  - Depends on: integration coverage tasks

### Group 5: Automated Validation

Run focused and adjacent checks, recording evidence as implementation proceeds.

- [x] Run display-awake service unit tests —
      `/opt/homebrew/bin/flutter test test/data/display/display_awake_service_test.dart`
  - Depends on: Group 1
- [x] Run coordinator unit tests —
      `/opt/homebrew/bin/flutter test test/presentation/main/recording_display_awake_coordinator_test.dart`
  - Depends on: Group 2
- [x] Run main-screen widget tests —
      `/opt/homebrew/bin/flutter test test/presentation/main/main_screen_test.dart`
  - Depends on: Group 3
- [x] Run the focused combined test command from the plan:
      `/opt/homebrew/bin/flutter test test/data/display/display_awake_service_test.dart test/presentation/main/recording_display_awake_coordinator_test.dart test/presentation/main/main_screen_test.dart`
  - Depends on: Groups 1-3
- [x] Run main-screen display-awake integration coverage on the host or default
      test target:
      `/opt/homebrew/bin/flutter test integration_test/main_screen_display_awake_flow_test.dart`
  - Depends on: Group 4
- [x] Run static analysis — `/opt/homebrew/bin/flutter analyze`
  - Depends on: Groups 1-4
- [x] If generated backend API output is missing, run `npm run build` before
      Flutter tests and record that prerequisite in validation evidence.

### Group 6: Runtime Platform Verification

Collect Android emulator and iOS simulator evidence, applying the approved
idle-lock validation exception only where OS behavior cannot be asserted by
Flutter tests.

- [x] Verify the updated main-screen display-awake integration test on an
      Android emulator:
      `/opt/homebrew/bin/flutter test -d <android-emulator-id> integration_test/main_screen_display_awake_flow_test.dart`
  - Depends on: Group 5
- [x] Launch Wrait on the Android emulator with the debug/profile package
      identity and verify normal foreground usability —
      Android emulator runtime evidence
  - Depends on: Android integration verification
- [x] Temporarily set a short Android emulator screen timeout where practical,
      start recording, and verify the timer/stop control remain visible beyond
      ordinary timeout behavior — Android emulator runtime evidence
  - Depends on: Android launch verification
- [x] Stop recording and verify Wrait transitions away from listening and no
      longer intentionally holds keep-awake during upload/processing/saved or
      error — Android emulator runtime evidence
  - Depends on: Android recording verification
- [x] Background Wrait or trigger app-lock while listening and verify
      keep-awake is released from the app's state contract —
      Android emulator runtime evidence
  - Depends on: Android recording verification
- [x] Restore any Android emulator timeout setting changed during validation and
      record the final setting in validation evidence.
- [x] Verify the updated main-screen display-awake integration test on an iOS
      simulator:
      `/opt/homebrew/bin/flutter test -d <ios-simulator-id> integration_test/main_screen_display_awake_flow_test.dart`
  - Depends on: Group 5
- [x] Launch Wrait on the iOS simulator and verify normal foreground usability —
      iOS simulator runtime evidence
  - Depends on: iOS integration verification
- [x] Start recording on the iOS simulator and verify the timer/stop control
      remain visible while the app contract reports keep-awake active, noting
      any simulator idle-lock limitations — iOS simulator runtime evidence
  - Depends on: iOS launch verification
- [x] Stop recording and verify Wrait transitions away from listening and no
      longer intentionally holds keep-awake during upload/processing —
      iOS simulator runtime evidence
  - Depends on: iOS recording verification
- [x] Background Wrait or trigger app-lock while listening and verify
      keep-awake is released from the app's state contract —
      iOS simulator runtime evidence
  - Depends on: iOS recording verification
- [x] Record the approved validation exception: OS-level idle dim/lock behavior
      may be documented through runtime observation and app contract evidence
      when emulator/simulator APIs cannot prove the absent-wakelock baseline.

### Group 7: Implementation Evidence

Capture what changed and prepare the feature for external review.

- [x] Update task statuses as implementation progresses —
      `specs/021-keep-screen-on-during-recording/tasks.md`
- [x] Record automated test commands, runtime evidence, and approved validation
      exception notes in the validation evidence section —
      `specs/021-keep-screen-on-during-recording/tasks.md`
- [x] Confirm `spec.md` and `plan.md` still match implemented behavior —
      `specs/021-keep-screen-on-during-recording/spec.md`,
      `specs/021-keep-screen-on-during-recording/plan.md`
- [x] Create `implementation.md` with implementation summary, changed files,
      validation commands, runtime evidence, simulator limitations, and
      approved deviations —
      `specs/021-keep-screen-on-during-recording/implementation.md`
- [x] Stop and wait for external `review.md`, unless the user explicitly skips
      review — `specs/021-keep-screen-on-during-recording/review.md`

### Group 8: Review And Fix

Handle the external review loop without changing files before approval.

- [x] Read externally provided `review.md` when available —
      `specs/021-keep-screen-on-during-recording/review.md`
- [x] Prepare a remediation plan for each review finding without updating files
      — `specs/021-keep-screen-on-during-recording/review.md`
- [x] Present the remediation plan and wait for explicit approval before making
      any changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [x] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 9: Finalization

Close the feature only after durable documentation follow-up is handled.

- [ ] Decide whether US-021 produced durable learnings or long-lived
      product/architecture changes worth preserving
- [ ] Propose updates to `AGENTS.md`, `docs/application-description.md`, and
      `docs/agent-findings.md` if foreground-recording keep-awake behavior or
      emulator/simulator validation guidance should become long-lived guidance
- [ ] Wait for explicit approval before editing those long-lived guidance
      documents
- [ ] Apply approved long-lived documentation updates, or record the explicit
      no-update decision
- [ ] Mark `spec.md` status `Complete` only after implementation, validation,
      review handling, and final knowledge-capture gates are done

## Completion criteria

All tasks checked, validation evidence documented, approved OS idle-lock
validation exception recorded, Android emulator and iOS simulator verification
completed or explicitly documented under the approved exception, review handled
or explicitly skipped, final knowledge-capture gate handled, and `spec.md`
marked `Complete`.

## Validation evidence

Record test results, runtime observations, command output, approved exceptions,
or review-related notes here when complete.

```text
Approved validation exception:
- User approved the plan on 2026-06-23, including the exception that Flutter
  integration tests verify the app's display-awake contract through an injected
  fake service, while OS-level idle dim/lock behavior is validated with
  Android emulator and iOS simulator runtime evidence where practical.
- If emulator/simulator APIs cannot prove the absent-wakelock baseline, final
  validation may document that limitation while retaining automated
  state-contract coverage and platform runtime smoke.

Automated checks:
- PASS `/opt/homebrew/bin/flutter test test/data/display/display_awake_service_test.dart test/presentation/main/recording_display_awake_coordinator_test.dart test/presentation/main/main_screen_test.dart`
- PASS `/opt/homebrew/bin/flutter test integration_test/main_screen_display_awake_flow_test.dart`
- PASS `/opt/homebrew/bin/flutter test -d emulator-5554 integration_test/main_screen_display_awake_flow_test.dart`
- PASS `/opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_display_awake_flow_test.dart`
- PASS `/opt/homebrew/bin/flutter analyze`
- PASS remediation rerun `/opt/homebrew/bin/flutter test test/data/display/display_awake_service_test.dart test/presentation/main/recording_display_awake_coordinator_test.dart test/presentation/main/main_screen_test.dart`
- PASS remediation rerun `/opt/homebrew/bin/flutter test -d emulator-5554 integration_test/main_screen_display_awake_flow_test.dart`
- PASS remediation rerun `/opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_display_awake_flow_test.dart`
- PASS remediation rerun `/opt/homebrew/bin/flutter analyze`
- INFO remediation host-desktop attempt `/opt/homebrew/bin/flutter test -d macos integration_test/main_screen_display_awake_flow_test.dart` was not applicable because this repo does not include a macOS desktop target.

Backend generation prerequisite:
- Not needed. The generated backend API package was already present locally, so
  `npm run build` was not required for this implementation pass.

Android emulator runtime evidence:
- PASS Android emulator launched directly through the repo-documented fallback:
  `/Users/alexander/Library/Android/sdk/emulator/emulator -avd Pixel_8_emulator -no-snapshot-load`
- PASS `adb -s emulator-5554 shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity`
  returned:
  `Status: ok`
  `LaunchState: COLD`
  `Activity: com.wrait.flutter/.MainActivity`
  `TotalTime: 2806`
- PASS device-targeted integration coverage on `emulator-5554` exercised:
  listening -> upload/saved release
  listening -> error release
  listening -> background/app-lock release
- INFO emulator boot set `screen_off_timeout` to `2147483647`, so an ordinary
  idle-lock baseline was not reliable in this environment. The approved
  validation exception was used for that part of runtime evidence instead of
  claiming a hard measured dim/lock interval.
- INFO package identity under the emulator validation path was
  `com.wrait.flutter`, confirmed through `adb -s emulator-5554 shell pm list packages`.
- PASS remediation launcher verification:
  `adb -s emulator-5554 shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity`
  returned:
  `Status: ok`
  `LaunchState: WARM`
  `Activity: com.wrait.flutter/.MainActivity`
  `TotalTime: 1264`

iOS simulator runtime evidence:
- PASS device-targeted integration coverage on simulator
  `491CD949-D3C0-4C4C-A6B9-15BAB1859156` exercised:
  listening -> upload/saved release
  listening -> error release
  listening -> background/app-lock release
- PASS the test compiled and ran through Xcode on the connected iPhone 17
  simulator.
- INFO simulator idle dim/lock behavior was not used as a hard baseline. The
  approved exception was used here as well, with app-contract evidence coming
  from the targeted integration flow.

Review remediation notes:
- PASS review PO-1 / PO-3 remediation: the coordinator now tracks desired state
  separately from applied state, retries failed same-state updates when later
  events re-drive the coordinator, and serializes release after in-flight
  operations.
- PASS review PO-2 remediation: `MainScreen` now defaults an unknown initial
  lifecycle state to inactive and only acquires keep-awake after a definitive
  resumed callback.
- PASS added async race coverage, failed-enable retry coverage, conservative
  startup coverage, and post-disposal no-op coverage across unit, widget, and
  device-targeted integration tests.
- PASS second review pass cleanup: `FakeDisplayAwakeService.flush()` now
  documents the two-turn async drain requirement instead of leaving the
  double-zero-delay helper unexplained.
- INFO second review pass accepted as non-blocking within US-021 scope:
  no platform wakelock readback/reconciliation was added, no extra coordinator
  input assertions were added beyond disposed-state guards, no dedicated
  performance benchmark was added, and real-plugin end-to-end validation
  remains covered by the approved validation exception plus runtime evidence.
```

## Notes

- Do not use `RecordingControllerState.isActive` for keep-awake; it includes
  uploading and processing, which are explicitly out of scope for US-021.
- App-lock and non-resumed lifecycle states count as inactive for keep-awake
  even if upload, cleanup, registration, or retry work continues behind the
  lock or in the background.
- Manual device lock, power button, power off, and operating-system power
  policies remain outside app-controlled keep-awake behavior.
