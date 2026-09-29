# Feature Specification: Tap Entry Text To Edit

> **Feature number:** 047
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-09-23
> **Work item:** Not assigned

## Status history

| Date       | Status | Author | Notes |
| ---------- | ------ | ------ | ----- |
| 2026-09-23 | Draft  | Codex  | Initial specification for entering the existing edit mode by tapping the displayed entry text. |
| 2026-09-23 | Draft  | Codex  | User approved the draft. Clarification completed; awaiting finalized-spec approval before planning. |
| 2026-09-23 | Approved | Codex | User approved the finalized specification; plan prepared for approval. |
| 2026-09-23 | Approved | Codex | Plan and tasks approved. Cross-artifact analysis completed in tasks.md; awaiting analysis approval before implementation. |
| 2026-09-23 | In Progress | Codex | Analysis approved; implementation on codex/feat/tap-entry-text-to-edit. Focused tests passed and platform validation is underway. |
| 2026-09-24 | Awaiting External Review | Codex | Implementation, 25 focused tests, clean analysis, and 10 integration flows per platform completed. Awaiting externally authored review.md. |
| 2026-09-24 | In Progress | Codex | External review assessed; user approved fixes for findings 6, 7, and 10, the documented no-change dispositions, and deferral of localization/manual screen-reader testing. Revalidation underway. |
| 2026-09-25 | Awaiting Finalization Approval | Codex | Review fixes validated: 26 focused tests, clean analyzer, and 10 integration tests on each platform with software-keyboard verification enabled. Durable documentation proposals await approval. |
| 2026-09-25 | Complete | Codex | User approved finalization and durable documentation updates; application description and agent findings updated. All SDD gates handled. |

---

## Overview

The entry detail screen currently requires the user to tap the Edit action
before changing an entry's displayed text. This feature makes the displayed
entry body itself an additional way to enter the existing edit mode, reducing
friction when the user's intent is already focused on the text.

Tapping the displayed entry text should have the same observable result as
tapping the existing Edit action. The feature does not require the editor's
cursor to reflect the exact character or location that the user tapped.

## User stories

- As a Wrait user reviewing an entry, I want to tap its displayed text to enter
  edit mode so that I can begin editing without first reaching for the Edit
  action.
- As a Wrait user who is familiar with the existing controls, I want the Edit
  action to remain available so that either entry point works consistently.

## Acceptance criteria

- [x] When the entry detail screen is showing readable entry text outside edit
      mode, a single tap on that displayed text enters edit mode.
- [x] Tap-to-edit applies to whichever entry body is currently displayed,
      including raw transcript text shown when cleaned text is unavailable.
- [x] Scrolling the displayed body does not enter edit mode. Tapping the date,
      word count, or other metadata does not enter edit mode.
- [x] Entering edit mode by tapping the displayed text has the same observable
      result as entering it through the existing Edit action, including showing
      the editable text, focusing it for input, and making the existing Done
      action available.
- [x] The editable text initially contains the same complete text that was
      displayed before the tap; entering edit mode does not alter entry content.
- [x] The cursor position after entering edit mode may follow the existing Edit
      action behavior and is not required to match the position that was tapped.
- [x] The existing Edit action remains available outside edit mode and continues
      to enter the same edit mode.
- [x] Once edit mode is active, text interaction continues to support normal
      cursor placement, selection, and editing behavior.
- [x] Existing save, Done, back-navigation, sharing, deletion, scrolling, and
      error behavior remains unchanged regardless of whether edit mode was
      entered by tapping the text or the Edit action.
- [x] The displayed entry body exposes an accessible indication and action for
      entering edit mode, without removing the accessibility of the existing
      Edit action.
- [x] Loading, missing, invalid, and unreadable entry states do not expose a
      tappable entry body and retain their existing behavior.

## API contract

This feature introduces no HTTP endpoints and does not change the backend API.

## Data model changes

No entry fields, persisted values, or database schema change. Tapping the
displayed text changes only how the existing edit mode is entered.

## Dependencies

- [x] Existing entry detail read and edit modes.
- [x] Existing Edit and Done actions, editor focus behavior, and entry text
      persistence.
- [x] Existing entry-detail widget and integration coverage.

## UX / design references

No external design reference is required. The displayed entry text should keep
the current entry-detail layout and typography while also acting as an entry
point to edit mode.

## Non-functional requirements

- **Performance:** The transition from displayed text to edit mode should feel
  immediate and should not add noticeable delay to opening or scrolling an
  entry.
- **Security:** The feature must not expose, transmit, or log entry content, and
  must preserve the app's existing privacy protections.
- **Reliability:** Repeated entry into edit mode through either supported entry
  point must preserve the full displayed text and the existing save behavior.
- **Scalability:** Long entries must remain readable and scrollable outside edit
  mode and editable within the existing editor.
- **Observability:** No new analytics or entry-content logging is required.

## Out of scope

- Placing the cursor at the character or text position that the user tapped.
- Removing, relocating, or redesigning the existing Edit/Done action.
- Making the entry body permanently editable or eliminating the current
  distinction between read mode and edit mode.
- Changing autosave timing, persistence, sharing, deletion, navigation, or
  error-handling behavior.
- Changing entry-list interactions, import/export behavior, or stored entry
  data.
- Adding text-formatting controls, revision history, or undo history.

## Test strategy

- Widget coverage will verify that tapping readable displayed text enters the
  existing edit mode, preserves the complete displayed content, focuses the
  editor, exposes the Done action, and provides an accessible edit action.
- Existing widget coverage will continue to verify that the Edit action enters
  edit mode and that current saving, sharing, deletion, navigation, and invalid
  entry behavior does not regress.
- Entry-detail integration coverage will verify the in-scope user flow: open a
  readable entry, tap the displayed body, edit the text, complete or leave the
  edit flow, and confirm that the existing persistence behavior is preserved.
- Android emulator and iOS simulator verification will exercise tap-to-edit on
  the real entry detail screen, keyboard focus, text editing, completion, and
  persistence after navigation.
- Approved review follow-up explicitly covers entries over 10,000 characters.
  App-string localization and manual VoiceOver/TalkBack sessions are deferred;
  runtime semantic activation remains covered on both platforms.

## Open questions

None. The user explicitly discarded the older
`043-entry-inline-edit-autosave` proposal on 2026-09-23.

## Clarification outcome

- The entry screen means the existing entry detail screen. The tap target is
  its displayed text body; entry-list rows and detail metadata are excluded.
- The current Edit action defines the resulting edit mode and focus behavior.
  No new rule for the initial cursor position is needed.
- Scrolling remains a reading interaction. Once editing is active, taps retain
  normal editor behavior and do not act as Done.
- No unresolved product decisions remain. The user approved the finalized
  specification on 2026-09-23.
