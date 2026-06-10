# Tasks: Device Registration

> **Feature number:** 006
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-10

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

_Tasks are organized into sequential groups.
Tasks within the same group marked `[P]` can be worked on in parallel._

### Group 1: Foundation

_Set up the launch orchestration and shared session-state foundations._

- [x] Add or confirm the hashing support needed for backend-compatible device-ID normalization — `pubspec.yaml`
- [x] Create the launch registration orchestrator contract and implementation — `lib/domain/usecase/register_device_on_launch_use_case.dart`
- [x] Add Riverpod providers for the launch use case, session quota state, and lightweight warning logger — `lib/data/api/backend_providers.dart`

### Group 2: Core implementation

_Implement the main feature behavior._

- [x] Normalize newly resolved device IDs to a backend-compatible 64-character lowercase hash while preserving preexisting stored values unchanged — `lib/data/preferences/preferences_repository_impl.dart`
  - Depends on: Group 1
- [x] Trigger the non-blocking launch registration action from app startup without awaiting UI render — `lib/main.dart`
- [x] Update the launch registration use case to call backend registration, replace session quota only when valid quota is returned, preserve prior in-memory quota on silent partial success, and log failures without throwing — `lib/domain/usecase/register_device_on_launch_use_case.dart`
- [x] Wire the backend/provider graph so launch registration uses the existing backend client and preferences repository, and exposes session quota for future stories — `lib/data/api/backend_providers.dart`

### Group 3: Validation

_Add automated coverage and runtime verification._

- [x] Add or update preferences repository unit tests for hashed new IDs, hashed fallback IDs, stable reuse across repository re-creation, and unchanged preexisting stored values — `test/data/preferences/preferences_repository_impl_test.dart`
- [x] Add unit tests for launch registration success, silent success without quota, invalid-quota preservation, and logging-only failure handling — `test/data/api/register_device_on_launch_use_case_test.dart`
- [x] Implement `integration_test` coverage for launch-triggered registration success, relaunch reuse, and non-blocking transient failure against an in-process stub backend — `integration_test/device_registration_launch_flow_test.dart`
- [x] Verify `flutter analyze` completes successfully and record the result
- [x] Verify `flutter test` completes successfully and record the result
- [x] Verify the feature on an Android emulator, or record the approved exception
- [x] Verify the feature on an iOS simulator, or record the approved exception
- [x] Record all validation evidence, including emulator/simulator targets and integration-test commands, in this file

### Group 4: Review and fix

_Handle external review after implementation._

- [x] Create `implementation.md` with implementation notes and validation evidence
- [x] Stop and wait for external `review.md`, unless the user explicitly skips review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`, `tasks.md`, `implementation.md`, code, and tests when review changes scope, approach, or validation
- [x] Repeat the review/fix loop if the same `review.md` file is updated for another pass

### Group 5: Finalization

_Handle durable documentation follow-up and closeout._

- [x] Decide whether the feature produced durable learnings or long-lived product/architecture changes worth preserving
- [x] If needed, propose updates to `AGENTS.md`, `docs/application-description.md`, and `docs/agent-findings.md`
- [x] Wait for explicit approval before editing those long-lived guidance documents
- [x] Record whether the knowledge-capture gate resulted in updates or an explicit no-update decision

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

_Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete._

```text
$ flutter pub get
Resolving dependencies...
Changed 1 dependency! (`crypto` moved from transitive to direct dependency)

$ flutter analyze --no-pub
No issues found! (ran in 2.7s)

$ flutter test --no-pub test/data/preferences/preferences_repository_impl_test.dart test/data/api/register_device_on_launch_use_case_test.dart test/data/api/backend_client_test.dart test/data/api/backend_providers_test.dart
All tests passed! (31 tests)

$ flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/device_registration_launch_flow_test.dart
Xcode build done. 28.9s
All tests passed! (3 integration tests on iPhone 17 simulator)

$ emulator -avd Pixel_8_emulator -no-snapshot-load -no-boot-anim
Boot completed in 8994 ms

$ flutter test --no-pub -d emulator-5554 integration_test/device_registration_launch_flow_test.dart
Built build/app/outputs/flutter-apk/app-debug.apk
Installed on emulator-5554
All tests passed! (3 integration tests on Pixel_8_emulator)
```

## Notes

- `flutter analyze` was run with `--no-pub` after `flutter pub get` because a plain analyze invocation attempted to mutate `ios/Flutter/ephemeral/Packages/.packages` in this environment.
- The approved scope decision to avoid migrating preexisting stored device IDs is preserved: only newly resolved IDs are hashed into the backend-compatible 64-character form.
- External review was explicitly skipped by the user after implementation, so the review/fix loop was closed without a `review.md` pass.
- Knowledge capture resulted in updates to `docs/application-description.md` and `docs/agent-findings.md`; no `AGENTS.md` update was needed.
