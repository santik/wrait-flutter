# Tasks: Entry List Screen

> **Feature number:** 013
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-14

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Localization And Route Foundation

Prepare app-level prerequisites and replace the placeholder route entry point.

- [x] Add SDK `flutter_localizations` and direct `intl` support for
      locale-aware weekday, date, and time formatting — `pubspec.yaml`
- [x] Register Flutter localization delegates and broadly supported locales
      without changing existing UI copy — `lib/app.dart`
- [x] Route `/entries` to a new entry-list screen instead of the shell
      placeholder — `lib/core/router/app_router.dart`
- [x] Create the `presentation/entries` module folder and initial entry-list
      files — `lib/presentation/entries/`

### Group 2: Pure Entry-List State And Formatting

Create deterministic helpers before composing widgets.

- [x] [P] Create the entry-list controller/provider that watches all entries,
      includes drafts, sorts by `createdAt` descending, and exposes delete
      handling — `lib/presentation/entries/entry_list_controller.dart`
- [x] [P] Create row formatting helpers for content preview fallback,
      localized short weekday/date/time labels, and language display name
      fallback —
      `lib/presentation/entries/entry_list_formatters.dart`
- [x] [P] Add formatter tests for first-line cleaned-text preview,
      first-line raw-transcript fallback, audio-only draft preview, language
      labels, and locale-aware short weekday/date/time formatting —
      `test/presentation/entries/entry_list_formatters_test.dart`
- [x] [P] Add controller/provider tests for draft inclusion, newest-first
      sorting, delete success, and caught delete failure —
      `test/presentation/entries/entry_list_controller_test.dart`

### Group 3: Swipe Row Widget

Build the reusable entry row and its anchored delete reveal behavior.

- [x] Create `EntryListRow` with short weekday/date/time, single-line preview,
      always-visible language display, optional `draft` marker, and row tap
      callback —
      `lib/presentation/entries/entry_list_row.dart`
  - Depends on: Group 2
- [x] Implement right-swipe anchored reveal with hidden and 80dp revealed
      positions, red delete area, and trash icon —
      `lib/presentation/entries/entry_list_row.dart`
- [x] Trigger haptic feedback and the row fully-revealed callback when the row
      settles at the revealed anchor —
      `lib/presentation/entries/entry_list_row.dart`
- [x] Add a reset path so dialog Cancel/Delete can hide the red reveal state —
      `lib/presentation/entries/entry_list_row.dart`
- [x] Add row widget tests for layout, draft marker, preview ellipsis, row
      tap, audio-draft disabled tap, delete semantics action, 80dp red reveal,
      anchored settling, immediate reveal callback, and haptic behavior where
      practical —
      `test/presentation/entries/entry_list_row_test.dart`

### Group 4: Entry-List Screen Composition

Compose the route screen, navigation, and delete confirmation flow.

- [x] Create `EntryListScreen` with safe-area layout, top-left back control,
      centered empty state, and populated scrollable list —
      `lib/presentation/entries/entry_list_screen.dart`
  - Depends on: Groups 2-3
- [x] Wire empty state copy exactly as `no entries yet` —
      `lib/presentation/entries/entry_list_screen.dart`
- [x] Wire row taps to navigate to `/entry/<id>` —
      `lib/presentation/entries/entry_list_screen.dart`
- [x] Wire the top-left back control to return to `/` —
      `lib/presentation/entries/entry_list_screen.dart`
- [x] Show the delete confirmation dialog immediately after a row becomes
      fully revealed, using title `Delete entry?`, body
      `This entry will be permanently removed.`, and `Cancel`/`Delete`
      actions — `lib/presentation/entries/entry_list_screen.dart`
- [x] Wire Cancel to dismiss the dialog, hide the row reveal, and keep the row
      — `lib/presentation/entries/entry_list_screen.dart`
- [x] Wire Delete to call the controller delete action, dismiss the dialog,
      hide the row reveal, stay on `/entries`, and rely on the stream update
      to remove the row — `lib/presentation/entries/entry_list_screen.dart`
- [x] Ensure deletion failure keeps the row visible and shows no false
      deletion state — `lib/presentation/entries/entry_list_screen.dart`
- [x] Add meaningful semantics for back control, rows, delete action, and
      dialog actions — `lib/presentation/entries/entry_list_screen.dart`

### Group 5: Screen And Route Widget Tests

Validate composed UI behavior and update existing route expectations.

- [x] Update router tests so `/entries` renders the real entry-list screen and
      `/entry/:id` behavior remains intact —
      `test/core/router/app_router_test.dart`
  - Depends on: Group 4
- [x] Update main-screen widget tests so stats tap expects the real entry-list
      screen — `test/presentation/main/main_screen_test.dart`
- [x] Add entry-list screen tests for empty state and populated list rendering
      newest first — `test/presentation/entries/entry_list_screen_test.dart`
- [x] Add entry-list screen tests for draft marker and always-visible language
      labels — `test/presentation/entries/entry_list_screen_test.dart`
- [x] Add entry-list screen tests for audio-only draft retry preview and
      non-navigation on tap —
      `test/presentation/entries/entry_list_screen_test.dart`
- [x] Add entry-list screen tests for row tap to detail and back control to
      main — `test/presentation/entries/entry_list_screen_test.dart`
- [x] Add widget coverage for swipe reveal opening the approved confirmation
      dialog — `test/presentation/entries/entry_list_row_test.dart`
- [x] Add widget coverage for Cancel hiding the red reveal state and keeping
      the row — `test/presentation/entries/entry_list_row_test.dart`
- [x] Add widget/integration coverage for Delete removing the row after stream
      update and staying on the list —
      `test/presentation/entries/entry_list_row_test.dart`,
      `integration_test/entry_list_flow_test.dart`
- [x] Add controller/integration coverage for deletion failure leaving the row
      visible with no false deletion state —
      `test/presentation/entries/entry_list_controller_test.dart`,
      `integration_test/entry_list_flow_test.dart`
- [x] Add entry-list semantics coverage for meaningful labels/actions —
      `test/presentation/entries/entry_list_screen_test.dart`

### Group 6: Integration Tests

Add device/simulator integration coverage for every in-scope user flow.

- [x] Create an entry-list integration-test harness with provider overrides,
      local encrypted database, fake secure storage, and seeded entries —
      `integration_test/entry_list_flow_test.dart`
  - Depends on: Groups 1-5
- [x] Cover direct `/entries` empty-state flow —
      `integration_test/entry_list_flow_test.dart`
- [x] Cover populated-list flow with finalized and draft entries newest first
      plus always-visible language labels —
      `integration_test/entry_list_flow_test.dart`
- [x] Cover audio-only draft flow with retry preview, non-navigation on tap,
      and swipe-delete confirmation —
      `integration_test/entry_list_flow_test.dart`
- [x] Cover row tap navigation from list to `/entry/<id>` —
      `integration_test/entry_list_flow_test.dart`
- [x] Cover swipe-to-delete Cancel flow: reveal red area, prompt appears,
      cancel, red area hides, row remains —
      `integration_test/entry_list_flow_test.dart`
- [x] Cover swipe-to-delete Delete flow: reveal red area, prompt appears,
      confirm, row is removed, route remains `/entries` —
      `integration_test/entry_list_flow_test.dart`
- [x] Cover top-left back-control flow from `/entries` to the main screen —
      `integration_test/entry_list_flow_test.dart`
- [x] Update main-screen integration stats flow to expect the real entry-list
      screen — `integration_test/main_screen_flow_test.dart`

### Group 7: Validation

Run automated checks and required runtime verification.

- [x] Run `dart format` on changed Dart files
- [x] Run `flutter analyze` and record evidence below
- [x] Run `flutter test` and record evidence below
- [x] Run `integration_test/entry_list_flow_test.dart` on an Android emulator
      and record the emulator target plus passing evidence
- [x] Run `integration_test/main_screen_flow_test.dart` on an Android emulator
      and record the emulator target plus passing evidence for stats-to-list
      navigation
- [x] Run `integration_test/entry_list_flow_test.dart` on an iOS simulator and
      record the simulator target plus passing evidence
- [x] Run `integration_test/main_screen_flow_test.dart` on an iOS simulator and
      record the simulator target plus passing evidence for stats-to-list
      navigation
- [x] Capture Android runtime screenshot checkpoints during integration tests
      for `/entries`, populated rows, and delete-prompt states
- [x] Capture iOS runtime screenshot checkpoints during integration tests for
      `/entries`, populated rows, and delete-prompt states
- [x] Verify no validation exception is needed and record that decision below

### Group 8: Implementation Record

Record what changed and prepare for external review.

- [x] Create `implementation.md` with implemented behavior, file changes,
      decisions, and validation evidence —
      `specs/013-entry-list-screen/implementation.md`
- [x] Update this task list with completed statuses and validation evidence —
      `specs/013-entry-list-screen/tasks.md`
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

Use this section to record validation evidence and review-loop notes as the
feature progresses through implementation and review.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
2026-06-15

Formatting
- `dart format` run on all changed Dart files completed successfully.

Static analysis
- `flutter analyze` completed successfully.

Automated tests
- `flutter test` completed successfully.

Android runtime verification
- Command: `/opt/homebrew/bin/flutter test integration_test/main_screen_flow_test.dart integration_test/entry_list_flow_test.dart -d emulator-5554`
- Target: `emulator-5554` (`sdk gphone16k arm64`)
- Result: all tests passed.
- Runtime screenshot checkpoints captured during the integration run:
  `entry-list-empty`, `entry-list-populated`,
  `entry-list-audio-draft`, `entry-list-delete-prompt-cancel`,
  `entry-list-delete-prompt-confirm`, `entry-list-audio-draft-delete-prompt`,
  `main-screen-entry-list`

iOS runtime verification
- Command: `/opt/homebrew/bin/flutter test integration_test/main_screen_flow_test.dart integration_test/entry_list_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
- Target: `491CD949-D3C0-4C4C-A6B9-15BAB1859156` (`iPhone 17`)
- Result: all tests passed.
- Runtime screenshot checkpoints captured during the integration run:
  `entry-list-empty`, `entry-list-populated`,
  `entry-list-audio-draft`, `entry-list-delete-prompt-cancel`,
  `entry-list-delete-prompt-confirm`, `entry-list-audio-draft-delete-prompt`,
  `main-screen-entry-list`

Validation exception
- No validation exception requested or needed.

Workflow note
- Implementation artifacts are complete. The next gate is an externally
  provided `review.md`, unless the user explicitly skips review.

Review remediation
- Approved fixes applied for delete failure logging, timestamp-format fallback,
  reveal-flow reentrancy, and stronger destructive dialog semantics.
- Targeted command: `flutter test test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_formatters_test.dart test/presentation/entries/entry_list_row_test.dart test/presentation/entries/entry_list_screen_test.dart`
- Targeted widget/provider tests passed after the approved review fixes.
- `flutter analyze` rerun completed successfully after the approved review fixes.
- `flutter test` rerun completed successfully after the approved review fixes.
- Android rerun command: `/opt/homebrew/bin/flutter test integration_test/main_screen_flow_test.dart integration_test/entry_list_flow_test.dart -d emulator-5554`
- Android rerun result: all tests passed after the approved review fixes.
- iOS rerun command: `/opt/homebrew/bin/flutter test integration_test/main_screen_flow_test.dart integration_test/entry_list_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
- iOS rerun result: all tests passed after the approved review fixes.
- Knowledge-capture decision: durable updates were applied to
  `docs/application-description.md` and `docs/agent-findings.md`; no
  `AGENTS.md` change was needed.
- `spec.md` status was updated to `Complete` after knowledge capture closed.
```

## Notes

- Screen-level swipe navigation remains out of scope for US-013.
- Row swipe-to-delete remains in scope and opens confirmation immediately after
  the red area is fully revealed.
