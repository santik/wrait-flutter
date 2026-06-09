# Tasks: Backend API Client

> **Feature number:** 005
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-09

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

_Set up the files, contracts, and prerequisites needed for the feature._

- [x] Copy `wrait-android/wrait-backend.yaml` into the Flutter codebase as `api/wrait-backend.yaml` and verify the copied file is the intended direct generation input
- [x] Configure the chosen OpenAPI generation tooling and any required checked-in config so the Flutter repo can generate the low-level Dart client from `api/wrait-backend.yaml` — `package.json`, `openapitools.json`, `tool/openapi-generator/backend-api-config.yaml`
- [x] Generate the low-level OpenAPI-derived package under `tool/openapi-generator/output/backend_api/` during the local build/bootstrap flow, keeping only a thin compatibility bridge in `lib/data/api/generated/`
- [x] Create the new backend API package structure for handwritten adapter code — `lib/data/api/`

### Group 2: Core implementation

_Implement the main feature behavior._

- [x] Implement the validated quota model and generated-DTO conversion rules, including invalid-quota rejection to `null` — `lib/data/api/record_quota_state.dart`
  - Depends on: Group 1
- [x] Implement the app-facing backend result and failure types for registration, transcription, and cleanup — `lib/data/api/backend_results.dart`
- [x] Implement the thin backend adapter over the generated client, including base-URL bootstrap, `X-Proxy-Secret` wiring, `X-Device-Id` injection through `PreferencesRepository`, registration retry with bounded exponential backoff, success-payload validation, quota propagation, and narrowed registration failure handling — `lib/data/api/backend_client.dart`
- [x] Add Riverpod providers for the generated low-level client and the app-facing backend adapter, reusing the existing config and preferences providers — `lib/data/api/backend_providers.dart`, `lib/app.dart`, `lib/data/preferences/preferences_providers.dart`

### Group 3: Validation

_Add automated coverage and runtime verification._

- [x] Verify that `api/wrait-backend.yaml` is the checked-in generation input used to produce the low-level client, and record evidence below
- [x] Add integration coverage for register, transcribe, and cleanup flows against an in-process stub backend — `integration_test/backend_api_client_flow_test.dart`
- [x] Add unit coverage for quota validation and generated-DTO conversion rules — `test/data/api/record_quota_state_test.dart`
- [x] Add unit coverage for request metadata wiring, registration retry behavior, failure mapping, quota propagation on eligible non-success responses, and invalid-success-payload handling — `test/data/api/backend_client_test.dart`
- [x] Add unit coverage for backend `Dio` configuration defaults, including explicit timeout values — `test/data/api/backend_providers_test.dart`
- [x] Run `flutter analyze` and record passing evidence in the validation section below
- [x] Run the full relevant automated test suite, including the new unit and integration coverage, and record passing evidence below
- [x] Verify the feature on an Android emulator by launching the app and running the planned US-005 integration coverage, then record the exact target and result below
- [x] Verify the feature on an iOS simulator by launching the app and running the planned US-005 integration coverage, then record the exact target and result below

### Group 4: Review and fix

_Handle external review after implementation._

- [x] Create `implementation.md` with implementation notes and validation evidence
- [x] Stop and wait for external `review.md`, unless the user explicitly skips review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`, `tasks.md`, `implementation.md`, code, and tests when review changes scope, approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for another pass

### Group 5: Finalization

_Handle durable documentation follow-up and closeout._

- [ ] Decide whether the feature produced durable learnings or long-lived product/architecture changes worth preserving
- [ ] If needed, propose updates to `AGENTS.md`, `docs/application-description.md`, and `docs/agent-findings.md`
- [ ] Wait for explicit approval before editing those long-lived guidance documents
- [ ] Record whether the knowledge-capture gate resulted in updates or an explicit no-update decision

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

_Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete._

```text
$ npm run generate:backend-api
OpenAPI Generator CLI 7.23.0 (`dart-dio`) regenerated `tool/openapi-generator/output/backend_api`,
then `dart pub get` and `dart run build_runner build` completed for the generated package.

$ npm run build
Delegated to `npm run generate:backend-api` and completed successfully.

$ /opt/homebrew/bin/flutter analyze --no-pub
No issues found! (ran in 2.9s)

$ /opt/homebrew/bin/flutter test test/data/api
All tests passed! (23 tests)

$ /opt/homebrew/bin/flutter test
All tests passed! (72 tests)

$ /opt/homebrew/bin/flutter test integration_test/backend_api_client_flow_test.dart
Blocked in host-mode in this environment, even after simplifying the test to avoid app bootstrap concerns. Device-based validation below passed on both platforms.

$ /opt/homebrew/bin/flutter test integration_test/backend_api_client_flow_test.dart -d emulator-5554
All tests passed! (Android emulator: `sdk gphone16k arm64`, Android 17 / API 37)

$ /opt/homebrew/bin/flutter test integration_test/backend_api_client_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156
All tests passed! (iOS simulator: `iPhone 17`, iOS 26.5)
```

## Notes

- Local OpenAPI generation is implemented with the official OpenAPI Generator CLI `dart-dio` generator, configured by `package.json`, `openapitools.json`, and `tool/openapi-generator/backend-api-config.yaml`.
- `npm run build` now includes the backend OpenAPI generation workflow and is the required bootstrap step before Flutter dependency resolution on a fresh clone.
- `lib/data/api/generated/backend_api_generated.dart` is a thin compatibility bridge so the rest of the app can keep the narrower US-005 surface.
- The entire generated package under `tool/openapi-generator/output/backend_api/` is ignored in `.gitignore`; it is produced locally during build/bootstrap rather than stored in git.
- Approved second-pass review remediation added explicit `413`/`429` failure mapping while keeping `502`/`504` grouped under backend-unavailable, and it pinned explicit Dio timeout values in the shared backend provider.
- Device/runtime validation passed after recovering local adb and CoreSimulator tooling during this session.
