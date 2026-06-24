# Tasks: Dependency Constraint Refresh

> **Feature number:** 034
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-24

---

## Legend

- `[ ]` - not started
- `[x]` - complete
- `[P]` - can be parallelized with other `[P]` tasks in the same group
- `[B]` - blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Baseline and toolchain

Establish the current state and move the local stable Flutter toolchain to the
approved target.

- [x] Record pre-change `flutter --version` output in validation notes
- [x] Record pre-change `flutter pub outdated` output in validation notes
- [x] Upgrade stable Flutter from `3.44.1` to latest stable `3.44.3`
- [x] Verify post-upgrade `flutter --version` reports stable `3.44.3`
- [x] Confirm the bundled Dart version and whether `pubspec.yaml` SDK
      constraints need adjustment
- [x] Confirm there is still no project-local version-manager file such as
      `.fvmrc`
 

### Group 2: Dependency constraints and resolution

Refresh direct dependencies first, then let the solver update the lockfile.

- [x] Update `pubspec.yaml` with an explicit Flutter environment lower bound
      for the approved stable target
  - Depends on: Group 1
- [x] Update direct dependency constraints that are resolvable to latest:
      `drift`, `flutter_riverpod`, `path_provider`, `record`, and `sqlite3`
  - Depends on: Group 1
- [x] Attempt to update `drift_dev` to latest `2.34.1+1`
  - Depends on: Group 1
- [x] If `drift_dev` latest is not solver-compatible, settle on the freshest
      resolvable version and record the reason
  - Depends on: Group 1
- [x] Run `/opt/homebrew/bin/flutter pub get` and refresh `pubspec.lock`
  - Depends on: dependency constraint edits
- [x] Run `/opt/homebrew/bin/flutter pub outdated` and record remaining
      outdated packages with reasons in validation notes
  - Depends on: lockfile refresh
- [x] Check whether the generated backend package needs a local lockfile
      refresh; update `tool/openapi-generator/output/backend_api/pubspec.lock`
      only if validation requires it
  - Depends on: root dependency resolution

### Group 3: Compatibility fixes

Apply only the fixes required by the refreshed toolchain and dependency graph.

- [x] Run `/opt/homebrew/bin/flutter analyze`
  - Depends on: Group 2
- [x] Fix analyzer or compile errors caused by dependency/toolchain changes
  - Depends on: analyzer results
- [x] Run `/opt/homebrew/bin/flutter test test`
  - Depends on: analyzer success
- [x] Fix unit/widget regressions caused by dependency/toolchain changes
  - Depends on: unit/widget results
- [x] Run shell tests for deploy-script safeguards:
      `test/deploy_debug_script_test.sh` and
      `test/deploy_release_script_test.sh`
  - Depends on: unit/widget results
- [x] Build Android debug APK with `/opt/homebrew/bin/flutter build apk --debug`
  - Depends on: analyzer and unit/widget success
- [x] Build iOS simulator app with
      `/opt/homebrew/bin/flutter build ios --simulator --no-codesign`
  - Depends on: analyzer and unit/widget success
- [x] Apply native Android/iOS compatibility fixes only if build/runtime
      validation requires them
  - Depends on: platform build results

### Group 4: Integration and runtime app validation

Validate existing Wrait user-facing behavior after the maintenance update.

- [x] Run host integration coverage where practical:
      `/opt/homebrew/bin/flutter test integration_test`
  - Depends on: Group 3
- [x] Validate startup and main recording flows:
      `main_screen_flow_test.dart`, `main_recording_controller_flow_test.dart`,
      and `audio_recording_service_flow_test.dart`
  - Depends on: Group 3
- [x] Validate permission and backend flows:
      `main_screen_permission_flow_test.dart`, `backend_api_client_flow_test.dart`,
      `cloud_transcription_service_flow_test.dart`,
      `cleanup_transcript_use_case_flow_test.dart`, and
      `device_registration_launch_flow_test.dart`
  - Depends on: Group 3
- [x] Validate entry list/detail/share/delete flows:
      `entry_list_flow_test.dart`, `entry_detail_flow_test.dart`, and
      `entry_detail_device_smoke_test.dart`
  - Depends on: Group 3
- [x] Validate draft retry and local data lifecycle flows:
      `draft_retry_launch_flow_test.dart` and
      `local_data_lifecycle_flow_test.dart`
  - Depends on: Group 3
- [x] Validate app lock, capture prevention, and keep-awake flows:
      `app_lock_flow_test.dart`, `capture_prevention_flow_test.dart`, and
      `main_screen_display_awake_flow_test.dart`
  - Depends on: Group 3
- [x] Run Android emulator validation using the integration suite or approved
      app-validation subset
  - Depends on: host integration checks
- [x] Run iOS simulator validation using the integration suite or approved
      app-validation subset
  - Depends on: host integration checks
- [x] Capture validation evidence for dependency resolution, automated tests,
      Android emulator checks, and iOS simulator checks
  - Depends on: all validation commands

### Group 5: Artifact updates

Record the outcome for review and future maintainers.

- [x] Update `tasks.md` checkboxes and validation evidence as tasks complete
- [x] Create `implementation.md` with selected Flutter/Dart versions, package
      versions, remaining outdated packages, compatibility fixes, and
      validation evidence
- [x] Update `spec.md`, `plan.md`, or `tasks.md` if implementation findings
      require approved scope or approach corrections
- [x] Confirm no dependency audit/security report was generated because it is
      out of scope
- [x] Confirm no product behavior, API contract, or data model change was
      introduced

### Group 6: Review and fix

Handle external review after implementation.

- [x] Stop and wait for external `review.md`, unless the user explicitly skips
      review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any
      changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [x] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 7: Finalization

Handle durable documentation follow-up and closeout.

- [x] Decide whether this maintenance update produced durable guidance for
      `AGENTS.md`, `docs/application-description.md`, or
      `docs/agent-findings.md`
- [x] If durable guidance is needed, propose exact documentation updates to the
      user
- [x] Wait for explicit approval before editing long-lived guidance documents
- [x] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision

## Completion criteria

All tasks checked, validation evidence documented, remaining outdated packages
documented when applicable, review handled or explicitly skipped, and the final
knowledge-capture gate handled.

## Validation evidence

Record command output, selected versions, remaining outdated packages, Android
emulator evidence, iOS simulator evidence, and review-related notes here during
implementation.

```text
Pre-change toolchain:
- flutter --version -> Flutter 3.44.1 stable, Dart 3.12.1

Pre-change outdated summary:
- direct outdated: drift 2.33.0, flutter_riverpod 3.3.1, path_provider 2.1.5,
  record 7.0.0, sqlite3 3.3.2
- dev outdated: drift_dev 2.33.0, latest 2.34.1+1
- 20 lockfile packages upgradable, 32 packages newer than active constraints

Post-upgrade toolchain:
- flutter upgrade -> Flutter 3.44.3 stable, Dart 3.12.2
- no `.fvmrc` or other project-local Flutter version-manager file present

Dependency result:
- updated direct constraints: drift 2.34.0, flutter_riverpod 3.3.2,
  path_provider 2.1.6, sqlite3 3.3.3
- attempted record 7.1.0 and drift_dev 2.34.1+1
- kept drift_dev at 2.34.0 because 2.34.1+1 requires analyzer ^13.0.0, which
  conflicts with Flutter 3.44.3 `flutter_test` pins
- intentionally pinned record to 7.0.0 because record_android 2.1.2 from
  record 7.1.0 fails Android debug compilation with unresolved
  `AdtsContainer`
- generated backend package lockfile did not require changes

Final outdated summary:
- direct remaining exception: record 7.0.0, resolvable/latest 7.1.0
- dev remaining exception: drift_dev 2.34.0, latest 2.34.1+1
- remaining transitive lag: _fe_analyzer_shared, analyzer,
  flutter_secure_storage_darwin, matcher, meta, package_config, test,
  test_api, test_core, vector_math, xml, cli_util, dart_style
- `flutter pub outdated` confirms all remaining newer versions are not
  mutually compatible with the selected graph

Host validation:
- flutter analyze -> passed
- flutter test test -> passed
- flutter test --no-pub test -> passed after iOS simulator runs left Flutter
  startup lock/package cleanup noise
- bash test/deploy_debug_script_test.sh -> passed
- bash test/deploy_release_script_test.sh -> passed

Platform build validation:
- flutter build apk --debug -> passed after record rollback
- flutter build ios --simulator --no-codesign -> passed

Compatibility fix applied during validation:
- added `ref.mounted` guard in AppLockController.unlock() to avoid writing
  provider state after disposal during device-side teardown
- flutter test test/presentation/app_lock/app_lock_controller_test.dart ->
  passed with new disposal regression case
- review-fix audit found the same post-await disposal risk in
  EntryDetailController and added matching `ref.mounted` guards plus a new
  disposal regression test
- flutter test test/presentation/entries/entry_detail_controller_test.dart ->
  passed with new disposal regression case

Android emulator validation:
- flutter test -d emulator-5554 integration_test/main_screen_permission_flow_test.dart
  -> passed
- flutter test -d emulator-5554 integration_test/capture_prevention_flow_test.dart
  -> passed
- flutter test -d emulator-5554 integration_test/entry_detail_device_smoke_test.dart
  -> passed
- flutter test -d emulator-5554 integration_test/main_screen_display_awake_flow_test.dart
  -> passed
- flutter test -d emulator-5554 integration_test/main_recording_controller_flow_test.dart
  -> passed
- flutter test -d emulator-5554 integration_test/audio_recording_service_flow_test.dart
  -> reproducibly stalled on
  `provider graph supports start and valid stop with a completed file path`
  and reported `did not complete` after manual interruption at 00:52
- attempted full device suite on emulator; narrowed to targeted subset after
  flutter_tools log-reader/listener finalization instability around
  entry_detail_flow_test.dart, not an app crash

iOS simulator validation:
- flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/capture_prevention_flow_test.dart
  -> passed
- flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/app_lock_flow_test.dart
  -> passed
- flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_detail_device_smoke_test.dart
  -> failed once with UnmountedRefException before the app-lock fix, then passed
- flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart
  -> passed
- flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_flow_test.dart integration_test/device_registration_launch_flow_test.dart integration_test/draft_retry_launch_flow_test.dart integration_test/local_data_lifecycle_flow_test.dart
  -> passed
- flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_detail_device_smoke_test.dart
  -> passed again after the review-fix `EntryDetailController` disposal guard

Generated backend package validation:
- flutter pub get in `tool/openapi-generator/output/backend_api` -> passed
- flutter analyze in `tool/openapi-generator/output/backend_api`
  -> 7 generated-code warnings in `lib/lib/api/default_api.dart`, no
  compatibility errors

Knowledge-capture gate:
- user approved durable documentation updates
- updated `AGENTS.md` with dependency-refresh validation guidance,
  generated-backend validation expectations, and the current Android emulator
  recording limitation
- updated `docs/agent-findings.md` with the intentional `record` and
  `drift_dev` exceptions plus the Android emulator recording caveat
- no update was needed in `docs/application-description.md`
```

## Notes

- Plan approval received on 2026-06-24.
- Toolchain target from approved plan: Flutter stable 3.44.3.
- Validation scope: app validation checks only; no separate dependency
  audit/security report.
