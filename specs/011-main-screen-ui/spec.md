# Feature Specification: Main Screen UI

> **Feature number:** 011
> **Status:** Approved
> **Author:** Codex
> **Date:** 2026-06-12
> **Work item:** US-011

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-12 | Draft | Codex | Initial spec created from `plan/us_011.md`, the project SDD workflow, current recording controller behavior, and the broader product flow |
| 2026-06-12 | Draft | Codex | Clarify phase resolved button/status copy, stats calculation and formatting, countdown behavior, saved auto-clear, quota visibility, and removal of swipe scope |
| 2026-06-13 | Approved | Codex | User approved the finalized US-011 spec for implementation planning |
| 2026-06-13 | Approved | Codex | Removed mode handling from scope; the app always operates in Best mode |

---

## Overview

The app needs its root screen to become the primary recording experience
instead of a placeholder. The main screen must give the user one prominent
action button for writing by voice, clear status feedback underneath the
button for the current recording flow, summary access to existing entries, and
quota visibility when cloud-backed recording has usable quota data.

This feature defines the user-facing main-screen layout, text, animations, and
navigation outcomes that render the already-defined recording state. It does
not redefine the recording pipeline itself, entry-list content, entry-detail
content, quota calculation, or backend behavior; it
specifies how the main screen presents and activates those capabilities.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want a large central action button so that I can start and stop
  voice entry creation without navigating elsewhere.
- As a user, I want the main screen to show clear state-specific feedback so
  that I understand whether the app is ready, listening, uploading,
  processing, saved, blocked, deleted, or waiting for retry.
- As a user, I want visual feedback during active recording and invalid input
  so that I can tell when the app is listening, how much recording time is
  available, or whether it rejected a too-short or silent recording.
- As a user, I want entry statistics to be visible and tappable so that I can
  quickly move from capturing a new entry to browsing prior entries.
- As a user, I want remaining recording quota shown when known so that I
  understand how much recording capacity is available.

## Acceptance criteria

- [ ] The root screen presents the main recording experience with a vertically
      centered stack containing, in order: quota line when visible, circular
      action button, status line, and stats line.
- [ ] All user-visible recording-flow messages appear in the status line below
      the action button.
- [ ] The action button is circular and uses an adaptive diameter equal to 56%
      of the current screen width, clamped between 160dp and 280dp.
- [ ] The adaptive button size responds correctly on narrow phones, larger
      phones, split-screen widths, tablet widths, and landscape layouts.
- [ ] The main action button activates the existing recording flow from idle
      and stops listening while in the listening state.
- [ ] Action-button taps during uploading or processing do not visually imply
      that a second recording can start.
- [ ] The action-button label is `stop` while listening.
- [ ] The action-button label is `wrait` when the app is not listening,
      including idle, uploading, processing, saved, deleted, and error states.
- [ ] The action button uses full opacity during normal interactive states.
- [ ] The action button uses reduced opacity of 0.3 during uploading and
      processing to communicate that the button is temporarily unavailable.
- [ ] A pulse ring animation plays around the action button while listening,
      loops every 1800ms, scales from 1.0 to 1.6, and fades from 0.6 opacity
      to 0 opacity.
- [ ] The pulse ring is not visible when the app is idle, uploading,
      processing, saved, deleted, or in an error state.
- [ ] A countdown ring appears throughout listening and reflects progress
      against the maximum allowed recording length.
- [ ] The countdown ring is hidden outside the listening state.
- [ ] A horizontal shake animation fires once for each too-short or no-match
      recording feedback event.
- [ ] Repeated too-short or no-match feedback events retrigger the shake even
      when the visible status text is unchanged.
- [ ] The status line crossfades when the user-visible recording status text
      changes.
- [ ] Returning-user idle status text is `wrait`.
- [ ] First-time idle status text is `tap button to write`.
- [ ] Tapping the first-time idle status text triggers the same behavior as
      tapping the action button.
- [ ] Listening status text is `listening...`.
- [ ] Uploading status text is `uploading...`.
- [ ] Processing status text is `cleaning up...`.
- [ ] Saved status text is `saved, tap to read`.
- [ ] Saved feedback automatically clears back to idle after the saved display
      window unless another user action or recording-state transition happens
      first.
- [ ] Deleted status text is `deleted`.
- [ ] Too-short status text is `too short · keep talking`.
- [ ] No-match status text is `nothing caught · too quiet?`.
- [ ] Insufficient-permission status text is
      `mic blocked`.
- [ ] Failures that preserve an entry draft show `saved as draft`.
- [ ] Tapping `saved, tap to read` navigates to the detail screen for the
      saved entry.
- [ ] The stats line displays the current entry count and active-day count in
      the format `{count} entries - {days} days`.
- [ ] Stats line wording does not special-case singular values; for example,
      one entry across one active day displays `1 entries - 1 days`.
- [ ] Stats include every stored entry, including drafts.
- [ ] Active days are unique local calendar dates with at least one stored
      entry.
- [ ] The stats line updates when stored entries change.
- [ ] Tapping the stats line navigates to the entry list.
- [ ] When valid quota data is available, the quota line displays
      `{limit} total / {remaining} left`.
- [ ] The quota line remains visible while recording is active when the app is
      recording and valid quota data is available.
- [ ] The quota line is hidden when no valid quota data is available.
- [ ] Main-screen text and interactive regions remain accessible to assistive
      technologies with meaningful labels and actions.
- [ ] The main-screen behavior works correctly on both Android and iOS.

## API contract

This feature does not introduce or modify backend HTTP endpoints. It defines
the application-facing presentation contract for the main screen.

### Main-screen inputs

The main screen consumes:

- current recording state
- whether the user has ever successfully recorded
- saved-entry identifier when the current recording state is saved
- shake-error signal for too-short and no-match feedback
- listening hard-cap deadline when listening
- current entry collection for stats
- current valid quota state when available

### Main-screen outputs

The main screen can request:

- main action-button activation
- saved feedback clearing after the saved display window
- navigation to entry list
- navigation to saved entry detail

Functional expectations:

- UI actions must not create duplicate recording attempts while uploading or
  processing.
- Navigation requests should target existing placeholder routes when the full
  entry-list or entry-detail experiences are not yet implemented.

## Data model changes

This story does not require a persistent database schema change.

Functional data derived or displayed by this feature:

- entry count shown in the stats line
- active-day count shown in the stats line
- visible quota line from the current valid quota state
- first-time idle copy from the existing successful-recording preference
- saved-entry navigation target from the current saved recording state
- countdown progress from the current listening deadline and current time

Functional expectations:

- Stats are derived from stored entries rather than stored as a separate
  persistent counter.
- Stats include all stored entries, including draft entries.
- Active-day count is derived from unique local calendar dates represented by
  the stored entries.
- Quota is displayed only from already-validated quota data.
- No entry records are created, edited, or deleted by the main-screen UI
  itself, except through existing recording-flow activation.

## Dependencies

- [ ] Existing recording state and main action behavior from US-010
- [ ] Existing entry persistence and entry stream behavior
- [ ] Existing successful-recording preference
- [ ] Existing current-session quota state
- [ ] Existing root, entry-list, and entry-detail navigation routes
- [ ] Existing design requirements for adaptive button sizing, pulse timing,
      countdown behavior, reduced button opacity, and main-screen reserved
      regions

## UX / design references

- `plan/us_011.md`
- `plan/functionality.md`
  - F1 - Primary Recording Flow
  - F2 - Entry List
  - F8 - Statistics
  - F10 - Quota Display
  - F16 - Adaptive Button Sizing

## Non-functional requirements

- **Performance:** Main-screen state, stats, quota, and animation updates
  should feel immediate and should not block recording interactions.
- **Security:** The main screen must not expose raw transcript content in
  status, quota, or stats text.
- **Reliability:** Missing quota data, missing saved-entry data, and empty
  entry collections must degrade without crashing.
- **Scalability:** Stats calculation must remain suitable for the local entry
  volumes expected by a personal diary app.
- **Observability:** UI behavior must be testable through visible text,
  navigation outcomes, animation trigger state, and stats/quota updates.
- **Accessibility:** Interactive text, the action button, stats line, quota
  line, and status line must expose meaningful semantics.

## Out of scope

- Changing the recording state machine or recording pipeline behavior
- Implementing the full entry list beyond navigating to the current entry-list
  route
- Implementing the full entry detail experience beyond navigating to the saved
  entry route
- Swipe-up and swipe-down gestures
- Changing quota validation, quota persistence, or backend quota contracts
- Changing microphone permission request behavior beyond the blocked-microphone
  status action
- Entry deletion flows beyond rendering any existing deleted recording state
- Draft retry behavior
- Persistent schema changes

## Open questions

- [ ] None at this stage.
