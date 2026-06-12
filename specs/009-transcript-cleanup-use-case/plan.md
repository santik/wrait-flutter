# Implementation Plan: Transcript Cleanup Use Case

> **Feature number:** 009
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-12

---

## Approach summary

Implement US-008 as one app-facing `CleanupTranscriptUseCase` that composes
the existing backend cleanup client, the existing entry repository, and the
existing session quota state instead of adding a second cleanup service layer
or changing the database schema. The use case will own the best-mode cleanup
boundary for this story: it will ensure the target transcript exists as a
persisted text draft before reporting cleanup failure, bound only the cleanup
request input to the approved 10,000-character cap, reuse the transcript’s
existing usable language when available, fall back to English only when a
usable language is required by the current persistence/request path, call the
existing backend `/api/cleanup` operation, update the shared session quota
state whenever valid quota arrives, finalize the entry with cleaned text and a
recalculated cleaned-text word count on success, and leave the persisted text
draft intact on failure. Validation will combine deterministic unit tests,
fake-driven `integration_test` coverage through the real provider graph for
every in-scope fresh/retry flow, and Android emulator plus iOS simulator
verification by running the integration coverage on both platforms.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| App-facing boundary | Add `CleanupTranscriptUseCase` under `lib/domain/usecase/` with one result contract that serves both fresh post-transcription cleanup and persisted-draft retry cleanup | The story is framed as a use case, and one boundary keeps later controller and retry stories dependent on one stable cleanup contract instead of mixing repository and backend calls directly. |
| Persistence ownership | Let the use case own draft persistence before, during, and after the cleanup attempt | The approved spec now requires a persisted draft after each best-mode step, so cleanup failure in the fresh path cannot be handled correctly by a thin API wrapper alone. |
| Fresh-path persistence strategy | When no existing entry id is supplied, create a text draft before calling backend cleanup, then finalize that same entry on success | This satisfies the “persist after transcription and cleanup” rule while preserving one stable entry id across failure and success. |
| Existing-draft strategy | When an entry id is supplied, resolve that entry up front, reject missing or non-draft targets as typed cleanup failures, atomically persist the current raw transcript plus language onto the draft, then run cleanup | This supports the approved retry path, prevents crashes from invalid ids, and naturally enables future audio-draft-to-text-draft promotion without adding a second cleanup code path. |
| Repository reuse | Reuse the existing repository and extend it with one atomic `updateDraftTranscriptAndLanguage()` operation for retry-path draft promotion/update | Review uncovered a concrete gap: updating transcript and language separately risked partial draft state, so one repository-level operation is the simplest reliable fix. |
| Use-case input contract | Accept raw transcript text, optional transcript-associated language, and an optional existing entry id; return a typed success/failure result with any valid quota and an `entryId` that is always present on success and nullable on failure | The implementation needs to support both fresh and retry flows, surface which persisted entry was affected when possible, and still represent early persistence failures where no draft id exists. |
| Language resolution | Resolve the transcript-associated language to a supported canonical code when usable; otherwise fall back to `en-US` only where a supported non-null language is required for persistence or the cleanup request | The approved spec says to use the transcript language when available and English only when required, and the current entry schema cannot persist a null language. |
| Transcript-size cap | Apply the approved 10,000-character limit only to the cleanup request payload while preserving the full persisted raw transcript | This matches the approved Flutter spec even though the Android reference currently uses a tighter request cap; the spec is the source of truth for this story. |
| Blank-input handling | Fail fast on blank or whitespace-only raw transcript input without calling the backend, while still preserving or reusing the persisted draft entry as appropriate | Boundary validation should prevent obviously invalid cleanup requests from leaking into transport behavior while keeping the incremental draft-persistence guarantee intact. |
| Malformed-success validation ownership | Keep blank cleaned-text validation in the backend cleanup client so a nominal success payload is downgraded to failure exactly once while still surfacing any valid quota | The approved spec requires malformed cleanup successes to fail without losing quota, and centralizing that rule in the backend client avoids duplicate validation logic in the use case. |
| Quota propagation | Reuse the existing session quota provider and update it only when the backend cleanup result carries valid quota | Registration and transcription already share this session-only quota state, and the spec requires null/invalid quota to preserve the last valid value. |
| Failure surface | Reuse `BackendFailureReason` values from the backend cleanup client for the use case’s failure reason rather than introducing another enum | The existing backend client already maps cleanup transport/API failures into a meaningful app-facing enum, so another translation layer would add noise without clearer behavior. |
| Repository exception handling | Treat repository load, draft-persistence, and finalization exceptions as typed cleanup failures after logging a warning | The story must preserve drafts and return application-meaningful cleanup failures instead of leaking repository exceptions into later controller flows. |
| Word-count calculation | Compute the finalized entry word count from cleaned text using the same whitespace-splitting rule defined by the spec, in a small use-case-local helper | Only the cleaned-text finalization path needs this rule here, so a small local helper keeps the behavior explicit without prematurely extracting a shared text utility. |
| Validation approach | Use unit tests for result/persistence/quota/language rules and provider-graph `integration_test` coverage for all in-scope flows on Android and iOS | The behavior is mostly orchestration over repository and backend boundaries, so fake-driven integration tests give high confidence without requiring UI work. |
| Storage migration | None | The approved spec explicitly keeps the existing entry schema and quota model. |
| Validation exception | None requested | The feature can satisfy the default `integration_test` and dual-platform verification requirements. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `lib/domain/usecase/cleanup_transcript_use_case.dart` | Create | Define the cleanup use case, typed success/failure results, request-size/language resolution rules, cleaned-text word counting, and persistence orchestration for fresh and retry flows |
| `lib/data/api/backend_providers.dart` | Modify | Add cleanup-use-case provider wiring plus any cleanup-specific callback/logger providers needed to compose backend cleanup, entry persistence, and shared quota updates |
| `lib/data/api/backend_client.dart` | Modify | Preserve valid quota on malformed cleanup success payloads that must still be treated as cleanup failures |
| `lib/domain/repository/entry_repository.dart` | Modify | Add the atomic retry-path draft update contract that rewrites transcript and language together before cleanup |
| `lib/data/entries/entry_dao.dart` | Modify | Implement the single database update that rewrites draft transcript, word count, language, and clears any stale audio association in one write |
| `lib/data/entries/entry_repository_impl.dart` | Modify | Enforce canonical language resolution for the new atomic draft update and preserve the repository’s missing-row semantics |
| `test/domain/usecase/cleanup_transcript_use_case_test.dart` | Create | Unit coverage for fresh-path persistence, retry-path updates, language fallback, request truncation, blank-input handling, quota propagation, and failure preservation behavior |
| `integration_test/cleanup_transcript_use_case_flow_test.dart` | Create | Fake-driven provider-graph integration coverage for every in-scope fresh/retry cleanup flow and shared session quota updates |
| `test/data/api/backend_client_test.dart` | Modify | Add cleanup-client coverage for malformed cleanup success payloads that must fail while still surfacing valid quota |
| `test/data/entries/entry_repository_impl_test.dart` | Modify | Add direct repository coverage for the new atomic retry-path draft transcript/language update |
| `specs/009-transcript-cleanup-use-case/implementation.md` | Create later | Record implementation details and validation evidence during the implementation phase |

## API contract details

Implementation-specific rules on top of the approved spec:

- The story continues to consume only the existing `POST /api/cleanup`
  backend contract; no new HTTP endpoint or payload shape is introduced.
- The use case will expose one cleanup entry point that accepts:
  - `rawTranscript`
  - optional transcript-associated `language`
  - optional `entryId` for an already-persisted draft
- Before the backend call:
  - blank or whitespace-only transcript input is rejected without a backend
    request
  - the cleanup request transcript is trimmed and capped to
    `cleanupTranscriptMaxLength` (`10000`) characters
  - the full original raw transcript remains the value persisted on the entry
  - the use case resolves the transcript language to a supported canonical code
    when possible
  - if no usable transcript language is available and the use case needs a
    non-null supported language for persistence or request construction, it
    uses `en-US`
  - if `entryId` is absent, the use case persists a new text draft before the
    backend cleanup call
  - if `entryId` is present, the use case ensures the current raw transcript is
    persisted on that draft before the backend cleanup call by atomically
    updating transcript, word count, language, and clearing any prior
    audio-draft association
  - if `entryId` is present but the entry is missing or no longer a draft, the
    use case returns a typed cleanup failure instead of throwing
- On backend success:
  - blank cleaned text is treated as failure by the backend client, not the use
    case
  - if that malformed success payload still includes valid quota, that quota
    is surfaced through the failure result and remains eligible to update the
    shared session quota state
  - valid quota updates the shared session quota state
  - the target entry is finalized by writing `cleanedText`, recalculating the
    cleaned-text word count, clearing `isDraft`, and removing any remaining
    draft audio association through existing repository behavior
  - if repository finalization fails, the use case returns a typed cleanup
    failure and still surfaces any valid quota
- On backend failure:
  - the use case returns `Failure(reason, quota, entryId)`
  - valid quota still updates the shared session quota state
  - the persisted entry remains a text draft with the full raw transcript and
    no cleaned text
  - if draft persistence fails before an entry exists, the returned failure may
    carry a null `entryId`
- The typed result contract always includes `entryId` on success and includes
  it on failure when the use case can identify the affected draft entry.

## Data model changes

This story adds an app-facing cleanup use-case contract and activates
additional use of the existing entry-draft schema, but it does not change the
database shape.

### Before

```dart
abstract interface class EntryRepository {
  Future<int> saveDraft(String transcript, String language);
  Future<void> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  );
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  );
}

// No cleanup use case exists yet.
// Cleanup is available only as WraitBackendClient.cleanupTranscript(...).
```

### After

```dart
class CleanupTranscriptUseCase {
  Future<CleanupTranscriptResult> call({
    required String rawTranscript,
    String? language,
    int? entryId,
  });
}

sealed class CleanupTranscriptResult {
  const CleanupTranscriptResult({
    required this.entryId,
    this.quota,
  });

  final int? entryId;
  final RecordQuotaState? quota;
}

final class CleanupTranscriptSuccess extends CleanupTranscriptResult {
  const CleanupTranscriptSuccess({
    required super.entryId,
    required this.cleanedText,
    super.quota,
  });

  final String cleanedText;
}

final class CleanupTranscriptFailure extends CleanupTranscriptResult {
  const CleanupTranscriptFailure({
    required super.entryId,
    required this.reason,
    super.quota,
  });

  final BackendFailureReason reason;
}
```

### Migration

No migration is required.

The feature reuses the existing `rawTranscript`, `cleanedText`, `isDraft`,
`wordCount`, and `audioPath` columns and the existing in-memory quota state.

## Test strategy

Validation will cover three levels:

- unit tests for the new cleanup use case’s persistence orchestration, request
  truncation, language resolution, quota propagation, failure handling, and
  word-count calculation
- fake-driven `integration_test` coverage through the real provider graph and
  real entry repository/database wiring for every in-scope cleanup flow
- Android emulator and iOS simulator verification by running the integration
  flow tests on both platforms

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Fresh post-transcription cleanup success persists a text draft first, finalizes the same entry with cleaned text, preserves full raw transcript, clears `isDraft`, recalculates cleaned-text word count, and updates shared quota when valid quota is returned | Integration | `integration_test/cleanup_transcript_use_case_flow_test.dart` |
| Fresh post-transcription cleanup failure persists a text draft, leaves `cleanedText` unset, keeps `isDraft == true`, and surfaces failure plus any valid quota | Integration | `integration_test/cleanup_transcript_use_case_flow_test.dart` |
| Existing text-draft cleanup success reuses the supplied draft entry id, clears any stale audio association, and finalizes that entry without creating a duplicate entry | Integration | `integration_test/cleanup_transcript_use_case_flow_test.dart` |
| Cleanup uses the transcript-associated language when it is usable and falls back to `en-US` only when a usable supported language is required but absent | Integration | `integration_test/cleanup_transcript_use_case_flow_test.dart` |
| Cleanup request input is truncated to 10,000 characters while the persisted raw transcript remains full-length | Integration | `integration_test/cleanup_transcript_use_case_flow_test.dart` |
| Missing or invalid cleanup quota does not overwrite the existing session quota, while valid quota from either success or failure does update it | Integration | `integration_test/cleanup_transcript_use_case_flow_test.dart` |
| Malformed nominal cleanup success with blank cleaned text is downgraded to failure, preserves the draft, and still refreshes session quota when the quota payload is valid | Integration | `integration_test/cleanup_transcript_use_case_flow_test.dart` |
| Blank or whitespace-only cleanup input fails fast without a backend call and still preserves or creates the required draft entry for recovery | Unit | `test/domain/usecase/cleanup_transcript_use_case_test.dart` |
| Blank cleaned text in a nominal backend success is treated as failure, leaves the entry as a draft, and still propagates any valid quota from that cleanup response | Unit | `test/domain/usecase/cleanup_transcript_use_case_test.dart` |
| Existing draft cleanup rewrites the draft transcript before cleanup so later success finalizes the newest raw transcript value | Unit | `test/domain/usecase/cleanup_transcript_use_case_test.dart` |
| Missing entry ids, finalized entry ids, draft-persistence failures, and finalization failures return typed cleanup failures instead of crashing | Unit | `test/domain/usecase/cleanup_transcript_use_case_test.dart` |
| The backend cleanup client preserves valid quota when a nominal cleanup success payload contains blank cleaned text and must be downgraded to failure | Unit | `test/data/api/backend_client_test.dart` |
| The repository atomically rewrites draft transcript, word count, language, and clears `audioPath` in one update | Unit | `test/data/entries/entry_repository_impl_test.dart` |
| `flutter analyze` completes cleanly after cleanup-use-case wiring is added | Static analysis | Command evidence recorded in `tasks.md` |
| `flutter test` passes after cleanup-use-case coverage is added | Test suite | Command evidence recorded in `tasks.md` |

### Android emulator verification

1. Run `integration_test/cleanup_transcript_use_case_flow_test.dart` on an
   Android emulator using the real local database/provider graph plus backend
   cleanup callback overrides, and confirm the in-scope fresh and retry flows
   pass.
2. Verify on the Android emulator that the fresh cleanup success path produces
   one finalized non-draft entry with the expected cleaned text, preserved raw
   transcript, and updated session quota.
3. Verify on the Android emulator that the fresh cleanup failure path still
   leaves a persisted text draft for retry and does not overwrite the last
   valid quota when the cleanup response omits usable quota.
4. Record the emulator target and passing command evidence in `tasks.md`.

### iOS simulator verification

1. Run `integration_test/cleanup_transcript_use_case_flow_test.dart` on an
   iOS simulator using the real local database/provider graph plus backend
   cleanup callback overrides, and confirm the in-scope fresh and retry flows
   pass.
2. Verify on the iOS simulator that the fresh cleanup success path produces
   one finalized non-draft entry with the expected cleaned text, preserved raw
   transcript, and updated session quota.
3. Verify on the iOS simulator that the fresh cleanup failure path still
   leaves a persisted text draft for retry and does not overwrite the last
   valid quota when the cleanup response omits usable quota.
4. Record the simulator target and passing command evidence in `tasks.md`.

### Validation exception request

No exception requested.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require durable updates to:
  - `docs/application-description.md`
  - `docs/agent-findings.md`
- An `AGENTS.md` update is not expected unless implementation reveals new
  long-lived guidance about incremental draft persistence or cleanup-language
  fallback that belongs in the repo-level instructions.

## Integration notes

- Later `US-009` controller logic will call `CleanupTranscriptUseCase` after a
  successful best-mode transcription result and can rely on the use case to
  persist the fresh text draft before reporting cleanup failure.
- Later `US-015` draft retry logic can call the same use case with an existing
  `entryId` and a current raw transcript to retry text drafts through the same
  cleanup contract.
- The use case will depend on:
  - `WraitBackendClient.cleanupTranscript(...)`
  - `EntryRepository`
  - `sessionRecordQuotaStateProvider`
- Existing backend cleanup transport/error mapping remains owned by
  `WraitBackendClient`; the new use case will layer persistence and quota
  semantics on top of it instead of reimplementing HTTP behavior.

## Rollout & migration

- This is an additive app-internal capability with no backend contract change.
- No feature flag is planned.
- No schema migration is required.
- Backward compatibility concern:
  - because the current entry schema requires a non-null supported language,
    the use case will persist `en-US` when no usable transcript language is
    available and persistence cannot proceed otherwise

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Cleanup creates duplicate entries in the fresh path instead of finalizing the same draft | Medium | High | Persist the draft before cleanup and return the same `entryId` through both success and failure results; cover this in unit and integration tests |
| Missing-language transcripts conflict with the non-null persisted entry language requirement | Medium | Medium | Resolve usable transcript language first and use `en-US` only where persistence/request construction requires a supported non-null language; call this out explicitly in tests |
| Truncating the persisted raw transcript instead of only the request payload would violate the approved spec | Low | High | Keep transcript bounding inside the use case’s request-preparation step and assert in tests that the stored raw transcript remains full-length |
| Invalid quota from cleanup success/failure could incorrectly erase the last valid session quota | Medium | Medium | Reuse the existing validated quota model and update session quota only when the backend result exposes a valid `RecordQuotaState` |
| Future draft-retry flows might need different persistence semantics for audio drafts | Low | Medium | Reuse the atomic `updateDraftTranscriptAndLanguage()` path before cleanup so the use case naturally supports later audio-draft promotion without adding story-specific branching now |

## Open items from spec

None.
