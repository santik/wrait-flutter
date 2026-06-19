# Feature Specification: Microphone Permission Handling

> **Feature number:** 012
> **Status:** Approved
> **Author:** Codex
> **Date:** 2026-06-18
> **Work item:** US-012

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-18 | Draft | Codex | Initial spec created from `plan/us_012.md`, current recording behavior, the Android reference implementation, and the project SDD workflow |
| 2026-06-18 | Draft | Codex | Clarified analytics and offline mode as out of scope, blocked status copy, settings behavior, and restricted-permission handling |
| 2026-06-18 | Approved | Codex | User approved the finalized US-012 spec for implementation planning |
| 2026-06-18 | Approved | Codex | User approved the US-012 implementation plan for task breakdown |
| 2026-06-18 | Approved | Codex | User approved the US-012 task list for analysis |
| 2026-06-18 | Approved | Codex | Analysis corrected validation wording to include real Android device verification |

---

## Overview

The app needs to handle recording permissions as part of the voice-first
capture flow rather than exposing system permission failures as dead ends. A
user who starts recording for the first time should be asked for microphone
access at the moment it is needed, and a successful grant should immediately
continue into the recording flow they requested.

When access is denied, blocked, restricted, revoked, or restored through
system settings, the app should keep the main recording experience predictable:
retryable denial should let the user try again, blocked access should clearly
guide the user to settings, returning from settings should recover without
requiring an app restart, and permission loss during active recording should
stop recording safely.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a first-time user, I want the app to request microphone access only when I
  try to record so that the permission prompt has clear context.
- As a user who grants microphone access, I want my original recording action
  to continue so that I do not need to tap twice after approving the prompt.
- As a user who denies microphone access without blocking future prompts, I
  want the app to let me retry from the same recording action later.
- As a user whose microphone access is blocked, restricted, or permanently
  denied, I want a clear status affordance that opens app settings so that I
  can restore access.
- As a user who returns from settings after granting access, I want the blocked
  state to clear automatically so that recording feels recovered.
- As a user who loses microphone access while recording, I want recording to
  stop safely and show a clear non-crashing error so that the app never appears
  to be recording when it cannot capture audio.

## Acceptance criteria

- [ ] If microphone access has not yet been granted, the first user action to
      start recording requests microphone access before recording begins.
- [ ] If microphone access is granted from the request prompt, the app proceeds
      with the same recording attempt without requiring an additional tap.
- [ ] If microphone access is denied in a way that still allows future system
      prompts, the app does not start recording and leaves the user able to
      retry from the recording action on a later tap.
- [ ] Retryable denial does not show the blocked-settings status.
- [ ] If microphone access is permanently denied, blocked by platform policy,
      restricted by the platform, or otherwise cannot be requested again from
      inside the app, the main screen shows `mic blocked · tap settings`.
- [ ] The microphone-blocked status line is tappable and opens the operating
      system's app settings page for Wrait.
- [ ] Tapping the primary recording button while the app is in a
      microphone-blocked state does not start recording without access.
- [ ] Tapping the primary recording button while the app is in a
      microphone-blocked state opens the operating system's app settings page
      for Wrait.
- [ ] If the user grants microphone access from system settings and returns to
      Wrait, the app detects the change and clears the microphone-blocked
      state without requiring an app restart.
- [ ] If the user returns from settings without granting microphone access, the
      microphone-blocked state remains available.
- [ ] If microphone access is revoked while the app is in the foreground and
      no recording is active, the next recording attempt handles the missing
      permission according to the same first-request, retryable-denial, or
      blocked-state rules.
- [ ] If microphone access is revoked while recording is active, the app stops
      the active recording safely, does not continue to upload or save unusable
      audio as a successful entry, and shows a clear microphone-permission
      error state.
- [ ] Permission-related errors do not crash the app and do not leave the
      controller, status line, or recording button in an active-recording
      state after recording has stopped or failed.
- [ ] Existing non-permission recording failures continue to show their
      existing user-facing states.
- [ ] Permission status is checked when the app returns to the foreground so
      system-settings changes are reflected promptly.
- [ ] Main-screen permission states expose meaningful assistive technology
      labels and actions, including the settings action when access is blocked.
- [ ] The behavior works correctly on both Android and iOS for microphone
      access.

## API contract

This feature does not introduce or modify backend HTTP endpoints. It defines
the application-facing contract for recording permission checks, user prompts,
blocked-state recovery, and lifecycle re-checks.

### Permission inputs

The recording experience consumes:

- current microphone access status
- whether the platform can still present a microphone permission prompt
- whether microphone access is blocked, restricted, or permanently denied
- foreground/resume lifecycle events
- active recording state
- operating-system app settings availability

### Permission outputs

The recording experience can request:

- a platform microphone permission prompt
- transition into recording after a successful permission grant
- transition into a retryable permission-denied state
- transition into a microphone-blocked state
- opening the operating system app settings page for Wrait
- safe stop/cancel of an active recording when permission is revoked

Functional expectations:

- Permission prompts must be user-initiated from a recording action.
- The app must not represent recording as active unless required capture
  permission is currently available.
- A blocked permission state must be recoverable through app settings without
  restarting the app.

## Data model changes

This story does not require a persistent database schema change.

Functional state used by this feature:

- current microphone permission state
- whether the current permission denial is retryable or blocked
- current foreground/resume lifecycle state
- current recording state

Functional expectations:

- Permission state is derived from the platform rather than persisted as the
  source of truth.
- Returning from system settings re-checks platform state before clearing or
  preserving blocked feedback.
- Revoking permission during recording does not create a saved diary entry from
  unusable audio.

## Dependencies

- [ ] Existing main-screen recording action and status-line behavior
- [ ] Existing recording controller active, saved, and error states
- [ ] Existing audio capture and transcription flow
- [ ] Existing platform microphone permission declarations
- [ ] Existing iOS microphone and speech-recognition usage descriptions
- [ ] Platform app lifecycle foreground/resume signals
- [ ] Platform app-settings navigation

## UX / design references

- `plan/us_012.md`
- Android reference flow:
  `wrait-android/src/main/java/com/wrait/app/MainActivity.kt`

Functional UX notes:

- The blocked status should be concise and fit the existing reserved main
  status-line area.
- The blocked status should use `mic blocked · tap settings`.
- The blocked status must make the settings action discoverable through visible
  text, tap behavior, and accessibility metadata.
- Existing approved main-screen recording, saved, quota, and error feedback
  should remain visually stable.

## Non-functional requirements

- **Performance:** Permission checks and lifecycle re-checks must not block app
  startup or delay first-frame rendering. Recording should start promptly after
  a successful grant.
- **Security:** The app must never bypass platform permission decisions or
  imply that recording is active without required permission.
- **Reliability:** Permission denial, blocked status, settings round-trips, and
  mid-recording revocation must fail gracefully without crashes, duplicate
  recording starts, or stuck active states.
- **Scalability:** No new scalability requirements.
- **Observability:** No new analytics or telemetry behavior is required for
  this story.

## Test strategy

- Cover permission-state interpretation with lower-level automated tests.
- Cover recording-controller behavior for granted, retryable denial, blocked
  denial, settings recovery, and active-recording revocation.
- Cover main-screen status behavior and accessibility for the blocked settings
  action.
- Cover every in-scope user flow with `integration_test` unless an exception is
  requested and explicitly approved during planning.
- Verify the final implementation on an Android emulator, a real Android
  device, and an iOS simulator unless an exception is requested and explicitly
  approved during planning.

## Out of scope

- Building the analytics system planned by US-022, including microphone
  permission analytics events.
- Adding offline transcription mode, iOS speech-recognition permission
  prompting for offline mode, or broader offline-mode routing.
- Adding a settings screen inside Wrait.
- Changing backend transcription, cleanup, quota, or entry persistence
  behavior except where needed to avoid saving unusable audio after permission
  revocation.
- Changing existing non-permission recording error copy or retry behavior.
- Redesigning the main recording screen outside the permission status
  affordance.

## Open questions

No open questions remain after clarification.
