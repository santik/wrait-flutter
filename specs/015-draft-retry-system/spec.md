# Feature Specification: Draft Retry System

> **Feature number:** 015
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-19
> **Work item:** US-015

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-19 | Draft | Codex | Initial spec created from `plan/us_015.md`, `plan/functionality.md`, current draft persistence vocabulary, and the project SDD workflow |
| 2026-06-19 | Draft | Codex | User clarified single cloud-backed mode, launch-only retry, missing-audio deletion, no success feedback, and retry-failure preservation for quota/proxy failures |
| 2026-06-19 | Draft | Codex | User approved draft spec for clarify phase |
| 2026-06-19 | Draft | Codex | Clarify phase completed with no remaining open questions |
| 2026-06-19 | Approved | Codex | User approved the finalized US-015 spec for implementation planning |
| 2026-06-19 | Approved | Codex | User approved the US-015 implementation plan for task breakdown |
| 2026-06-19 | Approved | Codex | User approved the US-015 task list for analysis |
| 2026-06-19 | Approved | Codex | Analysis added explicit draft-language preservation coverage to the task list |
| 2026-06-19 | Approved | Codex | Implementation completed and documented in `implementation.md`; waiting for external `review.md` and remaining Android emulator verification |
| 2026-06-20 | Approved | Codex | Review remediation implemented, full test suite and Android physical-device validation passed, and Android emulator validation remains blocked pending a successful emulator run or approved exception |
| 2026-06-20 | Approved | Codex | Android emulator validation completed on `emulator-5554`; review remediation is validated across Android emulator, Android device, and iOS simulator targets |
| 2026-06-20 | Complete | Codex | Knowledge-capture gate completed with approved updates to `docs/application-description.md` and `docs/agent-findings.md`; no durable `AGENTS.md` update was needed |

---

## Overview

The app needs to preserve failed recording work as retryable drafts instead of
losing a user's spoken entry when cloud transcription or cleanup cannot
complete. A retryable recording failure should keep enough local data to try
again later, while a cleanup failure after successful transcription should keep
the raw transcript so the app can retry only the remaining cleanup work.

When the app starts and device registration has completed, pending drafts
should be retried automatically in the background. Retry work must not delay
first paint or block normal app use, and failures during retry must keep draft
data intact so the next launch can try again.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want failed recordings to be saved as drafts so that
  temporary network or service problems do not erase what I recorded.
- As a user, I want raw transcripts to be preserved when cleanup fails so that
  the app can finish processing them later without requiring me to record
  again.
- As a user, I want pending drafts to retry automatically on the next app
  launch so that recoverable failures are resolved without manual action.
- As a user, I want old unresolved drafts to be cleaned up automatically so
  stale retry data does not remain forever.
- As a user, I want draft retries to happen quietly in the background so that I
  can open and use the app immediately.

## Acceptance criteria

- [ ] A retryable transcription failure caused by network, timeout, or
      backend/service unavailability saves the retained audio as an audio
      draft when a usable local audio file is available.
- [ ] A successful transcription followed by a cleanup failure saves the raw
      transcript as a text draft.
- [ ] Draft creation for retryable failures does not mark the entry as a final
      readable entry.
- [ ] Draft creation preserves the best available language value for the draft.
- [ ] Draft creation failures do not crash the app or show a false saved/final
      state.
- [ ] On app launch, draft retry begins only after device registration has
      completed successfully.
- [ ] Draft retry eligibility is evaluated only during app launch; if launch
      registration fails, pending drafts wait for a future app launch.
- [ ] Draft retry runs in the background without blocking app startup, first
      rendering, navigation, or the primary recording action.
- [ ] Before loading pending drafts for retry, stale drafts older than 7 days
      are deleted automatically.
- [ ] Stale audio drafts delete their retained local audio file as part of
      stale draft cleanup.
- [ ] Pending drafts are loaded from locally stored entries where
      `isDraft=true`.
- [ ] Pending drafts are retried in descending `createdAt` order.
- [ ] Each pending draft is handled independently, so one draft retry failure
      does not prevent later pending drafts from being attempted in the same
      retry run.
- [ ] For an audio draft with a retained audio file, retry attempts cloud
      transcription using that file.
- [ ] If audio-draft transcription succeeds, the draft's raw transcript is
      updated from the retry result.
- [ ] If audio-draft transcription succeeds with a detected language that
      differs from the draft's stored language, the stored draft language is
      updated to the detected language.
- [ ] After successful audio-draft transcription, cleanup is attempted for the
      resulting raw transcript.
- [ ] If audio-draft transcription and cleanup both succeed, the draft becomes
      a final entry with cleaned text.
- [ ] If audio-draft transcription and cleanup both succeed, the retained
      local audio file is deleted.
- [ ] If audio-draft transcription succeeds but cleanup fails, the draft is
      promoted to a text draft by preserving the raw transcript and removing
      the audio-file association.
- [ ] If audio-draft transcription succeeds but cleanup fails, the retained
      local audio file is deleted after the text draft is preserved.
- [ ] If audio-draft transcription fails, the draft remains an audio draft for
      a future retry.
- [ ] If audio-draft transcription fails, the retained local audio file remains
      available for a future retry.
- [ ] If audio-draft transcription fails because of quota exhaustion or proxy
      authentication failure, the draft remains an audio draft for a future
      eligible launch.
- [ ] If an audio draft references a missing or unreadable audio file, the
      draft is deleted instead of being retried.
- [ ] For a text draft with a raw transcript and no audio file, retry attempts
      cleanup using the stored raw transcript.
- [ ] If text-draft cleanup succeeds, the draft becomes a final entry with
      cleaned text.
- [ ] If text-draft cleanup fails, the draft remains a text draft for a future
      retry.
- [ ] If text-draft cleanup fails because of quota exhaustion or proxy
      authentication failure, the draft remains a text draft for a future
      eligible launch.
- [ ] Finalized drafts are no longer included in subsequent pending-draft retry
      runs.
- [ ] Successfully finalized draft entries appear in the existing entry list,
      entry detail, and stats surfaces according to existing final-entry
      behavior.
- [ ] Successfully finalized drafts do not show separate foreground feedback;
      the finalized entries simply appear through existing entry surfaces.
- [ ] Failed retries leave draft data intact for the next eligible app launch.
- [ ] Quota exhaustion and proxy authentication failures during retry leave
      the draft intact for the next eligible app launch.
- [ ] Draft retry errors are handled gracefully without crashing the app or
      interrupting the active user flow.
- [ ] Draft retry behavior works correctly on both Android and iOS.

## API contract

This feature does not introduce or modify backend HTTP endpoints. It defines
the application-facing contract for saving retryable drafts and automatically
retrying them through the existing cloud transcription and cleanup
capabilities.

### Draft creation inputs

The recording flow consumes:

- transcription outcome
- cleanup outcome
- retained local audio-file availability after retryable transcription failure
- raw transcript from successful transcription
- detected or fallback language
- draft persistence availability

### Draft creation outputs

The recording flow can request:

- creation of an audio draft associated with a retained local audio file
- creation of a text draft associated with a raw transcript
- display of existing non-sensitive failure feedback for the failed recording
  or cleanup operation
- developer logging when draft preservation cannot complete

Functional expectations:

- Audio drafts represent entries that still need transcription and cleanup.
- Text drafts represent entries that already have a raw transcript and still
  need cleanup.
- A draft must not be represented to the user as a final entry until the
  required retry work succeeds.
- Draft creation must not introduce any new backend endpoint dependency.

### Draft retry inputs

The launch retry process consumes:

- successful device registration state
- locally stored draft entries
- draft creation timestamp
- draft raw transcript
- draft language
- optional retained audio-file path
- transcription retry outcome
- cleanup retry outcome

### Draft retry outputs

The launch retry process can request:

- deletion of stale drafts older than 7 days
- transcription retry for audio drafts
- cleanup retry for text drafts and successfully transcribed audio drafts
- updating draft raw transcript and language after successful retry
  transcription
- finalizing a draft with cleaned text
- promoting an audio draft to a text draft after cleanup failure
- deletion of retained audio files after they are no longer needed
- deletion of audio drafts whose retained audio file is missing or unreadable
- preservation of failed drafts for a future launch
- developer logging for retry failures or malformed draft data

Functional expectations:

- Draft retry starts only after the app has the device identity needed for
  backend transcription and cleanup calls.
- Draft retry is launch-only and does not start later in the same app session
  after a failed launch registration recovers.
- Draft retry must not block app startup or normal user interaction.
- Draft retry must be idempotent from the user's perspective: retrying an
  already finalized draft must not create duplicate final entries.
- Retry failures must preserve the latest valid draft state rather than
  partially finalizing an entry.

## Data model changes

This story does not require a new persistent concept beyond locally stored
entries that can distinguish final entries, text drafts, and audio drafts.

Functional data required by this feature:

- entry identifier
- raw transcript, which may be blank for audio drafts before successful retry
  transcription
- optional cleaned text for finalized entries
- draft/final status
- language code
- creation timestamp
- word count
- optional retained audio-file path

Functional expectations:

- Audio drafts store a draft/final marker and a retained audio-file path.
- Text drafts store a draft/final marker and raw transcript without an
  audio-file association.
- Finalized entries clear draft status and expose cleaned text through existing
  final-entry surfaces.
- Stale draft deletion uses the draft creation timestamp.
- Word count reflects the text that is currently available for the stored
  entry state.
- Existing final entries are not modified by stale draft cleanup or pending
  draft retry.
- Audio drafts with missing or unreadable retained audio files are removed
  rather than kept indefinitely.

## Dependencies

- [ ] Existing recording and cloud transcription flow
- [ ] Existing cleanup flow for raw transcripts
- [ ] Existing local entry persistence with draft/final state
- [ ] Existing retained audio-file support for retryable transcription
      failures
- [ ] Existing device registration state for backend transcription and cleanup
      calls
- [ ] Existing entry list, entry detail, and stats behavior for finalized
      entries
- [ ] Existing local audio-file deletion capability
- [ ] Existing developer logging for background failures

## UX / design references

- `plan/us_015.md`
- `plan/functionality.md`
  - F1 - Primary Recording Flow
  - F9 - Draft & Retry System
- Current draft visibility and non-readable audio-draft behavior documented in:
  - `specs/013-entry-list-screen/spec.md`
  - `specs/014-entry-detail-screen/spec.md`

Functional UX notes:

- Draft retry does not introduce a required foreground progress UI.
- Existing failure feedback for failed recording or cleanup should remain
  concise and non-technical.
- Existing entry-list draft visibility should remain stable while drafts are
  pending.
- Finalized retry drafts should appear through existing final-entry surfaces
  without a separate recovery screen.
- Successful background retry should not show a toast, banner, notification, or
  other foreground success message.

## Non-functional requirements

- **Performance:** Draft retry must not block app launch, first rendering, or
  normal foreground interaction. Pending drafts should be retried sequentially
  or otherwise controlled so background work does not overwhelm local storage,
  network, or backend services.
- **Security:** Draft retry must use the same privacy and backend identity
  requirements as ordinary recording. Retained audio files and transcripts
  must remain local except for the existing transcription and cleanup requests
  needed to process them.
- **Reliability:** Network errors, timeouts, backend failures, cleanup
  failures, missing drafts, malformed draft content, failed local updates,
  failed audio-file deletion, and app startup races must fail gracefully without
  crashes, duplicate final entries, or false final/saved states.
- **Scalability:** Retry processing should remain suitable for multiple pending
  drafts without requiring the user to manually process them one by one.
- **Observability:** Draft creation, stale deletion, retry start eligibility,
  per-draft retry success, per-draft retry failure, audio-to-text promotion,
  finalization, language updates, and audio-file deletion outcomes must be
  testable through stored state, existing UI outcomes, and developer logging
  where user-visible state intentionally does not change.
- **Accessibility:** No new user-facing controls are required by this story.
  Existing entry-list and entry-detail accessibility expectations continue to
  apply once drafts become final entries.

## Test strategy

Detailed test coverage belongs in `plan.md`, but the feature will require
coverage for:

- audio draft creation after retryable transcription failures
- text draft creation after cleanup failures
- launch retry eligibility by device registration state
- stale draft deletion before pending draft retry
- audio draft success, audio transcription failure, and audio-to-text promotion
  paths
- missing or unreadable audio-draft file deletion
- text draft cleanup success and cleanup failure paths
- quota exhaustion and proxy authentication retry failures preserving drafts
- language update after retry transcription detects a different language
- startup non-blocking behavior
- Android emulator and iOS simulator verification, unless an explicit
  planning-time exception is approved

## Out of scope

- Manual retry controls or a dedicated draft management screen
- New backend endpoints or backend contract changes
- Retrying drafts before device registration succeeds
- Changing the existing entry-list draft badge or draft row interaction rules
- Making audio-only drafts readable in entry detail before transcription
  succeeds
- Changing quota display behavior
- Editing draft text before cleanup succeeds
- User-facing notifications for successful background retry
- Cross-device draft sync or cloud backup
- Account-based recovery of drafts
- Changing encryption, app lock, screenshot protection, or broader privacy
  features

## Open questions

- [ ] None at this stage.
