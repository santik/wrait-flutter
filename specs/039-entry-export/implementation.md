# Implementation: Entry Export

> **Feature number:** 039
> **Date:** 2026-06-30
> **Status:** Implemented with external review remediation applied

## Summary

US-039 adds a manual CSV export action to the entries screen, writes the export
to a user-accessible platform destination, and keeps the export flow
non-mutating. The implementation keeps the default iOS encrypted database
location in Application Support so the new Files-visible export folder does not
expose the raw database.

## Implementation details

- Added `EntryExportService` in
  [lib/domain/service/entry_export_service.dart](/Users/alexander/projects/wrait/write-flutter/lib/domain/service/entry_export_service.dart)
  to generate deterministic CSV output with the approved columns:
  `id`, `type`, `created_at`, `created_at_epoch_ms`, `language`,
  `word_count`, `raw_transcript`, `cleaned_text`.
- Added `MethodChannelEntryExportFileWriter` and providers in
  [lib/data/entries/entry_export_file_writer.dart](/Users/alexander/projects/wrait/write-flutter/lib/data/entries/entry_export_file_writer.dart)
  and
  [lib/data/entries/entry_export_providers.dart](/Users/alexander/projects/wrait/write-flutter/lib/data/entries/entry_export_providers.dart).
- Updated
  [lib/presentation/entries/entry_list_controller.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/entries/entry_list_controller.dart)
  to a `Notifier` with `isExporting` single-flight state.
- Updated
  [lib/presentation/entries/entry_list_screen.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/entries/entry_list_screen.dart)
  to add the export button, progress state, and generic success/failure
  feedback.
- Added Android native export writing in
  [android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt](/Users/alexander/projects/wrait/write-flutter/android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt):
  - API 29+ writes to `Downloads/Wrait` via `MediaStore`
  - older Android falls back to the app external downloads directory
- Added iOS native export writing in
  [ios/Runner/AppDelegate.swift](/Users/alexander/projects/wrait/write-flutter/ios/Runner/AppDelegate.swift)
  and enabled Files visibility in
  [ios/Runner/Info.plist](/Users/alexander/projects/wrait/write-flutter/ios/Runner/Info.plist).
- Updated
  [lib/data/entries/local_entry_database.dart](/Users/alexander/projects/wrait/write-flutter/lib/data/entries/local_entry_database.dart)
  so the default iOS database path is now `Library/Application Support`.
  No legacy migration path is included because iOS has no existing shipped user
  base to preserve.
- After external review, tightened export diagnostics, added same-second
  filename collision suffixes, improved export-progress accessibility
  semantics, and added the iOS export-directory conflict check.

## Validation evidence

### Formatting and analysis

```text
$ dart format lib/data/entries/entry_export_file_writer.dart lib/domain/service/entry_export_service.dart lib/data/entries/entry_export_providers.dart lib/data/entries/local_entry_database.dart lib/presentation/entries/entry_list_controller.dart lib/presentation/entries/entry_list_screen.dart test/domain/service/entry_export_service_test.dart test/data/entries/entry_export_file_writer_test.dart test/data/entries/local_entry_database_path_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart integration_test/entry_list_flow_test.dart
Formatted 12 files (7 changed) in 0.10 seconds.

$ flutter analyze
No issues found! (ran in 6.0s)

$ flutter test test/data/entries/local_entry_database_path_test.dart
All tests passed! (2 tests)

$ flutter test test/domain/service/entry_export_service_test.dart test/data/entries/entry_export_file_writer_test.dart test/presentation/entries/entry_list_screen_test.dart
All tests passed! (service, file-writer, and entries-screen coverage)

$ flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart
All tests passed! (11 tests on iOS simulator)

$ flutter test -d 4A181FDJH0030G integration_test/entry_list_flow_test.dart
All tests passed! (11 tests on Android device)

$ flutter analyze
No issues found! (ran in 7.1s)
```

### Focused automated tests

```text
$ flutter test test/domain/service/entry_export_service_test.dart test/data/entries/entry_export_file_writer_test.dart test/data/entries/local_entry_database_path_test.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart
All tests passed! (32 tests)

$ flutter test integration_test/entry_list_flow_test.dart
All tests passed! (11 tests on Android device run)
```

### Broader regression suites

```text
$ flutter test test/data/entries
All tests passed! (43 tests)

$ flutter test test/presentation/entries
All tests passed! (61 tests)
```

### Android emulator runtime verification

```text
$ flutter test -d emulator-5554 integration_test/entry_list_flow_test.dart
All tests passed! (11 tests)

$ adb -s emulator-5554 shell ls -l /sdcard/Download/Wrait
wrait-entries-20260616-070000.csv

$ adb -s emulator-5554 shell cat /sdcard/Download/Wrait/wrait-entries-20260616-070000.csv
id,type,created_at,created_at_epoch_ms,language,word_count,raw_transcript,cleaned_text
2,draft,2026-06-16T07:00:00.000Z,1781593200000,en-US,3,newer draft entry,
1,saved,2026-06-15T07:00:00.000Z,1781506800000,en-US,3,older final entry,
```

### iOS simulator runtime verification

```text
$ flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart
All tests passed! (11 tests)

$ /opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/entry_list_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156
All tests passed. Leaving the application running.

$ /opt/homebrew/bin/flutter run -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --route=/entries --dart-define=APP_LOCK_ENABLED=false
App launched on the normal bootstrap path.

$ xcrun simctl get_app_container 491CD949-D3C0-4C4C-A6B9-15BAB1859156 com.wrait.app data
/Users/alexander/Library/Developer/CoreSimulator/Devices/491CD949-D3C0-4C4C-A6B9-15BAB1859156/data/Containers/Data/Application/CDEC4F30-5968-4C4F-9CD7-4BEBFCD482E3

$ ls -R .../Documents
Documents/Wrait Exports/wrait-entries-20260616-070000.csv

$ ls -R .../Library/Application\ Support
wrait_entries_v2.sqlite

$ cat .../Documents/Wrait\ Exports/wrait-entries-20260616-070000.csv
id,type,created_at,created_at_epoch_ms,language,word_count,raw_transcript,cleaned_text
2,draft,2026-06-16T07:00:00.000Z,1781593200000,en-US,3,newer draft entry,
1,saved,2026-06-15T07:00:00.000Z,1781506800000,en-US,3,older final entry,
```

## Notes

- Export filenames are currently based on UTC timestamps. Because the test clock
  starts from a local `09:00` and the environment timezone is
  `Europe/Amsterdam`, the generated runtime filename is
  `wrait-entries-20260616-070000.csv`.
- The iOS `flutter test` install is transient, so container inspection was done
  with `flutter drive --keep-app-running` and a follow-up normal `flutter run`
  launch to verify the real bootstrap database location.
- The external review gate was explicitly skipped by the user for this pass so
  the implementation was updated directly after initial validation.
- After the user removed the no-longer-needed iOS migration requirement, the
  follow-up validation reran the database-path test and `flutter analyze`.
- A later external review was still processed and the accepted remediation
  items were applied without restoring the intentionally removed iOS migration
  path.
- The remediation validation reused the existing on-device export integration
  flow on iOS simulator and Android after tightening diagnostics and filename
  handling, but it did not repeat manual file-content inspection because the
  review fixes did not change the CSV row contract.
- Flutter still prints the existing plugin warning about older Kotlin Gradle
  Plugin application in several dependencies. It did not block this feature's
  build or validation.
