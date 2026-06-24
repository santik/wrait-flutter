# Feature Specification: Keep Screen On During Recording

> **Feature number:** 021
> **Status:** In Progress
> **Author:** Codex
> **Date:** 2026-06-23
> **Work item:** US-021

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-23 | Draft | Codex | Initial spec created from `plan/us_021.md` and the project SDD workflow |
| 2026-06-23 | Draft | Codex | User approved draft spec for clarify phase |
| 2026-06-23 | Draft | Codex | User clarified keep-awake applies only while foreground recording/listening, not upload or cleanup; app-lock and background count as inactive; manual device lock may override keep-awake |
| 2026-06-23 | Approved | Codex | User approved finalized spec for implementation planning |
| 2026-06-23 | Approved | Codex | User approved the US-021 implementation plan, including the OS idle-lock validation exception, for task breakdown |
| 2026-06-23 | Approved | Codex | User approved the US-021 task list for analysis |
| 2026-06-23 | Approved | Codex | Analysis corrected integration coverage to use a main-screen display-awake flow and found no remaining artifact gaps |
| 2026-06-24 | Approved | Codex | User approved the US-021 analysis for implementation |
| 2026-06-24 | In Progress | Codex | Implementation completed, validation evidence recorded, and the feature is waiting for external `review.md` |
| 2026-06-24 | In Progress | Codex | External review read, remediation plan approved, and review-driven fixes plus revalidation completed; the feature is waiting for the next external review pass or final user direction |
| 2026-06-24 | In Progress | Codex | Second external review read, small test-helper cleanup approved, and remaining low-priority review items were accepted as non-blocking within the approved story scope |

---

## Overview

Wrait should keep the device display awake while a user is actively recording a
voice entry in the foreground. During recording, the user needs to see the
timer, understand that capture is still running, and retain an immediate way to
stop recording; ordinary screen timeout should not dim or lock the device in
the middle of that interaction.

When foreground recording is no longer in progress, Wrait should return the
device to its normal screen-timeout behavior. Uploading, processing, cleanup,
saved, error, deleted, background, and locked states do not require user
attention for this story and should not keep the display awake.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want my screen to stay awake while I am recording an entry so
  that the device does not lock before I finish speaking.
- As a user, I want normal screen timeout behavior to resume after the entry
  flow completes, fails, or is canceled so that Wrait does not keep my device
  awake unnecessarily.
- As a user, I want upload and cleanup work to continue without keeping the
  display awake so that Wrait does not consume extra power when I no longer need
  to watch or control recording.

## Acceptance criteria

- [ ] The device display remains awake while Wrait is in a listening state.
- [ ] The listening-state timer and stop control remain visible during ordinary
      device screen-timeout periods while Wrait is foregrounded.
- [ ] Normal device screen timeout behavior resumes when Wrait returns to an
      idle state.
- [ ] Normal device screen timeout behavior resumes when Wrait starts uploading
      recorded audio.
- [ ] Normal device screen timeout behavior resumes when Wrait starts processing
      a transcript or cleanup result.
- [ ] Normal device screen timeout behavior resumes when an entry reaches a
      saved state.
- [ ] Normal device screen timeout behavior resumes when the active flow reaches
      an error state.
- [ ] Normal device screen timeout behavior resumes when the active flow reaches
      a deleted or canceled state.
- [ ] Normal device screen timeout behavior resumes when Wrait leaves active
      foreground use or becomes locked.
- [ ] The keep-awake behavior is applied only while needed and repeated active
      state updates do not create duplicate or conflicting keep-awake requests.
- [ ] Repeated inactive state updates do not create duplicate or conflicting
      release requests.
- [ ] Keep-awake behavior is cleaned up when Wrait closes or the recording
      surface is disposed.
- [ ] Manual device locking, pressing the power button, power off, and
      operating-system power policies may override Wrait's keep-awake behavior.
- [ ] Keep-awake behavior does not change recording, transcription, cleanup,
      draft retry, quota, entry persistence, app-lock, screenshot prevention, or
      navigation behavior.
- [ ] Keep-awake behavior works on both Android and iOS.
- [ ] Validation evidence includes coverage for entering active recording
      states, returning to inactive states, cleanup on app close or disposal,
      repeated state transitions, plus Android emulator and iOS simulator
      verification unless a planning-time validation exception is explicitly
      approved.

## API contract

This feature does not introduce or modify backend HTTP endpoints. It defines an
application-level display-awake contract for the voice-entry flow.

### Keep-awake inputs

The app may receive or derive these display-awake conditions:

- the voice-entry flow enters listening
- the voice-entry flow leaves listening and enters uploading
- the voice-entry flow leaves listening and enters processing
- the voice-entry flow enters idle
- the voice-entry flow enters saved
- the voice-entry flow enters error
- the voice-entry flow enters deleted or canceled
- the app leaves active foreground use
- the app becomes locked
- the recording surface is disposed or the app closes
- the same active or inactive condition is reported more than once

### Keep-awake outputs

The app can produce:

- normal display timeout behavior
- display-awake behavior while foreground listening is in progress
- cleanup that restores normal display timeout behavior

Functional expectations:

- Foreground listening should keep the display awake.
- Uploading, processing, idle, saved, error, deleted, canceled, background, and
  locked states should restore normal display timeout behavior.
- Cleanup should restore normal display timeout behavior even if the flow ends
  through disposal or app close.
- Duplicate state notifications should not produce conflicting behavior.

## Data model changes

This feature does not require persisted journal data model changes.

Functional state needed by the app may include:

- whether the current voice-entry flow is foreground listening
- whether display-awake behavior is currently active for Wrait

## Dependencies

- [ ] Existing main recording controller states for listening, uploading,
      processing, idle, saved, error, and deleted outcomes
- [ ] Existing app lifecycle and recording-surface disposal behavior
- [ ] Existing app-lock behavior from US-019
- [ ] Existing Android and iOS runtime validation paths
- [ ] Existing screenshot and screen recording prevention behavior from US-020
      where present

## UX / design references

No external design file is provided. The reference behavior is `plan/us_021.md`
and the legacy Android implementation named there:

- `wrait-android/src/main/java/com/wrait/app/MainActivity.kt`

The Flutter behavior should preserve Wrait's minimal voice-first UI while
preventing ordinary screen timeout from interrupting active entry creation.

## Non-functional requirements

- **Performance:** Keep-awake state changes must not add noticeable delay to
  recording start, recording stop, transition to upload, processing,
  saved/error feedback, navigation, app resume, or first render.
- **Security:** Keep-awake behavior must not expose journal content, local file
  paths, backend details, stack traces, secrets, or other sensitive
  implementation details.
- **Reliability:** The app must not leave display-awake behavior active after
  foreground listening ends, after the app locks or backgrounds, after the
  recording surface is disposed, or after the app closes.
- **Scalability:** The behavior should derive from shared voice-entry activity
  state where possible so future active recording states can be handled without
  screen-specific duplication.
- **Observability:** Validation evidence must document active-state
  acquisition, release on upload/processing/inactive states, release on
  app-lock/background, duplicate transition handling, cleanup behavior, and
  Android/iOS runtime verification unless a planning-time exception is
  explicitly approved.

## Out of scope

- Adding a user preference to enable, disable, or configure keep-awake behavior
- Changing device lock settings, system timeout duration, or global power
  settings outside Wrait's active use
- Keeping the display awake while Wrait is uploading, processing, idle, saved,
  error, deleted, backgrounded, locked, or otherwise outside foreground
  listening unless a future approved story expands that behavior
- Changing recording duration limits, recording controls, transcript cleanup,
  draft retry, quota display, backend registration, entry list, entry detail,
  sharing, editing, deletion, local persistence, app-lock, or capture
  prevention behavior
- Adding new foreground success or failure messaging for keep-awake state
- Preventing the user from manually locking the device, pressing the power
  button, powering off, or being interrupted by operating-system power
  constraints outside normal app-controlled display timeout behavior

## Open questions

None.
