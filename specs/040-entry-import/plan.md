# Implementation Plan: Entry Import

> **Feature number:** 040
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-30

---

## Approach summary

Add a small, explicit CSV import path to the entries screen that mirrors the
existing export feature shape: platform file selection/reading at the data
boundary, CSV parsing and validation in a domain service, additive persistence
through the entry repository, and short snackbar feedback from the entries
screen. The implementation will accept only the Wrait export header contract,
apply explicit file and field size limits, parse the full file before writing
anything, then insert new rows in one repository operation so failures leave
existing entries unchanged.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Import format | Require exact Wrait export CSV headers from `EntryExportService.csvHeaders` | The spec limits import to Wrait-produced CSV. Exact headers are the simplest reliable boundary and avoid custom mapping. |
| CSV parser | Add a small parser in the import service for comma, quote, CRLF, and newline-in-field handling | No CSV dependency exists today, and adding a dependency for the app's own narrow CSV contract is unnecessary. The parser will still handle the CSV escaping produced by Wrait export. |
| Existing exported `id` | Ignore CSV `id` when creating rows | Import is additive. Reusing exported ids would create collisions or update semantics, both out of scope. |
| Creation time | Persist `created_at_epoch_ms` from the CSV row and validate it against the ISO `created_at` field when present | Preserves user-visible record metadata while keeping the database schema unchanged. |
| Draft state | Persist CSV `type` as-is (`draft` remains draft, `saved` remains saved) | Directly implements the approved clarification and avoids hidden conversion. |
| Cleaned text | Treat an empty `cleaned_text` CSV field as absent (`null`) | Wrait export writes absent cleaned text as an empty field. This preserves the current export/import contract without adding a new marker. |
| Audio paths | Always import with `audioPath = null` | Export intentionally omits audio files; import must not invent or restore retained audio. |
| Persistence | Add a narrow `importEntries(List<Entry>)` repository method that inserts rows in a database transaction | Existing save methods use the current clock and cannot preserve imported timestamps or word counts. A dedicated additive method avoids schema changes and keeps mutation behavior explicit. |
| Platform file access | Add `EntryImportFileReader` using a method channel plus small Android/iOS native pickers | The app has no file picker dependency. Native channel code keeps scope narrow and avoids network/dependency churn. |
| Import size limits | Enforce a 10 MB total import limit plus per-field byte caps at the native bridge and service layers | Keeps the first version simple while preventing oversized picker payloads and pathological row content from reaching persistence. |
| UI placement | Add an import icon button beside the existing export button on `/entries` | Matches the spec and keeps import/export actions discoverable in one entry-management surface. |
| State handling | Extend `EntryListControllerState` with `isImporting` and guard duplicate import taps | Reuses current export controller pattern and prevents concurrent import writes. |
| Failure feedback | Surface sanitized failure categories (`invalid format`, `unreadable file`, `too large`, `save failed`) instead of one generic import error | Preserves simple UI copy while giving users and validation clearer outcomes without exposing stack traces or file internals. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `specs/040-entry-import/spec.md` | Modify | Already marked approved for planning. |
| `lib/domain/repository/entry_repository.dart` | Modify | Add additive `importEntries(List<Entry> entries)` contract. |
| `lib/data/entries/entry_repository_impl.dart` | Modify | Validate supported language/type through existing helpers and insert imported entries without audio paths. |
| `lib/data/entries/entry_dao.dart` | Modify | Add transactional/batch insert support for imported entry companions. |
| `lib/data/entries/local_entry_database.g.dart` | Modify/generated | Regenerated if Drift output changes after DAO edits. |
| `lib/domain/service/entry_import_service.dart` | Create | Parse Wrait CSV, validate rows, call repository import, and return success/failure/count result. |
| `lib/data/entries/entry_import_file_reader.dart` | Create | Flutter boundary for selecting and reading a CSV import file through method channel. |
| `lib/data/entries/entry_import_providers.dart` | Create | Riverpod providers for import reader/service. |
| `lib/presentation/entries/entry_list_controller.dart` | Modify | Add import state and import command with warning logging on failure. |
| `lib/presentation/entries/entry_list_screen.dart` | Modify | Add entries-screen import button, progress state, and success/failure/empty feedback. |
| `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt` | Modify | Add `wrait/entry_import` channel and Android document picker/read handling. |
| `ios/Runner/AppDelegate.swift` | Modify | Register import channel and bridge to an inline retained iOS document picker helper. |
| `test/domain/service/entry_import_service_test.dart` | Create | Unit coverage for parsing, validation, additive import, repeated import, empty CSV, and failure without repository mutation. |
| `test/data/entries/entry_import_file_reader_test.dart` | Create | Method-channel boundary tests for argument/response validation and platform errors. |
| `test/data/entries/entry_repository_impl_test.dart` | Modify | Verify imported rows preserve metadata, ignore CSV ids, set `audioPath` null, and insert additively. |
| `test/presentation/entries/entry_list_controller_test.dart` | Modify | Cover import success, failure, state reset, and duplicate-tap guard. |
| `test/presentation/entries/entry_list_screen_test.dart` | Modify | Cover import button feedback, empty import feedback, failure feedback, and progress semantics. |
| `integration_test/entry_list_flow_test.dart` | Modify | Add provider-overridden import flow coverage for saved/draft imports, empty import, repeated import, and failure without mutation. |
| `specs/040-entry-import/tasks.md` | Later phase | Filled only after plan approval. |
| `specs/040-entry-import/implementation.md` | Later phase | Created during implementation with validation evidence. |

## API contract details

No backend HTTP contract changes.

Internal import contract:

- Method channel name: `wrait/entry_import`.
- Method: `pickCsvImport`.
- Flutter request: no arguments.
- Flutter success response:

```json
{
  "fileName": "string - selected file display name",
  "contents": "string - UTF-8 CSV contents"
}
```

- Flutter cancellation response: `null`, treated as no-op with no error snackbar.
- Platform or validation failure: service returns a categorized failure result;
  UI shows a short sanitized message without stack traces or file internals.
- Native bridges reject files above the 10 MB import size limit before handing
  contents back to Dart when file metadata or streamed read sizes exceed the
  cap.

CSV validation rules:

- Header must exactly match:

```text
id,type,created_at,created_at_epoch_ms,language,word_count,raw_transcript,cleaned_text
```

- `id` must be present but is ignored for insertion.
- `type` must be `draft` or `saved`.
- `created_at_epoch_ms` must parse as a non-negative integer timestamp.
- `created_at` must parse as an ISO timestamp and match `created_at_epoch_ms`
  after UTC conversion.
- `language` must resolve through the existing supported-language rules.
- `word_count` must parse as a non-negative integer and is preserved.
- `raw_transcript` and `cleaned_text` are imported from the CSV text fields;
  empty `cleaned_text` becomes absent.
- The service parses and validates every row before inserting any row.

## Data model changes

No schema change is planned.

### Before

```text
entries(
  id auto-increment,
  raw_transcript text,
  cleaned_text text nullable,
  type text check('draft', 'saved'),
  language text,
  created_at integer,
  word_count integer default 0,
  audio_path text nullable
)
```

### After

```text
No table or persisted field changes.
Imported rows use the same entries table with new auto-generated ids.
```

### Migration

No migration is required.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Parses Wrait-exported CSV with saved and draft rows, quoted commas, quotes, newlines, and Unicode | Unit | `test/domain/service/entry_import_service_test.dart` |
| Empty Wrait CSV imports zero records and reports an understandable empty result | Unit | `test/domain/service/entry_import_service_test.dart` |
| Re-importing the same valid CSV calls additive insert again and produces duplicate-looking new rows | Unit | `test/domain/service/entry_import_service_test.dart` |
| Malformed header, malformed row, unsupported type/language, bad timestamps, or bad word count fails before repository mutation | Unit | `test/domain/service/entry_import_service_test.dart` |
| Repository imported rows preserve type, created timestamp, language, word count, raw transcript, cleaned text, and null audio path with generated ids | Unit | `test/data/entries/entry_repository_impl_test.dart` |
| Method-channel import reader validates successful response, cancellation, invalid response types, blank contents, and preserved platform error codes | Unit | `test/data/entries/entry_import_file_reader_test.dart` |
| Entry-list controller handles import success/failure, resets progress state, and prevents concurrent imports | Unit | `test/presentation/entries/entry_list_controller_test.dart` |
| Entries screen shows import action, progress semantics, added-count feedback, zero-record feedback, cancellation no-op, and categorized failure feedback | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Entries-screen user flow imports saved and draft CSV rows through an overridden test reader/service and renders the added rows | Integration | `integration_test/entry_list_flow_test.dart` |
| Entries-screen user flow imports an empty Wrait CSV without changing the list | Integration | `integration_test/entry_list_flow_test.dart` |
| Entries-screen user flow re-imports the same Wrait CSV and shows additive rows | Integration | `integration_test/entry_list_flow_test.dart` |
| Entries-screen user flow handles import failure without changing existing rows | Integration | `integration_test/entry_list_flow_test.dart` |

### Android emulator verification

1. Launch the app on an Android emulator with app lock disabled or unlocked.
2. Navigate to `/entries`.
3. Use the import action to select a Wrait CSV from emulator-accessible storage.
4. Verify saved and draft records appear in the entries list with preserved
   metadata and no existing rows removed or edited.
5. Repeat import of the same file and verify a second set of new rows appears.
6. Try an unsupported/malformed CSV and verify failure feedback with no list
   mutation.

### iOS simulator verification

1. Launch the app on an iOS simulator with app lock disabled or unlocked.
2. Navigate to `/entries`.
3. Use the import action to select a Wrait CSV through the document picker.
4. Verify saved and draft records appear in the entries list with preserved
   metadata and no existing rows removed or edited.
5. Repeat import of the same file and verify a second set of new rows appears.
6. Try an unsupported/malformed CSV and verify failure feedback with no list
   mutation.

### Validation exception request

None. The plan includes integration-test coverage for the entries-screen import
flow using provider-overridden import readers/services, plus Android emulator
and iOS simulator runtime verification for the native picker path.

Review remediation note: if the system document picker cannot be driven through
the available simulator/emulator automation path in this environment, record
that blocker explicitly in `implementation.md` and rely on method-channel unit
coverage plus fresh iOS/Android integration builds for native bridge
regression evidence.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require durable updates after final approval:
  `docs/application-description.md` should mention manual CSV import, and
  `AGENTS.md` / `docs/agent-findings.md` may need concise guidance that Wrait
  CSV import is additive-only and preserves draft state as-is.

## Integration notes

- Import reuses the existing encrypted entry database and entry list stream.
- Import does not call backend services and does not alter device identity,
  quota, app-lock settings, export behavior, recording, transcription, cleanup,
  retry, sharing, or deletion.
- Imported draft rows may be considered drafts by existing draft retry/stale
  cleanup logic. Because the approved spec says draft rows remain drafts, this
  interaction will be noted in implementation evidence and validated with
  current behavior.

## Rollout & migration

No feature flag or data migration is planned. The change ships as a new manual
entries-screen action. Existing data remains readable and untouched. Imported
records receive new local auto-increment ids and can coexist with all existing
entries.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| CSV parser mishandles quoted fields from Wrait export | Medium | High | Unit-test commas, quotes, CRLF, embedded newlines, empty fields, and Unicode against the current export format. |
| Partial import occurs after a later row fails | Low | High | Parse and validate all rows before repository insertion; repository inserts in a transaction. |
| Imported drafts trigger existing retry/stale-draft behavior unexpectedly | Medium | Medium | Preserve draft state per spec, import without audio paths, and validate resulting list state. Document observed interaction in `implementation.md`. |
| Native file picker is flaky in automated integration tests | Medium | Medium | Cover Flutter user flow with provider overrides and verify native picker manually/on-device in Android emulator and iOS simulator runtime checks. |
| UI action cluster becomes cramped with back/export/import buttons | Medium | Low | Use compact icon buttons with stable keys, semantics, and tooltips; adjust positioning in widget tests for small surfaces. |
| Platform reader exposes file paths or details in user-facing errors | Low | Medium | Return generic failures to UI and log diagnostics only through existing internal warning logger. |

## Open items from spec

No open spec questions remain.
