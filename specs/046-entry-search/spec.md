# Feature Specification: Entry list text search

> **Feature number:** 046
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-09-08
> **Work item:** Not assigned

## Status history

| Date       | Status | Author | Notes |
| ---------- | ------ | ------ | ----- |
| 2026-09-08 | Draft  | Codex  | Initial spec for the simplest local entry-list search. |
| 2026-09-08 | Draft  | Codex  | Draft approved; clarification completed and awaiting final spec approval. |
| 2026-09-08 | Approved | Codex | Finalized spec approved for planning. |
| 2026-09-08 | In Progress | Codex | Analysis approved; implementation started on `codex/feat/entry-list-search`. |
| 2026-09-08 | Awaiting External Review | Codex | Implementation and planned validation completed; waiting for externally authored review. |
| 2026-09-09 | Awaiting External Review | Codex | User-requested compact one-row header refinement implemented and revalidated; external review remains deferred until the feature is considered correctly implemented. |
| 2026-09-09 | Awaiting Finalization Approval | Codex | External review was read; the user-approved remediation and Android/iOS validation are complete. Awaiting the durable-documentation decision. |
| 2026-09-10 | Complete | Codex | User approved and received the durable search documentation updates; implementation, review remediation, validation, and finalization are complete. |

---

## Overview

Users can currently browse all saved and draft entries in newest-first order,
but cannot quickly locate an entry by its content. This feature adds a text
search field to the existing entries list so users can narrow the visible
records without leaving the list or changing entry data.

The first version is intentionally small: search is local to the entries list,
does not require a network request, and does not introduce relevance ranking,
fuzzy matching, metadata filters, or semantic search.

## User stories

- As a journal user, I want to search my entries by their written content so
  that I can find a past record quickly.
- As a journal user, I want drafts to remain searchable so that unfinished
  thoughts are not hidden from me.
- As a journal user, I want to clear or remove my search query so that I can
  return to the complete entry list.

## Acceptance criteria

- [x] The entries list contains an accessible search field labelled
      `Search entries`.
- [x] The search field sits in a compact single header row between Back on the
      leading edge and Import/Export on the trailing edge, without reducing
      either action's tap target.
- [x] With an empty or whitespace-only query, the list shows all existing
      entries in the current newest-first order.
- [x] The query is trimmed and split at whitespace. Each remaining term is a
      literal text fragment; punctuation has no special search meaning.
- [x] A non-empty query filters the list to entries for which every query term
      occurs in the entry's cleaned text, raw transcript, or both, without case
      sensitivity and without requiring terms to be adjacent or ordered.
- [x] Search covers both saved entries and drafts.
- [x] An audio-only draft with no transcript text does not match a non-empty
      text query, but remains visible when the query is empty.
- [x] Search results retain the existing row behavior: opening readable
      entries, keeping audio-only drafts non-navigable, and supporting row
      deletion.
- [x] When a non-empty query has no matches, the list shows the distinct text
      `No matching entries` and an accessible `Clear search` action.
- [x] Clearing the query restores the complete list without restarting the
      screen.
- [x] Search input does not open the on-screen keyboard automatically when the
      user first enters the entries list.
- [x] Pressing the keyboard Search action dismisses the keyboard while keeping
      the current query and filtered results visible.
- [x] The query is screen-local: leaving the entries list and opening it again
      starts with the complete, unfiltered list.
- [x] Filtering does not modify, delete, or reorder stored entries beyond the
      existing newest-first presentation rule.
- [x] While a query is active, entry imports, edits, and deletions update the
      visible results to reflect the current stored entries.
- [x] Existing import and export actions continue to operate on the complete
      entry collection rather than silently changing their data scope because
      a search query is active.
- [x] Search text remains local to the device and is not sent to the backend.
- [x] Search text is filtered in memory and is never incorporated into a SQL
      statement or other database query.
- [x] The search field and clear action expose meaningful semantics labels and
      remain usable with the on-screen keyboard and assistive technologies.

## API contract

This feature introduces no HTTP endpoints and does not change the backend API.

## Data model changes

No user-visible entry fields or persisted entry values change. Existing saved
and draft records become searchable through their existing cleaned-text and
raw-transcript values.

## Dependencies

- [x] Existing entries list and entry-row behavior.
- [x] Existing local entry repository and stored entry content.
- [x] Existing import, export, navigation, and deletion flows.

## UX / design references

No external design reference is required for the first version. The search
control should follow the existing entries-screen typography, colors, and
accessibility conventions while sharing a compact top row with Back and the
Import/Export actions.

## Non-functional requirements

- **Performance:** Typing a query should update the visible list promptly for
  the expected local entry volume and must not make the list unusable while the
  keyboard is open.
- **Security:** Search must not transmit entry text or the query to any
  external service. It filters the already loaded local collection in memory,
  never constructs SQL from query text, and leaves existing local-data
  protection unchanged.
- **Reliability:** Blank input, repeated edits, clearing, imports, edits, and
  deletions must leave the displayed results consistent with the stored entry
  collection.
- **Scalability:** Future search-quality improvements may change how results
  are found, but must preserve the stated entry-search behavior unless a later
  approved feature changes the user-facing contract.
- **Observability:** Do not log search queries or entry contents. Search
  failures, if they occur, should use the existing generic user-facing error
  conventions and developer-only diagnostics.

## Out of scope

- Relevance ranking or changing the existing newest-first result order.
- Fuzzy, typo-tolerant, phonetic, or semantic search.
- Accent-insensitive matching, language-aware stemming, and special query
  syntax such as quoted phrases or boolean operators.
- Locale-aware or full Unicode case folding. This first version uses Dart's
  default case conversion for literal matching.
- Search by date, language, draft/saved status, word count, or other metadata.
- Search history, saved searches, or query persistence across app launches.
- Match highlighting or custom search-result snippets.
- Changes to entry import/export file formats.
- Backend search endpoints or cloud indexing.
- Changes to the encrypted database schema or entry model.

## Test strategy

- Widget coverage will verify the compact header geometry, initial unfiltered
  list, whitespace-only and multi-term queries, matching across cleaned and
  raw text, saved and draft results, audio-only draft behavior, newest-first
  ordering, no-results and clear-search behavior, Search-key keyboard
  dismissal, semantics, and no automatic keyboard focus.
- Unit coverage will verify literal punctuation, emoji, repeated terms,
  SQL-shaped text, and a long query without introducing query syntax.
- Entry-list integration coverage will verify navigating to the list, filtering
  records, opening a matching readable record, deleting a matching record,
  returning to the complete list, and keeping import/export behavior scoped to
  the full entry collection while a query is active.
- Android emulator and iOS simulator verification will exercise the real
  entries screen, keyboard interaction, result/no-result states, clear action,
  row navigation, and unchanged import/export controls.

## Open questions

None for the simplest first version. The choices above can be revisited in a
follow-up search-quality story after real usage data is available.
