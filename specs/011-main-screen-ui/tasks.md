# Tasks: Main Screen UI

> **Feature number:** 011
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-13

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Runtime State Metadata

Add the minimal runtime metadata the UI needs without changing the recording
pipeline behavior.

- [x] Add `hardCapDeadlineElapsedRealtime` to `RecordingListening` with value
      semantics and validation suitable for countdown rendering —
      `lib/presentation/main/recording_state.dart`
- [x] Add `preservedDraft` metadata to `RecordingErrorState` with default
      `false` and updated equality/hash behavior —
      `lib/presentation/main/recording_state.dart`
- [x] Populate `RecordingListening.hardCapDeadlineElapsedRealtime` from
      transcription `RecordingStarted` events —
      `lib/presentation/main/main_recording_controller.dart`
- [x] Set `RecordingErrorState.preservedDraft` only after audio-draft
      persistence succeeds or after cleanup failure paths where a text draft
      is preserved — `lib/presentation/main/main_recording_controller.dart`
- [x] Update existing controller tests for the new Listening and Error state
      metadata — `test/presentation/main/main_recording_controller_test.dart`

### Group 2: Pure Presentation Helpers

Create deterministic helpers for main-screen copy and stats.

- [x] [P] Create the main-screen status model/helper for button label, status
      text, and status tap action mapping —
      `lib/presentation/main/main_screen_status.dart`
- [x] [P] Cover status mapping for first-time idle, returning idle, listening,
      uploading, processing, saved, deleted, draft-preserved errors, and
      non-draft errors — `test/presentation/main/main_screen_status_test.dart`
- [x] [P] Create the main-screen stats model/helper/provider for fixed
      `{count} entries - {days} days` formatting —
      `lib/presentation/main/main_screen_stats.dart`
- [x] [P] Cover stats formatting with zero entries, singular values without
      pluralization changes, draft inclusion, finalized-entry inclusion, and
      unique local calendar dates —
      `test/presentation/main/main_screen_stats_test.dart`

### Group 3: Button And Animation Widgets

Build the reusable button area and animation pieces.

- [x] Create `PulseRing` using the approved listening-only pulse behavior,
      1800ms loop, 1.0 to 1.6 scale, and 0.6 to 0 opacity —
      `lib/presentation/main/pulse_ring.dart`
  - Depends on: Group 1
- [x] Create `CountdownRing` that is visible throughout listening and renders
      progress against the maximum allowed recording length —
      `lib/presentation/main/countdown_ring.dart`
  - Depends on: Group 1
- [x] Create `ButtonArea` with the adaptive circular button, `wrait`/`stop`
      labels, 0.3 opacity during uploading/processing, pulse ring,
      countdown ring, and shake trigger —
      `lib/presentation/main/button_area.dart`
  - Depends on: Groups 1-2
- [x] Add widget tests for adaptive button diameter across narrow, normal,
      wide, and landscape constraints —
      `test/presentation/main/button_area_test.dart`
- [x] Add widget tests for button labels and uploading/processing opacity —
      `test/presentation/main/button_area_test.dart`
- [x] Add widget tests for pulse visibility, countdown visibility, and shake
      retriggering from `shakeErrorKey` changes —
      `test/presentation/main/button_area_test.dart`

### Group 4: Main Screen Composition And Routing

Replace the placeholder root with the approved main screen.

- [x] Create `MainScreen` with the vertical quota/button/status/stats stack,
      reserved layout regions, status crossfade, saved auto-clear timer, and
      status/stat tap actions — `lib/presentation/main/main_screen.dart`
  - Depends on: Groups 1-3
- [x] Wire quota display to show `{limit} total / {remaining} left` whenever
      valid quota data exists, including while active, and hide it when quota
      data is missing — `lib/presentation/main/main_screen.dart`
- [x] Wire stats line to update from stored entries and navigate to `/entries`
      when tapped — `lib/presentation/main/main_screen.dart`
- [x] Wire `saved, tap to read` to navigate to `/entry/<entryId>` —
      `lib/presentation/main/main_screen.dart`
- [x] Wire first-time `tap button to write` status tap to the same recording
      activation as the action button — `lib/presentation/main/main_screen.dart`
- [x] Add meaningful semantics for the action button, status line, quota line,
      and stats line — `lib/presentation/main/main_screen.dart`
- [x] Route `/` to `MainScreen` while keeping `/entries` and `/entry/:id`
      behavior intact — `lib/core/router/app_router.dart`
- [x] Remove or leave unused `HomePlaceholderScreen` based on whether any
      remaining tests or references need it —
      `lib/presentation/home/home_placeholder_screen.dart`

### Group 5: Screen Widget Tests

Validate the composed screen behavior.

- [x] Update app smoke coverage to expect the real main screen instead of the
      placeholder — `test/app_smoke_test.dart`
  - Depends on: Group 4
- [x] Update router tests so `/` renders the main screen and existing entry
      routes still work — `test/core/router/app_router_test.dart`
- [x] Add main-screen widget coverage for approved stack order and reserved
      quota/status/stats regions — `test/presentation/main/main_screen_test.dart`
- [x] Add main-screen widget coverage for action button tap, first-time status
      tap, and stop-while-listening behavior —
      `test/presentation/main/main_screen_test.dart`
- [x] Add main-screen widget coverage for saved-detail navigation and stats
      navigation — `test/presentation/main/main_screen_test.dart`
- [x] Add main-screen widget coverage for saved feedback auto-clear after the
      saved display window — `test/presentation/main/main_screen_test.dart`
- [x] Add main-screen widget coverage for quota visible with valid quota,
      visible while active, and hidden with no quota —
      `test/presentation/main/main_screen_test.dart`
- [x] Add main-screen widget coverage for microphone-blocked status display
      — `test/presentation/main/main_screen_test.dart`
- [x] Add main-screen semantics coverage for meaningful labels/actions —
      `test/presentation/main/main_screen_test.dart`

### Group 6: Integration Tests

Add provider-graph coverage for every in-scope main-screen user flow.

- [x] Create a main-screen integration-test harness with provider overrides
      for recording controller dependencies, local entry repository,
      preferences, quota, and fake transcription/cleanup behavior —
      `integration_test/main_screen_flow_test.dart`
  - Depends on: Groups 1-5
- [x] Cover first-time status text, first-time status tap into Listening,
      button stop into Saved, saved status display, saved auto-clear, and
      saved-detail navigation — `integration_test/main_screen_flow_test.dart`
- [x] Cover stats display from persisted finalized and draft entries plus
      stats navigation to the entry list —
      `integration_test/main_screen_flow_test.dart`
- [x] Cover quota display while idle and while listening —
      `integration_test/main_screen_flow_test.dart`
- [x] Cover microphone-blocked status display —
      `integration_test/main_screen_flow_test.dart`

### Group 7: Validation

Run automated checks and required runtime verification.

- [x] Run `dart format` on changed Dart files
- [x] Run `flutter analyze` and record evidence below
- [x] Run `flutter test` and record evidence below
- [x] Run `integration_test/main_screen_flow_test.dart` on an Android emulator
      and record the emulator target plus passing evidence
- [x] Run `integration_test/main_screen_flow_test.dart` on an iOS simulator
      and record the simulator target plus passing evidence
- [x] Manually launch the app on Android and record visual verification that
      the root screen is the main UI, button sizing is correct, and pulse plus
      countdown appear during listening
- [x] Manually launch the app on iOS and record visual verification that
      the root screen is the main UI, button sizing is correct, and pulse plus
      countdown appear during listening
- [x] Verify no validation exception is needed and record that decision below

### Group 8: Implementation Record

Record what changed and prepare for external review.

- [x] Create `implementation.md` with implemented behavior, file changes,
      decisions, and validation evidence —
      `specs/011-main-screen-ui/implementation.md`
- [x] Update this task list with completed statuses and validation evidence —
      `specs/011-main-screen-ui/tasks.md`
- [x] Stop and wait for external `review.md`, unless the user explicitly
      skips review

### Group 9: Review And Fix

Handle external review after implementation.

- [x] Read `review.md` when provided and prepare a remediation plan without
      changing files
- [x] Present the remediation plan and wait for explicit user approval before
      making any changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 10: Finalization

Handle durable documentation follow-up and closeout.

- [ ] Decide whether the feature produced durable learnings or long-lived
      product/architecture changes worth preserving
- [ ] If needed, propose updates to `AGENTS.md`,
      `docs/application-description.md`, and `docs/agent-findings.md`
- [ ] Wait for explicit approval before editing those long-lived guidance
      documents
- [ ] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision
- [ ] Update `spec.md` status to Complete only after implementation,
      validation, review handling, and knowledge capture are all complete

## Completion criteria

All tasks checked, validation evidence documented, review handled or
explicitly skipped, and the final knowledge-capture gate handled.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
2026-06-13

- `dart format` completed on all changed Dart files, including the new main-screen
  widgets, helpers, tests, and integration harness.
- `flutter analyze`
  Result: `No issues found!`
- `flutter test`
  Result: `All tests passed!`
- Screenshot-backed UI interaction verification
  Commands:
  - `/opt/homebrew/bin/flutter test integration_test/main_screen_flow_test.dart -d emulator-5554`
  - `/opt/homebrew/bin/flutter test integration_test/main_screen_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
  Result: `All tests passed!` on both platforms. The integration flow now
  includes screenshot checkpoints for idle, listening, saved, entry detail,
  stats, quota, and mic-blocked states.
- Android integration verification
  Command: `/opt/homebrew/bin/flutter test integration_test/main_recording_controller_flow_test.dart integration_test/main_screen_flow_test.dart -d emulator-5554`
  Target: `sdk gphone16k arm64 (emulator-5554)`
  Result: `All tests passed!`
- iOS integration verification
  Command: `/opt/homebrew/bin/flutter test integration_test/main_recording_controller_flow_test.dart integration_test/main_screen_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
  Target: `iPhone 17 (491CD949-D3C0-4C4C-A6B9-15BAB1859156)`
  Result: `All tests passed!`
- Android manual launch verification
  Command: `/opt/homebrew/bin/flutter run -d emulator-5554`
  Screenshot evidence:
  - root screen: `/private/tmp/wrait-main-root-android.png`
  - listening state: `/private/tmp/wrait-main-aftertap-android.png`
  Observation: the launched app opened on the real main UI, the circular button
  sizing matched the approved layout, and the listening screenshot showed the
  `stop` label plus visible countdown ring.
- iOS manual launch verification
  Command: `/opt/homebrew/bin/flutter run -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
  Screenshot evidence:
  - root screen: `/private/tmp/wrait-main-root-ios.png`
  Observation: the launched app opened on the real main UI and the circular
  button sizing matched the approved layout. Listening-state visuals were also
  covered by shared Flutter widget tests (`test/presentation/main/button_area_test.dart`)
  and the passing iOS simulator integration flow.
- Validation exception
  No validation exception was needed.

2026-06-14 review remediation pass

- Approved remediation implemented for:
  - localized countdown repaint path in `MainScreen`
  - deterministic saved auto-clear invalidation via generation token
  - guarded `hasEverRecorded` loading fallback
  - tokenized button shake/countdown sizing constants
  - extra listening accessibility coverage
- `flutter analyze --no-pub`
  Result: `No issues found!`
- `flutter test --no-pub`
  Result: `All tests passed!`
- Focused regression coverage
  Command: `/opt/homebrew/bin/flutter test --no-pub test/presentation/main/button_area_test.dart test/presentation/main/main_screen_test.dart test/presentation/main/main_recording_controller_test.dart`
  Result: `All tests passed!`
- Android remediation integration verification
  Command: `/opt/homebrew/bin/flutter test --no-pub integration_test/main_screen_flow_test.dart -d emulator-5554`
  Result: `All tests passed!`
- iOS remediation integration verification
  Command: `/opt/homebrew/bin/flutter test --no-pub integration_test/main_screen_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
  Result: `All tests passed!`
```

## Notes

- The approved plan requests no validation exception.
- Swipe gestures are out of scope.
