# Implementation: App Updates Preserve Local Data

> **Feature number:** 030
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-20

## Summary

US-030 is implemented by removing the app's only known silent database-reset
path, disabling Android backup/restore, and adding lifecycle coverage that
proves same-identity installs preserve local diary data while uninstall and
platform data removal return the app to a fresh state.

The implementation also fixes an iOS-specific retained-audio edge case that
appeared during simulator validation: absolute cache paths could change across
same-bundle reinstalls because the simulator app container UUID changed. The
repository now stores app-managed draft-audio paths in a portable form and
resolves them back to the current container path on read.

## Implemented behavior

- Existing encrypted databases are no longer deleted and recreated when open
  fails. The app now surfaces the existing bootstrap retry/error shell instead
  of silently replacing user data with an empty store.
- First-run database creation still succeeds when no database file exists.
- Android explicitly disables app backup/restore so uninstall does not restore
  old local diary data through platform backup mechanisms.
- Draft audio paths stored inside the app-managed cache directory are persisted
  in a portable form and resolved to the current runtime cache location when
  read back.
- Legacy absolute draft-audio paths still resolve when the original file
  exists, and can fall forward to the current cache directory when the file was
  preserved under the same basename after a platform reinstall/update.
- New lifecycle integration coverage supports four scenarios:
  - isolated repeatable storage
  - platform seed
  - platform update verification
  - platform fresh-state verification
- Platform lifecycle validation now covers:
  - update preserving saved entries
  - update preserving draft rows
  - update preserving linked draft audio
  - update preserving `hasEverRecorded`
  - update preserving stored device id
  - Android clear-data returning a fresh state
  - Android uninstall/reinstall returning a fresh state
  - iOS uninstall/reinstall returning a fresh state

## File-change summary

### Production code

- `lib/data/entries/local_entry_database.dart`
- `lib/data/entries/draft_audio_path_codec.dart`
- `lib/data/entries/entry_repository_impl.dart`
- `lib/data/entries/entry_providers.dart`
- `android/app/src/main/AndroidManifest.xml`

### Tests and validation harness

- `test/data/entries/entry_database_test.dart`
- `test/data/entries/entry_repository_impl_test.dart`
- `test/platform/android_manifest_data_lifecycle_test.dart`
- `integration_test/local_data_lifecycle_flow_test.dart`
- `test_driver/integration_test.dart`

### Existing coverage re-verified without source edits

- `test/bootstrap_app_test.dart`

## Notable implementation notes

- The startup UX remains the existing simple bootstrap loading/retry shell.
  This story intentionally did not add recovery UI beyond surfacing the error.
- The portable draft-audio handling is limited to app-managed cache files. It
  does not rewrite arbitrary external file paths.
- Android validation continues to target package `com.wrait.flutter`.
- iOS validation confirmed the Runner bundle identifier remains `com.wrait.app`.
- The old native Android app identity (`com.wrait.app`) is still out of scope
  for update-in-place migration into the Flutter Android app
  (`com.wrait.flutter`).

## Deviations from the approved plan

- The approved plan assumed `flutter test -d ... integration_test/...` could be
  used directly for same-identity platform update verification. During
  implementation, that runner tore down the installed app container between
  runs, which made it unsuitable for proving in-place update persistence.
- To keep validation faithful to the requirement, I added
  `test_driver/integration_test.dart` and switched the platform lifecycle loops
  to `flutter drive --keep-app-running`. That preserved the installed app
  between seed, update, and fresh-state steps and let the story be validated as
  specified.
- iOS simulator validation exposed a real product issue, not just a harness
  issue: absolute retained-audio cache paths were not stable across same-bundle
  reinstalls. The implementation expanded slightly from the original plan to
  store and resolve app-managed draft-audio paths portably so the linked-file
  requirement is actually met on iOS.

## Validation

The following validation completed successfully:

- `dart format lib/data/entries/draft_audio_path_codec.dart lib/data/entries/entry_providers.dart lib/data/entries/entry_repository_impl.dart integration_test/local_data_lifecycle_flow_test.dart test/data/entries/entry_database_test.dart test/data/entries/entry_repository_impl_test.dart test_driver/integration_test.dart`
- `/opt/homebrew/bin/flutter analyze`
- `/opt/homebrew/bin/flutter test test/data/entries/entry_database_test.dart test/platform/android_manifest_data_lifecycle_test.dart test/bootstrap_app_test.dart`
- `/opt/homebrew/bin/flutter test test/data/entries/entry_repository_impl_test.dart`
- `/opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/local_data_lifecycle_flow_test.dart`
- `/opt/homebrew/bin/flutter test`

Android emulator validation (`emulator-5554`):

- `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d emulator-5554 --dart-define=US030_SCENARIO=platform-seed`
- `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d emulator-5554 --dart-define=US030_SCENARIO=platform-update-verify`
- `adb -s emulator-5554 shell pm clear com.wrait.flutter`
- `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d emulator-5554 --dart-define=US030_SCENARIO=platform-fresh-state`
- `adb -s emulator-5554 uninstall com.wrait.flutter`
- `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d emulator-5554 --dart-define=US030_SCENARIO=platform-fresh-state`

iOS simulator validation (`491CD949-D3C0-4C4C-A6B9-15BAB1859156`):

- `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --dart-define=US030_SCENARIO=platform-seed`
- `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --dart-define=US030_SCENARIO=platform-update-verify`
- `xcrun simctl uninstall 491CD949-D3C0-4C4C-A6B9-15BAB1859156 com.wrait.app`
- `/opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --dart-define=US030_SCENARIO=platform-fresh-state`

## Review status

The external review pass has been applied for the approved subset of findings.

### Review remediation implemented

- Added database corruption coverage so a corrupted encrypted database now has
  explicit evidence that open fails without deleting the underlying artifacts.
- Reworked the lifecycle integration harness so platform update verification
  persists seeded entry IDs and other expected metadata at runtime instead of
  hardcoding entry IDs.
- Adjusted the platform lifecycle harness to recompute the current draft-audio
  cache path during update verification, which keeps the test focused on the
  approved runtime-captured-ID fix instead of pinning expectations to a stale
  simulator container path.
- Added an explicit destructive-use warning comment to
  `LocalEntryDatabase.deleteDatabaseArtifacts(...)`.
- Replaced manual path construction in `entry_repository_impl_test.dart` with
  `path.join(...)`.

### Review findings intentionally deferred

- The `DraftAudioPathCodec` behavior findings were not remediated in US-030 by
  explicit user direction. That follow-up is being handled in US-032 so the
  iOS-focused draft-audio path problem can be simplified there without
  reopening the approved US-030 scope.

Implementation remains in progress overall because the knowledge-capture gate
still has not been handled.
