# Implementation Plan: Backend API Client

> **Feature number:** 005
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-09

---

## Approach summary

Implement US-005 as a thin Flutter-side adapter over code generated from a
checked-in copy of the backend OpenAPI contract inside the Flutter codebase.
The existing contract file at `wrait-android/wrait-backend.yaml` will first be
copied into the Flutter project, and the copied file will become the direct
generation input for this story's generated client layer. The generated layer
will own as much of the HTTP contract as possible, including endpoint method
signatures, request DTOs, response DTOs, and serialization. Handwritten code
will stay narrowly focused on runtime configuration, device-ID resolution,
request header wiring, registration retry behavior, quota validation, and
translation from transport/generated responses into a small application-facing
result surface that later stories can consume safely.

This approach satisfies the spec by keeping the OpenAPI contract as the source
of truth for request and response shapes, maximizing generated code reuse, and
keeping only the behavioral rules that cannot be expressed in the contract
itself in a small adapter layer. Validation will combine integration coverage
for the three in-scope backend operations with focused unit tests for retry,
quota validation, and error mapping, plus explicit verification that the copied
contract remains the expected generation input.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| OpenAPI source of truth | Copy `wrait-android/wrait-backend.yaml` into the Flutter codebase and use that checked-in copy as the direct generation input for this story | The clarified spec requires the existing OpenAPI contract to define the shapes, and the user explicitly wants the YAML copied into the Flutter codebase. |
| Generation strategy | Use the official OpenAPI Generator CLI `dart-dio` generator to emit a dedicated Dart package under `tool/openapi-generator/output/backend_api`, then keep a small compatibility bridge in `lib/data/api/generated/` | This replaces the custom local generator with a well-established upstream tool while preserving the narrower app-facing surface approved for US-005. |
| HTTP stack | Use `dio` as the transport used by the generated client and the thin adapter layer | `plan/us_005.md` explicitly requires `dio`, and the current project already depends on it. |
| Handwritten adapter scope | Keep handwritten code limited to client bootstrap, device-ID/header injection, quota validation, retry, and result/error mapping | These behaviors are app-specific policy rather than raw OpenAPI schema, so they belong outside generated code. |
| Request identity wiring | Resolve the device ID through the existing `PreferencesRepository` and attach it to every generated operation call | US-004 already established one stable app device ID contract, so US-005 should reuse it rather than creating a second identity path. |
| Proxy secret wiring | Read the proxy secret from `AppConfig` and apply it centrally when constructing the low-level client | This keeps secrets out of call sites and guarantees every request carries the required auth header. |
| Registration failure surface | Expose a narrower registration failure result than the richer failure mapping used for transcription and cleanup | The clarified spec explicitly allows a narrower registration failure surface. |
| Quota handling | Convert generated quota DTOs into a validated `RecordQuotaState?`, returning `null` for invalid data and preserving caller-controlled last-known-good state | This matches the Android reference behavior and the approved spec requirement. |
| Retry policy | Apply bounded exponential backoff only to registration for transient timeout, connectivity, and backend-unavailable failures | The story requires retry only for registration, and keeping that policy scoped avoids surprising behavior in the user-facing transcription flow. |
| Provider wiring | Add Riverpod providers for the generated low-level client and the app-facing backend adapter | This matches the project’s existing bootstrap and dependency-injection patterns. |
| Validation approach | Add integration coverage for register/transcribe/cleanup against an in-process stub backend plus unit coverage for mapping and retry edge cases | This story is infrastructure-heavy, so real client/server contract exercises and focused unit tests provide stronger evidence than UI-only checks. |
| Migration behavior | No data or schema migration | The story is additive and only introduces backend communication infrastructure. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `pubspec.yaml` | Modify | Add the generated backend package as a path dependency and keep `integration_test` support needed for this story |
| `package.json` | Create | Pin the official OpenAPI Generator CLI wrapper and expose the reproducible generation command |
| `package-lock.json` | Create | Lock the Node-based OpenAPI generator tooling dependency graph |
| `openapitools.json` | Create | Pin the selected upstream OpenAPI Generator CLI version used by the local wrapper |
| `.gitignore` | Modify | Ignore transient OpenAPI-generator byproducts that do not need to be committed |
| `api/wrait-backend.yaml` | Create | Checked-in Flutter-side copy of the backend OpenAPI contract used as the direct generation input for this story |
| `tool/openapi-generator/backend-api-config.yaml` | Create | Checked-in config for the official OpenAPI Generator CLI `dart-dio` run |
| `tool/openapi-generator/output/backend_api/` | Create at build time | Official generated Dart package derived from `api/wrait-backend.yaml`, produced locally during the build/bootstrap flow rather than committed to git |
| `lib/data/api/` | Create | New backend API package for the compatibility bridge and handwritten adapter code |
| `lib/data/api/generated/` | Create | Thin compatibility bridge over the official generated package so the rest of the app can keep the approved US-005 surface |
| `lib/data/api/record_quota_state.dart` | Create | App-facing validated quota model and generated-DTO-to-app conversion rules |
| `lib/data/api/backend_client.dart` | Create | Thin app-facing adapter for registration, transcription, and cleanup operations |
| `lib/data/api/backend_results.dart` | Create | Small result/failure types for registration, transcription, and cleanup callers |
| `lib/data/api/backend_providers.dart` | Create | Riverpod providers for the generated low-level client and app-facing adapter |
| `lib/app.dart` | Modify | Reuse the existing `appConfigProvider` from the backend provider graph |
| `lib/data/preferences/preferences_providers.dart` | Modify | Reuse the existing preferences repository provider from the backend provider graph if needed for injection ergonomics |
| `test/data/api/record_quota_state_test.dart` | Create | Validate quota acceptance/rejection rules and DTO conversion behavior |
| `test/data/api/backend_client_test.dart` | Create | Verify result mapping, retry behavior, request metadata wiring, and failure translation with stubbed transport |
| `integration_test/backend_api_client_flow_test.dart` | Create | Exercise register, transcribe, and cleanup flows end-to-end against an in-process stub backend using the generated client plus adapter |
| `specs/005-backend-api-client/implementation.md` | Create later | Record implementation details and validation evidence during the implementation phase |

The official generator workflow also requires a checked-in config and a Node
tooling entrypoint so regeneration stays explicit and reproducible inside the
Flutter repo.

## API contract details

Implementation-specific rules on top of the OpenAPI contract:

- The generated client will be built from the copied Flutter-side contract
  file, committed to the repo, and not generated dynamically at runtime.
- The low-level client will target the base URL from `AppConfig.backendUrl`.
- `X-Proxy-Secret` will be attached centrally from `AppConfig.proxySecret`.
- The shared `Dio` instance will use explicit transport timeouts:
  - `connectTimeout`: 15 seconds
  - `sendTimeout`: 60 seconds
  - `receiveTimeout`: 60 seconds
- `X-Device-Id` will be resolved from `PreferencesRepository.getDeviceId()`
  and attached to every backend operation.
- Registration will expose:
  - success with optional validated quota
  - failure with a narrowed reason surface suitable for launch-time callers
- Transcription will expose:
  - success with transcript, detected language, and optional validated quota
  - failure mapped to app-meaningful reasons such as timeout,
    no-internet/network, request-too-large, quota-exceeded, proxy-auth
    failure, backend unavailable, and generic API failure
- Cleanup will expose:
  - success with cleaned text and optional validated quota
  - failure mapped to the same app-meaningful categories as transcription
- HTTP `502` and `504` will remain intentionally grouped under
  backend-unavailable rather than widening the failure surface further.
- When the backend includes quota in success or quota-related non-success
  responses, the adapter will attempt to validate and surface it.
- Invalid success payloads, such as blank transcript or blank cleaned text,
  will be treated as failure rather than as successful operations with bad
  content.
- Registration retries will use exponential backoff with at most three
  attempts total and no retries for non-transient 4xx responses.

## Data model changes

This story adds new backend result contracts and a validated quota model
without changing any existing entry or preference persistence schema.

### Before

```dart
// No Flutter backend API client package exists yet.
// Later stories only have planning references to backend registration,
// transcription, and cleanup behavior.
```

### After

```dart
sealed class RegistrationResult {
  const RegistrationResult();
}

sealed class TranscriptionResult {
  const TranscriptionResult();
}

sealed class CleanupResult {
  const CleanupResult();
}

class RecordQuotaState {
  final int limit;
  final int count;
  final int remaining;
  final DateTime resetAt;
}
```

### Migration

No migration is required.

## Test strategy

Validation will cover three levels:

- contract-level integration coverage of the generated client plus adapter
  against an in-process stub backend
- unit coverage of app-specific behavior that generation does not provide,
  especially quota validation, retry policy, and failure mapping
- Android emulator and iOS simulator execution to prove the backend client
  wiring does not break app launch and that the integration coverage can run in
  both supported runtimes

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| The copied Flutter-side OpenAPI contract is present and usable as the generation input for the backend client | Unit / generation verification | Command or file evidence recorded in `tasks.md` |
| Registration flow succeeds against a stub backend and returns validated quota when present | Integration | `integration_test/backend_api_client_flow_test.dart` |
| Transcription flow uploads multipart audio using the OpenAPI-defined field names and returns transcript, detected language, and validated quota | Integration | `integration_test/backend_api_client_flow_test.dart` |
| Cleanup flow sends the OpenAPI-defined JSON body and returns cleaned text plus validated quota | Integration | `integration_test/backend_api_client_flow_test.dart` |
| Quota DTO conversion accepts internally consistent values | Unit | `test/data/api/record_quota_state_test.dart` |
| Quota DTO conversion rejects invalid negative or over-limit values and returns `null` | Unit | `test/data/api/record_quota_state_test.dart` |
| Registration retries transient timeout failures with bounded exponential backoff and succeeds when a later attempt succeeds | Unit | `test/data/api/backend_client_test.dart` |
| Registration stops retrying after the configured maximum attempts and returns failure | Unit | `test/data/api/backend_client_test.dart` |
| Registration does not retry non-transient 4xx failures | Unit | `test/data/api/backend_client_test.dart` |
| Transcription maps HTTP 401 to proxy-auth failure | Unit | `test/data/api/backend_client_test.dart` |
| Cleanup maps HTTP 401 to proxy-auth failure | Unit | `test/data/api/backend_client_test.dart` |
| Transcription and cleanup map HTTP 5xx to backend-unavailable failure | Unit | `test/data/api/backend_client_test.dart` |
| Transcription and cleanup map connection errors to no-internet or network failure | Unit | `test/data/api/backend_client_test.dart` |
| Timeout errors map to the timeout-specific failure type | Unit | `test/data/api/backend_client_test.dart` |
| HTTP `413` maps to the request-too-large failure type for transcription and cleanup | Unit | `test/data/api/backend_client_test.dart` |
| HTTP `429` maps to the quota-exceeded failure type while still surfacing valid quota data | Unit | `test/data/api/backend_client_test.dart` |
| HTTP `502` and `504` remain explicitly grouped under backend-unavailable | Unit | `test/data/api/backend_client_test.dart` |
| Shared backend Dio configuration applies the explicit base URL, proxy header, and timeout values | Unit | `test/data/api/backend_providers_test.dart` |
| Quota included in eligible non-success responses is surfaced when valid | Unit | `test/data/api/backend_client_test.dart` |
| Blank transcript or blank cleaned text is treated as failure | Unit | `test/data/api/backend_client_test.dart` |
| App-wide regression suite continues to pass after backend provider wiring is added | Test suite | Command evidence recorded in `tasks.md` |
| `flutter analyze` completes cleanly after the new API package, generation output, and tests are added | Static analysis | Command evidence recorded in `tasks.md` |

### Android emulator verification

1. Launch the app on an Android emulator and confirm startup still succeeds
   after the new backend providers and generated client dependencies are wired.
2. Run the US-005 integration test target on the Android emulator so the
   generated client and adapter execute register, transcribe, and cleanup
   against the in-process stub backend.
3. Record passing command evidence in `tasks.md`, including the emulator target
   used and the integration test result.

### iOS simulator verification

1. Launch the app on an iOS simulator and confirm startup still succeeds after
   the new backend providers and generated client dependencies are wired.
2. Run the US-005 integration test target on the iOS simulator so the
   generated client and adapter execute register, transcribe, and cleanup
   against the in-process stub backend.
3. Record passing command evidence in `tasks.md`, including the simulator
   target used and the integration test result.

### Validation exception request

No exception requested.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This story is likely to produce durable guidance for
  `docs/agent-findings.md` around OpenAPI regeneration, generated-code
  ownership boundaries, and backend quota/error-mapping conventions.

## Integration notes

- The new backend adapter will consume `AppConfig` from
  [lib/app.dart](/Users/alexander/projects/wrait/write-flutter/lib/app.dart)
  and the existing preferences/device-ID path from
  [lib/data/preferences/preferences_providers.dart](/Users/alexander/projects/wrait/write-flutter/lib/data/preferences/preferences_providers.dart).
- The generated code will use the checked-in Flutter-side copy of the backend
  contract at [api/wrait-backend.yaml](/Users/alexander/projects/wrait/write-flutter/api/wrait-backend.yaml)
  rather than duplicating endpoint payloads by hand.
- The copied Flutter-side contract should stay synchronized with the original
  file at [wrait-android/wrait-backend.yaml](/Users/alexander/projects/wrait/write-flutter/wrait-android/wrait-backend.yaml)
  until the repository adopts a single shared contract location.
- Later stories such as device registration, cloud transcription, and cleanup
  should depend on the app-facing adapter layer, not on raw generated DTOs or
  direct `dio` calls.
- Because the current OpenAPI contract defines transcription as multipart audio
  upload without a language field, US-005 will follow that contract exactly.
  Any future backend contract change to add transcription language must start
  with updating the OpenAPI file and regenerating the client.

## Rollout & migration

This is an additive infrastructure story.

- No feature flags are needed.
- No local data migration is needed.
- The main rollout concern is drift between the original Android-side YAML, the
  copied Flutter-side YAML, and the generated output, so the implementation
  should keep regeneration inputs and outputs explicit in the repo.
- Backward-compatibility risk is low because no Flutter runtime code currently
  depends on a backend client package.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| The copied Flutter-side YAML drifts from the original Android-side YAML | Medium | High | Copy the file explicitly during implementation, treat the Flutter-side copy as the generation input, and document the synchronization requirement in implementation evidence and agent findings if needed |
| Generated path dependency is absent on a fresh clone until generation runs | High | Medium | Make `npm run build` the required bootstrap step before Flutter dependency resolution and keep the app-facing compatibility bridge stable once generation completes |
| Generated DTO field naming differs from the app-facing contract expected by later stories | Medium | Medium | Hide generated types behind thin handwritten result adapters and keep later features depending on app-facing result models only |
| Header wiring is applied inconsistently and some requests miss `X-Device-Id` or `X-Proxy-Secret` | Low | High | Centralize client construction and cover request metadata in both unit and integration tests |
| Retry logic accidentally retries non-transient errors and slows user-facing flows | Medium | Medium | Scope retry to registration only and unit-test retry eligibility explicitly |
| Quota parsing accepts invalid data and corrupts later quota state | Medium | High | Keep quota validation in one dedicated conversion layer with exhaustive invalid-value tests |
| Integration tests become flaky if they depend on external networking | Low | High | Use an in-process stub backend so tests stay local, deterministic, and offline-capable |

## Open items from spec

None.
