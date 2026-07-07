# Implementation: Entry CSV Without Id

> **Feature number:** 041
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-30

---

## Summary

Updated the Wrait entry CSV contract to remove both the database-only `id`
field and the duplicate `created_at_epoch_ms` field. Export now writes the
reduced six-column shape:

```text
type,created_at,language,word_count,raw_transcript,cleaned_text
```

Import now accepts only that new shape, parses `created_at` directly as the
raw persisted integer value, and keeps the existing additive-only behavior.
Older Wrait CSV files that still include `id` or `created_at_epoch_ms` are now
rejected by design.

The approved review pass added a bounded `created_at` validation rule so the
reduced contract still rejects unreasonable future timestamps while preserving
the raw persisted integer model.

## Implementation details

### Shared CSV contract

- Updated
  [lib/domain/service/entry_export_service.dart](/Users/alexander/projects/wrait/write-flutter/lib/domain/service/entry_export_service.dart)
  so `csvHeaders` is now the reduced six-column contract.
- Export row generation no longer emits `entry.id` or any second timestamp
  representation.
- Export now writes `entry.createdAt.toString()` directly for `created_at`.

### Import parsing

- Updated
  [lib/domain/service/entry_import_service.dart](/Users/alexander/projects/wrait/write-flutter/lib/domain/service/entry_import_service.dart)
  to parse rows as:
  - `type`
  - `created_at`
  - `language`
  - `word_count`
  - `raw_transcript`
  - `cleaned_text`
- Removed CSV `id` parsing entirely.
- Removed duplicate timestamp validation and conversion logic.
- Added a maximum supported `created_at` ceiling of
  `2100-01-01T00:00:00Z` (`4102444800000`) to reject unreasonable future
  timestamps.
- Split invalid `created_at` handling into explicit empty, non-integer,
  negative, and above-maximum failures.
- Kept the existing additive repository import path, supported-language/type
  validation, null `audioPath`, and failure categorization unchanged.

### Test and fixture updates

- Updated export coverage in
  [test/domain/service/entry_export_service_test.dart](/Users/alexander/projects/wrait/write-flutter/test/domain/service/entry_export_service_test.dart)
  for the reduced header and raw integer `created_at`.
- Updated import coverage in
  [test/domain/service/entry_import_service_test.dart](/Users/alexander/projects/wrait/write-flutter/test/domain/service/entry_import_service_test.dart)
  for the new header, direct `created_at` parsing, and explicit rejection of
  the old Wrait header shape.
- Updated entries-screen CSV fixtures in
  [test/presentation/entries/entry_list_controller_test.dart](/Users/alexander/projects/wrait/write-flutter/test/presentation/entries/entry_list_controller_test.dart),
  [test/presentation/entries/entry_list_screen_test.dart](/Users/alexander/projects/wrait/write-flutter/test/presentation/entries/entry_list_screen_test.dart),
  and
  [integration_test/entry_list_flow_test.dart](/Users/alexander/projects/wrait/write-flutter/integration_test/entry_list_flow_test.dart).
- Added an integration assertion that on-device export starts with the exact
  reduced header and excludes both `id` and `created_at_epoch_ms`.
- Added an integration case proving old-shape CSV import fails without
  mutating existing rows.
- Added import tests for zero timestamp acceptance, maximum timestamp
  acceptance, above-maximum rejection, empty `created_at` rejection, and data
  rows with extra columns.

## Review remediation summary

Applied the approved review fixes without widening scope into timestamp
ordering rules, CSV versioning, or parser-library replacement.

- Added an upper bound for `created_at` values.
- Kept the bound deterministic with a fixed cutoff instead of a moving
  now-plus-N-years window.
- Added more specific `created_at` format errors while keeping the UI-level
  invalid-format feedback unchanged.
- Expanded focused import tests for timestamp boundaries and extra trailing
  columns.

## Compatibility note

This is an intentional compatibility break.

- New export files no longer include `id` or `created_at_epoch_ms`.
- Import no longer supports older Wrait CSV files that still include those
  columns.
- The local database schema is unchanged; `created_at` remains the existing
  integer value stored in the database.

## Validation evidence

### Formatting and analysis

```text
$ dart format lib/domain/service/entry_export_service.dart lib/domain/service/entry_import_service.dart test/domain/service/entry_export_service_test.dart test/domain/service/entry_import_service_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart integration_test/entry_list_flow_test.dart
Formatted 7 files (0 changed) in 0.03 seconds.

$ flutter analyze
No issues found! (ran in 5.3s)
```

### Focused automated tests

```text
$ flutter test test/domain/service/entry_export_service_test.dart test/domain/service/entry_import_service_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart
All tests passed.

$ flutter test test/presentation/entries test/domain/service
All tests passed.
```

### Device integration

```text
$ flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart
All 16 integration tests passed on iOS simulator.

$ flutter test -d emulator-5554 integration_test/entry_list_flow_test.dart
All 16 integration tests passed on Android emulator.
```

The simulator/emulator integration flow now explicitly verifies:

- export header equals
  `type,created_at,language,word_count,raw_transcript,cleaned_text`
- export excludes `id` and `created_at_epoch_ms`
- valid reduced-shape import stays additive
- old-shape CSV import is rejected without mutating existing rows

### Validation note

Direct manual automation of the native document picker UI is still outside the
current repo-local integration harness. Import validation on iOS simulator and
Android emulator therefore runs through deterministic test-reader overrides at
the entries-screen layer, while export validation covers both the captured CSV
content path and a real on-device export-writer completion path.

One intermediate Android emulator rerun ended with
`Error waiting for a debug connection: The log reader stopped unexpectedly`
before assertions completed. A clean rerun passed without any code change, so
this was treated as transient test-runner instability rather than an app-side
failure.

## Knowledge capture

The final knowledge-capture gate resulted in approved durable updates to:

- [AGENTS.md](/Users/alexander/projects/wrait/write-flutter/AGENTS.md)
- [docs/application-description.md](/Users/alexander/projects/wrait/write-flutter/docs/application-description.md)
- [docs/agent-findings.md](/Users/alexander/projects/wrait/write-flutter/docs/agent-findings.md)

Those updates record the reduced six-column CSV contract, the intentional
rejection of older `id` / `created_at_epoch_ms` CSV shapes, and the fixed
upper bound for imported `created_at` values.

### Review remediation reruns

```text
$ dart format lib/domain/service/entry_import_service.dart test/domain/service/entry_import_service_test.dart
Formatted 2 files (1 changed) in 0.02 seconds.

$ flutter test test/domain/service/entry_export_service_test.dart test/domain/service/entry_import_service_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart
All tests passed after review remediation.

$ flutter analyze
No issues found! (ran in 5.7s)

$ flutter test integration_test/entry_list_flow_test.dart
All 16 integration tests passed after review remediation.

$ flutter test -d emulator-5554 integration_test/entry_list_flow_test.dart
All 16 integration tests passed on Android emulator after review remediation.

$ flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart
All 16 integration tests passed on iOS simulator after review remediation.
```
