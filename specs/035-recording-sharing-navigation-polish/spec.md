# Feature Specification: Recording, Sharing, and Navigation Polish

> **Feature number:** 035
> **Status:** In Progress
> **Author:** Codex
> **Date:** 2026-06-24
> **Work item:** US-035

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-24 | Draft | Codex | Initial spec created from requested recording pulse, share-date, and Android back-button polish |
| 2026-06-24 | Draft | Codex | Clarified shared date/time format and root Android back behavior |
| 2026-06-24 | Approved | User | Finalized spec approved for planning |
| 2026-06-25 | In Progress | Codex | Implementation completed with validation evidence; awaiting external review |
| 2026-06-25 | In Progress | Codex | Approved review remediation implemented; awaiting user validation or another review pass |

---

## Overview

Wrait should make the active recording experience feel more immersive, make
shared records easier to understand outside the app, and support the expected
Android system back behavior throughout app navigation. These changes are
small user-facing polish improvements, but together they reduce friction in
three common moments: recording, sharing a past record, and leaving or backing
out of a screen.

The recording pulse should visually extend to the screen edges and slightly
beyond while recording is active, so the listening state feels intentional at
full-screen scale instead of bounded near the primary action. Shared record
content should include the record's date and time so recipients and users can
understand when the record was created without relying on app context. On
Android, the system back button should behave like the app's own back
navigation wherever a back action is available.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user recording a voice note, I want the recording pulse to reach the
  visible screen boundaries and slightly beyond so that the active listening
  state feels immersive and polished.
- As a user sharing a record, I want the shared content to include the record
  date and time so that the exported text has useful context outside Wrait.
- As a recipient of shared record text, I want to see when the record was
  created so that I can understand the note's timing without asking for extra
  context.
- As an Android user, I want the system back button to perform the same back
  action as the app UI so that navigation follows platform expectations.
- As a maintainer, I want these polish changes covered by focused automated
  and runtime validation so that recording, sharing, and navigation behavior
  stays stable.

## Acceptance criteria

- [ ] While active recording is in progress, the pulse-ring visual reaches all
      visible screen edges and extends slightly beyond them.
- [ ] The active recording pulse remains visually centered on the recording
      experience and does not leave unintended gaps at the edges on supported
      phone viewports.
- [ ] The active recording pulse does not obscure or disable required recording
      controls, recording status text, quota or limit information, navigation
      affordances, permission prompts, or error feedback.
- [ ] The active recording pulse change does not regress the non-recording,
      starting, stopping, processing, success, or error visual states.
- [ ] Sharing a record includes the record date and time in the shared content.
- [ ] The shared date and time use the existing in-app display format and are
      clearly associated with the shared record content.
- [ ] Sharing a record still includes the same record body content that was
      shared before this story, with no intentional loss or truncation.
- [ ] Sharing records with short text, long text, draft-like content where
      sharing is already available, and edited content includes the correct
      date for the record being shared.
- [ ] On Android, pressing the system back button from a screen with an
      available in-app back action returns to the previous app screen.
- [ ] On Android, pressing the system back button from app surfaces without an
      in-app back destination uses the simplest behavior that preserves current
      platform expectations and avoids unnecessary navigation changes.
- [ ] Android system back behavior remains compatible with dialogs, sheets,
      confirmation prompts, text editing, selection, sharing flows, and
      privacy/app-lock surfaces.
- [ ] These changes do not intentionally alter recording persistence,
      transcription, cleanup, backend communication, entry deletion, app-lock,
      or capture-privacy behavior.
- [ ] Validation evidence includes automated coverage for the recording pulse,
      shared date/time content, and Android back-button behavior plus runtime
      checks on both Android emulator and iOS simulator unless a planning-time
      validation exception is explicitly approved.

## API contract

This feature does not introduce or modify backend HTTP endpoints.

## Data model changes

This feature does not intentionally add, remove, or modify persisted data
models. The shared date and time should come from existing record metadata
unless planning identifies and justifies a gap in the current data model.

## Dependencies

- [ ] Existing main recording screen and active recording visual feedback
- [ ] Existing record detail and sharing flow
- [ ] Existing record creation date metadata
- [ ] Existing app navigation behavior and Android runtime navigation
- [ ] Existing dialog, confirmation, text editing, and app-lock behavior
- [ ] Android emulator validation path
- [ ] iOS simulator validation path

## UX / design references

No external design reference is currently provided. The approved behavior should
preserve Wrait's minimal voice-first visual language while making the active
recording pulse feel full-screen and ensuring shared record text remains clear
and readable.

## Non-functional requirements

- **Performance:** Pulse scaling and navigation handling must not add
  noticeable delay to app startup, recording state changes, screen
  transitions, sharing, or entry rendering.
- **Security:** Shared content must include only the intended record date and
  existing shared record body; no additional private metadata, identifiers,
  local file paths, backend details, or diagnostics should be exposed.
- **Reliability:** Recording controls, share actions, and Android back
  navigation must remain predictable across normal, error, and interrupted
  flows.
- **Scalability:** The pulse behavior should support a reasonable range of
  phone viewport sizes and orientations without relying on a single fixed
  screen size.
- **Observability:** Validation evidence must include automated test output and
  runtime observations or screenshots demonstrating the recording pulse,
  shared date/time output, and Android back behavior.

## Out of scope

- Redesigning the recording screen beyond the active pulse-ring sizing behavior
- Changing recording logic, audio capture, transcription, quota calculation, or
  backend behavior
- Adding new share formats, export destinations, file attachments, or share
  customization options
- Changing the record date itself, timezone storage rules, or record ordering
- Redesigning app navigation structure or adding new destinations
- Changing iOS system navigation gestures beyond ensuring existing behavior is
  not regressed
- Changing app-lock, screenshot prevention, screen-recording prevention, or
  privacy-cover behavior
- Updating long-lived documentation before the final SDD knowledge-capture gate

## Open questions

No open questions remain in the spec. Clarification answers recorded:

- Shared record output should include both date and time.
- The shared date and time should use the existing in-app display format.
- Android system back behavior from the main recording screen should use the
  simplest implementation that preserves current platform expectations.
