# Implementation Notes: Backend API Client

> **Feature number:** 005
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-09

---

## Summary

US-005 is implemented as a generated-plus-handwritten backend slice:

- `api/wrait-backend.yaml` is now the checked-in Flutter-side OpenAPI copy used
  as the direct generation input.
- `package.json` plus `tool/openapi-generator/backend-api-config.yaml` drive
  the official OpenAPI Generator CLI `dart-dio` workflow.
- `npm run build` now delegates to that generation workflow so the official
  generator path is part of the repo tooling entrypoint.
- The generator produces a dedicated Dart package at
  `tool/openapi-generator/output/backend_api` during local build/bootstrap
  rather than storing that output in git.
- Handwritten Flutter code wraps the generated layer to provide:
  - validated quota conversion
  - narrowed registration failure handling
  - richer transcription and cleanup failure mapping, including explicit
    request-too-large and quota-exceeded reasons
  - registration retry with exponential backoff
  - `X-Device-Id` injection through `PreferencesRepository`
  - `X-Proxy-Secret` injection through centralized `Dio` setup with explicit
    timeout configuration
  - Riverpod providers for the low-level client and the app-facing adapter

## Implemented files

- `api/wrait-backend.yaml`
- `package.json`
- `package-lock.json`
- `openapitools.json`
- `analysis_options.yaml`
- `.gitignore`
- `tool/openapi-generator/backend-api-config.yaml`
- `lib/data/api/generated/backend_api_generated.dart`
- `lib/data/api/record_quota_state.dart`
- `lib/data/api/backend_results.dart`
- `lib/data/api/backend_client.dart`
- `lib/data/api/backend_providers.dart`
- `test/data/api/record_quota_state_test.dart`
- `test/data/api/backend_client_test.dart`
- `test/data/api/backend_providers_test.dart`
- `integration_test/backend_api_client_flow_test.dart`
- `pubspec.yaml`

## Validation evidence

Successful automated validation:

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
Blocked in host-mode in this environment.

$ /opt/homebrew/bin/flutter test integration_test/backend_api_client_flow_test.dart -d emulator-5554
All tests passed! (Android emulator: `sdk gphone16k arm64`, Android 17 / API 37)

$ /opt/homebrew/bin/flutter test integration_test/backend_api_client_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156
All tests passed! (iOS simulator: `iPhone 17`, iOS 26.5)
```

## Notes

- The generated package now comes from the official OpenAPI Generator CLI
  `dart-dio` backend, while `lib/data/api/generated/backend_api_generated.dart`
  remains a thin compatibility bridge over that output.
- The generated package output is not tracked in git; `npm run build` is the
  required bootstrap step that recreates it before Flutter resolves the path
  dependency on a fresh clone.
- The second approved remediation pass added explicit `413`/`429` failure
  mapping, kept `502`/`504` explicitly grouped under
  `BackendFailureReason.backendUnavailable`, and pinned shared Dio timeout
  values at 15 seconds connect / 60 seconds send / 60 seconds receive.
- The adapter treats invalid quota payloads as unavailable data and allows
  callers to preserve last-known-good quota state outside the backend layer.
- The required Android emulator and iOS simulator verification completed
  successfully during this session after recovering local adb and
  CoreSimulator tooling.
- One external review pass has been completed and its approved remediation
  has been implemented; additional review/fix passes remain optional if the
  same `review.md` is updated again.
