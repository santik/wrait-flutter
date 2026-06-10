# Implementation Plan: Device Registration

> **Feature number:** 006
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-10

---

## Approach summary

Implement US-016 as a small app-start orchestration slice that reuses the
existing preferences-backed device identity and backend registration client
instead of inventing a second startup path. The app bootstrap in
`main.dart` will trigger one non-blocking registration action from the shared
`ProviderContainer` immediately before `runApp`, without awaiting completion,
so registration starts on every app launch while the UI remains free to render
normally. That action will resolve the current device ID, call the existing
backend `register()` operation, log failures without surfacing user-visible
errors, and push any valid returned quota into one in-memory quota state owner
that later stories can consume.

This approach satisfies the spec by keeping launch registration centralized,
reusing the retry behavior already present in the backend client, preserving
the last valid in-memory quota when registration succeeds without usable quota
data, and avoiding new persistence beyond the existing device-ID store.
Validation will combine app-level integration coverage for launch success,
relaunch reuse, and non-blocking failure with focused unit tests for
orchestration and newly resolved backend-compatible device-ID generation.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Launch trigger location | Start registration from `main.dart` using the already-bootstrapped `ProviderContainer` and an unawaited registration action | This guarantees the behavior runs on every app launch, remains route-agnostic, and does not make widget tests or routing responsible for startup side effects. |
| Registration orchestration layer | Add one small orchestrator in `lib/domain/usecase/` for launch registration | The orchestration is domain behavior rather than raw transport code: it coordinates backend registration, in-memory quota updates, and logging policy in one place instead of scattering side effects across bootstrap code. |
| Backend registration implementation | Reuse `WraitBackendClient.register()` as the only network call path | US-005 already owns retry policy and registration result mapping, so US-016 should build on that instead of duplicating HTTP behavior. |
| Quota state ownership | Introduce a single in-memory Riverpod-backed quota state owner under the backend API area | The approved spec requires launch-time quota updates but explicitly rejects persistence. A dedicated in-memory state owner is the smallest reusable surface for later backend-assisted stories. |
| Quota update policy | Replace quota state only when registration returns valid quota; keep the previous in-memory value when quota is absent or invalid | This exactly matches the approved clarified spec and avoids wiping useful state because of partial or malformed responses. |
| Failure handling | Log registration failures in the orchestration layer and do not surface UI errors in this story | Logging-only failure handling is an explicit clarified requirement, and keeping it in the orchestration layer avoids coupling launch logic to placeholder UI. |
| Device-ID compatibility | Change only newly resolved device IDs to a backend-compatible anonymous 64-character lowercase SHA-256 hex form; do not migrate previously stored values | This matches the approved scope: future/newly resolved values should satisfy the backend contract, while existing stored IDs remain untouched even if some older installs keep failing non-blockingly. |
| Device-ID storage mechanism | Keep using the existing preferences repository and local preferences storage for the persisted identifier | The stored value will be an anonymous hashed identifier rather than a raw platform ID, so reusing the existing persistence path is simpler than introducing a second secure-storage dependency for this story. |
| Hash input strategy | Derive the stored identifier from the resolved platform-or-fallback source using a stable app-scoped salt before persisting it | This keeps the stored identifier opaque to the rest of the app, aligns with the Android reference behavior, and satisfies the backend’s 64-hex contract for newly resolved IDs. |
| Registration-complete tracking | Do not add a persisted “device registered” flag | The spec requires registration on every app launch, so remembering prior success would create behavior the story does not want. |
| Logging testability | Inject or centralize the warning logger behind a small callable dependency/provider | This keeps the implementation simple while still allowing unit tests to verify that failed launch registration produces diagnostic output. |
| Validation approach | Cover app-start success, relaunch reuse, and non-blocking failure with `integration_test`, then add unit coverage for orchestration and device-ID normalization | The story is mostly startup plumbing, so app-level integration evidence plus small deterministic unit tests is the strongest validation mix. |
| Validation exception | None requested | The story can satisfy the default `integration_test` and dual-platform verification requirements. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `pubspec.yaml` | Modify | Add any hashing dependency needed for backend-compatible anonymous device-ID generation if the implementation uses a package rather than handwritten digest logic |
| `lib/main.dart` | Modify | Trigger the non-blocking app-launch registration action from the shared startup container before `runApp` |
| `lib/domain/usecase/register_device_on_launch_use_case.dart` | Create | Centralize launch registration orchestration, quota update policy, and logging-only failure handling |
| `lib/data/api/backend_providers.dart` | Modify | Add providers for the launch registration orchestrator, the in-memory quota state owner, and any lightweight logging dependency |
| `lib/data/preferences/preferences_repository_impl.dart` | Modify | Normalize newly resolved device IDs to the backend-compatible anonymous hash form while preserving existing stored values untouched |
| `test/data/preferences/preferences_repository_impl_test.dart` | Modify | Update device-ID expectations for backend-compatible hashing, verify stable reuse of stored values, and cover the no-migration behavior for preexisting stored IDs |
| `test/data/api/register_device_on_launch_use_case_test.dart` | Create | Verify success-path quota updates, silent success without quota, invalid-quota preservation, and logging-only failure handling |
| `integration_test/device_registration_launch_flow_test.dart` | Create | Exercise launch-triggered registration against an in-process stub backend for success, relaunch reuse, and non-blocking failure flows |
| `specs/006-device-registration/implementation.md` | Create later | Record implementation details and validation evidence during the implementation phase |

## API contract details

Implementation-specific rules on top of the approved spec:

- The story continues to consume the existing `POST /api/register` contract
  through the US-005 backend client surface.
- Registration will be initiated once per app launch from startup code and
  will not be awaited before the Flutter UI is rendered.
- Launch orchestration will treat:
  - `RegistrationSuccess(quota: validQuota)` as success plus in-memory quota
    replacement
  - `RegistrationSuccess(quota: null)` as silent success with no quota change
  - `RegistrationFailure(...)` as warning-level diagnostic logging with no
    user-visible error and no quota replacement
- Transient retry behavior remains owned by `WraitBackendClient.register()`
  and stays at three attempts with exponential backoff for timeout,
  connectivity, and 5xx cases.
- No new HTTP endpoints, request headers, or backend payload shapes are added
  in this story.
- No persisted quota state is introduced.
- No migration path will be added for older stored device IDs that do not
  match the backend contract; those installs may continue to fail
  non-blockingly and remain outside this story’s scope.

## Data model changes

This story introduces launch-oriented in-memory state and revises the shape of
newly resolved persisted device IDs, but it does not add a new database schema
or any quota persistence.

### Before

```dart
// Device registration exists only as a backend client capability.
// No app-start orchestration or shared in-memory quota owner exists yet.
//
// PreferencesRepositoryImpl currently persists whatever device ID source it
// resolves first, including legacy stored values and a 32-character fallback.
```

### After

```dart
class RegisterDeviceOnLaunchUseCase {
  Future<void> call();
}

// Riverpod-owned in-memory state for the current app session only.
typedef RecordQuotaSessionState = RecordQuotaState?;

// Newly resolved device IDs are normalized to a backend-compatible anonymous
// 64-character lowercase SHA-256 hex string before first persistence.
```

### Migration

No migration is required or planned.

Existing stored device IDs remain as-is by explicit approved scope decision.

## Test strategy

Validation will focus on app-start behavior rather than UI rendering changes:

- app-level integration coverage that drives registration from a real startup
  container and verifies the resulting quota/session behavior against an
  in-process stub backend
- unit coverage for orchestration rules, especially quota preservation and
  logging-only failure handling
- unit coverage for the revised device-ID normalization behavior in the
  preferences repository
- Android emulator and iOS simulator execution to prove startup wiring and the
  integration tests behave correctly on both supported platforms

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| App launch triggers registration, allows the shell to render without waiting for the backend, and stores valid returned quota in session state | Integration | `integration_test/device_registration_launch_flow_test.dart` |
| A second app launch reuses the same persisted device ID, triggers registration again, and starts with no carried-over quota until the new launch response arrives | Integration | `integration_test/device_registration_launch_flow_test.dart` |
| Launch-time transient registration failure does not block app usage and leaves quota unchanged while still completing the bounded retry cycle | Integration | `integration_test/device_registration_launch_flow_test.dart` |
| The launch registration use case replaces in-memory quota on successful registration with valid quota | Unit | `test/data/api/register_device_on_launch_use_case_test.dart` |
| The launch registration use case preserves the previous in-memory quota when success returns no quota | Unit | `test/data/api/register_device_on_launch_use_case_test.dart` |
| The launch registration use case preserves the previous in-memory quota when success returns invalid quota | Unit | `test/data/api/register_device_on_launch_use_case_test.dart` |
| The launch registration use case logs and swallows registration failure without throwing or clearing quota | Unit | `test/data/api/register_device_on_launch_use_case_test.dart` |
| `getDeviceId()` stores newly resolved platform-backed IDs in backend-compatible 64-character lowercase hash form | Unit | `test/data/preferences/preferences_repository_impl_test.dart` |
| `getDeviceId()` stores newly generated fallback IDs in backend-compatible 64-character lowercase hash form and reuses them across repository re-creation | Unit | `test/data/preferences/preferences_repository_impl_test.dart` |
| `getDeviceId()` returns existing stored values unchanged, even when they predate the backend-compatible format | Unit | `test/data/preferences/preferences_repository_impl_test.dart` |
| `flutter analyze` completes cleanly after startup and provider wiring changes | Static analysis | Command evidence recorded in `tasks.md` |
| `flutter test` passes after the new launch-registration and preferences tests are added | Test suite | Command evidence recorded in `tasks.md` |

### Android emulator verification

1. Launch the app on an Android emulator and confirm the root shell renders
   successfully with the new startup registration wiring in place.
2. Run `integration_test/device_registration_launch_flow_test.dart` on the
   Android emulator so the real app container performs launch registration
   against the in-process stub backend.
3. Record the passing emulator command output and the verified emulator target
   in `tasks.md`.

### iOS simulator verification

1. Launch the app on an iOS simulator and confirm the root shell renders
   successfully with the new startup registration wiring in place.
2. Run `integration_test/device_registration_launch_flow_test.dart` on the
   iOS simulator so the real app container performs launch registration
   against the in-process stub backend.
3. Record the passing simulator command output and the verified simulator
   target in `tasks.md`.

### Validation exception request

No exception requested.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This story is likely to produce durable follow-up for
  `docs/agent-findings.md` around launch-side-effect placement, in-memory quota
  ownership, and backend-compatible device-ID normalization expectations.

## Integration notes

- Startup integration will continue to use the explicit `ProviderContainer`
  bootstrap path in [lib/main.dart](/Users/alexander/projects/wrait/write-flutter/lib/main.dart)
  rather than moving side effects into route builders or placeholder screens.
- The new launch registration orchestrator will consume:
  - `WraitBackendClient` from
    [lib/data/api/backend_providers.dart](/Users/alexander/projects/wrait/write-flutter/lib/data/api/backend_providers.dart)
  - the existing preferences repository from
    [lib/data/preferences/preferences_providers.dart](/Users/alexander/projects/wrait/write-flutter/lib/data/preferences/preferences_providers.dart)
  - the new in-memory quota state owner from the backend provider layer
- The home and shell placeholder UI can remain unchanged in this story because
  no user-visible registration messaging or quota presentation is required yet.
- Later stories such as draft retry, transcription, and quota-aware messaging
  should read the shared in-memory quota state instead of caching registration
  results independently.
- Because the app currently has no general logging abstraction, the plan keeps
  logging lightweight and local to the launch orchestration path.

## Rollout & migration

This is an additive startup-behavior story.

- No feature flags are needed.
- No backend contract migration is needed.
- No local quota migration exists because quota remains in-memory only.
- Older installs that already persisted a non-backend-compatible device ID are
  an accepted out-of-scope edge case and may keep failing registration
  non-blockingly until local app data is reset.
- The main rollout concern is unexpected startup coupling; keeping the work in
  one use case triggered from `main.dart` contains that risk.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Startup registration accidentally blocks the first frame or app interactivity | Medium | High | Trigger the registration action unawaited from startup code, add integration coverage that asserts the shell renders before backend completion, and validate on both platforms |
| Registration side effects become route-specific or widget-lifecycle-dependent | Medium | High | Keep launch orchestration in `main.dart` plus a dedicated use case rather than in screens or router builders |
| Newly resolved device IDs still fail the backend’s 64-hex contract | Medium | High | Normalize all newly resolved IDs through one hashing path and cover both platform-backed and fallback-backed resolution in repository tests |
| Older installs with legacy stored IDs continue to fail registration | Medium | Medium | Treat as an explicit out-of-scope compatibility gap for this story, keep failures non-blocking, and document the limitation in validation notes |
| Quota state is accidentally cleared on partial success or failure | Medium | Medium | Centralize quota update rules in the launch use case and unit-test both silent-success-without-quota and failure preservation cases |
| Logging is hard to verify and failures become silent in practice | Low | Medium | Route logging through a small injectable callable/provider so tests can assert warning emission without adding a full logging framework |

## Open items from spec

None.
