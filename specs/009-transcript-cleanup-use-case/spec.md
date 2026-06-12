# Feature Specification: Transcript Cleanup Use Case

> **Feature number:** 009
> **Status:** In Progress
> **Author:** Codex
> **Date:** 2026-06-12
> **Work item:** US-008

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-12 | Draft | Codex | Initial spec created from `plan/us_008.md`, the project SDD workflow, the completed cloud-transcription foundation, the broader product flow, and the current entry persistence behavior |
| 2026-06-12 | Draft | Codex | Clarify phase resolved that full raw transcripts remain stored even when cleanup input is truncated, cleanup supports both fresh and retry paths, transcript language is reused when available with English only as required fallback, blank cleaned-text successes are treated as failures, and draft persistence is incremental across recording, transcription, and cleanup until the full flow succeeds |
| 2026-06-12 | Approved | Codex | User approved the finalized cleanup spec for implementation planning |
| 2026-06-12 | In Progress | Codex | Implemented the cleanup use case, backend malformed-success quota preservation, provider wiring, fresh/retry draft persistence flows, and automated validation on Android and iOS ahead of external review |
| 2026-06-12 | In Progress | Codex | Applied the approved review remediation so invalid or non-draft retry targets fail safely, draft transcript and language updates happen atomically before cleanup, repository persistence/finalization failures return typed cleanup failures instead of crashing, and regression coverage now includes those paths |

---

## Overview

The app needs one best-mode transcript-cleanup capability that can take a raw
spoken transcript plus its language and turn that text into a finalized diary
entry when cleanup succeeds. Without this feature, the Flutter app can already
obtain raw transcript text from the backend and can already persist entries,
but it still lacks the application behavior that turns retryable draft text
into the cleaned-up entry the product is centered around.

This feature defines the functional expectations for one transcript-cleanup
attempt in the best-mode flow. The app must be able to submit raw transcript
text for cleanup, respect the maximum cleanup-input size, surface any returned
quota information, finalize the target entry with cleaned text and a new word
count when cleanup succeeds, and preserve a retryable raw-text draft when
cleanup fails. The same cleanup behavior must support both the fresh
post-transcription path and the already-saved text-draft retry path. This
story also assumes incremental draft persistence across the broader best-mode
flow: a draft is persisted after recording, after transcription, and after
cleanup attempts, and only a fully successful flow clears the draft state.
Later stories will orchestrate when cleanup runs in the main recording flow
and when text drafts are retried automatically.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user in Best mode, I want my raw transcript cleaned up so that my saved
  diary entry reads naturally without filler words or punctuation mistakes.
- As a user in Best mode, I want a cleanup failure to preserve my raw text as
  a draft so that I can still keep what I said and retry later.
- As the app, I want cleanup responses to refresh usable quota information so
  that quota-aware parts of the experience stay accurate during the same app
  session.

## Acceptance criteria

- [ ] The app can submit one raw transcript text plus one language code to the
      existing transcript-cleanup backend capability and receive either a
      successful cleaned-text result or a failure result with an
      application-meaningful reason.
- [ ] The cleanup behavior supports both:
      - a fresh post-transcription attempt before a final entry has been
        produced
      - a retry against an already-saved text draft
- [ ] In the broader best-mode flow, draft persistence happens incrementally
      after recording, after transcription, and after cleanup attempts, so a
      cleanup failure in the fresh post-transcription path still leaves a
      persisted text draft behind.
- [ ] On cleanup success, the target entry is finalized with:
      - the original raw transcript preserved
      - cleaned text stored as the entry's preferred display text
      - `isDraft` cleared
      - word count recalculated from the cleaned text by splitting on
        whitespace and counting non-empty tokens
- [ ] On cleanup failure, the target entry remains a text draft with raw
      transcript content preserved and no cleaned text applied.
- [ ] If a retry cleanup attempt references a missing entry or a finalized
      entry instead of a draft, the app reports cleanup failure without
      crashing and does not create a duplicate finalized entry.
- [ ] Valid quota information returned by the cleanup response is surfaced to
      callers and refreshes the app's current quota state.
- [ ] Missing or invalid quota information from a cleanup response does not
      overwrite the app's last valid quota state.
- [ ] If the raw transcript exceeds 10,000 characters, the cleanup attempt
      handles it gracefully by limiting only the submitted cleanup input to
      10,000 characters while preserving the full stored raw transcript and
      still following the same success and failure rules.
- [ ] If the backend returns a nominal cleanup success with blank or
      whitespace-only cleaned text, the app treats that result as a cleanup
      failure and preserves the draft.
- [ ] The cleanup attempt uses the language already associated with the
      transcript when that language is usable.
- [ ] If a cleanup attempt does not already have a usable transcript language
      and the cleanup request requires one, the app uses English for the
      cleanup request.
- [ ] This transcript-cleanup behavior works correctly on both Android and iOS.

## API contract

This feature does not introduce a new backend endpoint. It consumes the
existing transcript-cleanup endpoint and defines how the app uses it for
best-mode transcript finalization.

### `POST /api/cleanup`

**Purpose:**

Submit raw transcript text and its language for cleanup and return cleaned
text plus optional quota information.

**Request:**

```json
{
  "transcript": "string - raw transcript text, limited to 10000 submitted characters",
  "language": "string - language code associated with the transcript"
}
```

**Response (success):**

```json
{
  "cleanedText": "string - cleaned transcript text to save on the entry",
  "wasTruncated": false,
  "quota": {
    "limit": 10,
    "count": 4,
    "remaining": 6,
    "resetAt": "2026-06-12T00:00:00Z"
  }
}
```

Functional expectations:

- `cleanedText` must be non-blank to count as usable success.
- `quota` may be absent. When present, it must be internally consistent before
  being surfaced as valid quota information.
- The app limits the submitted transcript before the request is sent when the
  raw transcript exceeds the allowed cleanup-input length, but does not
  truncate the stored raw transcript for that reason alone.
- The app uses the language already associated with the transcript when that
  language is usable.
- If the cleanup request requires a language and no usable transcript language
  is available from earlier steps, the app uses English as the fallback
  request language.

**Error responses:**

| Status | Body | When |
| --- | --- | --- |
| 401 | `{ "error": "..." }` | Proxy-authentication credential missing or invalid |
| 413 | `{ "error": "..." }` | Submitted cleanup input rejected as too large |
| 429 | `{ "error": "...", "quota": { ... } }` | Device has reached the applicable daily quota limit |
| 5xx | `{ "error": "..." }` | Backend unavailable or upstream/internal failure |
| Timeout / connectivity failure | transport-level failure | Request did not complete successfully |
| Other non-success | `{ "error": "..." }` | Request rejected for another backend-defined reason |

This feature also introduces an application-facing contract with these
functional expectations:

- the app can attempt cleanup for one raw transcript and one language
- success returns cleaned text plus any valid quota information
- failure returns an application-meaningful failure reason plus any valid quota
  information
- success finalizes the target entry
- failure preserves a retryable text draft

## Data model changes

This story changes functional entry state, but it does not require a new
persistent schema.

Functional expectations for the target entry:

- the target entry may already exist as a persisted draft before cleanup
  begins, or it may need to be persisted as part of the fresh
  post-transcription path before cleanup failure is reported
- `rawTranscript` remains the original transcript text captured before cleanup
- if cleanup input had to be truncated for the request, the stored
  `rawTranscript` still remains the full original transcript text
- `cleanedText` becomes populated only after a usable cleanup success
- `isDraft` remains `true` through the incremental recording, transcription,
  and cleanup draft states and becomes `false` only after the full happy-path
  flow completes successfully
- `wordCount` is recalculated from the cleaned text on success
- a cleanup failure preserves the entry as a text draft rather than deleting it
  or converting it back into an audio draft

This story also refreshes the app's current quota state when a cleanup
response includes valid quota data.

## Dependencies

- [ ] Existing best-mode transcription behavior that produces raw transcript
      text and a transcript-associated language when available for later
      cleanup
- [ ] Existing entry persistence with draft and finalized entry states
- [ ] Existing transcript-cleanup backend endpoint contract
- [ ] Existing quota validation rules and current-session quota state
- [ ] Later recording-state-machine and draft-retry stories that will decide
      when cleanup is triggered in the broader app flow

## UX / design references

The broader user-facing flow is described in `plan/functionality.md`.

This story primarily establishes the cleanup behavior that later recording and
draft-retry flows will call.

## Non-functional requirements

- **Performance:** Cleanup input submitted by the app must not exceed 10,000
  characters per attempt.
- **Security:** Transcript and language inputs must be validated before use,
  and backend cleanup continues to require the app's existing request identity
  and authentication behavior.
- **Reliability:** A failed cleanup attempt must preserve the user's raw text
  as a retryable draft instead of losing content.
- **Scalability:** The feature only needs to support one cleanup attempt per
  target transcript at a time; broader orchestration and retry scheduling are
  handled by later stories.
- **Observability:** Cleanup failures should be distinguishable enough for the
  app to react appropriately and for later validation to confirm draft
  preservation behavior.

## Out of scope

- UI state, animations, or button-flow orchestration for recording and saving
- Audio transcription itself
- Offline-mode transcript handling
- Automatic retry scheduling for pending text drafts
- Entry list, detail, or quota presentation UI
- Changes to the backend cleanup endpoint contract itself

## Open questions

- [ ] None at this stage.
