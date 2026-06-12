# Tasks: Recording State Machine and Controller

> **Feature number:** 010
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-12

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: State Model And Transcription Surface

Set up the runtime state contracts and lower-level failure reasons the
controller will consume.

- [x] [P] Create the app-facing recording state model with `RecordingState`,
      `RecordingError`, `RecordingControllerState`, `isActive`, and equality
      semantics — `lib/presentation/main/recording_state.dart`
- [x] [P] Extend transcription failure reasons with `tooShort`,
      `nothingCaught`, and `micBlocked` — `lib/data/transcription/transcription_service.dart`
- [x] [P] Update cloud transcription behavior so too-short live stops and
      blank nominal successes return typed transcription failures instead of
      leaking generic failures or exceptions — `lib/data/transcription/cloud_transcription_service.dart`
- [x] [P] Add or update cloud transcription unit coverage for typed too-short
      and blank-transcript/NoMatch behavior — `test/data/transcription/cloud_transcription_service_test.dart`

### Group 2: Main Recording Controller

Implement the main Best-mode state machine and provider wiring.

- [x] Create `MainRecordingController` as a Riverpod notifier with initial
      Idle state, public `onMainButtonTapped`, `clearSaved`, `resetToIdle`,
      and `onEntriesDeleted` methods — `lib/presentation/main/main_recording_controller.dart`
  - Depends on: Group 1
- [x] Wire controller dependencies from existing providers: transcription
      service, cleanup use case, entry repository, preferences repository,
      monotonic clock, warning logger, and configurable feedback delays —
      `lib/presentation/main/main_recording_controller.dart`
- [x] Implement Idle/Saved/Deleted/retryable Error start behavior, Listening
      stop behavior, Uploading/Processing ignored behavior, and
      insufficient-permissions reset behavior — `lib/presentation/main/main_recording_controller.dart`
- [x] Ensure `RecordingControllerState.isActive` is true only for Listening,
      Uploading, and Processing, and false for Idle, Saved, Error, and Deleted
      — `lib/presentation/main/recording_state.dart`
- [x] Implement Best-mode success orchestration: Listening -> Uploading ->
      Processing -> cleanup use case -> `setHasEverRecorded(true)` ->
      Saved(entryId, detectedLanguage) — `lib/presentation/main/main_recording_controller.dart`
- [x] Implement transcription failure handling, including audio-draft
      persistence when `audioDraftPath` is present and Android-equivalent
      failure mapping — `lib/presentation/main/main_recording_controller.dart`
- [x] Implement cleanup failure handling, including draft preservation through
      the cleanup use case and Android-equivalent failure mapping —
      `lib/presentation/main/main_recording_controller.dart`
- [x] Implement shake-error increments exactly for TooShort and NoMatch —
      `lib/presentation/main/main_recording_controller.dart`
- [x] Implement cancellable three-second auto-clear behavior for Error and
      Deleted feedback, and ensure Saved only clears via `clearSaved()` or a
      new recording start — `lib/presentation/main/main_recording_controller.dart`

### Group 3: Controller Unit Tests

Cover the state machine with deterministic fake dependencies and short timer
durations.

- [x] Add test doubles for transcription service, cleanup callback/use case,
      entry repository, preferences repository, monotonic clock, and warning
      logging as needed — `test/presentation/main/main_recording_controller_test.dart`
- [x] Test Idle button tap starts live recording and publishes Listening —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] Test Listening stop before five seconds publishes TooShort, increments
      `shakeErrorKey` once, and auto-clears to Idle —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] Test valid stop publishes Uploading, then Processing, then Saved with
      entry id and detected language after transcription and cleanup success —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] Test Uploading and Processing button taps are ignored —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] Test Saved, Deleted, and retryable Error button taps start a new
      independent recording attempt without mutating previously saved entries —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] Test insufficient-permissions Error button tap resets to Idle —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] Test transcription failure mapping for TooShort, NoMatch, NoInternet,
      BackendUnavailable, ProxyAuthFailed, and ApiFailed —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] Test transcription failure with `audioDraftPath` persists an audio draft
      using the supported fallback language before publishing Error —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] Test cleanup failure preserves the draft, publishes mapped Error, and
      does not set `hasEverRecorded` — `test/presentation/main/main_recording_controller_test.dart`
- [x] Test cleanup success sets `hasEverRecorded` and still publishes Saved
      when preference persistence logs a warning —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] Test Deleted feedback ignores non-positive counts, publishes positive
      counts, and auto-clears after the configured delay —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] Test Saved feedback does not auto-clear from the controller and clears
      only through `clearSaved()` or new recording start —
      `test/presentation/main/main_recording_controller_test.dart`

### Group 4: Provider-Graph Integration Tests

Add in-scope integration coverage using fake service callbacks plus real
repository/preference wiring where practical.

- [x] Create the main recording controller integration-test harness with a
      real encrypted local database, real entry repository, SharedPreferences
      test store, fake transcription service, and backend cleanup callback
      overrides — `integration_test/main_recording_controller_flow_test.dart`
  - Depends on: Groups 1-2
- [x] Test provider graph completes the Best-mode success path through
      controller tap start/stop, transcription, cleanup, finalized entry
      persistence, session quota update, Saved state, and `hasEverRecorded` —
      `integration_test/main_recording_controller_flow_test.dart`
- [x] Test provider graph preserves an audio draft and emits mapped Error when
      live transcription fails after capture —
      `integration_test/main_recording_controller_flow_test.dart`
- [x] Test provider graph preserves a text draft and emits mapped Error when
      cleanup fails after transcription success —
      `integration_test/main_recording_controller_flow_test.dart`
- [x] Test provider graph supports starting another recording after Saved
      while the first saved entry remains persisted —
      `integration_test/main_recording_controller_flow_test.dart`

### Group 5: Validation

Run automated checks and required runtime verification.

- [x] Run `dart format` on changed Dart files
- [x] Run `flutter analyze` and record evidence below
- [x] Run `flutter test` and record evidence below
- [x] Run `integration_test/main_recording_controller_flow_test.dart` on an
      Android emulator and record the emulator target plus passing evidence
- [x] Run `integration_test/main_recording_controller_flow_test.dart` on an
      iOS simulator and record the simulator target plus passing evidence
- [x] Verify no validation exception is needed and record that decision below

### Group 6: Implementation Record

Record what changed and prepare for external review.

- [x] Create `implementation.md` with implemented behavior, file changes,
      decisions, and validation evidence —
      `specs/010-recording-state-machine-controller/implementation.md`
- [x] Update this task list with completed statuses and validation evidence —
      `specs/010-recording-state-machine-controller/tasks.md`
- [x] Stop and wait for external `review.md`, unless the user explicitly
      skips review

### Group 7: Review And Fix

Handle external review after implementation.

- [x] Read `review.md` when provided and prepare a remediation plan without
      changing files
- [x] Present the remediation plan and wait for explicit user approval before
      making any changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [x] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 8: Finalization

Handle durable documentation follow-up and closeout.

- [x] Decide whether the feature produced durable learnings or long-lived
      product/architecture changes worth preserving
- [x] If needed, propose updates to `AGENTS.md`,
      `docs/application-description.md`, and `docs/agent-findings.md`
- [x] Wait for explicit approval before editing those long-lived guidance
      documents
- [x] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision
- [x] Update `spec.md` status to Complete only after implementation,
      validation, review handling, and knowledge capture are all complete

## Completion criteria

All tasks checked, validation evidence documented, review handled or
explicitly skipped, and the final knowledge-capture gate handled.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
$ dart format lib/presentation/main/recording_state.dart lib/presentation/main/main_recording_controller.dart lib/data/transcription/transcription_service.dart lib/data/transcription/cloud_transcription_service.dart test/data/transcription/cloud_transcription_service_test.dart test/presentation/main/main_recording_controller_test.dart integration_test/main_recording_controller_flow_test.dart
Completed successfully.

$ /opt/homebrew/bin/flutter analyze
No issues found! (ran in 3.3s)

$ /opt/homebrew/bin/flutter test
All tests passed! (132 tests)

$ /opt/homebrew/bin/flutter test integration_test/main_recording_controller_flow_test.dart -d emulator-5554
All tests passed on Android emulator sdk gphone16k arm64 (emulator-5554).

$ /opt/homebrew/bin/flutter test integration_test/main_recording_controller_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156
All tests passed on iOS simulator iPhone 17 (491CD949-D3C0-4C4C-A6B9-15BAB1859156).

Validation exception: none requested, none used.

$ /opt/homebrew/bin/flutter analyze
No issues found! (ran in 2.5s) after review remediation.

$ /opt/homebrew/bin/flutter test
All tests passed! (137 tests) after review remediation.

$ /opt/homebrew/bin/flutter test integration_test/main_recording_controller_flow_test.dart -d emulator-5554
All tests passed on Android emulator sdk gphone16k arm64 (emulator-5554) after review remediation.

$ /opt/homebrew/bin/flutter test integration_test/main_recording_controller_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156
All tests passed on iOS simulator iPhone 17 (491CD949-D3C0-4C4C-A6B9-15BAB1859156) after review remediation.
```

## Notes

- The approved plan requests no validation exception.
- US-010 owns concrete Best-mode network preflight.
- Offline-mode recording remains out of scope for this feature.
- Knowledge capture completed with approved updates to
  `docs/application-description.md` and `docs/agent-findings.md`.
- `AGENTS.md` was reviewed during the documentation phase and intentionally
  left unchanged because US-009 did not add a new recurring workflow rule.
- The same `review.md` file was not updated for another pass after the
  approved remediation.
