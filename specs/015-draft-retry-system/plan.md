# Implementation Plan: Draft Retry System

> **Feature number:** 015
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-19

---

## Approach summary

Add a launch-only draft retry path that runs after successful device
registration, without blocking the existing first-frame/bootstrap behavior.
Registration will continue to be fire-and-forget from the UI's perspective,
but the launch work will become an explicit sequence: register the device, and
only when registration succeeds, delete stale drafts and retry pending drafts.
The retry use case will process local drafts newest-first, handle each draft
independently, finalize successful text/audio drafts through existing
transcription and cleanup contracts, delete retained audio files when they are
no longer needed, delete audio drafts with missing/unreadable files, and leave
retry failures intact for the next eligible launch.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Launch orchestration | Create an `AppLaunchWorkUseCase` that calls registration first and draft retry only after registration success | The spec requires launch-only retry after registration. A coordinator keeps this sequencing explicit and prevents retry from being triggered by later in-session registration recovery. |
| Registration result surface | Change `RegisterDeviceOnLaunchUseCase.call()` to return a success/failure result while preserving current quota update, logging, and swallowed-error behavior | Existing callers do not need thrown failures, but draft retry needs to know whether registration succeeded. Returning a result is simpler and more testable than watching mutable provider state. |
| Retry location | Add a dedicated `RetryPendingDraftsUseCase` in the application/domain use-case layer | Draft retry is workflow logic spanning entries, transcription, cleanup, and local files. Keeping it out of UI controllers preserves startup non-blocking behavior and keeps retry testable without widgets. |
| Pending draft ordering | Use `EntryRepository.getPendingDrafts()` as the source of truth | The repository already returns `isDraft=true` rows in descending `createdAt` order, matching the spec and avoiding duplicate query logic. |
| Stale cleanup timing | Run `EntryRepository.deleteStaleDrafts(daysOld: 7)` inside the launch retry use case before loading pending drafts | The current database bootstrap deletes stale drafts while opening local storage, but the spec requires stale cleanup before retry. Keeping the call in retry makes the behavior explicit while preserving existing bootstrap cleanup unless implementation proves duplication harmful. |
| Audio-file validation | Validate an audio draft's retained file before calling transcription; delete the draft if the file is missing, unreadable, empty, or has a blank path | The spec says malformed audio drafts are deleted, while ordinary transcription failures are preserved. Pre-validation distinguishes malformed local state from backend retry failure. |
| Audio retry | Use existing `TranscriptionService.transcribeAudioDraft(audioPath)` | The service already supports draft audio uploads and propagates quota. Reusing it avoids duplicate backend upload logic. |
| Text cleanup retry | Use existing `CleanupTranscriptUseCase(rawTranscript, language, entryId)` | The cleanup use case already reuses draft ids, persists text draft state on failure, finalizes on success, canonicalizes language, truncates request payload only, and propagates quota. |
| Audio-to-text promotion | After audio transcription success, call cleanup with the existing draft id; if cleanup fails, keep the draft as a text draft and delete the retained audio file | Cleanup failure with an existing draft id updates raw transcript/language and clears `audioPath`. The retry use case will then delete the now-unneeded local audio file. |
| Audio finalization | After audio transcription and cleanup both succeed, delete the retained audio file best-effort | Repository finalization clears `audioPath` but intentionally does not delete files. The retry workflow owns removal of retained audio after successful processing. |
| Language updates | Pass the detected language from audio retry into cleanup; rely on cleanup use case/repository canonicalization to update stored language | This satisfies detected-language updates without adding a separate language-write step or risking inconsistent transcript/language updates. |
| Retry failures | Leave drafts intact on transcription/cleanup failures, including quota exhaustion and proxy auth failures | This matches the approved spec. Failure details are logged for developers without foreground user feedback. |
| User feedback | Do not add new foreground UI for retry progress or success | The spec explicitly says finalized drafts simply appear through existing entry surfaces. |
| Concurrency | Use a launch-use-case-level single-flight guard for draft retry | Launch work should not create overlapping retry loops if tests or future code call it twice accidentally. Sequential processing also avoids stressing backend services. |
| Data schema | No schema migration | Existing entry fields already represent audio drafts, text drafts, final entries, timestamps, language, word count, and retained audio paths. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `lib/domain/usecase/register_device_on_launch_use_case.dart` | Modify | Return a launch registration result while keeping current non-throwing behavior, quota propagation, and warning logging. |
| `lib/domain/usecase/app_launch_work_use_case.dart` | Create | Sequence launch registration and launch-only draft retry, skipping retry when registration fails. |
| `lib/domain/usecase/retry_pending_drafts_use_case.dart` | Create | Delete stale drafts, load pending drafts, retry audio/text drafts, delete malformed audio drafts, delete retained audio files after success/promotion, and log per-draft failures. |
| `lib/data/api/backend_providers.dart` | Modify | Update the registration use-case provider for the new registration result contract. |
| `lib/data/launch/app_launch_providers.dart` | Create | Wire `AppLaunchWorkUseCase`, `RetryPendingDraftsUseCase`, draft-retry warning logging, transcription service, cleanup use case, entry repository, and file validation/deletion callbacks without creating provider import cycles. |
| `lib/main.dart` | Modify | Change `startAppLaunchWork` to call the new launch-work use case while preserving fire-and-forget, non-blocking startup. |
| `test/data/api/register_device_on_launch_use_case_test.dart` | Modify | Assert returned registration launch result for success, handled failure, and caught exception paths. |
| `test/domain/usecase/app_launch_work_use_case_test.dart` | Create | Cover registration-success retry, registration-failure skip, and swallowed/logged launch-work exceptions. |
| `test/domain/usecase/retry_pending_drafts_use_case_test.dart` | Create | Unit coverage for stale deletion, ordering, audio success, audio transcription failure, audio-to-text promotion, missing/unreadable audio deletion, text success/failure, quota/proxy preservation, and per-draft isolation. |
| `test/bootstrap_app_test.dart` | Modify | Update launch-work provider overrides and keep existing bootstrap non-blocking/retry behavior expectations. |
| `integration_test/device_registration_launch_flow_test.dart` | Modify | Verify launch registration remains non-blocking, retry runs after successful registration, and retry is skipped when registration fails. |
| `integration_test/draft_retry_launch_flow_test.dart` | Create | End-to-end provider/app launch coverage for pending audio/text draft retry, stale cleanup, malformed audio deletion, and failure preservation. |
| `integration_test/main_recording_controller_flow_test.dart` | Modify | Keep existing audio/text draft creation coverage aligned with any provider changes and verify draft creation still feeds launch retry. |
| `integration_test/cleanup_transcript_use_case_flow_test.dart` | Modify | Keep existing text-draft cleanup retry expectations aligned with launch retry orchestration. |
| `specs/015-draft-retry-system/implementation.md` | Create later | Record implementation details and validation evidence during implementation. |

## API contract details

No backend HTTP contract changes are required.

Application-facing contracts:

- `startAppLaunchWork(container)` remains non-blocking and returns immediately.
- Launch work calls device registration once for the app launch.
- Draft retry starts only when launch registration returns success.
- Draft retry does not start later in the same process when a failed launch
  registration might recover externally.
- Draft retry calls stale draft cleanup before loading pending drafts.
- Pending drafts are read from local entry storage where `isDraft=true`.
- Pending drafts are processed in repository order, newest first.
- Audio drafts require a non-blank, existing, readable, non-empty audio file.
- Audio drafts with invalid retained files are deleted through entry deletion.
- Audio draft transcription failures leave the draft row and retained file in
  place.
- Audio draft transcription success passes raw transcript, detected language,
  and existing draft id to cleanup.
- Audio draft cleanup success finalizes the same draft id and deletes the
  retained audio file best-effort.
- Audio draft cleanup failure preserves a text draft at the same id and deletes
  the retained audio file best-effort.
- Text draft cleanup success finalizes the same draft id.
- Text draft cleanup failure leaves the draft intact.
- Quota exhaustion and proxy authentication failures during retry are treated
  as retry failures that preserve the draft.
- Per-draft exceptions are logged and do not stop later drafts in the same run.
- Successful retries do not show new foreground messages.

## Data model changes

No persistent schema change is planned.

### Before

```text
Entry {
  id: int
  rawTranscript: String
  cleanedText: String?
  isDraft: bool
  language: String
  createdAt: int
  wordCount: int
  audioPath: String?
}
```

### After

```text
Entry {
  id: int
  rawTranscript: String
  cleanedText: String?
  isDraft: bool
  language: String
  createdAt: int
  wordCount: int
  audioPath: String?
}
```

State meanings used by this feature:

- Audio draft: `isDraft=true`, `audioPath` is non-blank, and `rawTranscript`
  may be blank.
- Text draft: `isDraft=true`, `audioPath=null`, and `rawTranscript` is
  non-blank.
- Final entry: `isDraft=false`, `cleanedText` contains the cleaned result.

### Migration

None. Existing rows already contain the needed columns. Existing stale draft
cleanup and entry deletion already tolerate missing audio files.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Registration use case returns success and preserves quota behavior | Unit | `test/data/api/register_device_on_launch_use_case_test.dart` |
| Registration use case returns failure for handled registration failures and caught exceptions | Unit | `test/data/api/register_device_on_launch_use_case_test.dart` |
| Launch work calls draft retry after registration success | Unit | `test/domain/usecase/app_launch_work_use_case_test.dart` |
| Launch work skips draft retry after registration failure | Unit | `test/domain/usecase/app_launch_work_use_case_test.dart` |
| Launch work logs and swallows retry exceptions without affecting UI startup | Unit/widget | `test/domain/usecase/app_launch_work_use_case_test.dart`, `test/bootstrap_app_test.dart` |
| Draft retry deletes stale drafts before loading pending drafts | Unit/integration | `test/domain/usecase/retry_pending_drafts_use_case_test.dart`, `integration_test/draft_retry_launch_flow_test.dart` |
| Pending drafts are processed newest-first and independently | Unit | `test/domain/usecase/retry_pending_drafts_use_case_test.dart` |
| Audio draft transcription + cleanup success finalizes the same entry and deletes audio | Unit/integration | `test/domain/usecase/retry_pending_drafts_use_case_test.dart`, `integration_test/draft_retry_launch_flow_test.dart` |
| Audio draft transcription failure leaves draft and audio intact | Unit/integration | `test/domain/usecase/retry_pending_drafts_use_case_test.dart`, `integration_test/draft_retry_launch_flow_test.dart` |
| Audio draft transcription success + cleanup failure promotes to text draft and deletes audio | Unit/integration | `test/domain/usecase/retry_pending_drafts_use_case_test.dart`, `integration_test/draft_retry_launch_flow_test.dart` |
| Audio draft detected language updates stored language when different | Unit/integration | `test/domain/usecase/retry_pending_drafts_use_case_test.dart`, `integration_test/draft_retry_launch_flow_test.dart` |
| Audio draft with blank/missing/unreadable/empty audio file is deleted | Unit/integration | `test/domain/usecase/retry_pending_drafts_use_case_test.dart`, `integration_test/draft_retry_launch_flow_test.dart` |
| Text draft cleanup success finalizes the same entry | Unit/integration | `test/domain/usecase/retry_pending_drafts_use_case_test.dart`, `integration_test/draft_retry_launch_flow_test.dart` |
| Text draft cleanup failure leaves the draft intact | Unit/integration | `test/domain/usecase/retry_pending_drafts_use_case_test.dart`, `integration_test/draft_retry_launch_flow_test.dart` |
| Quota exhaustion during transcription/cleanup leaves drafts intact | Unit | `test/domain/usecase/retry_pending_drafts_use_case_test.dart` |
| Proxy authentication failure during transcription/cleanup leaves drafts intact | Unit | `test/domain/usecase/retry_pending_drafts_use_case_test.dart` |
| Per-draft failure does not prevent later drafts from being attempted | Unit | `test/domain/usecase/retry_pending_drafts_use_case_test.dart` |
| Launch registration remains non-blocking while eventual success triggers retry | Integration | `integration_test/device_registration_launch_flow_test.dart`, `integration_test/draft_retry_launch_flow_test.dart` |
| Launch registration failure is non-blocking and does not retry drafts | Integration | `integration_test/device_registration_launch_flow_test.dart`, `integration_test/draft_retry_launch_flow_test.dart` |
| Existing recording failures still create audio/text drafts | Unit/integration | `test/presentation/main/main_recording_controller_test.dart`, `integration_test/main_recording_controller_flow_test.dart` |

`integration_test/draft_retry_launch_flow_test.dart` will cover every in-scope
user-facing flow from the spec at app/provider-launch level:

- pending audio draft finalizes after launch registration succeeds
- pending text draft finalizes after launch registration succeeds
- failed audio retry leaves draft and audio available for the next launch
- failed text retry leaves draft available for the next launch
- stale drafts are removed before retry
- missing/unreadable audio drafts are deleted
- finalized retry entries appear through existing entry list/detail/stats
  surfaces without a separate foreground success message
- registration failure skips retry until a future launch

The feature has no new manual foreground controls, so app-launch integration
coverage plus existing entry-surface integration coverage is the appropriate
flow coverage.

### Android emulator verification

1. Run the planned automated unit/widget test subset for registration, launch
   work, retry use case, bootstrap, and recording-controller draft creation.
2. Run `integration_test/draft_retry_launch_flow_test.dart` on an Android
   emulator.
3. Run `integration_test/device_registration_launch_flow_test.dart` on an
   Android emulator to verify startup remains non-blocking and retry waits for
   successful registration.
4. Run existing relevant entry-surface integration coverage on an Android
   emulator to verify finalized retry entries appear in list/detail/stats.
5. Record command output and state evidence in `tasks.md` and
   `implementation.md`.

### iOS simulator verification

1. Run the planned automated unit/widget test subset for registration, launch
   work, retry use case, bootstrap, and recording-controller draft creation.
2. Run `integration_test/draft_retry_launch_flow_test.dart` on an iOS
   simulator.
3. Run `integration_test/device_registration_launch_flow_test.dart` on an iOS
   simulator to verify startup remains non-blocking and retry waits for
   successful registration.
4. Run existing relevant entry-surface integration coverage on an iOS simulator
   to verify finalized retry entries appear in list/detail/stats.
5. Record command output and state evidence in `tasks.md` and
   `implementation.md`.

### Validation exception request

None requested. This feature is expected to satisfy the default
`integration_test`, Android emulator, and iOS simulator verification
requirements.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require a durable update to
  `docs/application-description.md` if the current product description still
  references multiple recording/privacy modes after this story is completed.
- This feature is likely to require a durable update to
  `docs/agent-findings.md` documenting the launch-work sequencing and draft
  retry use-case boundaries for future startup/backend stories.
- `AGENTS.md` changes are not expected unless implementation reveals durable
  workflow or validation guidance.

## Integration notes

- Startup remains non-blocking: `runApp()` stays before heavy initialization,
  and `startAppLaunchWork` remains fire-and-forget after the provider
  container is ready.
- The launch retry path depends on successful registration because backend
  transcription and cleanup require device identity/proxy-authenticated calls.
- Existing `CleanupTranscriptUseCase` continues to own cleanup request
  truncation, text-draft preservation, finalization, quota propagation, and
  language canonicalization.
- Existing `TranscriptionService.transcribeAudioDraft` continues to own draft
  audio upload and transcription quota propagation.
- Existing entry list/detail/stats surfaces should update through repository
  streams after retry finalization; no special UI refresh path is planned.
- No OpenAPI/backend API generation is required because no backend contract
  changes are planned.

## Rollout & migration

The feature rolls out as launch-work behavior. No feature flag or data
migration is planned. Existing pending drafts become eligible for retry on the
next launch after the feature is installed. Existing malformed audio drafts
with missing/unreadable files will be deleted during the first eligible retry
run.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Draft retry accidentally blocks startup | Medium | High | Keep launch work fire-and-forget and verify main UI appears while registration/retry futures are still pending. |
| Registration failure still triggers retry | Medium | High | Return explicit registration result and cover success/failure sequencing in unit and integration tests. |
| Overlapping retry loops duplicate backend calls | Low | Medium | Add a single-flight guard to the retry use case and process drafts sequentially. |
| Audio file deleted before text draft is safely preserved | Medium | High | Delete retained audio only after cleanup success finalizes or cleanup failure has preserved the text draft. |
| Missing/unreadable audio draft is confused with backend transcription failure | Medium | Medium | Validate retained audio file before transcription and delete only malformed local drafts. |
| Finalization clears `audioPath` but leaves local audio behind | Medium | Medium | Make retained-audio deletion an explicit retry-use-case responsibility and cover it in tests. |
| Per-draft exception stops all retries | Medium | Medium | Wrap each draft retry independently and continue to the next pending draft after logging. |
| Quota/proxy failures are accidentally treated as terminal | Medium | High | Add explicit unit cases for quota exceeded and proxy auth failure in both transcription and cleanup paths. |
| Stale cleanup runs twice during startup | Medium | Low | Existing bootstrap cleanup is idempotent; keep retry-time stale cleanup explicit and remove duplication only if implementation/testing exposes a concrete problem. |
| Integration tests become flaky due to background timing | Medium | Medium | Use deterministic fake services/completers and poll stored repository state rather than sleeping. |

## Open items from spec

None. The spec has no open questions.
