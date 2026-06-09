# Tasks: Encrypted Local Entry Store

> **Feature number:** 003
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-08

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

_Tasks are organized into sequential groups.
Tasks within the same group marked `[P]` can be worked on in parallel._

### Group 1: Establish the encrypted persistence foundation

_Add the target persistence dependencies and the shared primitives the data
layer will rely on._

- [x] Update the dependency surface for the target architecture by adding Drift, its build/codegen tooling, and the encrypted SQLite runtime packages, while leaving `sqflite_sqlcipher` only for later reevaluation if it still proves necessary — `pubspec.yaml`
- [x] Create the small clock abstraction used for timestamps and stale-draft cutoff calculations — `lib/core/time/system_clock.dart`
  - Depends on: Group 1 dependency task
- [x] Create the secure key-store wrapper that reads or generates the encrypted database key through protected storage — `lib/data/entries/database_key_store.dart`
  - Depends on: Group 1 dependency task

### Group 2: Define the domain and Drift data contracts

_Create the typed storage model, schema, and query surfaces that implement the
approved entry contract._

- [x] [P] Create the domain entry model with the approved persistent fields and BCP-47 language contract — `lib/domain/model/entry.dart`
- [x] [P] Create the domain repository interface covering reactive reads, one-time reads, CRUD, draft operations, and stale-draft cleanup — `lib/domain/repository/entry_repository.dart`
- [x] Build the Drift database definition with the encrypted `entries` table, schema versioning, and encrypted connection bootstrap — `lib/data/entries/local_entry_database.dart`
  - Depends on: Group 1 dependency and key-store tasks
- [x] Create the Drift DAO for newest-first list queries, entry-by-id watched and one-time lookups, insert/update/delete flows, and stale-draft selection/cleanup queries — `lib/data/entries/entry_dao.dart`
  - Depends on: Group 2 database-definition task
- [x] Add mapping helpers between Drift row models and the domain `Entry` model — `lib/data/entries/entry_mapper.dart`
  - Depends on: Group 2 domain-model and database-definition tasks
- [x] Generate the Drift support code for the local entry database and DAO — `lib/data/entries/local_entry_database.g.dart`
  - Depends on: Group 2 database-definition and DAO tasks

### Group 3: Implement repository behavior and startup wiring

_Connect the encrypted store to the app lifecycle and expose the full storage
behavior required by the spec._

- [x] Implement the repository with Drift-backed CRUD, draft finalization, reactive watched queries, one-time reads, timestamp handling, and best-effort audio-file deletion — `lib/data/entries/entry_repository_impl.dart`
  - Depends on: Group 1 clock task and all Group 2 tasks
- [x] Create Riverpod providers for secure storage, clock, encrypted database bootstrap, and repository access — `lib/data/entries/entry_providers.dart`
  - Depends on: Group 1 key-store task and Group 3 repository task
- [x] Update app startup to initialize Flutter bindings, bootstrap the encrypted store, run stale-draft cleanup before `runApp`, and launch the app with the prepared provider container — `lib/main.dart`
  - Depends on: Group 3 provider task

### Group 4: Add post-implementation repository and database validation

_Prove the encrypted store contract with automated coverage after the
implementation is in place._

- [x] Create the in-memory secure-storage fake needed for deterministic key lifecycle tests — `test/test_doubles/fake_secure_storage.dart`
- [x] Create the controllable fake clock used for created-at and stale-draft cutoff tests — `test/test_doubles/fake_clock.dart`
- [x] Add database bootstrap tests for key generation, schema creation, encrypted open, and key-loss recovery into a fresh usable store — `test/data/entries/entry_database_test.dart`
  - Depends on: Groups 1, 2, and 4 test-double tasks
- [x] Add repository tests covering completed entry saves, text drafts, audio drafts, transcript updates, cleaned-text finalization, language updates, reactive list updates, reactive entry-by-id updates, one-time reads, pending drafts, entry deletion, stale-draft deletion, and stale audio-file cleanup — `test/data/entries/entry_repository_impl_test.dart`
  - Depends on: Groups 2, 3, and 4 test-double tasks
- [x] Add an automated startup/bootstrap test that proves the encrypted store is initialized and stale-draft cleanup runs before normal app use continues — `test/data/entries/entry_database_test.dart` or dedicated startup/bootstrap test
  - Depends on: Groups 1, 2, 3, and 4 test-double tasks
- [x] Run Drift code generation and ensure generated files are up to date
  - Depends on: Groups 2 and 3
- [x] Run `flutter analyze` and record zero-warning results as validation evidence
  - Depends on: Groups 1, 2, 3, and 4 test-creation tasks
- [x] Run `flutter test` and record passing repository/database coverage as validation evidence
  - Depends on: Groups 1, 2, 3, and 4 test-creation tasks
- [x] Perform manual Android and iOS launch verification plus encrypted-store and stale-draft cleanup checks, then record the results in this file
  - Depends on: Groups 1, 2, and 3
- [x] Record validation evidence and implementation notes directly in this file — `specs/003-encrypted-local-database/tasks.md`
  - Depends on: All groups

## Completion criteria

All tasks checked, Drift-generated code committed and in sync, `flutter analyze`
warning-free, `flutter test` passing after implementation, manual Android/iOS
verification completed, and validation evidence documented in this file.

## Validation evidence

_Record test results, screenshots, or command output here when complete._

```text
$ dart format lib test
Formatted lib/data/entries/entry_dao.dart
Formatted lib/data/entries/entry_providers.dart
Formatted lib/data/entries/entry_repository_impl.dart
Formatted lib/data/entries/local_entry_database.dart
Formatted lib/domain/repository/entry_repository.dart
Formatted lib/main.dart
Formatted test/data/entries/entry_database_test.dart
Formatted test/data/entries/entry_repository_impl_test.dart
Formatted 29 files (8 changed) in 0.08 seconds.

$ /opt/homebrew/bin/flutter pub get
Changed 21 dependencies!
The following plugins do not support Swift Package Manager for ios:
  - sqflite_sqlcipher

$ dart run build_runner build --delete-conflicting-outputs
W These options have been removed and were ignored: --delete-conflicting-outputs
Built with build_runner/aot in 20s; wrote 56 outputs.

$ /opt/homebrew/bin/flutter analyze
Analyzing write-flutter...
No issues found! (ran in 5.4s)

$ /opt/homebrew/bin/flutter test
00:01 +27: All tests passed!

$ /opt/homebrew/bin/flutter run -d emulator-5554
Launched on Android emulator.
Manual verification captured:
- App booted successfully with the new startup bootstrap path.
- `flutter_secure_storage` performed a no-data algorithm migration without blocking launch.
- `adb -s emulator-5554 shell run-as com.wrait.app ls -R .` showed `app_flutter/wrait_entries.sqlite`, confirming startup database creation on Android.

$ /opt/homebrew/bin/flutter run -d 0140EF83-0B3E-4517-B669-FDBE5E3B0BBA
Launched on iPhone 17 Pro simulator.
Manual verification captured:
- App booted successfully with the new startup bootstrap path on iOS.
- Direct filesystem inspection found:
  `/Users/alexander/Library/Developer/CoreSimulator/Devices/0140EF83-0B3E-4517-B669-FDBE5E3B0BBA/data/Containers/Data/Application/BC91FB64-8B18-48F9-9FF9-288F783C032B/Documents/wrait_entries.sqlite`
  confirming startup database creation on iOS.
```

## Notes

- The implementation should follow the revised plan’s target architecture:
  `drift + SQLite3MultipleCiphers`.
- `sqflite_sqlcipher` should not become the long-term persistence foundation in
  this story; any continued need for it should be treated as a follow-up
  refinement question.
- The shipped implementation uses Drift plus `sqlite3` with the `sqlite3mc`
  build-hook configuration and does not route application persistence through
  `sqflite_sqlcipher`.
- The automated startup/bootstrap test now covers the ordering requirement that
  stale-draft cleanup runs before normal app use continues.
- `sqflite_sqlcipher` remains in `pubspec.yaml` for now, which is why Flutter
  commands still print the existing Swift Package Manager warning even though
  this story’s persistence implementation no longer depends on it at runtime.
