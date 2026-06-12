# Implementation Plan: Cloud Transcription Service

> **Feature number:** 008
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-12

---

## Approach summary

Implement US-007 as one app-facing cloud transcription service layered over the
completed audio-recording service and the existing backend client instead of
adding UI-driven orchestration early. The new service will own the live
best-mode flow boundary for this story: start recording into a service-owned
temporary audio file, emit `RecordingStarted` with the recording hard-cap
deadline, stop the recording on user request, emit `Uploading`, submit the
captured file to the existing backend transcription operation, normalize the
backend language into an optional supported canonical code, update the shared
session quota state whenever valid quota arrives, delete the live recording
file immediately on successful transcription, and retain the file path when
transcription fails so later draft handling can reuse it.

This approach satisfies the approved spec by keeping the live flow linear and
sequential, collapsing transport connectivity issues into the narrower
story-specific failure surface without rewriting the backend client, and
reusing the existing recording and backend foundations rather than duplicating
capture or HTTP logic. Validation will combine deterministic unit tests,
fake-driven `integration_test` coverage for every in-scope service flow, and
Android emulator plus iOS simulator runtime verification against the real
recording plugin with a local stub backend.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| App-facing boundary | Add a `TranscriptionService` contract plus a `CloudTranscriptionService` implementation under `lib/data/transcription/` | The story reference is service-oriented, and a small app-facing contract lets later state-machine stories depend on one stable best-mode surface instead of coordinating recording and backend calls separately. |
| Layer placement | Keep the cloud transcription implementation in `data` and reuse existing `data/audio` and `data/api` dependencies directly | The service is composition over existing plugin/network infrastructure, and the repo’s current pattern already keeps app-facing backend and recording abstractions in `data`. |
| Live-flow ownership | Let the new cloud transcription service own the live recording lifecycle for this story, including choosing the temp output path | US-007 explicitly needs a linear `start -> stop -> save audio -> transcribe` flow with status callbacks, so pushing path ownership up into a later controller would add indirection before it is useful. |
| Sequential-operation policy | Treat the entire live transcription flow as a single in-progress operation from recording start until transcription completes; reject new starts or draft transcriptions while another transcription operation is active, with one explicit internal state model covering start, record, stop, and upload phases | The approved spec requires sequential transcription behavior with no overlapping jobs, and an explicit state model makes those linear transitions easier to reason about than overlapping booleans. |
| Status signaling | Use typed status callbacks for `RecordingStarted(deadline)` and `Uploading` emitted directly by the service methods | The story and acceptance criteria are explicitly callback-oriented, and a small callback surface keeps US-007 focused without forcing the broader reactive controller/state-machine design from US-009 early. |
| Backend reuse | Reuse `WraitBackendClient.transcribeAudio()` as the only upload path and adapt its result to the narrower US-007 result contract | US-005 already owns request construction, backend auth/device headers, timeout configuration, and quota extraction, so US-007 should map over that instead of duplicating HTTP behavior. |
| Failure-surface narrowing | Map backend-client `timeout` to `Timeout`, collapse `noInternet` and other connectivity failures into `Network`, map backend unavailability and proxy-auth failures directly, and fold remaining non-success cases including quota-exceeded/request-too-large into `ApiError` while still surfacing valid quota | The approved spec wants a narrower failure contract than the backend client currently exposes, but it still requires quota propagation whenever the backend includes it. |
| Quota state ownership | Reuse one shared session quota owner in the backend provider layer and generalize its naming away from registration-only semantics | Registration and cloud transcription both update the same current-session quota concept; a second quota cache would create drift and force later stories to reconcile them. |
| Language normalization | Root all backend language normalization in `lib/domain/model/supported_language.dart` by sharing sanitization and locale-shape validation helpers before resolving to a supported canonical code | This matches the approved spec’s parse-and-normalize requirement while keeping one source of truth for supported-language parsing and canonicalization. |
| Invalid-language success policy | Treat a non-blank transcript plus an unresolvable detected language as success with `detectedLanguage == null` | This exactly matches the approved clarified behavior and avoids throwing away usable transcription text because backend language detection was noisy. |
| Live-file lifecycle | Delete the temporary live recording file immediately after successful transcription and keep it only on failure | The user explicitly approved immediate deletion on live success, and retaining the file only for failures satisfies the retry requirement without accumulating temporary audio. |
| Draft-file lifecycle | `transcribeAudioDraft(audioPath)` reuses the same upload/result mapping rules but leaves the file lifecycle to the caller on success and failure | Later US-015 retry behavior needs the draft orchestration layer to decide whether to keep, promote, or delete audio after transcription succeeds, so the draft path cannot blindly apply the live-flow deletion rule. |
| Draft-file validation | Validate draft paths locally before upload: blank, missing, unreadable, or zero-byte files fail fast with warning logs and no backend call | This avoids wasting quota or producing misleading network/API failures for obviously invalid local draft input. |
| Temporary file generation | Generate live recording paths inside app-controlled temporary storage through a small injectable temp-directory/path factory | The recording service requires a caller-supplied path, and an injectable factory keeps path generation deterministic in tests while ensuring live recordings stay in temporary storage. |
| Logging scope | Add a lightweight transcription logger dependency/provider for warning-level diagnostics on retryable or unexpected failures | The approved spec requires proper logging for network and backend issues, and a small injected logger keeps the behavior testable without adding a general logging framework. |
| Validation approach | Use fake-driven `integration_test` coverage for all service flows and real Android/iOS runtime verification with the actual recorder plugin plus a stub backend | Deterministic automation is best for business rules, while cross-platform runtime checks still need real plugin behavior for final approval. |
| Validation exception | None requested | The story can satisfy the default `integration_test` and dual-platform runtime-verification requirements. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `lib/data/transcription/transcription_service.dart` | Create | Define the app-facing cloud transcription contract, typed statuses, result types, and narrowed failure enum for US-007 |
| `lib/data/transcription/cloud_transcription_service.dart` | Create | Implement the sequential live and draft transcription flows on top of the recording service, backend client, temp-file generation, quota updates, language normalization, logging, and live-file cleanup |
| `lib/data/transcription/transcription_providers.dart` | Create | Wire Riverpod providers for the temp-directory/path factory, transcription logger, and app-facing cloud transcription service |
| `lib/data/api/backend_providers.dart` | Modify | Generalize the session quota state owner so both launch registration and cloud transcription update the same provider |
| `integration_test/device_registration_launch_flow_test.dart` | Modify | Update references if the quota provider is renamed/generalized |
| `test/data/api/register_device_on_launch_use_case_test.dart` | Modify | Update references if the quota provider is renamed/generalized |
| `test/data/api/backend_client_test.dart` | Modify | Expand backend-client expectations only if needed for quota-carrying failure data or live-story assumptions uncovered during implementation |
| `test/domain/model/supported_language_test.dart` | Modify | Add normalization/resolve coverage only if the existing helper needs to expand for the new locale-shaped parse behavior |
| `test/data/transcription/cloud_transcription_service_test.dart` | Create | Unit coverage for sequential gating, status ordering, language normalization, failure mapping, quota propagation, and file lifecycle behavior |
| `integration_test/cloud_transcription_service_flow_test.dart` | Create | Fake-driven integration coverage through the real provider graph for every in-scope US-007 service flow |
| `specs/008-cloud-transcription-service/implementation.md` | Create later | Record implementation details and validation evidence during the implementation phase |

## API contract details

Implementation-specific rules on top of the approved spec:

- The story continues to consume the existing `POST /api/transcribe` contract
  only; no new endpoint or payload shape is introduced.
- The app-facing service will expose two flow entry points:
  - one for the live record-then-transcribe flow
  - one for transcribing an already-retained audio draft
- The live-flow entry points will emit:
  - `RecordingStarted(hardCapDeadlineElapsedRealtime)` immediately after a new
    recording starts successfully
  - `Uploading` immediately after the user stops a valid recording and before
    the backend upload begins
- The service will internally choose a temporary `.m4a` output path for live
  recordings and hand that path to the existing recording service.
- The service will reject:
  - a new live start while recording is already active
  - a new live start while an upload/transcription is still in progress
  - an audio-draft transcription request while another live or draft
    transcription operation is still in progress
- Before a draft upload begins, the service will:
  - reject blank audio paths as invalid draft input
  - reject missing, unreadable, or zero-byte files locally
  - log the validation failure and skip the backend call entirely
- On backend success:
  - blank transcript remains a failure
  - non-blank transcript plus resolvable supported language returns success
    with canonical `detectedLanguage`
  - non-blank transcript plus unresolvable detected language returns success
    with `detectedLanguage == null`
  - any valid returned quota updates the shared session quota state and is
    surfaced in the returned success result only after the success payload is
    accepted as usable by the app
- On backend failure:
  - timeout maps to the service `Timeout` failure
  - connectivity/no-internet maps to the service `Network` failure
  - 5xx/upstream unavailable maps to `BackendUnavailable`
  - 401 maps to `ProxyAuthFailed`
  - all other non-success cases, including 413 and 429, map to `ApiError`
  - valid quota from failure payloads such as `429 Daily record limit exceeded`
    still updates the shared session quota state and is surfaced in the
    returned failure result
- On live success:
  - the temporary audio file is deleted immediately after a usable
    transcription result is available
- On live failure:
  - the recorded audio file is preserved and returned as `audioDraftPath`
- On draft retry success or failure:
  - the service does not delete or rewrite the caller-supplied draft audio file
  - later draft orchestration will own post-transcription file cleanup or
    promotion behavior

## Data model changes

This story adds new app-facing in-memory transcription contracts and broadens
session quota ownership, but it does not add a database schema or preferences
migration.

### Before

```dart
// No app-facing cloud transcription service exists yet.
// The app has:
// - AudioRecordingService for start/stop/capture only
// - WraitBackendClient for raw backend transcription only
// - a registration-named in-memory quota owner used only at launch
```

### After

```dart
abstract interface class TranscriptionService {
  bool get isRecording;
  bool get isTranscribing;
  int? get hardCapDeadlineElapsedRealtime;

  Future<void> startLiveTranscription({
    required void Function(TranscriptionStatus status) onStatus,
  });

  Future<TranscriptionResult> stopLiveTranscription({
    required void Function(TranscriptionStatus status) onStatus,
  });

  Future<TranscriptionResult> transcribeAudioDraft(String audioPath);
}

sealed class TranscriptionStatus {
  const TranscriptionStatus();
}

final class RecordingStarted extends TranscriptionStatus {
  const RecordingStarted(this.hardCapDeadlineElapsedRealtime);

  final int hardCapDeadlineElapsedRealtime;
}

final class Uploading extends TranscriptionStatus {
  const Uploading();
}

enum TranscriptionFailureReason {
  network,
  timeout,
  backendUnavailable,
  proxyAuthFailed,
  apiError,
}

typedef RecordQuotaSessionState = RecordQuotaState?;
```

### Migration

No migration is required.

This story is additive and keeps all persistence behavior unchanged.

## Test strategy

Validation will cover three levels:

- unit tests for the new service’s sequencing, status ordering, failure
  mapping, language normalization, quota propagation, and live/draft file
  lifecycle rules
- fake-driven `integration_test` coverage through the real provider graph for
  every in-scope US-007 flow
- Android emulator and iOS simulator runtime verification against the real
  recording plugin and a local stub backend to prove the cross-platform
  record-stop-upload behavior

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Starting a live transcription emits `RecordingStarted` with the recording hard-cap deadline and marks the service as recording | Integration | `integration_test/cloud_transcription_service_flow_test.dart` |
| Stopping a valid live transcription emits `Uploading`, uploads the audio, returns transcript plus canonical detected language and quota, and deletes the live temp file on success | Integration | `integration_test/cloud_transcription_service_flow_test.dart` |
| A live transcription with usable text but an unsupported or invalid backend language succeeds with no detected language value | Integration | `integration_test/cloud_transcription_service_flow_test.dart` |
| A live transcription failure after valid recording returns the preserved `audioDraftPath`, surfaces the narrowed failure reason, and leaves the file on disk | Integration | `integration_test/cloud_transcription_service_flow_test.dart` |
| An audio-draft transcription success uses the same upload/result mapping rules without deleting the caller-owned draft file | Integration | `integration_test/cloud_transcription_service_flow_test.dart` |
| A quota-exceeded or other quota-bearing transcription failure surfaces valid quota data to callers and updates the shared session quota state | Integration | `integration_test/cloud_transcription_service_flow_test.dart` |
| A second live or draft transcription request is rejected while another transcription operation is still active | Integration | `integration_test/cloud_transcription_service_flow_test.dart` |
| Calling `stopLiveTranscription()` without an active live recording throws the typed misuse failure | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| A second live start is rejected while the first live start is still acquiring its recording path | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| `startLiveTranscription()` rejects when the service is already recording or already transcribing | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| `stopLiveTranscription()` emits `Uploading` before invoking backend upload | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Successful live transcription deletes the temp file and clears in-progress state | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Failed live transcription preserves the temp file path for retry and clears in-progress state | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| `transcribeAudioDraft()` fails fast without a backend call for blank, missing, or zero-byte draft files | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| `transcribeAudioDraft()` leaves the caller-owned audio file untouched on both success and failure | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Backend timeout maps to `Timeout`, backend no-internet or connectivity maps to `Network`, backend unavailable maps to `BackendUnavailable`, proxy auth maps to `ProxyAuthFailed`, and remaining failures map to `ApiError` | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Detected language normalization canonicalizes supported values and returns `null` for unresolvable ones without failing a usable transcript | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Valid quota from success and failure responses updates the shared session quota provider, but malformed success payloads rejected by the app do not mutate shared quota | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Launch registration still updates the generalized shared session quota provider after the provider naming or state-owner change | Integration | `integration_test/device_registration_launch_flow_test.dart` |
| `flutter analyze` completes cleanly after the new cloud transcription service and generalized quota wiring are added | Static analysis | Command evidence recorded in `tasks.md` |
| `flutter test` passes after the new transcription-service and quota-state coverage is added | Test suite | Command evidence recorded in `tasks.md` |

### Android emulator verification

1. Run `integration_test/cloud_transcription_service_flow_test.dart` on an
   Android emulator with provider overrides that use the real recording plugin
   and a local stub backend, and confirm the core US-007 flows pass.
2. Verify on the Android emulator that a real live recording can be started,
   stopped after 5 seconds, uploaded to the stub backend, and yield the
   expected success result plus immediate live-file cleanup.
3. Verify on the Android emulator that a stubbed failure response preserves the
   recorded file path for retry and surfaces the expected narrowed failure.
4. Re-run the existing launch registration integration test if the shared quota
   provider is generalized, to confirm no regression in quota updates.
5. Record the emulator target and passing command evidence in `tasks.md`.

### iOS simulator verification

1. Run `integration_test/cloud_transcription_service_flow_test.dart` on an iOS
   simulator with provider overrides that use the real recording plugin and a
   local stub backend, and confirm the core US-007 flows pass.
2. Verify on the iOS simulator that a real live recording can be started,
   stopped after 5 seconds, uploaded to the stub backend, and yield the
   expected success result plus immediate live-file cleanup.
3. Verify on the iOS simulator that a stubbed failure response preserves the
   recorded file path for retry and surfaces the expected narrowed failure.
4. Re-run the existing launch registration integration test if the shared quota
   provider is generalized, to confirm no regression in quota updates.
5. Record the simulator target and passing command evidence in `tasks.md`.

### Validation exception request

No exception requested.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This story is likely to produce durable follow-up for
  `docs/agent-findings.md` around:
  - sharing one session quota owner across registration and transcription
  - the split between live temporary audio ownership and caller-owned draft
    audio
  - the narrowed cloud-transcription failure surface above the backend client

## Integration notes

- The new cloud transcription service will compose:
  - `AudioRecordingService` from
    [lib/data/audio/audio_recording_providers.dart](/Users/alexander/projects/wrait/write-flutter/lib/data/audio/audio_recording_providers.dart)
  - `WraitBackendClient` and the shared session quota provider from
    [lib/data/api/backend_providers.dart](/Users/alexander/projects/wrait/write-flutter/lib/data/api/backend_providers.dart)
  - the supported-language helper in
    [lib/domain/model/supported_language.dart](/Users/alexander/projects/wrait/write-flutter/lib/domain/model/supported_language.dart)
- The service remains app-facing infrastructure only in US-007. No placeholder
  UI or route wiring is required yet; later stories such as US-009 will bind
  the service into the main recording controller and screen state.
- Generalizing the quota provider must preserve the existing launch
  registration behavior from US-016 so later stories see one consistent
  session quota source.
- The existing entry repository and draft persistence APIs are intentionally not
  invoked in this story. US-007 returns `audioDraftPath`; US-015 will decide
  when that path becomes a persisted audio draft record.
- Because the checked-in OpenAPI contract already defines transcription quota
  in both success and `429` failure responses, no contract change or generator
  refresh is expected in this story.

## Rollout & migration

This is an additive infrastructure story.

- No feature flag is needed.
- No backend contract migration is needed.
- No database or preferences migration is needed.
- The main rollout concern is cross-story quota-state drift; reusing one shared
  session quota owner contains that risk.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Generalizing the quota provider breaks the existing launch-registration flow | Medium | High | Reuse the same state owner instead of creating a second one, update the existing registration tests and integration flow, and re-run them during validation |
| Live and draft audio paths accidentally share the same cleanup behavior, breaking later retry work | Medium | High | Keep live and draft flows as separate methods with explicitly different file-lifecycle rules and cover both paths in unit and integration tests |
| The narrowed US-007 failure surface loses useful quota data from backend failures | Medium | Medium | Keep quota propagation separate from failure-reason mapping and verify quota-bearing failures in both unit and integration tests |
| Status callbacks fire in the wrong order around stop-upload transitions | Medium | Medium | Emit callbacks from one service boundary, test the exact ordering, and keep the callback surface minimal |
| Locale normalization rejects usable transcripts too aggressively | Medium | Medium | Treat transcript validity separately from detected-language validity and test both resolvable and unresolvable language inputs |
| Real plugin or runtime behavior differs from fake-driven automation on Android or iOS | Medium | High | Pair deterministic fake-driven tests with Android emulator and iOS simulator verification against the real recorder plugin and a stub backend |

## Open items from spec

None.
