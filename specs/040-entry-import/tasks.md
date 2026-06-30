# Tasks: Entry Import

> **Feature number:** 040
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-30

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Import Contracts and Repository Insertion

Set up the additive persistence contract before parsing, platform, or UI work.

- [x] Add an additive `importEntries(List<Entry> entries)` method to the
      repository contract — `lib/domain/repository/entry_repository.dart`
- [x] Add transactional/batch insert support for imported entry records —
      `lib/data/entries/entry_dao.dart`
- [x] Implement repository import insertion that preserves imported metadata,
      validates supported language/type through existing rules, ignores
      imported ids, generates new ids, and always stores `audioPath` as null —
      `lib/data/entries/entry_repository_impl.dart`
- [x] Regenerate Drift output if DAO changes require generated updates —
      `lib/data/entries/local_entry_database.g.dart`
- [x] Update fake/test repository implementations to satisfy the new
      repository contract — `test/**`, `integration_test/**`

### Group 2: CSV Import Service

Implement the Wrait CSV contract and all-or-failure import behavior.

- [x] Create the import result model and import service —
      `lib/domain/service/entry_import_service.dart`
  - Depends on: Group 1
- [x] Parse CSV according to the Wrait export escaping rules, including quotes,
      commas, CRLF, embedded newlines, empty fields, and Unicode —
      `lib/domain/service/entry_import_service.dart`
- [x] Require the exact Wrait export header order from
      `EntryExportService.csvHeaders` —
      `lib/domain/service/entry_import_service.dart`
- [x] Validate every row before repository insertion, including `type`,
      `created_at`, `created_at_epoch_ms`, `language`, `word_count`, and column
      count — `lib/domain/service/entry_import_service.dart`
- [x] Map valid rows into new `Entry` values with ignored CSV ids, preserved
      timestamp/type/language/word count/raw transcript, empty `cleaned_text`
      mapped to null, and null `audioPath` —
      `lib/domain/service/entry_import_service.dart`
- [x] Return distinct success, empty, cancelled, and failure results without
      leaking implementation details to UI callers —
      `lib/domain/service/entry_import_service.dart`

### Group 3: Import File Reader and Providers

Add the Flutter-side file-selection boundary and Riverpod wiring.

- [x] Create `EntryImportFileReader`, selected-file result, cancellation
      handling, and sanitized exception type —
      `lib/data/entries/entry_import_file_reader.dart`
  - Depends on: Group 2
- [x] Implement the `wrait/entry_import` method-channel reader using
      `pickCsvImport` with no arguments —
      `lib/data/entries/entry_import_file_reader.dart`
- [x] Validate method-channel success response types and reject blank file
      names or blank CSV contents —
      `lib/data/entries/entry_import_file_reader.dart`
- [x] Add provider wiring for the import file reader and import service —
      `lib/data/entries/entry_import_providers.dart`

### Group 4: Native File Selection Bridges

Implement the runtime picker/read path without adding a file-picker dependency.

- [x] Add Android import channel constants and handler while preserving existing
      device-id, app-lock, export, and capture-protection behavior —
      `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
  - Depends on: Group 3
- [x] Implement Android document picker launch, selected URI handling, UTF-8
      content read, cancellation response, and generic platform errors —
      `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
- [x] Add iOS import channel registration while preserving existing device-id
      and export registration — `ios/Runner/AppDelegate.swift`
- [x] Create a retained iOS document picker delegate that reads selected UTF-8
      CSV contents, handles cancellation, and returns sanitized errors —
      `ios/Runner/AppDelegate.swift`

### Group 5: Entries Screen UI and Controller

Wire import into `/entries` while preserving existing list, export, deletion,
navigation, app-lock, and capture behavior.

- [x] Extend entry-list controller state with `isImporting` while preserving
      `isExporting` behavior — `lib/presentation/entries/entry_list_controller.dart`
  - Depends on: Groups 2 and 3
- [x] Add controller import command with duplicate-tap guard, cancellation
      handling, failure logging, and progress reset —
      `lib/presentation/entries/entry_list_controller.dart`
- [x] Add an import icon button on the entries screen beside the export action
      with stable key, tooltip, semantics label, disabled/progress state, and
      no text overflow — `lib/presentation/entries/entry_list_screen.dart`
- [x] Add success feedback showing how many records were imported, zero-record
      feedback for empty valid CSV, cancellation no-op, and generic failure
      feedback — `lib/presentation/entries/entry_list_screen.dart`
- [x] Confirm the existing export button, back button, delete gestures, empty
      state, and populated list layout remain usable after adding the import
      action — `lib/presentation/entries/entry_list_screen.dart`

### Group 6: Unit and Widget Tests

Add focused automated coverage for the new parser, persistence, boundary, and
UI behavior.

- [x] Add import service tests for saved and draft rows from Wrait CSV —
      `test/domain/service/entry_import_service_test.dart`
- [x] Add parser tests for quoted commas, quotes, CRLF, embedded newlines,
      empty cleaned text, and Unicode —
      `test/domain/service/entry_import_service_test.dart`
- [x] Add empty Wrait CSV import test with zero-record result —
      `test/domain/service/entry_import_service_test.dart`
- [x] Add repeated import test proving additive behavior —
      `test/domain/service/entry_import_service_test.dart`
- [x] Add malformed header, malformed row, unsupported type/language, bad
      timestamp, bad word count, and all-or-failure no-mutation tests —
      `test/domain/service/entry_import_service_test.dart`
- [x] Add repository tests proving imported rows preserve metadata, ignore CSV
      ids, generate new ids, set null `audioPath`, and insert transactionally —
      `test/data/entries/entry_repository_impl_test.dart`
- [x] Add method-channel reader tests for success, cancellation, invalid
      response types, blank values, and platform exceptions —
      `test/data/entries/entry_import_file_reader_test.dart`
- [x] Add entry-list controller tests for import success, empty import, cancel,
      failure, state reset, failure logging, and duplicate-tap prevention —
      `test/presentation/entries/entry_list_controller_test.dart`
- [x] Add entries-screen widget tests for import action presence, semantics,
      progress, success count, zero-record feedback, cancel no-op, failure
      feedback, and coexistence with export/delete/list behavior —
      `test/presentation/entries/entry_list_screen_test.dart`

### Group 7: Integration Flow Coverage

Cover every in-scope user flow from the plan through the entries screen with
deterministic provider overrides.

- [x] Add an import reader or service override to the entry-list integration
      harness — `integration_test/entry_list_flow_test.dart`
  - Depends on: Groups 2, 3, and 5
- [x] Add integration coverage for importing saved and draft Wrait CSV rows and
      rendering the added rows — `integration_test/entry_list_flow_test.dart`
- [x] Add integration coverage for importing an empty Wrait CSV without list
      mutation — `integration_test/entry_list_flow_test.dart`
- [x] Add integration coverage for re-importing the same Wrait CSV and showing
      additive rows — `integration_test/entry_list_flow_test.dart`
- [x] Add integration coverage for import failure leaving existing rows
      unchanged — `integration_test/entry_list_flow_test.dart`
- [x] Capture screenshots where useful for entries-screen import runtime
      evidence — `integration_test/entry_list_flow_test.dart`

### Group 8: Automated Validation

Run planned local validation and record command output under Validation
evidence.

- [x] Run Dart formatting for all touched Dart files
- [x] Run targeted import tests:
      `flutter test test/domain/service/entry_import_service_test.dart test/data/entries/entry_import_file_reader_test.dart test/data/entries/entry_repository_impl_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart`
- [x] Run targeted integration test on host if supported:
      `flutter test integration_test/entry_list_flow_test.dart`
- [x] Run Flutter analysis:
      `flutter analyze`
- [x] Run the broader relevant entry test set if targeted tests suggest shared
      behavior risk:
      `flutter test test/data/entries test/presentation/entries`
- [x] Record all validation commands, outputs, and any failures/fixes in the
      Validation evidence section

### Group 9: Android Emulator Runtime Verification

Verify the native Android picker path and additive behavior.

- [B] Prepare valid Wrait CSV and malformed CSV files in emulator-accessible
      storage — blocked by the lack of a repo-local automated path for driving
      the Android system document picker from the current Flutter test harness
  - Depends on: Groups 4, 5, and 8
- [x] Launch the app on Android emulator with app lock disabled or unlocked and
      navigate to `/entries`
- [B] Use the import action to select the valid Wrait CSV and verify saved and
      draft rows appear with preserved content and no existing rows edited or
      removed — blocked by the same system-picker automation gap; covered
      instead by integration flow tests plus a fresh Android rebuild
- [B] Re-import the same CSV and verify a second set of new rows appears —
      blocked by the same system-picker automation gap
- [B] Import the malformed/unsupported CSV and verify failure feedback with no
      list mutation — blocked by the same system-picker automation gap
- [x] Record Android emulator evidence in the Validation evidence section

### Group 10: iOS Simulator Runtime Verification

Verify the native iOS picker path and additive behavior.

- [B] Prepare valid Wrait CSV and malformed CSV files in simulator-accessible
      storage — blocked by the lack of a repo-local automated path for driving
      the iOS system document picker from the current Flutter test harness
  - Depends on: Groups 4, 5, and 8
- [x] Launch the app on iOS simulator with app lock disabled or unlocked and
      navigate to `/entries`
- [B] Use the import action to select the valid Wrait CSV and verify saved and
      draft rows appear with preserved content and no existing rows edited or
      removed — blocked by the same system-picker automation gap; covered
      instead by integration flow tests plus a fresh iOS rebuild
- [B] Re-import the same CSV and verify a second set of new rows appears —
      blocked by the same system-picker automation gap
- [B] Import the malformed/unsupported CSV and verify failure feedback with no
      list mutation — blocked by the same system-picker automation gap
- [x] Record iOS simulator evidence in the Validation evidence section

### Group 11: Implementation Artifact

Capture what changed and validation evidence before the external review gate.

- [x] Create `specs/040-entry-import/implementation.md` with implementation
      details, key tradeoffs, native picker behavior, draft-state handling, and
      validation evidence
- [x] Update `specs/040-entry-import/tasks.md` with completed task checkboxes
      and validation evidence
- [x] Update `specs/040-entry-import/spec.md` status/history to reflect
      implementation progress after code and validation are complete

### Group 12: Review and Fix

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

### Group 13: Finalization

Handle durable documentation follow-up and closeout.

- [x] Decide whether the feature produced durable learnings or long-lived
      product/architecture changes worth preserving
- [x] Propose updates to `AGENTS.md`, `docs/application-description.md`, and
      `docs/agent-findings.md` if needed for additive CSV import behavior,
      draft-state preservation, or native picker validation guidance
- [x] Wait for explicit approval before editing any long-lived guidance
      documents
- [x] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision
- [x] Update `specs/040-entry-import/spec.md` status/history to Complete only
      after implementation, review handling, validation, and knowledge capture
      are finished

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, final knowledge-capture gate handled, and `spec.md` marked Complete.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
$ dart format lib/domain/repository/entry_repository.dart lib/data/entries/entry_dao.dart lib/data/entries/entry_repository_impl.dart lib/data/entries/entry_import_file_reader.dart lib/data/entries/entry_import_providers.dart lib/domain/service/entry_import_service.dart lib/presentation/entries/entry_list_controller.dart lib/presentation/entries/entry_list_screen.dart test/domain/service/entry_import_service_test.dart test/data/entries/entry_import_file_reader_test.dart test/data/entries/entry_repository_impl_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart integration_test/entry_list_flow_test.dart test/presentation/main/main_recording_controller_test.dart integration_test/capture_prevention_flow_test.dart integration_test/branding_surfaces_flow_test.dart integration_test/main_screen_permission_flow_test.dart integration_test/main_screen_display_awake_flow_test.dart integration_test/app_lock_flow_test.dart test/presentation/entries/entry_detail_controller_test.dart test/presentation/main/main_screen_test.dart test/presentation/entries/entry_detail_screen_test.dart test/domain/usecase/cleanup_transcript_use_case_test.dart test/domain/usecase/retry_pending_drafts_use_case_test.dart test/app_smoke_test.dart test/bootstrap_app_test.dart test/core/router/app_router_test.dart
Formatted successfully.

$ flutter test test/domain/service/entry_import_service_test.dart test/data/entries/entry_import_file_reader_test.dart test/data/entries/entry_repository_impl_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart
All tests passed.

$ flutter test integration_test/entry_list_flow_test.dart
Failed because no supported mobile device was connected in the initial host attempt.

$ flutter analyze
No issues found.

$ flutter test test/data/entries test/presentation/entries
All tests passed.

$ flutter devices
Detected iPhone 17 simulator and Android emulator once they were booted.

$ flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart
All tests passed on iOS simulator.

$ flutter test -d emulator-5554 integration_test/entry_list_flow_test.dart
All tests passed on Android emulator.

$ dart format lib/domain/service/entry_import_service.dart lib/data/entries/entry_import_file_reader.dart lib/data/entries/entry_dao.dart lib/data/entries/entry_repository_impl.dart lib/presentation/entries/entry_list_screen.dart test/domain/service/entry_import_service_test.dart test/data/entries/entry_import_file_reader_test.dart test/data/entries/entry_repository_impl_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart integration_test/entry_list_flow_test.dart
Passed during review remediation.

$ flutter test test/domain/service/entry_import_service_test.dart test/data/entries/entry_import_file_reader_test.dart test/data/entries/entry_repository_impl_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart
Passed during review remediation.

$ flutter test test/data/entries test/presentation/entries
Passed during review remediation.

$ flutter analyze
No issues found after review remediation.

$ flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart
Passed again during review remediation after a fresh Xcode build.

$ flutter test -d emulator-5554 integration_test/entry_list_flow_test.dart
Passed again during review remediation after a fresh Gradle build.
```

## Notes

- No validation exceptions are approved or requested in the plan.
- Import remains additive-only: CSV ids are ignored and repeated imports create
  new rows.
- Draft rows remain drafts exactly as represented in the Wrait CSV.
- Review remediation added explicit import-size limits, field-size validation,
  explicit transactional insertion, and categorized user-facing import failure
  feedback.
- The knowledge-capture gate resulted in approved updates to `AGENTS.md`,
  `docs/application-description.md`, and `docs/agent-findings.md`.
- Direct native picker smoke testing with manually selected CSV files remains
  blocked in this environment because the current repo-local Flutter
  integration harness can rebuild and run the app on simulator/emulator but
  cannot automate the platform system document picker UI itself. The native
  picker bridge contract is still covered by method-channel unit tests and by
  fresh iOS/Android integration builds using the updated native bridge code.
