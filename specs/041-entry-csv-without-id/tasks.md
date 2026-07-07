# Tasks: Entry CSV Without Id

> **Feature number:** 041
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

### Group 1: Shared CSV Contract Revision

Update the single source of truth for the Wrait CSV shape before touching
import/export behavior in tests or UI flows.

- [x] Revise the shared export/import header contract to:
      `type,created_at,language,word_count,raw_transcript,cleaned_text` —
      `lib/domain/service/entry_export_service.dart`
- [x] Remove `id` and `created_at_epoch_ms` from the documented/exported CSV
      row shape and keep `created_at` as the raw database value —
      `lib/domain/service/entry_export_service.dart`

### Group 2: Export Contract Update

Update export generation to emit the reduced CSV contract and preserve the
existing non-mutating behavior.

- [x] Remove `id` and duplicate timestamp emission from CSV export rows while
      preserving escaping, row order, and file naming —
      `lib/domain/service/entry_export_service.dart`
  - Depends on: Group 1
- [x] Update export unit tests for the new header shape, raw `created_at`
      values, and continued escaping/empty-state behavior —
      `test/domain/service/entry_export_service_test.dart`

### Group 3: Import Contract Update

Update import parsing and validation to accept only the new reduced Wrait CSV
shape.

- [x] Remove `id` parsing and duplicate timestamp validation from the import
      service and read `created_at` directly as the persisted integer value —
      `lib/domain/service/entry_import_service.dart`
  - Depends on: Group 1
- [x] Keep import additive behavior, supported-language/type checks, null
      `audioPath`, and existing failure categorization intact after the
      contract change — `lib/domain/service/entry_import_service.dart`
- [x] Update import service tests for the new no-id single-timestamp CSV
      contract, including rejection of the old header shape —
      `test/domain/service/entry_import_service_test.dart`

### Group 4: Entries Flow Fixture Updates

Bring controller, widget, and integration fixtures into alignment with the new
CSV contract.

- [x] Update controller-level import CSV helpers to the reduced contract —
      `test/presentation/entries/entry_list_controller_test.dart`
  - Depends on: Groups 2 and 3
- [x] Update entries-screen widget export expectations and import fixtures to
      the reduced contract — `test/presentation/entries/entry_list_screen_test.dart`
- [x] Update entries integration flow fixtures/assertions for export and import
      with the reduced contract — `integration_test/entry_list_flow_test.dart`

### Group 5: Automated Validation

Run planned local validation and record evidence.

- [x] Run Dart formatting for all touched Dart files
- [x] Run targeted CSV contract tests:
      `flutter test test/domain/service/entry_export_service_test.dart test/domain/service/entry_import_service_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart`
- [x] Run targeted integration coverage:
      `flutter test integration_test/entry_list_flow_test.dart`
- [x] Run Flutter analysis:
      `flutter analyze`
- [x] Run the broader relevant entry/UI test set if targeted runs suggest
      shared behavior risk:
      `flutter test test/data/entries test/presentation/entries`
- [x] Record commands, outcomes, and any fixes in the Validation evidence
      section

### Group 6: Android Emulator Verification

Verify the reduced CSV contract on Android emulator.

- [x] Launch the app on Android emulator with app lock disabled or unlocked and
      navigate to `/entries`
  - Depends on: Groups 2, 3, 4, and 5
- [x] Verify an entries export produces the new CSV header without `id` or
      `created_at_epoch_ms`
- [x] Verify importing a valid reduced-shape CSV adds rows additively with
      preserved `type`, `created_at`, `language`, `word_count`, and text
      content
- [x] Verify importing an old-shape CSV with `id` or `created_at_epoch_ms`
      fails without mutating existing rows
- [x] Record Android emulator evidence in the Validation evidence section

### Group 7: iOS Simulator Verification

Verify the reduced CSV contract on iOS simulator.

- [x] Launch the app on iOS simulator with app lock disabled or unlocked and
      navigate to `/entries`
  - Depends on: Groups 2, 3, 4, and 5
- [x] Verify an entries export produces the new CSV header without `id` or
      `created_at_epoch_ms`
- [x] Verify importing a valid reduced-shape CSV adds rows additively with
      preserved `type`, `created_at`, `language`, `word_count`, and text
      content
- [x] Verify importing an old-shape CSV with `id` or `created_at_epoch_ms`
      fails without mutating existing rows
- [x] Record iOS simulator evidence in the Validation evidence section

### Group 8: Implementation Artifact

Capture what changed and the validation evidence before the external review
gate.

- [x] Create `specs/041-entry-csv-without-id/implementation.md` with
      implementation details, compatibility-break notes, and validation
      evidence
- [x] Update `specs/041-entry-csv-without-id/tasks.md` with completed task
      checkboxes and validation evidence
- [x] Update `specs/041-entry-csv-without-id/spec.md` status/history to reflect
      implementation progress after code and validation are complete

### Group 9: Review and Fix

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

### Group 10: Finalization

Handle durable documentation follow-up and closeout.

- [x] Decide whether the feature produced durable learnings or long-lived
      product/architecture changes worth preserving
- [x] Propose updates to `AGENTS.md`, `docs/application-description.md`, and
      `docs/agent-findings.md` if needed for the reduced CSV contract and
      intentional compatibility break
- [x] Wait for explicit approval before editing any long-lived guidance
      documents
- [x] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision
- [x] Update `specs/041-entry-csv-without-id/spec.md` status/history to
      Complete only after implementation, review handling, validation, and
      knowledge capture are finished

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, final knowledge-capture gate handled, and `spec.md` marked Complete.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
$ dart format lib/domain/service/entry_export_service.dart lib/domain/service/entry_import_service.dart test/domain/service/entry_export_service_test.dart test/domain/service/entry_import_service_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart integration_test/entry_list_flow_test.dart
Formatted 7 files (0 changed) in 0.03 seconds.

$ flutter test test/domain/service/entry_export_service_test.dart test/domain/service/entry_import_service_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart
All tests passed.

$ flutter analyze
No issues found! (ran in 5.3s)

$ flutter test test/presentation/entries test/domain/service
All tests passed.

$ flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart
All 16 integration tests passed on iOS simulator, including:
- export header assertion for `type,created_at,language,word_count,raw_transcript,cleaned_text`
- additive valid import
- old-shape CSV rejection with no row mutation

$ flutter test -d emulator-5554 integration_test/entry_list_flow_test.dart
All 16 integration tests passed on Android emulator, including:
- export header assertion for `type,created_at,language,word_count,raw_transcript,cleaned_text`
- additive valid import
- old-shape CSV rejection with no row mutation

Note: one earlier Android emulator rerun ended with `Error waiting for a debug connection: The log reader stopped unexpectedly` before app assertions completed. A clean rerun passed without code changes, so this was recorded as transient runner instability rather than an app regression.

$ dart format lib/domain/service/entry_import_service.dart test/domain/service/entry_import_service_test.dart
Formatted 2 files (1 changed) in 0.02 seconds.

$ flutter test test/domain/service/entry_export_service_test.dart test/domain/service/entry_import_service_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart
All tests passed after review remediation, including new `created_at` boundary and extra-column cases.

$ flutter analyze
No issues found! (ran in 5.7s)

$ flutter test integration_test/entry_list_flow_test.dart
All 16 integration tests passed after review remediation.

$ flutter test -d emulator-5554 integration_test/entry_list_flow_test.dart
All 16 integration tests passed on Android emulator after review remediation.

$ flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart
All 16 integration tests passed on iOS simulator after review remediation.
```

## Notes

- This story intentionally changes the supported Wrait CSV contract and does
  not preserve compatibility with older CSV files that still include `id` or
  `created_at_epoch_ms`.
- The knowledge-capture gate resulted in approved updates to `AGENTS.md`,
  `docs/application-description.md`, and `docs/agent-findings.md` for the
  reduced six-column CSV contract and fixed `created_at` upper-bound rule.
