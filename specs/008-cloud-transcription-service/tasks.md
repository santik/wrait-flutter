# Tasks: Cloud Transcription Service

> **Feature number:** 008
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-12

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

_Tasks are organized into sequential groups.
Tasks within the same group marked `[P]` can be worked on in parallel._

### Group 1: Service contracts and shared state

_Define the app-facing contract and prepare the shared dependencies the
implementation will use._

- [x] Create the cloud transcription contract, status types, success/failure result types, and narrowed failure enum for US-007 — `lib/data/transcription/transcription_service.dart`
- [x] Modify the shared quota state owner so both launch registration and cloud transcription can update one session quota provider without changing the underlying behavior — `lib/data/api/backend_providers.dart`
- [x] Update existing registration-focused tests and integration coverage to use the generalized shared quota provider if the provider naming or access pattern changes — `test/data/api/register_device_on_launch_use_case_test.dart`, `integration_test/device_registration_launch_flow_test.dart`

### Group 2: Cloud transcription implementation

_Implement the sequential live and draft transcription flows on top of the
existing recording and backend foundations._

- [x] Create the cloud transcription service implementation with sequential operation gating, live temp-file path generation, live start/stop flow ownership, and status callback emission — `lib/data/transcription/cloud_transcription_service.dart`
  - Depends on: Group 1
- [x] Implement backend-result adaptation inside the cloud transcription service, including failure-surface narrowing, valid-quota propagation from success and failure responses, and warning-level logging for retryable or unexpected failures — `lib/data/transcription/cloud_transcription_service.dart`
  - Depends on: Group 1
- [x] Implement detected-language normalization for backend values by sanitizing separators and case, applying lightweight locale-shaped validation, resolving to a supported canonical code when possible, and allowing success with `null` language when transcript text is usable — `lib/data/transcription/cloud_transcription_service.dart`
  - Depends on: Group 1
- [x] Implement live-versus-draft audio lifecycle rules so live temp files are deleted immediately on successful transcription, retained on failure as `audioDraftPath`, and caller-owned draft files remain untouched by draft transcription — `lib/data/transcription/cloud_transcription_service.dart`
  - Depends on: Group 1
- [x] Add Riverpod providers for temp-path generation, transcription logging, and the app-facing cloud transcription service wiring — `lib/data/transcription/transcription_providers.dart`
  - Depends on: Group 2 implementation tasks

### Group 3: Automated coverage

_Add deterministic tests for all in-scope US-007 service flows._

- [x] Add unit tests for sequential gating, status ordering, language normalization, failure mapping, quota propagation, and live/draft file lifecycle behavior — `test/data/transcription/cloud_transcription_service_test.dart`
  - Depends on: Group 2
- [x] Add fake-driven provider-graph integration coverage for the live success flow, live failure flow, invalid-language success flow, draft transcription flow, quota-bearing failure flow, and concurrent-request rejection — `integration_test/cloud_transcription_service_flow_test.dart`
  - Depends on: Group 2
- [x] Expand lower-level backend or language-helper tests only if implementation changes require new direct coverage for quota-bearing failure assumptions or normalization behavior — `test/data/api/backend_client_test.dart`, `test/domain/model/supported_language_test.dart`
  - Depends on: Group 2
- [x] Verify launch registration still updates the generalized shared session quota provider after the quota-state changes — `integration_test/device_registration_launch_flow_test.dart`
  - Depends on: Group 1

### Group 4: Validation

_Add automated coverage and runtime verification._

- [x] Run the approved `integration_test` coverage for every in-scope US-007 user flow and record the results — `integration_test/cloud_transcription_service_flow_test.dart`, `integration_test/device_registration_launch_flow_test.dart`
- [x] Run the planned lower-level automated tests and record the results — `test/data/transcription/cloud_transcription_service_test.dart`, affected existing tests
- [x] Verify the feature on an Android emulator with a real recording, stub-backend success, stub-backend failure, and shared-quota regression checks, then record the evidence
- [x] Verify the feature on an iOS simulator with a real recording, stub-backend success, stub-backend failure, and shared-quota regression checks, then record the evidence
- [x] Verify the project analysis and test suite complete successfully and record the command evidence

### Group 5: Review and fix

_Handle external review after implementation._

- [x] Create `implementation.md` with implementation notes and validation evidence
- [x] Stop and wait for external `review.md`, unless the user explicitly skips review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`, `tasks.md`, `implementation.md`, code, and tests when review changes scope, approach, or validation
- [x] Repeat the review/fix loop if the same `review.md` file is updated for another pass

### Group 6: Finalization

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
$ /opt/homebrew/bin/flutter analyze
No issues found!

$ /opt/homebrew/bin/flutter test --no-pub
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/cloud_transcription_service_flow_test.dart
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/device_registration_launch_flow_test.dart
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/cloud_transcription_service_flow_test.dart
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/device_registration_launch_flow_test.dart
All tests passed.

Ad hoc real-recording runtime verification with a stubbed transcription callback:
- Android emulator (`emulator-5554`): passed after granting `RECORD_AUDIO` to the installed app with `adb -s emulator-5554 shell pm grant com.wrait.app android.permission.RECORD_AUDIO`; the real recorder produced a non-empty file, the stubbed transcription succeeded, and the live audio file was deleted immediately afterward.
- iOS simulator (`491CD949-D3C0-4C4C-A6B9-15BAB1859156`): passed; the real recorder produced a non-empty file, the stubbed transcription succeeded, and the live audio file was deleted immediately afterward.

Post-review remediation coverage added:
- unit coverage for stop-without-start, concurrent live starts, fail-fast invalid draft uploads, broader language normalization inputs, and quota non-propagation on malformed success payloads
- provider-graph concurrency coverage now waits for an explicit upload-start signal to avoid race-driven hangs on Android and iOS
```

## Notes

- Branch creation could not be completed in this sandbox because `.git` refs are read-only here.
- The shared quota provider was generalized by adding `sessionRecordQuotaStateProvider` while keeping the old registration-specific name as a deprecated alias to avoid unnecessary churn.
- Lower-level backend transcription results now allow `detectedLanguage == null` so the new cloud transcription service can preserve usable transcript success when backend language normalization fails.
- Android emulator real-recording verification required an explicit `adb` microphone-permission grant for the installed test app before the runtime probe could complete successfully.
- In this environment, post-remediation `flutter test` was run with `--no-pub` because the plain command attempted iOS ephemeral package cleanup and failed before running the Dart tests.
- A second-pass `review.md` update was explicitly skipped by the user, so no additional remediation changes were made for that pass.
- Final knowledge capture resulted in durable updates to:
  - `docs/application-description.md`
  - `docs/agent-findings.md`
  - no `AGENTS.md` update was needed
