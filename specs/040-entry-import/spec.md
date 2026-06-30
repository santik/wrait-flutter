# Feature Specification: Entry Import

> **Feature number:** 040
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-30
> **Work item:** US-040

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-30 | Draft | Codex | Initial spec created from the request to import valid CSV records additively with the simplest practical scope |
| 2026-06-30 | Draft | User/Codex | Clarified that import accepts Wrait-produced CSV, preserves draft state as-is, and lives on the entries screen |
| 2026-06-30 | Approved | User | Finalized spec approved for implementation planning |
| 2026-06-30 | Approved | User | Implementation plan approved for task breakdown |
| 2026-06-30 | Approved | User | Task list approved for analysis |
| 2026-06-30 | In Progress | User/Codex | Analysis approved and implementation started |
| 2026-06-30 | In Progress | Codex | Additive CSV import, tests, and dual-platform device integration runs completed; awaiting external review artifact |
| 2026-06-30 | In Progress | User/Codex | External review remediation applied: explicit transactional inserts, import/file size limits, categorized failure feedback, and renewed iOS/Android validation completed |
| 2026-06-30 | Complete | User/Codex | Knowledge-capture updates were approved and applied to long-lived guidance after review remediation and final validation |

---

## Overview

Users who have a valid Wrait-produced CSV record file need a simple way to
bring those records into the app as local diary entries. This complements the
existing CSV export safety-copy flow by allowing records from that export
format to be added back into the local entry list.

The import must be strictly additive: it can create new local records from the
selected CSV, but it must not update, replace, merge, reorder, or delete any
existing app data. To keep the first version simple, the supported import file
is expected to already be valid and in the accepted record format. Unsupported
or unreadable files should fail clearly without changing existing entries.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a diary user, I want to import records from a valid CSV file so that I can
  add those records to my local Wrait entry list.
- As a diary user, I want importing to preserve my existing records exactly so
  that I can use import without risking data loss or unintended edits.
- As a diary user, I want import success and failure to be clearly reported so
  that I know whether records were added.
- As a maintainer, I want the import behavior covered by focused validation so
  that future entry-storage or CSV changes do not silently break additive
  import.

## Acceptance criteria

- [ ] The app provides a clear user-initiated action for importing entry
      records from a CSV file on the entries screen.
- [ ] The import action accepts a valid CSV file produced by Wrait's supported
      export format.
- [ ] A successful import creates new local entry records for every supported
      record in the selected file.
- [ ] Imported records preserve the user-visible record content and metadata
      represented by the supported CSV format, including creation time,
      language, draft state, word count, raw transcript, and cleaned text when
      present.
- [ ] Imported records preserve their CSV draft state as-is: draft records are
      saved as drafts, and saved records are saved as saved records, with no
      hidden state conversion.
- [ ] Importing records is strictly additive: it must not update, overwrite,
      merge, delete, finalize, retry, upload, reorder, or otherwise mutate any
      existing entry or draft.
- [ ] Re-importing the same valid CSV file adds another set of new records
      rather than matching against or modifying records imported earlier.
- [ ] A successful import clearly communicates that import completed and how
      many records were added.
- [ ] Importing a valid CSV file with no records does not crash, does not
      change existing entries, and gives the user an understandable result.
- [ ] If the selected file is missing, unreadable, unsupported, malformed, or
      otherwise cannot be imported, the app clearly communicates the failure
      and leaves existing entries unchanged.
- [ ] Importing records must not import retained audio files, backend
      registration state, device identity, app-lock settings, quota state,
      secrets, encryption keys, stack traces, or unrelated app-private data.
- [ ] Importing records must remain compatible with the current app-lock and
      capture-privacy expectations.
- [ ] Validation evidence includes automated coverage for successful import,
      empty-file import behavior, repeated import behavior, and failure
      handling plus runtime checks on both Android emulator and iOS simulator
      unless a planning-time validation exception is explicitly approved.

## API contract

This feature does not introduce or modify backend HTTP endpoints.

## Data model changes

This feature does not require new user-visible diary fields or changes to the
persisted entry data model.

The import must create new local entries from supported CSV record fields. If
planning identifies that the current entry data shape cannot represent a
supported CSV field without changing the data model, the plan must document the
gap before any code changes are made.

## Dependencies

- [ ] Existing locally stored entry and draft data
- [ ] Existing entry-list behavior
- [ ] Existing CSV export record semantics
- [ ] Existing entry metadata: creation time, language, draft state, word
      count, raw transcript, and cleaned text
- [ ] Platform support for user selection of a local CSV file
- [ ] Existing app-lock and capture-privacy behavior
- [ ] Android emulator validation path
- [ ] iOS simulator validation path

## UX / design references

No external design reference is currently provided.

The import action should live on the entries screen and fit the existing
entry-management experience. It should avoid turning the app into a
general-purpose data migration tool. Success and failure feedback should be
short, clear, and consistent with existing Wrait messaging.

## Non-functional requirements

- **Performance:** Import should complete without noticeable UI jank for normal
  personal CSV sizes. Large imports should avoid blocking entry browsing longer
  than necessary.
- **Security:** Import must be explicitly user-initiated and must accept only
  intended entry-record content from the selected file. It must not expose or
  import secrets, encryption keys, backend configuration, unrelated local file
  paths, retained audio files, or diagnostic internals.
- **Reliability:** Import must be all-or-clear-failure from the user's
  perspective: a success message should only be shown after the new records are
  added, and a failed import must leave existing entries unchanged.
- **Scalability:** The import format and flow should support growth from a few
  records to a large local diary without requiring a future redesign for normal
  personal-use volumes.
- **Observability:** Validation evidence must include automated test output and
  runtime observations showing that valid records are added, existing entries
  remain unchanged, repeated imports remain additive, and invalid import
  attempts fail without mutation.

## Test strategy

Automated validation should cover the additive import behavior at the
repository/use-case boundary and at the user-flow boundary. Required scenarios
include successful import from a valid CSV, empty valid CSV import, repeated
import of the same valid CSV, and failure handling for an unreadable or
unsupported file without changing existing records.

Runtime validation must exercise the user-visible import flow on Android
emulator and iOS simulator unless a planning-time validation exception is
explicitly requested and approved.

## Out of scope

- Updating, replacing, merging, deduplicating, or deleting existing entries
- Treating a repeated import as a restore or synchronization operation
- Importing retained draft audio files
- Importing backend registration state, device identity, preferences, app-lock
  settings, quota state, secrets, encryption keys, or unrelated app-private
  data
- Cloud backup, cloud sync, account-based restore, or cross-device transfer
- Custom field mapping, preview/edit-before-import, conflict resolution, or
  partial-row repair
- Importing arbitrary third-party CSV formats or user-authored CSV files that
  were not produced by Wrait's supported export format
- Redesigning the entries screen beyond the import action and required import
  feedback
- Changing recording, transcription, cleanup, retry, sharing, deletion, app
  lock, export, or capture-privacy behavior except where needed to keep the
  import flow correct and private
- Updating long-lived documentation before the final SDD knowledge-capture gate

## Open questions

No open questions remain in the spec. Clarification answers recorded:

- Import should be limited to CSV files produced by Wrait.
- Imported records should be saved as-is, including draft records staying
  drafts.
- The import action should live on the entries screen.
