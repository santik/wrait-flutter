# Feature Specification: Entry Detail Screen

> **Feature number:** 014
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-16
> **Work item:** US-014

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-16 | Draft | Codex | Initial spec created from `plan/us_014.md`, `plan/functionality.md`, current entry-list behavior, and the project SDD workflow |
| 2026-06-16 | Draft | Codex | Incorporated user clarifications for edit persistence, missing-entry handling, and failure behavior |
| 2026-06-16 | Draft | Codex | User approved draft spec for clarify phase |
| 2026-06-16 | Draft | Codex | Clarify phase completed with no remaining open questions |
| 2026-06-16 | Approved | Codex | User approved the finalized US-014 spec for implementation planning |
| 2026-06-16 | Approved | Codex | User approved the US-014 implementation plan for task breakdown |
| 2026-06-16 | Approved | Codex | User approved the US-014 task list for analysis |
| 2026-06-17 | Complete | Codex | Implementation, review remediation, validation, and approved long-lived documentation updates completed |

---

## Overview

The app needs a real entry-detail experience so users can open a stored diary
entry and read the full text, not just the compact list preview. The detail
screen should preserve the diary's minimal reading flow while exposing the
entry metadata needed to understand when the entry was created.

Entry detail is also the first place where a user can edit, share, and delete
the currently opened entry. These actions must be deliberate, preserve privacy
expectations around sensitive journal text, and keep navigation predictable
after the action finishes.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want to open a diary entry from the entry list or saved-entry
  feedback so that I can read the full entry text.
- As a user, I want the entry detail to show the entry date, day of week, and
  word count so that I can understand the context of the entry.
- As a user, I want entry text to be selectable so that I can copy part of a
  diary entry when needed.
- As a user, I want to edit the entry text from detail so that I can correct
  transcription or cleanup mistakes after saving.
- As a user, I want to share the entry text through the platform share
  experience so that I can intentionally export an entry.
- As a user, I want deleting an opened entry to require confirmation so that I
  do not accidentally remove diary data.
- As a user, I want simple back navigation from detail to the entry list so
  that browsing entries feels continuous.

## Acceptance criteria

- [ ] Opening `/entry/{id}` for a stored readable entry displays that entry's
      detail screen.
- [ ] Tapping a readable entry row from the entry list opens that entry's
      detail screen.
- [ ] Tapping saved-entry feedback on the main screen opens the saved entry's
      detail screen.
- [ ] The detail screen displays the full cleaned entry text when cleaned text
      exists.
- [ ] If cleaned entry text is unavailable, the detail screen displays the full
      raw transcript.
- [ ] Entry text is selectable and copyable through the platform text-selection
      interaction.
- [ ] The detail screen provides an edit affordance for readable entries.
- [ ] Activating edit allows the user to modify the entry text shown on the
      detail screen.
- [ ] Edited text is saved automatically without requiring an explicit Save
      action.
- [ ] Automatically saved edits become the entry text shown on subsequent
      detail opens.
- [ ] Automatically saved edits update only the stored cleaned entry text; the
      original raw transcript remains unchanged.
- [ ] Automatically saved edits update the entry word count to match the
      edited cleaned text.
- [ ] Automatically saved edits are reflected anywhere the entry preview is
      derived from the stored cleaned entry text.
- [ ] If the user leaves the detail screen after editing, the latest edits are
      preserved automatically.
- [ ] If saving an edit fails, the user is not shown a false saved state and
      the previous stored entry text remains available.
- [ ] The detail screen displays the entry's local day of week and full local
      date derived from the entry creation timestamp.
- [ ] Date display respects the user's current locale.
- [ ] The detail screen displays the entry word count.
- [ ] The word count reflects the stored entry word count for the readable
      entry.
- [ ] The detail content scrolls when the entry text is longer than the
      available viewport.
- [ ] A top-left back control returns from entry detail to the entry list.
- [ ] Back navigation does not mutate stored diary data.
- [ ] A share control is available for readable entries.
- [ ] Activating share opens the platform share experience with the same entry
      text shown on the detail screen.
- [ ] If the platform share experience cannot be opened, the app shows a
      graceful non-crashing failure message without changing the entry.
- [ ] The share failure message does not require exact wording, as long as it
      is clear to the user.
- [ ] A delete control is available for the opened entry.
- [ ] Activating delete shows a confirmation dialog before any deletion
      request is made.
- [ ] The delete confirmation dialog uses the title `Delete entry?` and body
      `This entry will be permanently removed.`
- [ ] The delete confirmation dialog uses standard alert-dialog behavior with
      `Cancel` and `Delete` actions.
- [ ] The detail deletion confirmation wording, action labels, destructive
      semantics, and cancel/delete outcomes match the existing entry-list
      deletion confirmation behavior.
- [ ] Choosing Cancel dismisses the confirmation dialog without deleting the
      entry and keeps the user on the detail screen.
- [ ] Choosing Delete removes the opened entry, dismisses the confirmation
      dialog, and returns the user to the entry list.
- [ ] After a confirmed deletion succeeds, the deleted entry is no longer shown
      in the entry list and is no longer available through its detail route.
- [ ] If deletion fails, the entry remains stored and the user is not shown a
      false deleted state.
- [ ] If deletion fails, the failure is logged for developers without exposing
      implementation details to the user.
- [ ] Opening detail for a missing, deleted, invalid, or unreadable entry does
      not crash and redirects the user to the entry list.
- [ ] Entry-detail text and interactive controls expose meaningful assistive
      technology labels and actions.
- [ ] The entry-detail behavior works correctly on both Android and iOS.

## API contract

This feature does not introduce or modify backend HTTP endpoints. It defines
the application-facing presentation and interaction contract for viewing,
sharing, deleting, and leaving a locally stored diary entry.

### Entry-detail inputs

The entry-detail experience consumes:

- a selected entry identifier
- stored diary entry existence and readability
- entry creation timestamp
- raw transcript
- optional cleaned entry text
- stored word count
- current user locale
- platform share availability
- edited entry text submitted by the user

### Entry-detail outputs

The entry-detail experience can request:

- navigation back to the entry list
- automatically saving edited entry text for the currently opened entry
- sharing of the currently displayed entry text
- deletion of the currently opened entry after confirmation
- display of non-sensitive user feedback when editing, sharing, or deletion
  cannot complete

Functional expectations:

- The screen must render without requiring network access.
- The entry identifier must resolve to exactly one stored entry before
  displaying diary content.
- Edit-save requests must target exactly the entry currently displayed.
- Saved edits must update the stored cleaned text and word count together.
- Saved edits must not overwrite the original raw transcript.
- Share requests must use only the text currently displayed on the detail
  screen.
- Deletion requests must target exactly the entry currently displayed.
- A deletion request must not be issued until the user confirms the
  destructive action.
- Date and word-count display must be derived from stored entry data rather
  than duplicating those values in a separate persistent display model.

## Data model changes

This story does not require a persistent database schema change.

Functional data used by this feature:

- entry identifier for loading, sharing context, deletion, and route
  availability
- raw transcript as fallback readable text
- optional cleaned text as preferred readable text
- word count for the opened entry
- creation timestamp for localized date display

Functional expectations:

- Readable text is derived at display time from cleaned text or raw transcript.
- Editing changes only the stored cleaned text used by detail, previews, and
  sharing.
- Editing keeps the original raw transcript unchanged.
- Editing recalculates and stores the word count for the edited cleaned text.
- Missing, deleted, invalid, or unreadable entries do not create replacement
  diary data and redirect to the entry list.
- Deleting an entry removes the stored diary entry from subsequent detail,
  list, and stats availability.

## Dependencies

- [ ] Existing local entry persistence and per-entry loading behavior
- [ ] Existing entry-list navigation to `/entry/{id}` for readable entries
- [ ] Existing main-screen saved-entry feedback navigation to `/entry/{id}`
- [ ] Existing application navigation routes for main, entry list, and entry
      detail
- [ ] Existing deletion capability in the local entry store
- [ ] Existing entry-list deletion confirmation behavior
- [ ] Existing or new local entry update capability for edited text and word
      count
- [ ] Platform text selection and copy behavior
- [ ] Platform share capability
- [ ] Device locale availability

## UX / design references

- `plan/us_014.md`
- `plan/functionality.md`
  - F3 - Entry Detail
  - F4 - Entry Deletion
  - F5 - Entry Sharing
- Current entry-list behavior documented in:
  - `specs/013-entry-list-screen/spec.md`
  - `docs/agent-findings.md`
- Reference implementation notes from `plan/us_014.md`:
  - `wrait-android/src/main/java/com/wrait/app/ui/entries/EntryDetailScreen.kt`
  - `wrait-android/src/main/java/com/wrait/app/ui/entries/EntryDetailViewModel.kt`

## Non-functional requirements

- **Performance:** Entry detail should open promptly for locally stored diary
  entries and remain smooth while scrolling long text.
- **Security:** Entry text should only be displayed and edited from local
  stored data already available to the authenticated app session. Share is an
  explicit user action and editing or deletion failures must not expose
  implementation details.
- **Reliability:** Missing entries, deleted entries, invalid entry identifiers,
  unreadable entries, empty text, long text, unsupported locale formatting
  inputs, failed edit saves, unavailable share targets, and deletion failures
  must degrade without crashing.
- **Scalability:** Detail rendering should remain suitable for long personal
  diary entries without forcing all entry-management behavior into the detail
  screen.
- **Observability:** Entry loading, missing-entry redirects, date/word-count
  display, edit mode, automatic edit-save success/failure outcomes, share
  success/failure outcomes, confirmation, deletion, delete-failure handling,
  and back navigation must be testable through visible UI state, observable app
  outcomes, and developer logging where user-visible state intentionally does
  not change.
- **Accessibility:** Header actions, edit, share, delete, confirmation actions,
  back navigation, date metadata, word count, readable entry text, and editable
  entry text must be accessible to assistive technologies.

## Out of scope

- Creating, recording, transcribing, cleaning up, or retrying entries
- Swipe or overscroll gesture navigation from the entry-detail screen
- Changing entry-list ordering, row previews, row deletion behavior, or row
  navigation rules
- Introducing a separate deletion confirmation pattern for entry detail
- Making audio-only drafts readable from detail when they have no transcript
  text
- Backend API changes
- Persistent schema changes
- Bulk deletion or multi-select actions
- Search, filtering, grouping, or pagination
- Changing main-screen stats calculation
- Showing entry-deleted feedback on the main screen, unless already provided
  by existing behavior
- In-app share preview, custom share destinations, or share history
- Export formats beyond sharing the currently displayed entry text

## Open questions

- [ ] None at this stage.
