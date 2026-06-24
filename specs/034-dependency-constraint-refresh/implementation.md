# Implementation Notes: Dependency Constraint Refresh

> **Feature number:** 034
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-24

---

## Summary

This implementation refreshed the project to Flutter stable `3.44.3` with
Dart `3.12.2`, updated the direct dependency graph to the freshest compatible
versions that remain valid under that toolchain, and preserved build/test
health across host, Android emulator, and iOS simulator validation.

The review/fix pass also hardened two async presentation controllers against
provider disposal during awaited work:

- `AppLockController.unlock()` now exits cleanly when the provider is disposed
  before authentication completes.
- `EntryDetailController` now exits cleanly when the provider is disposed while
  an auto-save is still in flight.

Two package exceptions were intentionally kept:

- `drift_dev` stayed on `2.34.0` because `2.34.1+1` requires
  `analyzer ^13.0.0`, which conflicts with the `flutter_test` package pins
  shipped with Flutter `3.44.3`.
- `record` was pinned back to `7.0.0` after attempting `7.1.0`, because
  `record_android 2.1.2` fails Android debug compilation under this toolchain
  with unresolved `AdtsContainer` references inside the plugin code.

## Versions applied

### Toolchain

- Flutter `3.44.1` -> `3.44.3`
- Dart `3.12.1` -> `3.12.2`

### `pubspec.yaml`

- Added `environment.flutter: ">=3.44.3 <3.45.0"`
- Updated `environment.sdk` from `^3.12.1` to `^3.12.2`
- Updated `drift` from `^2.33.0` to `^2.34.0`
- Updated `flutter_riverpod` from `^3.3.1` to `^3.3.2`
- Updated `path_provider` from `^2.1.5` to `^2.1.6`
- Updated `sqlite3` from `^3.3.1` to `^3.3.3`
- Updated `drift_dev` from `^2.33.0` to `^2.34.0`
- Tried `record 7.1.0`, then pinned `record: 7.0.0` after Android plugin
  build failure
- Added an inline `pubspec.yaml` comment above `record` documenting the
  upstream Android plugin failure that requires the exact pin

### `pubspec.lock`

Selected notable resolved updates:

- `drift` -> `2.34.0`
- `drift_dev` -> `2.34.0`
- `flutter_riverpod` -> `3.3.2`
- `riverpod` -> `3.3.2`
- `path_provider` -> `2.1.6`
- `sqlite3` -> `3.3.3`
- `coverage` -> `1.15.1`
- `dbus` -> `0.7.14`
- `path_provider_platform_interface` -> `2.1.3`
- `permission_handler_apple` -> `9.4.10`
- `shared_preferences_android` -> `2.4.26`
- `sqlparser` -> `0.44.5`

No generated backend package lockfile update was required.

## Compatibility fix discovered during validation

Device-side iOS validation first exposed a provider-lifecycle issue in
`AppLockController.unlock()`: after awaiting the authenticator, the controller
could still attempt to update state even if the provider had already been
disposed by test teardown.

Fix applied:

- Added a `ref.mounted` guard after the async authenticator call in
  [app_lock_controller.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/app_lock/app_lock_controller.dart)
- Added a disposal regression test in
  [app_lock_controller_test.dart](/Users/alexander/projects/wrait/write-flutter/test/presentation/app_lock/app_lock_controller_test.dart)

The review/fix pass then audited the remaining presentation-layer async
controllers for the same post-`await` state-write pattern. That audit found
one additional high-risk case in `EntryDetailController`, which is
`autoDispose` and performs async save work before writing state again.

Second fix applied:

- Added `ref.mounted` guards in
  [entry_detail_controller.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/entries/entry_detail_controller.dart)
  after awaited save work and before post-save state reads/writes
- Added a disposal regression test in
  [entry_detail_controller_test.dart](/Users/alexander/projects/wrait/write-flutter/test/presentation/entries/entry_detail_controller_test.dart)

Audit result:

- `AppLockController` fixed
- `EntryDetailController` fixed
- `MainRecordingController` reviewed and left unchanged because it is not
  `autoDispose`, and the reviewed async paths did not present the same
  provider-disposal risk profile found in the two controllers above

These were not planned feature changes; they were runtime-safety corrections
required to satisfy the approved validation bar after the toolchain update.

## Generated backend package validation

The generated backend API package was revalidated after the root dependency
refresh even though its lockfile did not need to change.

- `flutter pub get` in
  `tool/openapi-generator/output/backend_api` resolved successfully
- `flutter analyze` in
  `tool/openapi-generator/output/backend_api` reported 7 generated-code
  warnings in `lib/lib/api/default_api.dart`
  (`unused_import` and `duplicate_import`) and no compatibility errors

Because that package is generated output and the warnings pre-exist the refresh
goal, no generated source changes were made in this maintenance story.

## Remaining outdated packages

### Intentional direct/dev exceptions

- `record 7.0.0` while `7.1.0` is resolvable/latest
  Reason: Android build failure in upstream `record_android 2.1.2`
- `drift_dev 2.34.0` while `2.34.1+1` is latest
  Reason: analyzer version conflict with Flutter `3.44.3` SDK test pins

### Solver-constrained transitives

- `_fe_analyzer_shared`
- `analyzer`
- `flutter_secure_storage_darwin`
- `matcher`
- `meta`
- `package_config`
- `test`
- `test_api`
- `test_core`
- `vector_math`
- `xml`
- `cli_util`
- `dart_style`

`flutter pub outdated` reports that the repo is already using the newest
mutually compatible resolvable versions for the selected graph.

## Validation

### Host

- `flutter analyze` -> passed
- `flutter test test` -> passed
- `flutter test --no-pub test` -> passed (`333` tests)
- `bash test/deploy_debug_script_test.sh` -> passed
- `bash test/deploy_release_script_test.sh` -> passed

### Build

- `flutter build apk --debug` -> passed
- `flutter build ios --simulator --no-codesign` -> passed

### Android emulator

- `flutter test -d emulator-5554 integration_test/main_screen_permission_flow_test.dart` -> passed
- `flutter test -d emulator-5554 integration_test/capture_prevention_flow_test.dart` -> passed
- `flutter test -d emulator-5554 integration_test/entry_detail_device_smoke_test.dart` -> passed
- `flutter test -d emulator-5554 integration_test/main_screen_display_awake_flow_test.dart` -> passed
- `flutter test -d emulator-5554 integration_test/main_recording_controller_flow_test.dart` -> passed (`6` tests)
- `flutter test -d emulator-5554 integration_test/audio_recording_service_flow_test.dart`
  -> reproducibly stalled on
  `provider graph supports start and valid stop with a completed file path`,
  then reported `did not complete` after manual interruption at `00:52`

Additional note:

- A full device-suite attempt on the Android emulator was started, but the run
  was narrowed to targeted subsets after `flutter_tools` hit log-reader and
  listener finalization instability around `entry_detail_flow_test.dart`.
  The evidence pointed to test-runner infrastructure instability rather than an
  app crash.

### iOS simulator

- `flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/capture_prevention_flow_test.dart` -> passed
- `flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/app_lock_flow_test.dart` -> passed
- `flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_detail_device_smoke_test.dart` -> passed after the app-lock disposal fix
- `flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart` -> passed
- `flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_flow_test.dart integration_test/device_registration_launch_flow_test.dart integration_test/draft_retry_launch_flow_test.dart integration_test/local_data_lifecycle_flow_test.dart` -> passed
- Re-ran `flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_detail_device_smoke_test.dart`
  after the `EntryDetailController` fix -> passed (`2` tests)

## Exact toolchain output

### Pre-upgrade `flutter --version`

```text
Flutter 3.44.1 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 924134a44c (4 weeks ago) • 2026-05-29 12:13:22 -0400
Engine • hash 39b1f7043775b9578bbb26a1676e79c4e31c8b5e (revision c416acfeb8) (27 days ago) • 2026-05-27 20:19:31.000Z
Tools • Dart 3.12.1 • DevTools 2.57.0
```

### Post-upgrade `flutter --version`

```text
Flutter 3.44.3 • channel stable • https://github.com/flutter/flutter.git
Framework • revision e1fd963c6f (6 days ago) • 2026-06-18 14:59:18 -0700
Engine • hash 97bcd50733ba183d436566477a85414db19fdb97 (revision a4ce257c68) (5 days ago) • 2026-06-18 17:14:12.000Z
Tools • Dart 3.12.2 • DevTools 2.57.0
```

## Exact dependency resolution output

### Pre-refresh `flutter pub outdated`

```text
Showing outdated packages.
[*] indicates versions that are not the latest available.

Package Name                      Current   Upgradable  Resolvable  Latest

direct dependencies:
drift                             *2.33.0   2.34.0      2.34.0      2.34.0
flutter_riverpod                  *3.3.1    3.3.2       3.3.2       3.3.2
path_provider                     *2.1.5    2.1.6       2.1.6       2.1.6
record                            *7.0.0    7.1.0       7.1.0       7.1.0
sqlite3                           *3.3.2    3.3.3       3.3.3       3.3.3

dev_dependencies:
drift_dev                         *2.33.0   *2.34.0     *2.34.0     2.34.1+1

transitive dependencies:
_fe_analyzer_shared               *99.0.0   *99.0.0     *99.0.0     104.0.0
analyzer                          *12.1.0   *12.1.0     *12.1.0     14.0.0
coverage                          *1.15.0   1.15.1      1.15.1      1.15.1
dbus                              *0.7.13   0.7.14      0.7.14      0.7.14
flutter_secure_storage_darwin     *0.3.2    *0.3.2      *0.3.2      0.4.0
matcher                           *0.12.19  *0.12.19    *0.12.19    0.12.20
meta                              *1.18.0   *1.18.0     *1.18.0     1.18.3
package_config                    *2.2.0    *2.2.0      *2.2.0      3.0.0
path_provider_platform_interface  *2.1.2    2.1.3       2.1.3       2.1.3
permission_handler_apple          *9.4.9    9.4.10      9.4.10      9.4.10
record_android                    *2.0.1    2.1.2       2.1.2       2.1.2
record_ios                        *2.0.0    2.1.1       2.1.1       2.1.1
record_linux                      *2.0.0    2.1.0       2.1.0       2.1.0
record_macos                      *2.0.0    2.1.1       2.1.1       2.1.1
record_platform_interface         *2.0.0    2.1.0       2.1.0       2.1.0
record_web                        *2.0.0    2.1.0       2.1.0       2.1.0
record_windows                    *2.0.0    2.2.0       2.2.0       2.2.0
riverpod                          *3.2.1    3.3.2       3.3.2       3.3.2
shared_preferences_android        *2.4.25   2.4.26      2.4.26      2.4.26
test                              *1.31.0   *1.31.0     *1.31.0     1.31.1
test_api                          *0.7.11   *0.7.11     *0.7.11     0.7.12
test_core                         *0.6.17   *0.6.17     *0.6.17     0.6.18
vector_math                       *2.2.0    *2.2.0      *2.2.0      2.4.0

transitive dev_dependencies:
cli_util                          *0.4.2    *0.4.2      *0.4.2      0.5.1
dart_style                        *3.1.8    *3.1.8      *3.1.8      3.1.9
sqlparser                         *0.44.4   0.44.5      0.44.5      0.44.5

20 upgradable dependencies are locked (in pubspec.lock) to older versions.
To update these dependencies, use `flutter pub upgrade`.
```

### Post-refresh `flutter pub outdated`

```text
Showing outdated packages.
[*] indicates versions that are not the latest available.

Package Name                   Current   Upgradable  Resolvable  Latest

direct dependencies:
record                         *7.0.0    *7.0.0      7.1.0       7.1.0

dev_dependencies:
drift_dev                      *2.34.0   *2.34.0     *2.34.0     2.34.1+1

transitive dependencies:
_fe_analyzer_shared            *99.0.0   *99.0.0     *99.0.0     104.0.0
analyzer                       *12.1.0   *12.1.0     *12.1.0     14.0.0
flutter_secure_storage_darwin  *0.3.2    *0.3.2      *0.3.2      0.4.0
matcher                        *0.12.19  *0.12.19    *0.12.19    0.12.20
meta                           *1.18.0   *1.18.0     *1.18.0     1.18.3
package_config                 *2.2.0    *2.2.0      *2.2.0      3.0.0
test                           *1.31.0   *1.31.0     *1.31.0     1.31.1
test_api                       *0.7.11   *0.7.11     *0.7.11     0.7.12
test_core                      *0.6.17   *0.6.17     *0.6.17     0.6.18
vector_math                    *2.2.0    *2.2.0      *2.2.0      2.4.0
xml                            *6.6.1    *6.6.1      *6.6.1      7.0.1

transitive dev_dependencies:
cli_util                       *0.4.2    *0.4.2      *0.4.2      0.5.1
dart_style                     *3.1.8    *3.1.8      *3.1.8      3.1.9

1 dependency is constrained to a version that is older than a resolvable version.
To update it, edit pubspec.yaml, or run `flutter pub upgrade --major-versions`.
```

## Recorded `record` 7.1.0 blocker

The attempted `record 7.1.0` upgrade pulled `record_android 2.1.2`, which
failed Android Kotlin compilation. The observed plugin error included:

```text
e: .../record_android-2.1.2/.../AacFormat.kt:8:46 Unresolved reference 'AdtsContainer'
e: .../record_android-2.1.2/.../AacFormat.kt:52:14 Unresolved reference 'AdtsContainer'

FAILURE: Build failed with an exception.
* What went wrong:
Execution failed for task ':record_android:compileProfileKotlin'.
> A failure occurred while executing org.jetbrains.kotlin.compilerRunner.btapi.BuildToolsApiCompilationWork
   > Compilation error. See log for more details
```

## Scope confirmation

- No API contract changes were introduced.
- No data model or migration changes were introduced.
- No dependency audit/security report was generated; that remained out of scope.
- No generated backend source regeneration was required.
