# Feature Specification: Audio Recording Service

> **Feature number:** 007
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-10
> **Work item:** US-006

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-10 | Draft | Codex | Initial spec created from `plan/us_006.md`, the project SDD workflow, the broader Flutter functionality roadmap, and the current app context |
| 2026-06-10 | Draft | Codex | Clarify phase resolved concurrent-start behavior, too-short recording validity, and post-auto-stop stop behavior; detailed start-failure categorization remains for later stories |
| 2026-06-10 | In Progress | Codex | Implemented the audio recording service, automated validation, and Android/iOS runtime verification ahead of external review |
| 2026-06-10 | In Progress | Codex | Applied the approved review remediation: active-dispose cleanup, output-path validation, clearer output-file failure handling, cleanup logging, and expanded regression coverage |
| 2026-06-10 | Complete | Codex | External review fixes and approved long-lived documentation updates are applied; the knowledge-capture gate is complete |

---

## Overview

The app needs one cross-platform recording capability that can capture a single
voice session and hand the resulting audio file to later parts of the
voice-diary pipeline. Without this feature, the user can enter the app and see
recording-oriented placeholders, but the core act of capturing spoken audio
for transcription cannot happen yet.

This feature defines the functional expectations for starting a recording,
ending it, enforcing the configured maximum duration, and managing the
resulting audio file long enough for downstream processing and draft retry
flows. It must support the primary "tap to speak, tap to stop" experience
while preserving a backend-compatible audio artifact that later stories can
transcribe, save, retry, or clean up.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want the app to capture my spoken voice when I start recording
  so that the rest of the diary flow can turn it into text.
- As a user, I want recording to stop cleanly when I choose to stop or when
  the maximum allowed duration is reached so that I do not lose the audio I
  just recorded.
- As the app, I want the completed audio file to remain available until
  downstream processing succeeds or fails so that later stories can either
  finish the entry flow or preserve a retryable draft.

## Acceptance criteria

- [ ] The app can begin a new voice recording session and expose that a
      recording is currently active.
- [ ] If a new recording start is requested while another recording session is
      already active, the new request fails and the existing recording
      continues unchanged.
- [ ] When a recording session begins, the app exposes the active session's
      maximum-duration deadline using a monotonic time reference suitable for
      countdown behavior.
- [ ] The app records the session into an app-controlled temporary file that
      is usable by downstream transcription processing and playable by standard
      audio tools.
- [ ] The recorded audio preserves speech-oriented capture characteristics
      required by the product's cloud transcription flow, including one audio
      channel and the configured speech-optimized sampling behavior.
- [ ] A recording shorter than 5 seconds is treated as invalid and is not
      handed off for downstream transcription or draft processing.
- [ ] When the user explicitly stops an active recording, the app ends the
      session cleanly, exposes that recording is no longer active, and returns
      the path to the completed audio file.
- [ ] When the configured maximum recording duration is reached, the app stops
      the active session automatically without requiring additional user input
      and makes the completed audio file available to the caller.
- [ ] If stop is requested when no recording session is active, including
      after a session has already auto-stopped at the hard cap, the request
      fails rather than returning another completed file.
- [ ] The maximum recording duration is driven by app configuration, with the
      current product default applied when no override is provided.
- [ ] The app does not delete the completed audio file immediately after
      recording stops; it remains available for downstream success or retry
      handling.
- [ ] When downstream processing ultimately succeeds, the completed audio file
      is deleted so temporary recording artifacts do not accumulate.
- [ ] When downstream processing fails in a way that should produce a retryable
      draft, the completed audio file remains available on disk for that retry
      flow.
- [ ] The recording feature behaves correctly on both Android and iOS.

## API contract

This feature does not introduce or modify any HTTP endpoint.

It does introduce an application-facing recording contract with these
functional expectations:

- the app can request the start of a recording session for a caller-selected
  output destination
- the app can request the stop of the current recording session and receive the
  resulting completed audio file location
- the app can observe whether a recording session is currently active
- the app can observe the active session's maximum-duration deadline for UI
  countdown behavior while the recording is active

Contract expectations clarified for this story:

- a start request made while another recording is active must fail without
  altering the active session
- a stop request made when no recording is active must fail
- recordings shorter than 5 seconds are invalid and must not produce a
  downstream-consumable completed recording result

Failure behavior that affects user-visible messaging or permission handling is
defined by later stories and depends on this feature exposing enough signal for
callers to respond safely.

## Data model changes

This feature introduces or activates functional application state for:

- one active recording session state
- one current recording output file location for the active or just-completed
  session
- one configured maximum-duration deadline associated with the active session
- one minimum valid recording duration threshold of 5 seconds for deciding
  whether a completed capture can enter downstream processing
- temporary on-disk audio artifacts that may later be deleted or retained for
  draft retry depending on downstream outcomes

Functional expectations:

- Only one recording session may be active at a time.
- The active-session deadline must be derived from the configured hard cap and
  must remain stable for the life of that session.
- A capture shorter than 5 seconds is invalid and must not be treated as a
  successful completed recording for downstream use.
- Completed recording files must live in app-controlled temporary storage until
  later success or retry logic decides whether to delete or keep them.
- This story does not by itself require persistence of recording session state
  across app relaunches.

## Dependencies

- [ ] Existing app runtime configuration for the recording hard-cap value
- [ ] Existing main recording experience that will trigger start and stop
- [ ] Later best-mode transcription and draft-retry flows that consume the
      recorded file
- [ ] Platform microphone access on Android and iOS

## UX / design references

The broader recording interaction is described in `plan/functionality.md`.

This story primarily establishes the shared recording behavior that later UI
and orchestration stories will consume.

## Non-functional requirements

- **Performance:** Starting and stopping a recording should feel responsive and
  should not leave the app appearing stuck while the session state changes.
- **Security:** Recorded audio must remain in app-controlled temporary storage
  and must not be retained longer than the product flow requires.
- **Reliability:** Explicit stop and hard-cap auto-stop must both yield a
  usable completed recording file when the capture is valid, rather than a
  silently lost session.
- **Scalability:** The recording contract should remain reusable by later best
  mode and offline-oriented stories without duplicate capture logic.
- **Observability:** The app should be able to tell whether recording is
  active and when the hard cap will be reached so later UI and orchestration
  layers can react consistently.
- **Compatibility:** The resulting audio file must satisfy the needs of the
  downstream speech-processing flow on both supported mobile platforms.

## Out of scope

- Microphone permission request UX, blocked-permission recovery, or settings
  deep-link behavior
- Transcription, transcript cleanup, draft creation, or draft retry
  orchestration beyond the recording file lifecycle requirements defined above
- Recording-state-machine transitions such as Uploading, Processing, Saved, or
  Error beyond what is needed to expose the active recording session itself
- Offline speech recognition or language selection
- UI animations, countdown rendering, or final status copy
- Background recording, multiple simultaneous recordings, or resuming a
  partially completed session after app termination

## Open questions

None at this stage.
