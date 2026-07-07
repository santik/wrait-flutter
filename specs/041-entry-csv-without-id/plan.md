# Implementation Plan: Entry CSV Without Id

> **Feature number:** 041
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-30

---

## Approach summary

Revise the shared Wrait CSV contract in one pass so export stops writing the
database-only `id` field and the duplicate converted timestamp field, while
import accepts only that new reduced contract. The implementation stays scoped
to the existing export/import services, their tests, and the entries-screen
user flow. Persisted app data and database schema remain unchanged: the CSV
format changes, but import still creates additive rows from the remaining
fields and stores `created_at` exactly as the database integer value.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| CSV contract owner | Keep `EntryExportService.csvHeaders` as the single source of truth for the shared import/export header order | Export already defines the contract and import already validates against it. Updating one shared header list is the simplest way to keep both sides aligned. |
| `id` handling | Remove `id` from export output and from import parsing entirely | Import never persists CSV ids. Keeping the field only adds noise and implies false identity semantics. |
| Timestamp representation | Export a single `created_at` column containing the raw database integer value and import that same value directly, but reject values above a fixed supported ceiling | The user explicitly wants no timestamp conversion. One field matches the stored model and removes duplicate CSV data plus conversion logic, while a fixed ceiling prevents unreasonable future timestamps. |
| Database schema | No schema or migration change | The local database already stores a single integer `created_at`. Only the CSV artifact changes. |
| Compatibility | Do not support older Wrait CSV files that still include `id` or a second timestamp column | The user explicitly rejected backward compatibility. The simplest correct implementation is to switch the accepted contract fully. |
| Import validation | Keep exact-header validation and row-count checks against the new reduced contract | Exact validation keeps the feature simple and makes the compatibility break explicit. |
| Additive behavior | Preserve the existing repository import path and generated local ids | Removing CSV `id` does not change the persistence model. Existing additive insertion remains the right behavior. |
| UI placement | Keep import/export actions on `/entries` with no workflow redesign | The request is a contract simplification, not a screen redesign. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `specs/041-entry-csv-without-id/spec.md` | Modify | Approved spec for this contract revision |
| `specs/041-entry-csv-without-id/plan.md` | Modify | This implementation plan |
| `lib/domain/service/entry_export_service.dart` | Modify | Remove `id` and duplicate timestamp export columns; write raw `created_at` directly |
| `lib/domain/service/entry_import_service.dart` | Modify | Validate the new header shape, remove `id` parsing, and read `created_at` directly as the persisted value |
| `test/domain/service/entry_export_service_test.dart` | Modify | Update expected header/content coverage for the new no-id single-timestamp CSV contract |
| `test/domain/service/entry_import_service_test.dart` | Modify | Update happy-path and failure-path coverage for the new header and direct `created_at` parsing |
| `test/presentation/entries/entry_list_controller_test.dart` | Modify | Update helper CSV fixtures used by import flow tests |
| `test/presentation/entries/entry_list_screen_test.dart` | Modify | Update export/import CSV expectations and fixtures shown through the entries screen |
| `integration_test/entry_list_flow_test.dart` | Modify | Update deterministic import fixtures and export assertions to the new contract |
| `specs/041-entry-csv-without-id/tasks.md` | Later phase | Filled after plan approval |
| `specs/041-entry-csv-without-id/implementation.md` | Later phase | Created during implementation with validation evidence |

## API contract details

This feature does not add backend HTTP APIs.

The internal platform export/import channel surfaces stay the same. Only the
CSV payload shape changes.

CSV contract after this change:

```text
type,created_at,language,word_count,raw_transcript,cleaned_text
```

Rules:

- `type` must be `draft` or `saved`.
- `created_at` is the raw integer value stored in the local database column
  `created_at`.
- Export writes `created_at` exactly as stored, with no ISO conversion or
  duplicate epoch column.
- Import parses `created_at` directly as a non-negative integer, rejects values
  above the fixed supported maximum of `2100-01-01T00:00:00Z`
  (`4102444800000`), and persists accepted values unchanged into the local
  database through the existing additive import path.
- `language` must resolve through the existing supported-language rules.
- `word_count` must parse as a non-negative integer.
- `raw_transcript` and `cleaned_text` continue using the existing CSV escaping
  rules, and empty `cleaned_text` continues mapping to absent/null.
- Exact-header validation remains in place; older Wrait CSV files with `id` or
  a second timestamp column are unsupported.

## Data model changes

No database schema or persisted app-model change is planned.

### Before

```text
Local database row:
  id auto-increment
  raw_transcript text
  cleaned_text text nullable
  type text
  language text
  created_at integer
  word_count integer
  audio_path text nullable

CSV contract:
  id
  type
  created_at
  created_at_epoch_ms
  language
  word_count
  raw_transcript
  cleaned_text
```

### After

```text
Local database row:
  unchanged

CSV contract:
  type
  created_at
  language
  word_count
  raw_transcript
  cleaned_text
```

### Migration

No local-data migration is required.

Contract migration behavior:

- New exports use the reduced CSV shape immediately.
- Import supports only the new reduced shape.
- Older exported Wrait CSV files with `id` or `created_at_epoch_ms` are
  intentionally rejected.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Export writes the new header without `id` and without duplicate timestamp columns | Unit | `test/domain/service/entry_export_service_test.dart` |
| Export writes raw integer `created_at` values directly from entry data | Unit | `test/domain/service/entry_export_service_test.dart` |
| Export still escapes commas, quotes, CR/LF, empty cleaned text, and Unicode correctly | Unit | `test/domain/service/entry_export_service_test.dart` |
| Import accepts the new no-id single-timestamp Wrait CSV for saved and draft rows | Unit | `test/domain/service/entry_import_service_test.dart` |
| Import still remains additive and preserves type/language/word count/text values | Unit | `test/domain/service/entry_import_service_test.dart` |
| Import accepts zero and maximum supported `created_at` boundary values and rejects values above the supported maximum | Unit | `test/domain/service/entry_import_service_test.dart` |
| Import rejects the old header shape that still contains `id` or `created_at_epoch_ms` | Unit | `test/domain/service/entry_import_service_test.dart` |
| Import rejects data rows with extra columns beyond the reduced header | Unit | `test/domain/service/entry_import_service_test.dart` |
| Entries-screen export flow reflects the new CSV shape | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Entries-screen import flow still succeeds with the new CSV fixtures | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Controller import helpers continue working with the new CSV fixtures | Unit | `test/presentation/entries/entry_list_controller_test.dart` |
| Entries-screen integration flow exports/imports with the reduced CSV contract | Integration | `integration_test/entry_list_flow_test.dart` |

### Android emulator verification

1. Launch the app on Android emulator with app lock disabled or unlocked.
2. Navigate to `/entries`.
3. Run the entries export flow and verify the resulting CSV content uses the
   new header shape without `id` or `created_at_epoch_ms`.
4. Run the entries import flow using a valid CSV with the new shape and verify
   rows are added additively with preserved `type`, `created_at`, `language`,
   `word_count`, transcript text, and cleaned text.
5. Try importing a CSV with the old header shape and verify it fails clearly
   without mutating existing rows.

### iOS simulator verification

1. Launch the app on an iOS simulator with app lock disabled or unlocked.
2. Navigate to `/entries`.
3. Run the entries export flow and verify the resulting CSV content uses the
   new header shape without `id` or `created_at_epoch_ms`.
4. Run the entries import flow using a valid CSV with the new shape and verify
   rows are added additively with preserved `type`, `created_at`, `language`,
   `word_count`, transcript text, and cleaned text.
5. Try importing a CSV with the old header shape and verify it fails clearly
   without mutating existing rows.

### Validation exception request

None. The plan keeps the normal integration-test and dual-platform runtime
verification requirements.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require durable updates to `AGENTS.md`,
  `docs/application-description.md`, and `docs/agent-findings.md` because it
  changes the supported Wrait CSV contract and removes the prior `id` and
  duplicate timestamp guidance.

## Integration notes

- This change touches both export and import because they share the same CSV
  contract.
- The repository import path, native file picker path, native export writer
  path, app lock, capture privacy, and local database schema should remain
  behaviorally unchanged outside the CSV payload shape.
- The local database column named `created_at` already stores the integer value
  the user wants preserved. The plan intentionally avoids introducing a second
  timestamp representation anywhere in the CSV flow.

## Rollout & migration

- No feature flag is planned.
- No database migration is planned.
- The CSV contract changes immediately once this story ships.
- Older Wrait CSV exports with `id` and `created_at_epoch_ms` become unsupported
  by design.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Export and import drift apart after the header change | Medium | High | Keep one shared header source in `EntryExportService.csvHeaders` and update import tests against that exact list. |
| Raw integer `created_at` is less human-readable than the old dual-timestamp export | Medium | Low | Follow the explicit user requirement and keep the contract minimal; validate that the preserved value still round-trips correctly through import. |
| Old Wrait CSV files fail unexpectedly after the compatibility break | High | Medium | Keep exact-header validation and add explicit tests proving the old shape is rejected, so the break is deliberate rather than accidental. |
| Fixture churn hides a regression in entries-screen behavior | Medium | Medium | Update widget/integration fixtures carefully and retain the same user-flow assertions beyond the CSV shape itself. |

## Open items from spec

No open spec questions remain. The plan implements the recorded answers:

- No backward compatibility is required for older Wrait CSV files that still
  include `id`.
- `created_at` stays as the raw database value with no separate converted
  timestamp field and no import/export timestamp conversion.
