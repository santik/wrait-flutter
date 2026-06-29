# Tasks: Recording, Sharing, and Navigation Polish

> **Feature number:** 035
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-24

---

## Legend

- `[ ]` - not started
- `[x]` - complete
- `[P]` - can be parallelized with other `[P]` tasks in the same group
- `[B]` - blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Baseline and contracts

Confirm current behavior and establish the smallest internal contracts needed
for implementation.

- [x] Inspect current recording pulse geometry on the main screen and identify
      the layout bounds needed for full-screen pulse sizing
- [x] Inspect current entry-detail share payload construction and identify the
      existing date/time display format to reuse
- [x] Inspect current route/back behavior for `/`, `/entries`, and `/entry/:id`
      to confirm which surfaces need explicit Android back handling
- [x] Confirm no data model, backend API, generated client, app-lock, or
      capture-privacy changes are needed

### Group 2: Recording pulse implementation

Make the active recording pulse reach the screen borders and slightly beyond
without changing recording logic.

- [x] Update `MainScreen` to pass available recording surface bounds or pulse
      diameter input into the action area - `lib/presentation/main/main_screen.dart`
  - Depends on: Group 1
- [x] Update `ButtonArea` to render the enlarged listening pulse behind the
      action button and countdown while preserving current idle/uploading/
      processing states - `lib/presentation/main/button_area.dart`
  - Depends on: main-screen bounds task
- [x] Update `PulseRing` only as needed to support the larger pulse diameter
      while preserving animation timing and opacity - `lib/presentation/main/pulse_ring.dart`
  - Depends on: button-area task
- [x] Verify action button, countdown ring, quota, status, stats navigation, and
      error feedback remain visible and tappable while the pulse is active
  - Depends on: pulse implementation tasks

### Group 3: Share date/time implementation

Include the record date and time in shared entry text while preserving the
existing shared body content.

- [x] Add or expose a share-date/time formatter using the existing in-app entry
      timestamp style and locale fallback - `lib/presentation/entries/entry_detail_formatters.dart`
  - Depends on: Group 1
- [x] Update entry-detail sharing to compose date/time plus displayed body text
      before calling the share service - `lib/presentation/entries/entry_detail_controller.dart`
  - Depends on: formatter task
- [x] Pass entry `createdAt` and locale into the share path for readable and
      edited detail states - `lib/presentation/entries/entry_detail_screen.dart`
  - Depends on: controller share task
- [x] Preserve generic share failure messaging and avoid exposing extra metadata
      beyond date/time and the existing shared body content
  - Depends on: screen share task

### Group 4: Android back behavior implementation

Align Android system back with visible app back behavior while keeping root
behavior simple.

- [x] Verify current `PopScope` behavior on entry detail and adjust only if
      Android system back does not already use `_handleBackNavigation` -
      `lib/presentation/entries/entry_detail_screen.dart`
  - Depends on: Group 1
- [x] Add route-level or screen-level back handling only where needed so system
      back from detail returns to entries after flushing edits and system back
      from the entry list returns to the main screen - `lib/presentation/entries/entry_list_screen.dart`
  - Depends on: current behavior verification
- [x] Confirm dialogs, delete confirmation, text editing, share flow, and
      app-lock surfaces keep their existing back behavior
  - Depends on: back handling task
- [x] Leave main/root back behavior unchanged when current platform behavior is
      the simplest compatible option
  - Depends on: route behavior inspection

### Group 5: Automated tests

Add focused coverage for each in-scope user flow and regression risk from the
plan.

- [x] Add widget coverage for enlarged listening pulse sizing and layering -
      `test/presentation/main/button_area_test.dart`
  - Depends on: Group 2
- [x] Add unit coverage for shared date/time formatting and locale fallback -
      `test/presentation/entries/entry_detail_formatters_test.dart`
  - Depends on: Group 3
- [x] Add controller coverage for sharing date/time plus body text and preserving
      share failure behavior - `test/presentation/entries/entry_detail_controller_test.dart`
  - Depends on: Group 3
- [x] Add widget coverage for entry-detail share payloads and platform pop/back
      parity where practical - `test/presentation/entries/entry_detail_screen_test.dart`
  - Depends on: Groups 3 and 4
- [x] Add widget coverage for entry-list system back parity with the visible
      back button - `test/presentation/entries/entry_list_screen_test.dart`
  - Depends on: Group 4
- [x] Add integration coverage for active-recording pulse geometry on the app
      main surface - `integration_test/main_screen_flow_test.dart`
  - Depends on: Group 2
- [x] Extend integration coverage for readable short, long, draft-like where
      sharing is already available, edited share, and platform pop/back from
      entry detail - `integration_test/entry_detail_flow_test.dart`
  - Depends on: Groups 3 and 4
- [x] Add integration coverage for platform pop/back from the entry list
      returning to the main screen - `integration_test/entry_list_flow_test.dart`
  - Depends on: Group 4
- [x] Ensure every in-scope user flow from the plan has `integration_test`
      coverage or document a user-approved exception
  - Depends on: integration test tasks

### Group 6: Host validation

Run focused and broad local validation before device/simulator checks.

- [x] Run `/opt/homebrew/bin/flutter analyze`
  - Depends on: Group 5
- [x] Run focused widget/unit tests for main and entry-detail changes
  - Depends on: analyzer success
- [x] Run focused integration tests for the touched flows, using explicit `-d`
      device targets when Flutter requires device disambiguation in this
      environment
  - Depends on: focused widget/unit tests
- [x] Run the broader relevant test set if focused tests pass:
      `test/presentation/main`, `test/presentation/entries`, and existing
      entry/main integration coverage
  - Depends on: focused host integration tests
- [x] Fix any validation failures without expanding scope beyond the approved
      spec and plan
  - Depends on: validation results

### Group 7: Android emulator validation

Collect runtime evidence on Android emulator as required by the plan.

- [x] Run focused automated tests on Android emulator for main recording and
      entry detail flows
  - Depends on: Group 6
- [x] Start recording and capture evidence that the pulse reaches all screen
      edges and slightly beyond while controls remain usable
  - Depends on: Android test run
- [x] Share an entry and verify the payload includes date/time plus body text
  - Depends on: Android test run
- [x] Press Android system back from entry detail and verify it returns to the
      entry list after flushing edits when applicable
  - Depends on: Android test run
- [x] Verify root/main-screen back behavior remains platform-appropriate and
      does not introduce a navigation loop
  - Depends on: Android back validation

### Group 8: iOS simulator validation

Collect runtime evidence on iOS simulator as required by the plan.

- [x] Run focused automated tests on iOS simulator for main recording and entry
      detail flows
  - Depends on: Group 6
- [x] Start recording and capture evidence that the pulse reaches all screen
      edges and slightly beyond while controls remain usable
  - Depends on: iOS test run
- [x] Share an entry and verify the payload includes date/time plus body text
  - Depends on: iOS test run
- [x] Confirm entry detail navigation, visible back, edit, share failure, and
      delete dialog behavior were not regressed
  - Depends on: iOS test run

### Group 9: Artifact updates

Record implementation details and validation evidence for review.

- [x] Update `tasks.md` checkboxes and validation evidence as implementation
      proceeds - `specs/035-recording-sharing-navigation-polish/tasks.md`
- [x] Create `implementation.md` with implementation notes, file changes,
      test results, Android emulator evidence, and iOS simulator evidence -
      `specs/035-recording-sharing-navigation-polish/implementation.md`
- [x] Update `spec.md`, `plan.md`, or `tasks.md` only if implementation findings
      require approved scope or approach corrections
- [x] Confirm no product behavior beyond the approved pulse, share date/time,
      and Android back changes was intentionally introduced
- [x] Confirm no API contract, data model, backend generation, app-lock, or
      capture-privacy changes were introduced

### Group 10: Review and fix

Handle external review after implementation.

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

### Group 11: Finalization

Handle durable documentation follow-up and closeout.

- [x] Decide whether this polish story produced durable guidance for
      `AGENTS.md`, `docs/application-description.md`, or
      `docs/agent-findings.md`
- [x] If durable guidance is needed, propose exact documentation updates to the
      user
- [x] Wait for explicit approval before editing long-lived guidance documents
- [x] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, Android
emulator evidence, iOS simulator evidence, and review-related notes here during
implementation.

```text
Implementation validation:

- dart format on all touched Dart files -> passed
- /opt/homebrew/bin/flutter analyze -> passed
- /opt/homebrew/bin/flutter test --no-pub test/presentation/main/button_area_test.dart test/presentation/entries/entry_detail_formatters_test.dart test/presentation/entries/entry_detail_controller_test.dart test/presentation/entries/entry_detail_screen_test.dart test/presentation/entries/entry_list_screen_test.dart -> passed
- /opt/homebrew/bin/flutter test --no-pub test/presentation/main test/presentation/entries -> passed

Integration validation notes:

- /opt/homebrew/bin/flutter test --no-pub integration_test/... without `-d` -> Flutter required explicit device selection because multiple devices were connected
- /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_flow_test.dart integration_test/entry_detail_flow_test.dart integration_test/entry_list_flow_test.dart -> passed
- /opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/main_screen_flow_test.dart integration_test/entry_detail_flow_test.dart integration_test/entry_list_flow_test.dart -> passed

Post-feedback pulse visibility fix:

- /opt/homebrew/bin/flutter analyze -> passed
- /opt/homebrew/bin/flutter test --no-pub test/presentation/main/button_area_test.dart -> passed
- /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_flow_test.dart -> passed

Review remediation validation:

- dart format on remediated Dart files -> passed
- /opt/homebrew/bin/flutter analyze -> passed
- /opt/homebrew/bin/flutter test --no-pub test/presentation/main/button_area_test.dart test/presentation/entries/entry_detail_formatters_test.dart test/presentation/entries/entry_detail_controller_test.dart test/presentation/entries/entry_list_screen_test.dart test/presentation/entries/entry_detail_screen_test.dart -> passed
- /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_flow_test.dart -> passed
- /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_detail_flow_test.dart integration_test/entry_list_flow_test.dart -> passed
- /opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/main_screen_flow_test.dart -> passed
- /opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/entry_detail_flow_test.dart integration_test/entry_list_flow_test.dart -> passed
- /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_flow_test.dart integration_test/entry_detail_flow_test.dart integration_test/entry_list_flow_test.dart -> intermittent simulator-only failure in `main_screen_flow_test.dart: listening pulse grows beyond the viewport while controls stay visible`; isolated `main_screen_flow_test.dart` and the shared `entry_detail` + `entry_list` run both passed, so this was recorded as a simulator combined-run flake rather than an app regression

Environment notes:

- Android emulator booted via `/Users/alexander/Library/Android/sdk/emulator/emulator @Pixel_8_emulator -no-snapshot-save`
- Android runs emitted a non-blocking Flutter warning that `package_info_plus`, `share_plus`, `speech_to_text`, and `wakelock_plus` still apply the Kotlin Gradle Plugin path and will need future maintenance
```

## Notes

Implementation finding: Android system back parity also required
`entry_list_screen.dart` because route changes use `context.go(...)`, which
does not preserve the same route history as a push-style navigation stack.
The pulse ring also needed a stronger visible stroke/glow at the button-sized
start of the animation so it remained perceptible on deployed devices.
The knowledge-capture gate resulted in approved updates to `AGENTS.md`,
`docs/application-description.md`, and `docs/agent-findings.md`.
