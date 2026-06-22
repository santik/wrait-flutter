# Tasks: App Updates Preserve Local Data

> **Feature number:** 030
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-20

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel after their group prerequisites are met.

### Group 1: Database Open Safety

Remove the only known path that can silently replace an existing local diary
database.

- [x] Modify `LocalEntryDatabase.open` so an existing database open failure
      propagates instead of deleting database artifacts and retrying —
      `lib/data/entries/local_entry_database.dart`
- [x] Keep first-run/fresh-install database creation behavior unchanged when
      no database file exists — `lib/data/entries/local_entry_database.dart`
- [x] Remove or update log messages that imply automatic recovery by deleting
      existing database artifacts — `lib/data/entries/local_entry_database.dart`
- [x] Keep `deleteDatabaseArtifacts` available only as an explicit utility; do
      not call it from existing-database open failure handling unless a future
      approved recovery/reset feature adds explicit user choice —
      `lib/data/entries/local_entry_database.dart`

### Group 2: Android Fresh-Reinstall Contract

Prevent Android backup/restore from bringing back app data after uninstall.

- [x] Explicitly disable app backup/restore for the Android app identity —
      `android/app/src/main/AndroidManifest.xml`
- [x] Verify the manifest change keeps the existing app identity, label, icon,
      activity, Impeller setting, and microphone permission behavior unchanged —
      `android/app/src/main/AndroidManifest.xml`

### Group 3: Lower-Level Automated Coverage

Prove the database and platform-config contracts before runtime validation.

- [x] Update the key-loss database test to expect failure without creating an
      empty replacement database — `test/data/entries/entry_database_test.dart`
- [x] Add assertions that an existing database open failure leaves the primary
      database file and SQLite sidecar artifacts untouched where those sidecars
      exist — `test/data/entries/entry_database_test.dart`
- [x] Add or keep coverage that reopening an encrypted database with the same
      key preserves saved entries — `test/data/entries/entry_database_test.dart`
- [x] Add or keep coverage that creating a fresh encrypted database still works
      when no database file exists — `test/data/entries/entry_database_test.dart`
- [x] Add static manifest coverage that Android backup is disabled —
      `test/platform/android_manifest_data_lifecycle_test.dart`
- [x] Confirm existing bootstrap widget coverage still proves the simple retry
      error appears when startup fails — `test/bootstrap_app_test.dart`

### Group 4: Lifecycle Integration Coverage

Cover the app-level update and fresh-state flows through real providers.

- [x] Create lifecycle integration test scaffolding with scenario selection for
      isolated, platform seed, platform update-verify, and platform fresh-state
      runs — `integration_test/local_data_lifecycle_flow_test.dart`
- [x] In the seed scenario, create at least one saved entry with current entry
      metadata, one draft row with a linked app-private audio file,
      `hasEverRecorded=true`, and a stored device id —
      `integration_test/local_data_lifecycle_flow_test.dart`
- [x] In the update-verify scenario, reopen the same app storage and assert the
      saved entry, draft row, linked audio file, `hasEverRecorded`, and stored
      device id are still present —
      `integration_test/local_data_lifecycle_flow_test.dart`
- [x] In the fresh-state scenario, assert the app starts with no saved entries
      and no pending drafts after platform data removal —
      `integration_test/local_data_lifecycle_flow_test.dart`
- [x] Add a UI checkpoint that renders the app and proves a preserved saved
      entry is visible through the entry-list flow after lifecycle reopen —
      `integration_test/local_data_lifecycle_flow_test.dart`
- [x] Ensure platform seed mode intentionally leaves seeded app data in place
      for the external same-identity install step —
      `integration_test/local_data_lifecycle_flow_test.dart`
- [x] Ensure ordinary isolated test runs clean up their temporary storage so
      local test runs remain repeatable —
      `integration_test/local_data_lifecycle_flow_test.dart`

### Group 5: Automated Validation

Run focused checks before device and simulator lifecycle verification.

- [x] Run Dart formatting on changed Dart files
- [x] Run `flutter analyze`
- [x] Run focused database lifecycle tests:
      `flutter test test/data/entries/entry_database_test.dart`
- [x] Run Android manifest lifecycle test:
      `flutter test test/platform/android_manifest_data_lifecycle_test.dart`
- [x] Run bootstrap regression tests:
      `flutter test test/bootstrap_app_test.dart`
- [x] Run the full Flutter test suite: `flutter test`
- [x] Run lifecycle integration coverage in ordinary isolated mode on the local
      test target or an available simulator/device:
      `flutter test integration_test/local_data_lifecycle_flow_test.dart`

### Group 6: Android Emulator Lifecycle Verification

Validate the same-identity update and fresh-state paths on Android.

- [x] Boot one Android emulator and confirm it targets `com.wrait.flutter`
- [x] Run lifecycle integration test in platform seed mode on the emulator
- [x] Build and install the same app identity over the existing emulator
      install using the simplest local replace-install path
- [x] Run lifecycle integration test in platform update-verify mode and confirm
      entries, draft, linked audio, and preferences persist
- [x] Clear app data through the Android platform flow and run platform
      fresh-state verification
- [x] Uninstall and reinstall the app on the emulator, then run platform
      fresh-state verification again
- [x] Record Android commands, results, and observations in `tasks.md` and
      `implementation.md`

### Group 7: iOS Simulator Lifecycle Verification

Validate the same-bundle update and fresh-state paths on iOS.

- [x] Boot one iOS simulator and confirm the Runner bundle identifier is
      unchanged
- [x] Run lifecycle integration test in platform seed mode on the simulator
- [x] Build and install the same bundle over the existing simulator app using
      the simplest local install path
- [x] Run lifecycle integration test in platform update-verify mode and confirm
      entries, draft, linked audio, and preferences persist
- [x] Uninstall and reinstall the app on the simulator, then run platform
      fresh-state verification
- [x] Record iOS commands, results, and observations in `tasks.md` and
      `implementation.md`

### Group 8: Implementation Record

Document the completed implementation and evidence for review.

- [x] Create `implementation.md` with implementation summary, changed files,
      behavior notes, and validation evidence —
      `specs/030-update-preserves-local-data/implementation.md`
- [x] Record any deviations from the approved plan and explain why they were
      necessary — `specs/030-update-preserves-local-data/implementation.md`
- [x] Update this task file with completed checkboxes and validation evidence —
      `specs/030-update-preserves-local-data/tasks.md`

### Group 9: Review and Fix

Handle external review after implementation.

- [x] Stop and wait for external `review.md`, unless the user explicitly
      skips review
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

- [ ] Decide whether US-030 produced durable learnings or long-lived
      product/architecture changes worth preserving
- [ ] If needed, propose updates to `AGENTS.md` for database-open failure and
      app-update lifecycle guidance
- [ ] If needed, propose updates to `docs/application-description.md` for
      product-level update/uninstall data behavior
- [ ] If needed, propose updates to `docs/agent-findings.md` for reusable
      lifecycle validation and encrypted database handling findings
- [ ] Wait for explicit approval before editing long-lived guidance documents
- [ ] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision
- [ ] Mark `spec.md` status as `Complete` only after implementation, review,
      validation, and final knowledge-capture gates are handled

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
- `dart format lib/data/entries/draft_audio_path_codec.dart lib/data/entries/entry_providers.dart lib/data/entries/entry_repository_impl.dart integration_test/local_data_lifecycle_flow_test.dart test/data/entries/entry_database_test.dart test/data/entries/entry_repository_impl_test.dart test_driver/integration_test.dart`
- `/opt/homebrew/bin/flutter analyze` -> passed
- `/opt/homebrew/bin/flutter test test/data/entries/entry_database_test.dart test/platform/android_manifest_data_lifecycle_test.dart test/bootstrap_app_test.dart` -> passed
- `/opt/homebrew/bin/flutter test test/data/entries/entry_repository_impl_test.dart` -> passed
- `/opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/local_data_lifecycle_flow_test.dart` -> passed (isolated scenario)
- `/opt/homebrew/bin/flutter test` -> passed
- Review-fix validation:
  - `/opt/homebrew/bin/flutter analyze` -> passed
  - `/opt/homebrew/bin/flutter test test/data/entries/entry_database_test.dart test/data/entries/entry_repository_impl_test.dart` -> passed
  - `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d emulator-5554 --dart-define=US030_SCENARIO=platform-seed` -> passed
  - `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d emulator-5554 --dart-define=US030_SCENARIO=platform-update-verify` -> passed
  - `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --dart-define=US030_SCENARIO=platform-seed` -> passed
  - `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --dart-define=US030_SCENARIO=platform-update-verify` -> passed

Android emulator verification (`emulator-5554`, package `com.wrait.flutter`):
- `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d emulator-5554 --dart-define=US030_SCENARIO=platform-seed` -> passed
- `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d emulator-5554 --dart-define=US030_SCENARIO=platform-update-verify` -> passed
- `adb -s emulator-5554 shell pm clear com.wrait.flutter` -> `Success`
- `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d emulator-5554 --dart-define=US030_SCENARIO=platform-fresh-state` -> passed after `pm clear`
- `adb -s emulator-5554 uninstall com.wrait.flutter` -> `Success`
- `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d emulator-5554 --dart-define=US030_SCENARIO=platform-fresh-state` -> passed after uninstall/reinstall

iOS simulator verification (`491CD949-D3C0-4C4C-A6B9-15BAB1859156`, bundle `com.wrait.app`):
- `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --dart-define=US030_SCENARIO=platform-seed` -> passed
- `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --dart-define=US030_SCENARIO=platform-update-verify` -> passed
- `xcrun simctl uninstall 491CD949-D3C0-4C4C-A6B9-15BAB1859156 com.wrait.app`
- `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --dart-define=US030_SCENARIO=platform-fresh-state` -> passed after uninstall/reinstall

Observation:
- The original `flutter test -d ... integration_test/...` approach tears down the installed app container between runs, so it is not a faithful same-identity update harness for this story. `flutter drive --keep-app-running` was used for platform seed/update/fresh-state loops instead.
```

## Notes

- No validation exceptions were approved or requested in the plan.
- Android emulator and iOS simulator lifecycle verification are required before
  final approval.
- The current plan intentionally replaces silent database reset on open failure
  with the existing simple bootstrap error screen.
