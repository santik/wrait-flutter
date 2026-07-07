# Feature Specification: Entry CSV Without Id

> **Feature number:** 041
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-30
> **Work item:** US-041

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-30 | Draft | Codex | Initial spec created from the request to remove the `id` column from both entry export and entry import |
| 2026-06-30 | In Progress | Codex | Implemented the reduced CSV contract, validated local tests plus iOS simulator and Android emulator flows, and is now waiting for external review |
| 2026-07-01 | In Progress | Codex | Applied approved review fixes for `created_at` upper-bound validation plus import boundary coverage and reran the focused validation suites |
| 2026-07-01 | Complete | User/Codex | Knowledge-capture updates were approved and applied to long-lived guidance after review remediation and final iOS/Android validation |

---

## Overview

The current Wrait CSV contract includes an `id` column even though import does
not use that value to persist records. This makes the exported file noisier
than necessary and suggests a stronger identity meaning than the app actually
supports during import.

This feature simplifies the Wrait CSV contract by removing the `id` field from
both export and import. Exported files should contain only the entry content
and metadata that matter outside the local database, and import should accept
that reduced contract while remaining strictly additive and preserving draft
state as-is.

This change also removes the duplicated timestamp representation. The CSV
should carry `created_at` exactly as stored in the local database, with no
second converted timestamp field and no timestamp conversion during export or
import.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a diary user, I want exported CSV files to omit database-only identifiers
  so that the file contains only meaningful record data.
- As a diary user, I want Wrait import to work without an `id` column so that
  the CSV contract matches what export produces.
- As a maintainer, I want the import/export CSV contract to reflect actual app
  behavior so that users are not misled into thinking imported rows preserve
  or depend on database ids.
- As a maintainer, I want `created_at` to match the database value directly so
  that import/export avoids redundant timestamp conversion logic.

## Acceptance criteria

- [ ] Exported Wrait CSV files no longer include an `id` column.
- [ ] The exported CSV header and row order remain stable and understandable
      after removing `id`.
- [ ] The CSV contract includes a single `created_at` field and does not
      include a second converted timestamp representation.
- [ ] The exported `created_at` value matches the value stored in the database
      for that entry, with no export-time conversion.
- [ ] Import accepts the supported Wrait CSV format without an `id` column.
- [ ] Import reads `created_at` directly from the supported CSV contract
      without requiring conversion between multiple CSV timestamp fields.
- [ ] Import rejects `created_at` values outside the supported persisted
      timestamp range.
- [ ] Successful import still creates new local rows only and does not depend
      on any record identifier from the CSV file.
- [ ] Imported records still preserve the supported non-id metadata from the
      CSV format, including draft state, timestamps, language, word count, raw
      transcript, and cleaned text when present.
- [ ] Export and import remain mutually compatible after the `id` field is
      removed.
- [ ] Import does not need to preserve compatibility with older Wrait CSV
      files that still include an `id` column.
- [ ] Exporting and importing remain non-mutating toward existing entries
      except for the additive creation of new rows during successful import.
- [ ] Failure handling, empty-file behavior, app-lock compatibility, and
      capture-privacy expectations remain intact.
- [ ] Validation evidence includes automated coverage and Android emulator plus
      iOS simulator verification unless a planning-time exception is explicitly
      approved.

## API contract

This feature does not introduce or modify backend HTTP endpoints.

## Data model changes

This feature does not require new user-visible diary fields or changes to the
persisted entry data model.

The change is limited to the supported CSV representation of existing entries.
If planning identifies any existing local-data or CSV-compatibility constraint
that requires a broader contract change, that must be documented before
implementation.

## Dependencies

- [ ] Existing entry export behavior on `/entries`
- [ ] Existing entry import behavior on `/entries`
- [ ] Existing entry metadata: creation time, language, draft state, word
      count, raw transcript, and cleaned text
- [ ] Existing app-lock and capture-privacy behavior
- [ ] Android emulator validation path
- [ ] iOS simulator validation path

## UX / design references

No external design reference is currently provided.

This should stay a contract simplification, not a broader entries-screen
redesign. User-visible messaging should remain short and consistent with
current Wrait entry import/export behavior.

## Non-functional requirements

- **Performance:** Export and import should remain comparable to the current
  CSV flow for normal personal diary sizes.
- **Security:** The CSV contract must continue excluding secrets, encryption
  keys, retained audio files, and unrelated app-private data.
- **Reliability:** Export and import must remain clearly successful or clearly
  failed from the user's perspective, with no partial hidden mutation.
- **Scalability:** The simplified CSV contract should still support growth from
  a few records to a large personal diary without introducing a future need to
  restore database-only identifiers.
- **Observability:** Validation evidence must show that the CSV contract no
  longer includes `id`, that only one raw `created_at` value is exported and
  imported, that import/export remain compatible, and that additive import
  behavior is unchanged.

## Test strategy

Automated validation should cover the CSV header/row shape after `id` removal,
successful import of the supported no-id single-timestamp Wrait CSV,
empty-file behavior, and continued additive import behavior.

Runtime validation must exercise the user-visible entries import/export flows
on Android emulator and iOS simulator unless a planning-time validation
exception is explicitly requested and approved.

## Out of scope

- Reusing, restoring, or exposing database ids outside the app
- Introducing a separate external stable record identifier
- Broad CSV schema redesign beyond removing `id`
- Changing the entries screen beyond any feedback or behavior needed to keep
  import/export correct after the contract change
- Importing arbitrary third-party CSV formats
- Updating long-lived documentation before the final SDD knowledge-capture gate

## Open questions

No open questions remain in the spec. Clarification answer recorded:

- No backward compatibility is required for older Wrait CSV files that still
  include an `id` column.
- `created_at` should stay as the raw database value, with no separate
  converted timestamp field and no import/export timestamp conversion.
