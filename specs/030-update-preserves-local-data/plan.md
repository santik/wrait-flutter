# Implementation Plan: App Updates Preserve Local Data

> **Feature number:** 030
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-19

---

## Approach summary

Keep the app's existing same-identity update behavior simple: do not move user
data, do not add a backup/restore layer, and do not add a user-facing migration
flow. The implementation will remove the current silent database replacement
path when an existing encrypted database fails to open, because that can turn a
bad key, corrupt file, or unsupported migration into apparent data loss. An
existing database open failure will surface through the current bootstrap error
screen instead. Android will explicitly opt out of app backup/restore so a
normal uninstall/reinstall cannot restore the removed database. Existing app
container behavior covers normal update persistence and normal uninstall
removal on both Android and iOS; tests and platform verification will prove
those lifecycle paths.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Update persistence | Preserve the current database file, secure database key, shared preferences, and draft audio file locations across same-identity installs | App updates preserve the app container and key/value stores on Android and iOS. Keeping the existing locations is the smallest correct change and avoids migration risk. |
| Existing database open failure | Fail startup with the existing simple bootstrap error instead of deleting the existing database and retrying | The current retry path can silently replace a user's diary after key loss or corruption. The spec requires an understandable error rather than silent empty-database replacement. |
| Fresh install behavior | Let first launch create a new database when no database file exists | This preserves normal new-install behavior and keeps reinstall after uninstall fresh because the platform removes the app data container. |
| Android uninstall/reinstall restore prevention | Set Android backup behavior to disabled for the app | Android backup/restore can otherwise bring app data back after reinstall. Disabling backup aligns with the existing privacy requirement and the spec's fresh reinstall requirement. |
| iOS uninstall behavior | Rely on normal iOS app-container removal for database and linked files; allow platform device identity reuse | The database and temporary draft audio files are app-container data and are removed by normal uninstall. The spec allows anonymous device identity reuse after reinstall as long as old diary data is not restored. |
| Draft audio lifecycle | Keep live/draft recording files in the app temporary directory and keep database `audioPath` references unchanged across updates | Recording paths are already app-owned. Same-container updates preserve them; uninstall/clear-data removes them with app data. |
| Preferences lifecycle | Preserve current shared preferences across updates; treat currently implemented `hasEverRecorded` and `app_device_id` as the concrete preference state | Selected language and privacy mode are not implemented yet. The plan preserves the shared-preferences store so future preference keys inherit the same lifecycle behavior. |
| Database schema | No schema version change planned | The current table shape already contains the fields named in the spec. The behavior change is open-failure handling, not a data model migration. |
| Validation | Add lifecycle integration coverage plus unit tests for database-open failure and Android backup config | The riskiest regression is silent data replacement. Unit tests catch that directly; integration/runtime checks prove app-level lifecycle behavior on both platforms. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `lib/data/entries/local_entry_database.dart` | Modify | Remove automatic deletion/retry for existing database open failures; keep fresh database creation behavior unchanged. |
| `android/app/src/main/AndroidManifest.xml` | Modify | Explicitly disable Android app backup/restore for the Flutter app. |
| `test/data/entries/entry_database_test.dart` | Modify | Replace the key-loss recovery expectation with failure-without-deletion coverage, and add focused reopen/persistence checks where needed. |
| `test/platform/android_manifest_data_lifecycle_test.dart` | Create | Assert the manifest disables app backup so reinstall cannot restore the database through Android backup. |
| `integration_test/local_data_lifecycle_flow_test.dart` | Create | Cover same-storage update simulation, draft audio preservation, preference/device-id preservation, and fresh-state behavior after data removal. |
| `specs/030-update-preserves-local-data/tasks.md` | Modify later | Replace the copied template with the approved task checklist in the next SDD phase. |
| `specs/030-update-preserves-local-data/implementation.md` | Create later | Record implementation details and validation evidence during implementation. |

No generated Drift file change is planned because the schema is unchanged.

## API contract details

No backend HTTP contract changes are required.

Application-facing lifecycle contract:

- `LocalEntryDatabase.open` creates a usable encrypted database when no database
  exists.
- `LocalEntryDatabase.open` opens an existing encrypted database with its stored
  key and preserves all rows.
- `LocalEntryDatabase.open` does not delete an existing database file, WAL,
  SHM, or journal file as recovery from an open failure.
- Existing database open failures propagate to app bootstrap, which shows the
  existing simple error screen: `could not open wrait` / `try again`.
- Same-identity app installs over an existing installation must not clear the
  database, draft audio files, shared preferences, or locally stored device id.
- Fresh installs after uninstall or clear-data may create a new device id, or
  may reuse a stable platform-provided identity, but must not restore old diary
  entries.

Platform lifecycle contract:

- Android app backup/restore is disabled for this app identity.
- Android update validation uses a replace install for the same package id:
  `com.wrait.flutter`.
- Android fresh-state validation uses both app data clearing and uninstall/
  reinstall.
- iOS update validation uses a same-bundle install over the existing simulator
  app.
- iOS fresh-state validation uses simulator uninstall/reinstall.

## Data model changes

No persistent schema change is planned.

### Before

```text
Entry {
  id: int
  rawTranscript: String
  cleanedText: String?
  isDraft: bool
  language: String
  createdAt: int
  wordCount: int
  audioPath: String?
}

Preferences currently implemented:
  has_ever_recorded: bool?
  app_device_id: String?

Database open behavior:
  if existing encrypted database open fails:
    delete database artifacts
    retry with the current key
```

### After

```text
Entry {
  id: int
  rawTranscript: String
  cleanedText: String?
  isDraft: bool
  language: String
  createdAt: int
  wordCount: int
  audioPath: String?
}

Preferences currently implemented:
  has_ever_recorded: bool?
  app_device_id: String?

Database open behavior:
  if existing encrypted database open fails:
    propagate the failure
    leave database artifacts untouched
```

### Migration

No schema migration is required. Existing version-1 databases remain version 1.
The implementation changes failure handling only.

If implementation discovers that a platform stores the database or draft audio
outside app-owned data, the plan must be revised before coding continues.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Existing encrypted database reopens with the same key and preserves saved entry rows | Unit | `test/data/entries/entry_database_test.dart` |
| Existing encrypted database open failure does not delete database, WAL, SHM, or journal artifacts | Unit | `test/data/entries/entry_database_test.dart` |
| Key loss against an existing encrypted database fails and leaves the database file present rather than creating an empty replacement | Unit | `test/data/entries/entry_database_test.dart` |
| Fresh database creation still works when no database file exists | Unit | `test/data/entries/entry_database_test.dart` |
| Bootstrap still renders the simple retry error when startup fails | Widget regression | `test/bootstrap_app_test.dart` |
| Android manifest disables app backup/restore | Unit/static | `test/platform/android_manifest_data_lifecycle_test.dart` |
| Same-storage lifecycle preserves saved entries, draft rows, linked draft audio file existence, `hasEverRecorded`, and stored device id after closing and reopening the app runtime | Integration | `integration_test/local_data_lifecycle_flow_test.dart` |
| Fresh-state lifecycle starts with no entries or drafts after database/key/preference data is removed | Integration | `integration_test/local_data_lifecycle_flow_test.dart` |
| App UI shows a preserved entry after lifecycle reopen | Integration | `integration_test/local_data_lifecycle_flow_test.dart` |

`integration_test/local_data_lifecycle_flow_test.dart` will use the real app
providers. For ordinary automated runs it can use isolated test-owned storage.
For platform lifecycle validation it will use the app's default database,
shared-preferences store, and a deterministic app-private draft-audio path so
seeded data survives across a separate same-identity install. Scenario selection
through `--dart-define` will allow one run to seed persistent app data, an
external install step to simulate the update, and a second run to verify the
persisted state.

### Android emulator verification

1. Boot one Android emulator and confirm `com.wrait.flutter` is the target app
   identity.
2. Run the lifecycle integration test in platform seed mode to create at least
   one saved entry, one draft with linked audio, `hasEverRecorded=true`, and a
   stored device id in default app storage.
3. Build and install the same app identity over the existing install using the
   simplest available replace-install path for the local build.
4. Run the lifecycle integration test in platform update-verify mode and
   confirm the entry, draft, linked audio file, and preferences remain present.
5. Clear app data through the Android platform flow and run fresh-state
   verification to confirm no old entries or drafts are visible.
6. Uninstall and reinstall the app on the emulator, then run fresh-state
   verification again.
7. Record commands and results in `tasks.md` and `implementation.md`.

### iOS simulator verification

1. Boot one iOS simulator and confirm the Runner bundle identifier is unchanged.
2. Run the lifecycle integration test in platform seed mode to create at least
   one saved entry, one draft with linked audio, `hasEverRecorded=true`, and a
   stored device id in default app storage.
3. Build and install the same bundle over the existing simulator app using the
   simplest available local install path.
4. Run the lifecycle integration test in platform update-verify mode and
   confirm the entry, draft, linked audio file, and preferences remain present.
5. Uninstall and reinstall the app on the simulator, then run fresh-state
   verification to confirm no old entries or drafts are visible.
6. Record commands and results in `tasks.md` and `implementation.md`.

### Validation exception request

None requested. The feature is expected to satisfy the default
`integration_test`, Android emulator, and iOS simulator verification
requirements.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require durable updates to `AGENTS.md` and
  `docs/agent-findings.md` after final approval because it changes the rule for
  encrypted database open failures and documents platform lifecycle validation.
- `docs/application-description.md` may need a small update only if the final
  implementation changes the product-level privacy/storage description.

## Integration notes

- The existing bootstrap UI in `lib/main.dart` already provides the required
  simple startup error state. The plan does not move database opening back into
  pre-UI startup.
- Stale draft cleanup still runs after a successful database open. It must not
  run if the database cannot be opened.
- `EntryRepositoryImpl.deleteEntry` and `deleteStaleDrafts` already remove
  linked audio files for explicit row deletion; this feature does not add a
  custom uninstall hook.
- Backend registration keeps using `PreferencesRepositoryImpl.getDeviceId`.
  Reinstall after uninstall may reuse the same hashed platform id, which the
  spec allows, but old entries must not reappear.
- No OpenAPI generation or backend API changes are required.

## Rollout & migration

The change rolls out with the next same-identity app install. No feature flag is
planned.

Backward compatibility:

- Existing version-1 databases remain readable with the same schema.
- Existing installs with a valid database key continue to open normally.
- Existing installs with an unreadable database now show the simple bootstrap
  error instead of silently replacing the database.
- Android users who reinstall after uninstall should not receive restored app
  data through Android backup after this version disables backup.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Removing automatic recovery leaves some users stuck on a startup error after key loss | Medium | Medium | This matches the spec's simple error requirement and avoids silent data loss. A future approved recovery/reset story can add explicit user choice. |
| Android backup behavior differs across API levels | Medium | High | Explicitly disable app backup in the manifest and add a static test. Validate uninstall/reinstall on an Android emulator. |
| Integration tests accidentally clean up seeded data before update verification | Medium | Medium | Add scenario-mode lifecycle testing and avoid teardown cleanup in seed mode used by platform validation. |
| `flutter test` reinstall behavior differs from store update behavior | Medium | Medium | Pair integration tests with explicit replace-install runtime verification on both platforms. |
| Draft audio files are in temporary storage and may be purged by the OS independently of an update | Low | Medium | Verify update persistence in the planned lifecycle test. The spec covers app update behavior, not arbitrary OS cache pressure. |
| iOS Keychain or platform identifier persists after uninstall | Medium | Low | The spec allows device identity reuse after reinstall. Verification focuses on old diary data not reappearing. |
| Disabling Android backup affects future user restore expectations | Low | Medium | The current product requirement says no cloud backup and reinstall should be fresh. Future backup/restore would need a new approved feature. |

## Open items from spec

None. The spec has no open questions.
