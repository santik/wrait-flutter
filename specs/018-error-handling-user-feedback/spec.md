# Feature Specification: Error Handling and User Feedback

> **Feature number:** 018
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-22
> **Work item:** US-018

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-22 | Draft | Codex | Initial spec created from `plan/us_018.md`, current Flutter feedback behavior, and the project SDD workflow |
| 2026-06-22 | Draft | Codex | User clarified the app has one Best mode only; offline-mode-specific `ConnectionRequired` and `NotAvailable(lang)` messages are out of scope |
| 2026-06-22 | Draft | Codex | User clarified dot-separated copy, simple current-behavior-preserving scope, universal 3-second auto-clear, and language out of scope |
| 2026-06-22 | Draft | Codex | User approved keeping the current no-draft fallback copy for network, backend, proxy-auth, and generic API failures |
| 2026-06-22 | Draft | Codex | User approved the draft spec for clarify phase |
| 2026-06-22 | Draft | Codex | Clarify phase completed with no remaining open questions |
| 2026-06-22 | Approved | Codex | User approved the finalized US-018 spec for implementation planning |
| 2026-06-22 | Approved | Codex | User approved the US-018 implementation plan for task breakdown |
| 2026-06-22 | Approved | Codex | User approved the US-018 task list for analysis |
| 2026-06-22 | Approved | Codex | Analysis completed with no artifact corrections required |
| 2026-06-22 | Approved | Codex | User approved the US-018 analysis for implementation |
| 2026-06-22 | In Progress | Codex | Implementation completed and documented in `implementation.md`; waiting for external `review.md` and an Android emulator validation decision |
| 2026-06-22 | In Progress | Codex | Review remediation approved and implemented; accepted review findings now have code and test coverage updates |
| 2026-06-22 | Complete | Codex | Android emulator and iOS simulator validation passed, review loop handled, and the knowledge-capture gate concluded with no long-lived documentation updates needed |

---

## Overview

Wrait should explain recording, transcription, cleanup, permission, and
connectivity failures in language that helps the user decide what to do next.
When the app cannot complete a voice entry, the main status line should avoid
technical failure names and instead show concise, friendly, actionable feedback.

Some failures are simple user-correctable recording problems, some require a
permission recovery path, and some are backend or network failures where the
most important reassurance is that the user's recording work was preserved as a
draft when preservation actually succeeded. Non-blocking failures that do not
belong in the main recording status should be shown as transient messages that
do not interrupt the current flow.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want error messages to be short and understandable so that I
  know what happened without reading technical details.
- As a user, I want recording-quality errors to be visually noticeable so that
  I understand the app needs me to try again immediately.
- As a user, I want permission errors to tell me how to recover microphone
  access so that I can keep using voice capture.
- As a user, I want network and service failures to reassure me when my entry
  was saved as a draft so that I do not worry that my recording was lost.
- As a user, I want minor non-blocking failures to appear briefly without
  replacing the main recording status so that I can continue what I was doing.

## Acceptance criteria

- [ ] Every user-visible recording failure maps to approved friendly status
      text; no raw error enum, exception, HTTP status, stack trace, provider
      name, or backend implementation detail is displayed to the user.
- [ ] A too-short recording failure shows `too short · keep talking`.
- [ ] A no-match or nothing-caught recording failure shows
      `nothing caught · too quiet?`.
- [ ] A blocked or insufficient microphone permission failure shows
      `mic blocked · tap settings`.
- [ ] No-internet, network, and timeout failures show
      `no connection · saved as draft` when the failed work was actually
      preserved as a draft.
- [ ] Backend-unavailable failures show
      `service unavailable · saved as draft` when the failed work was actually
      preserved as a draft.
- [ ] Proxy-authentication failures show
      `server config error · saved as draft` when the failed work was actually
      preserved as a draft.
- [ ] Generic API failures show `saved as draft · will retry` when the failed
      work was actually preserved as a draft.
- [ ] Draft-saving reassurance is shown only when the app has successfully
      preserved retryable draft data for the failed work.
- [ ] If draft preservation fails or no usable draft data exists, the app shows
      the current simple fallback copy that does not falsely imply the entry
      was saved: `no connection`, `service unavailable`,
      `server config error`, or `something went wrong`.
- [ ] Too-short and no-match failures trigger a brief horizontal shake of the
      primary recording control.
- [ ] The shake movement oscillates horizontally with decreasing amplitude over
      roughly one third of a second, ending back at rest.
- [ ] No other error category triggers the shake feedback.
- [ ] Every error feedback message returns to the idle status after 3 seconds.
- [ ] Permission-recovery feedback gives the user an actionable way to open the
      relevant app or system settings when settings are needed.
- [ ] Non-blocking failures that are already part of the current product are
      shown as transient toast/snackbar-style messages without replacing the
      current recording status.
- [ ] Transient non-blocking messages do not block recording controls,
      navigation, entry reading, or retryable draft preservation.
- [ ] Error feedback remains accessible to assistive technologies, including
      actionable permission-recovery feedback.
- [ ] Error handling and feedback work on both Android and iOS.
- [ ] The implementation keeps existing behavior when it already satisfies
      these criteria and uses the simplest user-flow-preserving change where
      behavior is missing or mismatched.

## API contract

This feature does not introduce or modify backend HTTP endpoints. It defines
the application-facing feedback contract for failures that can occur while the
user is recording, preserving, retrying, or configuring the voice-entry flow.

### Feedback inputs

The app may receive or derive these user-facing failure categories:

- too-short recording
- no match or nothing caught
- insufficient or blocked microphone permission
- no internet, network failure, or timeout
- backend or service unavailable
- proxy authentication failure
- generic API failure
- non-blocking persistence or settings failure already present in the current
  product scope
- draft preservation succeeded or failed

### Feedback outputs

The app can present:

- main status-line text
- primary recording-control shake feedback
- permission-settings recovery action
- transient non-blocking toast/snackbar-style message
- accessibility label and hint text for actionable feedback

Functional expectations:

- Main status-line feedback must be concise and user-friendly.
- Main status-line feedback must not reveal sensitive journal content.
- Draft-preservation copy must accurately reflect whether retryable draft data
  is available.
- Non-blocking messages must not change the recording state by themselves.
- Permission recovery must remain reachable when the failure requires settings.

## Data model changes

This feature does not require data model changes.

Functional data already needed by the app may include:

- the current recording or processing state
- the current user-facing failure category
- whether the failed work was preserved as a retryable draft

## Dependencies

- [ ] Existing main status-line feedback on the recording screen
- [ ] Existing recording, transcription, cleanup, and draft-preservation
      outcomes
- [ ] Existing microphone permission recovery path
- [ ] Existing transient message surface, or an approved equivalent
- [ ] Android emulator validation path
- [ ] iOS simulator validation path

## UX / design references

No external design file is provided. The reference behavior is `plan/us_018.md`
and the legacy Android implementation named there:

- `wrait-android/src/main/java/com/wrait/app/ui/main/MainScreen.kt`
- `wrait-android/src/main/java/com/wrait/app/ui/main/ButtonArea.kt`
- `wrait-android/src/main/java/com/wrait/app/MainRecordingController.kt`

The Flutter behavior should preserve Wrait's minimal voice-first UI while
making failure states clearer and more reassuring.

## Non-functional requirements

- **Performance:** Error feedback, auto-clear timing, and transient messages
  must not add noticeable delay to recording start, recording stop, status
  updates, navigation, or first render.
- **Security:** Error feedback must not expose stack traces, backend internals,
  proxy secrets, raw journal content, local file paths, or other sensitive
  implementation details.
- **Reliability:** Failure feedback must be accurate, must not falsely claim a
  draft was saved, and must not leave the app stuck in an unrecoverable visible
  error state.
- **Scalability:** The feedback contract should support new failure categories
  by adding explicit user-facing copy rather than falling back to raw technical
  labels.
- **Observability:** Validation evidence must include automated coverage for
  error-to-text mapping, shake triggering, auto-clear behavior, permission
  recovery action, and non-blocking messages, plus Android and iOS runtime
  verification unless a planning-time exception is explicitly approved.

## Out of scope

- Changing backend transcription, cleanup, registration, or retry behavior
- Changing when drafts are created, retried, finalized, or deleted except where
  needed to truthfully report whether a draft was preserved
- Adding modes, offline transcription behavior, offline model availability
  messages, or language availability logic
- Redesigning settings or preferences beyond showing non-blocking failure
  feedback for an in-scope settings save failure
- Adding language settings, language-specific error messages, or
  language-settings persistence behavior
- Redesigning the main recording screen layout beyond the feedback elements
  required by this story
- Changing entry list, entry detail, stats, sharing, editing, or deletion flows
- Showing foreground success feedback for background draft retries

## Open questions

None.
