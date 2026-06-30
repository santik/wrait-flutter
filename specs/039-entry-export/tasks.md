# Tasks: Entry Export

> **Feature number:** 039
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-29

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Export Contracts and CSV Core

Set up the shared export model, CSV generation, and provider contracts before
touching platform or UI behavior.

- [x] Create the export result, file writer interface, and CSV export service
      with stable file-name generation — `lib/domain/service/entry_export_service.dart`
- [x] Add CSV export unit tests covering headers, saved entries, draft entries,
      empty exports, row order, file naming, and success result shape —
      `test/domain/service/entry_export_service_test.dart`
- [x] Add CSV escaping and omission tests for commas, quotes, newlines, empty
      cleaned text, audio-only draft metadata, absent `audioPath`, and absence
      of local paths/secrets — `test/domain/service/entry_export_service_test.dart`
- [x] Add provider wiring for the export service, file writer, and export clock
      or timestamp source — `lib/data/entries/entry_export_providers.dart`

### Group 2: Platform File Writers

Implement the automatic destination writers and keep native bridge contracts
small and testable.

- [x] Create the Dart platform-channel writer for `wrait/entry_export` and map
      native responses/failures into non-sensitive Dart results —
      `lib/data/entries/entry_export_file_writer.dart`
  - Depends on: Group 1
- [x] Add platform-channel writer tests for method name, arguments, success
      response parsing, invalid responses, and platform failures —
      `test/data/entries/entry_export_file_writer_test.dart`
- [x] Implement Android CSV writing to a Downloads/Wrait-style destination via
      the native export channel while preserving existing MethodChannel handlers —
      `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
- [x] Implement iOS CSV writing to `Documents/Wrait Exports` through the native
      export channel while preserving existing device-id registration —
      `ios/Runner/AppDelegate.swift`
- [x] Enable the iOS document visibility keys required for the user-accessible
      export folder — `ios/Runner/Info.plist`

### Group 3: iOS Database Location Migration

Keep the iOS encrypted database in Application Support and out of the
Files-visible Documents export location.

- [x] Add a default database-file resolver that uses Application Support on iOS
      and preserves the existing location on Android and other platforms —
      `lib/data/entries/local_entry_database.dart`
  - Depends on: Group 1
- [x] Keep the iOS default database path isolated from the user-visible export
      folder without adding a legacy migration path —
      `lib/data/entries/local_entry_database.dart`
- [x] Add tests for iOS and non-iOS default database path resolution —
      `test/data/entries/local_entry_database_path_test.dart`

### Group 4: Entries Screen Export UI

Wire the export behavior into the entries screen without mutating entries or
changing existing navigation, deletion, sharing, app-lock, or capture behavior.

- [x] Extend the entry-list controller with a single export method that accepts
      the current entries and delegates to the export service —
      `lib/presentation/entries/entry_list_controller.dart`
  - Depends on: Groups 1 and 2
- [x] Add controller tests for export success, export failure, empty-entry
      export, and non-mutating behavior —
      `test/presentation/entries/entry_list_controller_test.dart`
- [x] Add the export icon button, semantics label, loading/disabled state, and
      success/failure SnackBar feedback to the entries screen —
      `lib/presentation/entries/entry_list_screen.dart`
- [x] Update entries screen widget tests for export button presence, semantics,
      successful feedback with destination information, failure feedback, empty
      state export, and duplicate-tap prevention —
      `test/presentation/entries/entry_list_screen_test.dart`
- [x] Confirm existing entries-screen tests for row rendering, navigation,
      delete dialog behavior, audio-only drafts, and Android system back remain
      valid after adding the export action —
      `test/presentation/entries/entry_list_screen_test.dart`

### Group 5: Integration Flow Coverage

Add end-to-end UI coverage for the in-scope export user flow with deterministic
test writer overrides.

- [x] Add a test export writer override and captured export assertion helpers
      to the entry-list integration harness — `integration_test/entry_list_flow_test.dart`
  - Depends on: Groups 1, 2, and 4
- [x] Add an integration test where the user opens the entries screen, taps
      export, sees success feedback, and the captured CSV contains saved and
      draft rows with no audio path — `integration_test/entry_list_flow_test.dart`
- [x] Add or update screenshot capture for the export action or success state
      where useful for runtime evidence — `integration_test/entry_list_flow_test.dart`

### Group 6: Automated Validation

Run the planned local validation and record command output under Validation
evidence.

- [x] Run Dart formatting for all touched Dart files
- [x] Run targeted unit/widget tests:
      `flutter test test/domain/service/entry_export_service_test.dart test/data/entries/entry_export_file_writer_test.dart test/data/entries/local_entry_database_path_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart`
- [x] Run targeted integration test on host if supported:
      `flutter test integration_test/entry_list_flow_test.dart`
- [x] Run Flutter analysis:
      `flutter analyze`
- [x] Run the broader relevant entry/local-data test set if targeted tests
      suggest shared behavior risk:
      `flutter test test/data/entries test/presentation/entries`
- [x] Record all validation commands, outputs, and any failures/fixes in the
      Validation evidence section

### Group 7: Runtime Verification

Verify real platform file creation and privacy/storage expectations on both
supported simulator/emulator targets.

- [x] Run the updated entry-list integration flow on Android emulator with the
      deterministic test writer override and record the command/evidence
- [x] Run a real Android writer smoke check on emulator: seed saved and draft
      entries, tap export, confirm success feedback, and verify a CSV appears
      under a Downloads/Wrait-style destination
- [x] Pull or inspect the Android CSV and verify headers, saved row, draft row,
      cleaned/raw text, timestamp fields, and absence of audio paths or secrets
- [x] Run the updated entry-list integration flow on iOS simulator with the
      deterministic test writer override and record the command/evidence
- [x] Run a real iOS writer smoke check on simulator: seed saved and draft
      entries, tap export, confirm success feedback, and verify the CSV appears
      under `Documents/Wrait Exports`
- [x] Inspect the iOS simulator app container and verify
      `wrait_entries.sqlite` and sidecar artifacts are not in Documents after
      migration
- [x] Pull or inspect the iOS CSV and verify headers, saved row, draft row,
      cleaned/raw text, timestamp fields, and absence of audio paths or secrets

### Group 8: Implementation Artifact

Capture what changed and the validation evidence before the external review
gate.

- [x] Create `specs/039-entry-export/implementation.md` with implementation
      details, key tradeoffs, migration behavior, and validation evidence
- [x] Update `specs/039-entry-export/tasks.md` with completed task checkboxes
      and validation evidence
- [x] Update `specs/039-entry-export/spec.md` status/history to reflect
      implementation progress after code and validation are complete

### Group 9: Review and Fix

Handle external review after implementation.

- [x] Stop and wait for external `review.md`, unless the user explicitly skips
      review
- [x] User explicitly skipped review for this pass before the post-implementation
      iOS migration removal
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any
      changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 10: Finalization

Handle durable documentation follow-up and closeout.

- [x] Decide whether the feature produced durable learnings or long-lived
      product/architecture changes worth preserving
- [x] Propose updates to `AGENTS.md`, `docs/application-description.md`, and
      `docs/agent-findings.md` if needed for the new export behavior, iOS
      database location, or platform validation guidance
- [x] Wait for explicit approval before editing any long-lived guidance
      documents
- [x] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision
- [x] Update `specs/039-entry-export/spec.md` status/history to Complete only
      after implementation, review handling, validation, and knowledge capture
      are finished

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, final knowledge-capture gate handled, and `spec.md` marked Complete.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
$ dart format lib/data/entries/entry_export_file_writer.dart lib/domain/service/entry_export_service.dart lib/data/entries/entry_export_providers.dart lib/data/entries/local_entry_database.dart lib/presentation/entries/entry_list_controller.dart lib/presentation/entries/entry_list_screen.dart test/domain/service/entry_export_service_test.dart test/data/entries/entry_export_file_writer_test.dart test/data/entries/local_entry_database_path_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart integration_test/entry_list_flow_test.dart
Formatted successfully.

$ flutter test test/domain/service/entry_export_service_test.dart test/data/entries/entry_export_file_writer_test.dart test/data/entries/local_entry_database_path_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart
All tests passed.

$ flutter test integration_test/entry_list_flow_test.dart
All tests passed.

$ flutter analyze
No issues found.

$ flutter test test/data/entries/local_entry_database_path_test.dart
All tests passed.

$ flutter test test/domain/service/entry_export_service_test.dart test/data/entries/entry_export_file_writer_test.dart test/presentation/entries/entry_list_screen_test.dart
All tests passed.

$ flutter analyze
No issues found.

$ flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart
All tests passed.

$ flutter test -d 4A181FDJH0030G integration_test/entry_list_flow_test.dart
All tests passed.

$ flutter test test/data/entries
All tests passed.

$ flutter test test/presentation/entries
All tests passed.

$ flutter test -d emulator-5554 integration_test/entry_list_flow_test.dart
All tests passed.

$ adb -s emulator-5554 shell cat /sdcard/Download/Wrait/wrait-entries-20260616-070000.csv
Verified headers plus saved/draft rows; no audio path column/value present.

$ flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart
All tests passed.

$ /opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/entry_list_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156
All tests passed. Application left running for container inspection.

$ /opt/homebrew/bin/flutter run -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --route=/entries --dart-define=APP_LOCK_ENABLED=false
Verified the normal bootstrap path and inspected the simulator data container:
- Documents contains only `Wrait Exports/wrait-entries-20260616-070000.csv`
- Library/Application Support contains `wrait_entries_v2.sqlite`
```

## Notes

- The task list follows the approved plan's choice to move the iOS encrypted
  database to Application Support before exposing user-visible CSV exports in
  Documents. The initial migration sub-plan was removed after the user
  confirmed there are no shipped iOS users and explicitly skipped review for
  this pass.
- No validation exception is currently approved or requested.
- The iOS bootstrap/runtime container verification used a normal `flutter run`
  because the integration harness intentionally overrides the database path to a
  temporary file.
- After the user explicitly skipped review for this pass, the follow-up removal
  of the iOS migration logic was revalidated with the database-path test and a
  clean `flutter analyze` run.
- The later external review focused on diagnostics, filename collisions,
  accessibility semantics, and platform-specific export-path edge cases rather
  than reinstating the intentionally removed iOS database migration logic.
- The knowledge-capture gate resulted in durable updates to `AGENTS.md`,
  `docs/application-description.md`, and `docs/agent-findings.md`.
