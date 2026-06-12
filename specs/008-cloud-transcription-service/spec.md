# Feature Specification: Cloud Transcription Service

> **Feature number:** 008
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-12
> **Work item:** US-007

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-12 | Draft | Codex | Initial spec created from `plan/us_007.md`, the project SDD workflow, the current Flutter app state, the broader product flow, and the completed backend/audio foundation stories |
| 2026-06-12 | Draft | Codex | Clarify phase resolved the live flow as sequential, allowed success without detected language when normalization fails, collapsed connectivity issues into one network failure category with logging, required surfacing valid quota whenever the backend includes it, and deletes audio immediately after successful transcription |
| 2026-06-12 | Approved | Codex | User approved the clarified US-007 spec for implementation planning |
| 2026-06-12 | In Progress | Codex | Implemented the cloud transcription service, shared session quota updates, automated coverage, and Android/iOS validation evidence ahead of external review |
| 2026-06-12 | In Progress | Codex | Applied the approved review hardening pass: shared language normalization now lives in `supported_language.dart`, transcription state uses one explicit state model, invalid draft files fail fast before upload, malformed success payloads no longer update shared quota, and validation was re-run on Android and iOS |
| 2026-06-12 | Complete | Codex | User skipped the second-pass review, approved the final long-lived documentation updates, and the knowledge-capture gate was completed |

---

## Overview

The app needs one best-mode transcription capability that can take spoken audio
from capture through backend transcription and return a usable raw transcript
for the rest of the diary pipeline. Without this feature, the Flutter app can
already record audio locally and can already call the backend transcription
endpoint, but it still lacks one application-facing behavior that connects
those pieces into the product's "record, upload, get text" flow.

This feature defines the functional expectations for a best-mode transcription
session, including starting a live capture session, exposing the active
recording deadline, saving the completed audio when recording stops, uploading
that audio for transcription, returning normalized detected-language
information when available, and preserving the audio artifact when
transcription fails in a retryable way. The flow for a live capture is linear:
start recording, stop recording, keep the completed audio artifact, then send
that audio for transcription before another transcription attempt begins. The
feature must support both a fresh live-recording path and a later retry path
for already-retained audio drafts, while leaving transcript cleanup, entry
persistence, and broader UI state orchestration to later stories.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user in Best mode, I want my spoken recording sent to the backend and
  returned as text so that I can create a diary entry from speech with
  cloud-quality transcription.
- As a user in Best mode, I want failed backend transcription attempts to keep
  my recorded audio available for retry so that a temporary outage does not
  force me to record the same entry again.
- As the app, I want detected language and quota data from transcription to be
  surfaced in a normalized, application-usable form so that later features can
  save entries consistently and show accurate quota information.

## Acceptance criteria

- [ ] In Best mode, the app can begin a new live transcription session and
      expose that recording has started together with the active
      maximum-duration deadline for that session.
- [ ] When the user stops a valid live recording session, the app completes the
      recording, retains the resulting audio artifact, and then transitions
      from recording to uploading for that capture before the backend
      transcription result is returned.
- [ ] Live best-mode transcription attempts run sequentially as one linear
      record-then-transcribe flow rather than allowing overlapping
      transcription jobs.
- [ ] The app can submit the completed recorded audio to the existing backend
      transcription endpoint with the required request identity and
      authentication metadata.
- [ ] On a usable backend success response, the app returns the raw transcript
      text, an optional normalized supported detected-language code, and any
      valid quota information included by the backend.
- [ ] Detected language normalization treats underscore and hyphen separators
      equivalently, resolves letter-case variations, and only returns a
      supported canonical language code when the backend-provided value can be
      resolved safely.
- [ ] If the backend returns blank, malformed, or otherwise unusable
      transcription success data, the app does not treat the operation as a
      successful transcription result. A transcription result with usable text
      but an unresolvable detected language still counts as success without a
      detected language value.
- [ ] On timeout or any network/connectivity failure, backend unavailability,
      proxy-authentication failure, or other backend API failure, the app
      returns an application-meaningful failure outcome instead of leaking
      transport-level errors.
- [ ] When the backend includes valid quota information in either a success or
      supported failure response, the app surfaces that quota information to
      callers.
- [ ] When a live transcription attempt fails after a valid recording has been
      captured, the recorded audio remains available on disk and its path is
      returned as retryable draft input for later draft-handling flows.
- [ ] When a live transcription attempt succeeds, the recorded audio file is
      deleted immediately after successful transcription so temporary audio
      artifacts do not accumulate beyond the retry window needed for failures.
- [ ] The app can submit an already-retained audio draft for backend
      transcription without requiring a new live recording session, and that
      retry path follows the same success, normalization, quota, and failure
      rules as a fresh live recording after the upload begins.
- [ ] This story's best-mode transcription behavior works correctly on both
      Android and iOS.

## API contract

This feature does not introduce a new backend endpoint. It consumes the
existing backend transcription endpoint and defines how the app uses it for
both fresh live recordings and retained audio drafts.

### `POST /api/transcribe`

**Purpose:**

Submit a recorded audio artifact for backend transcription and return raw
transcript text, optional normalized detected language, and optional quota
data.

**Request:**

```text
multipart form data containing the recorded audio file, using the backend's
required request shape and request metadata
```

The request includes the app's required device identity and proxy
authentication metadata.

**Response (success):**

```json
{
  "transcript": "Today I went for a walk by the river.",
  "detected_language": "en_US",
  "quota": {
    "limit": 10,
    "count": 4,
    "remaining": 6,
    "resetAt": "2026-06-12T00:00:00Z"
  }
}
```

Functional expectations:

- `transcript` must be non-blank to count as usable success.
- `detected_language` is required by the backend success payload, but if the
  returned value cannot be resolved to a supported canonical language code, the
  transcription still succeeds without a detected language value.
- `quota` may be absent. When present, it must be internally consistent before
  being surfaced as valid quota information.

**Error responses:**

| Status | Body | When |
| --- | --- | --- |
| 401 | `{ "error": "..." }` | Proxy-authentication credential missing or invalid |
| 429 | `{ "error": "...", "quota": { ... } }` | Device has reached the applicable daily quota limit |
| 5xx | `{ "error": "..." }` | Backend unavailable or upstream/internal failure |
| Timeout / connectivity failure | transport-level failure | Request did not complete successfully |
| Other non-success | `{ "error": "..." }` | Request rejected for another backend-defined reason |

This feature also introduces an application-facing contract with these
functional expectations:

- the app can start one live best-mode transcription session and observe that
  recording has started plus the active hard-cap deadline
- the app can stop that live session, keep the completed audio artifact, and
  then trigger the upload phase
- the app can transcribe an already-retained audio draft without starting a
  new recording session
- success returns transcript text, optional normalized language, and optional valid
  quota data
- failure returns an application-meaningful failure reason and, when the
  operation began from a live recording, the retryable audio path plus any
  valid quota data included by the backend

## Data model changes

This feature introduces or activates functional application state for:

- one live best-mode transcription session status while recording is active
- one uploading status while recorded audio is being sent for transcription
- one optional normalized supported detected-language value produced by
  successful transcription
- one transcription result that can represent success or an application-level
  failure reason
- one optional retryable audio-file path returned on failure after a valid live
  recording has already been captured

Functional expectations:

- Live-recording and audio-draft transcription paths must share one consistent
  success and failure result shape once upload begins.
- A successful live transcription deletes its temporary audio artifact
  immediately after the transcription result becomes usable.
- A retryable failure must preserve access to the recorded audio artifact
  rather than returning only an abstract error.
- This story does not by itself require a new persistent database schema or
  direct creation of draft entry records.

## Dependencies

- [ ] Existing audio-recording capability with maximum-duration enforcement and
      caller-visible recording deadline behavior
- [ ] Existing backend transcription endpoint contract and required request
      metadata
- [ ] Existing app/device identity support used by backend calls
- [ ] Existing supported-language catalog and canonical language resolution
      rules
- [ ] Later transcript-cleanup, entry-save, recording-state-machine, and
      draft-retry stories that consume the result of this feature

## UX / design references

The broader user-facing flow is described in `plan/functionality.md`.

This story primarily establishes the best-mode transcription behavior that
later UI, state-machine, and retry flows will consume.

## Non-functional requirements

- **Performance:** Stopping a live recording should promptly produce a completed
  audio artifact and transition into the upload phase for that capture without
  appearing hung.
- **Security:** Recorded audio must remain in app-controlled storage and only
  be retained only as long as needed for a transcription attempt, with
  immediate deletion after successful transcription and retention only for
  retryable failures.
- **Reliability:** Transient backend or connectivity failures must degrade into
  retryable outcomes that preserve the recorded audio artifact.
- **Scalability:** The same transcription behavior should serve both fresh
  recordings and later audio-draft retry flows without duplicated business
  rules.
- **Observability:** The app must be able to observe recording-start and
  uploading phases distinctly enough for later UI and controller layers to
  react consistently, and network-related failures should leave diagnostic
  logging that helps distinguish transient transport issues from backend
  contract problems.
- **Compatibility:** Successful transcription results must expose supported
  canonical language codes that later persistence and cleanup flows can use
  safely.

## Out of scope

- Transcript cleanup or AI post-processing of the raw transcription result
- Saving a completed entry or persisting a draft record in the local database
- Automatic retry of failed drafts on app launch
- Pre-recording network-availability checks or offline-model checks before a
  recording session begins
- User-visible error copy, animations, or full main-screen state-machine
  behavior beyond the recording-started and uploading phases this story needs
- Offline transcription behavior

## Open questions

None at this stage.
