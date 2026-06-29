# Feature Specification: Entry Type Classification

> **Feature number:** 037
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-29
> **Work item:** US-037

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-29 | Draft | Codex | Initial spec created from request to replace binary entry draft state with entry type classification |
| 2026-06-29 | Draft | Codex | Replaced proposed completed-entry type name from `final` to `saved` because completed entries remain editable |
| 2026-06-29 | Draft | User | User approved the draft spec for clarify phase |
| 2026-06-29 | Draft | Codex | Clarify phase completed with no remaining open questions |
| 2026-06-29 | Approved | User | User approved the finalized spec for implementation planning |
| 2026-06-29 | Approved | User | User approved the implementation plan for task breakdown |
| 2026-06-29 | Approved | User | User approved the task list for analysis |
| 2026-06-29 | Approved | Codex | Analysis completed with no artifact corrections required |
| 2026-06-29 | In Progress | Codex | Implementation completed with focused automated coverage plus Android emulator and iOS simulator integration verification; waiting for external `review.md` |
| 2026-06-29 | In Progress | User | Review remediation changed scope: the entry-type store now rolls out as a fresh local installation with no migration from the legacy `isDraft` database |
| 2026-06-29 | In Progress | Codex | Approved review remediation implemented: the type-based store now uses a fresh database file with constrained persisted types, and focused validation reran cleanly on Android emulator and iOS simulator |
| 2026-06-29 | Complete | Codex | Second external review reported no remaining issues, and durable documentation updates were applied for the fresh-install entry-store rollout |

---

## Overview

Entries currently distinguish draft state with a binary draft marker. That is
too narrow now that entries can be different types. Wrait needs each entry to
carry an explicit type classification so the app can represent drafts and
saved entries today while leaving room for additional entry categories without
adding more unrelated boolean fields.

The change should preserve current user-visible draft and saved-entry behavior
for supported fresh installs. Entry list, detail, retry, cleanup, sharing,
stats, and recording flows should continue to behave consistently using the
new entry classification, but this rollout does not preserve or transform the
legacy `isDraft` local database.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want entry lists, entry details, sharing, deletion, stats, and
  recording completion to keep working the same way after the classification
  change.
- As a maintainer, I want entries to use a single explicit type value instead
  of a draft-only boolean so that future entry categories can be added without
  reshaping the model again.
- As a maintainer, I want invalid or unknown entry type values handled safely
  so that malformed stored data cannot silently enter the wrong workflow.
- As a maintainer, I want the type-based store to initialize as fresh local
  state so the rollout does not depend on preserving or transforming the legacy
  `isDraft` database.

## Acceptance criteria

- [ ] Every entry has exactly one explicit `type` classification.
- [ ] The entry model no longer exposes `isDraft` as the source-of-truth
      classification for normal app behavior.
- [ ] Draft-only behavior continues to apply only to entries with the draft
      type, including pending-draft loading, retry eligibility, stale-draft
      cleanup, draft labels, and draft-specific detail behavior.
- [ ] Saved-entry behavior continues to apply only to entries with the
      saved-entry type, including ordinary list display, detail display,
      sharing where already available, stats counting, and deletion.
- [ ] Recording flows that create a completed saved entry assign the
      saved-entry type.
- [ ] Recording flows that preserve retryable failed work assign the draft
      entry type.
- [ ] Draft promotion changes the entry type from draft to saved entry only
      when the draft is successfully completed.
- [ ] Text drafts and audio drafts remain distinguishable by their existing
      entry content and retained-audio data; the entry type does not erase that
      distinction.
- [ ] Unknown, missing, or invalid entry type values are not treated as
      retryable drafts by default.
- [ ] The change preserves existing entry ordering, timestamps, language,
      transcript content, cleaned text, word counts, retained audio paths, and
      deletion behavior for supported fresh installs.
- [ ] This rollout treats the entry database as fresh local state and does not
      migrate or reinterpret legacy `isDraft` database files.
- [ ] Automated and runtime validation cover new saved entries, new retryable
      drafts, draft retry, draft promotion, entry list/detail behavior, stats,
      and sharing behavior unless a planning-time validation exception is
      explicitly approved.

## API contract

This feature does not introduce or modify backend HTTP endpoints.

### Entry classification contract

Entries expose a `type` classification for application behavior.

Functional expectations:

- The `type` value is required for every entry.
- The draft type identifies entries that are incomplete and eligible for
  draft-specific workflows.
- The saved-entry type identifies completed entries shown as ordinary journal
  records.
- Additional entry types may be introduced by future approved stories without
  reintroducing draft-specific boolean classification.
- Unknown or unsupported type values must be handled explicitly and safely.

## Data model changes

Before this feature, entries use a binary draft classification:

- `isDraft = true`: incomplete draft entry
- `isDraft = false`: completed saved entry

After this feature, entries use an explicit type classification:

- `type = draft`: incomplete draft entry
- `type = saved`: completed saved entry

Fresh-install expectations:

- New entries use the explicit `type` classification from their first write.
- Legacy `isDraft` database files are not migrated or interpreted by this
  story.
- Supported behavior starts from the new type-based local store.

## Dependencies

- [ ] Existing entry list and detail behavior
- [ ] Existing recording completion and retryable-draft preservation behavior
- [ ] Existing pending-draft retry behavior
- [ ] Existing stale-draft cleanup behavior
- [ ] Existing cleanup and draft-promotion behavior
- [ ] Existing entry sharing and deletion behavior
- [ ] Existing entry stats behavior
- [ ] Android emulator validation path
- [ ] iOS simulator validation path

## UX / design references

No external design reference is provided. This feature should preserve the
current visible entry list, detail, draft label, sharing, stats, and recording
feedback behavior unless a later approved phase identifies a required copy or
layout adjustment.

## Non-functional requirements

- **Performance:** Entry classification must not add noticeable delay to app
  startup, entry list rendering, entry detail loading, recording completion,
  draft retry, cleanup, sharing, or deletion.
- **Security:** Invalid entry type handling must not expose local file paths,
  stored transcript internals, database details, stack traces, or diagnostics
  to users.
- **Reliability:** Supported fresh installs must initialize cleanly with the
  type-based schema, and unknown or malformed entry types must not be retried,
  promoted, shared, or displayed as the wrong user-facing category without
  explicit handling.
- **Scalability:** The classification should support future entry categories
  without adding more category-specific boolean source-of-truth fields.
- **Observability:** Validation evidence must include automated test output and
  Android emulator plus iOS simulator runtime observations for entry
  classification behavior unless a planning-time validation exception is
  explicitly approved.

## Out of scope

- Adding new user-visible entry categories beyond the draft and saved-entry
  categories required to replace current behavior
- Changing draft retry timing, retry limits, stale-draft retention age, or
  stale-draft cleanup policy
- Changing recording, transcription, cleanup, quota, backend registration, or
  backend API behavior
- Changing entry list ordering, grouping, filters, visual design, or copy
- Changing entry sharing format, deletion confirmation behavior, or stats
  definitions except where needed to preserve current behavior with entry type
- Migrating or preserving pre-US-037 local entry data from the legacy
  `isDraft` database file
- Cleaning up or repairing already-corrupt local data beyond safe handling of
  unknown or invalid entry type values
- Updating long-lived documentation before the final SDD knowledge-capture gate

## Open questions

None.

Clarification answers recorded:

- Completed but still editable entries use the `saved` type name, not `final`.
