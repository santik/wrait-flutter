# Feature Specification: Entry List Screen

> **Feature number:** 013
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-14
> **Work item:** US-013

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-14 | Draft | Codex | Initial spec created from `plan/us_013.md`, `plan/functionality.md`, and the project SDD workflow |
| 2026-06-14 | Draft | Codex | Clarify phase resolved draft inclusion, screen-level swipe scope, language visibility, and immediate delete confirmation behavior |
| 2026-06-14 | Approved | Codex | User approved the finalized US-013 spec for implementation planning |
| 2026-06-15 | Complete | Codex | Implementation, review remediation, validation, and approved long-lived documentation updates completed |

---

## Overview

The app needs a dedicated entry-list experience so users can browse the diary
entries they have already saved. The list should be reachable from the main
screen, present entries in a predictable newest-first order, summarize each
entry compactly, and let users continue from browsing into entry detail.

The entry list is also the first deletion surface for stored diary entries. It
must make deletion intentional by revealing a delete affordance through a
controlled row gesture and requiring explicit confirmation before any entry is
removed.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want to open a scrollable list of my diary entries so that I can
  revisit what I have recorded.
- As a user, I want entries shown newest first so that recent diary content is
  easiest to reach.
- As a user, I want each row to show the entry date, time, content preview, and
  language information so that I can recognize an entry without opening it.
- As a user, I want draft entries to appear in the list with clear draft
  status so that pending diary entries are not hidden from me.
- As a user, I want to open an entry from the list so that I can read the full
  detail.
- As a user, I want list deletion to require a deliberate confirmation so that
  accidental swipes do not destroy diary data.
- As a user, I want clear empty and back-navigation states so that the list
  behaves naturally whether or not I have saved entries.

## Acceptance criteria

- [ ] The entry list is reachable from the main screen by tapping the stats
      line.
- [ ] The entry list displays all locally stored diary entries, including draft
      entries.
- [ ] Draft entries are visibly marked as `draft`.
- [ ] Entries are sorted by creation timestamp descending, with the newest
      entry first.
- [ ] Each populated row displays a short day-of-week label, formatted local
      date, and formatted local time derived from the entry creation timestamp.
- [ ] Date and time formatting respects the user's current locale.
- [ ] Each populated row displays a single-line content preview using the first
      line of cleaned entry text when cleaned text exists.
- [ ] If cleaned entry text is unavailable, the row preview uses the first line
      of the raw transcript.
- [ ] Audio-only drafts without cleaned text or transcript remain visible in
      the list and use `pending · will retry` as the row preview.
- [ ] Long content previews stay on one line and truncate with an ellipsis
      instead of wrapping or overflowing.
- [ ] Each populated row displays the entry language display name.
- [ ] Tapping an entry row navigates to that entry's detail screen.
- [ ] Audio-only draft rows do not navigate to entry detail on tap.
- [ ] Swiping a row to the right reveals a destructive delete affordance.
- [ ] The delete affordance is red, contains a trash icon, and occupies an
      80dp-equivalent width when fully revealed.
- [ ] The row deletion gesture settles only into hidden or fully revealed
      positions; it must not remain at arbitrary intermediate offsets after
      the gesture ends.
- [ ] Revealing the delete affordance produces haptic feedback once per reveal
      event.
- [ ] When the row delete affordance becomes fully revealed, the delete
      confirmation dialog appears immediately without requiring a separate tap
      on the delete affordance.
- [ ] Swiping a row does not delete the entry by itself.
- [ ] The delete confirmation dialog uses the title `Delete entry?` and body
      `This entry will be permanently removed.`
- [ ] The delete confirmation dialog uses standard alert-dialog behavior with
      `Cancel` and `Delete` actions.
- [ ] Choosing Cancel dismisses the confirmation dialog without deleting the
      entry and hides the row delete affordance.
- [ ] Choosing Delete removes the selected entry, dismisses the confirmation
      dialog, hides the row delete affordance, and keeps the user on the entry
      list.
- [ ] After a confirmed deletion succeeds, the deleted entry disappears from
      the list.
- [ ] Audio-only draft rows remain swipe-deletable.
- [ ] If deletion fails, the entry remains visible in the list and no false
      deletion state is shown.
- [ ] When there are no browsable entries, the list area shows centered
      `no entries yet` text.
- [ ] Empty state text is not shown when one or more browsable entries exist.
- [ ] A top-left back control returns from the entry list to the main screen.
- [ ] Back navigation does not delete entries or otherwise mutate stored diary
      data.
- [ ] Entry-list text and interactive regions expose meaningful assistive
      technology labels and actions.
- [ ] Assistive technologies can trigger row deletion through a dedicated
      delete action without performing the swipe gesture.
- [ ] The entry-list behavior works correctly on both Android and iOS.

## API contract

This feature does not introduce or modify backend HTTP endpoints. It defines
the application-facing presentation and interaction contract for browsing and
deleting locally stored diary entries.

### Entry-list inputs

The entry list consumes:

- stored diary entry identifiers
- entry creation timestamps
- raw transcripts
- optional cleaned entry text
- draft status
- entry language codes
- current user locale

### Entry-list outputs

The entry list can request:

- navigation back to the main screen
- navigation to a selected entry detail screen
- deletion of a selected entry after confirmation

Functional expectations:

- The list must render without requiring network access.
- Deletion requests must target exactly the entry selected by the user.
- A deletion request must not be issued until the user confirms the
  destructive action.
- The entry-list screen remains the active screen after list deletion.
- Date, time, language, and content preview display must be derived from stored
  entry data rather than duplicating those values in a separate persistent
  display model.

## Data model changes

This story does not require a persistent database schema change.

Functional data used by this feature:

- entry identifier for navigation and deletion
- raw transcript for fallback previews
- optional cleaned text for preferred previews
- draft status for visible draft marking
- language code for language display
- creation timestamp for sorting and localized date/time display

Functional expectations:

- Sorting is derived from entry creation timestamps.
- Content preview is derived at display time from cleaned text or raw
  transcript.
- Language display is derived from each entry language.
- Deleting an entry removes the stored diary entry from subsequent list,
  stats, and detail availability.
- Draft entries remain browseable and visibly marked while they are stored.

## Dependencies

- [ ] Existing local entry persistence and entry streaming behavior
- [ ] Existing main-screen stats interaction from US-011
- [ ] Existing application navigation routes for main, entry list, and entry
      detail
- [ ] Existing entry-detail destination or placeholder destination for opening
      a selected entry
- [ ] Existing deletion capability in the local entry store
- [ ] Device locale availability
- [ ] Platform haptic feedback capability

## UX / design references

- `plan/us_013.md`
- `plan/functionality.md`
  - F2 - Entry List
  - F3 - Entry Detail
  - F4 - Entry Deletion
  - F8 - Statistics
- Reference implementation notes from `plan/us_013.md`:
  - `wrait-android/app/src/main/java/com/wrait/app/ui/entries/EntryListScreen.kt`
  - `wrait-android/app/src/main/java/com/wrait/app/ui/entries/EntryListViewModel.kt`

## Non-functional requirements

- **Performance:** The list should remain smooth while scrolling and while
  revealing or hiding a row delete affordance for the local entry volumes
  expected by a personal diary app.
- **Security:** Entry content should only be displayed from local stored data
  already available to the authenticated app session, and deletion must not
  expose implementation details if it fails.
- **Reliability:** Empty data, missing cleaned text, unsupported locale
  formatting inputs, missing or unknown language data, and deletion failures
  must degrade without crashing.
- **Scalability:** Ordering and preview derivation should remain suitable as a
  user's local diary grows over time.
- **Observability:** Sorting, empty state, navigation, swipe reveal,
  confirmation, deletion, delete failures, haptic-trigger behavior, and
  localized display must be testable through visible UI state, observable app
  outcomes, and developer logging where user-visible state intentionally does
  not change.
- **Accessibility:** Row previews, date/time text, language labels, back
  control, delete affordance, and confirmation actions must be accessible to
  assistive technologies.

## Out of scope

- Creating, recording, transcribing, cleaning up, or retrying entries
- Editing entry text
- Sharing entries
- Entry-detail screen content beyond navigating to the selected entry
- Backend API changes
- Persistent schema changes
- Bulk deletion or multi-select actions
- Search, filtering, grouping, or pagination
- Changing main-screen stats calculation beyond using it as an entry-list
  navigation trigger
- Screen-level swipe navigation, including swipe-up entry-list opening and
  swipe-down back navigation
- Showing entry-deleted feedback on the main screen, unless already provided by
  existing behavior

## Open questions

- [ ] None at this stage.
