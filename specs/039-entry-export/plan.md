# Implementation Plan: Entry Export

> **Feature number:** 039
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-29

---

## Approach summary

Add an export action to the entries screen that generates a CSV snapshot from
the currently stored entries and writes it to an automatically selected
user-accessible destination. The export will be explicitly user-triggered,
single-flight in the UI, non-mutating, and independent from release deployment.
CSV generation will stay in Dart for deterministic tests. Platform file
placement will use a narrow native bridge so Android can write to Downloads
and iOS can write to an app-visible Documents export folder without exposing
the encrypted database as the export artifact.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Export trigger | Add an icon button on the entries screen toolbar area | The requested entry point is the entries screen. An icon button matches the existing back-button style and keeps the list focused on records. |
| Export source | Use the entry-list stream's current sorted entry list | The entries screen already represents saved and draft database entries. Reusing that source avoids a second repository contract for the same list and keeps export order predictable. |
| Export format | CSV with stable headers and RFC-style field escaping | The user requested CSV. A stable header row makes the file readable in spreadsheets and simple to validate. |
| CSV columns | `id`, `type`, `created_at`, `created_at_epoch_ms`, `language`, `word_count`, `raw_transcript`, `cleaned_text` | These columns cover the approved database-entry content and metadata while intentionally omitting audio files and local audio paths. |
| File name | `wrait-entries-YYYYMMDD-HHMMSS.csv` | The name identifies Wrait exports and keeps repeated exports distinguishable. |
| File writer abstraction | Dart `EntryExportFileWriter` interface with a platform-channel implementation | The export controller can be tested without platform IO, while runtime builds still create real user-accessible files. |
| Android destination | Public Downloads collection, preferably `Download/Wrait`, via a native MediaStore bridge | This satisfies the automatic downloads-style destination without broad storage permissions on modern Android. Older Android fallback can use app-specific external Documents if MediaStore Downloads is unavailable. |
| iOS destination | `Documents/Wrait Exports` with document sharing enabled while the encrypted database stays in Application Support | iOS has no automatic public Downloads folder for apps. Documents is the closest user-accessible local destination through Files/Finder, while Application Support keeps the raw encrypted database outside the user-visible export folder. |
| iOS database storage path | Use Application Support for the default iOS database location with no legacy migration path | There are no shipped iOS users yet, so adding migration logic only increases risk and code surface. |
| UI feedback | Show short success/failure SnackBars and disable export while a write is in progress | The user needs clear confirmation and failure reporting. Single-flight export prevents accidental duplicate writes. |
| Dependencies | No new Flutter package by default | Existing Dart IO, path utilities, Riverpod, and native platform APIs are sufficient. Avoiding a package reduces dependency and permission risk. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `specs/039-entry-export/spec.md` | Modify | Keep status/history aligned with the approved planning phase |
| `specs/039-entry-export/plan.md` | Modify | This implementation plan |
| `lib/domain/service/entry_export_service.dart` | Create | Export result model, CSV export service, file-name generation, and failure-safe orchestration |
| `lib/data/entries/entry_export_file_writer.dart` | Create | Platform file-writer abstraction and MethodChannel-backed implementation |
| `lib/data/entries/entry_export_providers.dart` | Create | Riverpod providers for export service, file writer, and clock/date source |
| `lib/data/entries/local_entry_database.dart` | Modify | Resolve the default iOS database path to Application Support without legacy migration logic |
| `lib/presentation/entries/entry_list_controller.dart` | Modify | Add export entry point that delegates to the export service without mutating entries |
| `lib/presentation/entries/entry_list_screen.dart` | Modify | Add export button, loading/disabled state, semantics, and SnackBar feedback |
| `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt` | Modify | Add `wrait/entry_export` MethodChannel handler that writes CSV to Android Downloads |
| `ios/Runner/AppDelegate.swift` | Modify | Add `wrait/entry_export` MethodChannel handler that writes CSV to the iOS export folder |
| `ios/Runner/Info.plist` | Modify | Enable user document visibility needed for the iOS export folder |
| `test/domain/service/entry_export_service_test.dart` | Create | CSV generation, escaping, all-entry coverage, empty export, failure, and non-mutation coverage |
| `test/data/entries/entry_export_file_writer_test.dart` | Create | Platform-channel writer contract tests with mocked channel responses and failures |
| `test/data/entries/local_entry_database_path_test.dart` | Create or modify | Coverage for iOS and non-iOS default database path resolution |
| `test/presentation/entries/entry_list_controller_test.dart` | Modify | Controller export success/failure delegation tests |
| `test/presentation/entries/entry_list_screen_test.dart` | Modify | Export button rendering, disabled/loading behavior, success/failure feedback, and empty-list export UI coverage |
| `integration_test/entry_list_flow_test.dart` | Modify | Add in-app export flow using a test writer override for stable cross-platform UI coverage |

## API contract details

This feature does not add backend HTTP APIs.

Internal platform-channel contract:

```text
channel: wrait/entry_export
method: writeCsvExport
arguments:
  fileName: String
  contents: String

success:
  pathLabel: String  // user-facing destination label
  fileName: String

failure:
  PlatformException with a generic code and non-sensitive message
```

The Dart service will validate that the generated file name and CSV contents
are non-empty before calling native code. Native errors will be converted into
generic export failure feedback; stack traces, filesystem internals, local DB
paths, and platform exception details must not be shown in the UI.

CSV contract:

```csv
id,type,created_at,created_at_epoch_ms,language,word_count,raw_transcript,cleaned_text
```

- `created_at` is ISO-8601 UTC text derived from the stored epoch milliseconds.
- `created_at_epoch_ms` preserves the exact stored timestamp value.
- `cleaned_text` is empty when absent.
- `audioPath` is intentionally omitted to avoid exporting draft audio files or
  local filesystem paths.
- Rows are exported in the same newest-first order used by the entries screen.

## Data model changes

No entry table fields are added, removed, or retyped. CSV is an export artifact,
not a new persisted app model.

### Before

```text
Entry:
  id
  type
  rawTranscript
  cleanedText?
  language
  createdAt
  wordCount
  audioPath?

iOS default database file:
  Application Documents/wrait_entries.sqlite
```

### After

```text
Entry:
  unchanged

Export CSV row:
  id
  type
  created_at
  created_at_epoch_ms
  language
  word_count
  raw_transcript
  cleaned_text

iOS default database file:
  Application Support/wrait_entries.sqlite

iOS export files:
  Application Documents/Wrait Exports/wrait-entries-YYYYMMDD-HHMMSS.csv
```

### Migration

- Android database location remains unchanged.
- iOS database open resolves the Application Support path directly.
- No legacy iOS migration path is implemented because there are no existing
  shipped iOS users to preserve.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| CSV export includes saved entries and drafts with stable headers | Unit | `test/domain/service/entry_export_service_test.dart` |
| CSV escaping handles commas, quotes, newlines, and empty cleaned text | Unit | `test/domain/service/entry_export_service_test.dart` |
| Audio draft row omits `audioPath` while preserving database metadata | Unit | `test/domain/service/entry_export_service_test.dart` |
| Empty-entry export creates a valid header-only CSV and success result | Unit | `test/domain/service/entry_export_service_test.dart` |
| File-writer failure returns a failure result and does not mutate entry input | Unit | `test/domain/service/entry_export_service_test.dart` |
| Platform writer sends the expected channel method and arguments | Unit | `test/data/entries/entry_export_file_writer_test.dart` |
| Platform writer surfaces generic failure on platform exception | Unit | `test/data/entries/entry_export_file_writer_test.dart` |
| iOS database path resolves to Application Support | Unit | `test/data/entries/local_entry_database_path_test.dart` |
| Entry-list controller delegates export success and failure | Unit | `test/presentation/entries/entry_list_controller_test.dart` |
| Entries screen exposes export semantics and disables export while running | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Entries screen shows success feedback with destination information | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Entries screen shows failure feedback and keeps rows visible | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Entries screen supports exporting from the empty state | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| User opens entries screen, taps export, and sees success feedback | Integration | `integration_test/entry_list_flow_test.dart` |

### Android emulator verification

1. Run the updated automated integration flow on Android emulator with an
   overridden test writer to verify the user flow consistently.
2. Run a runtime export smoke check with the real Android writer on an emulator:
   seed at least one saved entry and one draft, tap the entries-screen export
   button, and confirm success feedback.
3. Use `adb shell content` or `adb shell ls` where supported to confirm a CSV
   exists under a Downloads/Wrait-style destination and inspect/pull the file to
   verify headers, rows, saved entry content, draft content, and absence of
   audio paths.

### iOS simulator verification

1. Run the updated automated integration flow on iOS simulator with an
   overridden test writer to verify the user flow consistently.
2. Run a runtime export smoke check with the real iOS writer on a simulator:
   seed at least one saved entry and one draft, tap the entries-screen export
   button, and confirm success feedback.
3. Inspect the simulator app container to confirm the CSV exists under
   `Documents/Wrait Exports`, verify headers/content, and confirm the encrypted
   database file is stored under `Library/Application Support`.

### Validation exception request

No exception is requested at this planning stage. Automated integration
coverage plus Android emulator and iOS simulator runtime checks are planned.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require durable updates to `docs/application-description.md`
  and `docs/agent-findings.md` because it adds a user-visible data-export
  capability and clarifies the iOS split between user-visible exports in
  Documents and the encrypted database in Application Support. An `AGENTS.md`
  update may also be proposed if validation finds future-agent guidance is
  needed around export destinations or iOS Documents exposure.

## Integration notes

- The export feature integrates with the existing entries screen only; entry
  detail sharing remains unchanged.
- App lock stays above router content through the existing `AppLockGate`, so
  export remains behind the same lock as the entries screen.
- Android capture protection remains in `MainActivity`; adding another
  MethodChannel handler must preserve the existing device-id and app-lock
  handlers.
- iOS capture privacy remains in `SceneDelegate`; export channel setup belongs
  with existing app-level channel registration and must not change the native
  privacy cover.
- `deploy_release.sh` remains unchanged. Manual export is intentionally a user
  action before deployment, not a script pre-step.

## Rollout & migration

- No feature flag is planned; the export button appears once implemented.
- Existing Android app data remains in the current location and update behavior
  should be unchanged.
- Existing iOS rollout assumes no shipped users, so no database-location
  migration path is included.
- Export files are additive user artifacts. Re-running export creates a new CSV
  and does not overwrite older exports unless the platform destination somehow
  reports a filename conflict; the native writer should prefer a unique name.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| iOS Documents exposure reveals the encrypted database | Medium | High | Move iOS database artifacts to Application Support before relying on Documents for visible exports; validate the simulator container after migration. |
| iOS database migration loses or corrupts existing data | Low | High | Move only when new DB is absent, preserve old artifacts on failure, add focused migration tests, and include runtime verification. |
| Android Downloads write differs by API level | Medium | Medium | Use MediaStore on modern Android and a conservative app-specific external fallback for older versions; report failure clearly if no destination is available. |
| CSV fields break spreadsheet parsing when text contains commas/newlines | Medium | Medium | Centralize CSV escaping and test quotes, commas, CR/LF, empty values, and Unicode text. |
| Export accidentally includes local audio paths or secrets | Low | High | Use an explicit allow-list of CSV columns and tests asserting no `audioPath`, key, backend, or path fields are present. |
| Duplicate taps create multiple exports or inconsistent UI feedback | Medium | Low | Disable export while a write is in progress and test single-flight behavior. |
| Large local diaries jank the UI | Low | Medium | Keep export orchestration asynchronous and avoid per-row UI work during CSV generation. |

## Open items from spec

No open spec questions remain. The plan implements the recorded answers:

- Export all database entries.
- Do not export retained draft audio files.
- Use CSV.
- Select the destination automatically.
