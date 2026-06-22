# Feature Specification: Horizontal Layout Fix

> **Feature number:** 033
> **Status:** Draft
> **Author:** Codex
> **Date:** 2026-06-22
> **Work item:** US-033

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-22 | Draft | Codex | Initial spec created from the request to fix layout in horizontal view |

---

## Overview

Wrait should remain usable when the device is held horizontally, when the app
is shown in a wide viewport, or when the usable height is reduced by system UI.
The current vertical-first experience risks controls, status text, and content
becoming clipped, overlapping, or awkwardly positioned in these layouts.

This story defines the expected user-facing behavior for horizontal layouts:
the primary recording experience, navigation targets, entry reading surfaces,
dialogs, and transient feedback must adapt to the available space without
losing core actions or obscuring journal content.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user holding my phone horizontally, I want the main recording screen to
  remain fully usable so that I can start, stop, and understand recording state
  without rotating the device.
- As a user reviewing entries in horizontal view, I want entry lists and entry
  details to remain readable and navigable so that my journal is not limited to
  portrait orientation.
- As a user on a small or interrupted viewport, I want controls and feedback to
  avoid unsafe screen areas and system overlays so that I can reliably interact
  with the app.
- As a maintainer, I want horizontal-layout behavior to be covered by tests and
  runtime validation so that future UI changes do not reintroduce clipping or
  overlap regressions.

## Acceptance criteria

- [ ] In horizontal view, the main screen shows the primary recording action,
      status text, and entry stats without overlap or unintended clipping.
- [ ] In horizontal view, the user can complete the in-scope main recording
      interactions: start recording, stop recording, observe processing or
      error feedback, and navigate from stats to the entry list.
- [ ] In horizontal view, listening-state visual feedback remains visible and
      does not obscure the primary action, status text, quota text, or stats.
- [ ] In horizontal view, the main screen respects device safe areas and system
      UI so that actionable controls are not hidden behind notches, gesture
      areas, navigation bars, keyboards, or status bars.
- [ ] In horizontal view, entry list rows remain readable, selectable, and
      deletable, including rows with drafts, language labels, and long preview
      text.
- [ ] In horizontal view, entry detail remains readable and supports existing
      actions including share, delete, back navigation, text selection, and
      edit mode where already available.
- [ ] Confirmation dialogs, permission/settings prompts, and transient feedback
      remain visible, readable, and actionable in horizontal view.
- [ ] Horizontal layout behavior does not regress existing portrait behavior on
      phones.
- [ ] Horizontal layout behavior works in constrained-height cases such as
      compact landscape phones and split-screen or resizable app windows where
      the platform supports them.
- [ ] Validation evidence includes automated coverage for horizontal layouts
      plus runtime checks on both Android emulator and iOS simulator unless a
      planning-time validation exception is explicitly approved.

## API contract

This feature does not introduce or modify backend HTTP endpoints.

## Data model changes

This feature does not require data model changes.

## Dependencies

- [ ] Existing main recording screen and recording-state feedback
- [ ] Existing entry list and entry detail screens
- [ ] Existing permission, confirmation, share, delete, and edit flows
- [ ] Android emulator validation path
- [ ] iOS simulator validation path

## UX / design references

No external design reference is currently provided. The approved behavior should
preserve Wrait's minimal voice-first visual language while adapting placement,
spacing, and scrolling to horizontal and constrained-height viewports.

## Non-functional requirements

- **Performance:** Layout adaptation must not add noticeable delay to first
  render, screen transitions, recording state updates, or entry scrolling.
- **Security:** The fix must not weaken existing privacy protections or expose
  journal content outside the current app surfaces.
- **Reliability:** Horizontal and constrained-height layouts must avoid
  overflow, hidden actions, unreadable text, and gesture-only dead ends.
- **Scalability:** The behavior should support a reasonable range of phone
  sizes, platform safe areas, and resizable windows without screen-specific
  special cases becoming the primary layout rule.
- **Observability:** Validation evidence must include screenshots or test
  output demonstrating the main screen, entry list, and entry detail in
  horizontal layout on Android and iOS.

## Out of scope

- Tablet-specific redesign beyond making horizontal layouts usable
- Desktop-specific navigation or keyboard shortcut redesign
- New product flows, new recording states, or changed copy unrelated to layout
- Reworking the app visual identity, typography system, or theme
- Changing backend behavior, local persistence, transcription, cleanup, quota,
  or draft retry behavior
- Adding new entry-management features beyond preserving existing actions in
  horizontal view

## Open questions

- [ ] Should this story cover only phone landscape orientation, or should it
      explicitly include tablet and desktop-width layouts as first-class
      validation targets?
- [ ] Are there specific horizontal-view failures already observed by the user
      that should be captured as must-fix regression cases before planning?
