# Feature Specification: Recording State Machine and Controller

> **Feature number:** 010
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-12
> **Work item:** US-009

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-12 | Draft | Codex | Initial spec created from `plan/us_009.md`, the project SDD workflow, completed recording/transcription/cleanup capabilities, and the broader product flow |
| 2026-06-12 | Draft | Codex | Incorporated user clarifications: US-010 owns network preflight, Offline mode is out of scope, Android controller failure mapping is authoritative, Saved clearing is UI-owned, and new recording attempts must not overwrite previously persisted entries |
| 2026-06-12 | Draft | Codex | Clarify phase completed with no remaining open questions; tightened Best-mode scope and failure mapping language |
| 2026-06-12 | Approved | Codex | User approved the finalized US-009 spec for implementation planning |
| 2026-06-12 | In Progress | Codex | Implementation started for the recording state model, controller provider, and controller/transcription validation coverage |
| 2026-06-12 | In Progress | Codex | Approved review remediation tightened Saved-state entry-id validity and retryable audio-draft-path validation without changing feature scope |
| 2026-06-12 | Complete | Codex | Validation, approved review remediation, and final knowledge capture are complete; durable docs updated and `AGENTS.md` intentionally required no changes |

---

## Overview

The app needs one central recording-flow coordinator that turns the product's
single-button interaction into a complete diary-entry pipeline. Without this
feature, the app has lower-level capabilities for recording audio,
transcribing audio, cleaning transcripts, and saving entries, but it still
lacks the application behavior that decides what happens when the user taps
the main action button and how the rest of the app observes that progress.

This feature defines the functional state model and transition rules for the
Best-mode recording pipeline: ready, recording, uploading, processing, saved,
error, and deleted feedback. It also defines minimum-duration handling,
temporary feedback clearing, successful-entry side effects, and retry behavior
after terminal states. Later UI stories will render these states, later
network-availability work will add the concrete Best-mode connectivity
preflight, later offline work will add Offline-mode recording behavior, and
later list/detail stories will trigger deletion feedback.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want the main recording button to reliably start, stop, and
  complete a recording flow so that I can create diary entries from one simple
  interaction.
- As a user, I want clear temporary feedback when a recording is saved,
  deleted, too short, unavailable, or failed so that I understand what happened
  and can continue without restarting the app.
- As the app, I want one observable source of recording state so that the main
  screen, status text, button behavior, and later navigation can stay
  consistent with the active recording pipeline.
- As the app, I want the Best-mode recording flow routed through the correct
  transcription, cleanup, and save behavior so that the primary cloud-backed
  recording pipeline is controlled from one place.

## Acceptance criteria

- [ ] The app exposes one observable recording state that can represent:
      Idle, Listening, Uploading, Processing, Saved with an entry identifier
      and optional detected language, Error with an application-level failure,
      and Deleted with a deleted-entry count.
- [ ] The app exposes whether the recording pipeline is active; active means
      the state is Listening, Uploading, or Processing.
- [ ] When the action button is activated from Idle, the app starts a new
      independent Best-mode recording attempt unless recording is blocked by
      microphone permission or another in-scope recording-start failure.
- [ ] When the action button is activated from Listening after at least five
      seconds of captured audio, the app stops listening and continues the
      Best-mode recording pipeline.
- [ ] When the action button is activated from Listening before five seconds
      of captured audio, the app reports a TooShort Error and increments the
      shake-error signal exactly once for that failed stop attempt.
- [ ] While the app is Uploading or Processing, action-button activations do
      not start, stop, retry, or otherwise change the active pipeline.
- [ ] When the action button is activated from Saved, Deleted, or any
      retryable Error state other than insufficient permissions, the app starts
      a new independent recording attempt and does not reuse or overwrite any
      previously saved entry.
- [ ] When the action button is activated from an insufficient-permissions
      Error state, the app returns to Idle so the permission-handling behavior
      can take over on the next recording attempt.
- [ ] In Best mode, a valid stopped recording progresses through cloud
      transcription, transcript cleanup, and entry save in order.
- [ ] A new recording attempt creates its own persisted entry or draft record
      when the pipeline reaches the existing persistence point for that
      outcome, and never mutates the entry created by an earlier Saved state.
- [ ] A successful save enters Saved with the created entry identifier and any
      detected language available from the pipeline.
- [ ] Saved is published only when the completed pipeline yields a positive
      persisted entry identifier; missing or non-positive identifiers settle
      into a generic application failure instead of exposing invalid Saved
      state.
- [ ] After the first successful save, the app records that the user has
      created at least one recording.
- [ ] Error states for TooShort and NoMatch increment the shake-error signal so
      the UI can distinguish repeated shake-triggering failures.
- [ ] Error and Deleted feedback automatically clears back to Idle after three
      seconds unless another user action or recording-state transition happens
      first.
- [ ] Saved feedback remains observable until the UI clears it after its
      four-second display window or the user starts another recording; the
      controller does not automatically clear Saved feedback on its own timer.
- [ ] Deletion feedback can be triggered by another app flow with the number
      of entries deleted, then clears according to the same three-second rule
      as Error feedback.
- [ ] All terminal and failure outcomes use application-level failure
      categories rather than leaking lower-level service errors to observers.
- [ ] Failure mapping follows the prior Android controller behavior:
      transcription TooShort maps to TooShort, NothingCaught maps to NoMatch,
      microphone-blocked maps to insufficient permissions, network upload
      failure maps to NoInternet, unavailable backend maps to
      BackendUnavailable, proxy authentication failure maps to ProxyAuthFailed,
      backend API failure maps to ApiFailed, cleanup network or timeout failure
      maps to NoInternet, and other cleanup failures map to ApiFailed.
- [ ] The recording state-machine behavior works correctly on both Android
      and iOS.

## API contract

This feature does not introduce or modify backend HTTP endpoints. It defines
an application-facing recording-flow contract that coordinates existing app
capabilities.

### Recording state observation

Consumers can observe the current recording state.

**State values:**

```text
Idle
Listening
Uploading
Processing
Saved(entryId, detectedLanguage?)
Error(error)
Deleted(count)
```

Functional expectations:

- `entryId` identifies the saved diary entry created by the successful flow.
- `entryId` is always a positive identifier for the saved diary entry created
  by the successful flow.
- `detectedLanguage` is optional and is present only when the Best-mode pipeline
  produced a supported language value.
- `error` is one application-level failure category suitable for UI behavior.
- `count` is the number of entries represented by a deletion feedback event.
- Observers can also read an active flag that is true only while the state is
  Listening, Uploading, or Processing.
- Observers can read a shake-error signal that changes when a TooShort or
  NoMatch error should retrigger shake feedback.

### Action-button activation

Consumers can ask the app to handle the main action-button activation.

**Input:**

```text
Current recording state and elapsed listening duration when applicable
```

**Result:**

```text
The observable recording state transitions according to the accepted state
transition rules, and any successful save or preference side effects are
completed before Saved is reported.
```

**Failure outcomes:**

| Failure | When |
| --- | --- |
| TooShort | User stops listening before the minimum recording duration |
| NoMatch | The Best-mode transcription pipeline cannot produce speech text |
| InsufficientPermissions | Recording cannot begin or continue because required microphone access is unavailable |
| NoInternet / Network / Timeout | A started Best-mode upload fails due to connectivity or timeout after recording |
| BackendUnavailable | A started Best-mode backend operation is unavailable after recording |
| ProxyAuthFailed | A started Best-mode backend operation fails due to backend authentication configuration |
| Other application failure | Any other recording, transcription, cleanup, or save failure that should be visible as a generic recording-flow error |

## Data model changes

This story introduces functional application state for the main recording
pipeline, but it does not require a persistent entry database schema change.

Functional state introduced or activated:

- current recording state
- derived active flag
- shake-error signal for repeated TooShort and NoMatch feedback
- temporary feedback clear behavior for Error and Deleted states
- saved-entry feedback with entry identifier and optional detected language
- successful-recording preference indicating the user has recorded at least
  once

Functional expectations:

- The recording state is runtime application state, not a persisted diary
  entry.
- The successful-recording preference persists after the first completed save.
- A saved entry or draft is created through the existing entry persistence
  behavior for the active recording attempt.
- Starting another recording from Saved replaces the observable Saved feedback
  with the new attempt's state, but the previously saved entry remains
  persisted and must not be reused by the new attempt.
- No new persistent fields are required for existing entries by this feature.

## Dependencies

- [ ] Existing audio-recording capability with minimum-duration invalidation
      and hard-cap behavior
- [ ] Existing Best-mode cloud transcription behavior
- [ ] Existing transcript-cleanup behavior
- [ ] Existing entry persistence behavior
- [ ] Existing preferences behavior for first-recording state
- [ ] Existing supported-language behavior for detected and selected language
      values
- [ ] Later network-availability, UI, permission, deletion,
      offline-transcription, and retry stories that render or extend this
      state-machine behavior

## UX / design references

The user-facing flow is described in `plan/functionality.md`, especially:

- F1 — Primary Recording Flow
- F4 — Entry Deletion
- F12 — Microphone Permission Handling

This story defines the state and transition behavior that later main-screen UI
work will render. It does not define visual layout, animations, labels, or
gesture handling beyond the functional signals needed by those UI features.

## Non-functional requirements

- **Performance:** State changes caused by user action should become
  observable promptly, and active pipeline phases should not allow overlapping
  recording attempts.
- **Security:** Raw audio, transcript text, and saved-entry data continue to
  follow the existing local-storage and backend-authentication rules of their
  respective pipeline steps.
- **Reliability:** Every failed pipeline step must settle into one
  application-level Error state and must not leave observers permanently stuck
  in Listening, Uploading, or Processing.
- **Scalability:** The coordinator only needs to handle one active recording
  pipeline at a time.
- **Observability:** State observers must be able to distinguish listening,
  uploading, processing, saved, deleted, and error feedback states for later UI
  rendering and test validation.

## Out of scope

- Main-screen visual layout, animations, labels, gestures, and navigation
- Entry list and entry detail UI
- Actual delete actions from list or detail screens, beyond accepting deletion
  feedback from those flows
- Best-mode network availability preflight checks; US-010 owns concrete
  connectivity detection and ConnectionRequired behavior
- Offline-mode recording, offline model availability checks, local
  transcription, and offline save routing
- Automatic retry of saved audio or text drafts
- Editing existing diary entries
- Changing backend API contracts
- Introducing new persistent entry fields

## Open questions

- [ ] None at this stage.
