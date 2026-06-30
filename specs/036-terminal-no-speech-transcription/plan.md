# Implementation Plan: Terminal No-Speech Transcription Handling

> **Feature number:** 036
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-25

---

## Approach summary

US-036 will keep the existing transcription, recording-controller, feedback,
and draft-persistence architecture. The cloud transcription service will treat
blank or otherwise non-usable live transcription payloads as terminal no-word failures,
delete the live temporary audio, and return no retryable audio-draft path. The
main recording controller will also treat `nothingCaught` as non-retryable even
if a service implementation accidentally supplies an audio path. Existing
retryable service failures will continue to preserve audio drafts, and
recordings with detected words will continue through cleanup and final-entry
creation unchanged. Quota publication will follow a single rule after review:
cleanup owns quota publication for successful transcription paths, while the
foreground controller and launch-retry use case publish quota from failed
transcription results. The same story will verify that local draft
preservation does not publish an extra quota update or make the visible quota
appear consumed twice for a single failed recording outcome.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| No-word ownership | Keep no-word classification in `CloudTranscriptionService` when it receives a blank or otherwise non-usable success payload, and keep a defensive controller guard for success payloads that still should not reach cleanup | The service is the narrowest place to normalize backend transcription outcomes, while the controller guard prevents future classifier drift from recreating retryable drafts. |
| Live audio lifecycle | Delete live temporary audio for blank successful transcription payloads | The spec says captured audio is not retained for future retry. The service already owns live temp audio deletion after usable transcription success. |
| Draft transcription lifecycle | Keep caller-owned draft audio untouched when draft transcription returns no words | Existing bad no-word drafts are out of scope, and draft transcription already treats caller-owned audio as not owned by the service. |
| Controller retry guard | Skip audio-draft persistence for `TranscriptionFailureReason.nothingCaught` before checking `audioDraftPath` | This directly satisfies the "no retryable audio draft" requirement and prevents tests or future service changes from making no-word failures retryable through an accidental path. |
| Quota ownership | Keep `CloudTranscriptionService` free of direct quota publication; let cleanup publish successful-transcription quota, and let callers publish failed-transcription quota from the returned result | This gives one consistent rule per result shape, removes duplicate failed-recording updates, and keeps local draft persistence out of quota ownership. |
| Retryable failure behavior | Leave network, timeout, backend unavailable, proxy-auth, quota, and generic API failure draft preservation unchanged | The spec requires recoverable failures to keep preserving draft data when usable audio exists. |
| Data model | No schema or entry model change | No new persistent no-word state is needed; the desired behavior is absence of a draft or final entry. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `specs/036-terminal-no-speech-transcription/spec.md` | Modify | Mark finalized spec as approved for planning. |
| `specs/036-terminal-no-speech-transcription/plan.md` | Modify | This implementation plan. |
| `specs/036-terminal-no-speech-transcription/tasks.md` | Modify later | Replace the copied template with the approved task breakdown in the next phase. |
| `specs/036-terminal-no-speech-transcription/implementation.md` | Create later | Record implementation details and validation evidence during implementation. |
| `lib/data/api/backend_client.dart` | Modify | Preserve backend success payloads even when the transcript trims to empty so the app-facing transcription layer can classify no-speech correctly instead of collapsing it to `apiError`. |
| `lib/data/transcription/cloud_transcription_service.dart` | Modify | Return terminal `nothingCaught` failures without a retryable audio path for blank or otherwise non-usable success payloads and delete live temp audio when the service owns it. |
| `lib/domain/usecase/cleanup_transcript_use_case.dart` | Modify | Let cleanup own quota publication for successful transcription paths by accepting fallback transcription quota when cleanup has no quota of its own. |
| `lib/data/launch/app_launch_providers.dart` | Modify | Wire launch-retry quota publication through the shared session quota notifier. |
| `lib/domain/usecase/retry_pending_drafts_use_case.dart` | Modify | Pass successful draft-transcription quota into cleanup retry as fallback quota and publish failed-transcription quota from launch retry. |
| `lib/presentation/main/main_recording_controller.dart` | Modify | Treat no-word transcription failures as non-retryable before attempting audio-draft persistence. |
| `test/data/api/backend_client_test.dart` | Modify | Cover that blank backend transcription success payloads are preserved for caller classification rather than rewritten to `apiError`. |
| `test/data/transcription/cloud_transcription_service_test.dart` | Modify | Update no-speech coverage to include blank and punctuation-only success payloads while keeping retryable failure and draft-audio ownership coverage intact. |
| `test/domain/usecase/cleanup_transcript_use_case_test.dart` | Modify | Cover cleanup fallback quota behavior when cleanup returns no quota, exits locally after successful transcription, or both cleanup and fallback quota are absent. |
| `test/domain/usecase/retry_pending_drafts_use_case_test.dart` | Modify | Cover launch-retry failed-transcription quota publication while preserving the draft audio. |
| `test/presentation/main/main_recording_controller_test.dart` | Modify | Cover that `nothingCaught` with an audio path still emits no-match feedback without saving an audio draft or showing preserved-draft state; cover that local audio-draft persistence does not publish an extra quota update. |
| `integration_test/cloud_transcription_service_flow_test.dart` | Modify | Add provider-graph coverage for blank live and blank draft terminal no-word outcomes while keeping quota publication caller-owned. |
| `integration_test/main_recording_controller_flow_test.dart` | Modify | Add provider-graph coverage for no-word recording feedback, no saved draft, unchanged retryable audio-draft behavior, and accurate failed-transcription quota publication after draft preservation. |
| `integration_test/main_screen_flow_test.dart` | Modify if needed | Add visible main-screen no-word feedback coverage if existing integration coverage does not already exercise the user-visible status line for no-match. |

## API contract details

No backend HTTP contract changes are required.

The app-facing transcription contract after this change:

- Blank successful transcription payload from a live recording returns
  `TranscriptionFailureReason.nothingCaught`.
- That no-word live result has no retryable audio-draft path.
- Live temporary audio for that no-word result is deleted best-effort by the
  service.
- Blank successful transcription payload from caller-owned draft audio still
  returns `TranscriptionFailureReason.nothingCaught` without transferring audio
  ownership to the service.
- Retryable backend or connectivity failures continue to return a retryable
  audio-draft path for live recordings when usable local audio exists.
- The recording controller never persists an audio draft for
  `TranscriptionFailureReason.nothingCaught`, regardless of whether a result
  object includes an audio path.
- Saving an audio draft does not call any quota updater and does not synthesize
  a quota state.
- `CloudTranscriptionService` returns backend quota in the transcription
  result but does not publish it directly.
- The foreground controller and launch-retry use case publish failed
  transcription quota once from the returned transcription result.
- Successful transcription paths rely on cleanup to publish cleanup quota, or
  the transcription quota fallback when cleanup has no quota.
- Draft persistence success or failure must not overwrite the backend quota
  with another value.

## Data model changes

No data model changes are required.

### Before

```text
TranscriptionFailure(reason, audioDraftPath?)
Entry(isDraft, rawTranscript, cleanedText?, audioPath?)
```

### After

```text
TranscriptionFailure(reason, audioDraftPath?)
Entry(isDraft, rawTranscript, cleanedText?, audioPath?)
```

No new entry state is added. No-word outcomes are represented by transient
recording feedback only.

### Migration

No migration is required. Existing no-word audio drafts created before this
feature are explicitly out of scope and will not be cleaned up by this story.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Blank backend transcription success payload is preserved for caller classification | Unit | `test/data/api/backend_client_test.dart` |
| Blank live transcription success returns `nothingCaught` with no audio-draft path and deletes live temp audio | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Punctuation-only transcription success is treated as `nothingCaught` instead of cleanup input | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Blank draft transcription success remains a caller-owned draft attempt and does not delete caller-owned audio | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Live network/backend failures still preserve retryable audio paths | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Cleanup falls back to transcription quota when cleanup returns no quota after successful transcription | Unit | `test/domain/usecase/cleanup_transcript_use_case_test.dart` |
| Cleanup failure leaves quota unchanged when both cleanup and fallback quota are absent | Unit | `test/domain/usecase/cleanup_transcript_use_case_test.dart` |
| Launch retry publishes failed-transcription quota once while preserving the draft | Unit | `test/domain/usecase/retry_pending_drafts_use_case_test.dart` |
| Controller maps no-word failure to no-match feedback without saving an audio draft, even if an audio path is present | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Controller treats punctuation-only transcription success as terminal no-match without entering cleanup | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Controller still persists audio drafts for retryable transcription failures with usable audio | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Controller preserves backend quota after retryable failure draft saving without publishing a second quota update | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Provider graph returns terminal no-word failure and deletes live temp audio for blank live transcription success | Integration | `integration_test/cloud_transcription_service_flow_test.dart` |
| Provider graph returns terminal no-word failure for blank draft transcription success while keeping caller-owned audio and caller-owned quota publication | Integration | `integration_test/cloud_transcription_service_flow_test.dart` |
| Provider graph shows no-word feedback and leaves no pending draft after a no-word recording result | Integration | `integration_test/main_recording_controller_flow_test.dart` |
| Provider graph treats punctuation-only transcription success as terminal no-match without saving a draft | Integration | `integration_test/main_recording_controller_flow_test.dart` |
| Provider graph still preserves pending audio draft and draft-preserved feedback for retryable live transcription failure | Integration | `integration_test/main_recording_controller_flow_test.dart` |
| Provider graph shows quota remaining from the backend retryable-failure response after local draft save, with no second local quota change | Integration | `integration_test/main_recording_controller_flow_test.dart` |
| Visible main screen shows existing no-match text for no-word recording without saved-draft copy, if not already covered by existing integration tests | Integration | `integration_test/main_screen_flow_test.dart` |

Planned validation commands:

```text
flutter test test/data/transcription/cloud_transcription_service_test.dart test/domain/usecase/cleanup_transcript_use_case_test.dart test/domain/usecase/retry_pending_drafts_use_case_test.dart test/presentation/main/main_recording_controller_test.dart
flutter test -d emulator-5554 integration_test/cloud_transcription_service_flow_test.dart integration_test/main_recording_controller_flow_test.dart integration_test/main_screen_flow_test.dart
flutter analyze
```

If the project requires the existing device-backed integration invocation for
`integration_test`, use that invocation during implementation and record the
exact command and device target in `implementation.md`.

### Android emulator verification

1. Run the focused US-036 integration coverage on an Android emulator.
2. Verify the no-word recording flow reaches existing no-match feedback without
   saved-draft copy and leaves no pending draft.
3. Verify a retryable transcription failure still creates a pending audio draft
   and shows draft-preserved feedback.
4. Verify quota remaining/count reflects the backend failure response once
   after local draft preservation.
5. Record the emulator name/device id, command, and pass/fail evidence in
   `implementation.md`.

### iOS simulator verification

1. Run the focused US-036 integration coverage on an iOS simulator.
2. Verify the no-word recording flow reaches existing no-match feedback without
   saved-draft copy and leaves no pending draft.
3. Verify a retryable transcription failure still creates a pending audio draft
   and shows draft-preserved feedback.
4. Verify quota remaining/count reflects the backend failure response once
   after local draft preservation.
5. Record the simulator name/device id, command, and pass/fail evidence in
   `implementation.md`.

### Validation exception request

None. This story should satisfy the default integration-test coverage plus
Android emulator and iOS simulator verification requirements.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This story is likely to produce durable implementation guidance that no-word
  transcription is terminal and should not become retryable draft data, and
  that local draft preservation must not publish quota consumption. The final
  knowledge-capture gate will decide whether to propose updates to
  `AGENTS.md`, `docs/application-description.md`, or
  `docs/agent-findings.md`.

## Integration notes

This change integrates with the existing recording controller, cloud
transcription service, main-screen feedback resolution, local draft
persistence, session quota feedback, and pending-draft retry behavior. It does
not change backend contracts, cleanup behavior, device registration,
stale-draft cleanup, or entry display behavior beyond preventing newly created
no-word draft rows.

## Rollout & migration

No feature flag, rollout switch, or data migration is required. The change is
backward-compatible for persisted data because it only changes how new no-word
recording outcomes and new draft-save quota feedback are handled. Existing
no-word audio drafts remain governed by the current draft system and are out of
scope.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| A retryable service failure stops preserving audio drafts | Low | High | Keep existing retryable failure paths unchanged and cover them with unit and integration tests. |
| Live no-word temp audio is left behind after removing the draft path | Medium | Medium | Delete service-owned live audio in the no-word branch and assert the file is gone in unit and integration tests. |
| Controller still saves no-word drafts from fake or future service results | Medium | High | Add a controller guard and tests that pass `nothingCaught` with an audio path. |
| Draft save still makes quota appear consumed twice | Medium | High | Add unit and integration coverage that quota after draft preservation equals the backend-provided quota and is not locally advanced again. |
| Draft-audio retry ownership changes accidentally delete caller-owned draft audio | Low | Medium | Preserve existing draft-transcription ownership behavior and keep/adjust tests that assert caller-owned audio remains. |
| Existing no-match UI copy regresses while changing draft behavior | Low | Medium | Use existing feedback mapping and add integration coverage for no-word status without saved-draft copy. |

## Open items from spec

None.
