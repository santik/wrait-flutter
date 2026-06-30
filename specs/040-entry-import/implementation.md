# Implementation: Entry Import

> **Feature number:** 040
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-30

---

## Summary

Implemented additive CSV import for Wrait entry records on the entries screen.
The new flow accepts only the Wrait export CSV contract, parses and validates
the entire file before any insert, preserves imported record metadata and draft
state, ignores exported ids, and inserts new local rows without updating or
deleting existing entries. The post-review remediation also added explicit
import-size limits, explicit transactional insertion, and categorized failure
feedback without exposing raw diagnostics to the UI.

The entries screen now exposes both import and export actions. Import shows
progress, treats picker cancellation as a no-op, reports imported record
counts on success, and reports a short sanitized failure message for invalid
format, unreadable file, oversized file/content, or persistence failure.

## Key implementation details

### Repository and persistence

- Added `EntryRepository.importEntries(List<Entry> entries)` as an explicit
  additive persistence contract.
- Added batch insert support in `EntryDao`.
- Implemented import insertion in `EntryRepositoryImpl` with:
  - generated database ids instead of CSV ids
  - preserved `createdAt`, `language`, `wordCount`, `rawTranscript`,
    `cleanedText`, and `type`
  - forced `audioPath = null`
  - supported-language canonicalization through the existing resolver
- Review remediation wrapped the batch insert in an explicit Drift
  transaction and added a rollback test for mixed valid/invalid import rows.

### CSV parsing and validation

- Added `EntryImportService` with:
  - exact header validation against `EntryExportService.csvHeaders`
  - CSV parsing for commas, quotes, CRLF, embedded newlines, and Unicode
  - UTF-8 BOM acceptance on the first header cell and CR-only line-ending
    coverage
  - per-row validation for `id`, `type`, `created_at`,
    `created_at_epoch_ms`, `language`, and `word_count`
  - explicit 10 MB total import limit plus per-field byte limits for small
    metadata fields and transcript text fields
  - all-or-failure behavior: every row is parsed before repository insertion
  - categorized success, cancelled, and failure results for UI callers

### Platform boundary

- Added `EntryImportFileReader` and Riverpod providers for the import path.
- Added Android `wrait/entry_import` method-channel handling in
  [MainActivity.kt](/Users/alexander/projects/wrait/write-flutter/android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt)
  using `OpenDocument`, URI metadata lookup, streamed UTF-8 content reads,
  explicit size-limit rejection, stable MIME-type constants, and cancellation
  handling.
- Added iOS `wrait/entry_import` channel handling in
  [AppDelegate.swift](/Users/alexander/projects/wrait/write-flutter/ios/Runner/AppDelegate.swift)
  using `UIDocumentPickerViewController`, background-thread `Data` reads,
  security-scoped resource access, explicit size-limit rejection, and
  cancellation handling.

### Entries screen

- Extended `EntryListControllerState` with `isImporting`.
- Added `EntryListController.importEntries()` with duplicate-tap protection and
  warning logging on non-cancel failures.
- Added `entryListImportButton` beside export on `/entries`.
- Added import snackbar outcomes:
  - success: `Imported N record(s) from <file>.`
  - cancel: no snackbar
  - failure: sanitized category-specific copy such as invalid Wrait CSV,
    unreadable file, oversized import, or save failure

## Review remediation summary

Applied the approved review fixes without widening scope into a parser-package
swap or a larger picker-state redesign.

- Added explicit file and field size limits at both the Dart service layer and
  the native picker bridges.
- Removed redundant repository type validation and the duplicate DAO empty-list
  guard.
- Added categorized UI feedback while keeping stack traces and platform details
  out of user-facing snackbars.
- Added regression coverage for UTF-8 BOM headers, CR-only line endings,
  field-size limits, native file-too-large error propagation, and transactional
  rollback.

## Validation

### Automated

```text
$ dart format <touched files>
Formatted successfully.

$ flutter test test/domain/service/entry_import_service_test.dart test/data/entries/entry_import_file_reader_test.dart test/data/entries/entry_repository_impl_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart
All tests passed.

$ flutter analyze
No issues found.

$ flutter test test/data/entries test/presentation/entries
All tests passed.

$ dart format lib/domain/service/entry_import_service.dart lib/data/entries/entry_import_file_reader.dart lib/data/entries/entry_dao.dart lib/data/entries/entry_repository_impl.dart lib/presentation/entries/entry_list_screen.dart test/domain/service/entry_import_service_test.dart test/data/entries/entry_import_file_reader_test.dart test/data/entries/entry_repository_impl_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart integration_test/entry_list_flow_test.dart
Passed during review remediation.

$ flutter test test/domain/service/entry_import_service_test.dart test/data/entries/entry_import_file_reader_test.dart test/data/entries/entry_repository_impl_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart
All tests passed during review remediation.

$ flutter test test/data/entries test/presentation/entries
All tests passed during review remediation.

$ flutter analyze
No issues found after review remediation.
```

### Device integration

```text
$ flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart
All tests passed on iOS simulator.

$ flutter test -d emulator-5554 integration_test/entry_list_flow_test.dart
All tests passed on Android emulator.

$ flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart
All tests passed again during review remediation after a fresh Xcode build.

$ flutter test -d emulator-5554 integration_test/entry_list_flow_test.dart
All tests passed again during review remediation after a fresh Gradle build.
```

### Validation note

The direct native picker path was implemented on both platforms and the
Flutter-side method-channel boundary is covered by unit tests. Fresh iOS and
Android integration runs recompiled the updated native bridge code and
validated the end-to-end entries-screen import behavior using deterministic
import-reader overrides.

Direct system-picker smoke testing with manually selected CSV files remains
blocked in this environment: the current repo-local Flutter integration
harness can run on simulator/emulator but cannot automate the platform
document picker UI itself. That blocker is recorded explicitly rather than
claiming unverified native-picker interaction evidence.

## Files changed

- Import service and provider wiring:
  [entry_import_service.dart](/Users/alexander/projects/wrait/write-flutter/lib/domain/service/entry_import_service.dart),
  [entry_import_file_reader.dart](/Users/alexander/projects/wrait/write-flutter/lib/data/entries/entry_import_file_reader.dart),
  [entry_import_providers.dart](/Users/alexander/projects/wrait/write-flutter/lib/data/entries/entry_import_providers.dart)
- Repository contract and persistence:
  [entry_repository.dart](/Users/alexander/projects/wrait/write-flutter/lib/domain/repository/entry_repository.dart),
  [entry_dao.dart](/Users/alexander/projects/wrait/write-flutter/lib/data/entries/entry_dao.dart),
  [entry_repository_impl.dart](/Users/alexander/projects/wrait/write-flutter/lib/data/entries/entry_repository_impl.dart)
- Entries UI/controller:
  [entry_list_controller.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/entries/entry_list_controller.dart),
  [entry_list_screen.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/entries/entry_list_screen.dart)
- Native platform bridges:
  [MainActivity.kt](/Users/alexander/projects/wrait/write-flutter/android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt),
  [AppDelegate.swift](/Users/alexander/projects/wrait/write-flutter/ios/Runner/AppDelegate.swift)
- Automated coverage:
  [entry_import_service_test.dart](/Users/alexander/projects/wrait/write-flutter/test/domain/service/entry_import_service_test.dart),
  [entry_import_file_reader_test.dart](/Users/alexander/projects/wrait/write-flutter/test/data/entries/entry_import_file_reader_test.dart),
  [entry_repository_impl_test.dart](/Users/alexander/projects/wrait/write-flutter/test/data/entries/entry_repository_impl_test.dart),
  [entry_list_controller_test.dart](/Users/alexander/projects/wrait/write-flutter/test/presentation/entries/entry_list_controller_test.dart),
  [entry_list_screen_test.dart](/Users/alexander/projects/wrait/write-flutter/test/presentation/entries/entry_list_screen_test.dart),
  [entry_list_flow_test.dart](/Users/alexander/projects/wrait/write-flutter/integration_test/entry_list_flow_test.dart)
