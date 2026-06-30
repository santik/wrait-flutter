# Feature Specification: Terminal No-Speech Transcription Handling

> **Feature number:** 036
> **Status:** In Progress
> **Author:** Codex
> **Date:** 2026-06-25
> **Work item:** US-036

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-25 | Draft | Codex | Initial spec created from user request to prevent successful no-word transcription results from being saved as retryable drafts |
| 2026-06-25 | Draft | Codex | User approved the draft spec for clarify phase |
| 2026-06-25 | Draft | Codex | Clarify phase completed with no remaining open questions |
| 2026-06-25 | Approved | Codex | User approved the finalized spec for implementation planning |
| 2026-06-25 | Draft | Codex | User added quota correctness to the same story after plan draft; spec returned to draft pending re-approval |
| 2026-06-25 | Draft | Codex | User approved the revised draft spec for clarify phase |
| 2026-06-25 | Draft | Codex | Clarify phase completed for no-word and quota scope with no remaining open questions |
| 2026-06-25 | Approved | Codex | User approved the finalized revised spec for implementation planning |
| 2026-06-25 | Approved | Codex | User approved the revised implementation plan for task breakdown |
| 2026-06-29 | Approved | Codex | User approved the task list for analysis |
| 2026-06-29 | Approved | Codex | User approved the analysis with no artifact corrections required |
| 2026-06-29 | In Progress | Codex | Implementation completed with focused automated coverage, Android emulator verification, and iOS simulator verification; waiting for external `review.md` |
| 2026-06-29 | In Progress | Codex | Review remediation approved and implemented; quota publication is now caller-owned for failed transcription paths and cleanup-owned for successful transcription paths, with focused validation rerun passing |
| 2026-06-30 | In Progress | Codex | User-reported regression reopened US-036 because backend blank-success and punctuation-only success payloads could still reach cleanup and create drafts; remediation approved |

---

## Overview

When a recording completes successfully but transcription does not produce any
usable spoken content, Wrait should treat that outcome as a terminal
recording-quality failure rather than a recoverable service failure. The user
should be told that nothing was caught and can record again, but the app
should not save the audio as a draft that will retry on future launches.

This prevents no-word or otherwise non-usable-transcript recordings from
becoming draft entries that retry
indefinitely until the user manually removes them. Retryable drafts should stay
reserved for failures where a later attempt can reasonably recover the user's
spoken entry, such as network or service availability problems.

Draft preservation must also keep recording quota feedback accurate. Saving a
local draft is not a remote recording attempt and must not make the visible
quota appear consumed twice for the same failed recording outcome. Quota shown
to the user should reflect actual backend-provided quota for remote recording
processing attempts, not local draft-save side effects.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want the app to tell me when no words were caught so that I can
  immediately record again.
- As a user, I do not want silent or unintelligible recordings saved as drafts
  so that my entry list does not accumulate items that can never complete.
- As a user, I want recoverable transcription failures to keep preserving my
  recording as a draft so that temporary service problems do not erase a real
  spoken entry.
- As a user, I want my recording quota to update accurately when a draft is
  saved so that I am not shown an extra consumed recording for local
  preservation work.

## Acceptance criteria

- [ ] When a completed recording produces no detected words or no other usable
      spoken content, the app shows the existing no-match or nothing-caught
      recording feedback.
- [ ] When a completed recording produces no detected words or no other usable
      spoken content, no retryable audio draft is created.
- [ ] When a completed recording produces no detected words or no other usable
      spoken content, the user-visible feedback must not claim that the
      recording was saved as a draft.
- [ ] When a completed recording produces no detected words or no other usable
      spoken content, the captured audio is not retained for future retry.
- [ ] No-word or otherwise non-usable-transcript outcomes do not appear in the
      entry list, entry detail, stats, or pending-draft retry set as saved
      draft entries.
- [ ] Retryable failures caused by network, timeout, backend/service
      unavailability, proxy authentication, quota, or generic service/API
      errors continue to preserve draft data when usable local audio is
      available.
- [ ] Saving a retryable local draft does not itself consume recording quota or
      make the visible quota count increase again.
- [ ] When a retryable failure returns backend quota information, the visible
      quota is updated from that backend-provided quota exactly once for that
      failed recording outcome.
- [ ] When a retryable draft is saved after a failed recording outcome, any
      draft-save fallback or persistence step must not overwrite the visible
      quota with a second locally inferred quota value.
- [ ] No-word transcription outcomes do not create pending drafts that can
      consume quota again through launch-time retry.
- [ ] Too-short recording behavior remains terminal and does not create a
      retryable audio draft.
- [ ] Microphone permission failure behavior remains terminal and does not
      create a retryable audio draft.
- [ ] Existing final-entry creation for recordings with detected words is
      unchanged.
- [ ] The no-word terminal failure behavior works correctly on both Android and
      iOS.

## API contract

This feature does not introduce or modify backend HTTP endpoints. It defines
the application-facing behavior for a transcription attempt that completes but
contains no usable words.

### No-word transcription input

The recording flow may receive a transcription outcome that indicates the audio
upload completed but no words were detected.

### No-word transcription output

The recording flow can present:

- no-match or nothing-caught user feedback
- no saved-draft reassurance
- no final entry
- no retryable audio draft

Functional expectations:

- No-word outcomes are terminal recording-quality outcomes.
- No-word outcomes are distinct from retryable service or connectivity
  failures.
- No-word outcomes must not be represented as final journal entries.
- No-word outcomes must not be represented as retryable drafts.

### Retryable failure output

The existing recording flow can still preserve retryable draft data for
recoverable failures where the original audio may complete successfully on a
later attempt.

Functional expectations:

- Retryable failure categories keep their existing draft-preservation behavior
  when usable local audio is available.
- User feedback for retryable failures continues to accurately state whether a
  draft was actually preserved.
- Local draft preservation does not produce its own quota update.
- Backend-provided quota from the failed remote operation remains the source of
  truth for visible quota after a draft is saved.

## Data model changes

This feature does not require data model changes.

Functional expectations:

- No new persistent entry state is needed for no-word transcription outcomes.
- No-word outcomes should leave no pending draft row behind.
- Existing draft and final-entry data remain compatible.
- No persistent quota state is added for draft preservation.

## Dependencies

- [ ] Existing recording completion flow
- [ ] Existing transcription outcome handling
- [ ] Existing user feedback for no-match or nothing-caught recording failures
- [ ] Existing draft preservation for retryable transcription failures
- [ ] Existing local audio retention and cleanup behavior
- [ ] Existing session recording quota feedback
- [ ] Existing entry list, detail, stats, and pending-draft retry behavior
- [ ] Android emulator validation path
- [ ] iOS simulator validation path

## UX / design references

No external design file is provided. This feature should preserve the current
minimal recording UI and existing no-match or nothing-caught feedback language.

## Non-functional requirements

- **Performance:** No-word handling must not add noticeable delay to recording
  stop, transcription feedback, draft preservation for retryable failures,
  navigation, or first render.
- **Security:** No-word handling must not expose local audio paths, raw backend
  responses, stack traces, or implementation details to the user.
- **Reliability:** No-word outcomes must not leave retained audio or retryable
  draft data that causes repeated future retry attempts. Recoverable failures
  must continue to preserve draft data when available. Draft preservation must
  not double-count or locally infer recording quota consumption.
- **Scalability:** The failure-handling contract should keep terminal
  recording-quality outcomes distinguishable from retryable service failures as
  new failure categories are added.
- **Observability:** Validation evidence must include automated coverage for
  no-word terminal handling, preservation of existing retryable-draft behavior,
  and Android and iOS runtime verification unless a planning-time exception is
  explicitly approved.

## Out of scope

- Changing backend transcription, cleanup, registration, or pending-draft retry
  endpoints
- Adding a new visible draft state for no-word recordings
- Retrying existing no-word audio drafts that were created before this feature
- Cleaning up existing no-word audio drafts that were created before this
  feature
- Changing backend quota accounting, quota response shapes, or quota limits
- Changing stale-draft cleanup timing or retention age
- Changing entry list, entry detail, stats, sharing, editing, or deletion
  behavior except to ensure no new no-word draft entry is created
- Changing no-match or nothing-caught feedback copy or animation
- Changing microphone permission, too-short recording, or successful final-entry
  behavior

## Open questions

None.
