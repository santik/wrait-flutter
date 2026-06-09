# Implementation Plan: Encrypted Local Entry Store

> **Feature number:** 003
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-08

---

## Approach summary

Implement the first Flutter entry persistence layer with `drift` on top of
`SQLite3MultipleCiphers`, using a small repository/data-source stack in
`lib/data` plus a domain-facing entry model and repository contract in
`lib/domain`. The database will store the approved entry fields in a single
encrypted `entries` table, unlock itself with random secret material retained in
platform-protected storage, and expose reactive newest-first entry updates
through Drift’s watched queries instead of manual refresh broadcasting. App
startup will initialize the store and run stale-draft cleanup before the rest
of the app relies on pending drafts. This satisfies the approved spec by
providing protected at-rest storage, CRUD and draft-finalization flows, both
reactive and one-time entry reads, and automatic deletion of stale drafts plus
their audio files, while avoiding a long-term architecture centered on
`sqflite_sqlcipher` and its current iOS CocoaPods dependency path.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Database implementation | Use `drift` with `SQLite3MultipleCiphers` as the target persistence architecture | This gives the project a stronger long-term local persistence foundation, built-in reactive queries, clearer schema/DAO structure, and avoids centering future architecture on `sqflite_sqlcipher` while its iOS path still depends on CocoaPods. |
| Secret storage | Generate one random database key on first use and store it in `flutter_secure_storage` | This matches the approved story intent and existing project dependencies, and keeps encryption-key lifecycle separate from the database file itself. |
| Key-loss behavior | If the protected key is missing or invalid for an existing database file, treat the previous store as unrecoverable and recreate a fresh empty encrypted database | This preserves the spec’s “unrecoverable by design” requirement while keeping the app usable instead of failing permanently at startup. |
| Schema shape | Start with a single `entries` table at schema version 1 containing the approved fields | The Flutter client has no prior persisted entry data, so a minimal initial schema is sufficient and avoids premature migrations. |
| Data-layer structure | Keep Drift table definitions, DAOs, database opening, and repository implementation in `lib/data`, with only the entry model and repository contract in `lib/domain` | This follows the layer split established in US-001 and keeps persistence details out of the domain layer while still giving the data layer strong typed schema ownership. |
| Reactive updates | Use Drift watched queries for the newest-first entry list and entry-by-id streams | Drift provides built-in query reactivity, which is simpler and less error-prone than hand-managed stream refresh logic. |
| Reactive single-entry reads | Provide both a watched query for entry-by-id and a one-time direct query for current state | This satisfies the clarified requirement cleanly using Drift’s native APIs instead of deriving one from the other. |
| Time source | Introduce a small injectable clock/time provider for timestamps and stale-draft cutoff calculations | This keeps cleanup and created-at behavior deterministic in tests without hard-coding `DateTime.now()` into repository logic. |
| Startup cleanup trigger | Initialize the local entry store and run stale-draft cleanup during app startup before `runApp` | The spec requires cleanup on app launch before pending drafts are relied on, and startup initialization is the clearest place to guarantee that ordering. |
| Audio-file cleanup policy | Delete audio files referenced by stale drafts or explicitly deleted entries on a best-effort basis after database deletion succeeds | This matches the clarified spec and Android behavior while avoiding rollback complexity for file-system cleanup failures. |
| `sqflite_sqlcipher` posture | Do not build the long-term persistence architecture around `sqflite_sqlcipher`; reevaluate its role only in future US-003 refinement if needed | The repo findings already note the fragile iOS CocoaPods path. This story should target the more durable architecture now instead of entrenching that dependency further. |
| Validation approach | Prefer unit and repository-level integration tests over UI tests for this story | The feature is data-layer heavy, so most confidence should come from repository/database tests rather than placeholder-screen behavior. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `pubspec.yaml` | Modify | Add Drift, build/codegen support, and the encrypted SQLite runtime packages needed by the target architecture; reevaluate whether `sqflite_sqlcipher` remains necessary after implementation |
| `lib/main.dart` | Modify | Make startup async, initialize Flutter bindings, create the bootstrap provider container, and run stale-draft cleanup before launching the app |
| `lib/core/time/system_clock.dart` | Create | Small clock abstraction for current time access used by the repository and tests |
| `lib/domain/model/entry.dart` | Create | Domain entry model containing the approved fields |
| `lib/domain/repository/entry_repository.dart` | Create | Domain-facing repository contract for reactive reads, one-time reads, CRUD, draft operations, and stale-draft cleanup |
| `lib/data/entries/local_entry_database.dart` | Create | Drift database, encrypted connection setup, schema definition, and migration/version handling |
| `lib/data/entries/entry_dao.dart` | Create | Drift DAO queries for list, single-entry, insert, update, delete, and stale-draft operations |
| `lib/data/entries/entry_mapper.dart` | Create | Mapping helpers between Drift row models and the domain `Entry` model |
| `lib/data/entries/database_key_store.dart` | Create | Secure-storage wrapper responsible for reading or generating the persisted database key |
| `lib/data/entries/entry_repository_impl.dart` | Create | Concrete repository implementation for SQL operations, reactive refresh, timestamps, and audio-file cleanup |
| `lib/data/entries/entry_providers.dart` | Create | Riverpod providers for secure storage, clock, database bootstrap, and repository access |
| `lib/data/entries/local_entry_database.g.dart` | Generate | Drift-generated table and DAO support code produced from the source database definition |
| `test/data/entries/entry_repository_impl_test.dart` | Create | Repository-focused tests covering CRUD, draft finalization, reactive updates, single-entry access, and stale-draft cleanup |
| `test/data/entries/entry_database_test.dart` | Create | Lower-level tests for encrypted database creation, schema initialization, and key-loss recovery behavior if repository tests alone are not enough |
| `test/test_doubles/fake_secure_storage.dart` | Create | In-memory fake for secure storage interactions during tests |
| `test/test_doubles/fake_clock.dart` | Create | Controllable clock for created-at and stale-draft cutoff tests |

## API contract details

No HTTP endpoints are implemented or changed in US-003.

The implementation-specific contract is internal to the Flutter client:

- Repository operations:
  - reactive newest-first list of entries
  - reactive entry-by-id lookup
  - one-time entry-by-id lookup
  - insert/save operations for completed entries and drafts
  - draft transcript updates
  - draft finalization
  - language updates
  - single-entry deletion
  - pending-draft listing
  - stale-draft cleanup
- Startup behavior:
  - open or create the encrypted local store
  - ensure a key exists in protected storage
  - remove stale drafts older than 7 days before normal app use
- Failure behavior:
  - missing/invalid key for an existing database recreates a fresh empty store
  - mutation operations against missing entries fail clearly
  - file cleanup remains best-effort and must not corrupt database state

## Data model changes

This story introduces the first persisted entry data model for the Flutter app.

### Before

```dart
// No Flutter entry persistence model or local entry database exists yet.
```

### After

```dart
class Entry {
  final int id;
  final String rawTranscript;
  final String? cleanedText;
  final bool isDraft;
  final String language; // supported BCP-47 code
  final int createdAt; // epoch milliseconds
  final int wordCount;
  final String? audioPath;
}
```

Database table:

```sql
CREATE TABLE entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  raw_transcript TEXT NOT NULL,
  cleaned_text TEXT,
  is_draft INTEGER NOT NULL,
  language TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  word_count INTEGER NOT NULL DEFAULT 0,
  audio_path TEXT
);
```

### Migration

No migration is required because the Flutter client does not yet persist entry
data. This will be schema version 1 for the Flutter local store.

## Test strategy

Validation will focus on proving the repository contract, Drift-backed
encryption bootstrap, and cleanup behavior rather than adding temporary UI.
Implementation should be completed first, then automated tests should verify
the protected store and repository behaviors end to end. Manual verification
will confirm the encrypted database file exists and is unreadable without the
stored key, and that startup cleanup occurs on real app launch.

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Creating the repository with no prior key generates and persists a database key | Unit | `test/data/entries/entry_database_test.dart` or `test/data/entries/entry_repository_impl_test.dart` |
| Opening the local store creates the Drift-managed `entries` table with the approved schema | Integration | `test/data/entries/entry_database_test.dart` |
| Saving a completed entry returns an ID and the entry appears in newest-first list results | Integration | `test/data/entries/entry_repository_impl_test.dart` |
| Saving a text draft stores `isDraft = true` and preserves transcript and language | Integration | `test/data/entries/entry_repository_impl_test.dart` |
| Saving an audio draft stores empty transcript, zero word count, and the provided audio path | Integration | `test/data/entries/entry_repository_impl_test.dart` |
| Updating cleaned text finalizes a draft and clears any audio-path reference | Integration | `test/data/entries/entry_repository_impl_test.dart` |
| Updating a draft transcript refreshes the reactive list and preserves draft state | Integration | `test/data/entries/entry_repository_impl_test.dart` |
| Finalizing a draft with raw transcript plus cleaned text refreshes reactive observers correctly | Integration | `test/data/entries/entry_repository_impl_test.dart` |
| Updating entry language persists the supported BCP-47 code and is visible from both reactive and one-time reads | Integration | `test/data/entries/entry_repository_impl_test.dart` |
| Deleting an entry removes it from both the database and reactive observers | Integration | `test/data/entries/entry_repository_impl_test.dart` |
| Reactive entry-by-id updates when the target entry changes | Integration | `test/data/entries/entry_repository_impl_test.dart` |
| One-time entry lookup returns the current value or null when missing | Integration | `test/data/entries/entry_repository_impl_test.dart` |
| `getPendingDrafts()` returns only draft entries | Integration | `test/data/entries/entry_repository_impl_test.dart` |
| `deleteStaleDrafts()` removes only drafts older than the cutoff and leaves newer drafts intact | Integration | `test/data/entries/entry_repository_impl_test.dart` |
| `deleteStaleDrafts()` also removes referenced audio files on a best-effort basis | Integration | `test/data/entries/entry_repository_impl_test.dart` |
| Recreating the store after simulated key loss produces an empty usable database instead of exposing unreadable prior data | Integration | `test/data/entries/entry_database_test.dart` |
| App startup bootstraps the encrypted store and triggers stale-draft cleanup before normal app use continues | Integration | `test/data/entries/entry_database_test.dart` or dedicated startup/bootstrap test |
| `flutter analyze` completes with zero warnings after the data-layer changes | Static analysis | N/A command evidence recorded in `tasks.md` |
| `flutter test` passes for the new repository/database coverage | Automated suite | N/A command evidence recorded in `tasks.md` |

### Manual verification

1. Complete the repository, encrypted database, and startup bootstrap implementation.
2. Run `flutter analyze` and confirm there are no warnings.
3. Run `flutter test` and confirm the repository/database tests pass.
4. Launch the app once on Android and verify the app still boots successfully after startup initialization.
5. Inspect the app database location on a development device or simulator and confirm the database file exists.
6. Verify the database contents are not readable as plain-text journal content without opening through the app’s stored key path.
7. Create sample entries through a debug harness or test-only invocation if needed, relaunch the app, and confirm persisted data remains available.
8. Simulate or force stale drafts older than 7 days, relaunch the app, and confirm those drafts and their referenced audio files are removed.

## Integration notes

- This story introduces the first non-UI domain and data modules under the layer split established in [lib](/Users/alexander/projects/wrait/write-flutter/lib).
- Riverpod is already available, so repository/bootstrap dependencies can be surfaced through providers for future UI and service stories.
- `flutter_secure_storage` will be used only for the database key in this story. User preferences remain out of scope for US-003 and belong to US-004.
- `sqflite_sqlcipher` already has iOS CocoaPods implications noted in [docs/agent-findings.md](/Users/alexander/projects/wrait/write-flutter/docs/agent-findings.md); this plan avoids building the long-term persistence architecture around it and instead targets Drift plus `SQLite3MultipleCiphers`.
- Drift code generation becomes part of the development workflow for this story, so generated artifacts need to stay in sync with schema changes.
- No route, theme, or backend API changes are required for the core persistence behavior, though startup wiring in `main.dart` will change.

## Rollout & migration

This is the first entry-storage implementation for the Flutter client.

- No feature flags are needed.
- No user-data migration is required.
- Backward compatibility risk is low because no existing Flutter feature depends on local entry persistence yet.
- The main rollout sensitivity is startup initialization: if database bootstrap is wrong, the app could fail to launch. Tests and manual launch verification should specifically cover that path.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Drift encrypted-database setup differs subtly across Android and iOS | Medium | High | Keep the implementation close to the chosen runtime package contract, verify the bootstrap path with repository/database tests, and manually verify launch on both platforms after tests pass |
| Drift code generation or generated-file drift causes broken builds | Medium | Medium | Keep the generated file in the file plan, regenerate it as part of implementation, and validate with `flutter analyze` plus `flutter test` |
| Key-loss recovery accidentally leaves the app unable to open the database | Medium | High | Cover the recovery path with dedicated tests and keep the recovery behavior simple: remove unusable store and recreate it |
| Best-effort audio-file deletion could hide filesystem cleanup failures | Medium | Medium | Keep file deletion side effects isolated, do not let them block database correctness, and validate the expected success case in tests |
| Startup cleanup adds launch-time failure or delay | Low | Medium | Limit startup work to database open plus one cleanup call, and verify the app still launches normally in manual checks |
| Tests become flaky because timestamps depend on wall-clock time | Medium | Medium | Use an injectable fake clock for repository and cleanup tests |

## Open items from spec

None.
